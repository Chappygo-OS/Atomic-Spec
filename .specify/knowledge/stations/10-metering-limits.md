# Station 10 — Usage Metering + Limits (SaaS)

> Design, Enforcement, and Cost Control

---

## 10.1 Objective

Implement usage metering and limits so they:

- **Protect unit economics**: cap worst-case cost-to-serve
- **Create predictable UX**: warn -> block -> upgrade
- **Stay tenant-safe**: tenant-scoped meters; no cross-tenant leakage
- **Are enforced server-side**: and double-checked for async work
- **Are explainable**: support can answer "why blocked?" instantly
- **Integrate cleanly**: with billing (Part 9) and auth principal (Part 8)

> **Mental model**: Limits are a runtime control system + a pricing surface.

---

## 10.2 Core Principles (Non-Negotiable)

- Meter the expensive thing first
- Fail fast (before expensive compute / external calls)
- Enforce twice for expensive async tasks (request + worker)
- Return stable error codes + structured details
- Separate entitlements from usage (limits table vs counters)
- Make limits observable and supportable (events, dashboards, logs)

---

## 10.3 Decide What You Meter

### 10.3.1 Common Meters

| Meter | Description |
|-------|-------------|
| seats | members |
| storage_bytes | file storage |
| api_requests | API calls |
| ai_tokens / compute_seconds | AI/compute usage |
| exports | PDF/video exports |
| projects/items | created resources |
| integrations | connectors, sync frequency |

### 10.3.2 MVP Selection Method (Repeatable)

1. List top 5 cost drivers (money, time, infra, external APIs)
2. Identify the top 1-3 that could "blow up" costs
3. Pick meters that correlate strongly with cost
4. Decide enforcement behavior per meter (warn/block/degrade)
5. Add one "anti-abuse" meter even if cheap (e.g., requests/minute)

### 10.3.3 Typical MVP Recommendations by SaaS Type

**AI-Heavy SaaS**:
- `ai_tokens` or `compute_seconds` (primary)
- `exports` (secondary)
- `storage_bytes` (tertiary)

**Collaboration SaaS**:
- `seats` (primary)
- `projects` or `items` (secondary)
- `storage_bytes` (tertiary)

**API SaaS**:
- `api_requests` (primary)
- `data_transfer_bytes` (secondary)
- `seats` (optional)

---

## 10.4 Define Entitlements (Plans -> Limits)

> Entitlements are what a tenant is allowed to use.

### 10.4.1 Entitlement Table (The "Source of Limits")

Each entitlement defines:

| Field | Description |
|-------|-------------|
| planId | Which plan this applies to |
| meterName | Which meter |
| limitValue | The limit value |
| periodType | monthly/weekly/daily/one-time |
| warningThreshold | e.g., 0.8 (80%) |
| hardBlock | boolean |
| degradePolicy | none/read-only/throttle/quality-reduction |
| overageAllowed | boolean (later) |
| resetPolicy | calendar month, rolling 30 days |

> **Rule**: The entitlement table is versioned. Changing limits is a product change.

---

## 10.5 Data Model (MVP)

> Design for correctness and explainability.

### 10.5.1 UsageMeter (Definition)

Defines meter semantics:

| Field | Description |
|-------|-------------|
| meterName | Unique identifier |
| unit | count, bytes, tokens, seconds |
| periodType | billing period type |
| aggregationRule | sum/max/count |
| enforcementPoint | api, worker, both |

### 10.5.2 TenantUsage (Period Snapshot)

A snapshot row per tenant per meter per period:

| Field | Description |
|-------|-------------|
| tenantId | |
| meterName | |
| periodStart, periodEnd | |
| value | current usage |
| limitValue | cached from entitlement |
| warningThreshold | cached |
| status | ok / warned / blocked |
| resetAt | |
| updatedAt | |

**Indexes**:
- Unique `(tenantId, meterName, periodStart)`
- Index `(tenantId, meterName, status)`

> **Rule**: Caching limitValue here is fine as long as you have a plan-change refresh mechanism.

### 10.5.3 UsageEvent Ledger (Recommended Even in MVP)

> This is the "why did we get blocked?" truth.

**Minimal fields**:

| Field | Description |
|-------|-------------|
| tenantId | |
| meterName | |
| delta | change in usage |
| sourceAction | e.g., export_pdf, ai_generate |
| entityType/entityId | optional |
| timestamp | |
| requestId | |
| userId | optional, but very useful |
| jobId | for async operations |

**Indexes**:
- `(tenantId, meterName, timestamp DESC)`
- `(requestId)` (debug correlation)

> **MVP shortcut**: If you truly can't store a full ledger, at least log top contributors for expensive meters (e.g., last N exports).

---

## 10.6 Enforcement Strategy (Server-Side, Consistent)

### 10.6.1 Where Enforcement Must Happen

| Layer | Description |
|-------|-------------|
| API/service layer | Before doing expensive work |
| Worker layer | Before executing expensive async jobs |
| DB layer | Ensure atomic increments and avoid race conditions |

> **Rule**: UI enforcement is only messaging.

### 10.6.2 Standard Enforcement Algorithm (Request-Time)

For each metered operation:

1. Resolve tenantId and principal (Part 8)
2. Load entitlement for `(tenantId, meterName)` from plan
3. Load current TenantUsage snapshot for period
4. If `value + delta > limitValue`:
   - Deny with stable error code + structured details
5. Else:
   - Proceed and record usage
   - If crossing warning threshold -> emit warning event (and optionally mark snapshot status)

**Two-Phase Approach (Recommended for Expensive Ops)**:
1. Reserve budget first (atomic)
2. Execute work
3. Finalize usage (commit)
4. On failure, release reservation (optional; depends on semantics)

> This prevents double-spending in concurrent requests.

### 10.6.3 Worker-Time Enforcement (Async Safety Net)

When a job starts:
1. Re-check entitlement + usage
2. If limit exceeded now -> stop job, mark as blocked, return a "limit reached" job status

**Why needed**:
- User can start many jobs quickly
- Usage changes between request and execution
- Retries can duplicate work

### 10.6.4 Warn -> Block -> Upgrade Policy

For each meter define:

| Threshold | Behavior |
|-----------|----------|
| Warn threshold (e.g., 80%) | Show banner + send email (optional) |
| Hard block at 100% | Deny operations that increase usage |
| Degrade policy (if used) | Throttle, reduced quality, smaller output, slower queue |

> **Rule**: Degrade is powerful but must be consistent and communicated. MVP often uses hard blocks only.

### 10.6.5 Error Responses (Standard)

Every limit denial returns:
- Stable `error.code`
- `meterName`, `current`, `limit`, `resetAt`
- Optional: `delta`, `planId`, `upgradeUrl`

**Codes to standardize**:
| Code | Description |
|------|-------------|
| `USAGE_LIMIT_REACHED` | generic |
| `AI_TOKENS_LIMIT_REACHED` | AI token limit |
| `EXPORT_LIMIT_REACHED` | Export limit |
| `STORAGE_LIMIT_REACHED` | Storage limit |
| `SEAT_LIMIT_REACHED` | Seat limit |

---

## 10.7 Periods, Resets, and Proration

### 10.7.1 Period Definition

**Choose**:
- Calendar month (simple, common)
- Rolling window (more fair, more complex)

> **MVP default**: Calendar month in UTC.

**Store**:
- `periodStart`, `periodEnd`, `resetAt`

### 10.7.2 Reset Strategy

Even if you compute periods on the fly, you need a job to ensure consistency:
- Create missing TenantUsage rows for active tenants
- Mark statuses back to `ok` at period rollover
- Optionally archive old usage snapshots

### 10.7.3 Plan Changes Mid-Period (MVP Policy)

**Define**:
- If upgrade increases limit immediately (usually yes)
- If downgrade applies next period (usually yes)
- How you handle "over limit" after downgrade (avoid immediate lock unless product requires it)

> **Rule**: These are product decisions; document them.

---

## 10.8 Concurrency and Correctness

### 10.8.1 Common Failure Modes

- Two concurrent requests both pass check, both increment -> exceed limit
- Retries double-increment usage
- Worker retries replay usage again
- Partial failures charge usage but don't deliver output (customer anger)

### 10.8.2 MVP-Safe Correctness Patterns

Pick one primary pattern:

#### Pattern A — Atomic Increment with Conditional Check

- DB operation: "increment if new value <= limit"
- If fails -> deny

#### Pattern B — Reservation System

1. Reserve budget first (idempotent with requestId)
2. Execute job
3. Finalize (commit) or release reservation

#### Pattern C — Event Ledger + Aggregator

- Append events (idempotent)
- Periodic aggregation into snapshots (later, more complex)

**MVP recommendation**:
- For simple meters: Pattern A
- For expensive async work: Pattern B (reservation)

---

## 10.9 Integration with Billing (Part 9) and Auth (Part 8)

### 10.9.1 Where Plan Limits Live

- `planId` from subscription (webhook-derived) drives entitlements
- Entitlements drive gating decisions

### 10.9.2 Update Path on Plan Change

When plan changes:
1. Refresh entitlement cache
2. Recompute `limitValue` cached in TenantUsage (optional but recommended)
3. Ensure principal contains `planId` + `billingStatus`

**UX requirement**:
> Upgrade should remove blocks quickly after Stripe webhook updates subscription state

---

## 10.10 Observability + Customer Explainability

### 10.10.1 Minimum Dashboards

- Blocks per meter (daily)
- Top tenants by usage (to detect abuse)
- Warning threshold crossings
- Cost-to-serve proxies (tokens, exports, compute time)

### 10.10.2 Support "Explain" Flow (Must Exist)

When a customer is blocked, support should see:
- Meter triggered
- Current vs limit
- Reset time
- Top recent usage events (by action)
- User who caused biggest deltas (optional)

> This is why the UsageEvent ledger is so valuable.

---

## 10.11 Templates

### 10.11.1 Entitlements Table (Expanded)

| planId | meterName | limitValue | periodType | warn | hardBlock | degradePolicy |
|--------|-----------|------------|------------|------|-----------|---------------|
| free | exports | 10 | monthly | 0.8 | true | none |
| free | ai_tokens | 50,000 | monthly | 0.8 | true | none |
| pro | exports | 200 | monthly | 0.8 | true | none |
| pro | ai_tokens | 2,000,000 | monthly | 0.8 | true | none |

### 10.11.2 Limit Block Error Response (Standard)

```json
{
  "error": {
    "code": "AI_TOKENS_LIMIT_REACHED",
    "type": "limit",
    "message": "AI token limit reached. Upgrade to continue this month.",
    "details": {
      "meterName": "ai_tokens",
      "current": 50000,
      "limit": 50000,
      "delta": 1200,
      "resetAt": "2026-01-31T23:59:59Z",
      "planId": "free"
    }
  },
  "requestId": "..."
}
```

### 10.11.3 Limit Enforcement Checklist (Per Endpoint/Job)

- [ ] Identify meter(s) impacted by this action
- [ ] Compute delta (estimated tokens/exports/etc.)
- [ ] Fetch entitlement for tenant+meter
- [ ] Fetch current usage snapshot
- [ ] Atomic enforce (or reserve)
- [ ] Record UsageEvent with requestId
- [ ] Update snapshot + status (ok/warned/blocked)
- [ ] Return stable error codes on deny
- [ ] Emit telemetry events (warn/block)

---

## 10.12 Deliverables (What Must Exist)

- `ADR_Metering_Model.md` (meters chosen + why)
- `Entitlements_Table.md` (plans -> limits)
- `Usage_Model_v1.md` (TenantUsage + UsageEvent schema)
- `Limits_Enforcement_Policy.md` (warn/block rules per meter)
- `Support_Explain_Playbook.md` (how to debug blocks)
