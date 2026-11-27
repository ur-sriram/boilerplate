---
name: claude-mem
description: Persistent cross-session episodic memory using thedotmack/claude-mem architecture in .agents/memory/. Stores decisions, discoveries and security notes, and recalls them at session start.
---

# Claude-Mem Episodic Memory

Stores and recalls observations across sessions in `.agents/memory/`: the
decisions, discoveries, changes and gotchas a project accumulates while it is
being built.

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
node .repo/claude-mem/run.mjs remember --type decision \
  --title "Adopt feature-folder architecture" \
  --body "All capabilities live under src/features/<name>/." \
  --concepts why-it-exists --tags architecture,layout
```

Recall episodes. Follow the three steps — search first, then fetch details
only for the ids you need:

```bash
node .repo/claude-mem/run.mjs search --text "feature folder" --limit 5
node .repo/claude-mem/run.mjs timeline <id> --depth 3
node .repo/claude-mem/run.mjs get <id>
```

A search returns compact index rows; a `get` returns the full record.

Other commands: `list`, `sessions`, `stats`, `sync`.

## Types and concepts

Types follow the upstream `code` mode profile: `bugfix`, `feature`,
`refactor`, `change`, `discovery`, `decision`, `security_alert`,
`security_note`, `sensitive`.

Concepts follow the same profile: `how-it-works`, `why-it-exists`,
`what-changed`, `problem-solution`, `gotcha`, `pattern`, `trade-off`.

`sensitive` episodes are stored but withheld from recall unless
`--include-sensitive` is passed.

## When to write

Record an episode when a decision is settled, a preference is stated, or an
error is recovered from — not on every turn. The agent is told to do this by
the `/remember` command; `/recall` searches the same store on demand.

Good titles are sharp and searchable ("Adopt feature-folder architecture"):
a title hit carries three times the weight of a body hit, and rare terms count
for more than common ones, so a precise title is what makes an episode
findable later.

## Store

`.agents/memory/episodes.jsonl` — one JSON object per line, append-only,
newest last. Machine-local state, git-ignored, pruned to the newest 500
episodes.

## Guardrails

- Never store secrets or credentials: credentials are scrubbed at write time
  and `.agents/memory/` is scoped strictly inside the repository.
- An episode whose title duplicates an existing one is merged, not duplicated.
- A near-duplicate is reported and not written, so nothing is lost silently.
- The hook is advisory — a missing store or runtime never fails a session.
