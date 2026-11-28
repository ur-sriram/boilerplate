# Cursor Setup

Cursor reads project rules from `.cursor/rules/core.mdc`, MCP servers from
`.cursor/mcp.json`, and slash commands from `.cursor/commands/`.

## 1. Entry Points

| What | Where |
|---|---|
| Rules | `.cursor/rules/core.mdc` (points at `AGENTS.md` and `.agents/rules/`) |
| MCP servers | `.cursor/mcp.json` — canonical invocations, `graphify` on by default |
| Slash commands | `.cursor/commands/*.md` (10 commands) |
| Skills | `.cursor/skills` → junction to `.agents/skills`; Cursor also reads `.agents/skills` natively |
| Hooks | Not available in Cursor project config — the guardrail is enforced at the prompt level by `AGENTS.md` |

## 2. MCP Invocation

The canonical invocations (kept identical to the root `.mcp.json`):

```json
"graphify":     { "command": "uvx", "args": ["--from", "graphifyy[mcp]", "graphify-mcp"] },
"ui-registry":  { "command": "npx", "args": ["-y", "ui-registry-mcp@0.7.1"], "disabled": true },
"headroom":     { "command": "uvx", "args": ["--from", "headroom-ai[mcp]", "headroom", "mcp", "serve"], "disabled": true }
```

`scripts/mcp-profile.py` rewrites the `disabled` flags of every adapter config
when the profile changes.

## 3. Slash Commands

Cursor discovers project-level commands in `.cursor/commands/`. The files are
copied there from `.agents/commands/` by `scripts/sync-agent-adapters.sh` — edit
the canonical copy, never the distributed one.
