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

All agents must utilize `Graphify` (`Graphify-Labs/graphify` / `codebase-memory-mcp`) to inspect and navigate repository topology deterministically:

### Priority Order for Code Discovery
1. `search_graph`: Find functions, classes, interfaces, and routes by regex or symbol name.
2. `trace_path`: Trace caller hierarchy (inbound) or dependency call chains (outbound).
3. `get_code_snippet`: Retrieve exact source blocks for qualified symbols without reading entire monolithic files.
4. `query_graph`: Execute Cypher AST queries for complex architectural patterns.
5. `get_architecture`: Generate high-level system summaries and module relationships.

### Fallback to Regex / Grep
Only fall back to grep when:
- Searching for raw string literals, error log messages, or configuration values.
- Inspecting non-code configuration files (`.json`, `.yaml`, `.toml`, `.env.example`).
- Graphify MCP tools return insufficient results for an unindexed asset.

---

## 3. Related Standards & Skills
- [Core Invariants](core-invariants.md): Scoping and read-only boundaries.
- [MCP CodeMode](mcp-codemode.md): Token burn prevention.
- [Planning Standards](planning-standards.md): Recording discoveries in `.planning/findings.md`.
