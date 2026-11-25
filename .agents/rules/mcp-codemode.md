# Cloudflare CodeMode: MCP Token Burn Prevention

> **Layer 2 Modular Rule** | Scope: All agents utilizing Model Context Protocol (MCP) servers | Enforced across repository

This document establishes the strict operational guidelines for utilizing MCP tools without causing catastrophic token burn in model context windows, following the [Cloudflare Agents Code Mode Architecture](https://github.com/cloudflare/agents/blob/main/docs/codemode/index.md).

---

## 1. The Token Burn Problem

Exposing dozens of monolithic MCP tool schemas directly to LLM prompts introduces severe inefficiencies:
1. **Schema Bloat**: 20+ MCP tool schemas consume 5,000 to 15,000 tokens of system context on *every single turn*, drastically reducing effective context capacity and increasing latency.
2. **Chatty Roundtrips**: Making sequential JSON-RPC tool calls for data extraction, intermediate transformation, and filtering burns output tokens and multiplies network turnarounds.
3. **Payload Dumping**: Many MCP servers return massive JSON arrays containing hundreds of unneeded fields, flooding model memory.

---

## 2. The CodeMode Solution & Mandatory Rules

All agents operating in this repository must adhere to the following 3 CodeMode principles:

### Rule 1: Dynamic MCP Profiles (Default Minimal Context)
- Never enable all MCP servers globally at all times.
- Keep the default MCP profile locked to `core` (<= 350 tokens: graphify, filesystem).
- Activate domain MCP servers on-demand only when a task strictly requires them using `scripts/mcp-profile.{ps1,sh}`:
  ```powershell
  # Toggles only UI registries when doing frontend work:
  powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile ui
  ```

### Rule 2: Programmatic Execution Over Serial Tool Calls
- When performing multi-step data lookups, querying databases, or searching registries, **write a compact script** (Node.js, TypeScript, or Python) to call the tool API/server directly.
- Filter, sort, and project only the required fields within the script before returning output.
- Pass ONLY the concise, filtered result back into the LLM context.

### Rule 3: Schema Inspection on Demand
- Rather than loading full tool schemas into system prompts, inspect tool signatures on demand via CLI help or targeted schema inspection when authoring an integration script.

---

## 3. Related Standards & Skills
- [Core Invariants](core-invariants.md): Scoping and boundaries.
- [Automation](automation.md): Dynamic profiles and execution hooks.
- [Codebase Exploration](codebase-exploration.md): Graphify AST navigation.
