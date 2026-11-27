# Claude-Mem: a working, project-level episodic memory store

**Status:** implemented, and reachable from every adapter.
**Scope:** the `claude-mem` skill, the `/remember` + `/recall` commands, the
`memory-sync` hook and the `.agents/memory/` store.

---

## 1. The problem

The repository described an episodic memory system in seven places and
implemented none of it:

| Claim | Reality |
|---|---|
| `AGENTS.md:11` — "Cross-session memory and learned operational facts persist in `.agents/memory/`" | Nothing was ever written. `.agents/memory/` contained only `.gitkeep` and a `README.md`. |
| `.agents/skills/automation/claude-mem/SKILL.md` — "Stores and recalls … across sessions" | A 12-line stub: the only file in the skill folder, with no store, no schema, no CLI. |
| `scripts/hooks/memory-sync.{sh,ps1}` — "Synced via …" | `mkdir -p` + `echo`. They created a directory and printed a line. |
| `THIRD_PARTY.md:23` — "**Integrated on Demand**", invocation `node mcp-server.cjs` | No MCP config contained claude-mem, and upstream ships `src/servers/mcp-server.ts` (TypeScript, needs a build) — there is no root `mcp-server.cjs`, so the documented invocation could never have worked. |
| `.agents/rules/automation.md:120` — "`claude-mem` … validated" by the bootstrap suite | `grep` for `claude-mem`/`memory-sync` in `scripts/test-bootstrap.{sh,ps1}` returned nothing. |

Worse, the whole suite was green while the feature was dead:

```
bash scripts/verify-all.sh   →  ALL VERIFICATION SUITES PASSED (100% GREEN)
```

`scripts/verify-adapters.py` checked that the three existing hooks were
wired, `scripts/verify-scripts.sh` only AST-parsed the hook scripts, and no
test ever wrote and read a memory. **The feature was unenforced, so it
decayed to a stub without a single failure.**

## 2. Why a local store, not the upstream MCP server

Two routes were available.

**Route B — install the upstream MCP server.** It would add a third always-on
server to all nine MCP manifests and to every profile in
`scripts/mcp-profile.py`, for a feature the repository only ever claimed as
"architecture". It also contradicts the repo's own context-budget rules
(the "core" profile is capped at ~350 tokens) and the "no external service"
posture of the guardrails.

**Route A — implement the architecture locally.** Dependency-free (Node
built-ins only), project-local, no new always-on MCP server, and it fits the
repository's own conventions: strict TypeScript, and TDD.

Route A was chosen.

## 3. What was built

### 3.1 The island — `.repo/claude-mem/`

The store is **vendored third-party architecture**, so it does not belong in
`src/features/` — that folder is the user's own code (`cp -r
src/features/_template src/features/my-feature`). It lives in a project-level
island instead:

| File | Role |
|---|---|
| `feature.types.ts` | `MemoryEntry`, `MemoryDraft`, `MemoryQuery`, `MemoryStats` |
| `feature.ts` | `MemoryStore`: read, write, recall, prune, redact — plus `findProjectRoot` |
| `cli.ts` | `remember` / `recall` / `list` / `stats` / `sync` |
| `run.mjs` | Plain-JS launcher: checks the runtime, then runs the CLI |
| `feature.test.ts` | 15 unit tests (`npm test`) |

**Format.** `.agents/memory/episodes.jsonl` — one JSON object per line,
append-only, newest last:

```json
{"id":"…","kind":"decision","title":"…","body":"…","tags":["…"],
 "sessionId":"…","createdAt":"2026-11-26T22:41:14.401Z"}
```

A corrupt line is skipped rather than failing the store, so a half-written
file can never break a session.

**Recall.** Tags are a hard filter; free text is a relevance score where a
title hit outweighs a body hit, so a sharply-titled decision wins over a
passing mention in a long body.

**Guardrails, enforced in code rather than prose.** Credentials are scrubbed
before an episode is written (GitHub/Slack/OpenAI/AWS/Google tokens, private
key blocks, `Bearer` headers and `key: value` assignments); every path
resolves inside the project root; the store is pruned to the newest 500
episodes; and the store file is git-ignored as machine-local state.

**Project root.** `findProjectRoot()` walks up to the nearest `AGENTS.md`
instead of counting directory levels. A fixed depth is a trap: when the island
sat under `src/features/claude-mem/` it was three levels up, and the same
arithmetic then pointed the store at the **parent of the project** — a write
outside the boundary the store promises never to cross. Two unit tests now
pin this behaviour.

### 3.2 The hook — `memory-sync`

`scripts/hooks/run-hook.mjs` gained a `memory-sync` handler, and
`scripts/hooks/memory-sync.{sh,ps1}` were rewritten from `mkdir + echo` into
real invocations of the same launcher. One implementation, four entry points
(the POSIX path, the PowerShell path, the Node dispatcher and the OpenCode
plugin), so they cannot disagree about the format, the redaction rules or the
store location.

The hook is advisory: a missing store or a missing Node runtime never fails
the session it runs in.

### 3.3 The commands — `/remember` and `/recall`

Recall at session start is automatic; **writing was not**. Nothing in the
agent workflow ever wrote an episode, so in a real session the hook recalled
an empty store — the feature looked alive and did nothing.

| Command | What it does |
|---|---|
| `/remember` | Record a decision, preference, error recovery or fact. |
| `/recall` | Search the store for what earlier sessions decided. |

Both live in `.agents/commands/` (the canonical source), are distributed to
every adapter by `scripts/sync-agent-adapters.sh`, and are enforced by
`scripts/verify-adapters.py`. `AGENTS.md` states the invariant that ties them
together: memory persists because the agent is told to write into it.

### 3.4 The wiring — every hook-capable adapter

| Adapter | Registration |
|---|---|
| Claude Code | `.claude/settings.json` → second `SessionStart` group |
| Codex CLI | `.codex/config.toml` → second `[[hooks.SessionStart]]` |
| Goose CLI | `.goose/hooks.json` → second `SessionStart` event |
| Qoder | `.qoder/settings.json` → `"MemorySync"` hook |
| Antigravity | `.antigravity/hooks.json` → `"MemorySync"` event |
| OpenCode | `.opencode/plugins/memory-sync.js` → new path plugin |

Adapters without a hook API (Cursor, Cline, Windsurf, Copilot, Kimi, Junie)
are unchanged; they rely on the prompt-level rules, as documented in
`.agents/rules/core-invariants.md` — and on `/recall` for on-demand search.

### 3.5 The enforcement — the part that was missing

The reason this feature died is that nothing checked it. Four checks now do:

1. **`scripts/verify-adapters.py`** — `HOOK_MARKERS` gained `memory-sync`, so
   an adapter that loses the hook fails the parity suite.
2. **`scripts/verify-adapters.py`** — `CANONICAL_COMMANDS` gained `remember`
   and `recall`, so an adapter that loses either command fails too.
3. **`scripts/verify-scripts.{sh,ps1}`** — the `memory-sync` hook is dry-run
   and must report the episodic store, instead of merely parsing.
4. **`scripts/test-bootstrap.{sh,ps1}`** — Assertion 6 writes an episode into
   the sandbox, recalls it, checks the store stayed inside the project root,
   and asserts the hook is registered in every hook-capable adapter.

`scripts/verify-opencode-plugins.mjs` also exercises the new OpenCode plugin
against the loader contract.

### 3.6 The runtime requirement

The CLI is TypeScript executed directly by Node, which needs the type
stripping that ships by default from **Node 22.18.0**. On an older runtime
the failure happens while the module graph is loading — before any code in
`cli.ts` runs — so it surfaced as an opaque
`TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".ts"`,
swallowed by the advisory catch. Three changes make it honest:

- `run.mjs` is plain JavaScript, so it always loads; it checks the version and
  prints what to install.
- `package.json` declares `"node": ">=22.18.0"` (it claimed `>=22.6.0`).
- `scripts/verify-tools.{sh,ps1}` asserts the version, so CI catches it
  before a session does.

## 4. Documentation corrections

| File | Change |
|---|---|
| `AGENTS.md` | Describes the real store, the commands, and the `.repo/` island convention. |
| `.agents/skills/automation/claude-mem/SKILL.md` | Real usage: launcher, CLI commands, when to write, store format, guardrails. |
| `.agents/memory/README.md` | Store format, retention, hook and command wiring. |
| `.agents/rules/automation.md` | New hook in the tree and the contract table; the write path is documented; the bootstrap-validation claim is now true. |
| `README.md` | New feature row; the slash-command table; the suite count (9 → 10) matches reality. |
| `THIRD_PARTY.md:23` | Status `Integrated on Demand` → `Adapted & Hooked`; the impossible `node mcp-server.cjs` invocation removed; the island path recorded. |
| `docs/agents/*.md` | The memory-sync hook and the two commands documented for all six hook-capable agents. |
| `.gitignore` / `.aiignore` | The store file is machine-local state. |

## 5. Residual risk

- **Recall quality is lexical.** Scoring is keyword-based, not semantic; there
  is no embedding or vector index. This matches the repository's "no external
  telemetry, no heavyweight dependency" posture, but it means recall is weaker
  than a semantic index for paraphrased questions.
- **Adapters without a hook API get no automatic recall.** The store is still
  writable and readable by hand — and through `/recall`; only the automatic
  trigger is missing there.
- **Qoder and Antigravity use a `"MemorySync"` event key.** Those runtimes
  ignore unknown event keys rather than failing, so the worst case is that the
  recall does not fire on those two hosts — it cannot break them.
- **The store is machine-local.** It is git-ignored, so a team shares no
  memory: each clone starts empty. Sharing it would mean committing episodes,
  which conflicts with the "zero secrets, machine-local state" rule.
