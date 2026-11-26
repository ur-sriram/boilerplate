# Moonshot Kimi Code CLI Setup Guide

This guide details configuration, rules discovery, and boundary enforcement for Kimi Code CLI in this repository.

## 1. Overview & Project Scoping

Kimi Code CLI supports local project configuration via `.kimi/config.toml`. It automatically reads project rules from `AGENTS.md` and discovers skills from `.agents/skills/`.

**MCP servers are not read from `config.toml`.** Kimi Code CLI loads them from
`mcp.json` — project scope is `.kimi-code/mcp.json` (provided here), user
scope is `~/.kimi-code/mcp.json`. The project file is gated by workspace
trust: approve the prompt at startup.

## 2. Configuration (`.kimi/config.toml`)

```toml
# Moonshot Kimi Code CLI Configuration
# Standardized project configuration

[project]
name = "boilerplate"
rules_file = "AGENTS.md"
respect_gitignore = true

[skills]
directory = ".agents/skills"
```

### Key Parameters:
- `rules_file = "AGENTS.md"`: Directs Kimi to load the Layer 1 core index on startup, adhering to the $\le 1,000$ token core constraint and Karpathy guidelines.
- `respect_gitignore = true`: Instructs Kimi to respect all ignore patterns in `.gitignore` (which strictly mirrors `.aiignore`), preventing caches, binary assets, and temp fixtures from entering context.
- `directory = ".agents/skills"`: Points Kimi directly to the canonical skill repository.

## 3. Hook Adaptation: Prompt-Based Rules

Because Kimi CLI does not feature an arbitrary shell hook execution engine:
- Security scoping is enforced through the explicit invariant in `AGENTS.md` and `.agents/rules/core-invariants.md`.
- Output filtering is handled by Kimi's internal context management.
- Verification is performed manually or via agent prompt invocation of `verify-all.cmd`.

## 4. Verification

Run the verification suite:
```cmd
verify-all.cmd
```
