# Codebase Exploration & Knowledge Graph Discovery

> **Layer 2 Modular Rule** | Scope: All codebase research, architecture discovery, and symbol lookup

This document defines the mandatory exploration protocol for agents operating in this repository.

---

## 1. Zero Guessing & No Blind Grepping

Agents must NOT:
- Guess symbol definitions, import paths, or architectural relationships.
- Run slow, naive whole-repository grep or recursive string searches across millions of characters.
- Hallucinate file locations or module boundaries.

---

## 2. Mandatory Graphify AST Knowledge Graph Protocol

All agents must utilize `Graphify` (`Graphify-Labs/graphify`, installed as the
`graphifyy[mcp]` package) to inspect and navigate repository topology
deterministically.

> **Tool names below were verified against the running server.** An earlier
> revision of this rule listed `search_graph`, `trace_path`, `get_code_snippet`
> and `get_architecture`. None of those tools exist in the Graphify MCP
> server - they belong to a different project (`DeusData/codebase-memory-mcp`).
> Calling them was guaranteed to fail. The list below is what the server
> actually exposes; re-verify it with `python3 scripts/verify-mcp-servers.py`
> after any Graphify upgrade.

### Priority Order for Code Discovery
1. `query_graph`: Search the knowledge graph (BFS or DFS) for symbols, concepts and relationships. This is the primary discovery tool.
2. `get_node`: Get full details for one node, by label or by ID.
3. `get_neighbors`: List a node's direct neighbours, with the connecting edges.
4. `shortest_path`: Find the shortest path between two concepts (`undirected=true` ignores stored edge direction).
5. `get_section`: Return the text of a Markdown section (heading node plus its subsections) or a whole Markdown page, straight from the source file.
6. `god_nodes`: Return the most connected nodes - the core abstractions of the graph.
7. `graph_stats`: Node count, edge count, community count and confidence breakdown.

### Pull Request Triage
`list_prs`, `get_pr_impact` and `triage_prs` report which knowledge-graph
communities a pull request touches. Use `triage_prs` when asked what to review
or what is ready to merge; use `get_pr_impact` to assess merge risk or
overlap with work in progress.

### Fallback to Regex / Grep
Only fall back to grep when:
- Searching for raw string literals, error log messages, or configuration values.
- Inspecting non-code configuration files (`.json`, `.yaml`, `.toml`, `.env.example`).
- Graphify MCP tools return insufficient results for an unindexed asset - for example a file added since the graph was last built.

---

## 3. Related Standards & Skills
- [Core Invariants](core-invariants.md): Scoping and read-only boundaries.
- [MCP CodeMode](mcp-codemode.md): Token burn prevention.
- [Planning Standards](planning-standards.md): Recording discoveries in `.planning/findings.md`.
