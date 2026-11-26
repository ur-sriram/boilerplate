# Claude Code Setup

Claude Code reads `CLAUDE.md` (which is just `@AGENTS.md`), the project
`.mcp.json`, `.claude/settings.json` and `.claude/commands/`.

## 1. Entry Points

| What | Where |
|---|---|
| Instructions | `CLAUDE.md` → `@AGENTS.md` (single source of truth) |
| MCP servers | `.mcp.json` (root) — `graphify` on, `ui-registry`/`headroom` off by default |
| Hooks | `.claude/settings.json` — `PreToolUse`, `PostToolUse`, `SessionStart` |
| Slash commands | `.claude/commands/*.md` (8 commands, distributed from `.agents/commands/`) |
| Skills | `.claude/skills` → junction to `.agents/skills` (created by `scripts/sync-agent-adapters.sh`) |

## 2. Hooks

All three hooks call the cross-platform Node dispatcher, so they behave
identically on Windows, macOS and Linux:

```json
"PreToolUse":  [ { "matcher": "Write|Edit|MultiEdit", "hooks": [ { "type": "command", "command": "node ./scripts/hooks/run-hook.mjs protect-config" } ] } ],
"PostToolUse": [ { "matcher": "Bash",                    "hooks": [ { "type": "command", "command": "node ./scripts/hooks/run-hook.mjs rtk-filter" } ] } ],
"SessionStart":[ {                                             "hooks": [ { "type": "command", "command": "node ./scripts/hooks/run-hook.mjs session-start" } ] } ]
```

- `protect-config` blocks any write whose resolved path falls outside the
  project root (exit code 1). It resolves both the root and the target
  physically, so a checkout behind a symlink still works.
- `rtk-filter` pipes terminal output through `rtk` when installed and passes
  it through untouched otherwise.
- `session-start` prints the runtime readiness summary.

## 3. Skills

Claude Code reads `.claude/skills/`. The junction is created by:

```bash
./scripts/sync-agent-adapters.sh
```

`--verify-only` fails if the junction is missing **or does not resolve into
`.agents/skills`**.

## 4. Verification

```bash
python3 scripts/verify-adapters.py   # parity matrix for every adapter
```
