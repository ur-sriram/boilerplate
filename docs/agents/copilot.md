# GitHub Copilot Setup

Copilot reads repository-wide instructions from `.github/copilot-instructions.md`
and prompt files from `.github/prompts/`.

## 1. Entry Points

| What | Where |
|---|---|
| Instructions | `.github/copilot-instructions.md` (plus `AGENTS.md`, which Copilot also supports) |
| Prompt files | `.github/prompts/*.prompt.md` (10 commands, distributed from `.agents/commands/`) |
| Skills | Copilot reads `.github/skills/`, `.claude/skills/` and `.agents/skills/` |
| MCP servers | `.mcp.json` (Copilot CLI) — `graphify` on by default |
| Hooks | Not available for Copilot IDE sessions; the guardrail is prompt-level |

## 2. Prompt Files

Prompt files must use the `.prompt.md` extension and live in
`.github/prompts/`. Enable them in the workspace settings:

```json
// .vscode/settings.json
{ "chat.promptFiles": true }
```

That file is provided in this repository.

## 3. Verification

```bash
python3 scripts/verify-adapters.py   # confirms the 8 prompt files exist
```
