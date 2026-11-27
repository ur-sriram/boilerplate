/**
 * Claude-Mem episodic memory contracts.
 *
 * The taxonomy mirrors upstream `thedotmack/claude-mem`, whose "code
 * development" mode profile (`plugin/modes/code.json`) defines the
 * observation types and concepts used here:
 *
 *   types    bugfix, feature, refactor, change, discovery, decision,
 *            security_alert, security_note, sensitive
 *   concepts how-it-works, why-it-exists, what-changed, problem-solution,
 *            gotcha, pattern, trade-off
 *
 * Upstream keeps four separate axes (storage kind, provenance source,
 * observation type, observation concept). A project-local store only needs
 * two of them: the type and the concept. Provenance is always "written by
 * an agent" here, because there is no observer process.
 */

/** Observation types, from the upstream `code` mode profile. */
export const MEMORY_TYPES = [
  'bugfix',
  'feature',
  'refactor',
  'change',
  'discovery',
  'decision',
  'security_alert',
  'security_note',
  'sensitive',
] as const;

export type MemoryType = (typeof MEMORY_TYPES)[number];

/** Observation concepts, from the upstream `code` mode profile. */
export const MEMORY_CONCEPTS = [
  'how-it-works',
  'why-it-exists',
  'what-changed',
  'problem-solution',
  'gotcha',
  'pattern',
  'trade-off',
] as const;

export type MemoryConcept = (typeof MEMORY_CONCEPTS)[number];

/**
 * Types written before the taxonomy was aligned with upstream. Reading them
 * still works; writing them is rejected.
 */
const LEGACY_TYPE_MAP: Readonly<Record<string, MemoryType>> = {
  decision: 'decision',
  fact: 'discovery',
  preference: 'decision',
  recovery: 'bugfix',
};

/** Map any accepted spelling onto an upstream type, or null if unknown. */
export function normalizeType(value: string): MemoryType | null {
  if ((MEMORY_TYPES as readonly string[]).includes(value)) {
    return value as MemoryType;
  }
  return LEGACY_TYPE_MAP[value] ?? null;
}

/** Map an accepted concept onto the upstream vocabulary, or null. */
export function normalizeConcept(value: string): MemoryConcept | null {
  return (MEMORY_CONCEPTS as readonly string[]).includes(value)
    ? (value as MemoryConcept)
    : null;
}

/**
 * Types that are withheld from a normal recall.
 *
 * Upstream's `sensitive` type is "information that isn't quite private, but
 * shouldn't leak into further content". It is stored, but it is not injected
 * into a session unless explicitly asked for.
 */
export const WITHHELD_TYPES: readonly MemoryType[] = ['sensitive'];

export interface MemoryDraft {
  readonly type: MemoryType;
  readonly title: string;
  readonly body: string;
  readonly concepts?: readonly MemoryConcept[];
  readonly tags?: readonly string[];
  readonly sessionId?: string;
}

export interface MemoryEntry {
  readonly id: string;
  readonly type: MemoryType;
  readonly title: string;
  readonly body: string;
  readonly concepts: readonly MemoryConcept[];
  readonly tags: readonly string[];
  readonly sessionId: string;
  readonly createdAt: string;
  readonly updatedAt?: string;
}

/**
 * A compact row: everything except the body.
 *
 * This is upstream's index/detail split. Upstream keeps its index rows at
 * roughly a tenth of a full record, so a search costs ~50-100 tokens per
 * result instead of ~500-1,000, and full details are only fetched for the
 * rows that were actually chosen.
 */
export interface MemoryIndexEntry {
  readonly id: string;
  readonly type: MemoryType;
  readonly title: string;
  readonly concepts: readonly MemoryConcept[];
  readonly tags: readonly string[];
  readonly sessionId: string;
  readonly createdAt: string;
}

/** A session groups the episodes written while one agent session was open. */
export interface MemorySession {
  readonly id: string;
  readonly startedAt: string;
}

export type RememberStatus =
  /** A new episode was written. */
  | 'stored'
  /** An existing episode with the same normalized title was updated. */
  | 'merged'
  /** A near-duplicate was found; the episode was NOT written. */
  | 'candidate';

export interface RememberResult {
  readonly status: RememberStatus;
  readonly entry: MemoryEntry;
  /** For `candidate`: the id of the episode this one looks like. */
  readonly duplicateOf?: string;
}

export interface MemoryQuery {
  readonly text?: string;
  readonly types?: readonly MemoryType[];
  readonly concepts?: readonly MemoryConcept[];
  readonly tags?: readonly string[];
  readonly limit?: number;
  /** Include `sensitive` episodes. Off by default. */
  readonly includeSensitive?: boolean;
}

export interface MemoryStoreOptions {
  /** Project root. Every read and write stays inside it. */
  readonly root: string;
  /** Maximum number of episodes kept in the store file. */
  readonly maxEntries?: number;
}

export interface MemoryStats {
  readonly path: string;
  readonly entries: number;
  readonly types: Readonly<Record<string, number>>;
  readonly sessions: number;
}

export interface MemorySessionSummary {
  readonly id: string;
  readonly startedAt?: string;
  readonly episodes: number;
  readonly types: Readonly<Record<string, number>>;
}
