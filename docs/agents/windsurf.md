# Windsurf Setup

Windsurf reads project rules from `.windsurfrules` and discovers skills from
`.windsurf/skills/`.

## 1. Entry Points

| What | Where |
|---|---|
| Rules | `.windsurfrules` (points at `AGENTS.md` and `.agents/rules/`) |
| Slash commands | `.windsurf/commands/*.md` (10 commands, distributed from `.agents/commands/`) |
| Skills | `.windsurf/skills` → junction to `.agents/skills` |
| MCP servers | Not configured by this repository — Windsurf reads MCP servers from its own global settings; the canonical invocations are published in `.mcp.json` so they can be copied verbatim |
| Hooks | Not available in Windsurf's project config |

## 2. MCP (optional, manual)

Copy the three server blocks from `.mcp.json` into your Windsurf MCP settings
to get the same tool surface as the other adapters.
