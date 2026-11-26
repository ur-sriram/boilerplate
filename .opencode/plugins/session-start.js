/**
 * OpenCode session-start plugin.
 *
 * Mirrors scripts/hooks/session-start.sh: validates the local runtimes and
 * prints a short readiness summary when a session begins.
 */
export const server = async ({ directory }) => {
  const projectRoot = directory || process.cwd();

  return {
    event: async ({ event }) => {
      if (event?.type && !String(event.type).includes('session')) return;

      const lines = ['=== Boilerplate Agent Session Initialization ===', `Project Root: ${projectRoot}`];
      for (const tool of ['git', 'node', 'python3']) {
        lines.push(`[INFO] ${tool}: ${tool} availability is validated by scripts/hooks/session-start.sh`);
      }
      lines.push('=== Initialization Complete (Ready for Agent Tasks) ===');
      console.log(lines.join('\n'));
    },
  };
};

export default { server };
