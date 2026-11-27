---
name: claude-mem
description: Persistent cross-session episodic memory using thedotmack/claude-mem architecture in .agents/memory/. Stores architectural decisions, user preferences and error recoveries, and recalls them at session start.
---

# Claude-Mem Episodic Memory

Stores and recalls architectural decisions, user preferences, and error
recoveries across sessions in `.agents/memory/`.

The store is implemented in the `.repo/claude-mem/` island (vendored
third-party architecture, project-level) and is invoked by the `memory-sync`
hook, which every hook-capable adapter registers
(`.claude/settings.json`, `.codex/config.toml`, `.goose/hooks.json`,
`.qoder/settings.json`, `.antigravity/hooks.json`,
`.opencode/plugins/memory-sync.js`).

## Usage

Use the launcher (`.repo/claude-mem/run.mjs`) — it is plain JavaScript, so it
starts on any runtime the project supports and explains the problem instead of
failing opaquely when the runtime is too old for TypeScript type stripping.

Record an episode:

```bash
node .repo/claude-mem/run.mjs remember --kind decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --tags architecture,layout
```

Recall episodes (free text is a relevance score, `--tags` is a hard filter):

```bash
node .repo/claude-mem/run.mjs recall --text "feature folder" --limit 5
node .repo/claude-mem/run.mjs list --limit 10
node .repo/claude-mem/run.mjs stats
```

The `sync` command is the hook entry point: it verifies the store, prints a
one-line summary and surfaces the most recent episodes as session context.

## When to write

Record an episode when a decision is settled, a preference is stated, or an
error is recovered from — not on every turn. The agent is told to do this by
the `/remember` command; `/recall` searches the same store on demand.

Good titles are sharp and searchable ("Adopt feature-folder architecture"),
because the title carries three times the weight of the body in recall.

## Store

`.agents/memory/episodes.jsonl` — one JSON object per line, append-only,
newest last. Machine-local state, git-ignored, pruned to the newest 500
episodes.

## Guardrails

- Never store secrets or credentials: credentials are scrubbed at write time
  and `.agents/memory/` is scoped strictly inside the repository.
- The hook is advisory — a missing store or runtime never fails a session.
