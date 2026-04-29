/**
 * Content collections — wires `src/content/docs/**` into Astro's typed
 * `getCollection('docs')` API.
 *
 * `loader: glob(...)` (Astro 5) replaces the legacy auto-discovery: it gives
 * us a stable feature ID and lets us co-locate MDX with the rest of `src/`.
 *
 * Schema is the contract every doc frontmatter must satisfy. Anything
 * missing or malformed fails `astro check` instead of breaking at render
 * time, which is the entire point of having a typed schema.
 */
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const docs = defineCollection({
  // Restrict to `.mdx` only — keeps the editUrl path in [...slug].astro safe
  // (it always appends `.mdx`). If `.md` files are ever needed, expose the
  // file extension via `entry.filePath` and switch the editUrl to use it.
  loader: glob({ pattern: '**/*.mdx', base: './src/content/docs' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    category: z.enum(['Getting Started', 'Guides', 'Reference', 'Concepts', 'Community']),
    order: z.number().default(100),
    lastUpdated: z.coerce.date().optional(),
    draft: z.boolean().default(false),
  }),
});

export const collections = { docs };
