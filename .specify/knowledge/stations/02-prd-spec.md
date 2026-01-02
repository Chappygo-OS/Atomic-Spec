# Station 02: Product Requirements (PRD)

## 1. Objective

Create a buildable, testable, and SaaS-complete specification that serves as the single source of truth.

## 2. Inputs

- Discovery artifacts (ICP, Wedge, Metrics).
- User Flows.

## 3. Trigger

Before starting engineering estimation or code implementation.

## 4. The "How-To"

### Header

- Must list owner, status (Draft/Approved), and target milestone.

### Scope Contract

- Define explicit "Goals".
- Define mandatory "Non-goals" to prevent scope creep.

### Stories

- Write User Stories (As a... I want... So that...).
- Map to "Must", "Should", or "Could" priorities.

### Acceptance Criteria (AC)

- Use "Given/When/Then" format.
- Every story must cover SaaS edge cases:
  - Authorization (403)
  - Tenant boundary
  - Validation
  - Limit-hit behavior
  - Billing state

### SaaS Rules Section

- Explicitly define:
  - **Tenancy**: Boundary definition.
  - **RBAC**: Roles/permissions.
  - **Limits**: Meters/tiers.
  - **Billing impact**: Trial/payment failure behavior.

### NFRs

- Define Security requirements.
- Define Performance requirements (e.g., p95 < 300ms).
- Define Reliability requirements.

## 5. Gate Criteria

- [ ] MVP scope and Non-goals are explicit.
- [ ] Every "Must" story has testable Acceptance Criteria.
- [ ] SaaS Rules (Tenancy, RBAC, Limits, Billing) are defined.
- [ ] Analytics events are mapped to metrics.
- [ ] All open questions are resolved or have owners/dates.
