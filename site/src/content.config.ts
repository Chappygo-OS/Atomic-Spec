// Phase 1: empty placeholder so content-collection types resolve to a clean object.
// Phase 3 will define `docs` and any related collections here using `defineCollection`.
//
// Typed as `Record<string, ReturnType<typeof defineCollection>>` so adding entries
// later is a one-line change without altering this export's shape.

import { defineCollection } from 'astro:content';

export const collections: Record<string, ReturnType<typeof defineCollection>> = {};
