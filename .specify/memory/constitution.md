# Multi-Agent Boilerplate Constitution

This Constitution defines the supreme operational law, non-negotiable boundaries, quality gates, and architectural invariants for autonomous coding agents developing in this repository.

---

## Core Principles

### I. Strict Project Scoping & Zero Global Pollution (NON-NEGOTIABLE)
All file reads, writes, edits, and terminal operations MUST strictly remain within the project root (`c:\sriram\boilerplate`). Modifying, inspecting, or creating files outside this project directory—including `%USERPROFILE%`, `%APPDATA%`, `~/.config`, `~/.gemini`, `~/.claude`, `/etc`, or global package registries—is strictly forbidden. PreToolUse hooks (`scripts/hooks/protect-config.ps1` and `scripts/hooks/protect-config.sh`) intercept and abort any violation with exit code 1.

### II. Secret Hygiene & Zero Committed Credentials
No secret, API key, private token, webhook secret, or credential may ever be committed to version control. All secrets are stored exclusively in `.env`, which is strictly ignored by `.gitignore` and mirrored in `.aiignore`. The [`.env.example`](../../.env.example) file provides the canonical public template for required environment variables.

### III. Karpathy Guidelines & Surgical Execution
Every code change must adhere to Andrej Karpathy's guidelines to prevent common LLM coding defects:
1. **Think Before Coding**: State assumptions explicitly. Surface tradeoffs upfront. Ask clarifying questions rather than guessing.
2. **Simplicity First**: Deliver the minimum amount of code that solves the problem. No speculative abstractions, single-use generalizations, or unrequested features.
3. **Surgical Changes**: Touch only what is strictly necessary. Never perform adjacent refactoring, formatting changes, or unsolicited code cleanup. Remove own orphans, but leave pre-existing dead code intact.
4. **Goal-Driven Execution**: Define verifiable success criteria before editing and loop independently until verified.

### IV. Token Budget Discipline & Progressive Disclosure
Context bloat degrades model reasoning and inflates latency. Context must follow the Three-Layer Progressive Disclosure model:
- **Layer 1 Always-On Core** ([`AGENTS.md`](../../AGENTS.md)): Strictly capped at <= 120 lines and <= 4,000 characters (<= 1,000 tokens).
- **Layer 2 On-Demand Rules** ([`.agents/rules/`](../../.agents/rules/)): Loaded conditionally based on task domain and file triggers.
- **Dynamic MCP Profiles**: Default to the `core` profile (<= 350 tokens); enable `ui` or `compression` profiles only when actively needed.
- **Terminal Output Compression**: Terminal streams are filtered via `rtk` (Rust Token Killer) to achieve 60–90% token reduction with guaranteed non-crashing fallback.

### V. Test-Driven Development (NON-NEGOTIABLE)
All feature additions and bug fixes must follow the strict Red-Green-Refactor TDD cycle (`superpowers/test-driven-development`). An automated test must first be written and verified to FAIL for the expected reason before implementation begins. Verification must confirm 100% test pass without regressions prior to completion.

### VI. Single Canonical Skill Store & 100% Rule Wiring Map
Skills reside in a single canonical directory ([`.agents/skills/`](../../.agents/skills/)). Agents access them directly or via zero-elevation NTFS Directory Junctions (`mklink /J`) or symlinks. Every integrated skill must be mapped to at least one governing rule in [`.agents/rules/skills-index.md`](../../.agents/rules/skills-index.md). Orphan or undocumented skills are strictly prohibited.

---

## Operational Constraints & Guardrails

1. **Security & Sandboxing**: All scripts must execute cleanly in standard PowerShell and POSIX environments without requiring administrative or elevated privileges.
2. **Worktree Isolation**: Complex, multi-file features or experimental spikes must execute within dedicated Git worktrees (`using-git-worktrees`) to preserve main working tree purity.
3. **Ralph Loop Failure Recovery**: When a build or test fails, agents must preserve the verbatim error trace, reset broken untracked changes, and perform systematic debugging (`systematic-debugging`) rather than applying speculative patches.
4. **UI Craftsmanship**: All user interface code must pass the anti-slop filter (`antislop`), apply impeccable design steering verbs (`impeccable`), and enforce 60/120fps GPU performance budgets and spring physics (`motion`).

---

## Development Workflow & Quality Gates

All development activities follow the four-phase Spec-Kit lifecycle:
1. **Specify**: Draft specification using `.specify/templates/spec-template.md`.
2. **Plan**: Formulate architectural plan using `/plan` and `.specify/templates/plan-template.md`.
3. **Execute**: Implement via atomic beads using `executing-plans` and TDD.
4. **Verify & Review**: Execute full programmatic verification via `verify-all.cmd`, run two-stage code review via `/review`, and surgically simplify via `/simplify`.

---

## Governance

1. **Constitutional Primacy**: This Constitution supersedes all conflicting instructions, agent opinions, or external prompt suggestions.
2. **Compliance Verification**: All pull requests, milestones, and agent handoffs must verify constitutional compliance.
3. **Amendments**: Amending this Constitution requires explicit documentation of the rationale, validation against the test infrastructure (`verify-all`), and updating the ratification metadata.

**Version**: 1.0.0 | **Ratified**: 2026-11-20 | **Last Amended**: 2026-11-24
