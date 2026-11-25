# Feature Template Contract

Each feature must be self-contained in its own dedicated vertical slice directory under `src/features/<feature-name>/`.

## Structure
- `index.ts`: Public barrel exports for external consumers.
- `feature.ts`: Domain logic & implementation (strictly <= 400 lines).
- `feature.types.ts`: Strict TypeScript interfaces & contracts.
- `feature.test.ts`: Automated TDD test suite with edge cases.
- `README.md`: Feature specification, boundary constraints, and usage examples.
