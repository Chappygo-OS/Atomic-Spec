/**
 * DocsSearchBar — client-side static search over the docs collection.
 *
 * Loads `/search-index.json` on first focus (~5-8 KB gzipped, one fetch,
 * cached in module scope for the rest of the session). Scores queries
 * against title / keywords / headings / description with hand-tuned
 * weights so short queries hit obvious pages first.
 *
 * Zero runtime dependencies beyond React + lucide-react (both already in
 * the site's stack). No search engine, no external service, no build-time
 * indexer package — the index is emitted by `src/pages/search-index.json.ts`.
 *
 * Accessibility: ARIA combobox pattern. Global `Cmd/Ctrl+K` focuses the
 * input. `ArrowDown` / `ArrowUp` cycle results, `Enter` navigates,
 * `Escape` clears + blurs. Screen readers get a live-region result count.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { KeyboardEvent as ReactKeyboardEvent } from 'react';
import { Search, ArrowUpRight } from 'lucide-react';
import { withBase } from '../../lib/url';
import { rankResults } from '../../lib/search';
import type { ScoredResult, SearchIndexEntry } from '../../lib/search';

// Module-scoped cache — the index is fetched once per browser session.
// Cheaper than an in-component ref because it survives unmount/remount.
let cachedIndex: SearchIndexEntry[] | null = null;
let inflightFetch: Promise<SearchIndexEntry[]> | null = null;

async function loadIndex(): Promise<SearchIndexEntry[]> {
  if (cachedIndex) return cachedIndex;
  if (inflightFetch) return inflightFetch;
  inflightFetch = fetch(withBase('/search-index.json'))
    .then((r) => (r.ok ? (r.json() as Promise<SearchIndexEntry[]>) : []))
    .catch(() => [])
    .then((data) => {
      cachedIndex = data;
      inflightFetch = null;
      return data;
    });
  return inflightFetch;
}

// ---- Component ----------------------------------------------------------
export default function DocsSearchBar() {
  const [query, setQuery] = useState<string>('');
  const [index, setIndex] = useState<SearchIndexEntry[]>([]);
  const [open, setOpen] = useState<boolean>(false);
  const [selected, setSelected] = useState<number>(0);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const listId = 'docs-search-listbox';

  const results = useMemo<ScoredResult[]>(
    () => (query ? rankResults(index, query) : []),
    [index, query],
  );

  // Global Cmd/Ctrl+K shortcut.
  useEffect(() => {
    function onKey(e: KeyboardEvent): void {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        inputRef.current?.focus();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const ensureIndex = useCallback(async () => {
    if (index.length > 0) return;
    const data = await loadIndex();
    setIndex(data);
  }, [index.length]);

  const onKeyDown = (e: ReactKeyboardEvent<HTMLInputElement>): void => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (results.length === 0) return;
      setSelected((s) => (s + 1) % results.length);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (results.length === 0) return;
      setSelected((s) => (s - 1 + results.length) % results.length);
    } else if (e.key === 'Enter') {
      const target = results[selected];
      if (target) {
        const anchor = target.matchedHeading ? `#${target.matchedHeading.slug}` : '';
        window.location.href = target.href + anchor;
      }
    } else if (e.key === 'Escape') {
      setQuery('');
      setOpen(false);
      inputRef.current?.blur();
    }
  };

  // Reset selection whenever the query changes so we don't leave the
  // highlight on an index that no longer exists.
  useEffect(() => setSelected(0), [query]);

  const showDropdown = open && query.length > 0;

  return (
    <div className="relative">
      <label className="sr-only" htmlFor="docs-search-input">
        Search docs
      </label>
      <div className="relative">
        <Search
          size={16}
          aria-hidden="true"
          className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-text-dim"
        />
        <input
          ref={inputRef}
          id="docs-search-input"
          type="search"
          role="combobox"
          aria-expanded={showDropdown}
          aria-controls={listId}
          aria-autocomplete="list"
          autoComplete="off"
          placeholder="Search docs..."
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => {
            void ensureIndex();
            setOpen(true);
          }}
          onBlur={() => {
            // Delay so a click on a result registers before we close.
            setTimeout(() => setOpen(false), 120);
          }}
          onKeyDown={onKeyDown}
          className="w-full min-h-[44px] rounded-lg border border-border bg-surface-1/60 px-9 py-2 text-sm text-text placeholder:text-text-dim backdrop-blur-sm transition-colors focus:border-primary/60 focus:outline-none focus:ring-2 focus:ring-primary/40"
        />
        <kbd
          aria-hidden="true"
          className="pointer-events-none absolute right-3 top-1/2 hidden -translate-y-1/2 select-none rounded border border-border bg-surface-2/60 px-1.5 py-0.5 font-mono text-[10px] uppercase tracking-wider text-text-dim md:inline-block"
        >
          {typeof navigator !== 'undefined' && /Mac|iPhone|iPad|iPod/.test(navigator.platform) ? '⌘K' : 'Ctrl K'}
        </kbd>
      </div>

      <span className="sr-only" aria-live="polite">
        {query.length > 0 ? `${results.length} search result${results.length === 1 ? '' : 's'}` : ''}
      </span>

      {showDropdown && (
        <ul
          id={listId}
          role="listbox"
          className="absolute left-0 right-0 top-[calc(100%+0.5rem)] z-30 max-h-[70vh] overflow-y-auto rounded-lg border border-border bg-surface-1/95 py-1 shadow-lg backdrop-blur-md"
        >
          {results.length === 0 ? (
            <li className="px-4 py-3 text-sm text-text-dim">
              No matches for <span className="font-mono text-text">{query}</span>.
            </li>
          ) : (
            results.map((r, i) => {
              const anchor = r.matchedHeading ? `#${r.matchedHeading.slug}` : '';
              const isSelected = i === selected;
              return (
                <li
                  key={r.slug + (r.matchedHeading?.slug ?? '')}
                  role="option"
                  aria-selected={isSelected}
                >
                  <a
                    href={r.href + anchor}
                    onMouseEnter={() => setSelected(i)}
                    className={`flex items-start gap-3 px-4 py-3 text-sm transition-colors ${
                      isSelected ? 'bg-primary/10 text-text' : 'text-text-muted hover:bg-surface-2/60'
                    }`}
                  >
                    <span className="mt-0.5 flex-1 min-w-0">
                      <span className="block truncate font-medium text-text">{r.title}</span>
                      <span className="mt-0.5 flex items-center gap-2 truncate text-xs text-text-dim">
                        <span className="rounded bg-surface-2/80 px-1.5 py-0.5 font-mono uppercase tracking-wider">
                          {r.category}
                        </span>
                        <span className="truncate">
                          {r.matchedHeading ? `→ ${r.matchedHeading.text}` : r.description}
                        </span>
                      </span>
                    </span>
                    <ArrowUpRight size={14} aria-hidden="true" className="mt-0.5 shrink-0 text-text-dim" />
                  </a>
                </li>
              );
            })
          )}
        </ul>
      )}
    </div>
  );
}
