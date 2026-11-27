import { spawnSync } from 'node:child_process';
import path from 'node:path';

/**
 * OpenCode memory-sync plugin.
 *
 * Recalls the project's cross-session episodic memory (claude-mem) when a
 * session starts, so the agent begins with the decisions, preferences and
 * error recoveries recorded in previous sessions.
 *
 * WHY IT SPAWNS THE LAUNCHER
 * The store lives in .repo/claude-mem/ and is covered by unit tests.
 * This plugin invokes the same launcher that the POSIX, PowerShell and
 * cross-platform dispatcher hooks invoke, so every entry point recalls the
 * same episodes in the same format.
 *
 * The plugin is ADVISORY: a missing store or a missing runtime must never
 * break the session.
 */

const CLI_RELATIVE = path.join('.repo', 'claude-mem', 'run.mjs');

/** Run the claude-mem CLI and return its stdout (empty on any failure). */
function recallEpisodes(projectRoot) {
  const cli = path.join(projectRoot, CLI_RELATIVE);
  const result = spawnSync(process.execPath, [cli, 'sync', '--root', projectRoot], {
    encoding: 'utf8',
    timeout: 10000,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  if (result.status !== 0 || !result.stdout) return '';
  return result.stdout;
}

export default {
  id: 'boilerplate-memory-sync',

  /** OpenCode V1 hook surface. */
  async server({ directory } = {}) {
    const projectRoot = directory || process.cwd();
    let announced = false;

    return {
      event: async ({ event }) => {
        const type = event?.type ? String(event.type) : '';
        if (type && !type.includes('session')) return;
        if (announced) return;
        announced = true;

        const output = recallEpisodes(projectRoot);
        if (output) console.log(output.trimEnd());
      },
    };
  },

  /** OpenCode V2 hook surface. */
  async setup(ctx) {
    const projectRoot = ctx?.location?.directory || process.cwd();
    let announced = false;

    await ctx.event.subscribe(async (event) => {
      const type = event?.type ? String(event.type) : '';
      if (type && !type.includes('session')) return;
      if (announced) return;
      announced = true;

      const output = recallEpisodes(projectRoot);
      if (output) console.log(output.trimEnd());
    });
  },
};
