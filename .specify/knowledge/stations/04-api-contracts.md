# Station 04: API Contract Standards

## 1. Objective

Define a stable, tenant-safe interface that enables parallel frontend/backend work.

## 2. Inputs

- User Flows.
- PRD.
- Data Model direction.

## 3. Trigger

Before backend implementation; during technical design.

## 4. The "How-To"

### Workflow

- **OpenAPI-first**: Define the YAML before coding.

### Tenant Scoping

- Every request must be tenant-scoped.
- Either explicit in URL `/tenants/{id}/...` or implicit via auth token.

### Standard Status Codes

- `200` (OK)
- `400` (Bad Request)
- `401` (Unauthorized)
- `403` (Forbidden)
- `404` (Not Found _in tenant_)
- `409` (Conflict)
- `429` (Rate Limit)

### Error Format

- Standard JSON response including:
  - `error.code` (machine stable)
  - `error.message`
  - `requestId`

### Specific Error Codes

- Define codes for SaaS states: e.g., `SEAT_LIMIT_REACHED`, `TRIAL_ENDED`, `TENANT_MISMATCH`.

### Idempotency

- Use `Idempotency-Key` header for retryable operations.

## 5. Gate Criteria

- [ ] OpenAPI covers MVP flows and edge states.
- [ ] Error schema is standardized.
- [ ] Tenant scoping is consistent and documented.
- [ ] Idempotency is defined for relevant operations.
- [ ] Observability fields (`requestId`) are included.
