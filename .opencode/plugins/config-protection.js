import fs from 'node:fs';
import path from 'node:path';

/**
 * OpenCode Pre-Tool Guardrail Plugin.
 *
 * Enforces strict project-level scoping by preventing file modification or
 * creation outside the project root.
 *
 * WHY THE DEFAULT EXPORT LOOKS LIKE THIS
 * --------------------------------------
 * OpenCode loads every `.opencode/plugins/*.{js,ts}` file as a *path plugin*.
 * The loader contract (verified against opencode 1.19.6) is:
 *
 *   - the module's DEFAULT export must be an object
 *   - that object must carry a non-empty string `id`
 *   - for a server plugin it must carry a `server()` function returning hooks
 *
 * A module that exports only `export const server = ...` (or that omits `id`)
 * is rejected at load time with:
 *
 *     failed to load plugin ... error="Path plugin ... must export id"
 *
 * and every hook it defines silently never fires. The previous revision of
 * this file had exactly that shape, so the guardrail was dead code.
 *
 * The `setup()` export is the OpenCode V2 entry point. OpenCode V1 (the
 * published `latest`) ignores it; V2 uses it and ignores `server()`. Both are
 * implemented here from the same guard function so the two paths cannot drift.
 */

/** Tools that create or modify files. Reads are intentionally not guarded. */
const MUTATING_TOOLS = new Set([
  'write',
  'edit',
  'multiedit',
  'multi_edit',
  'patch',
  'apply_patch',
  'create',
  'createfile',
  'writefile',
]);

/**
 * Resolve a path to its physical location.
 *
 * `path.resolve` is purely lexical, so a symlinked checkout (for example
 * `/workspace` -> `/run/csi/...`) would compare a project root against a
 * different physical prefix and block every legitimate write. This walks up to
 * the deepest existing ancestor, resolves that, then re-appends the missing
 * tail - which is what `realpath -m` does on the POSIX side.
 */
function physicalPath(target) {
  let current = target;
  const tail = [];

  while (!fs.existsSync(current)) {
    const parent = path.dirname(current);
    if (parent === current) return path.resolve(target);
    tail.unshift(path.basename(current));
    current = parent;
  }

  try {
    return path.join(fs.realpathSync(current), ...tail);
  } catch {
    return path.resolve(target);
  }
}

/** The first argument that names a file the tool is about to touch. */
function targetPath(args) {
  if (!args || typeof args !== 'object') return null;
  const candidate =
    args.path ?? args.file ?? args.filePath ?? args.target ?? args.destination ?? args.file_path;
  return typeof candidate === 'string' && candidate.length > 0 ? candidate : null;
}

/**
 * Throw when a mutating tool targets a path outside the project root.
 * Shared by the V1 (`server`) and V2 (`setup`) entry points.
 */
function guardWrite(projectRoot, toolName, args) {
  if (!MUTATING_TOOLS.has(String(toolName).toLowerCase())) return;

  const candidate = targetPath(args);
  if (!candidate) return;

  const root = physicalPath(projectRoot);
  const resolved = path.resolve(projectRoot, candidate);
  const target = physicalPath(resolved);
  const relative = path.relative(root, target);

  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(
      `[SECURITY] Out-of-scope write blocked: "${resolved}" is outside project root "${root}". ` +
        `This project runs in strict project-level scope; write only inside the project root.`,
    );
  }
}

export default {
  id: 'boilerplate-config-protection',

  /** OpenCode V1 hook surface. */
  async server({ directory } = {}) {
    const projectRoot = directory || process.cwd();

    return {
      'tool.execute.before': async (input, output) => {
        guardWrite(projectRoot, input?.tool ?? '', output?.args ?? {});
      },
    };
  },

  /** OpenCode V2 hook surface. */
  async setup(ctx) {
    const projectRoot = ctx?.location?.directory || process.cwd();

    await ctx.tool.hook('execute.before', async (event) => {
      const input = event?.input;
      guardWrite(projectRoot, event?.tool ?? '', input && typeof input === 'object' ? input : {});
    });
  },
};
