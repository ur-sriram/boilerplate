/**
 * Claude-Mem episodic memory store.
 *
 * WHY THIS EXISTS
 * ---------------
 * The `claude-mem` skill, `scripts/hooks/memory-sync.{sh,ps1}` and every
 * document that mentions episodic memory described a feature that did not
 * exist: the hook scripts only created a directory and printed a line, no
 * adapter registered them, and no code anywhere wrote or read a memory.
 *
 * This module is the missing implementation. It is deliberately dependency
 * free (Node built-ins only) and strictly project-local: the store lives in
 * `<project-root>/.agents/memory/episodes.jsonl` and the root can never be
 * escaped.
 *
 * FORMAT
 * ------
 * One JSON object per line (JSONL), append-only, newest last:
 *
 *   {"id":"…","kind":"decision","title":"…","body":"…","tags":["…"],
 *    "sessionId":"…","createdAt":"2026-01-01T00:00:00.000Z"}
 *
 * A corrupt line is skipped instead of failing the whole store, so a
 * half-written file can never break a session.
 */

import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

import type {
  MemoryDraft,
  MemoryEntry,
  MemoryQuery,
  MemoryStats,
  MemoryStoreOptions,
} from './feature.types.ts';

const DEFAULT_MAX_ENTRIES = 500;
const DEFAULT_RECALL_LIMIT = 5;
const MEMORY_DIR_SEGMENTS = ['.agents', 'memory'] as const;
const STORE_FILE = 'episodes.jsonl';

/**
 * Secret patterns scrubbed before an episode is written.
 *
 * The invariant "ZERO secrets committed" (AGENTS.md) has to be enforced by
 * code, not by prose — the previous implementation only promised it in a
 * SKILL.md bullet that nothing implemented.
 */
const SECRET_PATTERNS: readonly RegExp[] = [
  /gh[pousr]_[A-Za-z0-9]{16,}/g,
  /sk-[A-Za-z0-9]{16,}/g,
  /AKIA[0-9A-Z]{16}/g,
  /AIza[0-9A-Za-z\-_]{20,}/g,
  /xox[abprs]-[A-Za-z0-9-]{10,}/g,
  /-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g,
  /\bBearer\s+[A-Za-z0-9\-._~+/]{20,}=*/g,
];

/**
 * `api_key=…`, `token: …` and friends. The label and the separator are kept
 * so the reader still sees WHICH secret was removed.
 */
const LABELED_SECRET =
  /\b(api[_-]?key|secret|password|passwd|token)\b(\s*[:=]\s*)["']?[A-Za-z0-9\-._~+/]{8,}["']?/gi;

/** Replace anything that looks like a credential with a marker. */
export function redactSecrets(text: string): string {
  let output = text;
  for (const pattern of SECRET_PATTERNS) {
    output = output.replace(pattern, '[REDACTED]');
  }
  // The labeled pattern is handled separately: a replacer callback receives
  // the capture groups only for the pattern that matched, so sharing one
  // callback across patterns with different arities corrupts the output.
  output = output.replace(
    LABELED_SECRET,
    (_match: string, label: string, separator: string) => `${label}${separator}[REDACTED]`,
  );
  return output;
}

/** Split text into comparable search terms (3+ characters). */
export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((term) => term.length >= 3);
}

/**
 * Locate the project root that owns a given directory.
 *
 * The island lives at `<project-root>/.repo/claude-mem/`, so the root is two
 * levels up. A hard-coded depth is a trap: when the island sat under
 * `src/features/claude-mem/` it was three levels up, and the same arithmetic
 * then pointed the store at the PARENT of the project — outside the root the
 * store promises never to leave. Walking up to the nearest project marker
 * cannot do that.
 *
 * The marker is `AGENTS.md`, which every project bootstrapped from this
 * template has at its root. When it is missing, the island's own layout
 * (`<root>/.repo/claude-mem/`) is the fallback.
 */
export function findProjectRoot(startDir: string): string {
  const start = path.resolve(startDir);
  let dir = start;

  for (let depth = 0; depth < 8; depth += 1) {
    if (fs.existsSync(path.join(dir, 'AGENTS.md'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  return path.resolve(start, '..', '..');
}

function isMemoryEntry(value: unknown): value is MemoryEntry {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Partial<MemoryEntry>;
  return (
    typeof candidate.id === 'string' &&
    typeof candidate.kind === 'string' &&
    typeof candidate.title === 'string' &&
    typeof candidate.body === 'string' &&
    Array.isArray(candidate.tags)
  );
}

export class MemoryStore {
  private readonly root: string;
  private readonly maxEntries: number;

  constructor(options: MemoryStoreOptions) {
    this.root = path.resolve(options.root);
    this.maxEntries = options.maxEntries ?? DEFAULT_MAX_ENTRIES;
  }

  /** `<project-root>/.agents/memory` — always inside the project root. */
  get memoryDir(): string {
    return path.join(this.root, ...MEMORY_DIR_SEGMENTS);
  }

  /** Absolute path of the JSONL store file. */
  get storePath(): string {
    return path.join(this.memoryDir, STORE_FILE);
  }

  /** Persist one episode and return the stored (redacted) entry. */
  remember(draft: MemoryDraft): MemoryEntry {
    const entry: MemoryEntry = {
      id: randomUUID(),
      kind: draft.kind,
      title: redactSecrets(draft.title).trim(),
      body: redactSecrets(draft.body).trim(),
      tags: (draft.tags ?? []).map((tag) => redactSecrets(tag).trim().toLowerCase()).filter(Boolean),
      sessionId: draft.sessionId ?? 'unknown',
      createdAt: new Date().toISOString(),
    };

    fs.mkdirSync(this.memoryDir, { recursive: true });
    fs.appendFileSync(this.storePath, `${JSON.stringify(entry)}\n`, 'utf8');
    this.prune();
    return entry;
  }

  /** Every stored episode, oldest first. Corrupt lines are skipped. */
  read(): MemoryEntry[] {
    if (!fs.existsSync(this.storePath)) return [];

    const raw = fs.readFileSync(this.storePath, 'utf8');
    const entries: MemoryEntry[] = [];
    for (const line of raw.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        const parsed: unknown = JSON.parse(trimmed);
        if (isMemoryEntry(parsed)) entries.push(parsed);
      } catch {
        // A half-written or corrupted line must never break a session.
      }
    }
    return entries;
  }

  /** Newest episodes first. */
  list(limit = DEFAULT_RECALL_LIMIT): MemoryEntry[] {
    return this.read().slice(-limit).reverse();
  }

  /**
   * Retrieve the episodes most relevant to a query.
   *
   * Tag matches are hard filters; free text is a relevance score. Title hits
   * outweigh body hits, so a decision recorded with a sharp title wins over
   * a passing mention in a long body.
   */
  recall(query: MemoryQuery = {}): MemoryEntry[] {
    const limit = query.limit ?? DEFAULT_RECALL_LIMIT;
    const terms = tokenize(query.text ?? '');
    const requiredTags = (query.tags ?? []).map((tag) => tag.trim().toLowerCase());

    const scored = this.read()
      .filter((entry) =>
        requiredTags.length === 0
          ? true
          : requiredTags.every((tag) => entry.tags.includes(tag)),
      )
      .map((entry) => ({ entry, score: this.score(entry, terms) }))
      .filter((candidate) => terms.length === 0 || candidate.score > 0)
      .sort(
        (a, b) =>
          b.score - a.score ||
          b.entry.createdAt.localeCompare(a.entry.createdAt),
      );

    return scored.slice(0, limit).map((candidate) => candidate.entry);
  }

  /** Aggregate view of the store, used by the `stats` command. */
  stats(): MemoryStats {
    const entries = this.read();
    const kinds: Record<string, number> = {};
    for (const entry of entries) {
      kinds[entry.kind] = (kinds[entry.kind] ?? 0) + 1;
    }
    return { path: this.storePath, entries: entries.length, kinds };
  }

  /** Trim the store file to the newest `maxEntries` episodes. */
  private prune(): void {
    const entries = this.read();
    if (entries.length <= this.maxEntries) return;

    const kept = entries.slice(-this.maxEntries);
    fs.writeFileSync(
      this.storePath,
      `${kept.map((entry) => JSON.stringify(entry)).join('\n')}\n`,
      'utf8',
    );
  }

  private score(entry: MemoryEntry, terms: readonly string[]): number {
    if (terms.length === 0) return 1;

    const title = tokenize(entry.title);
    const body = tokenize(entry.body);
    const tags = entry.tags.map((tag) => tag.toLowerCase());

    let score = 0;
    for (const term of terms) {
      if (title.includes(term)) score += 3;
      if (body.includes(term)) score += 1;
      if (tags.some((tag) => tag.includes(term))) score += 2;
    }
    return score;
  }
}
