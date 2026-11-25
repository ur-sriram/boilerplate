# Junie Coding & Quality Guidelines

These guidelines define code quality, testing discipline, and review criteria for JetBrains Junie in this project.

## 1. Test-Driven Development (TDD)
- Write tests that assert behavior, not internal implementation details.
- Always observe test failure before implementing the corresponding feature or bugfix.
- Prioritize edge cases: null/undefined, empty collections, boundary conditions, and error paths.
- Ensure test executions are deterministic and fast.

## 2. Systematic Debugging
- Follow a 4-step discipline:
  1. Reproduce the failure with a minimal, isolated test case.
  2. Isolate the exact root cause by inspecting stack traces and state.
  3. Formulate a testable hypothesis.
  4. Apply a minimal surgical fix and verify regression freedom.

## 3. Code Simplification
- Avoid prematurely abstracting single-use routines into generic helper libraries.
- Remove dead code or unused imports introduced by your own modifications.
- Do not refactor adjacent, working legacy code unless explicitly instructed.
- Prefer standard library functions over bulky third-party dependencies where feasible.

## 4. Two-Stage Code Review
- **Stage 1 (Correctness & Security)**: Verify algorithmic correctness, null safety, exception handling, and input validation.
- **Stage 2 (Simplicity & Maintainability)**: Verify adherence to Karpathy guidelines — is the solution as simple as possible?
