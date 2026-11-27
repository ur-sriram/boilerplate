# OpenCode Setup & Operational Guide

This guide details project-level configuration, zero-build ESM plugins, MCP integration, and slash commands for OpenCode in this repository.

## 1. Overview & Project Scoping

OpenCode is fully configured as a primary agent within this repository without modifying global files in `~/.config/opencode` or `$HOME`. All configuration files, plugins, and custom slash commands reside strictly within the project boundary:

- Primary configuration: `opencode.json`
- Zero-build ESM plugins: `.opencode/plugins/`
- Custom slash commands: `.opencode/commands/`
- Core rules: `AGENTS.md` (read automatically on launch)

## 2. Configuration (`opencode.json`)

The primary configuration declares local stdio MCP servers and instruction paths:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "mcp": {
    "graphify": {
      "type": "local",
      "command": ["uvx", "--from", "graphifyy[mcp]", "graphify-mcp"],
      "enabled": true,
      "environment": {
        "UV_CACHE_DIR": ".cache/uv",
        "UV_DATA_DIR": ".cache/uv-data",
        "UV_TOOL_DIR": ".cache/uv-tools",
        "XDG_CACHE_HOME": ".cache",
        "XDG_DATA_HOME": ".cache/xdg-data",
        "npm_config_cache": ".cache/npm"
      }
    },
    "ui-registry": {
      "type": "local",
      "command": ["npx", "-y", "ui-registry-mcp@0.7.1"],
      "enabled": false,
      "environment": { "...": "same project-local cache paths" }
    },
    "headroom": {
      "type": "local",
      "command": ["uvx", "--from", "headroom-ai[mcp]", "headroom", "mcp", "serve"],
      "enabled": false,
      "environment": { "...": "same project-local cache paths" }
    }
  }
}
```

> **`command` is an array here, and the env block is called `environment`.**
> That is OpenCode's own schema (`McpLocalConfig` in
> `https://opencode.ai/config.json`). The Claude Code / Cursor shape
> (`"command": "uvx"` plus a separate `"args"` array and an `"env"` block) is
> **silently discarded** by OpenCode - it logs
> `Ignoring MCP config entry without type` and the server never starts. An
> earlier revision of this repository used the wrong shape here, so all three
> MCP servers were dead in OpenCode while looking correct in the file.
> `scripts/verify-adapters.py` now parses each config against its vendor's
> schema and fails on a shape mismatch.

By default, the `core` MCP profile is active: `graphify` is enabled (~350 tokens overhead), while `ui-registry` and `headroom` are disabled until dynamically activated.

## 3. Zero-Build Vanilla ESM Plugins

OpenCode executes vanilla ECMAScript modules directly via Node.js without requiring transpilation or npm build steps. Five plugins live in `.opencode/plugins/`:

1. **Config Protection Plugin (`.opencode/plugins/config-protection.js`)**:
   - Intercepts tool calls before execution via OpenCode's `tool.execute.before` hook.
   - Asserts that the target path of any **mutating** tool (write, edit, patch) resolves inside the project directory.
   - Compares *physical* paths, so a symlinked checkout (for example `/workspace` -> a mounted volume) does not break every legitimate write.
   - Throws a descriptive security error if an agent attempts an out-of-scope write.

2. **Headroom Guard Plugin (`.opencode/plugins/headroom-guard.js`)**:
   - Detects repository-wide grep / ripgrep commands via `tool.execute.before`.
   - **Advises, it does not block.** It prints a one-line reminder pointing at the Graphify MCP server. An earlier revision blocked these searches, which turned out to be wrong in both directions (it blocked single-file greps while allowing `grep -r .`). Blocking legitimate searches in an autonomous loop is worse than nudging.

3. **File-Size Guard Plugin (`.opencode/plugins/file-size-guard.js`)**:
   - Enforces the 400 effective-line ceiling from `.agents/rules/code-quality.md` at the moment of the edit.
   - Computes the size the file *would* have after the write, so a file that is already over the limit can still be repaired.

4. **RTK Interceptor Plugin (`.opencode/plugins/rtk-interceptor.js`)**:
   - Intercepts tool results after execution via `tool.execute.after` and pipes them through `rtk`.
   - If the `rtk` (Rust Token Killer) binary is installed in PATH, pipes output through `rtk filter` to compress verbose compiler or test logs by 60-90%. The compression itself is shared with the POSIX hook, the PowerShell hook and the cross-platform dispatcher (`scripts/hooks/rtk-filter.mjs`).
   - This is the adapter where the saving is real: the plugin replaces the tool result, so the model reads the compressed text rather than the raw output.
   - If `rtk` is not installed, passes the output through untouched. The binary is probed once and the result cached.

5. **Session Start Plugin (`.opencode/plugins/session-start.js`)**:
   - On a session event, prints the readiness summary: project root, resolved paths for `git`, `node`, `python3` and `sh`, whether `rtk` is present, and whether the canonical skills store exists.
   - Mirrors `scripts/hooks/session-start.sh`.

6. **Memory Sync Plugin (`.opencode/plugins/memory-sync.js`)**:
   - On a session event, recalls the project's episodic memory (claude-mem) and prints the stored episodes as session context.
   - Mirrors `scripts/hooks/memory-sync.sh`; invokes the same CLI, so the recalled episodes match the other adapters exactly.

## 4. Custom Slash Commands

OpenCode automatically discovers TOML command manifests located in `.opencode/commands/`:

- `/plan` (`.opencode/commands/plan.toml`): Directs the agent to formulate specifications using `.specify/` templates and decompose tasks using `.agents/skills/superpowers/writing-plans/SKILL.md`.
- `/test` (`.opencode/commands/test.toml`): Enforces test-driven development via `.agents/skills/superpowers/test-driven-development/SKILL.md`.
- `/review` (`.opencode/commands/review.toml`): Triggers 2-stage code review for correctness, security, and simplicity.
- `/simplify` (`.opencode/commands/simplify.toml`): Runs surgical simplification to eliminate unnecessary complexity per `.agents/skills/quality/code-simplification/SKILL.md`.

## 4.1 Plugin Contract

Plugins are **auto-discovered** from `.opencode/plugins/` - there is no
`plugins` key in `opencode.json`. (An earlier revision declared a
`"plugins"` array of file paths; OpenCode logs
`"plugins" kind=unsupported action="Omitted native setting that cannot be
represented in V1"` and ignores it.)

OpenCode loads every discovered file as a *path plugin*, and the loader
requires the module's **default export** to be an object carrying a
non-empty string `id` and a `server()` function:

```js
export default {
  id: 'boilerplate-config-protection',
  async server({ directory }) {
    return {
      'tool.execute.before': async (input, output) => { /* ... */ },
      'tool.execute.after': async (input, output) => { /* ... */ },
    };
  },
};
```

A plugin that exports only `export const server = ...`, or that omits `id`,
is rejected at load time:

```
failed to load plugin ... error="Path plugin ... must export id"
```

Every hook in that file then silently never fires. That was the state of all
five plugins in an earlier revision - the guardrails were dead code.

The plugins here also export a `setup(ctx)` function for the OpenCode V2 API.
V1 (the published `latest`) ignores `setup()` and uses `server()`; V2 uses
`setup()` and ignores `server()`. Both are implemented from the same guard
logic so the two paths cannot drift.

| Plugin | Hook | Purpose |
|---|---|---|
| `config-protection.js` | `tool.execute.before` | Blocks writes outside the project root |
| `headroom-guard.js` | `tool.execute.before` | Advises against whole-repository greps (enforces `.agents/rules/codebase-exploration.md`) |
| `file-size-guard.js` | `tool.execute.before` | Blocks writes that would push a file past the 400-line ceiling |
| `rtk-interceptor.js` | `tool.execute.after` | Compresses terminal output through `rtk` (60-90% saving, graceful passthrough) |
| `session-start.js` | `event` | Prints the session readiness summary |
| `memory-sync.js` | `event` | Recalls the project's episodic memory (claude-mem) |

## 5. Dynamic MCP Profile Management

To enable component discovery for frontend tasks or context compression for massive payloads:

```bash
# Linux / macOS
./scripts/mcp-profile.sh ui
./scripts/mcp-profile.sh core
./scripts/mcp-profile.sh --status
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 ui
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 core
```

## 6. Verification & Health Check

Run the repository verification suite to confirm the OpenCode configuration is valid:

```bash
bash scripts/verify-all.sh          # Linux / macOS
powershell -File ./scripts/verify-all.ps1   # Windows
```

Targeted checks:

```bash
python3 scripts/verify-adapters.py       # MCP shape + parity across all adapters
python3 scripts/verify-mcp-servers.py    # boot every MCP server for real
```

To see how OpenCode itself resolves the project config - and to confirm no
plugin fails to load - run:

```bash
opencode debug config
opencode run --print-logs --log-level DEBUG "say hi"
```

A healthy run contains no `failed to load plugin` and no
`Ignoring MCP config entry` lines.
