/**
 * Manual — the 18 Knowledge Stations of the Assembly Line.
 *
 * Hydrated `client:idle` because it's far below the fold and the static HTML
 * already shows the default station; users can scroll and read before JS hydrates.
 *
 * Layout: scrollable phase-grouped sidebar (left) + detail pane (right). Active
 * station id is `useState<string>` — no router, no global store. Station list is
 * the README's canonical 18 (matches `.specify/knowledge/stations/` filenames).
 *
 * Per COPY.md Open Questions 1, 2: stations 01 (Introduction) and 02 (Roles &
 * Ownership) use plausible deliverables that match the README names. Station 10
 * (Metering & Limits) is filled in with sensible defaults flagged in the report.
 */
import { useState } from 'react';
import { ChevronRight, BookOpen, CheckCircle2, AlertOctagon } from 'lucide-react';

interface Station {
  id: string;
  name: string;
  description: string;
  deliverables: string[];
  gateCriteria: string[];
}

interface PhaseGroup {
  title: string;
  stations: Station[];
}

const phases: PhaseGroup[] = [
  {
    title: 'Foundation (01–02)',
    stations: [
      {
        id: '01',
        name: 'Introduction',
        description:
          'Manual overview, Assembly Line concept, how stations gate phase transitions.',
        deliverables: ['manual_index.md', 'station_map.yaml'],
        gateCriteria: [
          'Every team member can locate the relevant station in under 30 seconds',
          'Phase-to-station mapping is documented',
          'Gate criteria template adopted across all stations',
        ],
      },
      {
        id: '02',
        name: 'Roles & Ownership',
        description: 'RACI matrix, gate responsibilities, technical ownership.',
        deliverables: ['roles.md', 'team_structure.yaml'],
        gateCriteria: [
          'Every domain has a single owner',
          'Escalation paths are defined',
          'Repo access is audited',
        ],
      },
    ],
  },
  {
    title: 'Specification (03–05)',
    stations: [
      {
        id: '03',
        name: 'Discovery',
        description: 'ICP, JTBD, wedge, competitor pain mining — raw requirement capture.',
        deliverables: ['discovery.md', 'problem_statement.md'],
        gateCriteria: [
          'User problem validated',
          "Anti-goals (what we won't ship) listed",
        ],
      },
      {
        id: '04',
        name: 'PRD Spec',
        description:
          'Convert needs into structured technical specifications. MVP scope, SaaS rules, acceptance criteria.',
        deliverables: ['prd.md', 'acceptance_criteria.md'],
        gateCriteria: [
          'No semantic ambiguity',
          'Gherkin acceptance criteria (Given/When/Then)',
          'Cross-team dependencies identified',
        ],
      },
      {
        id: '05',
        name: 'User Flows',
        description:
          'Visual mapping of critical paths — happy and unhappy. Edge states, RBAC, information architecture.',
        deliverables: ['flows.mermaid', 'states.json'],
        gateCriteria: [
          'Every error state mapped',
          'No UX dead-ends',
          'Mermaid diagrams validate',
        ],
      },
    ],
  },
  {
    title: 'Architecture (06–08)',
    stations: [
      {
        id: '06',
        name: 'API Contracts',
        description:
          'Define interfaces strictly before any implementation. OpenAPI, error schema, idempotency.',
        deliverables: ['openapi.yaml', 'error_catalog.md'],
        gateCriteria: [
          'Standardized error response schemas',
          'Pagination strategy chosen (cursor vs offset)',
          'API versioning defined',
        ],
      },
      {
        id: '07',
        name: 'Data Architecture',
        description: 'Schema design, relations, tenancy model, isolation, ADRs.',
        deliverables: ['schema.prisma', 'migrations_plan.md'],
        gateCriteria: [
          '3NF normalization (or documented exception)',
          'Performance indices defined',
          'Deletion strategy (soft vs hard)',
        ],
      },
      {
        id: '08',
        name: 'Auth & RBAC',
        description:
          'Security matrix and role-based access control. Session/JWT, permissions, hardening.',
        deliverables: ['auth_policy.md', 'permissions_matrix.csv'],
        gateCriteria: [
          'Least privilege by default',
          'Multi-tenant isolation validated',
          'JWT scopes defined',
        ],
      },
    ],
  },
  {
    title: 'SaaS Fundamentals (09–11)',
    stations: [
      {
        id: '09',
        name: 'Billing',
        description: 'Stripe integration, webhooks, state machine.',
        deliverables: ['pricing_model.json', 'metering_hooks.ts'],
        gateCriteria: [
          'Stripe webhooks idempotent',
          'Graceful payment failure handling',
          'Per-tier rate limiting',
        ],
      },
      {
        id: '10',
        name: 'Metering & Limits',
        description: 'Usage tracking, quotas, cost control.',
        deliverables: ['quotas.yaml', 'usage_events.ts'],
        gateCriteria: [
          'Per-tenant usage aggregation defined',
          'Quota enforcement is testable',
          'Cost-control alerts wired to billing',
        ],
      },
      {
        id: '11',
        name: 'Observability',
        description: 'Logging, tracing, alerting, runbooks.',
        deliverables: ['logging_config.ts', 'dashboards.json'],
        gateCriteria: [
          'No PII in logs',
          'Distributed tracing (OpenTelemetry) on',
          'Health alerts defined',
        ],
      },
    ],
  },
  {
    title: 'Operations (12–14)',
    stations: [
      {
        id: '12',
        name: 'CI/CD & Release',
        description: 'Pipelines, environments, migrations, blocking tests.',
        deliverables: ['ci.yml', 'deployment_strategy.md'],
        gateCriteria: [
          'Blocking tests on PRs',
          'Static analysis (lint/Sonar) enabled',
          'Automatic rollback on failure',
        ],
      },
      {
        id: '13',
        name: 'Security',
        description: 'Threat model, baseline, AppSec workflow, audit.',
        deliverables: ['audit_log_schema.json', 'security_headers.conf'],
        gateCriteria: [
          'OWASP headers configured',
          'Dependencies scanned (Snyk/Dependabot)',
          'Audit logs immutable',
        ],
      },
      {
        id: '14',
        name: 'Data Lifecycle',
        description: 'Retention, GDPR, backups, deletion.',
        deliverables: ['backup_policy.md', 'retention_jobs.sql'],
        gateCriteria: [
          'RPO/RTO defined and tested',
          'Encryption at rest enabled',
          'Staging environments anonymized',
        ],
      },
    ],
  },
  {
    title: 'Scale (15–18)',
    stations: [
      {
        id: '15',
        name: 'Performance',
        description:
          'Latency targets, caching, CDN, query optimization, load testing.',
        deliverables: ['caching_strategy.md', 'cdn_rules.json'],
        gateCriteria: [
          'Cache invalidation strategy defined',
          'Image/asset optimization',
          'N+1 queries detected and resolved',
        ],
      },
      {
        id: '16',
        name: 'Analytics',
        description: 'Event tracking, funnels, dashboards.',
        deliverables: ['tracking_plan.json', 'events_schema.ts'],
        gateCriteria: [
          'Consistent event naming (Object-Action)',
          'User vs event properties distinguished',
          'Cookie consent respected',
        ],
      },
      {
        id: '17',
        name: 'Admin Tooling',
        description: 'Support panel, playbooks, audit logging.',
        deliverables: ['admin_panel_specs.md', 'support_playbook.md'],
        gateCriteria: [
          'Audit logs on every admin action',
          'No direct DB deletes',
          'MFA on admin access',
        ],
      },
      {
        id: '18',
        name: 'Documentation',
        description: 'PRD/ADR templates, repo structure, technical and end-user docs.',
        deliverables: ['readme.md', 'api_docs.json', 'user_guide.md'],
        gateCriteria: [
          'Code examples are testable',
          'API docs auto-generated',
          'Architecture diagrams up to date',
        ],
      },
    ],
  },
];

const allStations: Station[] = phases.flatMap((p) => p.stations);

export default function Manual() {
  const [activeId, setActiveId] = useState<string>('03');
  const activeStation = allStations.find((s) => s.id === activeId) ?? allStations[0];

  return (
    <section
      id="manual"
      className="bg-transparent py-24 [content-visibility:auto] [contain-intrinsic-size:0_1100px]"
    >
      <div className="container mx-auto px-4">
        <div className="mb-12">
          <h2 className="mb-4 text-3xl font-bold text-white md:text-4xl">
            The Assembly Line Manual
          </h2>
          <p className="max-w-2xl text-slate-400">
            18 Knowledge Stations encode domain expertise as gate criteria. The AI stops
            guessing — it follows your engineering standard, station by station.
          </p>
        </div>

        {/* Mobile (< lg): stack sidebar + detail; sidebar gets a capped scroll height
            so it doesn't push the detail pane off-screen. Desktop: 12-column grid
            with a fixed 640px viewport. */}
        <div
          className="grid gap-8 lg:h-[640px] lg:grid-cols-12"
          aria-live="polite"
        >
          {/* Sidebar — scrollable, sticky phase headers */}
          <nav
            aria-label="Knowledge Stations"
            className="custom-scrollbar max-h-[60vh] space-y-6 overflow-y-auto pr-2 lg:col-span-4 lg:max-h-none lg:h-full"
          >
            {phases.map((phase) => (
              <div key={phase.title}>
                <h3 className="sticky top-0 z-10 ml-2 mb-1 border-b border-slate-800/50 bg-slate-950 py-2 text-xs font-bold uppercase tracking-wider text-emerald-500">
                  {phase.title}
                </h3>
                <ul className="mt-2 space-y-1">
                  {phase.stations.map((station) => {
                    const isActive = activeId === station.id;
                    return (
                      <li key={station.id}>
                        <button
                          type="button"
                          onClick={() => setActiveId(station.id)}
                          aria-current={isActive ? 'true' : undefined}
                          className={`group flex w-full items-center justify-between rounded-lg border px-4 py-3 text-sm font-medium transition-all focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-400 ${
                            isActive
                              ? 'border-emerald-500/30 bg-emerald-900/20 text-emerald-400'
                              : 'border-transparent text-slate-400 hover:bg-slate-800/50 hover:text-white'
                          }`}
                        >
                          <span className="flex items-center gap-3">
                            <span
                              className={`font-mono text-xs ${
                                isActive ? 'opacity-100' : 'opacity-40'
                              }`}
                            >
                              {station.id}
                            </span>
                            {station.name}
                          </span>
                          {isActive && (
                            <ChevronRight size={14} aria-hidden="true" />
                          )}
                        </button>
                      </li>
                    );
                  })}
                </ul>
              </div>
            ))}
          </nav>

          {/* Detail pane */}
          <div className="lg:col-span-8 lg:h-full">
            <article className="relative flex h-full flex-col overflow-y-auto rounded-2xl border border-slate-800 bg-slate-900/60 p-8 backdrop-blur-sm">
              <div
                aria-hidden="true"
                className="pointer-events-none absolute right-0 top-0 p-8 opacity-5"
              >
                <BookOpen size={200} />
              </div>

              <div className="relative z-10 flex h-full flex-col">
                <header className="mb-6">
                  <p className="mb-4 inline-flex items-center gap-2 rounded border border-slate-700 bg-slate-800 px-3 py-1 font-mono text-xs text-slate-300">
                    <span>Station {activeStation.id}</span>
                    <span className="text-slate-600" aria-hidden="true">
                      |
                    </span>
                    <span className="text-emerald-400">Standard</span>
                  </p>
                  <h3 className="mb-2 text-3xl font-bold text-white">
                    {activeStation.name}
                  </h3>
                  <p className="text-lg text-slate-400">{activeStation.description}</p>
                </header>

                <div className="grid flex-grow gap-6 md:grid-cols-2">
                  <div className="flex flex-col rounded-xl border border-slate-800 bg-slate-950/50 p-6">
                    <h4 className="mb-4 flex items-center gap-2 font-semibold text-white">
                      <AlertOctagon
                        size={16}
                        className="text-amber-500"
                        aria-hidden="true"
                      />
                      Gate criteria
                    </h4>
                    <ul className="space-y-3">
                      {activeStation.gateCriteria.map((criterion) => (
                        <li key={criterion} className="flex items-start gap-3">
                          <span
                            className="mt-1 flex h-4 w-4 min-w-[16px] items-center justify-center rounded border border-slate-600"
                            aria-hidden="true"
                          >
                            <span className="h-2 w-2 rounded-sm bg-slate-700" />
                          </span>
                          <span className="text-sm leading-snug text-slate-300">
                            {criterion}
                          </span>
                        </li>
                      ))}
                    </ul>
                  </div>

                  <div className="flex flex-col gap-6">
                    <div className="rounded-xl border border-slate-800 bg-slate-950/50 p-6">
                      <h4 className="mb-4 flex items-center gap-2 font-semibold text-white">
                        <CheckCircle2
                          size={16}
                          className="text-emerald-500"
                          aria-hidden="true"
                        />
                        Required deliverables
                      </h4>
                      <ul className="flex flex-wrap gap-2">
                        {activeStation.deliverables.map((d) => (
                          <li
                            key={d}
                            className="rounded border border-emerald-500/20 bg-emerald-950/40 px-2 py-1.5 font-mono text-xs text-emerald-300"
                          >
                            {d}
                          </li>
                        ))}
                      </ul>
                    </div>

                    <div className="mt-auto rounded-xl border border-amber-900/20 bg-amber-900/10 p-4">
                      <p className="mb-1 text-xs font-bold uppercase tracking-wide text-amber-500">
                        Why it matters
                      </p>
                      <p className="text-sm text-amber-100/70">
                        Skip Station <strong>{activeStation.id}</strong> and you ship
                        technical debt on day one. Without this context, the AI produces code
                        that runs and can't be maintained.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </div>
      </div>
    </section>
  );
}
