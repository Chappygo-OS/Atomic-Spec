/**
 * Hero — above-the-fold marketing landing.
 *
 * Hydrated `client:load` because the typewriter and tilt are immediately visible.
 * Animates a two-line headline with a blinking caret, fades the subhead and CTAs,
 * then renders the chaos-vs-assembly dual panel inside a `react-parallax-tilt` card.
 *
 * Brand notes:
 *   - Headline mirrors the README ("Stop your AI from vibe-coding.").
 *   - Subhead leads with concrete numbers (eight directives, four checkpoints).
 *   - Chaos panel is muted until hover; Assembly Line is always lit — visually
 *     reinforces the "system that ships" framing.
 */
import { useEffect, useState } from 'react';
import { Activity, ArrowRight, Check, Copy, GitCommit } from 'lucide-react';
import { motion } from 'framer-motion';
import Tilt from 'react-parallax-tilt';
import { withBase } from '../../lib/url';

const INSTALL_COMMAND = 'uv tool install atomic-spec';

interface TypewriterProps {
  text: string;
  speed?: number;
  delay?: number;
}

function prefersReducedMotion(): boolean {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function useTypewriter({ text, speed = 50, delay = 0 }: TypewriterProps): string {
  // Honor prefers-reduced-motion: skip the animation, render full text immediately.
  const reduced = prefersReducedMotion();
  const [display, setDisplay] = useState(reduced ? text : '');
  const [index, setIndex] = useState(reduced ? text.length : 0);
  const [armed, setArmed] = useState(reduced);

  useEffect(() => {
    if (reduced) return;
    const t = setTimeout(() => setArmed(true), delay);
    return () => clearTimeout(t);
  }, [delay, reduced]);

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

const HEADLINE = 'Stop your AI from vibe-coding.\nStart shipping atomic specs.';

/**
 * Copy-to-clipboard pill that shows the install command and copies it on click.
 * Visual sibling to the big INSTALL button so devs see the literal snippet
 * without leaving the hero — no waiting for the docs page to load.
 */
function InstallCommandCopy() {
  const [copied, setCopied] = useState(false);

  async function handleCopy(): Promise<void> {
    try {
      await navigator.clipboard.writeText(INSTALL_COMMAND);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard blocked (older Safari, http://, permissions denied).
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
    <button
      type="button"
      onClick={handleCopy}
      aria-label={copied ? 'Install command copied' : `Copy install command: ${INSTALL_COMMAND}`}
      className="group inline-flex items-center justify-between gap-3 rounded-lg border border-slate-700 bg-slate-900/60 px-4 py-3 font-mono text-sm text-slate-300 backdrop-blur-sm transition-colors hover:border-emerald-500/40 hover:bg-slate-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-300 sm:px-5"
    >
      <span className="flex items-center gap-2">
        <span className="text-emerald-400" aria-hidden="true">$</span>
        <span id="hero-install-command">{INSTALL_COMMAND}</span>
      </span>
      <span
        className={`flex items-center gap-1.5 text-xs uppercase tracking-wider transition-colors ${
          copied ? 'text-emerald-400' : 'text-slate-500 group-hover:text-emerald-300'
        }`}
        aria-live="polite"
      >
        {copied ? (
          <>
            <Check size={14} aria-hidden="true" /> Copied
          </>
        ) : (
          <>
            <Copy size={14} aria-hidden="true" /> Copy
          </>
        )}
      </span>
    </button>
  );
}

export default function Hero() {
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
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="inline-flex items-center gap-2 rounded-full border border-emerald-500/20 bg-emerald-500/10 px-3 py-1 text-sm font-medium text-emerald-400"
          >
            <Activity size={16} aria-hidden="true" />
            <span>Precision engineering for AI-written code</span>
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="min-h-[150px] whitespace-pre-line text-5xl font-bold leading-[1.1] tracking-tight text-white md:min-h-[180px] md:text-6xl"
          >
            <Typewriter text={HEADLINE} speed={50} delay={500} />
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="max-w-lg text-xl leading-relaxed text-slate-400"
          >
            Atomic Spec turns unpredictable AI into a governed assembly line —{' '}
            <span className="font-medium text-slate-200">eight Prime Directives</span>,{' '}
            <span className="font-medium text-slate-200">four HITL checkpoints</span>, atomic
            task files, and{' '}
            <span className="font-medium text-slate-200">21 specialized subagents</span>.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="relative z-20 space-y-4"
          >
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
                className="inline-flex items-center gap-1.5 rounded-md px-3 py-2 font-medium text-slate-300 transition-colors hover:text-white"
              >
                See how it works <ArrowRight size={14} aria-hidden="true" />
              </a>
              <span aria-hidden="true" className="text-slate-700">·</span>
              <a
                href="#manual"
                className="inline-flex items-center rounded-md px-3 py-2 font-medium text-slate-300 transition-colors hover:text-white"
              >
                Read the manual
              </a>
            </div>
          </motion.div>
        </div>

        {/* Visual comparison with parallax tilt. Per the brief: max 5deg tilt,
            light glare, slow 2s transition — feels engineered, not toyish. */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.8 }}
          className="relative"
        >
          <Tilt
            glareEnable={true}
            glareMaxOpacity={0.1}
            glareColor="lightblue"
            glarePosition="all"
            glareBorderRadius="0.75rem"
            tiltMaxAngleX={5}
            tiltMaxAngleY={5}
            transitionSpeed={2000}
            perspective={1200}
          >
            <div className="group relative h-full overflow-hidden rounded-xl border border-slate-800 bg-slate-900/50 p-6 shadow-2xl backdrop-blur-sm">
              <div className="absolute left-0 top-0 h-1 w-full bg-gradient-to-r from-red-500 via-amber-500 to-emerald-500" />

              <div className="grid h-[400px] grid-cols-2 gap-4">
                {/* Left: Chaos */}
                <div className="flex flex-col items-center justify-center border-r border-slate-800 pr-4 opacity-40 transition-opacity group-hover:opacity-100">
                  <div className="mb-4 font-mono text-sm text-red-400">Chaos mode</div>
                  <div className="w-full space-y-3">
                    <div className="h-2 w-3/4 animate-pulse rounded bg-slate-700" />
                    <div className="delay-75 h-2 w-1/2 animate-pulse rounded bg-slate-700" />
                    <div className="delay-150 h-2 w-full animate-pulse rounded bg-slate-700" />
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
          </Tilt>
        </motion.div>
      </div>
    </section>
  );
}
