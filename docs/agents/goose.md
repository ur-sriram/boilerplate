# Goose (Block) Setup Guide

This guide details configuration, pointer files, Open Plugins hooks, and MCP extensions for Goose in this repository.

## 1. Overview & Project Scoping

Goose reads project-level hints from `.goosehints` at the repository root and project-scoped configuration from `.goose/config.yaml`. No global modifications to `~/.goose` or host configurations are made.

## 2. Pointer File (`.goosehints`)

The root pointer file `.goosehints` directs Goose directly to the project invariants:

```markdown
# Goose Operational Hints
# Always inspect project-level invariants and rules first:
- Read AGENTS.md for core non-negotiable invariants and Karpathy guidelines.
- Skills reside in .agents/skills/.
- Use .agents/rules/ for task-specific guidance (planning-standards, code-quality, ui-standards).
- Never modify files outside this project directory.
```

## 3. Configuration (`.goose/config.yaml`)

Goose configures MCP extensions and project session parameters:

```yaml
version: 1.0.0
instructions: AGENTS.md
extensions:
  graphify:
    name: graphify
    cmd: uvx
    args:
      - "--from"
      - "graphifyy"
      - "graphify-mcp"
    enabled: true
    type: stdio
```

## 4. Open Plugins Lifecycle Hooks (`.goose/hooks.json`)

Goose implements lifecycle interception through the Open Plugins specification:

```json
{
  "hooks": [
    {
      "event": "PreToolUse",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/protect-config.ps1",
      "on_failure": "block"
    },
    {
      "event": "SessionStart",
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/session-start.ps1",
      "on_failure": "continue"
    }
  ]
}
```

- **PreToolUse**: Evaluates the tool target; terminates the call with exit code 1 if the target falls outside the project directory.
- **SessionStart**: Validates local prerequisites (Git, Node, Python, PowerShell/Bash).

## 5. Verification

Verify Goose project readiness:
```cmd
verify-all.cmd
```
