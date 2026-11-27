#!/usr/bin/env node
/**
 * Claude-Mem command line interface.
 *
 * Used by the lifecycle hook (`scripts/hooks/run-hook.mjs memory-sync`,
 * `scripts/hooks/memory-sync.sh`, `scripts/hooks/memory-sync.ps1`) and by
 * agents that want to record or recall an episode by hand.
 *
 * The retrieval commands follow upstream's three-step contract
 * (`src/servers/mcp-server.ts`, `important_workflow`):
 *
 *   1. search    -> compact index rows with ids
 *   2. timeline  -> the episodes around an interesting result
 *   3. get       -> the full record for the ids that were chosen
 *
 * An index row is roughly a tenth of a full record, so an agent pays for
 * details only on the episodes it actually reads.
 *
 * Usage:
 *   node cli.ts remember --type decision --title "…" [--body "…"]
 *                        [--concepts gotcha,pattern] [--tags a,b] [--session id]
 *   node cli.ts search   [--text "…"] [--types a,b] [--concepts a,b] [--tags a,b]
 *                        [--limit 5] [--include-sensitive]
 *   node cli.ts get      <id> [<id> …]
 *   node cli.ts timeline <id> [--depth 3]
 *   node cli.ts list     [--limit 10]
 *   node cli.ts sessions
 *   node cli.ts stats
 *   node cli.ts sync     [--root <project-root>] [--limit 5]
 *
 * `sync` is the hook entry point: it opens a session, prints a short summary
 * and surfaces the most recent episodes as session context.
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { MemoryStore, findProjectRoot } from './feature.ts';
import {
  MEMORY_CONCEPTS,
  MEMORY_TYPES,
  normalizeConcept,
  normalizeType,
  type MemoryConcept,
  type MemoryType,
} from './feature.types.ts';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_ROOT = findProjectRoot(SCRIPT_DIR);

function parseArgs(argv: readonly string[]): { flags: Record<string, string>; positional: string[] } {
  const flags: Record<string, string> = {};
  const positional: string[] = [];

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token) continue;
    if (!token.startsWith('--')) {
      positional.push(token);
      continue;
    }
    const key = token.slice(2);
    const next = argv[index + 1];
    if (next === undefined || next.startsWith('--')) {
      flags[key] = 'true';
    } else {
      flags[key] = next;
      index += 1;
    }
  }
  return { flags, positional };
}

function splitList(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseTypes(value: string | undefined): MemoryType[] {
  const types: MemoryType[] = [];
  for (const raw of splitList(value)) {
    const normalized = normalizeType(raw);
    if (!normalized) {
      throw new Error(
        `Unknown type '${raw}'. Expected one of: ${MEMORY_TYPES.join(', ')}`,
      );
    }
    types.push(normalized);
  }
  return types;
}

function parseConcepts(value: string | undefined): MemoryConcept[] {
  const concepts: MemoryConcept[] = [];
  for (const raw of splitList(value)) {
    const normalized = normalizeConcept(raw);
    if (!normalized) {
      throw new Error(
        `Unknown concept '${raw}'. Expected one of: ${MEMORY_CONCEPTS.join(', ')}`,
      );
    }
    concepts.push(normalized);
  }
  return concepts;
}

function formatIndexRow(row: {
  id: string;
  type: string;
  title: string;
  concepts: readonly string[];
  tags: readonly string[];
}): string {
  const concepts = row.concepts.length > 0 ? ` [${row.concepts.join(',')}]` : '';
  const tags = row.tags.length > 0 ? ` {${row.tags.join(',')}}` : '';
  return `  ${row.id.slice(0, 8)}  ${row.type}${concepts}${tags}  ${row.title}`;
}

function formatFullEntry(entry: {
  id: string;
  type: string;
  title: string;
  body: string;
  concepts: readonly string[];
  tags: readonly string[];
  sessionId: string;
  createdAt: string;
  updatedAt?: string;
}): string {
  const lines = [
    `  id        : ${entry.id}`,
    `  type      : ${entry.type}`,
    `  concepts  : ${entry.concepts.join(', ') || '-'}`,
    `  tags      : ${entry.tags.join(', ') || '-'}`,
    `  session   : ${entry.sessionId}`,
    `  created   : ${entry.createdAt}`,
  ];
  if (entry.updatedAt) lines.push(`  updated   : ${entry.updatedAt}`);
  lines.push(`  title     : ${entry.title}`);
  if (entry.body) lines.push(`  body      : ${entry.body}`);
  return lines.join('\n');
}

function main(): number {
  const argv = process.argv.slice(2);
  const command = argv[0] ?? 'sync';
  const { flags, positional } = parseArgs(argv.slice(1));
  const root = path.resolve(flags['root'] ?? DEFAULT_ROOT);
  const store = new MemoryStore({ root });

  switch (command) {
    case 'remember': {
      const type = flags['type'] ?? 'discovery';
      const normalized = normalizeType(type);
      if (!normalized) {
        process.stderr.write(
          `[MEMORY] Unknown type '${type}'. Expected one of: ${MEMORY_TYPES.join(', ')}\n`,
        );
        return 1;
      }
      if (!flags['title']) {
        process.stderr.write('[MEMORY] remember requires --title\n');
        return 1;
      }

      const result = store.remember({
        type: normalized,
        title: flags['title'],
        body: flags['body'] ?? '',
        concepts: parseConcepts(flags['concepts']),
        tags: splitList(flags['tags']),
        ...(flags['session'] ? { sessionId: flags['session'] } : {}),
      });

      if (result.status === 'candidate') {
        process.stdout.write(
          `[MEMORY] Not stored: a near-duplicate exists (${result.duplicateOf?.slice(0, 8)}). ` +
            'Use `get` to compare, then record a distinct episode.\n',
        );
        return 0;
      }
      if (result.status === 'merged') {
        process.stdout.write(`[MEMORY] Merged into existing episode: ${result.entry.title}\n`);
        return 0;
      }
      process.stdout.write(`[MEMORY] Stored ${result.entry.type}: ${result.entry.title}\n`);
      return 0;
    }

    case 'search':
    case 'recall': {
      const limit = Number.parseInt(flags['limit'] ?? '5', 10);
      const rows = store.recall({
        ...(flags['text'] ? { text: flags['text'] } : {}),
        types: parseTypes(flags['types']),
        concepts: parseConcepts(flags['concepts']),
        tags: splitList(flags['tags']),
        limit: Number.isNaN(limit) ? 5 : limit,
        includeSensitive: flags['include-sensitive'] === 'true',
      });

      if (rows.length === 0) {
        process.stdout.write('[MEMORY] No episodes matched.\n');
        return 0;
      }
      process.stdout.write(`[MEMORY] ${rows.length} episode(s) matched:\n`);
      for (const row of rows) process.stdout.write(`${formatIndexRow(row)}\n`);
      process.stdout.write('[MEMORY] Fetch details with: get <id>\n');
      return 0;
    }

    case 'get': {
      if (positional.length === 0) {
        process.stderr.write('[MEMORY] get requires at least one id\n');
        return 1;
      }
      for (const id of positional) {
        const entry = store.get(id) ?? store.read().find((item) => item.id.startsWith(id));
        if (!entry) {
          process.stdout.write(`[MEMORY] No episode with id '${id}'.\n`);
          continue;
        }
        process.stdout.write(`${formatFullEntry(entry)}\n\n`);
      }
      return 0;
    }

    case 'timeline': {
      const anchor = positional[0];
      if (!anchor) {
        process.stderr.write('[MEMORY] timeline requires an anchor id\n');
        return 1;
      }
      const depth = Number.parseInt(flags['depth'] ?? '3', 10);
      const entry = store.get(anchor) ?? store.read().find((item) => item.id.startsWith(anchor));
      if (!entry) {
        process.stdout.write(`[MEMORY] No episode with id '${anchor}'.\n`);
        return 0;
      }
      const around = store.timeline(entry.id, Number.isNaN(depth) ? 3 : depth);
      process.stdout.write(`[MEMORY] ${around.length} episode(s) around ${entry.id.slice(0, 8)}:\n`);
      for (const item of around) {
        const marker = item.id === entry.id ? '>' : ' ';
        process.stdout.write(`${marker} ${formatIndexRow(item)}\n`);
      }
      return 0;
    }

    case 'list': {
      const limit = Number.parseInt(flags['limit'] ?? '10', 10);
      const rows = store.list(Number.isNaN(limit) ? 10 : limit);
      process.stdout.write(`[MEMORY] ${rows.length} most recent episode(s):\n`);
      for (const row of rows) process.stdout.write(`${formatIndexRow(row)}\n`);
      return 0;
    }

    case 'sessions': {
      const sessions = store.sessions();
      process.stdout.write(`[MEMORY] ${sessions.length} session(s):\n`);
      for (const session of sessions) {
        const started = session.startedAt ? ` started ${session.startedAt}` : '';
        process.stdout.write(
          `  ${session.id}  ${session.episodes} episode(s)${started}\n`,
        );
      }
      return 0;
    }

    case 'stats': {
      const stats = store.stats();
      process.stdout.write(`[MEMORY] ${stats.entries} episode(s) in ${stats.path}\n`);
      for (const [type, count] of Object.entries(stats.types)) {
        process.stdout.write(`  - ${type}: ${count}\n`);
      }
      return 0;
    }

    case 'sync': {
      const limit = Number.parseInt(flags['limit'] ?? '5', 10);
      const session = store.openSession();
      const stats = store.stats();
      process.stdout.write(
        `[MEMORY] claude-mem episodic store at ${stats.path} (${stats.entries} episode(s), ${stats.sessions} session(s))\n`,
      );
      process.stdout.write(`[MEMORY] Session ${session.id} started ${session.startedAt}\n`);
      const rows = store.list(Number.isNaN(limit) ? 5 : limit);
      if (rows.length > 0) {
        process.stdout.write('[MEMORY] Recent episodes:\n');
        for (const row of rows) process.stdout.write(`${formatIndexRow(row)}\n`);
      }
      return 0;
    }

    default:
      process.stderr.write(
        `[MEMORY] Unknown command '${command}'. Expected: remember, search, get, timeline, list, sessions, stats, sync\n`,
      );
      return 1;
  }
}

try {
  process.exit(main());
} catch (error) {
  // A memory hook must never crash the host session.
  const message = (error as Error).message ?? String(error);

  // The CLI is TypeScript and runs directly under Node, so it needs the
  // type stripping that ships by default from Node 22.18. On an older
  // runtime the failure is an opaque ERR_UNKNOWN_FILE_EXTENSION — say what
  // actually went wrong instead.
  if (message.includes('ERR_UNKNOWN_FILE_EXTENSION') || message.includes('Unknown file extension')) {
    process.stderr.write(
      `[MEMORY] claude-mem needs Node >= 22.18.0 (TypeScript type stripping); this runtime is ${process.version}.\n`,
    );
  } else {
    process.stderr.write(`[MEMORY] claude-mem failed: ${message}\n`);
  }
  process.exit(0);
}
