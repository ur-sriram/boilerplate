#!/usr/bin/env node
/**
 * claude-mem launcher and runtime guard.
 *
 * WHY A SEPARATE PLAIN-JS ENTRY POINT
 * The CLI is TypeScript and runs directly under Node, which needs the type
 * stripping that ships by default from Node 22.18. On an older runtime the
 * failure happens while the module graph is being loaded — before any code
 * in cli.ts runs — so it surfaces as an opaque
 * `TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".ts"`.
 *
 * A guard written in TypeScript could never report that, because it would
 * fail to load for exactly the same reason. This launcher is plain ESM
 * JavaScript, so it loads on every runtime the project supports, and it can
 * explain the problem instead of letting it disappear into an advisory hook
 * that never fails.
 *
 * It is also the single entry point for every caller: the POSIX hook, the
 * PowerShell hook, the cross-platform dispatcher and the OpenCode plugin all
 * go through it, so they cannot disagree about the runtime requirement.
 *
 * Usage:
 *   node run.mjs remember --kind decision --title "…" [--body "…"] [--tags a,b]
 *   node run.mjs recall   [--text "…"] [--tags a,b] [--limit 5]
 *   node run.mjs list     [--limit 10]
 *   node run.mjs stats
 *   node run.mjs sync     [--root <project-root>] [--limit 5]
 */

import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const MIN_MAJOR = 22;
const MIN_MINOR = 18;
const HERE = path.dirname(fileURLToPath(import.meta.url));

/** Is this runtime new enough to strip TypeScript types without a flag? */
function runtimeSupportsTypeStripping() {
  const [major, minor] = process.versions.node.split('.').map(Number);
  return major > MIN_MAJOR || (major === MIN_MAJOR && minor >= MIN_MINOR);
}

if (!runtimeSupportsTypeStripping()) {
  process.stderr.write(
    `[MEMORY] claude-mem needs Node >= ${MIN_MAJOR}.${MIN_MINOR}.0 ` +
      `(TypeScript type stripping); this runtime is ${process.version}.\n` +
      '[MEMORY] Upgrade Node.js (https://nodejs.org/) to enable episodic memory.\n',
  );
  process.exit(0);
}

const result = spawnSync(
  process.execPath,
  [path.join(HERE, 'cli.ts'), ...process.argv.slice(2)],
  { stdio: 'inherit' },
);

process.exit(result.status ?? 0);
