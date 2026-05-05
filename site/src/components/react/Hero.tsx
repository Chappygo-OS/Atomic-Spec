/**
 * Hero — above-the-fold marketing landing.
 *
 * Hydrated `client:load` because the typewriter, install-pill clipboard, and
 * tilt handler all need to run as soon as the page is interactive.
 *
 * Performance notes (post-audit):
 *   - Dropped `framer-motion` (~30 KB gz) — replaced with CSS `.fade-up` /
 *     `.fade-scale` keyframe utilities defined in global.css. Identical visual.
 *   - Dropped `react-parallax-tilt` (~7 KB gz) — replaced with a 30-line
 *     mousemove handler gated by `(pointer: fine)`, so phones (no mouse) skip
 *     the listeners entirely.
 *   - `prefers-reduced-motion` lifted out of render into a hook with a proper
 *     `change` subscription so toggling system settings updates live.
 *
 * Brand notes:
 *   - Headline mirrors the README ("Stop your AI from vibe-coding.").
 *   - Subhead leads with concrete numbers (eight directives, four checkpoints).
 *   - Chaos panel is muted until hover; Assembly Line is always lit — visually
 *     reinforces the "system that ships" framing.
 */
import { useEffect, useRef, useState } from 'react';
import { Activity, ArrowRight, Check, Copy, GitCommit } from 'lucide-react';
import { withBase } from '../../lib/url';

const INSTALL_COMMAND = 'uv tool install atomic-spec';
const HEADLINE = 'Stop your AI from vibe-coding.\nStart shipping atomic specs.';

interface TypewriterProps {
  text: string;
  speed?: number;
  delay?: number;
}

/**
 * Tracks the user's `prefers-reduced-motion` preference and stays current
 * if they toggle it mid-session. Returns `false` during SSR.
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

function useTypewriter({ text, speed = 50, delay = 0 }: TypewriterProps): string {
  const reduced = usePrefersReducedMotion();
  const [display, setDisplay] = useState<string>(reduced ? text : '');
  const [index, setIndex] = useState<number>(reduced ? text.length : 0);
  const [armed, setArmed] = useState<boolean>(reduced);

  useEffect(() => {
    if (reduced) {
      setDisplay(text);
      setIndex(text.length);
      setArmed(true);
      return;
    }
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

function Typewriter({ text, speed = 50, delay = 0 }: TypewriterProps) {
  const display = useTypewriter({ text, speed, delay });
  // Hide the caret once typing finishes — leaving it blinking forever makes
  // the headline read as broken.
  const done = display === text && text.length > 0;
  return (
    <span>
      {display}
      {!done && (
        <span className="ml-1 inline-block animate-pulse text-emerald-400" aria-hidden="true">
          |
        </span>
      )}
    </span>
  );
}

/**
 * Lightweight tilt — applies a perspective rotateX/Y on mousemove, smoothly
 * easing back to neutral on mouseleave. Gated by `(pointer: fine)` so touch
 * devices skip the listeners entirely (no benefit, just battery drain).
 */
function useTilt<T extends HTMLElement>(maxAngle = 5) {
  const ref = useRef<T | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el || typeof window === 'undefined') return;
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
        el.style.transform = `perspective(1200px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
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
  }, [maxAngle]);

  return ref;
}

/**
 * Copy-to-clipboard pill paired with the literal install command. Visual
 * sibling to the big INSTALL button so devs see the snippet without leaving
 * the hero. Falls back to text selection if the Clipboard API is blocked.
 */
function InstallCommandCopy() {
  const [copied, setCopied] = useState<boolean>(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Clear any pending "copied" timer on unmount to avoid setting state on
  // an unmounted component.
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
      // Clipboard blocked (older Safari, http://, permission denied).
      // Fall back to selecting the text so the user can copy manually.
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
      {/* Off-screen status announce — keeps the button's accessible name
          stable so screen readers don't re-announce the whole label. */}
      <span className="sr-only" aria-live="polite">
        {copied ? 'Install command copied to clipboard' : ''}
      </span>

      <button
        type="button"
        onClick={handleCopy}
        aria-label={`Copy install command: ${INSTALL_COMMAND}`}
        className="group inline-flex w-full min-w-0 items-center justify-between gap-3 rounded-lg border border-slate-700 bg-slate-900/60 px-4 py-3 font-mono text-xs text-slate-300 backdrop-blur-sm transition-colors hover:border-emerald-500/40 hover:bg-slate-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-300 sm:w-auto sm:px-5 sm:text-sm"
      >
        <span className="flex min-w-0 items-center gap-2">
          <span className="text-emerald-400" aria-hidden="true">$</span>
          {/* iOS Safari long-press fallback: allow native text selection on
              the inner span so users can long-press → copy if they prefer. */}
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
        {/* Fixed-width chip — prevents button-width jitter when label flips
            from "Copy" → "Copied". */}
        <span
          aria-hidden="true"
          className={`flex w-[72px] shrink-0 items-center justify-end gap-1.5 text-xs uppercase tracking-wider transition-colors ${
            copied ? 'text-emerald-400' : 'text-slate-500 group-hover:text-emerald-300'
          }`}
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

export default function Hero() {
  const tiltRef = useTilt<HTMLDivElement>(5);

  return (
    <section
      id="hero"
      className="relative flex min-h-[90vh] items-center justify-center overflow-hidden px-4 py-20"
    >
      {/* Faint structural grid behind the hero. The radial mask keeps it from
          fighting with the AnimatedBackground blobs further down the page. */}
      <div
        aria-hidden="true"
        className="bg-grid pointer-events-none absolute inset-0 opacity-20
                   [mask-image:radial-gradient(ellipse_60%_50%_at_50%_0%,#000_70%,transparent_100%)]"
      />

      <div className="relative z-10 mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2">
        <div className="space-y-8 text-left">
          <div className="fade-up inline-flex items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/10 px-3 py-1 text-sm font-medium text-emerald-400">
            <Activity size={16} aria-hidden="true" />
            <span>Precision engineering for AI-written code</span>
          </div>

          <h1
            className="fade-up min-h-[110px] whitespace-pre-line text-[2.5rem] font-bold leading-[1.1] tracking-tight text-white sm:min-h-[150px] sm:text-5xl md:min-h-[180px] md:text-6xl"
            style={{ animationDelay: '100ms' }}
          >
            <Typewriter text={HEADLINE} speed={50} delay={500} />
          </h1>

          <p
            className="fade-up max-w-lg text-xl leading-relaxed text-slate-400"
            style={{ animationDelay: '200ms' }}
          >
            Atomic Spec turns unpredictable AI into a governed assembly line —{' '}
            <span className="font-medium text-slate-200">eight Prime Directives</span>,{' '}
            <span className="font-medium text-slate-200">four HITL checkpoints</span>, atomic
            task files, and{' '}
            <span className="font-medium text-slate-200">21 specialized subagents</span>.
          </p>

          <div className="fade-up relative z-20 space-y-4" style={{ animationDelay: '300ms' }}>
            {/* Primary: big INSTALL button paired with the actual command,
                copy-to-clipboard. Boss requested a single prominent install
                affordance; pairing it with the literal command earns trust
                with developers (who skip marketing and look for the snippet). */}
            <div className="flex flex-col gap-3 sm:flex-row sm:items-stretch">
              <a
                href={withBase('/docs/installation')}
                className="inline-flex items-center justify-center gap-2 rounded-lg bg-emerald-500 px-10 py-5 text-lg font-bold uppercase tracking-wider text-slate-950 shadow-[0_10px_40px_-10px_rgba(16,185,129,0.7)] transition-all hover:bg-emerald-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-300"
              >
                Install <ArrowRight size={22} aria-hidden="true" strokeWidth={2.5} />
              </a>

              <InstallCommandCopy />
            </div>

            <div className="flex flex-wrap gap-3 text-sm">
              <a
                href="#workflow"
                className="inline-flex min-h-[44px] items-center gap-1.5 rounded-md px-3 py-2 font-medium text-slate-300 transition-colors hover:text-white"
              >
                See how it works <ArrowRight size={14} aria-hidden="true" />
              </a>
              <span aria-hidden="true" className="self-center text-slate-700">·</span>
              <a
                href="#manual"
                className="inline-flex min-h-[44px] items-center rounded-md px-3 py-2 font-medium text-slate-300 transition-colors hover:text-white"
              >
                Read the manual
              </a>
            </div>
          </div>
        </div>

        {/* Visual comparison with native CSS tilt (no library). The `useTilt`
            hook installs a mousemove listener only on `(pointer: fine)`
            devices so phones don't pay for an effect they can't use. */}
        <div className="fade-scale relative">
          <div
            ref={tiltRef}
            className="group relative h-full overflow-hidden rounded-xl border border-slate-800 bg-slate-900/50 p-6 shadow-2xl backdrop-blur-sm [transform-style:preserve-3d] [transition:transform_400ms_ease-out]"
          >
            <div className="absolute left-0 top-0 h-1 w-full bg-gradient-to-r from-red-500 via-amber-500 to-emerald-500" />

            <div className="grid h-[400px] grid-cols-2 gap-4">
              {/* Left: Chaos */}
              <div className="flex flex-col items-center justify-center border-r border-slate-800 pr-4 opacity-40 transition-opacity group-hover:opacity-100">
                <div className="mb-4 font-mono text-sm text-red-400">Chaos mode</div>
                <div className="w-full space-y-3">
                  <div className="h-2 w-3/4 animate-pulse rounded bg-slate-700" />
                  <div
                    className="h-2 w-1/2 animate-pulse rounded bg-slate-700"
                    style={{ animationDelay: '300ms' }}
                  />
                  <div
                    className="h-2 w-full animate-pulse rounded bg-slate-700"
                    style={{ animationDelay: '600ms' }}
                  />
                  <div className="flex h-32 w-full items-center justify-center rounded border border-red-500/30 bg-red-500/5 p-2 text-center text-xs text-red-500/60">
                    Context pollution
                    <br />
                    Hallucinations
                    <br />
                    Zero governance
                  </div>
                </div>
              </div>

              {/* Right: Assembly Line */}
              <div className="flex flex-col items-center justify-center pl-4">
                <div className="mb-4 font-mono text-sm text-emerald-400">Assembly Line</div>
                <div className="w-full space-y-4">
                  <div className="flex items-center gap-2">
                    <GitCommit size={16} className="text-emerald-500" aria-hidden="true" />
                    <div className="h-2 w-20 rounded bg-emerald-500/30" />
                  </div>
                  <div className="flex items-center gap-2 border-l border-slate-700 pl-4">
                    <div className="h-3 w-3 rounded-full bg-emerald-500" />
                    <div className="h-8 w-full rounded border border-slate-700 bg-slate-800 p-2 font-mono text-[10px] text-slate-300">
                      HITL checkpoint: approved
                    </div>
                  </div>
                  <div className="flex items-center gap-2 border-l border-slate-700 pl-4">
                    <div className="h-3 w-3 rounded-full bg-blue-500" />
                    <div className="h-8 w-full rounded border border-slate-700 bg-slate-800 p-2 font-mono text-[10px] text-slate-300">
                      Task T-001: pinned
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
