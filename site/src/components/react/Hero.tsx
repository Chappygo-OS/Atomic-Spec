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
import { Activity, ArrowRight, GitCommit } from 'lucide-react';
import { motion } from 'framer-motion';
import Tilt from 'react-parallax-tilt';

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
            className="relative z-20 flex flex-wrap gap-4"
          >
            <a
              href="#workflow"
              className="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-8 py-4 font-semibold text-white shadow-lg shadow-emerald-900/30 transition-all hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-300"
            >
              See how it works <ArrowRight size={20} aria-hidden="true" />
            </a>
            <a
              href="#manual"
              className="inline-flex items-center rounded-lg border border-slate-700 bg-slate-800 px-8 py-4 font-semibold text-slate-200 transition-all hover:bg-slate-700 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-slate-300"
            >
              Read the manual
            </a>
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
