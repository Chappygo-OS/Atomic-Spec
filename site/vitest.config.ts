/**
 * vitest.config.ts — pure-logic test runner for the site.
 *
 * Scoped to `tests/` so it never crawls Astro-owned code paths that
 * need the framework's transformer (MDX / `.astro` / `astro:content`).
 * We test extracted modules like `src/lib/search.ts` here — nothing
 * that imports React, DOM, or Astro runtime shims.
 *
 * The Astro `tsconfig.json` already sits at the site root, so Vitest
 * (via Vite) picks it up automatically for the `.ts` files under
 * `tests/`. No jsdom — tests are Node-only.
 */
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    environment: 'node',
    globals: false,
    // Fail fast on unhandled rejections; a rejected promise in a test
    // fixture should never look like a passing suite.
    dangerouslyIgnoreUnhandledErrors: false,
  },
});
