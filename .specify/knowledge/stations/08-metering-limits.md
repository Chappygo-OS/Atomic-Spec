# Station 08: Usage Metering & Limits

## 1. Objective

Protect unit economics and enforce quotas via server-side controls.

## 2. Inputs

- Billing model.
- Auth principal structure.

## 3. Trigger

Implementing features that consume resources (AI tokens, storage, seats).

## 4. The "How-To"

### Select Meters

- Choose top cost/risk drivers (e.g., `seats`, `ai_tokens`, `api_requests`).

### Entitlements

- Create a table mapping `planId` → `limitValue` for each meter.

### Enforcement

- Enforce at **API layer** (request time) and **Worker layer** (async).
- Use a "Warn → Block → Upgrade" policy.

### Response

- Return stable error codes (e.g., `USAGE_LIMIT_REACHED`) with usage details.

### Correctness

- Use atomic increments or reservation patterns to prevent race conditions.

## 5. Gate Criteria

- [ ] Meters selected and documented.
- [ ] Entitlements Table (Plans → Limits) exists.
- [ ] Limits Enforcement Policy (Warn/Block rules) defined.
- [ ] Usage Model v1 schema defined.
