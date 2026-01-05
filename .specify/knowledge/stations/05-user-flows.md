# Station 05 — User Flows + Information Architecture (SaaS): Procedures + Templates

## 5.1 Objective

Create user flows and an information architecture (IA) that:

- Makes the product navigable, learnable, and predictable
- Prevents frontend/backend rework by clarifying states, transitions, and contracts
- Explicitly covers SaaS edge states (RBAC, tenancy, billing, limits)
- Provides stable inputs for API contracts, data modeling, and telemetry

> User flows are not "UX decoration". In SaaS, they are system specifications: they define what must happen when the user takes actions under different constraints.

---

## 5.2 Owner

| Role | Responsibility |
|------|----------------|
| **Accountable** | UX |
| **Consulted** | PO, TL |
| **Consulted (edge-state checks)** | Sec (RBAC/tenancy), Ops (operational constraints) |

> If there is no designer, PO owns the flow spec in written form. The format stays the same.

---

## 5.3 Inputs (Required)

- `ICP_JTBD.md`
- `Wedge_Positioning.md`
- `PRD_v1.md`
- `Metrics_Draft.md` + `Analytics_Events_Draft.md`

### Optional But Recommended

- Support expectations (who handles tickets, response time)
- Any compliance requirements (PII, retention, audit expectations)

---

## 5.4 Why This Station Prevents Rework (SaaS-Specific)

Most "engineering problems" in SaaS are actually missing flow decisions:

- What happens if a Member clicks an Admin-only button?
- What happens when a tenant reaches a seat limit?
- What happens when a trial ends while the user is mid-task?
- What happens when an invite is expired, already used, or the seat limit changed?

> If you don't specify these, engineering will make implicit decisions in code. That creates inconsistent UX, churn, and hard-to-debug edge cases.

---

## 5.5 Core Concepts (What Must Be Defined)

### 5.5.1 IA Definition (What IA Includes)

Your IA must define:

- **Primary navigation** (top-level modules)
- **Secondary navigation** (inside a module)
- **Settings/Admin area** (org-level capabilities)
- **Global entry points** (deep links, email links, notification links)
- **Context switching rules** (tenant/workspace switchers)

> **Rule:** In B2B SaaS, IA is not just a menu. It encodes your permission boundaries and your org vs user-level concepts.

### 5.5.2 Flow Types (Minimum Set)

You must define at least these flows (even if minimal in MVP):

| Flow Type | Description |
|-----------|-------------|
| Acquisition -> Activation flow | Signup/login, tenant creation/join, first success event |
| Core value flow (the wedge job) | The shortest path that delivers the promised outcome |
| Collaboration flow | Invites, roles, membership management |
| Billing flow (if monetized) | Trial start/end, upgrade, invoice access, cancellation |
| Limits flow (if limits exist) | Warning threshold, block point, upgrade CTA, degraded experience policy |
| Recovery flow | Password reset, invite expired, "no access", payment failed, contact support |
| Lifecycle flow (recommended) | Onboarding checklist, returning user path, reactivation path |

### 5.5.3 States You Must Cover (SaaS Edge States)

Every key screen/action must specify behavior for:

| State | Description |
|-------|-------------|
| RBAC state | Allowed vs forbidden |
| Tenant scope | Correct tenant vs mismatch |
| Billing state | Trial active, trial ended, payment failed, grace, canceled |
| Limit state | Under limit, near limit warning, hard limit exceeded |
| Empty state | New tenant, no data yet |
| Error state | Backend error, partial failure, retries |
| Loading state | Slow network behavior |
| Offline/unstable network | If mobile/field use case |

### 5.5.4 Flow Fidelity Levels

Not every flow needs the same fidelity. Use this rule:

| Level | Fidelity | Description |
|-------|----------|-------------|
| Level 1 | MVP flows | Step-by-step + UI states + API touchpoints + acceptance notes |
| Level 2 | Secondary flows | Step-by-step + key states |
| Level 3 | Later flows | Narrative + constraints |

> This keeps speed without sacrificing correctness.

---

## 5.6 The "State -> UX -> Backend" Contract Rule

For each state, specify:

- What the user sees (message, CTA)
- What the user can do (enabled/disabled actions)
- Which API call(s) are involved
- What errors can occur and how the UI reacts

This creates a consistent experience and prevents the classic:

> Frontend assumes behavior X, backend returns behavior Y

---

## 5.7 Procedure (Step-by-Step)

### Step 1 — Define the IA (Navigation Map) First

Create the navigation map with:

- Primary nav items
- Secondary sections
- Settings/admin area
- Contextual navigation inside the core workflow

**SaaS checklist for IA:**

- [ ] Is there a clear tenant/workspace concept?
- [ ] Is the boundary between user settings and org settings explicit?
- [ ] Does the IA reflect your plan/limit surfaces (billing, usage)?

**Quality bar:**

> Users can always answer: "Where am I? What can I do next? What does this affect (me vs org)?"

### Step 2 — Map Activation (First-Session Flow)

Activation is a system flow, not just a UI.

Define:

- Signup/login variants (email+password, magic link, OAuth)
- Tenant creation vs join existing tenant
- Onboarding checklist (optional)
- The exact activation event (from metrics draft)

**Quality bar:**

> The activation flow leads to a measurable "Aha" event in one session.

### Step 3 — Write the Happy Path for the Core Wedge

Map the shortest path from:

- First session -> activation
- Activation -> first repeated value

Include:

- Entry points (dashboard, deep link, email link)
- Exit points
- Confirmation steps (when the user knows it worked)

### Step 4 — Add Edge States Systematically (Non-Negotiable)

For each step in the happy path, add mandatory SaaS edge states:

#### RBAC

- What does a forbidden action look like?
- Do we hide the action or show it disabled?
- Do we include a request-access pattern?

#### Tenant Mismatch

- If a link is opened for another tenant, what happens?
- Do we offer tenant switch?

#### Limits

- When do we warn?
- When do we block?
- What happens to "in progress" work?

#### Billing

- Trial ended: block vs read-only
- Payment failed: grace vs restricted

#### Error/Loading

- Retries, backoff, "try again" behavior

**Quality bar:**

> For any step, the team can answer: "What happens if this fails or is forbidden?"

### Step 5 — Add Collaboration and Admin Flows

Even if the wedge is single-user, B2B SaaS typically requires:

- Members, roles
- Org settings
- Basic audit trail

Define:

- Which parts are MVP vs later
- How role changes impact UI and access

### Step 6 — Define the "Limit-Hit" UX Policy (Explicit)

Decide and document:

| Element | Decision |
|---------|----------|
| Warning threshold | e.g., 80% |
| Hard block | 100% |
| Which actions are blocked | Create/export/invite |
| Degrade vs stop policy | |
| Upgrade CTA behavior | Modal, banner, blocked screen |

> **Rule:** Limit behavior must be consistent across UI and API.

### Step 7 — Define Billing State UX Policy (If Monetized)

Decide:

- Trial end behavior (block vs read-only)
- Payment failed behavior (grace period, dunning)
- Cancellation behavior (end of period vs immediate)

> **Rule:** If billing state impacts access, it must be visible to the user (clear messaging) and consistent across screens.

### Step 8 — Convert Flows into a Screen/State Inventory

For each MVP screen:

- Purpose
- Entry conditions
- Roles allowed
- States (empty/loading/error/forbidden/limit/billing)
- Key actions

> This creates a shared reference for engineering and QA.

### Step 9 — Create API Touchpoints List

For each screen/flow, list:

- Endpoints
- Required data
- Mutations
- Expected errors

> This becomes direct input to Part 6 (API contract).

### Step 10 — Telemetry Placement (Recommended)

For each flow step, mark:

- Events to fire
- Properties needed
- Which metric it supports

> This prevents "we forgot analytics" at implementation time.

---

## 5.8 Deliverables

- `IA_Navigation_Map.md` (or Figma link)
- `User_Flows.md` (happy paths + edge paths)
- `Screen_State_Inventory.md`
- `API_Touchpoints.md`

### Recommended Additional Deliverable

- `Access_Surface_Map.md` (optional): list of screens/actions by role

---

## 5.9 Gate (Pass Criteria)

- [ ] IA includes core workflow + settings/admin surfaces
- [ ] Activation flow exists and references the activation event
- [ ] Core wedge flow exists with explicit edge states
- [ ] RBAC, tenancy, limits, billing states are covered where applicable
- [ ] Screen inventory exists for MVP screens
- [ ] API touchpoints list exists

---

## 5.10 Common Failure Modes + Fixes

| Failure | Fix |
|---------|-----|
| Flows only show happy paths | Enforce edge-state checklist per step |
| Flows don't mention roles | Write role variants (Admin vs Member) explicitly |
| IA bloated early | Separate MVP IA from future IA; keep menu minimal |
| Inconsistent limit/billing handling | Define global policies and reuse them across screens |
| Unclear tenant switching / deep link behavior | Specify tenant mismatch behavior and whether you support switching |

---

## 5.11 Templates Appendix (User Flows + IA)

### 5.11.1 Template — IA Navigation Map (Expanded)

**File:** `/02-product/IA_Navigation_Map.md`

```markdown
## Primary Navigation

- Home/Dashboard
- [Core module]
- [Secondary module]

## Secondary Navigation (Within Core)

- ...

## Settings / Admin

- Organization
- Members & roles
- Billing (if monetized)
- Usage & limits
- Integrations
- Security (optional)

## Tenant/Workspace Switching

- Is a tenant switcher present? (yes/no)
- Switch behavior:
- Deep link behavior if tenant mismatch:

## MVP vs Later

- **MVP:**
- **Later:**
```

### 5.11.2 Template — User Flow Spec (With Edge States)

**File:** `/02-product/User_Flows.md`

```markdown
## Flow: [e.g., Create First Report]

- **Goal:**
- **Actor/role:**
- **Entry points:**
- **Activation relevance:** (does this flow contribute to activation?)

### Happy Path

| Step | UI | API | Success Confirmation |
|------|-----|-----|----------------------|
| 1 | | | |
| 2 | | | |

### Edge States Checklist (Per Step)

| State | Behavior |
|-------|----------|
| RBAC forbidden (403) | |
| Tenant mismatch | |
| Limit warning / limit hit | |
| Billing state (trial ended/payment failed) | |
| Empty state | |
| Error state | |
| Loading state | |
| Retry behavior | |

### Telemetry (Recommended)

- **Events fired at this step:**
- **Required properties:**
```

### 5.11.3 Template — Screen/State Inventory

**File:** `/02-product/Screen_State_Inventory.md`

```markdown
## Screen: [Name]

- **Purpose:**
- **Roles allowed:**
- **Entry conditions:**
- **Primary actions:**

### States

| State | Behavior/Message |
|-------|------------------|
| Empty | |
| Loading | |
| Error | |
| Forbidden (RBAC) | |
| Tenant mismatch | |
| Limit warning / limit hit | |
| Billing restricted | |

### Messaging/CTA Per Restricted State

| State | Message | CTA |
|-------|---------|-----|
| | | |

### Key API Calls

- ...

### Telemetry

- ...
```

### 5.11.4 Template — API Touchpoints (Expanded)

**File:** `/02-product/API_Touchpoints.md`

```markdown
## Screen: [Name]

### Required API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| | | |

### Data Needed

- ...

### Mutations (Create/Update/Delete)

- ...

### Error Cases

| Code | Meaning | UI Response |
|------|---------|-------------|
| 403 | Forbidden | |
| 404 | Not found | |
| 409 | Conflict | |
| 429 | Rate limited | |
| 5xx | Server error | |

### Idempotency Needs

- ...
```
