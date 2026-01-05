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
