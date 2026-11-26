# Cloudflare CodeMode: MCP Token Burn Prevention

> **Layer 2 Modular Rule** | Scope: All agents utilizing Model Context Protocol (MCP) servers | Enforced across repository

This document establishes the strict operational guidelines for utilizing MCP tools without causing catastrophic token burn in model context windows, following the [Cloudflare Agents CodeMode Architecture](https://github.com/cloudflare/agents/blob/main/docs/codemode/index.md).

---

## 1. The Token Burn Problem

Exposing dozens of monolithic MCP tool schemas directly to LLM prompts introduces severe inefficiencies:
1. **Schema Bloat**: 20+ MCP tool schemas consume 5,000 to 15,000 tokens of system context on *every single turn*, drastically reducing effective context capacity and increasing latency.
2. **Chatty Roundtrips**: Making sequential JSON-RPC tool calls for data extraction, intermediate transformation, and filtering burns output tokens and multiplies network turnarounds.
3. **Payload Dumping**: Many MCP servers return massive JSON arrays containing hundreds of unneeded fields, flooding model memory.

---

## 2. The CodeMode Solution & Mandatory Rules

### Rule 1: Dynamic MCP Profiles (Default Minimal Context)
- Never enable all MCP servers globally at all times.
- Keep the default MCP profile locked to `core` (<= 350 tokens: the `graphify` server only).
- Activate domain MCP servers on-demand only when a task strictly requires them using `scripts/mcp-profile.{sh,ps1}`, which updates **all nine** adapter MCP configs at once:

  ```bash
  # POSIX - toggles only the UI registries when doing frontend work:
  ./scripts/mcp-profile.sh ui

  # Windows - same switcher, same effect:
  powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile ui

  # Inspect what is currently active, in every adapter:
  ./scripts/mcp-profile.sh --status
  ```

  Valid profiles: `core` (default), `ui`, `compression`, `all`.

  > There is no `filesystem` MCP server in this repository. An earlier
  > revision of this rule advertised the core profile as "graphify,
  > filesystem"; only `graphify` is configured.

### Rule 2: Programmatic Execution Over Serial Tool Calls
- When performing multi-step data lookups, querying databases, or searching registries, **write a compact script** (Node.js, TypeScript, or Python) to call the tool API/server directly.
- Filter, sort, and project only the required fields within the script before returning output.
- Pass ONLY the concise, filtered result back into the LLM context.

### Rule 3: Schema Inspection on Demand
- Rather than loading full tool schemas into system prompts, inspect tool signatures on demand via CLI help or targeted schema inspection when authoring an integration script.
- `scripts/verify-mcp-servers.py` prints the live tool list for every configured server, which is the cheapest way to see the real schema.

### Rule 4: A Configured Server Is Not A Working Server
- Every MCP server that this repository configures must be **proven to boot** before it is trusted. A server entry in a config file proves nothing: the Graphify entry was configured in all nine adapters while crashing on startup with `ModuleNotFoundError: No module named 'mcp'`, because the package was installed without its `mcp` extra.
- After changing any MCP invocation, run:

  ```bash
  python3 scripts/verify-mcp-servers.py
  ```

  It launches each server, completes the MCP handshake, and lists the tools it exposes. A server that cannot start fails the check.
- Use the **live tool names** from that output in rules and skills. Do not invent tool names: `search_graph`, `trace_path`, `get_code_snippet` and `get_architecture` do not exist in the Graphify server.

---

## 3. Related Standards & Skills
- [Core Invariants](core-invariants.md): Scoping and boundaries.
- [Automation](automation.md): Dynamic profiles and execution hooks.
- [Codebase Exploration](codebase-exploration.md): Graphify AST navigation.
