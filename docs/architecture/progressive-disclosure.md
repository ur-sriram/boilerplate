# Progressive Disclosure & Three-Layer Context Architecture

This document describes the context architecture, token budget limits, and runtime compression strategies implemented in this repository.

## 1. Architectural Philosophy

Standard AI agent configurations frequently suffer from severe context bloat by injecting entire rulebooks, large skill catalogs, and extensive tool schemas into every single turn. This wastes tens of thousands of tokens, increases latency, degrades reasoning quality, and quickly exhausts context windows.

This boilerplate implements a strict **Three-Layer Context Architecture** based on the principle of **Progressive Disclosure**: agents load only the minimal routing metadata required to recognize tasks, retrieving deep execution artifacts just-in-time (JIT).

```
Total Model Context Window (128k - 200k tokens)
┌────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: Always-On Core (Loaded on Every Turn)                         │
│ • AGENTS.md: Root index, Karpathy invariants, pointer table            │
│ • Hard budget: ≤ 120 lines / ≤ 9,000 characters (≈ 2,200 tokens)   │
│ • Default MCP schemas: Core Profile only (<= 350 tokens)               │
│ • Total Layer 1 baseline: <= 1,350 tokens                              │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ triggers
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: On-Demand Routing Metadata (Parsed at Startup / Discovered)   │
│ • Skill YAML frontmatter (name + description): ~30 tokens per skill    │
│ • Rule glob patterns (activation conditions): ~20 tokens per rule      │
│ • Total Layer 2 footprint: ~600 tokens                                 │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ dispatches
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: Deep Execution Artifacts (Loaded JIT Only During Active Task) │
│ • Full SKILL.md instruction bodies (~1,500 - 3,000 tokens)             │
│ • Design references (impeccable verbs, anti-slop checklists)           │
│ • Spec-Kit templates & specifications (.specify/)                      │
│ • Dynamic MCP tool invocations (UI Registry, Headroom)                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Token Budget Breakdown Table

The following table catalogs the strict token boundaries enforced across all layers:

| Component | Layer | File Path | Token Budget | Enforced Constraint |
|---|---|---|---|---|
| **Always-On Core Index** | Layer 1 | `AGENTS.md` | **≈ 2,200 tokens** | Max 120 lines, <= 9,000 chars; **enforced** by `test-bootstrap.sh` / `.ps1` |
| **Core MCP Schemas (Default)** | Layer 1 | `graphify` via `mcp_config.json` | **~350 tokens** | Only AST exploration tool enabled on startup |
| **Project Boundary Rules** | Layer 1 | `.aiignore` / `.gitignore` | ~100 tokens | Pure glob patterns; zero prose |
| **Core Invariants Rule** | Layer 2 | `.agents/rules/core-invariants.md` | ~250 tokens | Triggered on code edit or task initiation |
| **Planning Standards Rule** | Layer 2 | `.agents/rules/planning-standards.md` | ~300 tokens | Triggered on `/plan` or spec drafting |
| **UI & Motion Standards Rule** | Layer 2 | `.agents/rules/ui-standards.md` | ~350 tokens | Triggered on `**/*.{tsx,jsx,vue,svelte,css}` |
| **Code Quality Rule** | Layer 2 | `.agents/rules/code-quality.md` | ~250 tokens | Triggered on `/review` or refactoring |
| **Skills Routing Index** | Layer 2 | `.agents/rules/skills-index.md` | ~400 tokens | Metadata table mapping 100% of skills |
| **UI Registry MCP (On-Demand)** | Layer 3 | `ui-registry-mcp` | ~400 tokens | Enabled **only** when UI profile is active |
| **Active Skill Body (JIT)** | Layer 3 | `.agents/skills/<domain>/<skill>/SKILL.md` | 1,500 – 3,000 tokens | Loaded **only** when active skill is invoked |
| **Design Reference (JIT)** | Layer 3 | `docs/architecture/*.md` | 1,000 – 2,500 tokens | Loaded **only** when visual review is executed |
| **Active Specification (JIT)** | Layer 3 | `.specify/specs/<feature>/spec.md` | 2,000 – 4,000 tokens | Loaded **only** during active feature work |

---

## 3. Dynamic MCP Profiles

Rather than declaring all MCP servers as always-on (which would incur ~1,050 tokens of tool schemas on every turn), the boilerplate provides dynamic profiles:

- **`core` Profile (Default)**:
  - Active: `graphify` (AST code exploration).
  - Overhead: **<= 350 tokens**.
  - Suitable for: general coding, bug fixes, refactoring, testing.
- **`ui` Profile (On-Demand)**:
  - Active: `graphify` + `ui-registry` (12 component registries).
  - Overhead: **~750 tokens**.
  - Activated via: `powershell -ExecutionPolicy Bypass -File ./scripts/mcp-profile.ps1 -Profile ui` (or `./scripts/mcp-profile.sh ui`).
- **`compression` Profile (Optional)**:
  - Active: `graphify` + `headroom` (dynamic context compression).
  - Overhead: **~650 tokens**.
- **`all` Profile**:
  - Active: `graphify` + `ui-registry` + `headroom`.
  - Overhead: **~1,050 tokens**.

---

## 4. Runtime Output Token Compression

In addition to static prompt budgeting, two runtime mechanisms reduce output tokens during execution:

1. **`rtk` (Rust Token Killer)**:
   - Hooks into the `PostToolUse` lifecycle event via `scripts/hooks/rtk-filter.{ps1,sh}` and `.opencode/plugins/rtk-interceptor.js`.
   - Compresses verbose terminal output from build, test, and package manager commands (`npm test`, `cargo build`, `pytest`), achieving **60% to 90% token reduction**.
   - Features a guaranteed non-crashing fallback: if `rtk` is not installed, output passes through unmodified.

2. **`headroom` Context Compressor**:
   - Compresses large file reads and tool payloads by 20% to 70% when the `compression` or `all` profile is active.
