import { compressWithRtk } from '../../scripts/hooks/rtk-filter.mjs';

/**
 * OpenCode terminal output compressor.
 *
 * Pipes terminal command output through the `rtk` (Rust Token Killer) binary
 * when available, reducing output tokens by 60-90%. If rtk is missing or
 * fails, the output passes through untouched.
 *
 * OpenCode is the one adapter whose hook can REPLACE the tool output, so this
 * is the one place the saving is real: the compressed text becomes the
 * result the model sees.
 *
 * WHY THE DEFAULT EXPORT LOOKS LIKE THIS
 * --------------------------------------
 * OpenCode loads every `.opencode/plugins/*.{js,ts}` file as a *path plugin*.
 * The loader contract (verified against opencode 1.19.6) requires the module's
 * DEFAULT export to be an object carrying a non-empty string `id` and a
 * `server()` function. The previous revision exported a bare
 * `export const server = ...`, so OpenCode rejected the file with
 * "Path plugin ... must export id" and the compressor never ran.
 *
 * The compression itself is shared with the POSIX hook, the PowerShell hook
 * and the cross-platform dispatcher, so the four cannot disagree about what
 * counts as compressed output.
 */

/** Run `rtk filter` over the text; returns null when it cannot be used. */
function compress(text) {
  return compressWithRtk(text);
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
