# Code Quality, Modularity & Feature Architecture Standards

> **Layer 2 Modular Rule** | Scope: All code authoring and modifications across repository

This document establishes the code quality gates, file size constraints, feature-folder architecture, and testing requirements for all software authored in this repository.

---

## 1. Strict File Line Limits (Max 400 Lines)

To prevent unmaintainable monolithic files and ensure clean separation of concerns:
- **Maximum Line Ceiling**: No code file (`.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.ps1`) may exceed **400 lines** (excluding blank lines and comments).
- **Target Feature Size**: Ideal feature module sizes range from **200 to 400 lines**. Smaller single-responsibility utilities and types are encouraged.
- **Automated Enforcement**:
  - `tsconfig.json`: Strict type-checking (`strict: true`, `noUncheckedIndexedAccess: true`).
  - `eslint.config.js`: ESLint 9 flat config enforcing `"max-lines": ["error", { "max": 400, "skipBlankLines": true, "skipComments": true }]`.
    (Migrated from the legacy `.eslintrc.json`, which ESLint 9 no longer reads.)
  - `scripts/verify-file-limits.{ps1,sh}`: Programmatic verification check executed during CI and test suite runs.
    Both twins count *effective* lines (blank lines and comment-only lines excluded) so they agree with the ESLint rule.

---

## 2. Feature-Folder Vertical Slice Architecture

All functional capabilities must be organized into self-contained feature folders rather than scattered across global folders:
- **Location**: `src/features/<feature-name>/`
- **Standard Structure**: Follow the template defined in `src/features/_template/`:
  - `index.ts`: Public barrel exports for the feature.
  - `feature.ts`: Core domain logic (strictly <= 400 lines).
  - `feature.types.ts`: Strict TypeScript contracts and type definitions.
  - `feature.test.ts`: Automated test assertions (TDD red-green cycle).
  - `README.md`: Feature specification and usage instructions.

---

## 3. Test-Driven Development (TDD) Mandate

Follow the [`test-driven-development`](../skills/superpowers/test-driven-development/SKILL.md) workflow:
1. **Red**: Write a failing test asserting expected behavior before authoring implementation code.
2. **Green**: Write the minimal code necessary to make the test pass.
3. **Refactor**: Apply [`code-simplification`](../skills/quality/code-simplification/SKILL.md) to eliminate complexity without breaking passing tests.

---

## 4. Code Simplification & Karpathy Minimalism

- Refuse speculative abstractions, unused flexibility, or unnecessary configurable parameters.
- If an implementation can be solved in 50 lines cleanly, do not write 200 lines.
- Remove orphaned imports, dead variables, and obsolete types created by your changes.

---

## 5. Related Standards & Skills
- [Core Invariants](core-invariants.md): Operational boundaries and project scoping.
- [UI Standards](ui-standards.md): Mandatory 4-step UI/UX pipeline.
- [Planning Standards](planning-standards.md): Planning with files.
- [Skills Index](skills-index.md): Complete wiring map for all integrated skills.
