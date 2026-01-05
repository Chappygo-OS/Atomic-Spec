# Station 02 — Roles, Ownership, and Gate Responsibilities (SaaS RACI)

## 2.1 Objective

Define who is accountable for what, who contributes, who must review/approve at each gate, and how decisions are made when there is disagreement. This reduces ambiguity, prevents "silent ownership gaps", and keeps the line moving.

---

## 2.2 Role Definitions (SaaS-Oriented)

### Product Owner (PO)

**Accountable for:** Problem definition, scope, user value, metrics, packaging logic.

**Core responsibilities:**
- Own ICP/JTBD and value proposition
- Write and maintain PRD
- Define success metrics and thresholds
- Decide MVP scope and tradeoffs
- Drive beta feedback loop and prioritization

**Common anti-patterns to avoid:**
- Vague scope ("we'll see later")
- Treating billing/limits/RBAC as "engineering details"

### Tech Lead (TL)

**Accountable for:** System design, technical quality, delivery feasibility, technical risk.

**Core responsibilities:**
- Own architecture choices (ADRs), API contract, domain model
- Ensure tenancy enforcement and RBAC correctness
- Define DoD, delivery sequence, engineering standards
- Own technical risk register and mitigation

**Common anti-patterns to avoid:**
- Over-engineering pre-MVP
- Skipping contracts (API/tenancy) and "coding first"

### Design (UX/UI)

**Accountable for:** User flows, usability, onboarding, error/empty states.

**Core responsibilities:**
- Own user flow specs including edge cases
- Define interaction patterns and content for empty/error states
- Own onboarding path to activation
- Validate designs against constraints (RBAC, limits, billing states)

**Common anti-patterns to avoid:**
- Designing only happy paths
- Ignoring RBAC/limits/billing edge states

### Ops / Platform (Ops)

**Accountable for:** CI/CD, environments, reliability baseline, production readiness.

**Core responsibilities:**
- Own CI/CD pipelines and deployment safety
- Own environment strategy (dev/stage/prod)
- Own observability setup (logs/metrics/alerts) and runbooks
- Own release readiness gates and rollback plans

**Common anti-patterns to avoid:**
- Treating monitoring as "after launch"
- Shipping without rollback

### Security Owner (Sec)

**Accountable for:** Security baseline, threat model, security gates.

**Core responsibilities:**
- Define and enforce minimum security controls
- Ensure secrets management, authN/authZ, tenant isolation tests
- Review riskier features (file upload, external integrations, webhooks)
- Own security checklist per release

**Common anti-patterns to avoid:**
- Security reviews at the end
- "We'll add RBAC later"

---

## 2.3 Small Team Adaptation

If your team is small, you still need the responsibilities—just fewer people.

### Default Mapping

| Role | Maps To |
|------|---------|
| Founder/PM | PO |
| Senior engineer | TL |
| Same senior engineer (initially) | Sec |
| Same senior engineer or dedicated person | Ops |
| Designer (if available) | UX; otherwise PO provides written flow spec |

> **Rule:** Ownership does not disappear. If a role is not staffed, it becomes an explicit hat worn by someone.

---

## 2.4 RACI Overview (How to Read)

| Letter | Meaning |
|--------|---------|
| **R** (Responsible) | Does the work |
| **A** (Accountable) | Final decision, owns outcomes |
| **C** (Consulted) | Must be involved before approval |
| **I** (Informed) | Kept in the loop |

> **One rule:** Every artifact has exactly one **A**.

---

## 2.5 Gate Responsibility Matrix (RACI by Checkpoint)

### Checkpoint 1 — Discovery Review (ICP/JTBD + Wedge)

**Artifacts:** ICP_JTBD.md, competitor matrix, wedge statement, metrics draft.

| Role | RACI |
|------|------|
| PO | A/R (writes and owns) |
| TL | C (feasibility + differentiation sanity check) |
| UX | C (flow implications) |
| Ops | I |
| Sec | I |

**Pass criteria:**
- ICP is explicit, anti-ICP exists
- Wedge is not purely feature-based; it is tied to a pain and a measurable outcome
- Success metrics are drafted (even rough)

### Checkpoint 2 — Spec Review (User Flow + PRD v1)

**Artifacts:** User_Flows.md, PRD_v1.md.

| Role | RACI |
|------|------|
| PO | A/R |
| UX | R/C (owns flow quality) |
| TL | C (domain/API implications) |
| Sec | C (RBAC/tenancy baseline coverage) |
| Ops | I |

**Pass criteria:**
- Edge cases are defined (permission denied, limit hit, billing state, empty state)
- Acceptance criteria exist for MVP stories
- NFRs and analytics events exist

### Checkpoint 3 — Architecture Review (Tenancy + API + Baseline Security)

**Artifacts:** Tenancy ADR, API contract, tech design doc draft, security baseline checklist.

| Role | RACI |
|------|------|
| TL | A/R |
| Sec | C (must sign off on baseline) |
| Ops | C (deployment/observability feasibility) |
| PO | C (scope impact and tradeoffs) |
| UX | I/C (only where flows are impacted) |

**Pass criteria:**
- Tenancy model is chosen and enforceable
- API contract exists for core flows
- Security baseline is implemented in staging
- Observability plan exists for core flows

### Checkpoint 4 — Launch Readiness (Production Gate)

**Artifacts:** Production readiness checklist, release checklist, dashboards/alerts, rollback plan.

| Role | RACI |
|------|------|
| Ops | A/R |
| TL | C |
| Sec | C (security checklist pass) |
| PO | C (launch scope and comms readiness) |
| UX | I |

**Pass criteria:**
- Rollback tested or clearly defined
- Monitoring active with actionable alerts
- Support channel + process exists
- Billing/entitlements reconciliation is in place (if monetized)

---

## 2.6 Artifact Ownership (Single-Source-of-Truth Rules)

Each artifact must list: **Owner**, **Status**, **Last updated**, **Reviewers**.

### Default Ownership

| Artifact | Owner |
|----------|-------|
| ICP_JTBD.md | PO (A) |
| Competitor matrix | PO (A) |
| User_Flows.md | UX (A) |
| PRD_v1.md | PO (A) |
| ADR_0001_Tenancy.md | TL (A) |
| Tech_Design_v1.md | TL (A) |
| API_v1.yaml | TL (A) |
| Security_Checklist.md | Sec (A) |
| Production_Readiness.md | Ops (A) |
| Release_Checklist.md | Ops (A) |
| Runbooks.md | Ops (A) |

> **Rule:** If the "A" changes, record it (small change log entry).

---

## 2.7 Decision Rules (To Keep the Line Moving)

### 2.7.1 Decision Ownership by Domain

| Domain | Decision Owner |
|--------|----------------|
| Product scope, ICP, pricing logic | PO decides |
| Architecture, data model, API standards | TL decides |
| Security controls and go/no-go on baseline issues | Sec decides |
| Production readiness, deployment safety | Ops decides |
| UX patterns within constraints | UX decides |

### 2.7.2 Tie-Breakers

If there is disagreement:

1. Apply the gate criteria: if criteria not met, decision is "no" by default
2. Choose the option that reduces irreversible risk first (security, tenant isolation, billing correctness)
3. If still tied, choose the option that supports faster learning (ship a smaller slice, measure, iterate)

### 2.7.3 "Disagree and Commit" Policy

After a gate decision is recorded:
- Contributors can document concerns in the artifact
- Execution proceeds according to the decision
- Revisit only if new evidence emerges (metrics, incidents, user feedback)

---

## 2.8 Review SLAs (Fast Feedback Without Blocking)

To prevent "review limbo", define response expectations.

### Recommended Default SLAs

| Review Type | SLA |
|-------------|-----|
| PRD review | 24–48 hours |
| Tenancy/API/Tech design review | 24–48 hours |
| Security baseline review | 24–72 hours (depending on complexity) |
| Launch readiness review | Schedule in advance; no same-day surprise |

> **Rule:** If SLA is missed, the reviewer must either (a) block with reasons, or (b) approve with conditions.

---

## 2.9 Practical Review Checklists (Per Role)

### PO Review Checklist
- [ ] Scope is explicit (must/should/could + non-goals)
- [ ] Success metrics are defined with thresholds
- [ ] Billing/limits implications are stated
- [ ] Edge cases are documented
- [ ] Acceptance criteria are testable

### TL Review Checklist
- [ ] Tenancy enforcement path is clear (tenantId propagation)
- [ ] Data model supports flows with minimal coupling
- [ ] API contract is stable, consistent, and versioned
- [ ] DoD includes tests + telemetry + staging deploy

### UX Review Checklist
- [ ] Onboarding leads to activation with minimal friction
- [ ] Empty/error states are defined
- [ ] Permission denied and limit/billing states are designed
- [ ] Copy and UI feedback reduce support burden

### Ops Review Checklist
- [ ] CI/CD exists with staging and rollback
- [ ] Logs/metrics/alerts exist for core flows
- [ ] Dashboards show health clearly
- [ ] Runbooks exist for likely incidents

### Sec Review Checklist
- [ ] AuthN/AuthZ is implemented and tested
- [ ] RBAC is tenant-scoped
- [ ] Secrets are managed correctly
- [ ] Rate limiting / abuse controls exist
- [ ] Tenant isolation tests exist and run in CI
