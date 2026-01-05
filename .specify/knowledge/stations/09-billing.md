# Station 09 — Billing + Payments + Webhooks (SaaS, Stripe)

> Architecture, Flows, and Failure Handling

---

## 9.1 Objective

Implement billing so it is:

- **Reliable**: Stripe webhooks are the source of truth; event processing is idempotent
- **Tenant-safe**: every billing object maps deterministically to tenantId
- **Product-consistent**: billing states gate features predictably with stable error codes
- **Auditable**: plan changes and payment incidents are logged
- **Operable**: retries, reconciliation, and "fix billing" support paths exist

> **Key mental model**: Billing is an event-driven state machine, not a checkout button.

---

## 9.2 Stripe Primitives

In Stripe terms (common for SaaS subscriptions):

| Primitive | Description |
|-----------|-------------|
| Customer | Who is paying (map to tenant) |
| Checkout Session | Hosted checkout (recommended for MVP) |
| Subscription | Recurring payment contract |
| Invoice | Recurring billing document |
| PaymentIntent | Payment attempt (often attached to invoices) |
| Customer Portal | Self-serve billing management (strongly recommended) |
| Webhook events | Your source of truth |

> **MVP rule**: Use Stripe Checkout + Customer Portal. Avoid building your own payment forms early.

---

## 9.3 ADRs (Required Decisions)

Create ADRs for:

| Decision | Options/Notes |
|----------|---------------|
| Stripe integration model | Checkout + Portal (recommended) vs custom payment elements |
| Pricing model | seat-based vs usage-based vs hybrid |
| Canonical billing state machine | your internal statuses and access policy per status |
| Tenant <-> Stripe mapping strategy | how you store stripeCustomerId, stripeSubscriptionId, and how you guarantee correctness |
| Webhook reliability strategy | signature validation, idempotency, ordering, retries, reconciliation |
| Cancellation policy | cancel at period end vs immediate; downgrade semantics |

---

## 9.4 Data Model (Stripe-Backed Billing Foundation)

### 9.4.1 TenantBilling (One Per Tenant)

**Required fields**:
- `tenantId`
- `stripeCustomerId`
- `billingEmail` (optional)
- `defaultPaymentMethodStatus` (optional)
- `createdAt`, `updatedAt`

**Rules**:
- Unique index on `stripeCustomerId`
- Never reuse a Stripe customer across tenants

### 9.4.2 Subscription (One Active Subscription Per Tenant, Usually)

**Fields**:
| Field | Description |
|-------|-------------|
| tenantId | |
| stripeSubscriptionId | |
| planId | your internal plan key |
| status | your canonical status |
| currentPeriodStart | |
| currentPeriodEnd | |
| trialEnd | nullable |
| cancelAtPeriodEnd | bool |
| canceledAt | nullable |
| priceId | Stripe Price (optional but useful) |
| quantity | seats, if seat-based |
| timestamps | |

**Indexes**:
- Unique `(tenantId, status in active-like states)` as a logical constraint
- Unique `stripeSubscriptionId`

### 9.4.3 BillingEvent (Immutable Ledger)

**Fields**:
| Field | Description |
|-------|-------------|
| stripeEventId | unique |
| type | |
| apiVersion | optional |
| receivedAt | |
| processedAt | |
| processingStatus | success/failed |
| tenantId | resolved |
| stripeCustomerId | resolved |
| payloadJson | store raw or trimmed; be mindful of PII |
| lastError | nullable |
| requestId | |

**Rules**:
- Always insert into ledger before processing
- Idempotency = unique on `stripeEventId`

### 9.4.4 Invoice Snapshot (Optional But Practical)

If you want "Billing history" in-app:

| Field | Description |
|-------|-------------|
| stripeInvoiceId | |
| tenantId | |
| status | |
| amountDue, currency | |
| hostedInvoiceUrl, invoicePdf | |
| periodStart, periodEnd | |

> **MVP shortcut**: You can link to Stripe Customer Portal instead of storing invoices.

---

## 9.5 Canonical Billing State Machine

> Stripe has many statuses; you should map them to a small set that drives access.

**Recommended internal statuses**:

| Status | Description |
|--------|-------------|
| `trialing` | Trial active |
| `active` | Paid, good standing |
| `past_due` | Payment failed, in grace window |
| `restricted` | Hard restriction - no productive use |
| `canceled` | No longer active; may still be in paid-through period |
| `incomplete` | Started but not completed / requires action |

> Access policy lives here. The product enforces access via this state, not raw Stripe status.

---

## 9.6 Mapping Stripe Signals to Canonical States

You will primarily react to webhooks; you may also query Stripe for reconciliation.

**Common mappings**:

| Stripe Status | Canonical Status |
|---------------|------------------|
| subscription `trialing` | `trialing` |
| subscription `active` | `active` |
| subscription `past_due` | `past_due` |
| subscription `unpaid` | `restricted` |
| subscription `canceled` | `canceled` |
| Payment requires action (SCA) | `incomplete` (until resolved) |

> **Rule**: Decide whether `past_due` is partially usable (read-only) or still fully usable during grace.

---

## 9.7 Billing Flows (Stripe-Specific Specs)

### 9.7.1 Upgrade / Start Subscription (Checkout)

**Happy path**:
1. Admin clicks Upgrade
2. Backend creates Stripe Checkout Session with:
   - `customer` = existing stripeCustomerId (or create if none)
   - `mode` = subscription
   - `line_items` = priceId (+ quantity if seats)
   - `success_url` and `cancel_url`
   - `metadata` includes tenantId (and environment)
3. Frontend redirects to Stripe Checkout
4. Payment succeeds
5. Stripe sends webhook events
6. Webhook updates your DB subscription state
7. User returns -> app polls "billing status" until active

**Critical rules**:
- `success_url` is NOT the source of truth
- The webhook is the source of truth
- Backend must be able to re-check status (poll endpoint)

**UX rule**:
> After return, show "Activating subscription..." with retry/poll logic

### 9.7.2 Customer Portal (Self-Serve Changes)

Use Stripe Customer Portal for:
- Updating payment method
- Downloading invoices
- Canceling subscription
- Switching plans (if you enable it)

**Backend provides a "portal session" URL**:
- Only Admin can access
- Portal session tied to stripeCustomerId

> **MVP win**: Reduces support load massively.

### 9.7.3 Trial End Behavior (Must Be Explicit)

**Define**:
- What happens at trial end:
  - Block create vs read-only vs block all
  - Which CTA shows (Upgrade)
  - Error code: `TRIAL_ENDED`

**Implementation**:
- Trial end should be triggered by webhook state update
- App should reflect it immediately (auth principal updated)

### 9.7.4 Payment Failed / Dunning Flow

**Define**:
- Grace period length (e.g., 7 days)
- What is allowed during grace
- When you hard restrict

**States**:
- `past_due` during grace -> maybe read-only or still usable
- `restricted` after grace or Stripe status unpaid

**Error codes**:
- `ACCOUNT_PAST_DUE` (grace)
- `PAYMENT_REQUIRED` (hard restricted)

**UX**:
> Show clear banner + link to portal "Fix payment method"

### 9.7.5 Seat-Based Subscriptions (If Applicable)

**Decide**:
- Does quantity in Stripe equal seat count?
- When do you sync seat count changes?
  - Immediate on member added/removed
  - Or batched daily

**MVP recommendation**:
- Seat-based: update quantity when membership changes (Admin actions)
- Enforce seat limits in-app regardless (Part 8 + Part 7)

---

## 9.8 Webhooks — The Heart of Billing

### 9.8.1 Non-Negotiable Webhook Rules

- Validate Stripe signature using the webhook secret
- Insert event into BillingEvent ledger before processing
- Idempotency by `stripeEventId`
- Process quickly (ack 2xx fast)
- Implement retry-safe processing (Stripe retries)

### 9.8.2 Webhook Endpoint Architecture

**Recommended**:
- `/webhooks/stripe` as a dedicated route
- Minimal logic in controller:
  1. Verify signature
  2. Store event
  3. Enqueue for async processing (recommended)
  4. Return 200

**If you cannot queue yet**:
- Process synchronously but keep logic tight and fast

### 9.8.3 Event Types You Likely Care About (MVP)

**Common set**:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

> **Rule**: Don't guess; build mapping around the subscription lifecycle events + invoice payment failures.

### 9.8.4 Tenant Resolution Strategy (Critical)

You must reliably map Stripe events to tenantId.

**Best practice**:
1. Store `stripeCustomerId <-> tenantId` in DB
2. Include `tenantId` in Checkout Session metadata (belt + suspenders)
3. On webhook:
   - Extract customer id from event object
   - Look up tenantId using your DB mapping
   - If not found, mark event failed and alert (don't silently drop)

> **Rule**: Never trust metadata alone; it's helpful but DB mapping is authoritative.

### 9.8.5 Idempotency Strategy

Use a unique constraint on `stripeEventId`.

**Processing algorithm**:
1. Try insert event row
2. If duplicate -> return 200 immediately
3. Else process
4. Mark `processedAt` + status

**On failure**:
- Mark failed + error
- Allow replay (manual or automatic retry)

### 9.8.6 Out-of-Order and Eventual Consistency

> Stripe events can arrive out of order.

**Rules**:
- Store Stripe event `created` timestamp
- When updating subscription state, prefer the newest relevant event
- Avoid regressing state due to late events
- Reconciliation job (9.9) is your safety net

---

## 9.9 Reconciliation (Required for Reliability)

> Even with webhooks, build reconciliation early.

**MVP reconciliation job (hourly or daily)**:
1. For tenants in `past_due`, `incomplete`, or "unknown"
2. Fetch Stripe subscription status by `stripeSubscriptionId`
3. Reconcile DB state
4. Log correction + audit entry

**Support use case**:
> "Customer paid but still locked" -> run reconcile on that tenant

---

## 9.10 Access Gating Integration (Part 8)

Billing state must be part of the auth principal:
- `planStatus` / `billingStatus`
- Optionally `planId` and `limitsSnapshot`

**Enforcement**:
- If restricted, API returns stable error codes
- UI renders consistent CTAs (Upgrade / Fix payment)

> **Rule**: Billing gating must be enforced server-side, not only UI.

---

## 9.11 Security Checklist (Stripe-Specific)

- [ ] Use Stripe Checkout/Portal; do not handle card data
- [ ] Validate webhook signatures
- [ ] Never log card/payment details
- [ ] Store only necessary billing identifiers + URLs
- [ ] Treat webhook endpoint as sensitive:
  - Separate secret per environment
  - Rotate secrets if compromised
- [ ] Rate limit non-webhook billing endpoints (create checkout session, create portal session)
- [ ] Audit billing changes

---

## 9.12 Observability + Metrics (Billing)

**Track**:
- Webhook receive count + processing success/fail
- Webhook processing latency
- Number of tenants in `past_due` / `restricted`
- Checkout conversion funnel:
  - `upgrade_clicked` -> `checkout_created` -> `checkout_completed` -> `subscription_active`
- Reconciliation drift count

**Alerts**:
- Webhook failure spike
- Sustained `past_due` growth
- Reconcile drift > threshold

---

## 9.13 Templates

### 9.13.1 Billing Access Policy Table

Define per canonical status:

| Status | Allowed | Blocked | UI Message | CTA | Error Code |
|--------|---------|---------|------------|-----|------------|
| `past_due` | read-only | create/export | Payment failed | Fix payment | `ACCOUNT_PAST_DUE` |
| `restricted` | none | all | Account restricted | Upgrade / Pay invoice | `PAYMENT_REQUIRED` |
| `trialing` | full access | - | Trial active | - | - |

### 9.13.2 Webhook Processing Checklist

- [ ] Signature validated
- [ ] Event stored in ledger
- [ ] Idempotency check (`stripeEventId`)
- [ ] Tenant resolved via `stripeCustomerId` mapping
- [ ] Transactional update of Subscription
- [ ] Audit entry for plan/status change
- [ ] Metrics emitted
- [ ] Return 2xx quickly

### 9.13.3 Billing Error Codes

| Code | Description |
|------|-------------|
| `TRIAL_ENDED` | Trial period has ended |
| `ACCOUNT_PAST_DUE` | Payment failed, in grace period |
| `PAYMENT_REQUIRED` | Hard restriction, payment needed |
| `SUBSCRIPTION_CANCELED` | Subscription has been canceled |
| `CHECKOUT_INCOMPLETE` | Checkout not completed |
| `BILLING_TENANT_MAPPING_MISSING` | Internal alert condition |

---

## 9.14 Deliverables (What Must Exist)

- `ADR_Stripe_Integration.md`
- `ADR_Billing_StateMachine.md`
- `Billing_Access_Policy.md`
- `Stripe_Webhooks_Spec.md` (events handled + mapping rules)
- `Billing_Reconciliation_Spec.md`
