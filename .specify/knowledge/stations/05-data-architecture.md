# Station 05: Tenancy & Data Architecture

## 1. Objective

Make explicit decisions on tenancy models and data schemas to prevent security and scaling issues.

## 2. Inputs

- PRD.
- User Flows.
- API Contract.

## 3. Trigger

Designing the database schema or data access layer.

## 4. The "How-To"

### Tenancy Model

- Select:
  - **Model A**: Shared DB/Schema.
  - **Model B**: Shared DB/Sep Schema.
  - **Model C**: Sep DB.
- _Default for MVP is usually Model A with strict enforcement._

### Enforcement

- **Server-side only**.
- **"No naked queries"**: All DB access must pass through tenant-scoped functions.

### Baseline Entities

- Model `Tenant`, `User`, `Membership`, `Role`, `Subscription`, `Usage`, `AuditLog`.

### Keys

- Always include `tenant_id` in tenant-scoped resources.
- Use composite unique keys `unique(tenant_id, external_id)`.

### Isolation Tests

- Plan tests for:
  - Read isolation.
  - Write isolation.
  - Join leakage.

## 5. Gate Criteria

- [ ] Tenancy model selected and documented via ADR.
- [ ] Enforcement pattern (middleware + DAL) defined.
- [ ] "No naked queries" rule adopted.
- [ ] Tenant isolation test plan exists.
