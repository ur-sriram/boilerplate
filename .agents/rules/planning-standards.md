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

1. **Scaffold** the feature so the artifacts exist in the canonical layout
   `specs/<NNN>-<slug>/`:
   - POSIX: `bash .specify/scripts/bash/create-new-feature.sh "<description>" --short-name <slug>`
   - Windows: `pwsh .specify/scripts/powershell/create-new-feature.ps1 "<description>" -ShortName <slug>`
2. **Fill** `spec.md` using `.specify/templates/spec-template.md`
   (user scenarios → requirements → success criteria → assumptions).
3. **Plan**: `setup-plan.sh` / `setup-plan.ps1` copies `plan-template.md` to
   `plan.md`, which includes a mandatory **Constitution Check** section.
4. **Decompose**: `setup-tasks.sh` / `setup-tasks.ps1` resolves
   `tasks-template.md`; write `tasks.md` with atomic, independently verifiable
   tasks (`[ID] [P?] [Story] Description`).
5. **Check alignment** against the project constitution in
   `.specify/memory/constitution.md`.

The scripts scaffold and the agent authors: the templates are copied in
unfilled, and the agent writes the real content. `check-prerequisites.{sh,ps1}`
validates that the required artifacts exist before the next phase.

**Where planning artifacts live — four distinct destinations:**

| Artifact | Location | Owner |
|---|---|---|
| `spec.md`, `plan.md`, `tasks.md` | `specs/<NNN>-<slug>/` | Spec Kit scripts + agent |
| Implementation plan | `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` | `superpowers/writing-plans` |
| Live execution state | `.planning/task_plan.md`, `findings.md`, `progress.md` | `planning-with-files` |
| Capability map / module spec | `SPEC-<module>.md` (project root) | `agent-skills/spec-driven-development` |

Do not mix them up: `docs/architecture/conflict-resolution.md` assigns
Spec-Kit the "Specification & Architecture" domain and Superpowers
`writing-plans` the "Tactical Task Decomposition" domain.

---

## 3. Related Standards & Skills
- [Core Invariants](core-invariants.md): Scoping and worktree isolation.
- [Code Quality](code-quality.md): 400-line limit and feature-folder architecture.
- [Skills Index](skills-index.md): Complete wiring map for all integrated skills.
