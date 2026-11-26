/**
 * OpenCode "prefer the knowledge graph" advisor.
 *
 * `.agents/rules/codebase-exploration.md` requires agents to use the
 * Graphify AST graph for code discovery and to fall back to grep only for
 * raw string literals, log messages and configuration values.
 *
 * IMPORTANT - THIS ADVISES, IT DOES NOT BLOCK.
 * The first implementation of this plugin threw an exception for any
 * repository-wide grep. Measurement showed it was wrong in BOTH directions:
 *   - it blocked `grep "foo" src/features/feature.ts`  (a single-file search)
 *   - it allowed `grep -r "foo" .`                      (a true whole-repo scan)
 * because `-r` was treated as a narrowing flag and a trailing path argument
 * was never recognised. Blocking legitimate searches in an autonomous loop is
 * worse than nudging, so the guard now prints a one-line reminder and lets
 * the command run. Hard enforcement of that rule belongs in the prompt layer
 * (.agents/rules/codebase-exploration.md) and in Graphify itself.
 *
 * WHY THE DEFAULT EXPORT LOOKS LIKE THIS
 * --------------------------------------
 * OpenCode loads every `.opencode/plugins/*.{js,ts}` file as a *path plugin*.
 * The loader contract (verified against opencode 1.19.6) requires the module's
 * DEFAULT export to be an object carrying a non-empty string `id` and a
 * `server()` function. The previous revision exported a bare
 * `export const server = ...`, so OpenCode rejected the file with
 * "Path plugin ... must export id" and the advisory never fired.
 */

const SEARCH_COMMANDS = new Set(['grep', 'egrep', 'fgrep', 'rg', 'ripgrep', 'ag', 'ack']);

// Flags that consume the following token as their value.
const FLAGS_WITH_VALUE = new Set([
  '-e', '--regexp', '-m', '--max-count', '-f', '--file',
  '--include', '--exclude', '--include-dir', '--exclude-dir',
  '-g', '--glob', '--type', '-t', '--ignore-case', '-i',
]);

/** Split a command into tokens, honouring single and double quotes. */
function tokenize(command) {
  const tokens = [];
  let current = '';
  let quote = null;

  for (const char of command) {
    if (quote) {
      if (char === quote) quote = null;
      else current += char;
    } else if (char === '"' || char === "'") {
      quote = char;
    } else if (/\s/.test(char)) {
      if (current) {
        tokens.push(current);
        current = '';
      }
    } else {
      current += char;
    }
  }
  if (current) tokens.push(current);
  return tokens;
}

/** Paths that mean "the whole tree". */
function isBroadPath(path) {
  const normalized = path.replace(/\/+$/, '');
  return (
    normalized === '.' ||
    normalized === '..' ||
    normalized === '' ||
    normalized === '/' ||
    normalized === '**'
  );
}

/**
 * Return the broad path of an unbounded search, or null when the search is
 * scoped to specific files/directories.
 */
export function findBroadSearch(command) {
  if (!command || typeof command !== 'string') return null;

  const tokens = tokenize(command.trim());
  if (tokens.length === 0) return null;

  const commandName = tokens[0].split('/').pop();
  if (!SEARCH_COMMANDS.has(commandName)) return null;

  // Drop the command name, then the flags (and the values they consume).
  const positional = [];
  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token.startsWith('-')) {
      if (FLAGS_WITH_VALUE.has(token)) index += 1; // skip the flag's value
      continue;
    }
    positional.push(token);
  }

  // The first positional is the search pattern; everything after it is a path.
  const paths = positional.slice(1);

  // No path at all => the search walks the current directory.
  if (paths.length === 0) return '(current directory)';

  for (const path of paths) {
    if (isBroadPath(path)) return path;
  }
  return null;
}

function advise(command, broad, projectRoot) {
  console.error(
    `[ADVISORY] Repository-wide search detected ("${String(command).slice(0, 120)}"). ` +
      `For code structure use the graphify MCP server (query_graph / get_node / ` +
      `get_neighbors / shortest_path) per .agents/rules/codebase-exploration.md; reserve grep ` +
      `for string literals, log messages and config values. Project root: ${projectRoot}`,
  );
}

export default {
  id: 'boilerplate-headroom-guard',

  /** OpenCode V1 hook surface. */
  async server({ directory } = {}) {
    const projectRoot = directory || process.cwd();

    return {
      'tool.execute.before': async (input, output) => {
        const command = output?.args?.command ?? '';
        const broad = findBroadSearch(command);
        if (!broad) return;
        advise(command, broad, projectRoot);
      },
    };
  },

  /** OpenCode V2 hook surface. */
  async setup(ctx) {
    const projectRoot = ctx?.location?.directory || process.cwd();

    await ctx.tool.hook('execute.before', async (event) => {
      const input = event?.input;
      const command = input && typeof input === 'object' ? input.command : '';
      const broad = findBroadSearch(typeof command === 'string' ? command : '');
      if (!broad) return;
      advise(command, broad, projectRoot);
    });
  },
};
