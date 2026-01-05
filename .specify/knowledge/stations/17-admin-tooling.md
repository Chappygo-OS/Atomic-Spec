# Station 17 — Customer Support + Admin Tooling

> Reduce Support Load, Improve Reliability

## 17.1 Objective

Build support and admin tooling so you can:

- Resolve customer issues quickly without engineers paging each time
- Safely inspect tenant state (billing, limits, jobs, permissions)
- Perform controlled interventions (retries, unlocks, suspensions)
- Keep a clear audit trail of all support actions
- Scale operations as customers and complexity grow

> **Rule:** If support actions are done via DB scripts, you don't have support tooling - you have risk.

## 17.2 Scope (MVP vs Later)

**MVP (Recommended):**

- Internal admin panel with strict access controls
- Tenant lookup and overview
- Billing status + last Stripe events
- Usage/limits snapshot + last usage events
- Job queue status (per tenant)
- User/membership viewer (roles, status)
- Safe "actions": re-run reconciliation, resend invite, revoke sessions, suspend tenant/user
- Audit logging for every admin action

**Later:**

- Impersonation (dangerous; only if needed)
- Scripted playbooks (one-click workflows)
- Advanced search across entities
- Proactive support automation (alerts -> tickets)
- Multi-region operational controls

## 17.3 Security Model for Admin Tooling (Non-Negotiable)

> Admin tooling is a high-value target.

### 17.3.1 Access Controls

- Separate SupportAdmin role (not same as normal product roles)
- Enforce strong AuthN (2FA if possible)
- IP allowlist (optional MVP, recommended later)
- Strict session timeouts
- Audit all access + actions

> **Rule:** Admin tooling must be behind a separate permission boundary.

### 17.3.2 Data Access Rules

- Support users can only access tenants they are authorized to support (if needed)
- No raw PII display by default (mask where possible)
- Show internal IDs; reveal PII only with explicit action and audit

## 17.4 Admin Panel Core Screens (MVP)

### 17.4.1 Tenant Overview (First Screen)

**Must Show:**

| Field | Description |
|-------|-------------|
| tenantId, name (if safe) | Identification |
| planId, billingStatus | Current plan |
| createdAt, status | Active/suspended |
| Seat count, usage summary | Current usage |
| Last activity timestamp | Recent activity |
| Risk indicators | past_due, blocked by limits, high error rates |

> **Support outcome:** Instantly understand the tenant's health.

### 17.4.2 Billing Screen (Stripe)

**Must Show:**

| Field | Description |
|-------|-------------|
| stripeCustomerId, subscriptionId | Stripe identifiers |
| Canonical billing status | active/past_due/restricted/etc. |
| Current period end, trial end | Timeline |
| Last N Stripe events | From BillingEvent ledger |
| "Run reconciliation now" action | Manual trigger |
| Link to Stripe dashboard | Internal use |

**Actions:**

- Trigger reconcile for this tenant
- Refresh subscription snapshot (safe re-fetch)
- Generate portal session URL (Admin-only, logged)

### 17.4.3 Usage + Limits Screen

**Must Show:**

| Field | Description |
|-------|-------------|
| Per-meter usage | current/limit/resetAt |
| Recent usage events | Top contributors |
| Most frequent blocked actions | Codes |
| "Why blocked" explanation panel | Diagnostic |

**Actions:**

- Refresh usage snapshot (safe)
- (Optional) Grant temporary extension (risky - prefer plan upgrade)

> **Rule:** Avoid manual overrides unless you can track them and expire them.

### 17.4.4 Users + Memberships Screen

**Must Show:**

| Field | Description |
|-------|-------------|
| User list | With role + membership status |
| Last login timestamps | Activity |
| Invite status and timestamps | Pending invites |
| Audit log entries | For role changes |

**Actions:**

- Resend invite
- Revoke sessions for a user
- Suspend/unsuspend membership
- Change role (dangerous; audit required)

### 17.4.5 Jobs / Async Operations Screen

**Must Show:**

| Field | Description |
|-------|-------------|
| Job counts by status | For tenant |
| Recent job failures | + error codes |
| Retry counts and last error message | Sanitized |
| Links to logs/traces | By requestId/jobId |

**Actions:**

- Retry failed job (idempotent only)
- Cancel stuck job (if supported)
- Requeue with reason

## 17.5 Support Playbooks (Make Issues Repeatable)

### 17.5.1 "Customer Paid But Still Locked"

**Steps:**

1. Check billing status + last Stripe events
2. Run reconcile now
3. Verify subscription active + planId updated
4. Confirm principal refresh (cache invalidation)
5. If still locked -> check limits gating and error codes

**Actions:** Reconcile, refresh subscription cache

### 17.5.2 "User Can't Access Tenant"

**Steps:**

1. Verify membership status (active/suspended/removed)
2. Verify role
3. Check tenant suspension
4. Check audit logs for role changes
5. Verify tenant context selection logic

**Actions:** Resend invite, unsuspend membership, revoke sessions

### 17.5.3 "Exports Failing"

**Steps:**

1. Check job failures and error codes
2. Check usage limits for exports
3. Check storage access (signed URLs)
4. Check external dependencies latency/errors
5. Retry idempotent jobs

### 17.5.4 "Limits Blocking Unexpectedly"

**Steps:**

1. Check meter + current vs limit + resetAt
2. Inspect last usage events
3. Confirm entitlements match planId
4. If plan just changed -> refresh entitlements cache
5. If data drift -> run usage reconcile

## 17.6 Audit Logging for Admin Actions (Mandatory)

Every admin action logs:

| Field | Description |
|-------|-------------|
| actorSupportUserId | Who performed the action |
| tenantId / target userId | Target of the action |
| actionType | What was done |
| timestamp | When |
| reason | Required field |
| requestId | For tracing |

> **Rule:** Require a "reason" text for sensitive actions (suspend, role change).

## 17.7 Self-Serve Support Features (High ROI)

Reduce support requests with:

- Billing status banner + "Fix payment" portal link
- Usage meter page with "resetAt" and top contributors
- Job status page with retry suggestions
- System status page (internal or external)

> **Rule:** Good product UX is a support strategy.

## 17.8 Deliverables

- `Admin_Tooling_Spec.md` (screens + data + actions)
- `Support_Playbooks.md`
- `Admin_Action_Audit_Policy.md`
- `Support_Roles_and_Permissions.md`
- `Operational_SelfServe_UX.md`
