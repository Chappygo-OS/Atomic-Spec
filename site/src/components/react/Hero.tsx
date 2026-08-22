/**
 * Hero — above-the-fold marketing landing (v0.4 liquid-glass redesign).
 *
 * Composition:
 *   1. `<section id="hero">` establishes an isolated stacking context so the
 *      hero-local aurora cannot leak into the rest of the page.
 *   2. A single animated aurora sits behind the content: a conic gradient of
 *      iris + cyan at 8% opacity, softly rotating (~40s). Falls back to a
 *      static gradient under `prefers-reduced-motion`.
 *   3. All content lives inside a `.glass-hero` card — the visual-direction
 *      agent's rule "glass is the frame, never the content" means body text
 *      never sits directly on the animated aurora.
 *
 * Hydration: `client:load` because the typewriter, tilt handler, and
 * install-command clipboard all need to run as soon as the page is interactive.
 *
 * Motion policy (see design-research-motion.md):
 *   - Entry animations use var(--dur-narrative) 480ms + var(--ease-fluid).
 *   - Typewriter honors reduced-motion (paints the full string instantly).
 *   - Tilt is gated by `(pointer: fine)` AND reduced-motion — mobile and
 *     motion-sensitive users don't pay for an effect they can't (or won't) use.
 *   - Aurora rotates only when reduced-motion is off; the global reduced-motion
 *     rule in global.css also clamps its duration to 0.001ms as a safety net.
 *
 * Deps: no framer-motion, no react-parallax-tilt. Everything is native CSS,
 * WAAPI-free, and Tailwind 4 tokens sourced from global.css.
 */
import { useEffect, useRef, useState } from 'react';
import { ArrowRight, Check, Copy, Sparkles } from 'lucide-react';
import { withBase } from '../../lib/url';

const INSTALL_COMMAND = 'uv tool install atomic-spec';
const EYEBROW = 'Nine rules. Seventeen agents. Zero drift.';
const HEADLINE = 'Make your AI ship the spec, not the vibe.';
const SUBHEAD =
  'A governance framework that pins context, gates phase transitions, and forces atomic tasks — so Claude, Cursor, Copilot, and 14 others all produce the same PR from the same spec.';

interface TypewriterProps {
  text: string;
  speed?: number;
  delay?: number;
}

/**
 * Tracks the user's `prefers-reduced-motion` preference and stays current
 * if they toggle it mid-session. Returns `false` during SSR so the server
 * renders the animated variant and the client hydrates in place without
 * layout shift.
 */
function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  });

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    const handler = (e: MediaQueryListEvent): void => setReduced(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return reduced;
}

/**
 * SSR-safe typewriter. Server + first client render both emit the FULL text
 * so search engines, screen readers parsing the initial DOM, and no-JS users
 * see the headline immediately. On client mount, if the user hasn't opted
 * out of motion, we reset to `''` and animate the reveal — accepting one
 * paint flicker on JS-enabled clients who explicitly want the animation.
 *
 * Hydration mismatch is avoided because both server and client's INITIAL
 * useState value is `text`; the reset happens in an effect, after hydration.
 */
function useTypewriter({ text, speed = 40, delay = 0 }: TypewriterProps): string {
  const reduced = usePrefersReducedMotion();
  const [display, setDisplay] = useState<string>(text);
  const [index, setIndex] = useState<number>(text.length);
  const [armed, setArmed] = useState<boolean>(true);

  useEffect(() => {
    if (reduced) {
      // Motion-averse users stay on the full-text initial state — no
      // animation, no flicker. This is the accessibility branch.
      return;
    }
    // Client hydration finished; kick off the animation.
    setDisplay('');
    setIndex(0);
    setArmed(false);
    const t = setTimeout(() => setArmed(true), delay);
    return () => clearTimeout(t);
  }, [delay, reduced, text]);

  useEffect(() => {
    if (reduced) return;
    if (!armed) return;
    if (index >= text.length) return;
    const t = setTimeout(() => {
      setDisplay((prev) => prev + text[index]);
      setIndex((prev) => prev + 1);
    }, speed);
    return () => clearTimeout(t);
  }, [index, armed, speed, text, reduced]);

  return display;
}

interface TypewriterViewProps extends TypewriterProps {
  className?: string;
}

function Typewriter({ text, speed = 40, delay = 0, className }: TypewriterViewProps) {
  const display = useTypewriter({ text, speed, delay });
  // Hide the caret once typing finishes — leaving it blinking forever makes
  // the headline read as broken.
  const done = display === text && text.length > 0;
  return (
    <span className={className}>
      {display}
      {!done && (
        <span
          className="ml-1 inline-block w-[0.08em] animate-pulse text-primary-soft"
          aria-hidden="true"
          style={{ color: 'var(--color-primary-soft)' }}
        >
          |
        </span>
      )}
    </span>
  );
}

/**
 * Lightweight tilt — applies a small perspective rotateX/Y on mousemove, easing
 * back to neutral on mouseleave. Gated by:
 *   1. `(pointer: fine)` — no benefit on touch, just battery drain.
 *   2. `prefers-reduced-motion` — respect the user's motion preference.
 */
function useTilt<T extends HTMLElement>(maxAngle = 3, enabled = true) {
  const ref = useRef<T | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el || typeof window === 'undefined') return;
    if (!enabled) return;
    if (!window.matchMedia('(pointer: fine)').matches) return;

    let rafId = 0;

    function onMove(e: MouseEvent): void {
      cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(() => {
        if (!el) return;
        const rect = el.getBoundingClientRect();
        const x = (e.clientX - rect.left) / rect.width;
        const y = (e.clientY - rect.top) / rect.height;
        const rotateY = (x - 0.5) * (maxAngle * 2);
        const rotateX = -(y - 0.5) * (maxAngle * 2);
        el.style.transform = `perspective(1400px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
      });
    }

    function onLeave(): void {
      cancelAnimationFrame(rafId);
      if (!el) return;
      el.style.transform = '';
    }

    el.addEventListener('mousemove', onMove);
    el.addEventListener('mouseleave', onLeave);
    return () => {
      cancelAnimationFrame(rafId);
      el.removeEventListener('mousemove', onMove);
      el.removeEventListener('mouseleave', onLeave);
    };
  }, [maxAngle, enabled]);

  return ref;
}

/**
 * Copy-to-clipboard pill paired with the literal install command. Developers
 * scan for the exact snippet — the copy strategist agreed to keep this
 * affordance alongside the primary CTA. Falls back to text selection if the
 * Clipboard API is blocked (older Safari, http://, permission denied).
 */
function InstallCommandCopy() {
  const [copied, setCopied] = useState<boolean>(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => () => {
    if (timerRef.current) clearTimeout(timerRef.current);
  }, []);

  async function handleCopy(): Promise<void> {
    try {
      await navigator.clipboard.writeText(INSTALL_COMMAND);
      setCopied(true);
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(() => setCopied(false), 2000);
    } catch {
      const node = document.getElementById('hero-install-command');
      if (node && 'getSelection' in window) {
        const range = document.createRange();
        range.selectNodeContents(node);
        const sel = window.getSelection();
        sel?.removeAllRanges();
        sel?.addRange(range);
      }
    }
  }

  return (
    <>
      <span className="sr-only" aria-live="polite">
        {copied ? 'Install command copied to clipboard' : ''}
      </span>

      <button
        type="button"
        onClick={handleCopy}
        aria-label={`Copy install command: ${INSTALL_COMMAND}`}
        className="group inline-flex min-h-[44px] w-full min-w-0 items-center justify-between gap-3 rounded-lg border border-border bg-surface-1/60 px-4 py-3 font-mono text-xs text-text-muted backdrop-blur-sm transition-colors duration-[var(--dur-state)] ease-[var(--ease-fluid)] hover:border-primary/50 hover:text-text sm:w-auto sm:px-5 sm:text-sm"
      >
        <span className="flex min-w-0 items-center gap-2">
          <span
            aria-hidden="true"
            style={{ color: 'var(--color-gate-open)' }}
          >
            $
          </span>
          {/* iOS Safari long-press fallback: allow native text selection on the
              inner span so users can long-press → copy if they prefer. */}
          <span
            id="hero-install-command"
            className="truncate"
            style={{
              WebkitUserSelect: 'text',
              userSelect: 'text',
              WebkitTouchCallout: 'default',
            }}
          >
            {INSTALL_COMMAND}
          </span>
        </span>
        {/* Fixed-width chip — prevents button-width jitter when the label
            flips from "Copy" → "Copied". */}
        <span
          aria-hidden="true"
          className="flex w-[72px] shrink-0 items-center justify-end gap-1.5 text-xs uppercase tracking-wider transition-colors"
          style={{ color: copied ? 'var(--color-gate-open)' : 'var(--color-text-dim)' }}
        >
          {copied ? (
            <>
              <Check size={14} /> Copied
            </>
          ) : (
            <>
              <Copy size={14} /> Copy
            </>
          )}
        </span>
      </button>
    </>
  );
}

/**
 * Aurora — a single animated conic gradient behind the glass card. Uses design
 * tokens (iris primary + cyan secondary) so it stays on-palette. The wrapper
 * itself has `mix-blend-mode: screen` so it brightens the surface-0 body
 * without over-saturating it.
 *
 * Under `prefers-reduced-motion`, the global.css safety net collapses the
 * animation to 0.001ms — the aurora becomes a static gradient wash.
 * We also swap to a static conic frame here so its `transform` doesn't leave
 * the aurora in an arbitrary rotation from a mid-cycle collapse.
 */
function HeroAurora({ reduced }: { reduced: boolean }) {
  return (
    <>
      {/* Local keyframes — kept inline so this stays self-contained inside
          Hero.tsx (no global.css edits needed). React 19 hoists <style> to
          <head> at runtime. */}
      <style>{`
        @keyframes hero-aurora-rotate {
          from { transform: translate(-50%, -50%) rotate(0deg) scale(1.2); }
          to   { transform: translate(-50%, -50%) rotate(360deg) scale(1.2); }
        }
      `}</style>
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 -z-10 overflow-hidden"
      >
        <div
          className="absolute left-1/2 top-1/2 aspect-square w-[90%] max-w-[1100px] rounded-full"
          style={{
            transform: 'translate(-50%, -50%)',
            background:
              'conic-gradient(from 0deg at 50% 50%, transparent 0deg, var(--color-primary) 40deg, transparent 120deg, transparent 200deg, var(--color-secondary) 240deg, transparent 320deg)',
            // Perf pass: blur 90 → 56px (blur cost is O(r²), so ~2.6× cheaper)
            // and width 140% → capped 1100px (smaller source texture to blur).
            // Opacity nudged 0.12 → 0.16 to keep perceived weight after the
            // radius shrink. The CSS review agent identified this element as
            // the dominant per-frame cost above the fold — ~4-8 ms/frame at
            // the old settings. This edit targets the O(r²) portion first.
            filter: 'blur(56px)',
            opacity: 0.16,
            mixBlendMode: 'screen',
            animation: reduced
              ? 'none'
              : 'hero-aurora-rotate 24s linear infinite',
            willChange: reduced ? 'auto' : 'transform',
            // Isolate the aurora's paint / layout / style work from the rest
            // of the page — its rotation should never invalidate anything
            // outside its own bounding box.
            contain: 'layout paint style',
          }}
        />
      </div>
    </>
  );
}

export default function Hero() {
  const reducedMotion = usePrefersReducedMotion();
  const tiltRef = useTilt<HTMLDivElement>(3, !reducedMotion);

  return (
    <section
      id="hero"
      // `isolate` locks the aurora's `-z-10` into this section's stacking
      // context so it can never leak behind the site-wide AnimatedBackground.
      className="relative isolate flex min-h-[90dvh] items-center justify-center overflow-hidden px-4 py-24 sm:py-32"
    >
      {/* Faint structural grid — masked at the edges so it fades gracefully
          into the aurora rather than fighting with it. */}
      <div
        aria-hidden="true"
        className="bg-grid pointer-events-none absolute inset-0 -z-20 opacity-15
                   [mask-image:radial-gradient(ellipse_65%_55%_at_50%_40%,#000_60%,transparent_100%)]"
      />

      <HeroAurora reduced={reducedMotion} />

      <div className="relative z-10 mx-auto w-full max-w-3xl">
        <div
          ref={tiltRef}
          className="glass-hero px-6 py-10 sm:px-10 sm:py-14 md:px-14 md:py-16 [transform-style:preserve-3d]"
          style={{
            transition: reducedMotion
              ? 'none'
              : `transform var(--dur-narrative) var(--ease-fluid)`,
          }}
        >
          <div className="flex flex-col items-center gap-8 text-center">
            {/* Eyebrow — the elevator pitch in 5 words, mono-tinted so it
                reads as a system tag rather than marketing copy. */}
            <div
              className="fade-up inline-flex items-center gap-2 rounded-full border border-border-strong bg-surface-2/60 px-3.5 py-1.5 font-mono text-xs uppercase tracking-[0.14em] text-text-muted backdrop-blur-sm"
              style={{ animationDelay: '0ms' }}
            >
              <Sparkles size={14} aria-hidden="true" style={{ color: 'var(--color-primary-soft)' }} />
              <span>{EYEBROW}</span>
            </div>

            {/* Headline — single semantic <h1> wrapping the typewriter span.
                Min-height reserves layout space so the typewriter doesn't
                cause CLS as characters print in. */}
            <h1
              className="fade-up min-h-[6.5rem] text-balance text-4xl font-semibold leading-[1.1] tracking-tight text-text sm:min-h-[7.5rem] sm:text-5xl md:min-h-[8.5rem] md:text-6xl"
              style={{ animationDelay: '100ms' }}
            >
              <Typewriter text={HEADLINE} speed={35} delay={300} />
            </h1>

            {/* Subhead — sits on the glass card, not the aurora. Uses
                `text-text-muted` which is oklch(75% 0.015 265) — well over
                4.5:1 against the glass-hero surface-2 opaque fallback. */}
            <p
              className="fade-up max-w-2xl text-pretty text-lg leading-relaxed text-text-muted sm:text-xl"
              style={{ animationDelay: '200ms' }}
            >
              {SUBHEAD}
            </p>

            <div
              className="fade-up relative z-20 w-full space-y-5"
              style={{ animationDelay: '300ms' }}
            >
              <div className="flex flex-col items-stretch justify-center gap-3 sm:flex-row sm:items-center">
                {/* Primary CTA — Install. Emerald `bg-gate-open` retains the
                    v0.3 install-button recognition per copy strategist. */}
                <a
                  href={withBase('/docs/installation')}
                  className="inline-flex items-center justify-center gap-2 rounded-lg px-8 py-4 text-base font-bold uppercase tracking-wider transition-all duration-[var(--dur-state)] ease-[var(--ease-fluid)] hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:px-10 sm:py-5 sm:text-lg"
                  style={{
                    backgroundColor: 'var(--color-gate-open)',
                    color: 'var(--color-surface-0)',
                    boxShadow: '0 12px 40px -12px color-mix(in oklch, var(--color-gate-open) 60%, transparent)',
                  }}
                >
                  Install
                  <ArrowRight size={20} aria-hidden="true" strokeWidth={2.5} />
                </a>

                {/* Install command copy pill — trust-earning affordance for
                    developers who scroll past marketing copy. */}
                <InstallCommandCopy />
              </div>

              {/* Secondary CTA — links to the Nine Prime Directives doc.
                  Ghost style with iris hover per visual-direction brief. */}
              <div className="flex justify-center">
                <a
                  href={withBase('/docs/prime-directives')}
                  className="group inline-flex min-h-[44px] items-center gap-1.5 rounded-md px-3 py-2 text-sm font-medium text-text-muted transition-colors duration-[var(--dur-state)] ease-[var(--ease-fluid)] hover:text-text focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
                >
                  Read the Nine Prime Directives
                  <ArrowRight
                    size={14}
                    aria-hidden="true"
                    className="transition-transform duration-[var(--dur-state)] ease-[var(--ease-fluid)] group-hover:translate-x-0.5"
                  />
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
