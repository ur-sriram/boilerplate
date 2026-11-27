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
 *   {"id":"…","type":"decision","title":"…","body":"…","concepts":["…"],
 *    "tags":["…"],"sessionId":"…","createdAt":"…"}
 *
 * A corrupt line is skipped instead of failing the whole store, so a
 * half-written file can never break a session.
 *
 * UPSTREAM PARITY
 * ---------------
 * The taxonomy, the dedup tiers, the IDF ranking and the index/detail split
 * follow `thedotmack/claude-mem`. The observer process, the SQLite/Chroma
 * storage, the MCP server and the cloud sync do not: this store is local,
 * dependency-free and needs no model provider.
 */

import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

import type {
  MemoryConcept,
  MemoryDraft,
  MemoryEntry,
  MemoryIndexEntry,
  MemoryQuery,
  MemorySession,
  MemorySessionSummary,
  MemoryStats,
  MemoryStoreOptions,
  RememberResult,
} from './feature.types.ts';
import { normalizeConcept, normalizeType, WITHHELD_TYPES } from './feature.types.ts';
import {
  buildIdfModel,
  jaccard,
  MIN_SHARED_TOKENS,
  NEAR_DUPLICATE_THRESHOLD,
  normalizeTitle,
  sharedTokens,
  terms,
  type IdfModel,
} from './scoring.ts';

const DEFAULT_MAX_ENTRIES = 500;
const DEFAULT_RECALL_LIMIT = 5;
const MEMORY_DIR_SEGMENTS = ['.agents', 'memory'] as const;
const STORE_FILE = 'episodes.jsonl';
const SESSION_FILE = 'session.json';

/**
 * Secret patterns scrubbed before an episode is written.
 *
 * The invariant "ZERO secrets committed" (AGENTS.md) has to be enforced by
 * code, not by prose. Upstream ships redaction as an opt-in
 * (`CLAUDE_MEM_REDACT_ENABLED: false`); this store always redacts, because
 * the store is git-ignored and shared between agents.
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

/** Strip the body from an entry to build its compact index row. */
function toIndexEntry(entry: MemoryEntry): MemoryIndexEntry {
  return {
    id: entry.id,
    type: entry.type,
    title: entry.title,
    concepts: entry.concepts,
    tags: entry.tags,
    sessionId: entry.sessionId,
    createdAt: entry.createdAt,
  };
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
    typeof candidate.title === 'string' &&
    typeof candidate.body === 'string'
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

  /** Absolute path of the current-session file. */
  get sessionPath(): string {
    return path.join(this.memoryDir, SESSION_FILE);
  }

  // ---------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------

  /**
   * Persist one episode.
   *
   * Two dedup tiers, both from upstream
   * (`src/services/dedup/nearDuplicate.ts`):
   *
   *   Tier 0 — the normalized titles are identical: the existing episode is
   *            updated in place (a silent auto-merge).
   *   Tier 1 — the titles are near-duplicates under TF-IDF cosine: the new
   *            episode is NOT written and NOT merged. Upstream persists it as
   *            a review candidate; a silent merge would lose knowledge, so
   *            the caller is told instead.
   */
  remember(draft: MemoryDraft): RememberResult {
    const type = normalizeType(draft.type);
    if (!type) throw new Error(`Unknown memory type '${draft.type}'`);

    const entry: MemoryEntry = {
      id: randomUUID(),
      type,
      title: redactSecrets(draft.title).trim(),
      body: redactSecrets(draft.body).trim(),
      concepts: (draft.concepts ?? []).map((concept) => {
        const normalized = normalizeConcept(concept);
        if (!normalized) throw new Error(`Unknown concept '${concept}'`);
        return normalized;
      }),
      tags: (draft.tags ?? [])
        .map((tag) => redactSecrets(tag).trim().toLowerCase())
        .filter(Boolean),
      sessionId: draft.sessionId ?? this.currentSessionId(),
      createdAt: new Date().toISOString(),
    };

    const existing = this.read();

    const exact = existing.find(
      (item) =>
        item.type === entry.type && normalizeTitle(item.title) === normalizeTitle(entry.title),
    );
    if (exact) {
      const merged: MemoryEntry = {
        ...exact,
        body: entry.body || exact.body,
        concepts: entry.concepts.length > 0 ? entry.concepts : exact.concepts,
        tags: entry.tags.length > 0 ? entry.tags : exact.tags,
        updatedAt: entry.createdAt,
      };
      this.rewrite(merged);
      return { status: 'merged', entry: merged };
    }

    const near = this.findNearDuplicate(existing, entry);
    if (near) {
      return { status: 'candidate', entry, duplicateOf: near.id };
    }

    fs.mkdirSync(this.memoryDir, { recursive: true });
    fs.appendFileSync(this.storePath, `${JSON.stringify(entry)}\n`, 'utf8');
    this.prune();
    return { status: 'stored', entry };
  }

  // ---------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------

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
        if (isMemoryEntry(parsed)) entries.push(this.hydrate(parsed));
      } catch {
        // A half-written or corrupted line must never break a session.
      }
    }
    return entries;
  }

  /**
   * Step 1 of upstream's retrieval contract: return the compact index.
   *
   * The body is deliberately omitted — a full record costs roughly ten
   * times an index row, and details are only fetched for the rows the
   * caller actually chose (`get`).
   */
  recall(query: MemoryQuery = {}): MemoryIndexEntry[] {
    const limit = query.limit ?? DEFAULT_RECALL_LIMIT;
    const queryTerms = terms(query.text ?? '');
    const entries = this.read();
    const model = buildIdfModel(entries.map((entry) => terms(entry.title)));

    const filtered = entries.filter((entry) => {
      if (!query.includeSensitive && WITHHELD_TYPES.includes(entry.type)) return false;
      if (query.types && query.types.length > 0 && !query.types.includes(entry.type)) {
        return false;
      }
      if (
        query.concepts &&
        query.concepts.length > 0 &&
        !query.concepts.some((concept) => entry.concepts.includes(concept))
      ) {
        return false;
      }
      if (query.tags && query.tags.length > 0) {
        const wanted = query.tags.map((tag) => tag.toLowerCase());
        if (!wanted.every((tag) => entry.tags.includes(tag))) return false;
      }
      return true;
    });

    const scored = filtered
      .map((entry) => ({ entry, score: this.score(entry, queryTerms, model) }))
      .filter((candidate) => queryTerms.length === 0 || candidate.score > 0)
      .sort(
        (a, b) =>
          b.score - a.score || b.entry.createdAt.localeCompare(a.entry.createdAt),
      );

    return scored.slice(0, limit).map((candidate) => toIndexEntry(candidate.entry));
  }

  /** Step 3 of the contract: the full record for one index row. */
  get(id: string): MemoryEntry | undefined {
    return this.read().find((entry) => entry.id === id);
  }

  /** Step 2 of the contract: the episodes around an anchor, in time order. */
  timeline(anchorId: string, depth = 3): MemoryEntry[] {
    const entries = this.read();
    const index = entries.findIndex((entry) => entry.id === anchorId);
    if (index === -1) return [];

    const start = Math.max(0, index - depth);
    const end = Math.min(entries.length, index + depth + 1);
    return entries.slice(start, end);
  }

  /** The most recent episodes, as index rows. */
  list(limit = DEFAULT_RECALL_LIMIT): MemoryIndexEntry[] {
    return this.read()
      .slice(-limit)
      .reverse()
      .map(toIndexEntry);
  }

  /** Aggregate view of the store, used by the `stats` command. */
  stats(): MemoryStats {
    const entries = this.read();
    const types: Record<string, number> = {};
    for (const entry of entries) types[entry.type] = (types[entry.type] ?? 0) + 1;

    return {
      path: this.storePath,
      entries: entries.length,
      types,
      sessions: new Set(entries.map((entry) => entry.sessionId)).size,
    };
  }

  /** The sessions the stored episodes belong to. */
  sessions(): MemorySessionSummary[] {
    const entries = this.read();
    const bySession = new Map<string, MemoryEntry[]>();
    for (const entry of entries) {
      const bucket = bySession.get(entry.sessionId) ?? [];
      bucket.push(entry);
      bySession.set(entry.sessionId, bucket);
    }

    const current = this.readSession();
    return [...bySession.entries()]
      .map(([id, bucket]) => {
        const types: Record<string, number> = {};
        for (const entry of bucket) types[entry.type] = (types[entry.type] ?? 0) + 1;
        const summary: MemorySessionSummary = {
          id,
          episodes: bucket.length,
          types,
        };
        return current && current.id === id ? { ...summary, startedAt: current.startedAt } : summary;
      })
      .sort((a, b) => (a.startedAt ?? '').localeCompare(b.startedAt ?? ''));
  }

  // ---------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------

  /**
   * Open a session.
   *
   * The `memory-sync` hook runs on SessionStart, so this is the session
   * boundary: every episode written afterwards is attributed to it, which is
   * upstream's `memory_session_id`.
   */
  openSession(): MemorySession {
    const session: MemorySession = {
      id: `s-${new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 15)}-${randomUUID().slice(0, 4)}`,
      startedAt: new Date().toISOString(),
    };
    fs.mkdirSync(this.memoryDir, { recursive: true });
    fs.writeFileSync(this.sessionPath, `${JSON.stringify(session, null, 2)}\n`, 'utf8');
    return session;
  }

  /** The open session, if any. */
  readSession(): MemorySession | undefined {
    if (!fs.existsSync(this.sessionPath)) return undefined;
    try {
      const parsed: unknown = JSON.parse(fs.readFileSync(this.sessionPath, 'utf8'));
      if (typeof parsed !== 'object' || parsed === null) return undefined;
      const candidate = parsed as Partial<MemorySession>;
      if (typeof candidate.id !== 'string' || typeof candidate.startedAt !== 'string') {
        return undefined;
      }
      return { id: candidate.id, startedAt: candidate.startedAt };
    } catch {
      return undefined;
    }
  }

  /** The id episodes are attributed to when no session is open. */
  currentSessionId(): string {
    return this.readSession()?.id ?? 'manual';
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  /** Fill in the fields an older store file may not have. */
  private hydrate(entry: MemoryEntry): MemoryEntry {
    const type = normalizeType(entry.type) ?? 'discovery';
    const concepts = (entry.concepts ?? []).filter(
      (concept): concept is MemoryConcept => normalizeConcept(concept) !== null,
    );
    return {
      ...entry,
      type,
      concepts,
      tags: entry.tags ?? [],
      sessionId: entry.sessionId ?? 'manual',
    };
  }

  /** Find an episode that looks like the one being written. */
  private findNearDuplicate(
    existing: readonly MemoryEntry[],
    candidate: MemoryEntry,
  ): MemoryEntry | undefined {
    const candidateTokens = terms(candidate.title);

    for (const entry of existing) {
      if (entry.type !== candidate.type) continue;
      const entryTokens = terms(entry.title);
      if (sharedTokens(candidateTokens, entryTokens) < MIN_SHARED_TOKENS) continue;
      if (jaccard(candidateTokens, entryTokens) >= NEAR_DUPLICATE_THRESHOLD) {
        return entry;
      }
    }
    return undefined;
  }

  /** Replace one episode in place, keeping the file append-only elsewhere. */
  private rewrite(updated: MemoryEntry): void {
    const entries = this.read();
    const index = entries.findIndex((entry) => entry.id === updated.id);
    if (index === -1) return;

    const next = [...entries];
    next[index] = updated;
    fs.writeFileSync(
      this.storePath,
      `${next.map((entry) => JSON.stringify(entry)).join('\n')}\n`,
      'utf8',
    );
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

  /**
   * Rank one episode against the query terms.
   *
   * A term that occurs in most stored episodes carries no discriminating
   * power and is ignored (upstream's IDF veto); the rest are weighted by how
   * rare they are.
   */
  private score(entry: MemoryEntry, queryTerms: readonly string[], model: IdfModel): number {
    if (queryTerms.length === 0) return 1;

    const title = terms(entry.title);
    const body = terms(entry.body);
    const tags = entry.tags.map((tag) => tag.toLowerCase());

    let score = 0;
    for (const term of queryTerms) {
      const weight = model.idf.get(term) ?? 0;
      if (weight <= 0) continue;
      if (title.includes(term)) score += 3 * weight;
      if (tags.some((tag) => tag.includes(term))) score += 2 * weight;
      if (body.includes(term)) score += 1 * weight;
    }
    return score;
  }
}
