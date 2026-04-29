/**
 * Prefix any internal path with the configured site base (`import.meta.env.BASE_URL`).
 *
 * Astro injects `BASE_URL` from the `base` option in `astro.config.mjs`. In production
 * this is `/atomic-spec/`; in dev it can be `/` depending on configuration. Always
 * route internal links through this helper so a single config change reroutes the site.
 *
 * Edge cases handled:
 *   - empty / "/" / undefined path -> base + "/"
 *   - bare query (`?ref=nav`) and hash (`#section`) prepended to base + "/"
 *   - already-absolute URLs (http/https/mailto/tel) returned as-is
 *
 * @example
 *   withBase('/docs')                  // -> "/atomic-spec/docs"
 *   withBase('docs')                   // -> "/atomic-spec/docs"
 *   withBase('/docs?ref=nav')          // -> "/atomic-spec/docs?ref=nav"
 *   withBase('#section')               // -> "/atomic-spec/#section"
 *   withBase('https://example.com')    // -> "https://example.com" (untouched)
 */
export function withBase(path: string): string {
  if (/^([a-z][a-z0-9+\-.]*:|\/\/)/i.test(path)) {
    return path;
  }

  const base = (import.meta.env.BASE_URL ?? '/').replace(/\/+$/, '');

  if (!path || path === '/') {
    return `${base}/`;
  }

  if (path.startsWith('?') || path.startsWith('#')) {
    return `${base}/${path}`;
  }

  const normalized = path.startsWith('/') ? path : `/${path}`;
  return `${base}${normalized}`;
}

/**
 * Strip trailing slash so `/docs/foo` and `/docs/foo/` both match for active-state
 * comparison. The site is configured with `trailingSlash: 'ignore'` in
 * astro.config.mjs, so both forms are valid and need to be treated as equal.
 */
export function normalizePathname(path: string): string {
  return path.replace(/\/+$/, '') || '/';
}
