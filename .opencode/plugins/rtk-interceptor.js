import { spawnSync } from 'node:child_process';

/**
 * OpenCode Terminal Output Compressor Plugin.
 * Intercepts terminal command outputs and pipes them through the `rtk` (Rust Token Killer)
 * binary when available to reduce token consumption by 60-90%.
 * If `rtk` is not installed or fails, passes output through safely without disruption.
 */
export function onTerminalOutput({ command, stdout = '', stderr = '' } = {}) {
  try {
    // Check if rtk executable exists in PATH
    const probeCmd = process.platform === 'win32' ? 'where' : 'which';
    const probe = spawnSync(probeCmd, ['rtk'], {
      timeout: 1000,
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'ignore']
    });

    if (probe.status !== 0 || !probe.stdout) {
      // Graceful fallback: rtk is not installed
      return { stdout, stderr };
    }

    // Only filter non-empty stdout
    if (stdout && typeof stdout === 'string' && stdout.trim().length > 0) {
      const filter = spawnSync('rtk', ['filter'], {
        input: stdout,
        timeout: 5000,
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      });

      if (filter.status === 0 && filter.stdout) {
        return {
          stdout: filter.stdout,
          stderr
        };
      }
    }

    return { stdout, stderr };
  } catch (_error) {
    // Non-crashing zero-disruption passthrough
    return { stdout, stderr };
  }
}

export const postTerminalOutput = onTerminalOutput;

export default {
  name: 'rtk-interceptor',
  onTerminalOutput,
  postTerminalOutput
};
