# Claude-Mem Episodic Memory

Cross-session episodic memory: architectural decisions, user preferences, error
recoveries and learned project facts that survive a session boundary.

## Layout

| File | Role |
|---|---|
| `feature.types.ts` | Contracts: `MemoryEntry`, `MemoryDraft`, `MemoryQuery`, `MemoryStats` |
| `feature.ts` | `MemoryStore` — read, write, recall, prune, redact |
| `cli.ts` | `remember` / `recall` / `list` / `stats` / `sync` commands |
| `feature.test.ts` | Unit tests (`npm test`) |

## Store

Episodes live in `<project-root>/.agents/memory/episodes.jsonl` — one JSON
object per line, append-only, newest last. A corrupt line is skipped rather
than failing the store, so a half-written file can never break a session.

```json
{"id":"…","kind":"decision","title":"…","body":"…","tags":["…"],"sessionId":"…","createdAt":"…"}
```

The file is machine-local state and is git-ignored.

## Usage

```bash
node src/features/claude-mem/cli.ts remember --kind decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --tags architecture,layout

node src/features/claude-mem/cli.ts recall --text "feature folder" --limit 5
node src/features/claude-mem/cli.ts list --limit 10
node src/features/claude-mem/cli.ts stats
```

The `sync` command is the lifecycle-hook entry point: it verifies the store,
prints a one-line summary and surfaces the most recent episodes.

## Invariants

- **Project-local**: every read and write resolves inside the project root.
- **Secret hygiene**: credentials are scrubbed before an episode is written.
- **Bounded**: the store is pruned to the newest 500 episodes.

## Related

- Skill: `.agents/skills/automation/claude-mem/SKILL.md`
- Hook: `scripts/hooks/memory-sync.sh`, `scripts/hooks/memory-sync.ps1`,
  `scripts/hooks/run-hook.mjs memory-sync`
