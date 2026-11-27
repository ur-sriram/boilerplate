# Episodic Memory Store (`.agents/memory/`)

Powered by the `thedotmack/claude-mem` architecture, implemented locally in
the `.repo/claude-mem/` island.

- Stores cross-session architectural decisions, user preferences, and error
  recoveries strictly within the repository boundary.
- Episodes live in `episodes.jsonl` — one JSON object per line, append-only,
  newest last. The file is machine-local state and is git-ignored.
- Written by the agent through the `/remember` command, or by hand:
  `node .repo/claude-mem/run.mjs remember --kind decision --title "…"`.
- Searched on demand through the `/recall` command, or by hand:
  `node .repo/claude-mem/run.mjs recall --text "…"`.
- Recalled at session start by the `memory-sync` hook
  (`scripts/hooks/memory-sync.ps1`, `scripts/hooks/memory-sync.sh`,
  `scripts/hooks/run-hook.mjs memory-sync`).
- The store is pruned to the newest 500 episodes.
- Never store API keys, tokens, or secrets here: credentials are scrubbed at
  write time.

See `.agents/skills/automation/claude-mem/SKILL.md` for usage.
