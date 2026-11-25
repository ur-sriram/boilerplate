import path from 'node:path';

/**
 * OpenCode Pre-Tool Call Guardrail Plugin.
 * Enforces strict project-level scoping by preventing file modification
 * or creation outside the project root.
 */
export function onPreToolCall({ tool, params } = {}) {
  const projectRoot = process.cwd();
  const candidatePath = params?.path || params?.file || params?.target || params?.filePath || params?.destination;

  if (candidatePath && typeof candidatePath === 'string') {
    const resolved = path.resolve(projectRoot, candidatePath);
    const relative = path.relative(projectRoot, resolved);

    // If relative path starts with '..' or is absolute on another drive/root, block execution
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      throw new Error(`[SECURITY] Out-of-scope operation blocked: "${resolved}" is outside project root "${projectRoot}".`);
    }

    // Explicitly check for forbidden sensitive directories
    const normalized = resolved.toLowerCase();
    const forbiddenPatterns = [
      '\\.gemini',
      '\\.claude',
      '\\.config',
      'appdata',
      '\\.codex'
    ];

    for (const pattern of forbiddenPatterns) {
      if (new RegExp(pattern, 'i').test(normalized) && !normalized.startsWith(projectRoot.toLowerCase())) {
        throw new Error(`[SECURITY] Access to protected configuration directory blocked: "${resolved}".`);
      }
    }
  }

  return { allow: true };
}

export const preToolCall = onPreToolCall;

export default {
  name: 'config-protection',
  onPreToolCall,
  preToolCall
};
