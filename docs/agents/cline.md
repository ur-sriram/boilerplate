# Cline / Roo Code Setup

Cline reads project rules from `.clinerules` and discovers skills from
`.cline/skills/`.

## 1. Entry Points

| What | Where |
|---|---|
| Rules | `.clinerules` (points at `AGENTS.md` and `.agents/rules/`) |
| Slash commands | `.cline/commands/*.md` (10 commands, distributed from `.agents/commands/`) |
| Skills | `.cline/skills` → junction to `.agents/skills` |
| MCP servers | Not configured by this repository — Cline reads MCP servers from its own settings; the canonical invocations are published in `.mcp.json` |
| Hooks | Not available in Cline's project config |

## 2. MCP (optional, manual)

Copy the three server blocks from `.mcp.json` into your Cline MCP settings to
get the same tool surface as the other adapters.
