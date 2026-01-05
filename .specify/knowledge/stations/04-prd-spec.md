# Station 04 — PRD v1 (SaaS-Grade): Procedures + Templates + Worked Example

## 4.1 Objective

Produce a PRD that is:

- **Buildable:** engineering can estimate and implement with minimal assumptions
- **Testable:** acceptance criteria are explicit and cover real failure states
- **SaaS-complete:** includes tenancy, RBAC, limits, billing impact, telemetry, NFRs
- **Sliceable:** supports vertical slices that deliver end-to-end value in early sprints
- **Decision-friendly:** clarifies tradeoffs and prevents scope drift

> A PRD is not a marketing document and not a backlog dump. It is the single source of truth for what "done" means at the product level.

---

## 4.2 Owner

| Role | Responsibility |
|------|----------------|
| **Accountable** | PO |
| **Consulted** | TL, UX |
| **Consulted (baseline checks)** | Sec (tenancy/RBAC), Ops (telemetry/release constraints) |

> **Rule:** The PRD has one accountable owner. Contributors can propose changes, but the owner decides scope.

---

## 4.3 Inputs (Required)

- `ICP_JTBD.md` (Part 3)
- `Wedge_Positioning.md` (Part 3)
- `Metrics_Draft.md` + `Analytics_Events_Draft.md` (Part 3)
- `User_Flows.md` (happy path + edge cases)

### Optional But Recommended Inputs

- A short list of beta users and their constraints
- Any existing customer quotes or interview notes

---

## 4.4 Procedure (Step-by-Step)

### Step 0 — Establish a PRD "Scope Contract" (5 minutes)

Before writing content, define how scope changes will be handled.

**Rule set:**

- Draft PRD can change freely
- Approved PRD cannot change scope without a version bump (v1 -> v2) and a short gate review
- Clarifications that do not change scope are allowed as v1.1

> This prevents quiet scope creep.

### Step 1 — PRD Header and Status Discipline (5 minutes)

Start every PRD with:

- Owner, status, last updated
- Links to discovery artifacts
- Decision owner for scope
- Intended release milestone (MVP, v1, etc.)

**Quality bar:**

> If someone opens the PRD, they immediately know: what this is, who owns it, and what version is authoritative.

### Step 2 — Problem Statement (1 paragraph) + Success Statement (1 paragraph)

Write:

- **Problem statement:** what is broken today, for whom, in what context. Avoid solutions.
- **Success statement:** what will be true after shipping, including at least one metric threshold.

**Good problem statements:**
- Describe current workflow and friction
- Mention business impact (time, risk, money, churn)

**Good success statements:**
- Tie to activation/retention/conversion
- Mention measurable time-to-value improvements

### Step 3 — Goals, Non-Goals, and "Guardrails" (10-20 minutes)

#### Goals

Write 2-5 goals that align with the wedge and metrics.

#### Non-Goals (Mandatory)

Non-goals must remove:

- Tempting "nice to haves" that dilute the wedge
- Enterprise requirements not needed for MVP
- Deep customization that breaks repeatability

#### Guardrails (Recommended)

Guardrails are constraints you promise to respect:

- Performance target (even rough)
- Security baseline requirement
- Cost limit/usage policy

> This helps engineering avoid "it works but it's expensive/brittle".

### Step 4 — Define MVP Scope Using Must/Should/Could (and Map to Milestones)

MVP scope must be:

- Small enough to ship quickly
- Complete enough to test your wedge

**How to write Must/Should/Could well:**

- Each item should be phrased as user value, not an implementation detail
- Must items must be required to complete the core flow

**Recommended additional mapping:**

Assign each Must item to a milestone:

| Milestone | Description |
|-----------|-------------|
| MVP | Ship now |
| v1 | After MVP |
| v2 | Later |

> This prevents teams from smuggling v2 into MVP.

### Step 5 — Translate the User Flow into User Stories (Vertical-Slice Friendly)

**Rules:**

- One story describes an end-to-end outcome
- Stories are written by role
- Each story should map to telemetry and acceptance criteria

**Story writing pattern:**

> As a [role], I want [capability], so that [outcome].

**SaaS-specific reminder:** Many stories implicitly require:

- Tenancy scoping
- RBAC checks
- Plan/limit checks
- Audit logging

> If you don't mention them here, you'll forget them later.

### Step 6 — Add Acceptance Criteria for Every Must Story (Testable)

Use a strict format:

> Given / When / Then

**Minimum acceptance criteria categories (SaaS baseline):**

For every core flow, ensure coverage of:

- [ ] Authorization (403) for unauthorized roles
- [ ] Tenant boundary (cannot cross tenants)
- [ ] Validation (invalid input)
- [ ] Limit-hit behavior (quota exceeded)
- [ ] Billing state (trial ended/payment failed) if relevant
- [ ] Idempotency for operations that can be retried (invites, webhooks, payments)
- [ ] UI states (empty/error/loading feedback)

**Practical guideline:**

- 3-8 acceptance criteria per story is normal
- If you need 20+ ACs, split the story

### Step 7 — SaaS Rules Section (Mandatory)

This section prevents "forgotten fundamentals".

Include:

#### Tenancy

- Tenant boundary definition (org/workspace/project)
- tenantId propagation expectations
- Any multi-tenant constraints (shared DB vs isolated)

#### RBAC

- Roles and key permissions
- Permission matrix summary (even if small)
- What is audited (sensitive actions)

#### Plans and Limits

- Primary meter(s): seats/usage/storage/tokens
- Tier limits (even draft)
- Limit-hit behavior (block vs degrade vs warn)

#### Billing Impact

- Required plan level (if any)
- Trial behavior
- Payment failure behavior (grace, dunning, read-only mode)

> **Rule:** If a section is "not applicable", write "N/A" with justification.

### Step 8 — Non-Functional Requirements (NFRs)

**Minimum categories:**

- Security
- Performance
- Availability/Reliability
- Privacy/Data retention

**Make NFRs operational:**

| Category | Example |
|----------|---------|
| Performance | p95 < 300ms for invite creation endpoint |
| Reliability | error rate < 0.1% for core flows |
| Privacy | expired invites deleted after 30 days |

### Step 9 — Analytics Events Mapping (Metrics-Driven)

For each key flow:

- Define events
- Specify required properties
- Map events to the metric they support

**Required SaaS properties (default):**

- tenantId
- userId
- role
- plan
- source (marketing channel) for acquisition metrics

> **Rule:** If you can't measure it, you can't optimize it.

### Step 10 — Dependencies, Risks, Open Questions

**Rules:**

- Open questions must have owner + due date
- Risks must include mitigation plan
- Dependencies should be explicit (providers, external systems, internal modules)

**Blocking vs non-blocking questions:**

- If a question blocks engineering work, you must resolve it before approval
- If it doesn't block, document an assumption and proceed

---

## 4.5 Deliverables

- `/02-product/PRD_v1.md`
- MVP backlog (epics -> stories) aligned with PRD scope
- A short "assumptions log" if assumptions are present

---

## 4.6 Gate (Pass Criteria)

PRD passes only if:

- [ ] MVP scope + non-goals are explicit
- [ ] Every Must story has acceptance criteria
- [ ] SaaS rules exist (tenancy/RBAC/limits/billing)
- [ ] NFRs exist (at least security/performance/reliability)
- [ ] Analytics events exist and tie to metrics
- [ ] Open questions are non-blocking or have defined owners/due dates

---

## 4.7 Common Failure Modes + Fixes

| Failure | Fix |
|---------|-----|
| PRD is a feature wish list | Anchor each Must item to wedge + metric + user flow step |
| Missing edge cases | Enforce baseline AC categories (403, tenant boundary, limit hit, billing state, validation) |
| Scope creep after approval | Require version bump and gate review. No "silent adds" |
| NFRs ignored | NFRs become part of DoD for relevant stories |
| Stories are implementation tasks | Rewrite as user outcomes and keep implementation in Tech Design Doc |

---

## 4.8 Template — PRD v1 (SaaS)

**File:** `/02-product/PRD_v1.md`

```markdown
# PRD v1 — [Product / Feature]

**Owner:**
**Status:** Draft / In review / Approved
**Last updated:**
**Target milestone:** MVP / v1 / v2

## Links

- ICP/JTBD:
- Wedge/Positioning:
- Metrics Draft:
- User Flow:

---

## 1. Summary

- **Problem:**
- **Target ICP:**
- **JTBD (anchor):**
- **Desired outcome:**

---

## 2. Problem and Success Statements

**Problem statement (1 paragraph):**

**Success statement (1 paragraph):**

---

## 3. Goals, Non-Goals, Guardrails

### Goals

- G1:
- G2:

### Non-Goals (Mandatory)

- NG1:
- NG2:

### Guardrails (Recommended)

- Security baseline:
- Performance baseline:
- Cost/limits baseline:

---

## 4. Success Metrics

| Metric | Definition |
|--------|------------|
| North Star | |
| Activation | |
| Retention | |
| Conversion | |
| Reliability (SLO draft) | |
| Cost-to-serve | |

---

## 5. Scope (MVP)

### Must

- M1:
- M2:

### Should

- S1:

### Could

- C1:

---

## 6. User Flow

**Flow summary (happy path):**

**Edge cases covered:**

- [ ] Permission denied (403)
- [ ] Tenant boundary
- [ ] Validation
- [ ] Limit hit
- [ ] Billing state
- [ ] Empty/error states

---

## 7. User Stories + Acceptance Criteria

### Story 1 — [Title]

> As a [role], I want [capability], so that [outcome].

**Acceptance Criteria:**

- AC1 (Given/When/Then):
- AC2:

(Repeat for each story)

---

## 8. SaaS Rules (Mandatory)

### Tenancy

- Tenant boundary definition:
- TenantId propagation expectations:

### RBAC

- Roles:
- Key permissions:
- Audit requirements:

### Plans & Limits

- Meter(s):
- Limits per plan:
- Limit-hit behavior:

### Billing Impact

- Plan requirement:
- Trial behavior:
- Payment failure/grace behavior:

---

## 9. Non-Functional Requirements (NFRs)

- **Security:**
- **Performance:**
- **Availability/Reliability:**
- **Privacy/Data retention:**

---

## 10. Analytics Events

| Event Name | When It Fires | Required Properties | Metric |
|------------|---------------|---------------------|--------|
| | | | |

---

## 11. Dependencies, Risks, Open Questions

**Dependencies:**

**Risks (with mitigations):**

**Open questions (owner + due date):**
```

---

## 4.9 Worked Example — PRD v1 "Invite Team Members" (B2B SaaS)

```markdown
# PRD v1 — Invite Team Members

**Owner:** Product
**Status:** Draft
**Last updated:** 2025-12-27
**Target milestone:** MVP

## Links

- ICP/JTBD: /01-discovery/ICP_JTBD.md
- Wedge/Positioning: /01-discovery/Wedge_Positioning.md
- Metrics Draft: /01-discovery/Metrics_Draft.md
- User Flow: /02-product/User_Flows.md

---

## 1. Summary

- **Problem:** Teams share accounts or stay single-user because adding collaborators is frictionful, role rules are unclear, and invites are unreliable.
- **Target ICP:** Small professional teams (2-20 users) collaborating weekly, with basic permission needs and sensitivity around who can access what.
- **JTBD (anchor):** When onboarding my team, I want to invite collaborators and assign roles so we can collaborate securely and track who did what.
- **Desired outcome:** Increase multi-user adoption -> improve retention and conversion.

---

## 2. Problem and Success Statements

**Problem statement:**
Today, an admin cannot reliably onboard teammates with correct access. This causes account sharing, delayed collaboration, and support requests about "who can see what".

**Success statement:**
Within 7 days of signup, at least X% of organizations add a second user and complete one collaborative action; invite flows remain reliable (p95 latency and low error rate).

---

## 3. Goals, Non-Goals, Guardrails

### Goals

- G1: Admin can invite a teammate in < 60 seconds
- G2: Invitee can join the correct tenant securely and reach the product in < 2 minutes
- G3: Role assignment is clear and enforced (no accidental privilege)

### Non-Goals

- NG1: SSO/SAML
- NG2: Advanced org hierarchy (groups/departments)
- NG3: External guest access and sharing policies

### Guardrails

- Security baseline: signed, expiring, single-use invite tokens; tenant isolation
- Performance baseline: p95 < 300ms for invite creation
- Cost baseline: invite email sending cost within defined budget; abuse controls exist

---

## 4. Success Metrics

| Metric | Definition |
|--------|------------|
| North Star | Weekly Active Organizations (WAO) |
| Activation | % of orgs with >=2 users within 7 days of signup |
| Retention | 30-day WAO retention |
| Conversion | Trial -> paid among orgs with >=2 users |
| Reliability | 99.9% success rate for invite endpoints; p95 < 300ms |
| Cost-to-serve | Average invite-related cost per org remains below target |

---

## 5. Scope (MVP)

### Must

- M1: Admin can invite user by email
- M2: Invitee accepts via secure link and joins correct tenant
- M3: Role selected at invite time (Admin/Member)
- M4: Admin can view pending invites

### Should

- S1: Resend invitation

### Could

- C1: Bulk invites

---

## 6. User Flow

**Flow summary (happy path):**

1. Admin -> Settings -> Team -> Invite -> enter email + role -> Send
2. Admin -> Team -> Pending invites (view status, resend)
3. Invitee -> Email -> Accept invite -> set password or magic link -> land in tenant

**Edge cases:**

- Non-admin attempts invite -> 403
- Email already exists in tenant -> error state with guidance
- Invite expired -> error + request new invite
- Tenant seat limit reached -> block + upgrade CTA
- Duplicate submit/resend -> idempotent behavior

---

## 7. User Stories + Acceptance Criteria

### Story 1 — Send Invite

> As an Admin, I want to invite a user by email and assign a role, so that they can join my organization.

**Acceptance Criteria:**

- AC1: Given a Member user, when they attempt to invite, then the system returns 403
- AC2: Given an Admin user, when they invite an email, then an invite record is created scoped to the tenant
- AC3: Given an invalid email, when Admin invites, then validation fails with clear message
- AC4: Given seat limit reached, when Admin invites, then invite is blocked with clear message and upgrade path
- AC5: Given an email already in the tenant, when Admin invites, then system shows "already a member" state
- AC6: Given the Admin clicks "send" twice, when requests are retried, then system does not create duplicate invites (idempotency)

### Story 2 — View Pending Invites

> As an Admin, I want to view pending invites, so that I can manage onboarding.

**Acceptance Criteria:**

- AC1: Pending invites list is tenant-scoped
- AC2: List shows status (sent/expired/accepted)
- AC3: Only Admin can access this view (403 otherwise)

### Story 3 — Accept Invite

> As an invited user, I want to accept the invite securely, so that I can access the tenant.

**Acceptance Criteria:**

- AC1: Given a valid invite link, when user accepts, then they join the tenant defined by the invite
- AC2: Given an invite older than 7 days, when user opens it, then system shows expired invite state
- AC3: Given a used invite token, when reused, then system blocks the action (single-use)
- AC4: Given the invite is for a tenant at seat limit, when accepting, then acceptance is blocked with guidance

---

## 8. SaaS Rules

### Tenancy

- Tenant boundary: all membership operations are scoped by tenantId
- TenantId propagation: invite token includes tenantId; session includes tenantId after acceptance

### RBAC

- Roles: Admin, Member
- Permissions: Admin can invite/view pending/remove; Member cannot
- Audit requirements: invite created, invite accepted, role assigned

### Plans & Limits

- Meter: seats
- Limit-hit behavior: block invites; block acceptance if seat limit exceeded

### Billing Impact

- Feature available on all plans; seat limits vary by plan
- Payment failure behavior: invites blocked after grace period (defined in billing rules)

---

## 9. NFRs

- **Security:** signed invite tokens; tenant isolation tests required; rate limit invite attempts
- **Performance:** p95 < 300ms for invite creation; pending list paginated
- **Availability:** invite endpoints monitored; alert on error spikes
- **Privacy:** store invite emails; delete expired invites after 30 days

---

## 10. Analytics Events

| Event Name | When It Fires | Required Properties | Metric |
|------------|---------------|---------------------|--------|
| invite_sent | Invite created | tenantId, role, plan, seats_used, source | Activation |
| invite_viewed_pending | Pending list opened | tenantId | Engagement |
| invite_accepted | User accepts | tenantId, time_to_accept | Activation |
| invite_blocked_limit | Limit prevented invite | tenantId, plan, seats_used | Conversion |
| invite_expired_opened | Expired link clicked | tenantId | UX friction |

---

## 11. Dependencies, Risks, Open Questions

**Dependencies:**
- Email provider integration
- Template management

**Risks (with mitigations):**
- Email deliverability -> rate limiting; resend cooldown; monitoring bounce rates
- Abuse via invite spam -> rate limiting per tenant

**Open question:**
- Password vs magic link? (Owner: TL, due: Sprint 1)
```
