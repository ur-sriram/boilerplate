/**
 * Claude-Mem episodic memory contracts.
 *
 * An "episode" is one durable, cross-session fact: an architectural decision,
 * a user preference, an error recovery, or a learned project fact.
 */

export type MemoryKind = 'decision' | 'preference' | 'recovery' | 'fact';

export interface MemoryDraft {
  readonly kind: MemoryKind;
  readonly title: string;
  readonly body: string;
  readonly tags?: readonly string[];
  readonly sessionId?: string;
}

export interface MemoryEntry {
  readonly id: string;
  readonly kind: MemoryKind;
  readonly title: string;
  readonly body: string;
  readonly tags: readonly string[];
  readonly sessionId: string;
  readonly createdAt: string;
}

export interface MemoryQuery {
  readonly text?: string;
  readonly tags?: readonly string[];
  readonly limit?: number;
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
  readonly kinds: Readonly<Record<string, number>>;
}
