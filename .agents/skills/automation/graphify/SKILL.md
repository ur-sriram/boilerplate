---
name: graphify
description: Deterministic AST knowledge graph exploration using Graphify-Labs/graphify (codebase-memory-mcp) instead of naive whole-repo grepping.
---

# Graphify AST Exploration

Use `codebase-memory-mcp` / `graphify` tools (`search_graph`, `trace_path`, `get_code_snippet`, `query_graph`, `get_architecture`) before falling back to grep/glob.

## Priority Order
1. `search_graph` — find functions, classes, routes, variables by regex pattern
2. `trace_path` — trace callers (inbound) or callees (outbound)
3. `get_code_snippet` — read exact symbol source without loading whole files
4. `query_graph` — run Cypher AST queries for architectural patterns
5. `get_architecture` — high-level project summary
