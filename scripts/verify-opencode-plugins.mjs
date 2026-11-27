#!/usr/bin/env node
/**
 * OpenCode plugin contract verifier.
 *
 * OpenCode loads every file in `.opencode/plugins/` as a *path plugin*. The
 * loader contract (verified against opencode 1.19.6) is:
 *
 *   - the module's DEFAULT export must be an object
 *   - it must carry a non-empty string `id`
 *   - it must carry a `server()` function returning the hook object
 *   - it must NOT carry a `tui()` function alongside `server()`
 *
 * A plugin that breaks this contract is rejected at load time with
 * "failed to load plugin ... must export id" and every hook it defines
 * silently never fires. All five plugins in this repository were in exactly
 * that state until this verifier existed.
 *
 * Beyond the shape, each plugin's hooks are EXERCISED with mock tool calls,
 * so a guardrail that throws on every write - or one that never throws at
 * all - fails here instead of in production.
 *
 * Usage: node scripts/verify-opencode-plugins.mjs
 * Exit codes: 0 = every plugin satisfies the contract, 1 = a failure.
 */

import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { readdir } from 'node:fs/promises';

const ROOT = path.resolve(import.meta.dirname, '..');
const PLUGIN_DIR = path.join(ROOT, '.opencode', 'plugins');

/** The hook each plugin must expose. */
const REQUIRED_HOOKS = {
  'config-protection.js': 'tool.execute.before',
  'headroom-guard.js': 'tool.execute.before',
  'file-size-guard.js': 'tool.execute.before',
  'rtk-interceptor.js': 'tool.execute.after',
  'session-start.js': 'event',
  'memory-sync.js': 'event',
};

const failures = [];

function fail(message) {
  failures.push(message);
}

/** Assert that `fn` rejects; returns the error message, or null on failure. */
async function expectThrow(fn, label) {
  try {
    await fn();
  } catch (error) {
    return error.message;
  }
  fail(`${label}: expected the guard to throw, but it allowed the operation`);
  return null;
}

/** Assert that `fn` does NOT reject. */
async function expectNoThrow(fn, label) {
  try {
    await fn();
  } catch (error) {
    fail(`${label}: expected no error, but it threw: ${error.message}`);
  }
}

async function checkPlugin(file) {
  const module = await import(pathToFileURL(path.join(PLUGIN_DIR, file)).href);
  const plugin = module.default;

  if (!plugin || typeof plugin !== 'object') {
    fail(`${file}: default export must be an object`);
    return null;
  }
  if (typeof plugin.id !== 'string' || plugin.id.trim() === '') {
    fail(`${file}: default export must carry a non-empty string "id"`);
  }
  if (typeof plugin.server !== 'function') {
    fail(`${file}: default export must carry a server() function`);
    return null;
  }
  if (plugin.tui !== undefined) {
    fail(`${file}: default export must not define tui() alongside server()`);
  }

  const hooks = await plugin.server({ directory: ROOT });
  if (!hooks || typeof hooks !== 'object') {
    fail(`${file}: server() must return a hooks object`);
    return null;
  }
  for (const [name, hook] of Object.entries(hooks)) {
    if (typeof hook !== 'function') fail(`${file}: hook "${name}" is not a function`);
  }

  const required = REQUIRED_HOOKS[file];
  if (required && typeof hooks[required] !== 'function') {
    fail(`${file}: missing required hook "${required}"`);
  }

  return hooks;
}

/** Exercise each plugin's hooks with mock tool calls. */
async function exercise(file, hooks) {
  if (!hooks) return;

  if (file === 'config-protection.js') {
    const before = hooks['tool.execute.before'];
    await expectNoThrow(
      () => before({ tool: 'write' }, { args: { filePath: path.join(ROOT, 'src/app/page.tsx') } }),
      'config-protection: in-scope write must be allowed',
    );
    await expectThrow(
      () => before({ tool: 'write' }, { args: { filePath: '/etc/passwd' } }),
      'config-protection: out-of-scope write must be blocked',
    );
    await expectNoThrow(
      () => before({ tool: 'read' }, { args: { filePath: '/etc/hosts' } }),
      'config-protection: reads outside the project must not be blocked',
    );
  }

  if (file === 'file-size-guard.js') {
    const before = hooks['tool.execute.before'];
    const short = { args: { filePath: 'src/app/page.tsx', content: 'const a = 1;\n' } };
    await expectNoThrow(() => before({ tool: 'write' }, short), 'file-size-guard: a small write must be allowed');

    const long = { args: { filePath: 'src/app/page.tsx', content: 'const a = 1;\n'.repeat(401) } };
    await expectThrow(
      () => before({ tool: 'write' }, long),
      'file-size-guard: a write past 400 effective lines must be blocked',
    );
  }

  if (file === 'headroom-guard.js') {
    const before = hooks['tool.execute.before'];
    await expectNoThrow(
      () => before({ tool: 'bash' }, { args: { command: 'grep -r "foo" .' } }),
      'headroom-guard: advising must not block the command',
    );
    await expectNoThrow(
      () => before({ tool: 'bash' }, { args: { command: 'grep "foo" src/app/page.tsx' } }),
      'headroom-guard: a scoped search must not be flagged',
    );
  }

  if (file === 'rtk-interceptor.js') {
    const after = hooks['tool.execute.after'];
    const output = { output: 'a'.repeat(100) };
    await expectNoThrow(() => after({ tool: 'bash' }, output), 'rtk-interceptor: must pass through when rtk is absent');
  }

  if (file === 'session-start.js') {
    const onEvent = hooks.event;
    await expectNoThrow(() => onEvent({ event: { type: 'session.created' } }), 'session-start: session event must not throw');
    await expectNoThrow(() => onEvent({ event: { type: 'file.edited' } }), 'session-start: unrelated event must not throw');
  }

  if (file === 'memory-sync.js') {
    const onEvent = hooks.event;
    await expectNoThrow(() => onEvent({ event: { type: 'session.created' } }), 'memory-sync: session event must not throw');
    await expectNoThrow(() => onEvent({ event: { type: 'file.edited' } }), 'memory-sync: unrelated event must not throw');
  }
}

console.log('OpenCode plugin contract verification');
console.log('-'.repeat(78));

let files = [];
try {
  files = (await readdir(PLUGIN_DIR)).filter((name) => name.endsWith('.js')).sort();
} catch (error) {
  console.log(`[FAIL] cannot read ${PLUGIN_DIR}: ${error.message}`);
  process.exit(1);
}

if (files.length === 0) {
  console.log('[FAIL] no plugins found in .opencode/plugins/');
  process.exit(1);
}

for (const file of files) {
  const before = failures.length;
  let hooks;
  try {
    hooks = await checkPlugin(file);
    await exercise(file, hooks);
  } catch (error) {
    fail(`${file}: threw during verification - ${error.message}`);
  }
  const added = failures.length - before;
  console.log(added === 0 ? `[PASS] ${file}` : `[FAIL] ${file} (${added} problem(s))`);
}

console.log('-'.repeat(78));

if (failures.length > 0) {
  console.log(`[FAIL] ${failures.length} OpenCode plugin contract problem(s):`);
  for (const message of failures) console.log(`  - ${message}`);
  process.exit(1);
}

console.log(`[PASS] All ${files.length} OpenCode plugin(s) satisfy the loader contract.`);
