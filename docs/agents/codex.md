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

[[hooks.PreToolUse]]
matcher = "Write|Edit|MultiEdit"
hooks = [{ type = "command", command = "node ./scripts/hooks/run-hook.mjs protect-config" }]

[[hooks.PostToolUse]]
matcher = "Bash"
hooks = [{ type = "command", command = "node ./scripts/hooks/run-hook.mjs rtk-filter" }]

[[hooks.SessionStart]]
hooks = [{ type = "command", command = "node ./scripts/hooks/run-hook.mjs session-start" }]

[[hooks.SessionStart]]
hooks = [{ type = "command", command = "node ./scripts/hooks/run-hook.mjs memory-sync" }]
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

Codex expects `hooks.<Event>` to be an **array of matcher groups**, each with
its own `hooks` list of `{type = "command", command = "..."}` objects. Flat
string keys (the previous `pre_tool_use = "..."` form) match no documented
schema and never fired.

Every hook now calls the cross-platform Node dispatcher
`scripts/hooks/run-hook.mjs`, so the same command string works on Windows,
macOS and Linux:

- `PreToolUse`: `protect-config` aborts any tool execution targeting paths outside the repository (exit code 1).
- `PostToolUse`: `rtk-filter` compresses terminal output if `rtk` is available, otherwise passes it through untouched.
- `SessionStart`: `session-start` prints the runtime readiness summary;
  `memory-sync` recalls the project's episodic memory (claude-mem).

Codex also reads custom prompts from `.codex/prompts/` — the 8 slash commands
are distributed there from `.agents/commands/`.

## 5. Verification

To verify Codex configuration and skill accessibility:

```cmd
verify-all.cmd
```
