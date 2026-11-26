# Automation, Lifecycle Hooks & Verification Suite

> **Layer 2 Modular Rule** | Trigger: Verification runs, hook execution, CI/CD, script authoring, MCP switching

This document specifies the architecture, lifecycle hooks, dynamic profile switchers, and automated verification suites that safeguard repository integrity.

---

## 1. Standalone Executable Lifecycle Hooks

All lifecycle hooks reside in [`scripts/hooks/`](../../scripts/hooks/) and are implemented as standalone, non-crashing scripts with native dual-platform support (`.ps1` for Windows PowerShell and `.sh` for POSIX environments).

```
scripts/hooks/
├── run-hook.mjs              ──▶ Cross-platform dispatcher (Node): one command string for every OS
├── protect-config.ps1 / .sh  ──▶ PreToolUse: Intercepts & blocks out-of-scope filesystem writes
├── rtk-filter.ps1 / .sh      ──▶ PostToolUse: Compresses terminal outputs via rtk (60-90% savings)
└── session-start.ps1 / .sh   ──▶ SessionStart: Validates repository prerequisites and invariants
```

**Use `run-hook.mjs` when wiring hooks into an agent.** Every adapter except
Antigravity used to invoke `powershell -File ...ps1`, so on Linux/macOS — the
platform this repository's own README targets — no guardrail ran at all.
`run-hook.mjs` implements the same contract in Node.js and is referenced by
Claude Code, Codex, Qoder and Goose. Antigravity keeps its `.ps1`/`.sh` pair
because it supports a POSIX-specific command field.

### Hook Contract & Operational Behavior

| Hook Script | Lifecycle Event | Input | Logic & Exit Behavior |
|---|---|---|---|
| `protect-config.{ps1,sh}` | PreToolUse | Tool invocation parameters (`target_path`) | Validates `target_path` against project root. Blocks access to `%USERPROFILE%`, `%APPDATA%`, `~/.config`, `~/.gemini`, `~/.claude`.<br>**Exit 0**: Allowed.<br>**Exit 1**: Access denied with `[GUARDRAIL]` error. |
| `rtk-filter.{ps1,sh}` | PostToolUse | Raw stdout / stderr stream from terminal commands | Probes for `rtk` binary in `PATH`. If present, applies token compression (60–90% reduction). If absent, passes raw output through unmodified.<br>**Exit 0**: Guaranteed non-crashing passthrough. |
| `session-start.{ps1,sh}` | SessionStart | None | Asserts Git cleanliness, verifies `.env` presence/safety, checks runtime tools, prints statusline summary.<br>**Exit 0**: Ready. |

---

## 2. Dynamic MCP Profile Management

To prevent context bloat from always-loaded MCP tool schemas, agents switch tool profiles dynamically via [`scripts/mcp-profile.ps1`](../../scripts/mcp-profile.ps1) and `scripts/mcp-profile.sh`:

```powershell
# POSIX
./scripts/mcp-profile.sh <core|ui|compression|all>
./scripts/mcp-profile.sh --status

# Windows PowerShell
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 <core|ui|compression|all>
```

The switcher has a **single implementation** (`scripts/mcp-profile.py`) with
thin `.sh`/`.ps1` wrappers, and it updates **all nine** adapter MCP configs
(`.mcp.json`, `.agents/mcp.json`, `.cursor/mcp.json`, `opencode.json`,
`.antigravity/mcp_config.json`, `.qoder/settings.json`, `.kimi-code/mcp.json`,
`.goose/config.yaml`, `.codex/config.toml`). The previous inline scripts only
updated two of them, so the profiles silently disagreed.

| Profile Name | Active MCP Servers | Approximate Context Overhead | Primary Use Case |
|---|---|---|---|
| `core` *(Default)* | `graphify` (AST codebase memory) | **<= 350 tokens** | Daily coding, bug fixes, refactoring, TDD cycles. |
| `ui` | `graphify` + `ui-registry` (12 registries) | **~750 tokens** | UI component discovery, design audits, frontend work. |
| `compression` | `graphify` + `headroom` (context compressor) | **~650 tokens** | Large file refactoring, deep stack trace analysis. |
| `all` | `graphify` + `ui-registry` + `headroom` | **~1,050 tokens** | Complex multi-domain tasks requiring full ecosystem. |

---

## 2.1 Project-Level Isolation

Every MCP server in every adapter config pins its package caches inside the
project:

```json
"env": {
  "UV_CACHE_DIR": ".cache/uv",
  "UV_DATA_DIR": ".cache/uv-data",
  "UV_TOOL_DIR": ".cache/uv-tools",
  "XDG_CACHE_HOME": ".cache",
  "XDG_DATA_HOME": ".cache/xdg-data",
  "npm_config_cache": ".cache/npm"
}
```

The project `.npmrc` does the same for `npm install` (`cache=.cache/npm`).
`scripts/verify-adapters.py` fails the build if any adapter drops these keys,
so "zero global writes" cannot silently regress.

## 3. Programmatic Verification Suite

Quality and boundary enforcement are verified programmatically from scratch without third-party frameworks. The master test suite is invoked via [`verify-all.cmd`](../../verify-all.cmd), `scripts/verify-all.ps1` or `scripts/verify-all.sh`, and runs **nine** suites:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        verify-all.{cmd,ps1,sh}                         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ executes sequentially
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  verify-tools    │       │  verify-scripts  │       │  verify-links.py │
│ (Runtimes & MCP) │       │ (AST syntax check│       │ (Markdown links  │
└──────────────────┘       └──────────────────┘       │  & anchor slugs) │
                                                      └────────┬─────────┘
                                                               │
                                                               ▼
                                                      ┌──────────────────┐
                                                      │  test-bootstrap  │
                                                      │ (Sandbox test;   │
                                                      │  0 global writes)│
                                                      └──────────────────┘
```

1. **`verify-tools.{ps1,sh}`**: Asserts availability of Git, Node.js, Python, PowerShell, and tests executable resolution for configured MCP tools.
2. **`verify-scripts.{ps1,sh}`**: Performs AST parsing and syntax validation of all `.ps1`, `.sh`, and `.py` files in `scripts/`, `scripts/hooks/`, and `.specify/`, plus hook dry-runs (the guardrail must ALLOW an in-scope target and BLOCK an out-of-scope one).
3. **`verify-links.py`**: Multi-stage code-block aware parser validating that 100% of internal Markdown links, relative paths, and GitHub anchor slugs resolve cleanly.
4. **`test-bootstrap.{ps1,sh}`**: Clones repository into an isolated sandbox temp directory, runs the bootstrap sequence, and programmatically verifies:
   - Zero files created or modified outside the sandbox.
   - All configuration files parse cleanly.
   - `AGENTS.md` is present and valid as the universal core index.
   - 100% of skills in `.agents/skills/` are linked in rule files.
   - Additional hooks (`session-catchup.py`, `memory-sync.{ps1,sh}`), `claude-mem`, and `ponytail` / `headroom` / `rtk` integrations are validated.

---

## 4. Headless Browser Automation

For tasks requiring web browser interactions, DOM verification, or visual web testing, agents must follow the [`browser-harness`](../skills/automation/browser-harness/SKILL.md) skill:
- Script-driven CDP browser control connecting to local Chrome.
- Incurs **0 always-on tokens** (unlike heavyweight Playwright MCP servers).
- Operates in the background without stealing desktop window focus.

---

## 5. Related Standards & Skills

- [Core Invariants](core-invariants.md): Operational boundaries and project scoping.
- [Code Quality](code-quality.md): TDD and verification before completion.
- [Planning Standards](planning-standards.md): Task breakdown and Ralph loop.
- [Skills Index](skills-index.md): Complete wiring map for all integrated skills.
- Integrated Skills:
  - [`browser-harness`](../skills/automation/browser-harness/SKILL.md)
  - [`diagnosing-superpowers`](../skills/superpowers/diagnosing-superpowers/SKILL.md)
  - [`writing-skills`](../skills/superpowers/writing-skills/SKILL.md)
