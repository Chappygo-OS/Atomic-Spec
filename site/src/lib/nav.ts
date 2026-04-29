/**
 * Docs navigation builder.
 *
 * Reads the `docs` collection at build time, groups entries by `category`,
 * sorts each group by `order`, and returns a deterministic structure the
 * sidebar / mobile drawer / index page can render without any further
 * sorting logic.
 *
 * Drafts (`draft: true` in frontmatter) are excluded — the schema default
 * is `false`, so this only filters explicitly-marked drafts.
 *
 * Category ordering is hard-coded to match the IA agreed in COPY.md: a
 * reader's path is Getting Started → Guides → Concepts → Reference →
 * Community. Adding a new category requires adding it to both the schema
 * enum (content.config.ts) and the `order` array below.
 */
import { getCollection } from 'astro:content';
import { withBase } from './url';

export interface NavItem {
  slug: string;
  title: string;
  href: string;
  description: string;
}

export interface NavGroup {
  category: string;
  items: NavItem[];
}

const CATEGORY_ORDER: ReadonlyArray<string> = [
  'Getting Started',
  'Guides',
  'Concepts',
  'Reference',
  'Community',
];

export async function getDocsNav(): Promise<NavGroup[]> {
  const entries = await getCollection('docs', (e) => !e.data.draft);

  const groups = new Map<string, typeof entries>();
  for (const entry of entries) {
    const list = groups.get(entry.data.category) ?? [];
    list.push(entry);
    groups.set(entry.data.category, list);
  }

  return CATEGORY_ORDER.filter((c) => groups.has(c)).map((category) => ({
    category,
    // Spread before sort — `Array#sort` mutates in place; the spread keeps
    // the source `groups` map immutable in case future callers reuse it.
    items: [...groups.get(category)!]
      .sort((a, b) => a.data.order - b.data.order)
      .map((entry) => ({
        slug: entry.id,
        title: entry.data.title,
        href: withBase(`/docs/${entry.id}`),
        description: entry.data.description,
      })),
  }));
}
