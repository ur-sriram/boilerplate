# Master Conflict Resolution & Workflow Arbitration Matrix

This document provides a comprehensive analysis of overlapping skills and workflows across external sources, explaining the rationale for selecting exactly one primary workflow per domain and documenting how competing workflows are superseded or disabled.

## 1. Conflict Resolution Philosophy (Requirement R3)

When integrating multiple agent skill sources (`obra/superpowers`, `addyosmani/agent-skills`, `mattpocock/skills`, `github/spec-kit`, `affaan-m/ecc`, `pbakaus/impeccable`, `miqdadbadjuber/anti-slop`, `emilkowalski/skills`, etc.), functional overlap inevitably arises. Having multiple agents or multiple prompts attempt the same task leads to conflicting instructions, inconsistent conventions, and wasted context.

**Invariant**: For every distinct task domain, this repository selects **exactly one primary workflow**, documents the selection rationale, disables or supersedes competing workflows, and records explicit technical enforcement.

---

## 2. Master Conflict Resolution Matrix across 12 Domains

| Task Domain | Contending Sources | Selected Primary Workflow | Superseded / Disabled Workflows | Rationale & Technical Enforcement |
|---|---|---|---|---|
| **1. Specification & Architecture** | `github/spec-kit`, `OthmanAdi/planning-with-files`, `mattpocock/to-spec` | **Spec-Kit (`.specify/`)** | Standalone raw markdown scratchpads from `planning-with-files` and unvalidated specs from `mattpocock/to-spec`. | `spec-kit` provides executable PowerShell/Bash automation, schema validation, constitution enforcement, and phase gates. Disabled competing raw planning prompts. |
| **2. Tactical Task Decomposition** | `obra/superpowers/writing-plans`, `addyosmani/planning-and-task-breakdown`, `affaan-m/ecc/planning` | **Superpowers: `writing-plans`** | Generic planning from `agent-skills` and free-form ECC planners. | `superpowers/writing-plans` produces verifiable, atomic steps with explicit check commands aligned with TDD. Enforced via `.agents/rules/planning-standards.md`. |
| **3. Test-Driven Development** | `obra/superpowers/test-driven-development`, `addyosmani/test-driven-development`, `mattpocock/tdd` | **Superpowers: `test-driven-development`** | Addy Osmani TDD prompt, Matt Pocock TDD skill. | Superpowers TDD enforces strict failing-test verification before implementation, ironclad diff checks, and subagent isolation. Configured as primary in `skills-index.md`. |
| **4. Systematic Debugging** | `obra/superpowers/systematic-debugging`, `addyosmani/debugging-and-error-recovery`, `mattpocock/diagnosing-bugs` | **Superpowers: `systematic-debugging`** | Generic debugging prompts. | 4-phase structured discipline: reproduce, isolate root cause, form hypothesis, minimal fix with regression test. |
| **5. Code Review Protocol & Persona** | `obra/superpowers/requesting-code-review`, `msitarzewski/agency-agents` (Code Reviewer), `affaan-m/ecc` | **Superpowers Protocol + Agency Code Reviewer Persona** | Standalone ECC lint commands and uncurated reviewer prompts. | Superpowers governs the multi-agent handoff protocol; Agency Code Reviewer provides the deep checklist (correctness, performance, security). |
| **6. Code Simplification & Debt Reduction** | `addyosmani/agent-skills/code-simplification`, `DietrichGebert/ponytail` (`ponytail-debt`) | **Agent-Skills: `code-simplification`** | Heavy Ponytail multi-file debt rewrites. | Aligns directly with Karpathy guideline: minimal surgical changes, zero speculative refactoring. Ponytail is retained strictly for statusline utilities. |
| **7. UI Design Vocabulary & Review** | `pbakaus/impeccable`, `nextlevelbuilder/ui-ux-pro-max-skill`, `Leonxlnx/taste-skill` | **Impeccable (`pbakaus/impeccable`)** | `ui-ux-pro-max-skill` (heavy Python dependencies) and uncurated generators. | Industry-standard 20+ steering verbs (`bolder`, `quieter`, `polish`, `typeset`) with multi-agent generated configs. |
| **8. UI Quality Gate & Anti-Slop** | `miqdadbadjuber/anti-slop`, `Leonxlnx/taste-skill` (`scripts/gate.mjs`) | **Anti-Slop (`miqdadbadjuber/anti-slop`)** | Redundant taste-skill binary gate scripts. | Featherweight 12-line pointer rule with deep on-demand audits (WCAG contrast, buzzword removal, visual slop elimination). |
| **9. Motion & Animation Physics** | `emilkowalski/skills`, `pbakaus/impeccable` (`animate.md`), `taste-skill` | **Emil Kowalski Skills** | Generic CSS animation guides. | Unmatched 60/120fps GPU performance budgets, spring physics curves, touch gesture math, and `break-ui` stress testing. |
| **10. UI Component Discovery** | `mrityunjay-tiwari/ui-registry-mcp`, `ui.shadcn.com/docs/mcp`, `meta/astryx` | **`ui-registry-mcp` + Native `shadcn` CLI** | Standalone Astryx 1.38 GB monolithic repo (retained as optional enterprise alternative). | `ui-registry-mcp` covers 12 registries, provides `compare_components` and `check_consistency`, and emits standard `npx shadcn add` commands. Loaded dynamically in UI profile. |
| **11. Codebase Knowledge Graph** | `Graphify-Labs/graphify`, `thedotmack/claude-mem` (upstream `mcp-search`, not vendored here), text grep | **Graphify AST Knowledge Graph** | Naive full-codebase grep searches. | Deterministic AST dependency and caller mapping without vector DB overhead or external telemetry. The upstream `mcp-search` tool is not installed; `claude-mem` contributes only the episodic-memory architecture, reimplemented locally in `src/features/claude-mem/`. |
| **12. Browser Testing & Automation** | `browser-use/browser-harness`, legacy 30-tool Playwright MCP | **Browser Harness (CLI Script Mode)** | Heavy 30-tool Playwright MCP servers (2,500 always-on tokens). | Connects to local Chrome via CDP with 0 always-on tokens; script-driven via python heredoc; supports background execution without stealing window focus. |

---

## 3. Technical Enforcement Mechanisms

1. **Rule Wiring Exclusivity**:
   In `.agents/rules/`, each domain references only the selected primary workflow. For example, `.agents/rules/code-quality.md` mandates `superpowers/test-driven-development` and explicitly designates `code-simplification` for cleanup tasks.
2. **Slash Command Mapping**:
   Custom commands in `.opencode/commands/` point directly to the chosen primary workflow files (`plan.toml` invokes Spec-Kit + Superpowers plans; `test.toml` invokes Superpowers TDD).
3. **Repository Directory Structure**:
   Only chosen primary skills are copied into `.agents/skills/`. Superseded source repositories remain documented in `THIRD_PARTY.md` as "Integrated on Demand", "Modified & Integrated", or "Skipped (Documented)".
