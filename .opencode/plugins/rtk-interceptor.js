import { spawnSync } from 'node:child_process';

/**
 * OpenCode terminal output compressor.
 *
 * Pipes terminal command output through the `rtk` (Rust Token Killer) binary
 * when available, reducing output tokens by 60-90%. If rtk is missing or
 * fails, the output passes through untouched.
 *
 * OpenCode plugin contract (V1): the hook is `tool.execute.after`.
 */
export const server = async () => {
  const probeCmd = process.platform === 'win32' ? 'where' : 'which';

  return {
    'tool.execute.after': async (input, output) => {
      const stdout = output?.output ?? output?.stdout ?? '';
      if (typeof stdout !== 'string' || stdout.trim().length === 0) return;

      const probe = spawnSync(probeCmd, ['rtk'], {
        timeout: 1000,
        encoding: 'utf-8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });

      if (probe.status !== 0 || !probe.stdout) return; // graceful passthrough

      const filter = spawnSync('rtk', ['filter'], {
        input: stdout,
        timeout: 5000,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      if (filter.status === 0 && filter.stdout && output) {
        output.output = filter.stdout;
      }
    },
  };
};

export default { server };
