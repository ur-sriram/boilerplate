# Claude-Mem Episodic Memory

Cross-session episodic memory: architectural decisions, user preferences, error
recoveries and learned project facts that survive a session boundary.

Vendored island — the architecture comes from
[`thedotmack/claude-mem`](https://github.com/thedotmack/claude-mem)
(Apache-2.0, pinned in [`THIRD_PARTY.md`](../../THIRD_PARTY.md)); the
implementation is local, dependency-free and project-level.

## Layout

| File | Role |
|---|---|
| `feature.types.ts` | Contracts: `MemoryEntry`, `MemoryDraft`, `MemoryQuery`, `MemoryStats` |
| `feature.ts` | `MemoryStore` — read, write, recall, prune, redact — plus `findProjectRoot` |
| `cli.ts` | `remember` / `recall` / `list` / `stats` / `sync` commands |
| `run.mjs` | Plain-JS launcher: checks the runtime, then runs the CLI |
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

Always go through the launcher — `run.mjs` is plain JavaScript, so it loads on
every runtime and can explain a problem that `cli.ts` could only fail with:

```bash
node .repo/claude-mem/run.mjs remember --kind decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --tags architecture,layout

node .repo/claude-mem/run.mjs recall --text "feature folder" --limit 5
node .repo/claude-mem/run.mjs list --limit 10
node .repo/claude-mem/run.mjs stats
```

The `sync` command is the lifecycle-hook entry point: it verifies the store,
prints a one-line summary and surfaces the most recent episodes.

Agents reach the same commands through the `/remember` and `/recall` slash
commands.

## Invariants

- **Project-local**: every read and write resolves inside the project root.
  `findProjectRoot` walks up to the nearest `AGENTS.md` instead of counting
  directory levels, because a fixed depth once pointed the store at the
  *parent* of the project.
- **Secret hygiene**: credentials are scrubbed before an episode is written.
- **Bounded**: the store is pruned to the newest 500 episodes.
- **Advisory**: a missing store, a missing runtime or an old runtime never
  fails the session that triggered it.

## Runtime

Node **>= 22.18.0**. The CLI is TypeScript executed directly by Node, which
needs the type stripping that is on by default from 22.18. `run.mjs` checks
the version first and prints what to install instead of failing opaquely.

## Related

- Skill: `.agents/skills/automation/claude-mem/SKILL.md`
- Hook: `scripts/hooks/memory-sync.sh`, `scripts/hooks/memory-sync.ps1`,
  `scripts/hooks/run-hook.mjs memory-sync`
- Architecture: `docs/architecture/claude-mem.md`
