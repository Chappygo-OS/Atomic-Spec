/**
 * Unit tests for the docs search scoring module.
 *
 * Target: `src/lib/search.ts` — pure functions, no DOM, no fetch, no
 * React. Tests use small hand-crafted fixtures so failures point at
 * one weight or one branch rather than at "the whole index".
 *
 * Weight relationships (not exact numbers) are asserted where the
 * intent is "keyword hit should beat description hit". Exact numeric
 * assertions are kept for the exact-phrase bonus, unmatched entries,
 * and empty inputs — cases where the value has a single correct answer.
 */
import { describe, expect, it } from 'vitest';
import {
  rankResults,
  scoreEntry,
  tokenize,
  W_DESCRIPTION,
  W_EXACT_PHRASE,
  W_HEADING,
  W_KEYWORD,
  W_TITLE,
  type SearchIndexEntry,
} from '../src/lib/search';

// ---- Fixtures -----------------------------------------------------------

// A neutral entry with every field blanked out. Individual tests spread
// this and overwrite exactly the field they want to exercise so no test
// accidentally scores on a field it wasn't targeting.
const emptyEntry: SearchIndexEntry = {
  slug: 'x',
  href: '/docs/x',
  title: '',
  description: '',
  category: 'Guides',
  keywords: [],
  headings: [],
};

// ---- tokenize -----------------------------------------------------------

describe('tokenize', () => {
  it('splits on whitespace and lowercases', () => {
    expect(tokenize('Hello World')).toEqual(['hello', 'world']);
  });

  it('collapses runs of whitespace (spaces, tabs, newlines)', () => {
    expect(tokenize('  foo\t\tbar\n\nbaz  ')).toEqual(['foo', 'bar', 'baz']);
  });

  it('strips leading and trailing whitespace', () => {
    expect(tokenize('   hello   ')).toEqual(['hello']);
  });

  it('returns [] for an empty input', () => {
    expect(tokenize('')).toEqual([]);
  });

  it('returns [] for whitespace-only input', () => {
    expect(tokenize('   \t\n  ')).toEqual([]);
  });

  it('preserves single-token queries', () => {
    expect(tokenize('atomic')).toEqual(['atomic']);
  });
});

// ---- scoreEntry ---------------------------------------------------------

describe('scoreEntry', () => {
  it('scores 0 when tokens is empty', () => {
    const entry: SearchIndexEntry = { ...emptyEntry, title: 'Anything' };
    expect(scoreEntry(entry, [], '').score).toBe(0);
  });

  it('scores 0 for an entry that matches nothing', () => {
    const entry: SearchIndexEntry = {
      ...emptyEntry,
      title: 'Unrelated',
      description: 'Nothing to see here',
      keywords: ['foo', 'bar'],
      headings: [{ text: 'Section', slug: 'section', depth: 2 }],
    };
    expect(scoreEntry(entry, ['xyzzy'], 'xyzzy').score).toBe(0);
  });

  it('scores a title hit higher than a description hit for the same token', () => {
    const inTitle: SearchIndexEntry = { ...emptyEntry, title: 'Directives' };
    const inDescription: SearchIndexEntry = { ...emptyEntry, description: 'Directives are rules' };
    const titleScore = scoreEntry(inTitle, ['directives'], 'directives').score;
    const descScore = scoreEntry(inDescription, ['directives'], 'directives').score;
    expect(titleScore).toBeGreaterThan(descScore);
    expect(titleScore).toBe(W_TITLE);
    expect(descScore).toBe(W_DESCRIPTION);
  });

  it('keyword hit scores between title and description', () => {
    const inKeyword: SearchIndexEntry = { ...emptyEntry, keywords: ['directives'] };
    const s = scoreEntry(inKeyword, ['directives'], 'directives').score;
    expect(s).toBe(W_KEYWORD);
    expect(s).toBeGreaterThan(W_DESCRIPTION);
    expect(s).toBeLessThan(W_TITLE);
  });

  it('heading hit scores between keyword and description', () => {
    const inHeading: SearchIndexEntry = {
      ...emptyEntry,
      headings: [{ text: 'Directives', slug: 'directives', depth: 2 }],
    };
    const s = scoreEntry(inHeading, ['directives'], 'directives').score;
    expect(s).toBe(W_HEADING);
    expect(s).toBeGreaterThan(W_DESCRIPTION);
    expect(s).toBeLessThan(W_KEYWORD);
  });

  it('adds the exact-phrase bonus for a multi-token phrase found in the title', () => {
    const entry: SearchIndexEntry = { ...emptyEntry, title: 'Nine Prime Directives' };
    const s = scoreEntry(entry, ['prime', 'directives'], 'prime directives').score;
    // Both tokens hit the title (2 * W_TITLE) and the full phrase hits
    // the title too (W_EXACT_PHRASE).
    expect(s).toBe(W_TITLE * 2 + W_EXACT_PHRASE);
  });

  it('does NOT add the exact-phrase bonus for single-token queries', () => {
    const entry: SearchIndexEntry = { ...emptyEntry, title: 'Directives' };
    const s = scoreEntry(entry, ['directives'], 'directives').score;
    expect(s).toBe(W_TITLE); // no bonus
  });

  it('does NOT add the exact-phrase bonus when the phrase is only in the description', () => {
    const entry: SearchIndexEntry = { ...emptyEntry, description: 'prime directives are the rules' };
    const s = scoreEntry(entry, ['prime', 'directives'], 'prime directives').score;
    // Two description hits, no title/keyword/heading, no phrase bonus.
    expect(s).toBe(W_DESCRIPTION * 2);
  });

  it('counts a keyword only once per token even if multiple keywords match', () => {
    // Both keywords contain the token "prime". The `break` in the scorer
    // means the token contributes W_KEYWORD once — not twice.
    const entry: SearchIndexEntry = {
      ...emptyEntry,
      keywords: ['prime directives', 'primer material'],
    };
    const s = scoreEntry(entry, ['prime'], 'prime').score;
    expect(s).toBe(W_KEYWORD);
  });

  it('exposes the first matched heading so the UI can anchor-link', () => {
    const entry: SearchIndexEntry = {
      ...emptyEntry,
      headings: [
        { text: 'Setup', slug: 'setup', depth: 2 },
        { text: 'Configuration', slug: 'config', depth: 2 },
      ],
    };
    const result = scoreEntry(entry, ['config'], 'config');
    expect(result.matchedHeading).toEqual({ text: 'Configuration', slug: 'config', depth: 2 });
  });

  it('leaves matchedHeading undefined when no heading matches', () => {
    const entry: SearchIndexEntry = {
      ...emptyEntry,
      title: 'Directives',
      headings: [{ text: 'Setup', slug: 'setup', depth: 2 }],
    };
    const result = scoreEntry(entry, ['directives'], 'directives');
    expect(result.matchedHeading).toBeUndefined();
  });

  it('is case-insensitive across all fields', () => {
    const entry: SearchIndexEntry = {
      ...emptyEntry,
      title: 'PRIME DIRECTIVES',
      keywords: ['ATOMIC SPEC'],
      headings: [{ text: 'INTRODUCTION', slug: 'intro', depth: 2 }],
      description: 'GOVERNANCE FRAMEWORK',
    };
    const s = scoreEntry(
      entry,
      ['prime', 'atomic', 'introduction', 'governance'],
      'prime atomic introduction governance',
    ).score;
    // 1 title hit + 1 keyword hit + 1 heading hit + 1 description hit.
    expect(s).toBe(W_TITLE + W_KEYWORD + W_HEADING + W_DESCRIPTION);
  });
});

// ---- rankResults --------------------------------------------------------

describe('rankResults', () => {
  const corpus: SearchIndexEntry[] = [
    {
      ...emptyEntry,
      slug: 'prime-directives',
      title: 'Nine Prime Directives',
      keywords: ['nine prime directives', 'article ix'],
    },
    {
      ...emptyEntry,
      slug: 'quickstart',
      title: 'Quickstart',
      description: 'Get started with the framework',
    },
    {
      ...emptyEntry,
      slug: 'unrelated',
      title: 'Unrelated Guide',
      description: 'Nothing matches here',
    },
    {
      ...emptyEntry,
      slug: 'mentions-directives',
      description: 'Mentions directives in passing',
    },
  ];

  it('sorts results by score descending', () => {
    const results = rankResults(corpus, 'directives');
    // "Nine Prime Directives" (title hit) should outrank "mentions
    // directives in passing" (description hit).
    expect(results.map((r) => r.slug)).toEqual(['prime-directives', 'mentions-directives']);
    expect(results[0].score).toBeGreaterThan(results[1].score);
  });

  it('drops zero-score entries', () => {
    const results = rankResults(corpus, 'directives');
    expect(results.some((r) => r.slug === 'unrelated')).toBe(false);
    expect(results.some((r) => r.slug === 'quickstart')).toBe(false);
  });

  it('respects the limit parameter', () => {
    const results = rankResults(corpus, 'directives', 1);
    expect(results).toHaveLength(1);
    expect(results[0].slug).toBe('prime-directives');
  });

  it('defaults limit to 6', () => {
    // Build a corpus of 10 entries that all match a single token so the
    // default limit is the constraint, not the corpus size.
    const many: SearchIndexEntry[] = Array.from({ length: 10 }, (_, i) => ({
      ...emptyEntry,
      slug: `entry-${i}`,
      title: `Entry ${i} directives`,
    }));
    expect(rankResults(many, 'directives')).toHaveLength(6);
  });

  it('returns [] for an empty query', () => {
    expect(rankResults(corpus, '')).toEqual([]);
    expect(rankResults(corpus, '   ')).toEqual([]);
  });

  it('returns [] for an empty index', () => {
    expect(rankResults([], 'directives')).toEqual([]);
  });

  it('applies the exact-phrase bonus when ranking multi-token queries', () => {
    // "Nine Prime Directives" gets 3xW_TITLE + W_EXACT_PHRASE plus one
    // keyword hit per token (keywords match "nine prime directives").
    // The mentions-only entry gets 3xW_DESCRIPTION at best. The bonus
    // widens the gap versus what token-only scoring would produce.
    const results = rankResults(corpus, 'nine prime directives');
    expect(results[0].slug).toBe('prime-directives');
    // Sanity: score must exceed the sum you'd get without the bonus.
    expect(results[0].score).toBeGreaterThan(W_TITLE * 3);
  });
});
