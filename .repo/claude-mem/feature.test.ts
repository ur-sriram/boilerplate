import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { MemoryStore, findProjectRoot, redactSecrets, tokenize } from './feature.ts';

/**
 * The store writes to a throwaway directory in the OS temp folder. The
 * repository's "never write outside the project root" rule governs agent
 * behaviour, not the sandbox a unit test needs in order to leave the
 * checkout untouched.
 */
function createStore(maxEntries?: number): { store: MemoryStore; root: string } {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-mem-test-'));
  const store = new MemoryStore(maxEntries ? { root, maxEntries } : { root });
  return { store, root };
}

test('remember persists an episode to disk and reads it back', () => {
  const { store, root } = createStore();

  const entry = store.remember({
    kind: 'decision',
    title: 'Adopt feature-folder architecture',
    body: 'All capabilities live under src/features/<name>/.',
    tags: ['architecture'],
    sessionId: 'session-1',
  });

  assert.equal(entry.kind, 'decision');
  assert.deepEqual(entry.tags, ['architecture']);
  assert.ok(fs.existsSync(path.join(root, '.agents', 'memory', 'episodes.jsonl')));

  const stored = store.read();
  assert.equal(stored.length, 1);
  assert.equal(stored[0]?.title, 'Adopt feature-folder architecture');
});

test('remember redacts credentials before writing them', () => {
  const { store } = createStore();

  store.remember({
    kind: 'fact',
    title: 'Deploy uses ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345',
    body: 'token: supersecretvalue1234567890',
  });

  const raw = fs.readFileSync(store.storePath, 'utf8');
  assert.ok(!raw.includes('ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345'));
  assert.ok(!raw.includes('supersecretvalue1234567890'));
  assert.ok(raw.includes('[REDACTED]'));
});

test('redactSecrets scrubs common credential shapes', () => {
  assert.equal(redactSecrets('key sk-abcdefghijklmnopqrstuv'), 'key [REDACTED]');
  assert.equal(redactSecrets('AKIAIOSFODNN7EXAMPLE'), '[REDACTED]');
  assert.equal(
    redactSecrets('-----BEGIN RSA PRIVATE KEY-----\nabc\n-----END RSA PRIVATE KEY-----'),
    '[REDACTED]',
  );
  assert.equal(redactSecrets('a perfectly ordinary sentence'), 'a perfectly ordinary sentence');
});

test('tokenize keeps only comparable search terms', () => {
  assert.deepEqual(tokenize('Use the AST graph!'), ['use', 'the', 'ast', 'graph']);
  assert.deepEqual(tokenize('a b c'), []);
});

test('recall ranks a title match above a passing body mention', () => {
  const { store } = createStore();

  store.remember({
    kind: 'fact',
    title: 'Unrelated note',
    body: 'The graphify server is enabled by default.',
  });
  store.remember({
    kind: 'fact',
    title: 'Graphify is the default knowledge graph server',
    body: 'See docs/architecture/mcp-servers.md.',
  });

  const recalled = store.recall({ text: 'graphify' });
  assert.equal(recalled.length, 2);
  assert.equal(recalled[0]?.title, 'Graphify is the default knowledge graph server');
});

test('recall filters by tag and honours the limit', () => {
  const { store } = createStore();

  store.remember({ kind: 'preference', title: 'Prefer vitest', body: '', tags: ['testing'] });
  store.remember({ kind: 'preference', title: 'Prefer eslint', body: '', tags: ['linting'] });
  store.remember({ kind: 'preference', title: 'Prefer prettier', body: '', tags: ['testing'] });

  const tagged = store.recall({ tags: ['testing'] });
  assert.equal(tagged.length, 2);

  const limited = store.recall({ limit: 1 });
  assert.equal(limited.length, 1);
});

test('recall returns nothing when the query matches no episode', () => {
  const { store } = createStore();
  store.remember({ kind: 'fact', title: 'Kimi config lives in .kimi-code', body: '' });

  assert.deepEqual(store.recall({ text: 'kubernetes' }), []);
});

test('a corrupt line is skipped instead of breaking the store', () => {
  const { store } = createStore();
  store.remember({ kind: 'fact', title: 'Valid episode', body: '' });
  fs.appendFileSync(store.storePath, '{not json\n', 'utf8');

  const entries = store.read();
  assert.equal(entries.length, 1);
  assert.equal(entries[0]?.title, 'Valid episode');
});

test('the store is pruned to the configured maximum', () => {
  const { store } = createStore(3);

  for (let index = 0; index < 6; index += 1) {
    store.remember({ kind: 'fact', title: `Episode ${index}`, body: '' });
  }

  const entries = store.read();
  assert.equal(entries.length, 3);
  assert.equal(entries[2]?.title, 'Episode 5');
});

test('the store never leaves the project root', () => {
  const { store, root } = createStore();

  const relative = path.relative(root, store.storePath);
  assert.ok(!relative.startsWith('..'));
  assert.equal(path.basename(store.storePath), 'episodes.jsonl');
});

test('findProjectRoot walks up to the project marker, never past it', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-mem-root-'));
  fs.writeFileSync(path.join(root, 'AGENTS.md'), '# marker\n');

  const island = path.join(root, '.repo', 'claude-mem');
  fs.mkdirSync(island, { recursive: true });

  // The island sits two levels under the root, but the depth must not matter.
  assert.equal(findProjectRoot(island), root);
  assert.equal(findProjectRoot(path.join(root, '.repo')), root);
  assert.equal(findProjectRoot(root), root);
});

test('findProjectRoot falls back to the island layout when no marker exists', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'claude-mem-nomarker-'));
  const island = path.join(root, '.repo', 'claude-mem');
  fs.mkdirSync(island, { recursive: true });

  // Two levels up is <root> — and crucially NOT the parent of <root>.
  assert.equal(findProjectRoot(island), root);
  assert.notEqual(findProjectRoot(island), path.dirname(root));
});

test('stats reports the episode count and the kind breakdown', () => {
  const { store } = createStore();

  store.remember({ kind: 'decision', title: 'One', body: '' });
  store.remember({ kind: 'decision', title: 'Two', body: '' });
  store.remember({ kind: 'fact', title: 'Three', body: '' });

  const stats = store.stats();
  assert.equal(stats.entries, 3);
  assert.equal(stats.kinds['decision'], 2);
  assert.equal(stats.kinds['fact'], 1);
});
