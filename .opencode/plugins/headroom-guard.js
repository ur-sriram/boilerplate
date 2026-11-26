/**
 * OpenCode "no blind grepping" guard.
 *
 * .agents/rules/codebase-exploration.md forbids naive whole-repository
 * grep / recursive string searches and mandates the Graphify AST graph for
 * code discovery. This plugin enforces that at the tool boundary, which is
 * where it is cheap to enforce (the previous revision was a stub that
 * returned `allowed: true` unconditionally and never ran).
 *
 * Exemptions: explicit path arguments, file-scoped globs, and searches that
 * already target a specific directory.
 */
const WHOLE_REPO_PATTERNS = [
  /\bgrep\b(?![^\s]*\s--?[\w-]*[A-Za-z0-9_./-]+)/,
  /\brg\b/,
  /\bag\b/,
];

const NARROWING_FLAGS = ['-r', '--recursive', '-l', '--files', '--include', '--glob', '-g'];

function looksWholeRepo(command) {
  if (!command || typeof command !== 'string') return false;
  const cmd = command.trim();
  if (!WHOLE_REPO_PATTERNS.some((pattern) => pattern.test(cmd))) return false;

  // A narrowing flag or an explicit path/glob makes the search scoped.
  if (NARROWING_FLAGS.some((flag) => cmd.includes(flag))) return false;
  if (/\s(\.{1,2}\/|\/|[A-Za-z0-9_-]+\/)[A-Za-z0-9_./-]*\s/.test(cmd)) return false;
  if (cmd.includes('."') || cmd.includes("'")) return false;

  return true;
}

export const server = async ({ directory }) => {
  const projectRoot = directory || process.cwd();

  return {
    'tool.execute.before': async (input, output) => {
      const command = output?.args?.command ?? '';
      if (!looksWholeRepo(command)) return;

      throw new Error(
        `[GUARDRAIL] Whole-repository grep blocked ("${String(command).slice(0, 120)}").\n` +
          `Use the graphify MCP server (search_graph / trace_path / get_code_snippet) per ` +
          `.agents/rules/codebase-exploration.md, or narrow the search to a specific path. ` +
          `Project root: ${projectRoot}`,
      );
    },
  };
};

export default { server };
