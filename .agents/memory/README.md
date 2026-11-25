# Episodic Memory Store (`.agents/memory/`)

Powered by the `thedotmack/claude-mem` architecture.

- Stores cross-session architectural decisions, user preferences, and error recoveries strictly within the repository boundary.
- Synced via `scripts/hooks/memory-sync.ps1` and `scripts/hooks/memory-sync.sh`.
- Never store API keys, tokens, or secrets here.
