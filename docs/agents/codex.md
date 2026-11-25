# Codex CLI Setup Guide

This guide details configuration, zero-elevation NTFS directory junctions, native hooks, and rules discovery for Codex CLI in this repository.

## 1. Overview & Project Scoping

Codex CLI respects project-level scoping natively when launched inside the repository. It reads configuration directly from `.codex/config.toml` and discovers project invariants from `AGENTS.md`. No global modifications to `~/.codex` or host directories are performed.

## 2. Configuration (`.codex/config.toml`)

```toml
# Codex CLI Project Configuration
rules_file = "AGENTS.md"

[project]
name = "boilerplate"
skills_directory = ".codex/skills"

[mcp_servers.graphify]
command = "uvx"
args = ["--from", "graphifyy", "graphify-mcp"]

[hooks]
pre_tool_use = "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/protect-config.ps1"
post_tool_use = "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/rtk-filter.ps1"
session_start = "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/session-start.ps1"
```

## 3. Single Canonical Skill Store & Directory Junctions

Codex discovers project skills from `.codex/skills`. Rather than copying skills and causing duplication drift, this boilerplate uses native filesystem links:

- **Windows**: The bootstrap script (`scripts/bootstrap.ps1` or `bootstrap.cmd`) creates an **NTFS Directory Junction** (`mklink /J`):
  ```cmd
  cmd.exe /c mklink /J ".codex\skills" ".agents\skills"
  ```
  *Crucial note*: NTFS directory junctions require **zero elevation** and **zero Developer Mode** on all Windows versions.
- **POSIX (Linux / macOS)**: `scripts/bootstrap.sh` creates a relative symbolic link:
  ```bash
  ln -sfn ../.agents/skills .codex/skills
  ```

This guarantees Codex accesses the identical canonical skills maintained in `.agents/skills/`.

## 4. Lifecycle Hooks Integration

Codex CLI invokes executable scripts from `scripts/hooks/`:

- `pre_tool_use`: Calls `protect-config.ps1` (or `protect-config.sh` on POSIX) to abort any tool execution targeting paths outside the repository.
- `post_tool_use`: Calls `rtk-filter.ps1` (or `rtk-filter.sh` on POSIX) to compress terminal output if `rtk` is available.
- `session_start`: Calls `session-start.ps1` to verify the runtime environment.

## 5. Verification

To verify Codex configuration and skill accessibility:

```cmd
verify-all.cmd
```
