import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

/**
 * OpenCode session-start plugin.
 *
 * Mirrors scripts/hooks/session-start.sh: validates the local runtimes and
 * prints a short readiness summary when a session begins.
 *
 * WHY THE DEFAULT EXPORT LOOKS LIKE THIS
 * --------------------------------------
 * OpenCode loads every `.opencode/plugins/*.{js,ts}` file as a *path plugin*.
 * The loader contract (verified against opencode 1.19.6) requires the module's
 * DEFAULT export to be an object carrying a non-empty string `id` and a
 * `server()` function. The previous revision exported a bare
 * `export const server = ...`, so OpenCode rejected the file with
 * "Path plugin ... must export id" and the banner never printed.
 *
 * The previous revision also only *claimed* the runtimes were validated and
 * pointed at the shell script. This version actually runs the same checks.
 */

const RUNTIMES = ['git', 'node', 'python3', 'sh'];

/** Resolve an executable on PATH without shelling out. */
function which(command) {
  const probe = process.platform === 'win32' ? 'where' : 'which';
  const result = spawnSync(probe, [command], {
    timeout: 2000,
    encoding: 'utf-8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });

  if (result.status !== 0 || !result.stdout) return null;
  return result.stdout.split(/\r?\n/)[0].trim() || null;
}

function buildReport(projectRoot) {
  const lines = ['=== Boilerplate Agent Session Initialization ===', `Project Root: ${projectRoot}`];

  for (const runtime of RUNTIMES) {
    const location = which(runtime);
    lines.push(location ? `[OK] ${runtime}: ${location}` : `[WARN] ${runtime}: Not found in PATH`);
  }

  const rtk = which('rtk');
  lines.push(
    rtk
      ? `[OK] rtk compressor: Present (${rtk})`
      : '[INFO] rtk compressor: Absent (graceful passthrough active)',
  );

  const skills = path.join(projectRoot, '.agents', 'skills');
  lines.push(
    fs.existsSync(skills)
      ? '[OK] Canonical Skills Store: Present (.agents/skills)'
      : '[INFO] Canonical Skills Store: Pending (.agents/skills)',
  );

  lines.push('=== Initialization Complete (Ready for Agent Tasks) ===');
  return lines.join('\n');
}

export default {
  id: 'boilerplate-session-start',

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
        console.log(buildReport(projectRoot));
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
      console.log(buildReport(projectRoot));
    });
  },
};
