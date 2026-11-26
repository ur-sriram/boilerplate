import fs from 'node:fs';
import path from 'node:path';

/**
 * OpenCode file-size guard.
 *
 * `.agents/rules/code-quality.md` caps every source file at 400 effective
 * lines (excluding blank lines and comment-only lines), matching the
 * `max-lines` ESLint rule. This plugin blocks writes that would push a file
 * past the ceiling, so the cap is enforced at the moment of the edit rather
 * than only in CI.
 *
 * WHY THE DEFAULT EXPORT LOOKS LIKE THIS
 * --------------------------------------
 * OpenCode loads every `.opencode/plugins/*.{js,ts}` file as a *path plugin*.
 * The loader contract (verified against opencode 1.19.6) requires the module's
 * DEFAULT export to be an object carrying a non-empty string `id` and a
 * `server()` function. The previous revision exported a bare
 * `export const server = ...`, so OpenCode rejected the file with
 * "Path plugin ... must export id" and the guard never ran.
 *
 * The previous revision also had the logic inverted: it inspected the file as
 * it already was on disk, so it only fired on files that were *already* over
 * the limit - which made an over-limit file impossible to edit and fix. This
 * version computes the size the file *would* have after the write.
 */

const MAX_LINES = 400;
const GUARDED_EXTENSIONS = ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.py', '.ps1', '.sh'];

/** Count lines the way `max-lines` does: skip blanks and comment-only lines. */
function effectiveLineCount(content) {
  let count = 0;
  for (const raw of content.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith('#')) continue;
    if (line.startsWith('//')) continue;
    if (line.startsWith('/*')) continue;
    if (line.startsWith('*')) continue;
    count++;
  }
  return count;
}

function readIfPresent(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

/**
 * Work out the content the file would have after the tool runs.
 * Returns null when the outcome cannot be determined, in which case the
 * guard stays out of the way and CI's ESLint `max-lines` rule is the
 * backstop.
 */
function projectResultingContent(toolName, args, projectRoot) {
  if (!args || typeof args !== 'object') return null;

  const candidate = args.path ?? args.file ?? args.filePath ?? args.file_path;
  if (typeof candidate !== 'string' || !candidate) return null;

  const resolved = path.resolve(projectRoot, candidate);
  if (!GUARDED_EXTENSIONS.includes(path.extname(resolved).toLowerCase())) return null;

  const name = String(toolName).toLowerCase();

  // Full-file write: the content is right there in the arguments.
  if (typeof args.content === 'string') return args.content;

  // Targeted edit: apply the replacement to the current content.
  if (
    (name === 'edit' || name === 'multiedit' || name === 'multi_edit') &&
    typeof args.oldString === 'string' &&
    typeof args.newString === 'string'
  ) {
    const current = readIfPresent(resolved);
    if (current === null) return null;
    return current.replace(args.oldString, args.newString);
  }

  return null;
}

export default {
  id: 'boilerplate-ponytail-compactor',

  /** OpenCode V1 hook surface. */
  async server({ directory } = {}) {
    const projectRoot = directory || process.cwd();

    return {
      'tool.execute.before': async (input, output) => {
        const content = projectResultingContent(input?.tool ?? '', output?.args ?? {}, projectRoot);
        if (content === null) return;

        const lines = effectiveLineCount(content);
        if (lines > MAX_LINES) {
          const args = output?.args ?? {};
          const name = args.path ?? args.file ?? args.filePath ?? '(unknown)';
          throw new Error(
            `[GUARDRAIL] File size limit exceeded: "${name}" would have ${lines} effective lines ` +
              `(max ${MAX_LINES}). Split the module per .agents/rules/code-quality.md.`,
          );
        }
      },
    };
  },

  /** OpenCode V2 hook surface. */
  async setup(ctx) {
    const projectRoot = ctx?.location?.directory || process.cwd();

    await ctx.tool.hook('execute.before', async (event) => {
      const input = event?.input;
      const content = projectResultingContent(
        event?.tool ?? '',
        input && typeof input === 'object' ? input : {},
        projectRoot,
      );
      if (content === null) return;

      const lines = effectiveLineCount(content);
      if (lines > MAX_LINES) {
        throw new Error(
          `[GUARDRAIL] File size limit exceeded: write would produce ${lines} effective lines ` +
            `(max ${MAX_LINES}). Split the module per .agents/rules/code-quality.md.`,
        );
      }
    });
  },
};
