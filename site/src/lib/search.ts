/**
 * search.ts — pure scoring logic for the docs search index.
 *
 * Extracted from `DocsSearchBar.tsx` so the ranking can be unit-tested
 * without pulling in React / DOM / fetch. Also imported by
 * `src/pages/search-index.json.ts` so the emitted-JSON shape and the
 * consumer's expected shape share a single source of truth.
 *
 * Weights are hand-tuned: title matches dominate; keywords are the
 * second signal (author-declared → strong intent); headings and
 * description widen recall. A raw substring hit on the whole query gets
 * a bonus so multi-word queries like "prime directives" find their own
 * page first.
 */

// ---- Types --------------------------------------------------------------

export interface SearchHeading {
  text: string;
  slug: string;
  depth: number;
}

export interface SearchIndexEntry {
  slug: string;
  href: string;
  title: string;
  description: string;
  category: string;
  keywords: string[];
  headings: SearchHeading[];
}

export interface ScoredResult extends SearchIndexEntry {
  score: number;
  matchedHeading?: SearchHeading;
}

// ---- Scoring weights ----------------------------------------------------
// Exported so tests can reason about relative weights symbolically
// (e.g. keyword between title and description) instead of hardcoding
// numeric values in assertions.
export const W_TITLE = 3.0;
export const W_KEYWORD = 2.5;
export const W_HEADING = 1.5;
export const W_DESCRIPTION = 1.0;
export const W_EXACT_PHRASE = 2.0;

// ---- Pure functions -----------------------------------------------------

/**
 * Split a query string into lowercased, whitespace-delimited tokens.
 * Empty tokens (from consecutive whitespace or an empty input) are
 * filtered out so the downstream scorer never sees a zero-length match.
 */
export function tokenize(input: string): string[] {
  return input
    .toLowerCase()
    .split(/\s+/)
    .map((t) => t.trim())
    .filter(Boolean);
}

/**
 * Score a single index entry against a token list plus the raw
 * (lowercased) phrase. Returns the entry plus its score and, if any
 * heading matched, the first matching heading so the UI can anchor-link.
 */
export function scoreEntry(
  entry: SearchIndexEntry,
  tokens: string[],
  phrase: string,
): ScoredResult {
  if (tokens.length === 0) {
    return { ...entry, score: 0 };
  }

  const title = entry.title.toLowerCase();
  const description = entry.description.toLowerCase();
  const keywords = entry.keywords.map((k) => k.toLowerCase());
  const headings = entry.headings.map((h) => ({ ...h, textLower: h.text.toLowerCase() }));

  let score = 0;
  let matchedHeading: SearchHeading | undefined;

  for (const t of tokens) {
    if (title.includes(t)) score += W_TITLE;

    for (const k of keywords) {
      if (k.includes(t)) {
        score += W_KEYWORD;
        break; // one keyword hit per token, avoid multi-counting
      }
    }

    for (const h of headings) {
      if (h.textLower.includes(t)) {
        score += W_HEADING;
        // Remember the first heading that matches ANY token — the UI
        // uses this to build an anchor link on the result. Subsequent
        // hits still contribute to the score but don't override the
        // anchor target.
        if (!matchedHeading) {
          matchedHeading = { text: h.text, slug: h.slug, depth: h.depth };
        }
      }
    }

    if (description.includes(t)) score += W_DESCRIPTION;
  }

  if (tokens.length > 1 && title.includes(phrase)) score += W_EXACT_PHRASE;

  return { ...entry, score, matchedHeading };
}

/**
 * Score every entry in the index against a query, drop zero-score
 * entries, sort by score desc, and cap at `limit`. Returns [] for an
 * empty query or an empty index.
 */
export function rankResults(
  index: SearchIndexEntry[],
  query: string,
  limit = 6,
): ScoredResult[] {
  const tokens = tokenize(query);
  if (tokens.length === 0) return [];
  const phrase = query.trim().toLowerCase();
  return index
    .map((entry) => scoreEntry(entry, tokens, phrase))
    .filter((r) => r.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
}
