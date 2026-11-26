---
name: graphify
description: Deterministic AST knowledge graph exploration using Graphify-Labs/graphify (graphifyy[mcp]) instead of naive whole-repo grepping.
---

# Graphify AST Exploration

Use the `graphify` MCP server before falling back to grep/glob.

**Verified tool list** (from `python3 scripts/verify-mcp-servers.py graphify`).
An earlier revision of this skill listed `search_graph`, `trace_path`,
`get_code_snippet` and `get_architecture` - none of those exist in the
Graphify MCP server, so every call built on them was guaranteed to fail.

## Priority Order
1. `query_graph` - search the knowledge graph (BFS/DFS) for symbols and relationships
2. `get_node` - full details for one node, by label or ID
3. `get_neighbors` - direct neighbours of a node, with edge details
4. `shortest_path` - shortest path between two concepts
5. `get_section` - read a Markdown section or page from the source file
6. `god_nodes` - the most connected nodes (core abstractions)
7. `graph_stats` - node/edge/community counts and confidence breakdown

## Pull Request Triage
`list_prs`, `get_pr_impact`, `triage_prs` - which graph communities a PR
touches, for review priority, merge order and conflict risk.

## Fallback
Use grep only for string literals, log messages, config values, or files that
are not in the graph yet.
