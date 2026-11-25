# Qoder & Qoder CLI Setup Guide

This guide details configuration, rules wiring, directory junctions, and lifecycle hooks for Qoder and Qoder CLI.

## 1. Overview & Project Scoping

Qoder reads local project settings from `.qoder/settings.json`. All operational rules, skill definitions, and MCP configurations are maintained strictly within the project boundary. No global modifications to `~/.qoder` or system registries are made.

## 2. Configuration (`.qoder/settings.json`)

```json
{
  "rules": [
    "AGENTS.md",
    ".agents/rules/core-invariants.md"
  ],
  "skills": {
    "directory": ".qoder/skills"
  },
  "mcp": {
    "graphify": {
      "command": "uvx",
      "args": [
        "--from",
        "graphifyy",
        "graphify-mcp"
      ]
    }
  },
  "hooks": {
    "PreToolUse": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/protect-config.ps1",
    "SessionStart": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/session-start.ps1"
  }
}
```

## 3. Rules Wiring & Progressive Disclosure

- **Layer 1 Core Index**: `AGENTS.md` is loaded as the primary rule, ensuring the agent adheres to non-negotiable project boundaries and Karpathy minimal-change guidelines.
- **Layer 2 Invariants**: `.agents/rules/core-invariants.md` provides explicit operational constraints regarding worktree isolation and surgical edits.
- Additional domain rules (`planning-standards.md`, `code-quality.md`, `ui-standards.md`) are loaded on demand.

## 4. Skills Linking via NTFS Directory Junctions

Qoder looks for skills in `.qoder/skills/`. To maintain a single canonical source of truth in `.agents/skills/`:

- **Windows**: `bootstrap.cmd` creates an NTFS directory junction:
  ```cmd
  cmd.exe /c mklink /J ".qoder\skills" ".agents\skills"
  ```
  This creates a zero-overhead, zero-elevation directory pointer.
- **POSIX**: `scripts/bootstrap.sh` creates a relative symlink:
  ```bash
  ln -sfn ../.agents/skills .qoder/skills
  ```

## 5. Hook Guardrails

Qoder invokes `scripts/hooks/protect-config.ps1` before executing tools to prevent accidental writes outside the repository root, and runs `scripts/hooks/session-start.ps1` on session launch.

## 6. Verification

Run the unified health check:
```cmd
verify-all.cmd
```
