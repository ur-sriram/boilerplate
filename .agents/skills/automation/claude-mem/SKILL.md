---
name: claude-mem
description: Persistent cross-session episodic memory using thedotmack/claude-mem architecture in .agents/memory/. Stores architectural decisions, user preferences and error recoveries, and recalls them at session start.
---

# Claude-Mem Episodic Memory

Stores and recalls architectural decisions, user preferences, and error
recoveries across sessions in `.agents/memory/`.

The store is implemented in `src/features/claude-mem/` and is invoked by the
`memory-sync` hook, which every hook-capable adapter registers
(`.claude/settings.json`, `.codex/config.toml`, `.goose/hooks.json`,
`.qoder/settings.json`, `.antigravity/hooks.json`,
`.opencode/plugins/memory-sync.js`).

## Usage

Record an episode:

```bash
node src/features/claude-mem/cli.ts remember --kind decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --tags architecture,layout
```

Recall episodes (free text is a relevance score, `--tags` is a hard filter):

```bash
node src/features/claude-mem/cli.ts recall --text "feature folder" --limit 5
node src/features/claude-mem/cli.ts list --limit 10
node src/features/claude-mem/cli.ts stats
```

The `sync` command is the hook entry point: it verifies the store, prints a
one-line summary and surfaces the most recent episodes as session context.

## Store

`.agents/memory/episodes.jsonl` — one JSON object per line, append-only,
newest last. Machine-local state, git-ignored, pruned to the newest 500
episodes.

## Guardrails

- Never store secrets or credentials: credentials are scrubbed at write time
  and `.agents/memory/` is scoped strictly inside the repository.
- The hook is advisory — a missing store or runtime never fails a session.
