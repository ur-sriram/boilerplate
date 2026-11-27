import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import { MemoryStore, findProjectRoot, redactSecrets } from './feature.ts';
import { terms } from './scoring.ts';
import { normalizeConcept, normalizeType } from './feature.types.ts';

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

  const result = store.remember({
    type: 'decision',
    title: 'Adopt feature-folder architecture',
    body: 'All capabilities live under src/features/<name>/.',
    concepts: ['why-it-exists'],
    tags: ['architecture'],
    sessionId: 'session-1',
  });

  assert.equal(result.status, 'stored');
  assert.equal(result.entry.type, 'decision');
  assert.deepEqual(result.entry.concepts, ['why-it-exists']);
  assert.deepEqual(result.entry.tags, ['architecture']);
  assert.ok(fs.existsSync(path.join(root, '.agents', 'memory', 'episodes.jsonl')));

  const stored = store.read();
  assert.equal(stored.length, 1);
  assert.equal(stored[0]?.title, 'Adopt feature-folder architecture');
  assert.equal(stored[0]?.sessionId, 'session-1');
});

test('the upstream taxonomy is accepted and unknown types are rejected', () => {
  assert.equal(normalizeType('bugfix'), 'bugfix');
  assert.equal(normalizeType('security_alert'), 'security_alert');
  assert.equal(normalizeType('sensitive'), 'sensitive');
  assert.equal(normalizeType('not-a-type'), null);

  // Types written before the taxonomy was aligned with upstream still read.
  assert.equal(normalizeType('fact'), 'discovery');
  assert.equal(normalizeType('preference'), 'decision');
  assert.equal(normalizeType('recovery'), 'bugfix');

  assert.equal(normalizeConcept('gotcha'), 'gotcha');
  assert.equal(normalizeConcept('pattern'), 'pattern');
  assert.equal(normalizeConcept('nonsense'), null);

  const { store } = createStore();
  assert.throws(
    () => store.remember({ type: 'nope' as never, title: 'x', body: '' }),
    /Unknown memory type/,
  );
});

test('remember redacts credentials before writing them', () => {
  const { store } = createStore();

  store.remember({
    type: 'security_note',
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

test('terms keeps every comparable token', () => {
  assert.deepEqual(terms('Use the AST graph!'), ['use', 'the', 'ast', 'graph']);
  assert.deepEqual(terms('a b c'), ['a', 'b', 'c']);
});

test('recall returns compact index rows without the body', () => {
  const { store } = createStore();
  store.remember({
    type: 'discovery',
    title: 'Graphify is the default knowledge graph server',
    body: 'A body long enough that it would dominate a printed index row.',
  });

  const rows = store.recall({ text: 'graphify' });
  assert.equal(rows.length, 1);
  assert.equal(rows[0]?.title, 'Graphify is the default knowledge graph server');
  assert.equal('body' in (rows[0] as object), false);

  // Step 3 of the contract: the details are fetched only for a chosen id.
  const full = store.get(rows[0]?.id ?? '');
  assert.match(full?.body ?? '', /dominate/);
});

test('an exact title match merges into the existing episode', () => {
  const { store } = createStore();

  const first = store.remember({
    type: 'decision',
    title: 'Lock the core MCP profile to graphify',
    body: 'Original reasoning.',
  });
  const second = store.remember({
    type: 'decision',
    title: 'lock the core mcp profile to graphify',
    body: 'Sharper reasoning.',
  });

  assert.equal(first.status, 'stored');
  assert.equal(second.status, 'merged');
  assert.equal(second.entry.id, first.entry.id);
  assert.equal(second.entry.body, 'Sharper reasoning.');
  assert.equal(store.read().length, 1);
});

test('a near-duplicate is reported as a candidate and never silently merged', () => {
  const { store } = createStore();

  const first = store.remember({
    type: 'discovery',
    title: 'The graphify server crashes without the mcp extra',
    body: '',
  });
  const second = store.remember({
    type: 'discovery',
    title: 'The graphify server crashes without the mcp extra flag',
    body: '',
  });

  assert.equal(first.status, 'stored');
  assert.equal(second.status, 'candidate');
  assert.equal(second.duplicateOf, first.entry.id);
  // The new episode was NOT written, and the existing one was NOT changed.
  assert.equal(store.read().length, 1);
  assert.equal(store.read()[0]?.body, '');
});

test('a different episode is not mistaken for a duplicate', () => {
  const { store } = createStore();

  store.remember({ type: 'discovery', title: 'The graphify server crashes without the mcp extra', body: '' });
  const other = store.remember({
    type: 'discovery',
    title: 'The user prefers vitest over jest for unit tests',
    body: '',
  });

  assert.equal(other.status, 'stored');
  assert.equal(store.read().length, 2);
});

test('ranking weights a rare term above a term every episode shares', () => {
  const { store } = createStore();

  // Three episodes share "the"; only one mentions "graphify". The shared
  // episodes are written LAST, so a date tie-break would put them first.
  store.remember({ type: 'discovery', title: 'The graphify server builds the knowledge graph', body: '' });
  store.remember({ type: 'discovery', title: 'The readme explains the layout of the project', body: '' });
  store.remember({ type: 'discovery', title: 'The agent index lists the rules of the project', body: '' });

  const rows = store.recall({ text: 'the graphify' });
  assert.equal(rows.length, 3);
  assert.match(rows[0]?.title ?? '', /graphify server/);
});

test('a term so common it discriminates nothing is ignored', () => {
  const { store } = createStore();

  // 12 episodes share "boilerplate"; the veto drops it from the ranking.
  for (let index = 0; index < 12; index += 1) {
    store.remember({
      type: 'discovery',
      title: `The boilerplate note number ${index} explains the setup`,
      body: '',
    });
  }
  store.remember({
    type: 'discovery',
    title: 'The zebra guide explains the setup',
    body: '',
  });

  assert.deepEqual(store.recall({ text: 'boilerplate' }), []);
  assert.equal(store.recall({ text: 'zebra' }).length, 1);
});

test('recall filters by type, concept and tag', () => {
  const { store } = createStore();

  store.remember({ type: 'bugfix', title: 'Fixed the adapter parity check', body: '', concepts: ['problem-solution'], tags: ['testing'] });
  store.remember({ type: 'feature', title: 'Added the memory sync hook', body: '', concepts: ['what-changed'], tags: ['hooks'] });

  assert.equal(store.recall({ types: ['bugfix'] }).length, 1);
  assert.equal(store.recall({ concepts: ['what-changed'] }).length, 1);
  assert.equal(store.recall({ tags: ['testing'] }).length, 1);
  assert.equal(store.recall({ tags: ['hooks'] }).length, 1);
  assert.equal(store.recall({ limit: 1 }).length, 1);
});

test('sensitive episodes are withheld unless explicitly requested', () => {
  const { store } = createStore();

  store.remember({ type: 'sensitive', title: 'An internal incident note', body: '' });
  store.remember({ type: 'decision', title: 'The public roadmap decision', body: '' });

  const defaultRows = store.recall({ text: 'note' });
  assert.equal(defaultRows.length, 0);

  const withSensitive = store.recall({ text: 'note', includeSensitive: true });
  assert.equal(withSensitive.length, 1);
  assert.equal(withSensitive[0]?.type, 'sensitive');
});

test('timeline returns the episodes around an anchor', () => {
  const { store } = createStore();
  const first = store.remember({ type: 'discovery', title: 'First episode here', body: '' });
  store.remember({ type: 'discovery', title: 'Second episode here', body: '' });
  store.remember({ type: 'discovery', title: 'Third episode here', body: '' });

  const around = store.timeline(first.entry.id, 1);
  assert.equal(around.length, 2);
  assert.equal(around[0]?.id, first.entry.id);
});

test('a session is opened, attributed to, and grouped by', () => {
  const { store } = createStore();

  const session = store.openSession();
  assert.ok(fs.existsSync(store.sessionPath));

  const entry = store.remember({ type: 'decision', title: 'Recorded inside a session', body: '' });
  assert.equal(entry.entry.sessionId, session.id);

  const sessions = store.sessions();
  assert.equal(sessions.length, 1);
  assert.equal(sessions[0]?.id, session.id);
  assert.equal(sessions[0]?.episodes, 1);
  assert.equal(sessions[0]?.startedAt, session.startedAt);
});

test('episodes written without an open session are attributed to manual', () => {
  const { store } = createStore();
  const entry = store.remember({ type: 'fact' as never, title: 'x', body: '' });
  assert.equal(entry.entry.sessionId, 'manual');
});

test('a corrupt line is skipped instead of breaking the store', () => {
  const { store } = createStore();
  store.remember({ type: 'fact' as never, title: 'Valid episode', body: '' });
  fs.appendFileSync(store.storePath, '{not json\n', 'utf8');

  const entries = store.read();
  assert.equal(entries.length, 1);
  assert.equal(entries[0]?.title, 'Valid episode');
});

test('the store is pruned to the configured maximum', () => {
  const { store } = createStore(3);

  for (let index = 0; index < 6; index += 1) {
    store.remember({ type: 'discovery', title: `Episode ${index}`, body: '' });
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

test('stats reports the episode count, the types and the session count', () => {
  const { store } = createStore();

  store.remember({ type: 'decision', title: 'One', body: '' });
  store.remember({ type: 'decision', title: 'Two', body: '' });
  store.remember({ type: 'bugfix', title: 'Three', body: '' });

  const stats = store.stats();
  assert.equal(stats.entries, 3);
  assert.equal(stats.types['decision'], 2);
  assert.equal(stats.types['bugfix'], 1);
});
