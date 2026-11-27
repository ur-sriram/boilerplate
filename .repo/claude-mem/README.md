# Claude-Mem Episodic Memory

Cross-session episodic memory: decisions, discoveries, changes and gotchas
that survive a session boundary, using the upstream observation types.

Vendored island — the architecture comes from
[`thedotmack/claude-mem`](https://github.com/thedotmack/claude-mem)
(Apache-2.0, pinned in [`THIRD_PARTY.md`](../../THIRD_PARTY.md)); the
implementation is local, dependency-free and project-level.

## Layout

| File | Role |
|---|---|
| `feature.types.ts` | Taxonomy (types, concepts), entry, index row, session, query |
| `feature.ts` | `MemoryStore` — read, write, dedup, recall, prune, redact, sessions — plus `findProjectRoot` |
| `scoring.ts` | `terms`, `normalizeTitle`, `buildIdfModel`, `jaccard` |
| `cli.ts` | `remember` / `search` / `get` / `timeline` / `list` / `sessions` / `stats` / `sync` |
| `run.mjs` | Plain-JS launcher: checks the runtime, then runs the CLI |
| `feature.test.ts` | Unit tests (`npm test`) |

## Store

Episodes live in `<project-root>/.agents/memory/episodes.jsonl` — one JSON
object per line, append-only, newest last. The file is machine-local state
and is git-ignored.

```json
{"id":"…","type":"decision","title":"…","body":"…","concepts":["why-it-exists"],
 "tags":["…"],"sessionId":"s-…","createdAt":"…"}
```

A corrupt line is skipped rather than failing the store, so a half-written
file can never break a session.

## Usage

Always go through the launcher — `run.mjs` is plain JavaScript, so it loads on
every runtime and can explain a problem that `cli.ts` could only fail with:

```bash
node .repo/claude-mem/run.mjs remember --type decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --concepts why-it-exists --tags architecture,layout

node .repo/claude-mem/run.mjs search --text "feature folder" --limit 5
node .repo/claude-mem/run.mjs get <id>
node .repo/claude-mem/run.mjs stats
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --concepts why-it-exists --tags architecture,layout

node .repo/claude-mem/run.mjs search --text "feature folder" --limit 5
node .repo/claude-mem/run.mjs get <id>
node .repo/claude-mem/run.mjs stats
```

`search` returns compact index rows; `get` returns the full record. That
split is upstream's three-step retrieval contract (search → timeline →
get): an index row costs roughly a tenth of a full record, so details are
only paid for on the episodes that were actually read.

Agents reach the same commands through the `/remember` and `/recall` slash
commands.

## Invariants

- **Project-local**: every read and write resolves inside the project root.
  `findProjectRoot` walks up to the nearest `AGENTS.md` instead of counting
  directory levels, because a fixed depth once pointed the store at the
  *parent* of the project.
- **Secret hygiene**: credentials are scrubbed before an episode is written.
- **Bounded**: the store is pruned to the newest 500 episodes.

## Related

- Skill: `.agents/skills/automation/claude-mem/SKILL.md`
- Hook: `scripts/hooks/memory-sync.sh`, `scripts/hooks/memory-sync.ps1`,
  `scripts/hooks/run-hook.mjs memory-sync`
