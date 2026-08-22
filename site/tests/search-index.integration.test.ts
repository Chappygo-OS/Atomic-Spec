/**
 * Integration test — the built search-index.json.
 *
 * Reads `site/dist/search-index.json` (emitted by
 * `src/pages/search-index.json.ts` at `astro build`) and asserts the
 * shape the client-side scorer expects. Catches drift between the
 * schema in `src/lib/search.ts` and what actually ships to the browser.
 *
 * If `dist/` is missing (no build has run yet), the suite is skipped
 * with a helpful message instead of failing — CI can build first, but
 * a local `npm test` on a fresh clone shouldn't hard-fail on a missing
 * artifact.
 */
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import type { SearchIndexEntry } from '../src/lib/search';

const INDEX_PATH = join(__dirname, '..', 'dist', 'search-index.json');
const hasBuild = existsSync(INDEX_PATH);

// vitest's `describe.skipIf` fires the skip cleanly with a reason in
// the reporter output — no assertion noise, no false negatives.
describe.skipIf(!hasBuild)(
  'search-index.json integration (skipped if dist/ missing — run `npm run build` first)',
  () => {
    const raw = hasBuild ? readFileSync(INDEX_PATH, 'utf8') : '[]';
    const index = JSON.parse(raw) as SearchIndexEntry[];

    it('is an array', () => {
      expect(Array.isArray(index)).toBe(true);
    });

    it('has at least the 10 docs pages we ship today', () => {
      expect(index.length).toBeGreaterThanOrEqual(10);
    });

    it('every entry has the required fields with the right types', () => {
      for (const entry of index) {
        expect(typeof entry.slug).toBe('string');
        expect(entry.slug.length).toBeGreaterThan(0);
        expect(typeof entry.href).toBe('string');
        expect(entry.href.length).toBeGreaterThan(0);
        expect(typeof entry.title).toBe('string');
        expect(entry.title.length).toBeGreaterThan(0);
        expect(typeof entry.description).toBe('string');
        expect(typeof entry.category).toBe('string');
        expect(Array.isArray(entry.keywords)).toBe(true);
        expect(Array.isArray(entry.headings)).toBe(true);
      }
    });

    it('keywords is always an array of strings (never null / undefined)', () => {
      for (const entry of index) {
        expect(entry.keywords).not.toBeNull();
        expect(entry.keywords).not.toBeUndefined();
        for (const kw of entry.keywords) {
          expect(typeof kw).toBe('string');
        }
      }
    });

    it('headings entries have text, slug, and depth', () => {
      for (const entry of index) {
        for (const h of entry.headings) {
          expect(typeof h.text).toBe('string');
          expect(typeof h.slug).toBe('string');
          expect(typeof h.depth).toBe('number');
          // Endpoint filters to depth 2-3 (H2 / H3). Anything outside
          // that range is a regression in the emitter.
          expect(h.depth).toBeGreaterThanOrEqual(2);
          expect(h.depth).toBeLessThanOrEqual(3);
        }
      }
    });

    it('"nine prime directives" is a keyword on the prime-directives page', () => {
      const primeDirectives = index.find((e) => e.slug === 'prime-directives');
      expect(primeDirectives).toBeDefined();
      expect(primeDirectives?.keywords).toContain('nine prime directives');
    });
  },
);

// Emit a top-level hint when there's no build so the reason for the
// skip is obvious in local runs (vitest surfaces this in its output).
if (!hasBuild) {
  // eslint-disable-next-line no-console
  console.warn(
    `[search-index.integration] dist/search-index.json not found at ${INDEX_PATH} — run \`npm run build\` before \`npm test\` to enable this suite.`,
  );
}
