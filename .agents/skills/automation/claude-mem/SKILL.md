---
name: claude-mem
description: Persistent cross-session episodic memory using thedotmack/claude-mem architecture in .agents/memory/.
---

# Claude-Mem Episodic Memory

Stores and recalls architectural decisions, user preferences, and error recoveries across sessions in `.agents/memory/`.

## Usage
- Synced via `scripts/hooks/memory-sync.ps1` and `scripts/hooks/memory-sync.sh`.
- Never stores secrets or credentials; `.agents/memory/` is scoped strictly inside the repository.
