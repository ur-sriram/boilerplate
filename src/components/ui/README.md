# UI Component Registry Drop Zone

`components.json` maps the `@/components/ui` alias here. This is where
components sourced from the 12 registries (via `ui-registry-mcp`), the shadcn
CLI, or Astryx are installed and adapted.

**Pipeline**: `.agents/rules/ui-standards.md` Step 1 (source, do not author
from scratch) → Step 2 (motion) → Step 3 (anti-slop) → Step 4 (impeccable
polish).

**Note**: shadcn and Astryx emit React components. This boilerplate is
framework-agnostic TypeScript, so React is deliberately NOT a dependency here.
In a React project these files are installed as-is; in a non-React project,
adapt the registry component's markup and styling to the local framework
instead of adding React.
