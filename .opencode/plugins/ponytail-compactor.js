import fs from 'node:fs';
import path from 'node:path';

/**
 * OpenCode file-size guard.
 *
 * .agents/rules/code-quality.md caps every source file at 400 effective
 * lines (excluding blank lines and comment-only lines), matching the
 * `max-lines` ESLint rule. This plugin blocks writes that would push a file
 * past the ceiling, so the cap is enforced at the moment of the edit rather
 * than only in CI.
 *
 * The previous revision was a stub that returned a status object and never
 * ran.
 */

const MAX_LINES = 400;
const GUARDED_EXTENSIONS = ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.py', '.ps1', '.sh'];

function effectiveLineCount(filePath) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch {
    return 0;
  }
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

export const server = async ({ directory }) => {
  const projectRoot = directory || process.cwd();

  return {
    'tool.execute.before': async (input, output) => {
      const args = output?.args ?? {};
      const candidate = args.path ?? args.file ?? args.filePath;
      if (typeof candidate !== 'string' || !candidate) return;

      const resolved = path.resolve(projectRoot, candidate);
      if (!GUARDED_EXTENSIONS.includes(path.extname(resolved).toLowerCase())) return;
      if (!fs.existsSync(resolved)) return;

      const lines = effectiveLineCount(resolved);
      if (lines > MAX_LINES) {
        throw new Error(
          `[GUARDRAIL] File size limit exceeded: ${path.relative(projectRoot, resolved)} has ${lines} ` +
            `effective lines (max ${MAX_LINES}). Split the module per .agents/rules/code-quality.md.`,
        );
      }
    },
  };
};

export default { server };
