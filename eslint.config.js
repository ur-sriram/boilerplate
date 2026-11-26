// ESLint 9 flat configuration.
//
// Migrated from the legacy `.eslintrc.json`, which ESLint 9 no longer reads.
// The `max-lines` rule mirrors the 400-line ceiling enforced by
// scripts/verify-file-limits.{sh,ps1} and documented in
// .agents/rules/code-quality.md.
import js from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: [
      '.agents/skills/**',
      '.specify/**',
      'node_modules/**',
      'dist/**',
      'build/**',
      '.claude/skills/**',
      '.codex/skills/**',
      '.cursor/skills/**',
      '.cline/skills/**',
      '.qoder/skills/**',
      '.windsurf/skills/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{js,mjs,cjs,ts,tsx}'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: { ...globals.node, ...globals.browser },
    },
    rules: {
      'max-lines': [
        'error',
        { max: 400, skipBlankLines: true, skipComments: true },
      ],
      'no-unused-vars': 'error',
      'no-console': 'warn',
      '@typescript-eslint/no-unused-vars': 'error',
    },
  },
  {
    // CLI/plugin entry points legitimately write to stdout.
    files: ['scripts/**/*.js', 'scripts/**/*.mjs', '.opencode/plugins/**/*.js'],
    rules: { 'no-console': 'off' },
  },
);
