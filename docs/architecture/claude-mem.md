# Claude-Mem: From Documentation-Only to a Working Episodic Memory Store

**Status:** implemented.
**Scope:** the `claude-mem` skill, the `memory-sync` hook and the `.agents/memory/`
store.

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
repository's own conventions: a feature folder under `src/features/`, strict
TypeScript, and TDD.

Route A was chosen.

## 3. Upstream parity

Upstream `thedotmack/claude-mem` is a full product: a Bun worker service, an
LLM "observer" that runs beside the coding agent, SQLite plus Chroma, a
25-tool MCP server, cloud sync and telemetry. A project-local store cannot
and should not reproduce all of that. What it can do is reproduce the
**concepts** that make the system work.

| Upstream concept | Where it lives upstream | Here | Status |
|---|---|---|---|
| Observation **types** (9, from the `code` mode profile) | `plugin/modes/code.json` | `MemoryType` in `feature.types.ts` | **Adapted** |
| Observation **concepts** (7) | `plugin/modes/code.json` | `MemoryConcept` in `feature.types.ts` | **Adapted** |
| `sensitive` type withheld from injection | `src/sdk/prompts.ts` | `sensitive` excluded from recall unless `--include-sensitive` | **Adapted** |
| Tier-0 dedup: exact title → silent auto-merge | `src/services/dedup/nearDuplicate.ts` | same normalized title → merged in place | **Adapted** |
| Tier-1 dedup: near-duplicate → review candidate, never a silent merge | `src/services/dedup/nearDuplicate.ts` | near-duplicate → **not written**, reported to the caller | **Adapted** |
| IDF model + veto (`token_df`, `idf.ts`, `idfVeto.ts`) | `src/services/sqlite/dedup-store.ts` | `buildIdfModel` in `scoring.ts`, applied to ranking | **Adapted** |
| Index-first retrieval: `search` → `timeline` → `get_observations` | `src/servers/mcp-server.ts` | `search` → `timeline` → `get`, index rows carry no body | **Adapted** |
| Session identity (`memory_session_id`) | `observations.memory_session_id` | `session.json` + `MemorySession` | **Adapted** |
| Redaction of credentials | `src/utils/redaction.ts` (opt-in) | always on (upstream defaults to **off**) | **Adapted, stronger** |
| Project scoping | one user-scoped `~/.claude-mem` DB, projects are rows | one store per project, inside the project root | **Adapted, stronger** |
| No telemetry / no cloud | telemetry on by default upstream | none | **Adapted** |
| Observer process (LLM writes the observations) | `src/services/worker/`, `src/sdk/prompts.ts` | — | **Not adapted** (needs a model provider) |
| Automatic capture from tool activity | 8 Claude Code hook events | — | **Not adapted** (no observer to observe) |
| SQLite + FTS5 + Chroma vectors | `src/services/sqlite/`, `src/services/worker/search/` | JSONL + IDF ranking | **Not adapted** (no dependencies) |
| MCP server with 25 tools | `src/servers/mcp-server.ts` | — | **Not adapted** (see below) |
| Session summaries (`session_summaries`) | `src/services/sqlite/SessionStore.ts` | — | **Not adapted** (produced by the observer) |
| Corpus / knowledge agent, work state, TeamBrain, cloud sync | `src/services/worker/knowledge/`, `src/server/routes/` | — | **Out of scope** (product features, not memory) |

### Deliberate deviations

1. **Project-scoped, not user-scoped.** Upstream keeps one database for the
   whole machine and keys it by project. This repository's first invariant is
   "never write outside the project root" (`AGENTS.md:9`), so the store lives
   inside the project and is git-ignored.
2. **Redaction is always on.** Upstream ships `CLAUDE_MEM_REDACT_ENABLED:
   'false'` — redaction is opt-in. Here it is unconditional, because the
   store is shared between agents and the repo's invariant is "ZERO secrets
   committed".
3. **JSONL, not SQLite.** No native dependency, no build step, and the store
   is small enough (≤500 episodes) that a full-text index would be
   premature.
4. **Dedup similarity is Jaccard, not TF-IDF cosine.** Upstream compares
   near-duplicates with a TF-IDF cosine. At write time the corpus is still
   half-built, so a TF-IDF verdict depends on how much history happens to
   exist yet — two episodes differing only in a number were flagged as
   duplicates when the store was young and not when it was full. Jaccard has
   no such dependence. The IDF model is still used for **ranking**, where the
   whole store is available.
5. **Types are a fixed set.** Upstream's types are data-driven per "mode"
   (`src/services/domain/ModeManager.ts`); a project-local store has one mode,
   so the `code` mode's nine types are taken as the vocabulary.

### What is still missing, and why

- **The MCP server surface.** Upstream exposes `search`, `timeline`,
  `get_observations`, `save_memory` and twenty more tools so an agent can
  query memory natively. This repository's integration is the CLI plus the
  lifecycle hook. Adding an always-on MCP server would put a fourth server
  into all nine manifests and break the ~350-token "core" profile budget.
  A local stdio MCP server with the four memory tools is the natural next
  step if the budget allows it.
- **Automatic capture.** Upstream records every tool call and has an LLM
  summarise it into observations. Without a model provider there is nothing
  to summarise with, so episodes are written explicitly by an agent. The
  deterministic half of upstream's capture — which files were read and
  edited — is still possible and is not implemented.

## 4. What was built

### 4.1 The island — `.repo/claude-mem/`

| File | Role |
|---|---|
| `feature.types.ts` | Taxonomy (types, concepts), entry, index row, session, query |
| `feature.ts` | `MemoryStore`: read, write, dedup, recall, prune, redact, sessions |
| `scoring.ts` | `terms`, `normalizeTitle`, `buildIdfModel`, `jaccard` |
| `cli.ts` | `remember` / `search` / `get` / `timeline` / `list` / `sessions` / `stats` / `sync` |
| `run.mjs` | Plain-JS launcher: checks the runtime, then runs the CLI |
| `feature.test.ts` | 22 unit tests (`npm test`) |

**Format.** `.agents/memory/episodes.jsonl` — one JSON object per line,
append-only, newest last:

```json
{"id":"…","type":"decision","title":"…","body":"…","concepts":["why-it-exists"],
 "tags":["…"],"sessionId":"s-20261126T2312Z-3f9a","createdAt":"…"}
```

A corrupt line is skipped rather than failing the store, so a half-written
file can never break a session.

**Retrieval.** Upstream's three-step contract: `search` returns compact index
rows (no body — roughly a tenth of a full record), `timeline` returns the
episodes around an anchor, `get` returns the full record for the ids that
were chosen. Tags, concepts and types are hard filters; free text is scored
with the IDF model, and a term that occurs in most episodes is vetoed
because it no longer discriminates.

**Dedup.** Two tiers, both from upstream: an identical normalized title is
merged in place; a near-duplicate is reported and **not** written, because
silently merging would lose knowledge.

**Guardrails, enforced in code rather than prose.** Credentials are scrubbed
before an episode is written; every path resolves inside the project root;
the store is pruned to the newest 500 episodes; the store file is
git-ignored as machine-local state.

**Project root.** `findProjectRoot()` walks up to the nearest `AGENTS.md`
instead of counting directory levels. A fixed depth is a trap: when the
island sat under `src/features/claude-mem/` it was three levels up, and the
same arithmetic then pointed the store at the **parent of the project** — a
write outside the boundary the store promises never to cross. Two unit tests
pin this behaviour.

### 4.2 The hook — `memory-sync`

`scripts/hooks/run-hook.mjs` gained a `memory-sync` handler, and
`scripts/hooks/memory-sync.{sh,ps1}` were rewritten from `mkdir + echo` into
real invocations of the same launcher. One implementation, four entry points
(the POSIX path, the PowerShell path, the Node dispatcher and the OpenCode
plugin), so they cannot disagree about the format, the redaction rules, the
store location or the runtime requirement.

The hook is the session boundary: it opens a session, so every episode
written afterwards is attributed to it — upstream's `memory_session_id`.

The hook is advisory: a missing store or a missing Node runtime never fails
the session it runs in.

### 4.3 The commands — `/remember` and `/recall`

Recall at session start is automatic; **writing was not**. Nothing in the
agent workflow ever wrote an episode, so in a real session the hook recalled
an empty store — the feature looked alive and did nothing. Only the test
suite ever filled it.

| Command | What it does |
|---|---|
| `/remember` | Record an observation — a decision, a discovery, a change, a gotcha. |
| `/recall` | Search the store for what earlier sessions observed. |

Both live in `.agents/commands/` (the canonical source), are distributed to
every adapter by `scripts/sync-agent-adapters.sh`, and are enforced by
`scripts/verify-adapters.py`. `AGENTS.md` states the invariant that ties them
together, and `.agents/rules/core-invariants.md` gives the adapters without
a hook API a prompt-level rule to fall back on.

### 4.4 The wiring — every hook-capable adapter

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
`.agents/rules/core-invariants.md`.

### 4.5 The enforcement — the part that was missing

The reason this feature died is that nothing checked it. Four checks now do:

1. **`scripts/verify-adapters.py`** — `HOOK_MARKERS` gained `memory-sync`, so
   an adapter that loses the hook fails the parity suite.
2. **`scripts/verify-adapters.py`** — `CANONICAL_COMMANDS` gained `remember`
   and `recall`, so an adapter that loses either command fails too.
3. **`scripts/verify-scripts.{sh,ps1}`** — the `memory-sync` hook is dry-run
   and must report the episodic store, instead of merely parsing.
4. **`scripts/test-bootstrap.{sh,ps1}`** — a new Assertion 6 writes an episode
   into the sandbox, recalls it, checks the store stayed inside the project
   root, and asserts the hook is registered in every hook-capable adapter.

`scripts/verify-opencode-plugins.mjs` also exercises the new OpenCode plugin
against the loader contract.

### 4.6 The runtime requirement

The CLI is TypeScript executed directly by Node, which needs the type
stripping that ships by default from **Node 22.18.0**. On an older runtime
the failure happens while the module graph is loading — before any code in
`cli.ts` runs — so it surfaced as an opaque
`TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".ts"`,
swallowed by the advisory catch. Three changes make it honest:

- `run.mjs` is plain JavaScript, so it always loads; it checks the version
  and prints what to install.
- `package.json` declares `"node": ">=22.18.0"`.
- `scripts/verify-tools.{sh,ps1}` asserts the version, so CI catches it
  before a session does.

## 5. Documentation corrections

| File | Change |
|---|---|
| `AGENTS.md:11` | Describes the real store and the hook. |
| `.agents/skills/automation/claude-mem/SKILL.md` | Real usage: CLI commands, taxonomy, store format, guardrails. |
| `.agents/memory/README.md` | Store format, retention, hook wiring. |
| `.agents/rules/automation.md` | New hook in the tree and the contract table; the bootstrap-validation claim is now true. |
| `README.md` | New feature row; the suite count (9 → 10) matches reality. |
| `THIRD_PARTY.md:23` | Status `Integrated on Demand` → `Adapted & Hooked`; the impossible `node mcp-server.cjs` invocation removed. |
| `docs/agents/*.md` | The memory-sync hook documented for all six hook-capable agents. |
| `docs/architecture/conflict-resolution.md` | `mcp-search` marked as upstream-only and unused here. |
| `.gitignore` / `.aiignore` | The store file is machine-local state. |
| `.repo/README.md` | What a vendored island is and the rules one follows. |
| `.agents/rules/core-invariants.md` | New section: persist decisions, recall before asking, never invent history, keep secrets out. |
| `docs/architecture/claude-mem.md` | This document — the island, the write path and the runtime floor. |
| `package.json` | The Node engine floor is `>=22.18.0`: the hooks and the test suite both execute TypeScript directly, and type stripping is unflagged only from Node 22.18. |

## 6. Residual risk

- **Recall quality is lexical.** Scoring is IDF-weighted keyword matching, not
  semantic; there is no embedding index. This matches the repository's "no
  external telemetry, no heavyweight dependency" posture, but recall is
  weaker than a semantic index for paraphrased questions.
- **Adapters without a hook API get no automatic recall.** The store is still
  writable and readable by hand; only the automatic trigger is missing there.
- **Qoder and Antigravity use a `"MemorySync"` event key.** Those runtimes
  ignore unknown event keys rather than failing, so the worst case is that the
  recall does not fire on those two hosts — it cannot break them.
- **No automatic capture.** Episodes are written explicitly; upstream writes
  them from observed tool activity.
- **The store is machine-local.** It is git-ignored, so a team shares no
  memory: each clone starts empty. Sharing it would mean committing episodes,
  which conflicts with the "zero secrets, machine-local state" rule.
- **The island is vendored code.** `.repo/claude-mem/` is a local
  reimplementation of upstream's architecture, not upstream's code. It is
  pinned in `THIRD_PARTY.md`, and it stays in `.repo/` so that `src/features/`
  remains free for the user's own features.
