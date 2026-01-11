# Station Map (Station 00)

Use this map to find the authoritative guide for any domain.

---

## Assembly Line Overview

The Assembly Line Manual provides a repeatable operating system for building SaaS products end-to-end. Each station represents a phase in the development process with specific deliverables and gate criteria.

---

## Station Index

| ID | Station Name | File | Keywords / When to Consult |
|----|--------------|------|---------------------------|
| **01** | Introduction | `01-introduction.md` | Manual overview, Assembly Line concept, Station anatomy, Minimum artifact set, Document standards, Review cadence, Stop-the-line rules |
| **02** | Roles & Ownership | `02-roles-ownership.md` | RACI matrix, Role definitions (PO/TL/UX/Ops/Sec), Gate responsibilities, Decision rules, Review SLAs, Artifact ownership |
| **03** | Discovery | `03-discovery.md` | ICP, JTBD, Wedge, Competitors, Market benchmark, Anti-ICP, Metrics draft, Analytics events |
| **04** | PRD Spec | `04-prd-spec.md` | Product Requirements, MVP scope, Non-goals, Acceptance criteria, SaaS rules, User stories, NFRs |
| **05** | User Flows | `05-user-flows.md` | Information Architecture, Navigation, Edge states, RBAC states, Billing states, Empty/Error/Loading states, Screen inventory |
| **06** | API Contracts | `06-api-contracts.md` | OpenAPI, YAML, Status codes, Error schema, Idempotency, Pagination, Rate limiting, Versioning |
| **07** | Data Architecture | `07-data-architecture.md` | Tenancy models (A/B/C/D), Tenant isolation, "No naked queries", ADRs, Data model, Indexing, Soft delete |
| **08** | Auth & RBAC | `08-auth-rbac.md` | JWT vs Sessions, Magic links, OAuth, Roles, Permissions, Tenant membership, Billing/Limits gating, Security hardening |
| **09** | Billing | `09-billing.md` | Stripe integration, Checkout, Portal, Webhooks, Subscription states, Dunning, Reconciliation, Billing state machine |
| **10** | Metering & Limits | `10-metering-limits.md` | Usage meters, Quotas, Entitlements, Warn/Block logic, Cost control, Enforcement strategy, Period resets |
| **11** | Observability | `11-observability.md` | Structured logging, PII rules, Metrics, Tracing, Alerting, SEV levels, Incident runbooks, Dashboards |
| **12** | CI/CD & Release | `12-cicd-release.md` | Environments (Dev/Stage/Prod), CI pipeline, CD pipeline, Migrations, Feature flags, Rollback, Release checklist |
| **13** | Security | `13-security.md` | Threat model, Security baseline, AppSec workflow, PR checklists, Secrets management, Vulnerability management, Incident response |
| **14** | Data Lifecycle | `14-data-lifecycle.md` | Backups, Retention policy, Deletion (soft/hard), GDPR, Data export, Restore drills, RPO/RTO |
| **15** | Performance | `15-performance.md` | Latency targets, Noisy neighbor, Database optimization, Caching, Async jobs, Rate limiting, Load testing |
| **16** | Analytics | `16-analytics.md` | Event taxonomy, Activation funnel, Retention metrics, Conversion tracking, Event schema, Privacy rules, Dashboards |
| **17** | Admin Tooling | `17-admin-tooling.md` | Support tooling, Admin panel, Tenant overview, Billing screen, Usage screen, Support playbooks, Audit logging |
| **18** | Documentation | `18-documentation.md` | PRD templates, TRD/Tech specs, ADRs, Runbooks, Support playbooks, Policies, Repo structure, Workflow gates |

---

## Station Flow by Phase

### Phase 1: Discovery & Specification (Stations 01-05)

```
Introduction → Roles → Discovery → PRD Spec → User Flows
    01          02        03          04          05
```

**Gate:** Checkpoint 1 (Discovery Review) + Checkpoint 2 (Spec Review)

### Phase 2: Architecture & Design (Stations 06-08)

```
API Contracts → Data Architecture → Auth & RBAC
      06              07                08
```

**Gate:** Checkpoint 3 (Architecture Review)

### Phase 3: SaaS Fundamentals (Stations 09-11)

```
Billing → Metering & Limits → Observability
   09           10                 11
```

**Gate:** SaaS baseline verification

### Phase 4: Operations & Release (Stations 12-14)

```
CI/CD & Release → Security → Data Lifecycle
       12            13           14
```

**Gate:** Checkpoint 4 (Launch Readiness)

### Phase 5: Scale & Support (Stations 15-18)

```
Performance → Analytics → Admin Tooling → Documentation
     15           16           17              18
```

**Gate:** Operational maturity verification

---

## Quick Reference by Domain

### Product & Discovery
- **ICP/JTBD:** Station 03
- **PRD/Scope:** Station 04
- **User Flows:** Station 05
- **Metrics:** Station 16

### Architecture & Data
- **API Design:** Station 06
- **Tenancy/Data Model:** Station 07
- **Auth/RBAC:** Station 08

### Billing & Limits
- **Stripe/Payments:** Station 09
- **Usage/Quotas:** Station 10

### Operations
- **Logging/Metrics:** Station 11
- **CI/CD/Release:** Station 12
- **Security:** Station 13
- **Backups/GDPR:** Station 14

### Scale & Support
- **Performance:** Station 15
- **Analytics:** Station 16
- **Support Tools:** Station 17
- **Docs System:** Station 18

---

## Gate Checkpoints Summary

| Checkpoint | Required Stations | Key Artifacts |
|------------|-------------------|---------------|
| **1 - Discovery Review** | 01, 02, 03 | ICP_JTBD.md, Competitor_Matrix.md, Wedge_Positioning.md |
| **2 - Spec Review** | 04, 05 | PRD_v1.md, User_Flows.md |
| **3 - Architecture Review** | 06, 07, 08 | API_v1.yaml, ADR_Tenancy.md, Permission_Matrix.md |
| **4 - Launch Readiness** | 09-14 | Billing_Spec.md, Security_Checklist.md, Release_Checklist.md |

---

## Detailed Sub-Chapter Index

Use this index to access **only the specific section** you need without reading entire documents.

---

### Station 01 — Introduction (`01-introduction.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **1.1 What This Manual Is** | 1-35 | Process vs Templates layers, SaaS requirements |
| **1.2 What Success Looks Like** | 37-75 | Clarity, buildability, SaaS correctness, repeatability |
| **1.3 Assembly Line Concept** | 78-94 | Stations + Gates model, core rules |
| **1.4 Station Anatomy** | 97-113 | Standard chapter format (Objective, Owner, Inputs, Procedure, Deliverables, Gate) |
| **1.5 Minimum Artifact Set** | 116-206 | 8 required artifacts for any SaaS (ICP, User Flow, PRD, Tenancy ADR, API Contract, Security, Observability, Cost Guardrails) |
| **1.6 Document Standards** | 209-258 | Naming, versioning, status fields, quality bar |
| **1.7 Review Cadence** | 260-285 | Checkpoint gates, meeting format, allowed outcomes |
| **1.8 Stop-the-Line Rules** | 287-305 | Mandatory stop conditions, resolution process |
| **1.9 Day-to-Day Usage** | 307-324 | Practical operating rules |

---

### Station 02 — Roles & Ownership (`02-roles-ownership.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **2.1 Objective** | 1-6 | Accountability, ownership gaps prevention |
| **2.2 Role Definitions** | 8-81 | PO, TL, UX, Ops, Sec responsibilities + anti-patterns |
| **2.3 Small Team Adaptation** | 83-99 | Role mapping for small teams |
| **2.4 RACI Overview** | 101-112 | R/A/C/I definitions |
| **2.5 Gate Responsibility Matrix** | 114-186 | RACI by checkpoint (Discovery, Spec, Architecture, Launch) |
| **2.6 Artifact Ownership** | 188-210 | Single-source-of-truth rules, default owners |
| **2.7 Decision Rules** | 212-239 | Decision ownership by domain, tie-breakers, disagree-commit |
| **2.8 Review SLAs** | 241-256 | Response expectations by review type |
| **2.9 Review Checklists** | 258-292 | PO, TL, UX, Ops, Sec checklists |

---

### Station 03 — Discovery (`03-discovery.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **3.1 Objective** | 1-15 | Risk reduction, ICP/JTBD/Wedge/Metrics outputs |
| **3.2-3.3 Owners & Inputs** | 17-38 | PO accountable, required inputs |
| **3.4 Market & Competitor Benchmark** | 40-186 | Search frame, competitor list, benchmarking, pain mining, patterns |
| **3.5 ICP + JTBD Definition** | 188-282 | ICP v0, constraints, triggers, JTBD writing, anti-ICP |
| **3.6 Wedge + Positioning** | 284-347 | Wedge definition, candidates, rubric scoring |
| **3.7 Metrics Draft** | 349-433 | NSM, activation, retention, conversion, SLO, cost metrics |
| **3.8 Templates** | 435-644 | Competitor Matrix, Discovery Insights, ICP_JTBD, Wedge, Metrics, Analytics Events |

---

### Station 04 — PRD Spec (`04-prd-spec.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **4.1-4.3 Objective & Inputs** | 1-42 | Buildable, testable, SaaS-complete PRD requirements |
| **4.4 Procedure Steps 0-5** | 44-152 | Scope contract, header, problem/success statements, goals/non-goals, MVP scope, user stories |
| **4.4 Procedure Steps 6-10** | 154-256 | Acceptance criteria (GWT), SaaS rules section, NFRs, analytics events, dependencies/risks |
| **4.5-4.7 Deliverables & Gate** | 258-289 | Pass criteria, failure modes |
| **4.8 PRD Template** | 291-461 | Full PRD v1 template with all sections |
| **4.9 Worked Example** | 463-672 | Complete "Invite Team Members" PRD example |

---

### Station 05 — User Flows (`05-user-flows.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **5.1-5.4 Objective & Why** | 1-53 | System specifications, rework prevention |
| **5.5 Core Concepts** | 55-108 | IA definition, flow types (Acquisition, Core, Collaboration, Billing, Limits, Recovery), SaaS edge states, fidelity levels |
| **5.6 State-UX-Backend Contract** | 110-125 | Contract rule for consistent experience |
| **5.7 Procedure Steps 1-5** | 127-220 | IA definition, activation flow, happy path, edge states (RBAC, tenant, limits, billing), collaboration flows |
| **5.7 Procedure Steps 6-10** | 222-279 | Limit-hit UX policy, billing state UX, screen inventory, API touchpoints, telemetry |
| **5.8-5.10 Deliverables & Gate** | 281-315 | Required outputs, pass criteria, failure modes |
| **5.11 Templates** | 317-467 | IA Navigation Map, User Flow Spec, Screen/State Inventory, API Touchpoints |

---

### Station 06 — API Contracts (`06-api-contracts.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **6.1-6.3 Objective & Inputs** | 1-34 | Parallel work, predictable behavior, secure access |
| **6.4 OpenAPI-First Workflow** | 36-82 | Draft first, contract levels, review gate, implement against contract, drift prevention |
| **6.5.1-6.5.5 Core Principles Part 1** | 84-179 | Tenant scoping, URL structure, HTTP methods, status codes, error format |
| **6.5.6-6.5.9 Core Principles Part 2** | 181-244 | Error code taxonomy, validation errors, pagination/sorting/filtering, idempotency |
| **6.5.10-6.5.14 Core Principles Part 3** | 246-328 | Concurrency control, rate limiting, async operations, observability, versioning |
| **6.6-6.7 Deliverables & Gate** | 330-347 | Required outputs, pass criteria |
| **6.8 Templates** | 349-492 | Error schema, validation error, OpenAPI skeleton, API conventions doc |

---

### Station 07 — Data Architecture (`07-data-architecture.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **7.1-7.3 Objective & Inputs** | 1-48 | Foundational decisions, required inputs |
| **7.4 Tenancy Model Selection** | 50-152 | Models A/B/C/D (shared DB, separate schema, separate DB, hybrid), decision criteria, triggers to revisit |
| **7.5 Tenancy Enforcement** | 154-222 | Server-side enforcement, context propagation, "no naked queries" rule, isolation test plan |
| **7.6 Data Architecture Baseline** | 224-256 | Baseline entities (Tenant, User, Membership, Role, Subscription, Usage, Audit Log), domain entities |
| **7.7 Modeling Guidelines** | 258-319 | Keys/uniqueness, soft/hard delete, auditability, PII/retention, files/storage, analytics integrity |
| **7.8 ADR Workflow** | 321-345 | What is ADR, required ADRs for SaaS MVP |
| **7.9-7.10 Deliverables & Gate** | 347-370 | Required outputs, pass criteria |
| **7.11 Templates** | 372-455 | ADR Tenancy, Data Model v1, Tenant Isolation Test Plan |

---

### Station 08 — Auth & RBAC (`08-auth-rbac.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **8.1-8.3 Objective & ADRs** | 1-58 | Secure, tenant-aware, extensible auth; required ADRs |
| **8.4 Authentication (AuthN)** | 60-147 | Sessions vs JWT decision guide, credential storage, magic link, OAuth |
| **8.5 Account Lifecycle + Membership** | 149-197 | Data model (User, Tenant, Membership, Invite), tenant context selection, invite acceptance |
| **8.6 Authorization (AuthZ) + RBAC** | 199-268 | Fixed roles, permission model, policy engine pattern, enforcement layers, 401/403/404 policy |
| **8.7 Access Restrictions Beyond RBAC** | 270-320 | Billing state gating, limits gating, suspension |
| **8.8 Security Hardening** | 322-351 | Threat defense, minimum controls checklist |
| **8.9 Audit Logging** | 353-382 | What must be audited, required fields |
| **8.10 Observability** | 384-400 | Auth-focused metrics and logging rules |
| **8.11 Golden Path Specs** | 402-432 | Login flow spec, invite acceptance flow spec |
| **8.12-8.13 Templates & Deliverables** | 434-491 | Permission matrix, error codes, auth decision structure |

---

### Station 09 — Billing (`09-billing.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **9.1-9.3 Objective & ADRs** | 1-51 | Reliable, tenant-safe billing; Stripe primitives; required ADRs |
| **9.4 Data Model** | 53-127 | TenantBilling, Subscription, BillingEvent ledger, Invoice snapshot |
| **9.5-9.6 Billing State Machine** | 129-166 | Canonical statuses (trialing, active, past_due, restricted, canceled), Stripe signal mapping |
| **9.7 Billing Flows** | 168-249 | Checkout upgrade, customer portal, trial end, payment failed/dunning, seat-based subscriptions |
| **9.8 Webhooks** | 251-323 | Non-negotiable rules, endpoint architecture, event types, tenant resolution, idempotency, out-of-order handling |
| **9.9 Reconciliation** | 325-339 | Required reliability job |
| **9.10-9.11 Integration & Security** | 341-367 | Auth principal integration, security checklist |
| **9.12 Observability** | 369-384 | Billing metrics and alerts |
| **9.13-9.14 Templates & Deliverables** | 386-429 | Access policy table, webhook checklist, error codes |

---

### Station 10 — Metering & Limits (`10-metering-limits.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **10.1-10.2 Objective & Principles** | 1-30 | Protect unit economics, predictable UX, enforcement rules |
| **10.3 What to Meter** | 32-73 | Common meters, MVP selection method, recommendations by SaaS type |
| **10.4 Entitlements** | 75-95 | Plans -> Limits table structure |
| **10.5 Data Model** | 97-159 | UsageMeter definition, TenantUsage snapshot, UsageEvent ledger |
| **10.6 Enforcement Strategy** | 161-235 | Enforcement layers, request-time algorithm, worker-time enforcement, warn/block/upgrade policy, error responses |
| **10.7 Periods, Resets, Proration** | 237-265 | Period definition, reset strategy, plan changes mid-period |
| **10.8 Concurrency & Correctness** | 267-299 | Failure modes, MVP-safe patterns (atomic increment, reservation, event ledger) |
| **10.9 Integration** | 301-319 | Billing + auth integration, update path on plan change |
| **10.10 Observability** | 321-342 | Dashboards, support "explain" flow |
| **10.11-10.12 Templates & Deliverables** | 344-396 | Entitlements table, limit block error, enforcement checklist |

---

### Station 11 — Observability (`11-observability.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **11.1-11.3 Objective & Principles** | 1-49 | Detection, debugging, tenant-awareness, business-critical paths |
| **11.4 Logging Standards** | 51-98 | Structured JSON format, PII policy, required log events |
| **11.5 Metrics** | 100-159 | HTTP/API, job/queue, billing, limits/metering, database metrics |
| **11.6 Tracing** | 161-176 | MVP-friendly request timing breakdown |
| **11.7 Alerting** | 178-204 | SEV levels, MVP alert conditions |
| **11.8 Incident Readiness** | 206-237 | Required runbooks, post-incident review |
| **11.9 Support Diagnostics** | 239-248 | Internal admin/support view |
| **11.10-11.11 Deliverables & Templates** | 250-313 | Log event example, runbook skeleton |

---

### Station 12 — CI/CD & Release (`12-cicd-release.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **12.1-12.2 Objective & Environments** | 1-55 | Minimum environment set, data strategy, configuration discipline |
| **12.3 CI Pipeline** | 57-77 | Quality gates on PR, main branch/nightly checks |
| **12.4 CD Pipeline** | 79-107 | Deployment triggers, progressive delivery, rollback strategy |
| **12.5 Database Migrations** | 109-132 | Expand/contract pattern, migration gates |
| **12.6 Testing Strategy** | 134-146 | Test pyramid aligned to releases |
| **12.7 Release Checklist** | 148-159 | Required items for every release |
| **12.8 Observability Hooks** | 161-171 | Deployment markers, post-deploy checks |
| **12.9 Pitfalls & Fixes** | 173-183 | SaaS-specific issues and solutions |
| **12.10 Deliverables** | 185-193 | Required specs and policies |

---

### Station 13 — Security (`13-security.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **13.1 Objective** | 1-21 | Security baseline, AppSec workflow goals |
| **13.2 Threat Model** | 23-69 | Assets to protect, attacker goals, entry points, MVP threat ranking |
| **13.3 Ownership & Governance** | 71-87 | Security roles, sensitive PR definition |
| **13.4.1-13.4.4 Baseline Controls Part 1** | 89-155 | Identity/session safety, authorization invariants, web security hardening, API security |
| **13.4.5-13.4.8 Baseline Controls Part 2** | 157-209 | Data security, Stripe security, storage/file security, anti-abuse controls |
| **13.5 AppSec Workflow** | 211-263 | CI security gates, PR checklist, sensitive change review, secrets management |
| **13.6 Vulnerability Management** | 265-280 | SLA by severity |
| **13.7 Incident Response** | 282-311 | Detection signals, containment controls, post-incident requirements |
| **13.8 Enterprise Readiness** | 313-321 | Future design considerations |
| **13.9-13.10 Deliverables & Templates** | 323-356 | Security baseline checklist, PR section template |

---

### Station 14 — Data Lifecycle (`14-data-lifecycle.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **14.1-14.2 Objective & Classification** | 1-33 | Operationally safe, legally defensible; data categories |
| **14.3 Backups** | 35-74 | Backup scope, frequency, restore drills, RPO/RTO |
| **14.4 Retention Policy** | 76-98 | Default retention suggestions, minimum necessary principle |
| **14.5 Deletion Policy** | 100-137 | Soft/hard delete, tenant deletion, user deletion |
| **14.6 GDPR Basics** | 139-162 | Rights to support, data processing roles |
| **14.7 Data Export** | 164-176 | Export scopes and rules |
| **14.8 Implementation Patterns** | 178-196 | Deletion jobs, tombstone strategy |
| **14.9-14.11 Runbooks & Deliverables** | 198-241 | Required runbooks, templates |

---

### Station 15 — Performance (`15-performance.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **15.1-15.2 Objective & Targets** | 1-49 | Fast UX, predictable costs; API/frontend/async targets |
| **15.3 Noisy Neighbor Risk** | 51-72 | Vectors and required controls |
| **15.4 Database Performance** | 74-134 | Query contracts, pagination, indexing patterns, transaction/lock discipline, connection pools |
| **15.5 Caching** | 136-169 | Goals, what to cache first, what to avoid, invalidation rules |
| **15.6 Async Work & Jobs** | 171-199 | What belongs in async, job UX contract, correctness constraints |
| **15.7 Rate Limiting & Fairness** | 201-230 | Rate limiting layers, queue fairness strategies, backpressure patterns |
| **15.8 External Dependencies** | 232-240 | Client rules for external APIs |
| **15.9 Cost-to-Serve** | 242-259 | Performance-cost connection, AI-heavy SaaS controls |
| **15.10-15.11 Load Testing & Deliverables** | 261-296 | Scenarios, measurement, regression policy |

---

### Station 16 — Analytics (`16-analytics.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **16.1-16.3 Objective & Principles** | 1-45 | Decision-driving analytics, non-negotiable principles |
| **16.4 Event Taxonomy** | 47-77 | Naming convention, event levels |
| **16.5 What to Measure** | 79-135 | Activation funnel, retention/engagement, conversion/revenue funnel, limits/cost loop |
| **16.6 Event Schema** | 137-172 | Required fields, optional fields, event-specific properties |
| **16.7-16.8 Privacy & Idempotency** | 174-198 | Privacy rules, double-count prevention |
| **16.9-16.11 Architecture & Deliverables** | 200-230 | Where to emit events, MVP dashboards |

---

### Station 17 — Admin Tooling (`17-admin-tooling.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **17.1-17.2 Objective & Scope** | 1-36 | Reduce support load, MVP vs later features |
| **17.3 Security Model** | 38-57 | Access controls, data access rules |
| **17.4 Admin Panel Screens** | 59-146 | Tenant overview, billing screen, usage/limits, users/memberships, jobs/async |
| **17.5 Support Playbooks** | 148-194 | Customer paid but locked, user access issues, export failures, limit blocks |
| **17.6 Audit Logging** | 196-206 | Admin action logging requirements |
| **17.7-17.8 Self-Serve & Deliverables** | 208-226 | High-ROI self-serve features |

---

### Station 18 — Documentation (`18-documentation.md`)

| Section | Line Range | Contents |
|---------|------------|----------|
| **18.1-18.2 Objective & Doc Types** | 1-106 | PRD, TRD/Tech Spec, ADR, Runbooks, Support Playbooks, Policies |
| **18.3 Repo Structure** | 108-123 | Recommended folder organization |
| **18.4 Templates** | 125-191 | PRD template, Tech Spec template, ADR template |
| **18.5 Workflow & Gates** | 193-222 | Required gates, linking rules |
| **18.6-18.7 Maintenance & Deliverables** | 224-239 | Docs rot prevention, required outputs |

---

## Quick Lookup by Agent Task

| Agent Task | Recommended Stations/Sections |
|------------|-------------------------------|
| **Planning a new feature** | 03 (Discovery), 04 (PRD), 05 (User Flows) |
| **Designing APIs** | 06 (API Contracts), 07.5 (Tenant Enforcement) |
| **Database design** | 07 (Data Architecture), 15.4 (DB Performance) |
| **Auth implementation** | 08 (Auth & RBAC) |
| **Payment integration** | 09 (Billing) - all sections |
| **Usage limits/metering** | 10 (Metering & Limits) |
| **Logging/metrics** | 11 (Observability) |
| **CI/CD setup** | 12 (CI/CD & Release) |
| **Security review** | 13 (Security) |
| **Data retention/GDPR** | 14 (Data Lifecycle) |
| **Performance optimization** | 15 (Performance), 07.7 (Modeling Guidelines) |
| **Analytics instrumentation** | 16 (Analytics) |
| **Admin/support tools** | 17 (Admin Tooling) |
| **Documentation system** | 18 (Documentation) |
