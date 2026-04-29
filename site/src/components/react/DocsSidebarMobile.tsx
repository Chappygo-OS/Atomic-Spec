/**
 * DocsSidebarMobile — drawer-style nav for `<lg` viewports.
 *
 * The Astro DocsSidebar is hidden on mobile; this component fills that
 * gap with a hamburger button that toggles a slide-in drawer. The nav
 * data is JSON-serialized at build time and passed in as a prop, so the
 * island stays small (no client-side fetch, no Astro content hydration).
 *
 * Hydration: `client:idle` from the layout — the sidebar is non-critical
 * and shouldn't compete with hero / TOC interactions for first paint.
 *
 * Accessibility:
 *   - Trigger has `aria-expanded` + `aria-controls`
 *   - ESC closes
 *   - Click on backdrop closes
 *   - Focus moves to the close button when opened, returns to trigger
 *     when closed (a soft focus trap; the drawer is small enough that a
 *     full focus-trap library would be overkill)
 *   - Body scroll-locks while open so the page underneath doesn't drift
 */
import { useEffect, useRef, useState } from 'react';
import { Menu, X } from 'lucide-react';
import type { NavGroup } from '../../lib/nav';
import { normalizePathname } from '../../lib/url';

interface DocsSidebarMobileProps {
  nav: NavGroup[];
  /** Pathname of the active doc — passed in from Astro at build time. */
  currentPath: string;
}

const PANEL_ID = 'docs-mobile-nav-panel';

export default function DocsSidebarMobile({ nav, currentPath }: DocsSidebarMobileProps) {
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const triggerRef = useRef<HTMLButtonElement | null>(null);
  const closeBtnRef = useRef<HTMLButtonElement | null>(null);
  const drawerRef = useRef<HTMLElement | null>(null);

  const normalizedCurrent = normalizePathname(currentPath);

  // ESC to close, focus management, body scroll lock, and full focus trap.
  useEffect(() => {
    if (!isOpen) {
      return;
    }

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    // rAF so the drawer is in layout before we focus — avoids a visible flash.
    const focusFrame = requestAnimationFrame(() => {
      closeBtnRef.current?.focus();
    });

    function focusables(): HTMLElement[] {
      const root = drawerRef.current;
      if (!root) return [];
      return Array.from(
        root.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])',
        ),
      ).filter((el) => !el.hasAttribute('inert') && el.offsetParent !== null);
    }

    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        setIsOpen(false);
        return;
      }
      if (e.key !== 'Tab') return;
      // Clamp Tab + Shift-Tab to the first/last focusable in the drawer.
      const items = focusables();
      if (items.length === 0) return;
      const first = items[0];
      const last = items[items.length - 1];
      const active = document.activeElement as HTMLElement | null;
      if (e.shiftKey && active === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    }
    window.addEventListener('keydown', onKey);

    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = previousOverflow;
      cancelAnimationFrame(focusFrame);
      triggerRef.current?.focus();
    };
  }, [isOpen]);

  return (
    <>
      {/* Sticky bar visible only on <lg, sits below the site header.
          Uses --header-h CSS var so the offset stays in sync with the actual
          header height (set in BaseLayout / Header.astro). */}
      <div
        className="sticky z-30 border-b border-slate-800/60 bg-slate-950/80 backdrop-blur lg:hidden"
        style={{ top: 'var(--header-h, 3.5rem)' }}
      >
        <button
          ref={triggerRef}
          type="button"
          aria-expanded={isOpen}
          aria-controls={PANEL_ID}
          aria-label="Open documentation menu"
          onClick={() => setIsOpen(true)}
          className="flex w-full items-center gap-2 px-4 py-3 text-sm font-medium text-slate-300 transition hover:text-white"
        >
          <Menu className="h-4 w-4" aria-hidden="true" />
          <span>Browse documentation</span>
        </button>
      </div>

      {/* Backdrop + drawer. `aria-hidden` removed (not set to "false") when
          open — `aria-hidden="false"` is treated inconsistently across SRs. */}
      <div
        className={[
          'fixed inset-0 z-50 transition-opacity duration-200 lg:hidden',
          isOpen ? 'pointer-events-auto opacity-100' : 'pointer-events-none opacity-0',
        ].join(' ')}
        aria-hidden={isOpen ? undefined : true}
      >
        {/* Backdrop — tabIndex=-1 so it's not in the focus order; the explicit
            close button in the drawer header is the keyboard exit. */}
        <div
          aria-hidden="true"
          onClick={() => setIsOpen(false)}
          className="absolute inset-0 bg-slate-950/70 backdrop-blur-sm"
        />

        {/* Drawer */}
        <aside
          ref={drawerRef}
          id={PANEL_ID}
          role="dialog"
          aria-modal="true"
          aria-label="Documentation navigation"
          className={[
            'absolute inset-y-0 left-0 flex w-[85vw] max-w-sm flex-col border-r border-slate-800 bg-slate-950 shadow-2xl transition-transform duration-200',
            isOpen ? 'translate-x-0' : '-translate-x-full',
          ].join(' ')}
        >
          <header className="flex items-center justify-between border-b border-slate-800 px-5 py-4">
            <p className="text-xs font-bold uppercase tracking-wider text-slate-400">
              Documentation
            </p>
            <button
              ref={closeBtnRef}
              type="button"
              aria-label="Close documentation menu"
              onClick={() => setIsOpen(false)}
              className="rounded-md p-1 text-slate-400 transition hover:bg-white/5 hover:text-white"
            >
              <X className="h-5 w-5" aria-hidden="true" />
            </button>
          </header>

          <nav className="flex-1 overflow-y-auto px-5 py-4" aria-label="Documentation">
            {nav.map((group) => (
              <div key={group.category} className="mb-6 last:mb-0">
                <h2 className="mb-2 text-xs font-bold uppercase tracking-wider text-slate-500">
                  {group.category}
                </h2>
                <ul className="space-y-0.5">
                  {group.items.map((item) => {
                    const isActive = normalizePathname(item.href) === normalizedCurrent;
                    // Inactive items keep a transparent left border so the
                    // active state's emerald border doesn't reflow the row.
                    return (
                      <li key={item.slug}>
                        <a
                          href={item.href}
                          aria-current={isActive ? 'page' : undefined}
                          onClick={() => setIsOpen(false)}
                          className={[
                            'block rounded-md border-l-2 py-1.5 pl-3 text-sm transition',
                            isActive
                              ? 'border-emerald-500 font-semibold text-emerald-400'
                              : 'border-transparent text-slate-300 hover:text-white',
                          ].join(' ')}
                        >
                          {item.title}
                        </a>
                      </li>
                    );
                  })}
                </ul>
              </div>
            ))}
          </nav>
        </aside>
      </div>
    </>
  );
}
