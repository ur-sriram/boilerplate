import path from 'node:path';

/**
 * OpenCode Pre-Tool Guardrail Plugin.
 *
 * Enforces strict project-level scoping by preventing file modification or
 * creation outside the project root.
 *
 * OpenCode plugin contract (V1): a plugin exports `server()`, which returns
 * the hook object. The previous revision exported `onPreToolCall`, which is
 * not an OpenCode hook name and therefore never fired.
 */
export const server = async ({ directory }) => {
  const projectRoot = directory || process.cwd();

  const FORBIDDEN = ['\\.gemini', '\\.claude', '\\.config', 'appdata', '\\.codex'];

  return {
    'tool.execute.before': async (input, output) => {
      const tool = input?.tool ?? '';
      const args = output?.args ?? {};
      const candidate =
        args.path ?? args.file ?? args.filePath ?? args.target ?? args.destination;

      if (typeof candidate !== 'string' || candidate.length === 0) return;

      const resolved = path.resolve(projectRoot, candidate);
      const relative = path.relative(projectRoot, resolved);

      if (relative.startsWith('..') || path.isAbsolute(relative)) {
        throw new Error(
          `[SECURITY] Out-of-scope operation blocked: "${resolved}" is outside project root "${projectRoot}".`,
        );
      }

      const normalized = resolved.toLowerCase();
      const forbidden = FORBIDDEN.find((pattern) => normalized.includes(pattern));
      if (forbidden && !normalized.startsWith(path.resolve(projectRoot).toLowerCase())) {
        throw new Error(
          `[SECURITY] Sensitive global configuration path blocked: "${resolved}".`,
        );
      }

      void tool;
    },
  };
};

export default { server };
