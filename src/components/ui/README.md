# UI Component Registry Drop Zone

`components.json` maps the `@/components/ui` alias here. This is where
components sourced from the 12 registries (via `ui-registry-mcp`), the shadcn
CLI, or Astryx are installed and adapted.

**Pipeline**: `.agents/rules/ui-standards.md` Step 1 (source, do not author
from scratch) → Step 2 (motion) → Step 3 (anti-slop) → Step 4 (impeccable
polish).

**Installing a component**

```bash
npx shadcn@latest add @magicui/marquee        # named registry
npx shadcn@latest add @astryx/component-button
npx shadcn@latest add button                  # default shadcn registry
```

The theme lives in `src/app/globals.css` (Tailwind v4, CSS-first — there is
no `tailwind.config.js`; `components.json` sets `tailwind.config` to `""`).
`npm run css:build` compiles it. `python3 scripts/verify-ui-contracts.py`
checks that the contract file, the theme and the `@/*` alias are all still
coherent; add `--network` to also probe the live registries.

**Note**: shadcn and Astryx emit React components. This boilerplate is
framework-agnostic TypeScript, so React is deliberately NOT a dependency here.
In a React project these files are installed as-is; in a non-React project,
adapt the registry component's markup and styling to the local framework
instead of adding React.

**Astryx is the exception**: its components are StyleX-based
(`@astryxdesign/core` + `@stylexjs/stylex`), not Tailwind. They belong in
their own folder (`components/astryx/`) with their own CSS imports, not here.
