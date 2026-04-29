/**
 * HITL — the four Human-In-The-Loop checkpoints.
 *
 * Hydrated `client:visible`. Renders four step buttons that swap the body of a
 * terminal mock. The fourth checkpoint (Registry sync, Phase 0.9) is rendered
 * here in full per Open Question 3 in COPY.md.
 *
 * Terminal styling matches boss's dark-on-dark: outer panel #0c0c0c, inner
 * chrome #1a1a1a, traffic-light dots, monospace body.
 */
import { useState } from 'react';
import { Play } from 'lucide-react';

interface Step {
  id: string;
  title: string;
  description: string;
  content: string;
}

const steps: Step[] = [
  {
    id: 'stack',
    title: 'HITL #1 — Tech stack',
    description: 'Review every tech decision before design begins.',
    content: `══════════════════════════════════════════════════════════════
🛑 TECH STACK REVIEW — Phase 0.5 checkpoint
══════════════════════════════════════════════════════════════

Resolved decisions:
| Decision     | Value          | Source   |
|--------------|----------------|----------|
| Language     | Python 3.11    | Spec     |
| Framework    | FastAPI        | Spec     |
| Database     | PostgreSQL 15  | Assumed  |
| ORM          | SQLAlchemy 2.0 | Assumed  |

⚠ ASSUMPTIONS:
- PostgreSQL chosen over SQLite for multi-tenant support
- SQLAlchemy chosen for async compatibility

Your options:
1. [Approve all] — proceed with these choices
2. [Revise] — change Database to SQLite
3. [Reject] — start over`,
  },
  {
    id: 'validation',
    title: 'HITL #2 — Validation',
    description: 'Catch security and compatibility issues before they ship.',
    content: `══════════════════════════════════════════════════════════════
🔍 VALIDATION REVIEW — Phase 0.7 checkpoint
══════════════════════════════════════════════════════════════

Status: PASS_WITH_WARNINGS

| Package    | Version | Status | Issue                  |
|------------|---------|--------|------------------------|
| FastAPI    | 0.104.1 | WARN   | Security patch 0.105   |
| Pydantic   | 2.5.2   | OK     | -                      |

⚠ FastAPI 0.104.1 has a known CORS vulnerability.
   Recommendation: upgrade to 0.105.0

Your options:
1. [Accept rec] — upgrade to 0.105.0
2. [Ignore] — document risk and continue
3. [More info] — explain the vulnerability`,
  },
  {
    id: 'ui',
    title: 'HITL #3 — UI specs',
    description: 'Pin the design system before the AI drifts on UI choices.',
    content: `══════════════════════════════════════════════════════════════
🎨 UI SPECS — Phase 0.8 checkpoint
══════════════════════════════════════════════════════════════

Frontend work detected. Let's pin the standards.

1. UI component library?
   > Tailwind + Headless UI (recommended)
     Material UI
     Shadcn/ui
     Chakra UI

2. State management?
   > React Context + Hooks (recommended for MVP)
     Zustand
     Redux Toolkit

3. Additional requirements?
   [x] Dark mode support
   [ ] Accessibility (WCAG 2.1 AA)`,
  },
  {
    id: 'registry',
    title: 'HITL #4 — Registry sync',
    description: 'Promote new decisions into the Project Defaults Registry.',
    content: `══════════════════════════════════════════════════════════════
📒 REGISTRY SYNC — Phase 0.9 checkpoint
══════════════════════════════════════════════════════════════

Decisions promoted to specs/_defaults/registry.yaml:

| Key                       | Old           | New              |
|---------------------------|---------------|------------------|
| architecture.pattern      | (unset)       | layered          |
| data.access.style         | (unset)       | repository       |
| tenancy.model             | (unset)       | shared-schema    |
| api.error.envelope        | (unset)       | rfc7807          |

✓ Future features will inherit these defaults automatically.
✓ Diff written to registry.lock for audit.

Your options:
1. [Approve sync] — write to registry.yaml
2. [Reject] — keep registry untouched
3. [Edit] — adjust values before sync`,
  },
];

export default function HITL() {
  const [activeIndex, setActiveIndex] = useState<number>(0);
  const activeStep = steps[activeIndex];

  return (
    <section id="hitl" className="bg-transparent py-24">
      <div className="container mx-auto px-4">
        <div className="grid items-start gap-12 lg:grid-cols-2">
          <div>
            <h2 className="mb-6 text-3xl font-bold text-white md:text-4xl">
              This is where the AI stops.
            </h2>
            <p className="mb-8 text-lg text-slate-400">
              Most AI coding fails because the model makes silent decisions.{' '}
              <strong className="text-emerald-400">
                HITL checkpoints flip that.
              </strong>{' '}
              The agent proposes, then{' '}
              <strong className="text-amber-400">HALTS</strong>. You review. You approve. Only
              then does it build.
            </p>

            <div className="space-y-4" role="tablist" aria-label="HITL checkpoints">
              {steps.map((step, idx) => {
                const isActive = idx === activeIndex;
                return (
                  <button
                    key={step.id}
                    role="tab"
                    aria-selected={isActive}
                    aria-controls={`hitl-panel-${step.id}`}
                    id={`hitl-tab-${step.id}`}
                    type="button"
                    onClick={() => setActiveIndex(idx)}
                    className={`w-full rounded-xl border p-4 text-left transition-all focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-400 ${
                      isActive
                        ? 'border-emerald-500/50 bg-slate-900/60 shadow-lg shadow-emerald-900/10'
                        : 'border-slate-800 bg-transparent hover:bg-slate-900/40'
                    }`}
                  >
                    <h3
                      className={`font-bold ${isActive ? 'text-emerald-400' : 'text-slate-300'}`}
                    >
                      {step.title}
                    </h3>
                    <p className="mt-1 text-sm text-slate-500">{step.description}</p>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="relative">
            <div
              role="tabpanel"
              id={`hitl-panel-${activeStep.id}`}
              aria-labelledby={`hitl-tab-${activeStep.id}`}
              className="relative overflow-hidden rounded-xl border border-slate-800 bg-[#0c0c0c]/90 font-mono text-sm leading-relaxed shadow-2xl backdrop-blur-xl"
            >
              <div className="flex items-center gap-2 border-b border-slate-800 bg-[#1a1a1a]/90 px-4 py-2">
                <span
                  className="h-3 w-3 rounded-full bg-red-500/60"
                  aria-hidden="true"
                />
                <span
                  className="h-3 w-3 rounded-full bg-amber-500/60"
                  aria-hidden="true"
                />
                <span
                  className="h-3 w-3 rounded-full bg-emerald-500/60"
                  aria-hidden="true"
                />
                <span className="ml-2 text-xs text-slate-500">
                  atomicspec — interactive
                </span>
              </div>

              <div className="h-[480px] overflow-auto whitespace-pre-wrap p-6 text-slate-300">
                <span className="text-emerald-500">$ atomicspec plan --interactive</span>
                {'\n\n'}
                {activeStep.content}
                {'\n\n'}
                <span className="animate-pulse" aria-hidden="true">
                  _
                </span>
              </div>

              {/* Decorative chrome row — sits OUTSIDE the scrollable terminal body so
                  it never overlaps content. Marked aria-hidden because it's a visual
                  affordance for the screenshot, not an interactive button. */}
              <div
                aria-hidden="true"
                className="flex items-center justify-end border-t border-slate-800 bg-[#1a1a1a]/90 px-4 py-3"
              >
                <span className="inline-flex items-center gap-2 rounded-full bg-emerald-600 px-4 py-1.5 text-xs font-bold text-white shadow-lg">
                  <Play size={12} fill="currentColor" /> Approve &amp; continue
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
