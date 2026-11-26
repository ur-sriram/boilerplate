#!/usr/bin/env node
/**
 * Cross-platform lifecycle hook dispatcher.
 *
 * WHY THIS EXISTS
 * Every adapter except Antigravity used to invoke `powershell -File ...ps1`,
 * so on Linux/macOS — the platform the README's own bootstrap instructions
 * target — none of the guardrails ran at all. This dispatcher implements the
 * three hooks in Node.js (already a hard requirement of this repository), so a
 * single command string works identically on Windows, macOS and Linux:
 *
 *     node ./scripts/hooks/run-hook.mjs protect-config
 *     node ./scripts/hooks/run-hook.mjs rtk-filter
 *     node ./scripts/hooks/run-hook.mjs session-start
 *
 * The .ps1/.sh twins remain the reference implementations and are still used
 * by Antigravity (which supports a POSIX-specific command field).
 *
 * EXIT CODES
 *   protect-config : 0 = allowed, 1 = blocked (outside project root)
 *   rtk-filter     : 0 = always (pass-through fallback is guaranteed)
 *   session-start  : 0 = always (diagnostic only)
 */

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(SCRIPT_DIR, '..', '..');

// ---------------------------------------------------------------------------
// protect-config (PreToolUse)
// ---------------------------------------------------------------------------

/** Resolve a path physically (following symlinks) when it exists. */
function physicalPath(target) {
  try {
    return fs.realpathSync(target);
  } catch {
    // Path may not exist yet: resolve the deepest existing ancestor and
    // re-append the remainder so a brand-new file still resolves correctly.
    let current = path.resolve(target);
    const tail = [];
    while (!fs.existsSync(current)) {
      const parent = path.dirname(current);
      if (parent === current) return path.resolve(target);
      tail.unshift(path.basename(current));
      current = parent;
    }
    try {
      return path.join(fs.realpathSync(current), ...tail);
    } catch {
      return path.resolve(target);
    }
  }
}

/** Extract the tool target path from a hook payload. */
function extractTargetPath(payload) {
  if (!payload) return '';
  let data;
  try {
    data = JSON.parse(payload);
  } catch {
    return String(payload).trim();
  }
  if (!data || typeof data !== 'object') return '';

  const keys = ['path', 'file', 'target', 'target_path', 'filePath'];
  for (const key of keys) {
    if (typeof data[key] === 'string' && data[key].trim()) return data[key].trim();
  }
  const params = data.params && typeof data.params === 'object' ? data.params : {};
  for (const key of keys) {
    if (typeof params[key] === 'string' && params[key].trim()) return params[key].trim();
  }
  return '';
}

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch {
    return '';
  }
}

function hookProtectConfig() {
  const argv = process.argv.slice(2);
  const explicit = argv[1] && argv[1] !== '-' ? argv[1] : '';
  const payload = explicit || readStdin();
  const target = extractTargetPath(payload);

  // No target path (read-only/status commands) => allow.
  if (!target) return 0;

  let resolvedTarget = target;
  if (resolvedTarget === '~') {
    resolvedTarget = process.env.HOME || process.env.USERPROFILE || resolvedTarget;
  } else if (resolvedTarget.startsWith('~/')) {
    const home = process.env.HOME || process.env.USERPROFILE || '';
    resolvedTarget = path.join(home, resolvedTarget.slice(2));
  }

  const absolute = path.isAbsolute(resolvedTarget)
    ? path.resolve(resolvedTarget)
    : path.resolve(REPO_ROOT, resolvedTarget);

  const physicalRoot = physicalPath(REPO_ROOT);
  const physicalTarget = physicalPath(absolute);

  const inside = (candidate, root) =>
    candidate === root || candidate.startsWith(root + path.sep);

  if (inside(physicalTarget, physicalRoot) || inside(absolute, path.resolve(REPO_ROOT))) {
    return 0;
  }

  process.stderr.write(
    `[GUARDRAIL] Access Denied: Target path '${physicalTarget}' is outside project root '${physicalRoot}'.\n`,
  );
  return 1;
}

// ---------------------------------------------------------------------------
// rtk-filter (PostToolUse)
// ---------------------------------------------------------------------------

function hookRtkFilter() {
  const input = readStdin();
  const probe = spawnSync(process.platform === 'win32' ? 'where' : 'which', ['rtk'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });

  if (probe.status !== 0 || !probe.stdout) {
    // rtk is not installed: pass the output through untouched.
    process.stdout.write(input);
    return 0;
  }

  try {
    const filtered = spawnSync('rtk', ['filter'], {
      input,
      encoding: 'utf8',
      timeout: 5000,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    if (filtered.status === 0 && filtered.stdout) {
      process.stdout.write(filtered.stdout);
      return 0;
    }
  } catch {
    // fall through to passthrough
  }
  process.stdout.write(input);
  return 0;
}

// ---------------------------------------------------------------------------
// session-start (SessionStart)
// ---------------------------------------------------------------------------

function hookSessionStart() {
  const out = (line) => process.stdout.write(`${line}\n`);
  out('=== Boilerplate Agent Session Initialization ===');
  out(`Project Root: ${REPO_ROOT}`);

  for (const cmd of ['git', 'node', 'python3', 'sh']) {
    const probe = spawnSync(process.platform === 'win32' ? 'where' : 'which', [cmd], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    out(probe.status === 0 ? `[OK] ${cmd}: ${probe.stdout.split('\n')[0].trim()}` : `[WARN] ${cmd}: Not found in PATH`);
  }

  const rtk = spawnSync(process.platform === 'win32' ? 'where' : 'which', ['rtk'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });
  out(rtk.status === 0 ? '[OK] rtk compressor: Present' : '[INFO] rtk compressor: Absent (graceful passthrough active)');

  out(
    fs.existsSync(path.join(REPO_ROOT, '.agents', 'skills'))
      ? '[OK] Canonical Skills Store: Present (.agents/skills)'
      : '[INFO] Canonical Skills Store: Pending (.agents/skills)',
  );
  out('=== Initialization Complete (Ready for Agent Tasks) ===');
  return 0;
}

// ---------------------------------------------------------------------------

const HOOKS = {
  'protect-config': hookProtectConfig,
  'rtk-filter': hookRtkFilter,
  'session-start': hookSessionStart,
};

const hookName = process.argv[2];
const handler = HOOKS[hookName];

if (!handler) {
  process.stderr.write(
    `Unknown hook '${hookName ?? ''}'. Expected one of: ${Object.keys(HOOKS).join(', ')}\n`,
  );
  process.exit(0);
}

try {
  process.exit(handler());
} catch (error) {
  // Never crash a host session because of a guardrail.
  process.stderr.write(`[HOOK-ERROR] ${hookName}: ${error?.message ?? error}\n`);
  process.exit(0);
}
