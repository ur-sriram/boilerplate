/**
 * Token scoring for the claude-mem store.
 *
 * WHY THIS EXISTS
 * ---------------
 * The first implementation of the store ranked results by counting how many
 * times a query term appeared. A query for "the graph server" matched every
 * episode containing the word "the", and the useful ones sank.
 *
 * Upstream claude-mem solves this with an IDF model: it keeps a per-project
 * document-frequency table (`token_df`), weights a term by how rare it is,
 * and vetoes terms that appear in so many records that they no longer
 * discriminate (`src/services/sqlite/dedup-store.ts`,
 * `src/services/dedup/idf.ts`, `src/services/dedup/idfVeto.ts`).
 *
 * The same model is implemented here, dependency-free: the document
 * frequencies are derived from the store at query time, which is cheap
 * because the store is bounded to a few hundred episodes.
 */

/** A term that appears in more documents than this is not discriminating. */
const MIN_VETO_DF = 10;

/** Two titles are near-duplicates at or above this similarity. */
export const NEAR_DUPLICATE_THRESHOLD = 0.85;

/** A near-duplicate pair must share at least this many discriminating terms. */
export const MIN_SHARED_TOKENS = 2;

/**
 * Split text into terms.
 *
 * Every alphanumeric token is kept, numbers included: "Episode 1" and
 * "Episode 2" are different episodes, and dropping the number would make
 * them look like near-duplicates of each other. The IDF veto is what
 * removes the noise words — a term that occurs in most documents is
 * discarded, not filtered out of the tokenizer.
 */
export function terms(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((term) => term.length >= 1);
}

/**
 * Normalize a title so that trivially different spellings of the same
 * episode collapse onto one key.
 */
export function normalizeTitle(title: string): string {
  return terms(title).sort().join(' ');
}

/** The per-store IDF model, derived from the episodes currently stored. */
export interface IdfModel {
  readonly documentCount: number;
  readonly idf: ReadonlyMap<string, number>;
  /** Documents containing the term. */
  readonly documentFrequency: ReadonlyMap<string, number>;
}

/**
 * Build the IDF model over a corpus.
 *
 * A term that occurs in more than half the documents (and in more than
 * `MIN_VETO_DF` documents overall) is vetoed: it carries no discriminating
 * power, so it must not influence ranking or near-duplicate detection.
 */
export function buildIdfModel(corpus: readonly string[][]): IdfModel {
  const documentCount = corpus.length;
  const documentFrequency = new Map<string, number>();

  for (const tokens of corpus) {
    for (const term of new Set(tokens)) {
      documentFrequency.set(term, (documentFrequency.get(term) ?? 0) + 1);
    }
  }

  const vetoDf = Math.max(MIN_VETO_DF, Math.ceil(documentCount / 2));
  const idf = new Map<string, number>();
  for (const [term, df] of documentFrequency) {
    idf.set(term, df > vetoDf ? 0 : Math.log(1 + documentCount / (1 + df)));
  }

  return { documentCount, idf, documentFrequency };
}

/** True when the term carries discriminating power under this model. */
export function isDiscriminating(model: IdfModel, term: string): boolean {
  return (model.idf.get(term) ?? 0) > 0;
}

/**
 * Corpus-independent similarity between two titles.
 *
 * Upstream compares near-duplicates with a TF-IDF cosine
 * (`src/services/dedup/tfidfCosine.ts`). At write time the corpus is still
 * half-built, so a TF-IDF verdict depends on how much history happens to
 * exist yet: two episodes that differ only in a number were flagged as
 * duplicates when the store was young and not when it was full.
 *
 * Jaccard over the term sets has no such dependence — the same two titles
 * always get the same verdict — so it is used for the dedup decision. The
 * IDF model is still used for RANKING, where the whole store is available.
 */
export function jaccard(left: readonly string[], right: readonly string[]): number {
  const leftSet = new Set(left);
  const rightSet = new Set(right);
  if (leftSet.size === 0 || rightSet.size === 0) return 0;

  let shared = 0;
  for (const term of leftSet) {
    if (rightSet.has(term)) shared += 1;
  }
  const union = leftSet.size + rightSet.size - shared;
  return union === 0 ? 0 : shared / union;
}

/** How many terms the two documents share. */
export function sharedTokens(
  left: readonly string[],
  right: readonly string[],
): number {
  const rightSet = new Set(right);
  let shared = 0;
  for (const term of new Set(left)) {
    if (rightSet.has(term)) shared += 1;
  }
  return shared;
}
