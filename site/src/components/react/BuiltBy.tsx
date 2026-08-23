/**
 * BuiltBy — bottom-of-homepage maintainer section.
 *
 * Renders LinkedIn official profile badges for the two maintainers,
 * lazy-loaded on two levels so nothing from `platform.linkedin.com`
 * loads until the user actually reaches this section:
 *
 *   1. `client:visible` on the island (in index.astro) — Astro hydrates
 *      this component only when its bounding box scrolls in. No React,
 *      no useEffect, no script injection until the user gets here.
 *   2. LinkedIn's badge script uses their standard fallback-inside-the-div
 *      pattern — before the script loads (or if it never does, e.g.
 *      adblocker / LinkedIn CDN down), our own placeholder content
 *      stays visible. When the script fires, LinkedIn replaces the
 *      contents of each `.LI-profile-badge` div with its own iframe.
 *
 * Zero third-party cost on landing. Zero blocked render. Fallback that
 * never leaves the reader looking at a blank card.
 *
 * Trade-off (accepted deliberately): once LinkedIn's iframe renders,
 * the badge design is LinkedIn's, not ours. The wrapper `<div>` keeps
 * a subtle site-native frame around it (rounded, border, dark surface).
 */
import { useEffect } from 'react';

interface Maintainer {
  /** LinkedIn URL slug (the /in/{vanity} portion). */
  vanity: string;
  name: string;
  /** Short role label — kept ≤ ~40 chars so the placeholder doesn't wrap. */
  role: string;
  /** Two-letter monogram used in the fallback avatar. */
  initials: string;
}

const MAINTAINERS: Maintainer[] = [
  {
    vanity: 'mohammadkhoddami',
    name: 'Mohammad Khoddami',
    role: 'Maintainer · Prime Directives',
    initials: 'MK',
  },
  {
    vanity: 'pablo-nastar',
    name: 'Pablo Nastar',
    role: 'Maintainer · Assembly Line',
    initials: 'PN',
  },
];

const LINKEDIN_BADGE_SRC = 'https://platform.linkedin.com/badges/js/profile.js';

/**
 * Idempotently inject LinkedIn's badge script. Guards against duplicate
 * injection if this component is unmounted+remounted for any reason.
 */
function injectLinkedInBadgeScript(): void {
  if (typeof document === 'undefined') return;
  if (document.querySelector(`script[src="${LINKEDIN_BADGE_SRC}"]`)) return;
  const script = document.createElement('script');
  script.src = LINKEDIN_BADGE_SRC;
  script.async = true;
  script.defer = true;
  document.head.appendChild(script);
}

export default function BuiltBy() {
  useEffect(() => {
    // If this useEffect fires, the island has already been hydrated,
    // which under `client:visible` means the user has scrolled here.
    // Safe to load the script now.
    injectLinkedInBadgeScript();
  }, []);

  return (
    <section
      id="built-by"
      className="border-t border-slate-800/50 py-24"
      aria-labelledby="built-by-heading"
    >
      <div className="container mx-auto px-4">
        <div className="mb-12 text-center">
          <p className="mb-3 font-mono text-[11px] uppercase tracking-[0.22em] text-emerald-300">
            The humans
          </p>
          <h2
            id="built-by-heading"
            className="text-3xl font-bold text-white md:text-4xl"
          >
            Built by
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-slate-400">
            Two maintainers steward this fork. Each owns a load-bearing
            pillar of the framework — the Nine Prime Directives and the
            Assembly Line mental model.
          </p>
        </div>

        <div className="mx-auto grid max-w-3xl gap-6 sm:grid-cols-2">
          {MAINTAINERS.map((m) => (
            <div
              key={m.vanity}
              className="badge-base LI-profile-badge relative min-h-[340px] overflow-hidden rounded-xl border border-slate-800 bg-slate-900/40"
              data-locale="en_US"
              data-size="medium"
              data-theme="dark"
              data-type="VERTICAL"
              data-vanity={m.vanity}
              data-version="v1"
            >
              {/* Fallback / placeholder content — visible while LinkedIn's
                  script hasn't rendered (before scroll, during script
                  download, or permanently if the script never loads).
                  LinkedIn's script replaces the contents of the .LI-profile-badge
                  div when it fires, so this whole block gets swapped
                  out gracefully. If the script is blocked (adblocker,
                  CSP, LinkedIn CDN down), this stays as the honest
                  fallback state. */}
              <div className="flex h-full flex-col items-center justify-center gap-3 p-8 text-center">
                <div
                  aria-hidden="true"
                  className="mb-2 inline-flex h-16 w-16 items-center justify-center rounded-full border border-emerald-400/20 bg-emerald-400/10 font-mono text-lg font-bold uppercase tracking-wider text-emerald-300"
                >
                  {m.initials}
                </div>
                <p className="text-lg font-semibold text-white">{m.name}</p>
                <p className="text-xs uppercase tracking-wider text-slate-500">
                  {m.role}
                </p>
                <a
                  className="badge-base__link LI-simple-link mt-2 inline-flex items-center gap-1 text-sm text-emerald-300 transition-colors hover:text-emerald-200 hover:underline"
                  href={`https://www.linkedin.com/in/${m.vanity}?trk=profile-badge`}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  View LinkedIn profile
                  <span aria-hidden="true">→</span>
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
