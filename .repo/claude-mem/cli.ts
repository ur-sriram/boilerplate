#!/usr/bin/env node
/**
 * Claude-Mem command line interface.
 *
 * Used by the lifecycle hook (`scripts/hooks/run-hook.mjs memory-sync`,
 * `scripts/hooks/memory-sync.sh`, `scripts/hooks/memory-sync.ps1`) and by
 * agents that want to record or recall an episode by hand.
 *
 * Usage:
 *   node cli.ts remember --kind decision --title "…" [--body "…"] [--tags a,b] [--session id]
 *   node cli.ts recall   [--text "…"] [--tags a,b] [--limit 5]
 *   node cli.ts list     [--limit 10]
 *   node cli.ts stats
 *   node cli.ts sync     [--root <project-root>] [--limit 5]
 *
 * `sync` is the hook entry point: it verifies the store, prints a short
 * summary and surfaces the most relevant recent episodes.
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { MemoryStore, findProjectRoot } from './feature.ts';
import type { MemoryKind } from './feature.types.ts';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_ROOT = findProjectRoot(SCRIPT_DIR);
const KINDS: readonly MemoryKind[] = ['decision', 'preference', 'recovery', 'fact'];

function parseArgs(argv: readonly string[]): Record<string, string> {
  const args: Record<string, string> = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token || !token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[index + 1];
    if (next === undefined || next.startsWith('--')) {
      args[key] = 'true';
    } else {
      args[key] = next;
      index += 1;
    }
  }
  return args;
}

function splitList(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function formatEntry(entry: { kind: string; title: string; tags: readonly string[] }): string {
  const tags = entry.tags.length > 0 ? ` (tags: ${entry.tags.join(', ')})` : '';
  return `  - [${entry.kind}] ${entry.title}${tags}`;
}

function main(): number {
  const argv = process.argv.slice(2);
  const command = argv[0] ?? 'sync';
  const args = parseArgs(argv.slice(1));
  const root = path.resolve(args['root'] ?? DEFAULT_ROOT);
  const store = new MemoryStore({ root });

  switch (command) {
    case 'remember': {
      const kind = (args['kind'] ?? 'fact') as MemoryKind;
      if (!KINDS.includes(kind)) {
        process.stderr.write(
          `[MEMORY] Unknown kind '${kind}'. Expected one of: ${KINDS.join(', ')}\n`,
        );
        return 1;
      }
      if (!args['title']) {
        process.stderr.write('[MEMORY] remember requires --title\n');
        return 1;
      }
      const entry = store.remember({
        kind,
        title: args['title'],
        body: args['body'] ?? '',
        tags: splitList(args['tags']),
        ...(args['session'] ? { sessionId: args['session'] } : {}),
      });
      process.stdout.write(`[MEMORY] Stored ${entry.kind}: ${entry.title}\n`);
      return 0;
    }

    case 'recall': {
      const limit = Number.parseInt(args['limit'] ?? '5', 10);
      const entries = store.recall({
        ...(args['text'] ? { text: args['text'] } : {}),
        tags: splitList(args['tags']),
        limit: Number.isNaN(limit) ? 5 : limit,
      });
      if (entries.length === 0) {
        process.stdout.write('[MEMORY] No episodes matched.\n');
        return 0;
      }
      process.stdout.write(`[MEMORY] ${entries.length} episode(s) recalled:\n`);
      for (const entry of entries) process.stdout.write(`${formatEntry(entry)}\n`);
      return 0;
    }

    case 'list': {
      const limit = Number.parseInt(args['limit'] ?? '10', 10);
      const entries = store.list(Number.isNaN(limit) ? 10 : limit);
      process.stdout.write(`[MEMORY] ${entries.length} most recent episode(s):\n`);
      for (const entry of entries) process.stdout.write(`${formatEntry(entry)}\n`);
      return 0;
    }

    case 'stats': {
      const stats = store.stats();
      process.stdout.write(`[MEMORY] ${stats.entries} episode(s) in ${stats.path}\n`);
      for (const [kind, count] of Object.entries(stats.kinds)) {
        process.stdout.write(`  - ${kind}: ${count}\n`);
      }
      return 0;
    }

    case 'sync': {
      const limit = Number.parseInt(args['limit'] ?? '5', 10);
      const stats = store.stats();
      process.stdout.write(
        `[MEMORY] claude-mem episodic store at ${stats.path} (${stats.entries} episode(s))\n`,
      );
      const entries = store.list(Number.isNaN(limit) ? 5 : limit);
      if (entries.length > 0) {
        process.stdout.write('[MEMORY] Recent episodes:\n');
        for (const entry of entries) process.stdout.write(`${formatEntry(entry)}\n`);
      }
      return 0;
    }

    default:
      process.stderr.write(
        `[MEMORY] Unknown command '${command}'. Expected: remember, recall, list, stats, sync\n`,
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
