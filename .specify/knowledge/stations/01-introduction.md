# Station 01 — Introduction: Assembly Line Manual

## 1.1 What This Manual Is

This manual is a repeatable operating system for building SaaS products end-to-end: discovery → spec → architecture → build → release → operate.

It is designed to solve a common failure mode: teams "build features" without a shared system, then get stuck in rework (frontend ↔ backend ↔ database ↔ billing ↔ security).

The manual has two layers:

### Process Chapters ("Stations")

- Step-by-step instructions that are consistent across projects
- Each station defines what must be true before you move forward
- Stations reduce debate by turning ambiguity into explicit decisions and artifacts

### Templates ("Artifacts")

- Copy/paste documents to fill in
- They standardize what "good" looks like
- They are intentionally structured to prevent missing SaaS fundamentals (tenancy, RBAC, limits, billing/entitlements, telemetry, NFRs)

### Why This Matters for SaaS

SaaS requires more than "app screens":

- Multi-user + permissions
- Subscriptions + invoices + entitlements
- Tenant isolation
- Usage limits and cost control
- Observability and incident readiness

This manual assumes those are non-negotiable.

---

## 1.2 What Success Looks Like

Success is not "we shipped". Success is "we can ship repeatedly without breaking the business."

A project is healthy when:

### Clarity
Anyone can answer in 2 minutes:
- Who is this for?
- What problem does it solve?
- What is the MVP scope and what is explicitly out?

### Buildability
Engineering can implement without hidden assumptions:
- The domain model matches the user flow
- The API contract is stable enough for parallel work

### SaaS Correctness
- Tenant data cannot leak
- Permissions are enforced consistently
- Billing events cannot desync entitlements
- Limits prevent runaway cost

### Operational Readiness
- You can detect failures (logs/metrics/alerts)
- You can recover (rollback/runbooks)
- You can learn (telemetry)

### Repeatability
- A new engineer can join and contribute with minimal onboarding
- The same "line" can be reused for new products/modules

### Practical Indicators

- PRDs are short but decisive (no hand-waving)
- Architecture decisions are documented (ADRs)
- Releases are routine (checklist-driven)
- Incidents improve the system (runbook updates)

---

## 1.3 The Assembly Line Concept (Stations + Gates)

Each chapter is a **station**. Each station outputs **deliverables** and ends with a **gate**.

- **Deliverables** are tangible. If you can't open it, read it, run it, or test it, it's not a deliverable.
- **Gates** are measurable pass criteria. "Feels good" is not a gate.

> **Core rule: No gate pass → you do not proceed.**

This prevents downstream chaos. In a SaaS context, the cost of skipping early gates is typically paid later in:

- Broken onboarding
- Security vulnerabilities
- Billing churn
- High infrastructure spend
- Difficult debugging and production incidents

---

## 1.4 Station Anatomy (Standard Format)

Every station chapter follows the same structure so it's easy to execute and audit:

| Section | Description |
|---------|-------------|
| **Objective** | What outcome this station guarantees |
| **Owner(s)** | Who is accountable, who contributes, who approves at the gate |
| **Inputs (required)** | Artifacts that must exist before starting |
| **Procedure (step-by-step)** | Concrete actions; the smallest set of steps that consistently produces the deliverables |
| **Deliverables (required outputs)** | The artifacts created/updated in this station; includes file name conventions |
| **Gate (pass criteria)** | The objective test for moving forward |
| **Common failure modes + fixes** | The top mistakes teams make and how to correct them quickly |
| **Templates** | Copy/paste templates to speed up execution |

> **Tip:** In small teams, keep stations lightweight. The purpose is to prevent uncertainty and rework—not to create bureaucracy.

---

## 1.5 The Minimum Artifact Set for Any SaaS Project

Before starting meaningful build work (beyond scaffolding), the following must exist—even if as v0 drafts.

### 1. ICP + JTBD Summary (1–2 pages)

**Why:** Without an ICP, you build "for everyone" and convert no one.

**Minimum content:**
- ICP definition (industry, size, maturity, constraints)
- Triggers (why now?)
- Top pains and desired outcomes
- "Anti-ICP" (who to avoid)

### 2. User Flow + Edge Cases

**Why:** Many backend/frontend conflicts come from missing flow decisions.

**Minimum edge cases for SaaS:**
- Permission denied (403)
- Tenant mismatch attempt
- Limit hit (quota exceeded)
- Billing failure or trial ended
- Empty state (new user/org)

### 3. PRD v1 (MVP Scope + Acceptance Criteria)

**Why:** Prevents scope drift and makes work estimable.

**Minimum SaaS PRD sections:**
- Scope + non-goals
- Acceptance criteria (Given/When/Then style preferred)
- SaaS rules: tenancy + RBAC + limits + billing impact
- NFRs (security/performance/availability)
- Analytics events

### 4. Tenancy ADR (Multi-Tenancy Decision)

**Why:** Tenancy is foundational. Changing it late is expensive and risky.

**Minimum:**
- Tenancy model chosen
- Tenant boundary definition
- How tenantId is enforced everywhere
- Isolation test plan

### 5. API Contract v1

**Why:** Enables parallel frontend/backend delivery and reduces rework.

**Minimum:**
- Core endpoints
- Error format
- Pagination/filtering standards
- Authentication method

### 6. Security Baseline Checklist

**Why:** SaaS security issues are existential.

**Minimum controls:**
- AuthN/AuthZ and RBAC
- Secrets management
- Input validation
- Rate limiting / abuse prevention
- Tenant isolation tests

### 7. Observability Plan

**Why:** If you can't see it, you can't fix it.

**Minimum:**
- Structured logs + correlationId
- tenantId in logs
- Dashboards for core flows
- Alerts for error spikes / critical failures

### 8. Cost Guardrails

**Why:** Unbounded usage can kill a SaaS.

**Minimum:**
- What is metered
- Tier limits
- Budget alerts
- "What happens when limit is hit" behavior

### Gate for the Minimum Set

All eight artifacts exist in the repo/folder structure, in a readable format, with owners assigned.

---

## 1.6 Document Standards (Transferability Rules)

Transferability comes from consistency. If every project stores artifacts differently, knowledge doesn't scale.

### Naming and Structure (Recommended)

Use a consistent folder tree:

```
/01-discovery/
  - ICP_JTBD.md
  - Competitor_Matrix.xlsx (or .md)

/02-product/
  - User_Flows.md (or link to Figma)
  - PRD_v1.md

/03-architecture/
  - ADR_0001_Tenancy.md
  - Tech_Design_v1.md
  - API_v1.yaml (OpenAPI)

/04-delivery/
  - Backlog.md
  - Release_Checklist.md

/05-ops/
  - Production_Readiness.md
  - Runbooks.md
```

### Versioning Rules

- **PRD:** PRD_v1, PRD_v1.1 (clarifications), PRD_v2 (scope change)
- **ADRs:** Immutable once accepted. Changes require a new ADR.
- **API:** Changes must be backward compatible or explicitly versioned.

### Status Fields (Use Everywhere)

Use a consistent status to avoid ambiguity:

`Draft → In review → Approved → Implemented → Deprecated`

### Quality Bar (What "Good" Means)

- Avoid vague language ("should", "maybe", "nice to have") unless it's in a labeled assumptions section
- Every requirement that affects the system must be testable
- Every doc must list an owner and last updated date

---

## 1.7 Review Cadence (Minimal But Effective)

Gates work best when they're short, scheduled, and objective.

### Recommended Checkpoint Gates

| Checkpoint | Inputs | Outcome |
|------------|--------|---------|
| **Checkpoint 1 — Discovery Review** | ICP/JTBD + competitor wedge | Confirm the market angle and "who we're building for" |
| **Checkpoint 2 — Spec Review** | User flow + PRD v1 | Confirm MVP scope, edge cases, acceptance criteria |
| **Checkpoint 3 — Architecture Review** | Tenancy ADR + API contract + security baseline | Confirm foundations that prevent rework |
| **Checkpoint 4 — Launch Readiness** | Production readiness checklist + release checklist + monitoring | Confirm safe release posture |

### Meeting Format (30–60 minutes)

1. **10 min:** Read the gate criteria out loud
2. **20–40 min:** Verify deliverables exist and match criteria
3. **5 min:** Decision and next actions

### Allowed Outcomes

- ✅ Pass
- ❌ Fail (with explicit missing deliverables)
- ⚠️ Conditional pass (approved with documented risks/assumptions + due date)

---

## 1.8 "Stop-the-Line" Rules (Quality Control)

Stopping the line is a safeguard, not a punishment. Anyone can call a stop if the system is at risk.

### Mandatory Stop Conditions (SaaS-Critical)

- Tenant isolation is not guaranteed (risk of data leakage)
- Billing events can desync entitlements (risk of free access or locked paying users)
- No rollback path exists for the next release
- No monitoring exists for core flows
- Costs are unbounded (no limits or budgets)

### What Happens When the Line Stops

1. A short triage is created (owner, steps, ETA)
2. The next station is blocked until the condition is resolved
3. A runbook entry is created if the issue was discovered via an incident

---

## 1.9 How to Use This Manual Day-to-Day

This is the "operator instruction."

1. Create a project folder using the standard structure
2. Fill artifacts in order (don't skip tenancy/security/ops)
3. Run the gate reviews at the defined checkpoints
4. Build only through vertical slices tied to PRD acceptance criteria
5. Use release and readiness checklists for every deployment
6. After incidents, update runbooks and add prevention actions to the backlog

### Practical Operating Rules

- One story should map to one vertical slice when possible
- Don't start a story without acceptance criteria
- Don't merge code without passing DoD
- Don't deploy to production without readiness gate
