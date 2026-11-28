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
- **Installation/Execution**: `uvx --from "graphifyy[mcp]" graphify-mcp`
- **Type**: Local stdio
- **Capabilities** (verified against the running server):
  - `query_graph`: Search the knowledge graph (BFS or DFS) for symbols, concepts and relationships.
  - `get_node`: Get full details for one node, by label or by ID.
  - `get_neighbors`: List a node's direct neighbours, with the connecting edges.
  - `shortest_path`: Find the shortest path between two concepts.
  - `get_section`: Return the text of a Markdown section or a whole Markdown page from the source file.
  - `god_nodes`: The most connected nodes — the core abstractions of the graph.
  - `graph_stats`: Node count, edge count, community count and confidence breakdown.
  - `list_prs`, `get_pr_impact`, `triage_prs`: Which graph communities a pull request touches.
- **Overhead**: ~350 tokens.

> **Why the `[mcp]` extra matters**: the bare `graphifyy` package does not
> depend on the MCP SDK, so `uvx --from graphifyy graphify-mcp` dies with
> `ModuleNotFoundError: No module named 'mcp'`. Every earlier revision of
> this repository configured the server that way — in all nine adapters — so
> the core profile had **no working server at all**. The extra is what makes
> it boot.

> **A note on tool names**: an earlier revision of this document listed
> `search_graph`, `trace_path`, `get_code_snippet` and `get_architecture`.
> Those belong to a *different* project (`DeusData/codebase-memory-mcp`,
> whose current release fails its own checksum verification) and are not
> exposed by the Graphify server. The list above is what the server actually
> returns from `tools/list`.

### B. `ui-registry` (UI Profile — Activated On-Demand)
- **Source**: `mrityunjay-tiwari/ui-registry-mcp`
- **Installation/Execution**: `npx -y ui-registry-mcp@0.7.1`
- **Type**: Local stdio
- **Capabilities** (verified against the running server):
  - `list_registries`: List the component registries the server can pull from. The
    twelve it serves are ReUI, Kokonut UI, Kibo UI, Tailark, SmoothUI, Cult UI,
    useLayouts, Optics, Watermelon UI, beUI, AI Elements and Aceternity UI.
    The **default shadcn registry and Magic UI are not served by this server** —
    they are reached through the shadcn CLI (`npx shadcn@latest add @magicui/...`),
    which is why `components.json` declares them as named registries.
  - `list_components`: List the components available in a registry.
  - `search_components`: Search components across 12 registries.
  - `get_component`: Retrieve component implementation code and CLI installation commands.
  - `compare_components`: Compare implementations between registries.
  - `check_consistency`: Audit component styling and token consistency.
- **Overhead**: ~400 tokens additional (~750 total).

### C. `headroom` (Compression Profile — Activated On-Demand)
- **Source**: `headroomlabs-ai/headroom`
- **Installation/Execution**: `uvx --from "headroom-ai[mcp]" headroom mcp serve`
- **Type**: Local stdio
- **Capabilities** (verified against the running server):
  - `headroom_compress`: Compress large tool payloads, diffs and file reads (20% – 70% savings).
  - `headroom_retrieve`: Retrieve previously compressed content.
  - `headroom_stats`: Report compression effectiveness.
- **Overhead**: ~300 tokens additional (~650 total).

---

## 2.1 Verifying That The Servers Actually Boot

A configured MCP server is not a working MCP server. The Graphify entry above
was configured in all nine adapters for months while crashing on startup.

```bash
# Boot every canonical server, shake hands, and list its tools
python3 scripts/verify-mcp-servers.py

# Just one server, with a longer startup budget
python3 scripts/verify-mcp-servers.py graphify --timeout 300

# Show what would be launched
python3 scripts/verify-mcp-servers.py --list
```

The script launches each server with the project-local cache environment
(`UV_CACHE_DIR` and friends point inside `.cache/`), so a verification run
never writes to the user's home directory. It needs network access on the
first run, because `uvx` and `npx` download the packages.

---

## 3. Profile Switching Commands

Switching profiles updates **all nine** adapter MCP configs immediately:
`.mcp.json`, `.agents/mcp.json`, `.cursor/mcp.json`, `opencode.json`,
`.antigravity/mcp_config.json`, `.qoder/settings.json`, `.kimi-code/mcp.json`,
`.goose/config.yaml` and `.codex/config.toml`.

Each vendor marks "off" in its own way — `disabled` (Claude Code, Cursor,
Antigravity), `enabled` (OpenCode, Qoder, `.agents`), `deferred` (Kimi Code),
`enabled` inside `[mcp_servers.*]` (Codex) and `enabled` inside `extensions`
(Goose). The switcher writes the right key for each.

### Linux / macOS (Bash)
```bash
./scripts/mcp-profile.sh core
./scripts/mcp-profile.sh ui
./scripts/mcp-profile.sh compression
./scripts/mcp-profile.sh all
./scripts/mcp-profile.sh --status
```

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

---

## 4. Universal Manifests & shadcn Integration

- **`.mcp.json`**: Universal project manifest supported by Cursor, Claude Desktop, and Freebuff.
- **`.agents/mcp.json`**: Portable schema specifying profile memberships for agent harnesses.
- **`components.json`**: shadcn CLI configuration referencing local component directories (`src/components/ui`) and registries.
