/**
 * ContextPinning — toggle between polluted and pinned context.
 *
 * Hydrated `client:visible` because it's below the fold and only matters once
 * the user scrolls to it. The toggle flips between a bloated `User` model
 * (when the AI has read plan.md/spec.md) and the lean version it produces
 * when context is pinned to the current task file.
 *
 * Default state is `pinned=true` — we want the visible-on-scroll initial impression
 * to show the desired outcome, not the failure mode.
 */
import { useState } from 'react';
import { Lock, Unlock } from 'lucide-react';

const POLLUTED_CODE = `# Task: Create the User model
# AI reads the FULL plan, sees "admin dashboard" mentioned later
# Result: massive over-engineering

class User(Base):
    id = Column(UUID, primary_key=True)
    email = Column(String, unique=True)
    password_hash = Column(String)

    # Premature optimization for Task 20
    role = Column(Enum(UserRole))
    last_login = Column(DateTime)
    login_count = Column(Integer)
    preferences = Column(JSON)
    permissions = Column(JSON)
    stripe_id = Column(String)  # for billing later
    # ...15 more columns we don't need yet`;

const PINNED_CODE = `# Task: Create the User model
# AI reads ONLY T-010-create-user-model.md
# Result: clean, focused implementation

class User(Base):
    id = Column(UUID, primary_key=True)
    email = Column(String, unique=True)
    password_hash = Column(String)

# Roles added in T-015
# Analytics added in T-020
# Billing added in T-025`;

interface ConstraintRow {
  label: string;
  value: string;
  blocked: boolean;
}

const constraints: ConstraintRow[] = [
  { label: 'Current task', value: 'T-XXX.md', blocked: false },
  { label: 'Full plan (plan.md)', value: 'BLOCKED', blocked: true },
  { label: 'Spec (spec.md)', value: 'BLOCKED', blocked: true },
  { label: 'Other task files', value: 'BLOCKED', blocked: true },
];

export default function ContextPinning() {
  const [isPinned, setIsPinned] = useState<boolean>(true);

  return (
    <section
      id="context-pinning"
      className="border-t border-slate-800/50 bg-transparent py-24"
    >
      <div className="container mx-auto px-4 text-center">
        <h2 className="mb-6 text-3xl font-bold text-white md:text-4xl">
          Context Pinning — the pollution shield
        </h2>
        <p className="mx-auto mb-12 max-w-2xl text-lg text-slate-400">
          Conventional wisdom says AI needs more context. We disagree.{' '}
          <strong className="text-slate-200">Too much context causes drift.</strong> During
          implementation, the agent is{' '}
          <em className="font-semibold not-italic text-emerald-400">
            architecturally prevented
          </em>{' '}
          from reading anything outside the current task file — by design.
        </p>

        <div className="mx-auto max-w-5xl">
          <div className="mb-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center sm:gap-4">
            <span
              aria-hidden="true"
              className={`text-xs font-bold uppercase tracking-wider transition-colors ${
                !isPinned ? 'text-red-400' : 'text-slate-500'
              }`}
            >
              Polluted
            </span>

            <button
              type="button"
              role="switch"
              aria-checked={isPinned}
              aria-label={`Context pinning ${isPinned ? 'enabled' : 'disabled'} — click to toggle`}
              onClick={() => setIsPinned((prev) => !prev)}
              className={`relative inline-flex h-9 w-20 items-center rounded-full transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-400 ${
                isPinned ? 'bg-emerald-600' : 'bg-red-600/80'
              }`}
            >
              <span
                aria-hidden="true"
                className={`inline-block h-7 w-7 transform rounded-full bg-white shadow-md transition-transform ${
                  isPinned ? 'translate-x-[2.75rem]' : 'translate-x-1'
                }`}
              />
            </button>

            <span
              aria-hidden="true"
              className={`text-xs font-bold uppercase tracking-wider transition-colors ${
                isPinned ? 'text-emerald-400' : 'text-slate-500'
              }`}
            >
              Pinned
            </span>
          </div>

          <div className="grid gap-8 md:grid-cols-2">
            <div
              className={`relative overflow-hidden rounded-xl border-2 bg-[#0d1117]/90 text-left backdrop-blur-md transition-colors ${
                isPinned
                  ? 'border-emerald-500/50 shadow-[0_0_30px_rgba(16,185,129,0.1)]'
                  : 'border-red-500/50 shadow-[0_0_30px_rgba(239,68,68,0.1)]'
              }`}
            >
              <div
                className={`flex items-center justify-between px-4 py-2 text-xs font-bold text-white ${
                  isPinned ? 'bg-emerald-600' : 'bg-red-600'
                }`}
              >
                <span>{isPinned ? 'Context: pinned' : 'Context: polluted'}</span>
                {isPinned ? <Lock size={14} aria-hidden /> : <Unlock size={14} aria-hidden />}
              </div>
              <pre className="overflow-x-auto p-6 font-mono text-sm">
                <code className="text-slate-300">
                  {isPinned ? PINNED_CODE : POLLUTED_CODE}
                </code>
              </pre>
            </div>

            <div className="flex flex-col justify-center space-y-6 text-left">
              <div className="rounded-xl border border-slate-800 bg-slate-950/60 p-6 backdrop-blur-sm">
                <h3 className="mb-4 font-bold text-white">
                  Read access{' '}
                  <span className="font-mono text-xs font-normal text-slate-500">
                    (Directive 3)
                  </span>
                </h3>
                <dl className="space-y-3 text-sm">
                  {constraints.map((row, idx) => (
                    <div
                      key={row.label}
                      className={`flex justify-between ${
                        idx < constraints.length - 1 ? 'border-b border-slate-800 pb-2' : ''
                      }`}
                    >
                      <dt className="text-slate-400">{row.label}</dt>
                      <dd
                        className={`flex items-center gap-1 font-mono ${
                          row.blocked ? 'text-red-400' : 'text-emerald-400'
                        }`}
                      >
                        {row.blocked ? <Lock size={12} aria-hidden /> : null}
                        {row.value}
                      </dd>
                    </div>
                  ))}
                </dl>
              </div>

              <p className="text-sm italic text-slate-400">
                "Why forbid plan.md? Because if the AI sees 'future admin panel', it will try
                to build it today. Pinning forces the agent to build only what this task needs
                — and nothing else."
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
