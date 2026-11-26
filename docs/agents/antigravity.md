# Antigravity IDE & CLI Setup Guide

This guide details configuration, native lifecycle hooks, MCP mappings, and headless CLI operation for the Antigravity development environment.

## 1. Overview & Project Scoping

Antigravity operates with zero global configuration in `~/.gemini`. All rules discovery, MCP server definitions, and lifecycle guardrails are contained within the repository:

- Main settings: `.antigravity/settings.json`
- Native MCP mappings: `.antigravity/mcp_config.json`
- Native lifecycle hooks: `.antigravity/hooks.json`
- Core rules: `AGENTS.md` and `.agents/rules/*.md`
- Skills store: `.agents/skills/`

## 2. Settings Configuration (`.antigravity/settings.json`)

```json
{
  "rules": {
    "core": "AGENTS.md",
    "directory": ".agents/rules",
    "discovery": "glob"
  },
  "skills": {
    "directory": ".agents/skills"
  },
  "context": {
    "max_core_tokens": 1000,
    "progressive_disclosure": true,
    "mcp_profile": "core"
  },
  "security": {
    "strict_project_scoping": true,
    "allowed_root": "."
  }
}
```

The settings ensure that:
1. `AGENTS.md` is loaded as the hyper-dense core invariant index (Layer 1).
2. Domain rules in `.agents/rules/` are loaded on demand via glob patterns (Layer 2).
3. Skills in `.agents/skills/` are executed JIT when relevant tasks arise (Layer 3).

## 3. Native Lifecycle Hooks (`.antigravity/hooks.json`)

Antigravity executes cross-platform lifecycle hooks defined in `.antigravity/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": {
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/protect-config.ps1",
      "posix_command": "sh ./scripts/hooks/protect-config.sh",
      "timeout_ms": 3000,
      "on_failure": "block"
    },
    "PostToolUse": {
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/rtk-filter.ps1",
      "posix_command": "sh ./scripts/hooks/rtk-filter.sh",
      "timeout_ms": 5000,
      "on_failure": "continue"
    },
    "SessionStart": {
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/session-start.ps1",
      "posix_command": "sh ./scripts/hooks/session-start.sh",
      "timeout_ms": 10000,
      "on_failure": "warn"
    },
    "MemorySync": {
      "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/hooks/memory-sync.ps1",
      "posix_command": "sh ./scripts/hooks/memory-sync.sh",
      "timeout_ms": 10000,
      "on_failure": "warn"
    }
  }
}
```

- **PreToolUse**: Validates target paths before write operations. Blocks any attempt to access or modify paths outside the repository.
- **PostToolUse**: Pipes verbose terminal output through `rtk filter` to reduce token overhead, gracefully echoing raw logs if `rtk` is missing.
- **SessionStart**: Audits local prerequisites (Git, Node, Python, PowerShell/Bash) and prints an environment status summary.
- **MemorySync**: Recalls the project's episodic memory (claude-mem) so the session starts with previously recorded decisions.

## 4. Native Stdio MCP Mappings (`.antigravity/mcp_config.json`)

By default, the Core profile is active: `graphify` is enabled to provide AST knowledge graph search (`query_graph`, `get_node`, `get_neighbors`, `shortest_path`, `get_section`, `god_nodes`, `graph_stats`). `ui-registry` and `headroom` are disabled by default:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "uvx",
      "args": ["--from", "graphifyy[mcp]", "graphify-mcp"],
      "disabled": false,
      "autoApprove": ["query_graph", "get_node", "get_neighbors", "shortest_path", "get_section", "god_nodes", "graph_stats"]
    },
    "ui-registry": {
      "command": "npx",
      "args": ["-y", "ui-registry-mcp@0.7.1"],
      "disabled": true,
      "autoApprove": ["list_registries", "list_components", "search_components", "get_component", "compare_components", "check_consistency"]
    },
    "headroom": {
      "command": "uvx",
      "args": ["--from", "headroom-ai[mcp]", "headroom", "mcp", "serve"],
      "disabled": true,
      "autoApprove": []
    }
  }
}
```

## 5. Antigravity Headless CLI (`agy`)

Antigravity CLI functions 100% headless in terminal environments using the identical project configurations. No separate global flags are required.

To test hooks and configuration:
```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/hooks/session-start.ps1
```
