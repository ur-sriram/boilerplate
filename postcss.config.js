/**
 * PostCSS configuration for Tailwind.
 *
 * `src/app/globals.css` uses the Tailwind v4 syntax (`@import "tailwindcss"`
 * plus an `@theme inline` block), and `components.json` sets
 * `tailwind.config` to "" — the v4 marker, where the stylesheet is the
 * configuration and no `tailwind.config.js` is used.
 *
 * The v4 plugin (`@tailwindcss/postcss`) also handles vendor prefixing, so
 * `autoprefixer` is deliberately absent.
 */
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
