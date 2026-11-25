# Model Context Protocol (MCP) Server Architecture & Profile Management

This document details the project-level stdio MCP server architecture, profile switcher commands, token consumption budgets, and tool schemas.

## 1. Overview & Dynamic Profiling

MCP servers provide autonomous coding agents with deterministic capabilities (AST graph exploration, component discovery, and payload compression). However, exposing multiple MCP servers unconditionally injects hundreds of tool definition tokens into every turn, causing severe context bloat.

To solve this, the boilerplate implements **Dynamic MCP Profiles**:

```
MCP Profile Comparison:
┌─────────────────┬────────────────────────────────────────────┬──────────────────┐
│ Profile         │ Active MCP Servers                         │ Baseline Overhead│
├─────────────────┼────────────────────────────────────────────┼──────────────────┤
│ core (default)  │ graphify                                   │ <= 350 tokens    │
│ ui              │ graphify + ui-registry                     │ ~750 tokens      │
│ compression     │ graphify + headroom                        │ ~650 tokens      │
│ all             │ graphify + ui-registry + headroom          │ ~1,050 tokens    │
└─────────────────┴────────────────────────────────────────────┴──────────────────┘
```

---

## 2. Server Specifications

### A. `graphify` (Core Profile — Enabled by Default)
- **Source**: `Graphify-Labs/graphify`
- **Installation/Execution**: `uvx --from graphifyy graphify-mcp`
- **Type**: Local stdio
- **Capabilities**:
  - `search_graph`: Find functions, classes, routes, and variables by regex pattern.
  - `trace_path`: Trace caller/callee trees across dependencies.
  - `get_code_snippet`: Retrieve specific function/class source without reading entire files.
  - `query_graph`: Execute Cypher queries on the repository AST knowledge graph.
  - `get_architecture`: Produce high-level architectural overview.
- **Overhead**: ~350 tokens.

### B. `ui-registry` (UI Profile — Activated On-Demand)
- **Source**: `mrityunjay-tiwari/ui-registry-mcp`
- **Installation/Execution**: `npx -y ui-registry-mcp@0.7.1`
- **Type**: Local stdio
- **Capabilities**:
  - `list_registries`: List available component registries (shadcn, magicui, aceternity, etc.).
  - `search_components`: Search components across 12 registries.
  - `get_component`: Retrieve component implementation code and CLI installation commands.
  - `compare_components`: Compare implementations between registries.
  - `check_consistency`: Audit component styling and token consistency.
- **Overhead**: ~400 tokens additional (~750 total).

### C. `headroom` (Compression Profile — Activated On-Demand)
- **Source**: `headroomlabs-ai/headroom`
- **Installation/Execution**: `uvx --from "headroom-ai[mcp]" headroom mcp serve`
- **Type**: Local stdio
- **Capabilities**:
  - Dynamic token compression for large tool payloads, diffs, and file reads (20% – 70% savings).
- **Overhead**: ~300 tokens additional (~650 total).

---

## 3. Profile Switching Commands

Switching profiles updates `opencode.json` and `.antigravity/mcp_config.json` immediately:

### Windows (PowerShell)
```powershell
# Activate Core profile (default, <= 350 tokens)
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile core

# Activate UI profile for frontend tasks (~750 tokens)
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile ui

# Activate Compression profile (~650 tokens)
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile compression

# Activate All servers (~1,050 tokens)
powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile all
```

### Linux / macOS (Bash)
```bash
./scripts/mcp-profile.sh core
./scripts/mcp-profile.sh ui
./scripts/mcp-profile.sh compression
./scripts/mcp-profile.sh all
```

---

## 4. Universal Manifests & shadcn Integration

- **`.mcp.json`**: Universal project manifest supported by Cursor, Claude Desktop, and Freebuff.
- **`.agents/mcp.json`**: Portable schema specifying profile memberships for agent harnesses.
- **`components.json`**: shadcn CLI configuration referencing local component directories (`src/components/ui`) and registries.
