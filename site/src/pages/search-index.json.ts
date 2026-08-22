/**
 * /search-index.json — static docs search index.
 *
 * Emitted once at `astro build`, served as a plain JSON file from the CDN
 * (no runtime server, no runtime dependency). The client-side `DocsSearchBar`
 * fetches this on first focus and scores queries against title, keywords
 * (author-declared per page), body H2/H3 headings, and description.
 *
 * Design notes:
 *   - The index is deliberately small. Every entry ships title + description
 *     + a short heading list — no full-body text. On the current 10-doc
 *     corpus it lands well under 10 KB gzipped. If the doc set grows past
 *     ~50 pages, revisit whether to shard the index (per-category files)
 *     or pull in Pagefind. For now: one file, one fetch, zero deps.
 *   - Headings are filtered to depth 2-3 (H2/H3). H1 is the title (already
 *     indexed); H4+ is section-detail rarely searched for.
 *   - Draft entries are excluded (matches the `getDocsNav` filter in
 *     `src/lib/nav.ts` so search never surfaces pages the sidebar hides).
 */
import type { APIRoute } from 'astro';
import { getCollection, render } from 'astro:content';
import { withBase } from '../lib/url';

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

export const GET: APIRoute = async () => {
  const entries = await getCollection('docs', (e) => !e.data.draft);

  const index: SearchIndexEntry[] = await Promise.all(
    entries.map(async (entry) => {
      const { headings } = await render(entry);
      return {
        slug: entry.id,
        href: withBase(`/docs/${entry.id}`),
        title: entry.data.title,
        description: entry.data.description,
        category: entry.data.category,
        keywords: entry.data.keywords ?? [],
        headings: headings
          .filter((h) => h.depth >= 2 && h.depth <= 3)
          .map((h) => ({ text: h.text, slug: h.slug, depth: h.depth })),
      };
    }),
  );

  return new Response(JSON.stringify(index), {
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
};
