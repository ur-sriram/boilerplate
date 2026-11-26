import { spawnSync } from 'node:child_process';

/**
 * OpenCode terminal output compressor.
 *
 * Pipes terminal command output through the `rtk` (Rust Token Killer) binary
 * when available, reducing output tokens by 60-90%. If rtk is missing or
 * fails, the output passes through untouched.
 *
 * WHY THE DEFAULT EXPORT LOOKS LIKE THIS
 * --------------------------------------
 * OpenCode loads every `.opencode/plugins/*.{js,ts}` file as a *path plugin*.
 * The loader contract (verified against opencode 1.19.6) requires the module's
 * DEFAULT export to be an object carrying a non-empty string `id` and a
 * `server()` function. The previous revision exported a bare
 * `export const server = ...`, so OpenCode rejected the file with
 * "Path plugin ... must export id" and the compressor never ran.
 */

let rtkAvailable = null;

/** Probe for the rtk binary once and remember the answer. */
function hasRtk() {
  if (rtkAvailable !== null) return rtkAvailable;

  const probeCmd = process.platform === 'win32' ? 'where' : 'which';
  const probe = spawnSync(probeCmd, ['rtk'], {
    timeout: 1000,
    encoding: 'utf-8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });

  rtkAvailable = probe.status === 0 && Boolean(probe.stdout);
  return rtkAvailable;
}

/** Run `rtk filter` over the text; returns null when it cannot be used. */
function compress(text) {
  if (!hasRtk()) return null;

  const filter = spawnSync('rtk', ['filter'], {
    input: text,
    timeout: 5000,
    encoding: 'utf-8',
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  if (filter.status !== 0 || !filter.stdout) return null;
  return filter.stdout;
}

export default {
  id: 'boilerplate-rtk-interceptor',

  /** OpenCode V1 hook surface. */
  async server() {
    return {
      'tool.execute.after': async (input, output) => {
        const stdout = output?.output ?? output?.stdout ?? '';
        if (typeof stdout !== 'string' || stdout.trim().length === 0) return;

        const compressed = compress(stdout);
        if (compressed !== null && output) {
          output.output = compressed;
        }
      },
    };
  },

  /** OpenCode V2 hook surface. */
  async setup(ctx) {
    await ctx.tool.hook('execute.after', async (event) => {
      const result = event?.result;
      if (!result || typeof result !== 'object') return;

      const stdout = result.output ?? result.stdout ?? '';
      if (typeof stdout !== 'string' || stdout.trim().length === 0) return;

      const compressed = compress(stdout);
      if (compressed !== null) {
        event.result = { ...result, output: compressed };
      }
    });
  },
};
