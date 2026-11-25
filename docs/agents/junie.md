# JetBrains Junie Setup Guide

This guide details configuration, operational playbook, converted behavioral rules, and completion checklists for JetBrains Junie in this repository.

## 1. Overview & Project Scoping

JetBrains Junie operates inside JetBrains IDEs (IntelliJ IDEA, WebStorm, PyCharm, etc.) and respects project-level configuration without modifying global IDE settings. It discovers operational instructions from:

- Operational Playbook: `.junie/playbook.md`
- Converted Coding Rules: `.junie/rules/coding-guidelines.md`
- Converted UI Guidelines: `.junie/rules/ui-guidelines.md`
- Project Core Index: `AGENTS.md`

## 2. Operational Playbook (`.junie/playbook.md`)

The playbook establishes non-negotiable operational requirements:
1. **Strict Project Scoping**: Work exclusively within the project directory.
2. **Karpathy Guidelines**: Think before coding, favor simplicity, make surgical edits, and loop until verified.
3. **Structured Lifecycles**: Spec-Kit for architecture, Superpowers TDD for implementation, and 2-stage review before task completion.

## 3. Converted Behavioral Rules

Because JetBrains Junie does not execute native shell hooks (such as `PreToolUse`), hook guardrails and quality checks are converted directly into Junie-native rules:

- **`.junie/rules/coding-guidelines.md`**: Captures TDD discipline, systematic 4-phase debugging, code simplification, and correctness/security review criteria.
- **`.junie/rules/ui-guidelines.md`**: Captures Impeccable steering vocabulary (`bolder`, `quieter`, `polish`, `typeset`), anti-slop finish gate criteria, WCAG AA compliance, and 60fps motion performance budgets.

## 4. Completion Checklist

Before reporting task completion, Junie agents must verify:
- [ ] Code compiles and all automated tests pass.
- [ ] No files were written outside the repository root.
- [ ] No hardcoded secrets or credentials are present.
- [ ] Surgical simplification was applied to remove newly created orphans.
- [ ] Run `verify-all.cmd` (or `./scripts/verify-all.sh`) to confirm repository integrity.

## 5. Verification

Verify project setup:
```cmd
verify-all.cmd
```
