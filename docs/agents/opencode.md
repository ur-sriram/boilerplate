# OpenCode Setup & Operational Guide

This guide details project-level configuration, zero-build ESM plugins, MCP integration, and slash commands for OpenCode in this repository.

## 1. Overview & Project Scoping

OpenCode is fully configured as a primary agent within this repository without modifying global files in `~/.config/opencode` or `$HOME`. All configuration files, plugins, and custom slash commands reside strictly within the project boundary:

- Primary configuration: `opencode.json`
- Zero-build ESM plugins: `.opencode/plugins/`
- Custom slash commands: `.opencode/commands/`
- Core rules: `AGENTS.md` (read automatically on launch)

## 2. Configuration (`opencode.json`)

The primary configuration declares local stdio MCP servers, active plugins, and instruction paths:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "mcp": {
    "graphify": {
      "type": "local",
      "command": "uvx",
      "args": ["--from", "graphifyy", "graphify-mcp"],
      "enabled": true
    },
    "ui-registry": {
      "type": "local",
      "command": "npx",
      "args": ["-y", "ui-registry-mcp@0.7.1"],
      "enabled": false
    },
    "headroom": {
      "type": "local",
      "command": "uvx",
      "args": ["--from", "headroom-ai[mcp]", "headroom", "mcp", "serve"],
      "enabled": false
    }
  },
  "plugins": {
    "config-protection": {
      "path": ".opencode/plugins/config-protection.js",
      "enabled": true
    },
    "rtk-interceptor": {
      "path": ".opencode/plugins/rtk-interceptor.js",
      "enabled": true
    }
  }
}
```

By default, the `core` MCP profile is active: `graphify` is enabled (~350 tokens overhead), while `ui-registry` and `headroom` are disabled until dynamically activated.

## 3. Zero-Build Vanilla ESM Plugins

OpenCode executes vanilla ECMAScript modules directly via Node.js without requiring transpilation or npm build steps:

1. **Config Protection Plugin (`.opencode/plugins/config-protection.js`)**:
   - Intercepts tool calls before execution via OpenCode's `tool.execute.before` hook.
   - Asserts that target paths resolve within the project directory.
   - Throws a descriptive security error if an agent attempts an out-of-scope write to `%USERPROFILE%`, `%APPDATA%`, or other host directories.

2. **RTK Interceptor Plugin (`.opencode/plugins/rtk-interceptor.js`)**:
   - Intercepts tool results after execution via `tool.execute.after` and pipes them through `rtk`.
   - If the `rtk` (Rust Token Killer) binary is installed in PATH, pipes output through `rtk filter` to compress verbose compiler or test logs by 60–90%.
   - If `rtk` is not installed, catches the condition immediately and returns raw stdout without crashing or disrupting the agent execution loop.

## 4. Custom Slash Commands

OpenCode automatically discovers TOML command manifests located in `.opencode/commands/`:

- `/plan` (`.opencode/commands/plan.toml`): Directs the agent to formulate specifications using `.specify/` templates and decompose tasks using `.agents/skills/superpowers/writing-plans/SKILL.md`.
- `/test` (`.opencode/commands/test.toml`): Enforces test-driven development via `.agents/skills/superpowers/test-driven-development/SKILL.md`.
- `/review` (`.opencode/commands/review.toml`): Triggers 2-stage code review for correctness, security, and simplicity.
- `/simplify` (`.opencode/commands/simplify.toml`): Runs surgical simplification to eliminate unnecessary complexity per `.agents/skills/quality/code-simplification/SKILL.md`.

## 4.1 Plugin Contract

`opencode.json` declares plugins as an **array of paths** (the documented
OpenCode format), and each plugin file in `.opencode/plugins/` exports a
`server()` function returning the hook object:

```js
export const server = async ({ directory }) => ({
  'tool.execute.before': async (input, output) => { /* ... */ },
  'tool.execute.after': async (input, output) => { /* ... */ },
});
export default { server };
```

| Plugin | Hook | Purpose |
|---|---|---|
| `config-protection.js` | `tool.execute.before` | Blocks writes outside the project root and sensitive global config paths |
| `headroom-guard.js` | `tool.execute.before` | Blocks whole-repository greps (enforces `.agents/rules/codebase-exploration.md`) |
| `ponytail-compactor.js` | `tool.execute.before` | Blocks edits that would push a file past the 400-line ceiling |
| `rtk-interceptor.js` | `tool.execute.after` | Compresses terminal output through `rtk` (60-90% saving, graceful passthrough) |
| `session-start.js` | `event` | Prints the session readiness summary |

## 5. Dynamic MCP Profile Management

To enable component discovery for frontend tasks or context compression for massive payloads:

```powershell
# Windows PowerShell
# POSIX
./scripts/mcp-profile.sh ui
./scripts/mcp-profile.sh core
./scripts/mcp-profile.sh --status

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 ui
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 core

# Linux / macOS
./scripts/mcp-profile.sh ui
./scripts/mcp-profile.sh core
```

## 6. Verification & Health Check

Run the repository verification suite to confirm OpenCode configuration validity:

```cmd
verify-all.cmd
```
