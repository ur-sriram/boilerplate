# Freebuff Setup & Operational Guide

This guide details configuration, trust gate workarounds, behavioral rule enforcement, and MCP discovery for Freebuff in this repository.

## 1. Overview & Project Scoping

Freebuff automatically discovers project rules from `AGENTS.md` at repository root and reads portable MCP definitions from `.agents/mcp.json` (or root `.mcp.json`). It discovers skills directly from `.agents/skills/`.

## 2. Trust Gate Workaround (Named Exception)

### Problem
Freebuff by default presents an interactive confirmation dialog when accessing `.agents/` or custom agent configuration directories, which blocks non-interactive CI/CD runs, test execution scripts, and autonomous subagent execution.

### Solution
Set the environment variable:
```bash
# Windows Command Prompt:
set CODEBUFF_TRUST_AGENT_DIRS=1

# Windows PowerShell:
$env:CODEBUFF_TRUST_AGENT_DIRS = "1"

# POSIX (Linux / macOS):
export CODEBUFF_TRUST_AGENT_DIRS=1
```
This is cataloged as a named exception in `THIRD_PARTY.md` and included in `.env.example`.

## 3. Hook Adaptation: Behavioral Rules Translation

Freebuff does not possess a native lifecycle shell hook system (such as PreToolUse shell command interception). To ensure equivalent security and quality guarantees:

1. **Scoping Guardrail**: Translated into an explicit prompt rule in `AGENTS.md` and `.agents/rules/core-invariants.md`:
   - *"Strict Project Scoping: NEVER modify files outside c:\sriram\boilerplate. Writes to %USERPROFILE%, %APPDATA%, ~/.config, ~/.gemini, or ~/.claude are forbidden."*
2. **Terminal Output Compression**: Freebuff uses native token management; the `rtk` compressor is bypassed in favor of direct prompt-level concise output guidelines.
3. **Session Start Verification**: Freebuff agents are instructed via `AGENTS.md` to run `verify-all.cmd` (or `./scripts/verify-all.sh`) upon first being initialized in a repository.

## 4. MCP Server Discovery (`.agents/mcp.json`)

Freebuff reads `.agents/mcp.json` or `.mcp.json` to discover project tools:

- `graphify`: Available for AST exploration and symbol resolution.
- `ui-registry`: Available for shadcn component discovery when UI profile is active.
- `headroom`: Available for payload compression.

## 5. Verification

Verify Freebuff setup and project health:
```cmd
verify-all.cmd
```
