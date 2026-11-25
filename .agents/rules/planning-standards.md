# Planning Standards & File-Based Execution

> **Layer 2 Modular Rule** | Scope: All multi-step tasks, features, and complex architectural implementations

This document establishes the planning methodology combining [Spec-Kit](https://github.com/github/spec-kit) specification standards and [Planning-with-Files](https://github.com/OthmanAdi/planning-with-files) persistent disk-backed execution tracking.

---

## 1. Persistent File-Based Planning (`.planning/`)

To prevent state amnesia across model context resets or agent handoffs, agents must track multi-step execution in `.planning/`:
- **`task_plan.md`**: Defines current objective, requirements, acceptance criteria, and operational constraints.
- **`findings.md`**: Captures verified discoveries, architecture insights, and resolved unknowns.
- **`progress.md`**: Records timestamped execution milestones and current active step.
- **Session Catchup**: Use `scripts/hooks/session-catchup.py` to recover and synchronize active planning state across sessions.

---

## 2. Specification-Driven Development (`.specify/`)

Before implementing significant features:
1. Initialize the feature using `.specify/templates/spec-template.md`.
2. Decompose user requirements into verifiable tasks using `.specify/templates/tasks-template.md`.
3. Check and update the project constitution in `.specify/memory/constitution.md` to guarantee alignment with core project invariants.

---

## 3. Related Standards & Skills
- [Core Invariants](core-invariants.md): Scoping and worktree isolation.
- [Code Quality](code-quality.md): 400-line limit and feature-folder architecture.
- [Skills Index](skills-index.md): Complete wiring map for all integrated skills.
