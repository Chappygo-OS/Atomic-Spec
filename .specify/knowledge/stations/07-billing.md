# Station 07: Billing & Payments

## 1. Objective

Implement reliable billing where Stripe webhooks are the source of truth.

## 2. Inputs

- Pricing model.
- Auth/RBAC structure.

## 3. Trigger

Integrating Stripe or defining subscription logic.

## 4. The "How-To"

### Integration

- Use Stripe Checkout + Customer Portal.
- Avoid custom forms for MVP.

### Data Model

- Store `TenantBilling` (customer mapping) and `Subscription` locally.
- Use a `BillingEvent` ledger for webhooks.

### State Machine

- Map Stripe statuses to canonical internal states: `trialing`, `active`, `past_due`, `restricted`, `canceled`.

### Webhooks

- Validate signatures.
- Check idempotency using `stripeEventId`.
- Resolve `tenantId` from DB mapping (not just metadata).

### Reconciliation

- Implement a job to fix drift between Stripe and DB.

## 5. Gate Criteria

- [ ] ADR for Stripe Integration exists.
- [ ] Canonical Billing State Machine defined.
- [ ] Billing Access Policy (what allowed per state) defined.
- [ ] Webhook handling spec (events + mapping rules) exists.
