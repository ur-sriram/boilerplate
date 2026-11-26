/**
 * Tailwind configuration.
 *
 * Referenced by `components.json` (the shadcn registry contract). The
 * boilerplate ships the config and the base stylesheet so the UI pipeline's
 * Step 1 (`npx shadcn@latest add ...`) has a valid target; the component
 * registry itself is framework-specific (React), so React is NOT a dependency
 * of this package.
 */
export default {
  content: ['./src/**/*.{ts,tsx,js,jsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
};
