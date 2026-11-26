# Claude-Mem Episodic Memory

Cross-session episodic memory: decisions, discoveries, preferences and error
recoveries that survive a session boundary.

## Layout

| File | Role |
|---|---|
| `feature.types.ts` | Taxonomy (types, concepts), entry, index row, session, query |
| `feature.ts` | `MemoryStore` — read, write, dedup, recall, prune, redact, sessions |
| `scoring.ts` | `terms`, `normalizeTitle`, `buildIdfModel`, `jaccard` |
| `cli.ts` | `remember` / `search` / `get` / `timeline` / `list` / `sessions` / `stats` / `sync` |
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

```bash
node src/features/claude-mem/cli.ts remember --type decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --concepts why-it-exists --tags architecture,layout

node src/features/claude-mem/cli.ts search --text "feature folder" --limit 5
node src/features/claude-mem/cli.ts get <id>
node src/features/claude-mem/cli.ts stats
```

`search` returns compact index rows; `get` returns the full record. That
split is upstream's three-step retrieval contract (search → timeline →
get): an index row costs roughly a tenth of a full record, so details are
only paid for on the episodes that were actually read.

## Invariants

- **Project-local**: every read and write resolves inside the project root.
- **Secret hygiene**: credentials are scrubbed before an episode is written.
- **Bounded**: the store is pruned to the newest 500 episodes.
- **No silent loss**: an identical title is merged; a near-duplicate is
  reported and not written.

## Related

- Skill: `.agents/skills/automation/claude-mem/SKILL.md`
- Hook: `scripts/hooks/memory-sync.sh`, `scripts/hooks/memory-sync.ps1`,
  `scripts/hooks/run-hook.mjs memory-sync`
- Upstream parity: `docs/architecture/claude-mem.md`
