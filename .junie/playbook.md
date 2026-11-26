# JetBrains Junie Operational Playbook

This playbook governs how JetBrains Junie executes development tasks in this repository.

## 0. Canonical Project Index

**Read `AGENTS.md` first.** It is the single always-on source of truth for the
project invariants, the skill index (`.agents/rules/skills-index.md`) and the
slash-command surface. The rules below are a Junie-specific restatement of
those invariants — where the two disagree, `AGENTS.md` wins.

## 1. Project Invariants & Karpathy Guidelines

- **Strict Scoping**: Operate strictly within the repository root (the directory that contains this playbook). Do not touch files in user profile, application data, or global IDE directories.
- **Think Before Coding**: State assumptions explicitly. Surface tradeoffs. Push back on overcomplication.
- **Simplicity First**: Deliver the minimum viable code that satisfies the requirements. Avoid speculative abstractions or unrequested configurability.
- **Surgical Changes**: Edit only what is necessary. Preserve existing style and comments. Clean up only your own orphans.
- **Goal-Driven Execution**: Define verifiable success criteria (tests or commands) before modifying code. Loop until verified.

## 2. Core Workflow Lifecycles

### A. Architectural & Planning Phase
1. For multi-step or complex features, consult `.specify/` templates and `.agents/rules/planning-standards.md`.
2. Generate verifiable atomic task checklists.
3. Verify each plan step with explicit verification commands.

### B. Implementation Phase (TDD)
1. Write minimal failing test cases first (`.agents/skills/superpowers/test-driven-development/SKILL.md`).
2. Run test to verify failure.
3. Implement surgical code changes.
4. Verify tests pass.

### C. Review & Completion Checklist
- [ ] Code compiles and tests pass without regression.
- [ ] No files created outside project boundary.
- [ ] No secrets or hardcoded credentials committed.
- [ ] Run 2-stage review (correctness and simplicity) per `.junie/rules/coding-guidelines.md`.
