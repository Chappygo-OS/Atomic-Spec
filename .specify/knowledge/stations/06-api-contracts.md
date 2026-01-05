# Station 06 — API Contract Standards (OpenAPI-First): Procedures + Conventions + Templates

## 6.1 Objective

Define API standards that enable:

- **Parallel frontend/backend work** (stable contract)
- **Predictable behavior across modules** (consistent conventions)
- **Secure, tenant-safe access** (non-negotiable boundaries)
- **Stable versioning and backward compatibility**
- **Operational correctness** (idempotency, retries, observability)
- **Product consistency** (error messages and states match UX)

> In SaaS, the API contract is part of the product surface. A weak contract creates rework, inconsistent UX, support burden, and production incidents.

---

## 6.2 Owner

| Role | Responsibility |
|------|----------------|
| **Accountable** | TL |
| **Consulted** | PO (product semantics), UX (states and messaging) |
| **Consulted (required for gate)** | Sec (authN/authZ, tenancy), Ops (observability, reliability) |

---

## 6.3 Inputs (Required)

- `API_Touchpoints.md` (Part 5)
- `PRD_v1.md` (Part 4)
- Tenancy direction (Part 7 ADR or preliminary decision)
- `Analytics_Events_Draft.md` (so you don't forget telemetry properties)

---

## 6.4 OpenAPI-First Workflow (Recommended)

### Step 1 — Draft OpenAPI for Core Flows Before Implementation

Create `/03-architecture/API_v1.yaml` containing:

- Endpoints for MVP flows
- Request/response schemas
- Error schema + standard error codes
- Auth requirements
- Pagination/filtering parameters

> **Rule:** Frontend work targets the OpenAPI contract, not "whatever backend returns today."

### Step 2 — Define Contract "Levels"

To avoid paralysis, define:

| Level | Description |
|-------|-------------|
| Level 1 (MVP) | Stable for core flows; breaking changes require review |
| Level 2 | Secondary endpoints may evolve faster |

> This gives speed while protecting the critical paths.

### Step 3 — Contract Review Gate

Review contract with:

- **TL:** consistency, feasibility
- **PO/UX:** semantics, states, UX alignment
- **Sec:** tenant/RBAC correctness
- **Ops:** logging fields, rate limiting, reliability

### Step 4 — Implement Against the Contract (Not Vice Versa)

Backend implements responses exactly as defined. Frontend assumes only what the contract guarantees.

### Step 5 — Prevent Contract Drift

Pick at least one enforcement mechanism:

- Generate client types from OpenAPI
- Generate server stubs
- CI checks that compare implemented responses to schema (where possible)

---

## 6.5 Core API Principles (SaaS)

### 6.5.1 Tenant Scoping Principle

> Every request must be tenant-scoped.

**Two acceptable patterns:**

| Pattern | Example |
|---------|---------|
| Explicit scoping in URL | `/tenants/{tenantId}/reports/{reportId}` |
| Implicit scoping via auth context | `/reports/{reportId}` but server infers tenant from token and enforces tenant ownership |

**Guideline:**

- Explicit scoping makes debugging and logs clearer
- Implicit scoping reduces URL noise but requires strict server enforcement

> **Non-negotiable:** The server must enforce tenant boundaries regardless of client input.

### 6.5.2 URL Structure and Resource Modeling

Prefer nouns and resources:

```
/tenants/{tenantId}/members
/reports/{reportId}
/reports/{reportId}/export
```

Avoid verb endpoints unless they represent a true command:

```
/reports/{id}:publish (rare)
```

> **Rule:** Resource naming should reflect the domain model, not the UI.

### 6.5.3 HTTP Methods

| Method | Usage |
|--------|-------|
| GET | Read |
| POST | Create or command |
| PUT | Full replace (rare) |
| PATCH | Partial update (common) |
| DELETE | Delete |

> **Rule:** POST should be used for non-idempotent creation; idempotency must be added when needed.

### 6.5.4 Status Codes (Standard)

Use consistent status codes so the frontend can implement generic error handling.

| Code | Meaning |
|------|---------|
| 200 | OK |
| 201 | Created |
| 204 | No Content |
| 400 | Bad Request (validation errors; missing/invalid parameters) |
| 401 | Unauthorized (missing/invalid auth) |
| 403 | Forbidden (auth ok, not allowed) |
| 404 | Not Found (resource not found in tenant scope) |
| 409 | Conflict (duplicate, concurrency conflict, idempotency collision) |
| 422 | Unprocessable Entity (domain rule failure) |
| 429 | Too Many Requests (rate limiting) |
| 5xx | Server errors |

> **SaaS note:** Prefer 404 over 403 when you must avoid leaking resource existence across tenants.

### 6.5.5 Error Format (Single Standard)

All errors must return:

| Field | Description |
|-------|-------------|
| `error.code` | Stable, machine-readable |
| `error.message` | Human-friendly, can be shown in UI |
| `error.details` | Optional, structured |
| `requestId` | Correlation |

**Rules:**

- Frontend must not parse raw strings
- `error.code` must be documented and stable

**Recommended:** include `error.type` (optional):

- validation
- authorization
- billing
- limit
- conflict
- unknown

> This enables consistent UX behaviors.

### 6.5.6 Error Code Taxonomy (Recommended)

Define an error code namespace.

**Examples:**

| Code | Usage |
|------|-------|
| `AUTH_REQUIRED` | Missing authentication |
| `FORBIDDEN_ROLE` | Insufficient permissions |
| `TENANT_MISMATCH` | Wrong tenant context |
| `SEAT_LIMIT_REACHED` | Seat quota exceeded |
| `TRIAL_ENDED` | Trial period expired |
| `PAYMENT_REQUIRED` | Payment needed |
| `RATE_LIMITED` | Too many requests |
| `VALIDATION_FAILED` | Invalid input |
| `CONFLICT_VERSION` | Concurrency conflict |

> **Rule:** Every UX-relevant restriction state must have a dedicated error code.

### 6.5.7 Validation Errors (Standard Shape)

Validation errors should be field-addressable:

- Which field failed
- What rule
- Optional suggestion

> This reduces support tickets and speeds up frontend.

### 6.5.8 Pagination, Sorting, Filtering

Standardize to avoid custom implementations per endpoint.

**Preferred: cursor pagination for large datasets.**

| Parameter | Description |
|-----------|-------------|
| `limit` | Items per page |
| `cursor` | Pagination cursor |

**Response:**

| Field | Description |
|-------|-------------|
| `items` | Array of results |
| `nextCursor` | Next page cursor |

**Filtering:**

```
filter[field]=value (or consistent alternative)
```

**Sorting:**

```
sort=createdAt
order=asc|desc
```

> **Rule:** Never implement page-number pagination for large tables unless you have strong reasons.

### 6.5.9 Idempotency (Critical for SaaS)

Idempotency is required when:

- Clients may retry due to timeouts
- Operations trigger side effects (emails, payments, exports)
- Webhooks may deliver duplicates

**Mechanism:**

`Idempotency-Key` header

**Define:**

| Element | Decision |
|---------|----------|
| TTL for keys | e.g., 24 hours |
| Scope | Per tenant + endpoint |
| Response on duplicate key | Return the original result |

> **Rule:** Document which endpoints require idempotency.

### 6.5.10 Concurrency Control

Prevent "last write wins" data loss.

**Options:**

- ETag + If-Match
- Version fields (incrementing version)

**Behavior:**

- Return 409 on conflict
- Include server version in error details

### 6.5.11 Rate Limiting and Abuse Control

**Define:**

- Default rate limits per tenant/user
- Tighter limits for sensitive endpoints (login, invite, export)
- Burst vs sustained limits

**Response:**

- 429 + retry guidance

> **Rule:** Invite and auth endpoints must have explicit abuse controls.

### 6.5.12 Asynchronous Operations (When Needed)

For operations that take time (exports, heavy AI jobs):

1. POST starts a job -> returns jobId
2. GET job status endpoint
3. Client polls or uses webhooks

> **Rule:** Don't block the UI on long-running tasks with synchronous requests.

### 6.5.13 Observability Requirements (API-Level)

Every request should produce:

- `requestId` returned to client
- Logs include: requestId, tenantId, userId (if available), endpoint, status code, latency

> **Rule:** tenantId must be present in logs/traces for debugging and incident response.

### 6.5.14 Versioning Strategy

Choose and document a strategy:

| Strategy | Example |
|----------|---------|
| URL versioning | `/v1/...` |
| Header versioning | `Accept-Version: v1` |
| Semantic versioning per contract | |

**Recommended MVP rule:**

> Avoid breaking changes; when needed, add new fields and keep old ones.

---

## 6.6 Deliverables

- `/03-architecture/API_v1.yaml` (OpenAPI)
- `/03-architecture/API_Conventions.md` (conventions + error code list)
- Optional: generated types/SDK

---

## 6.7 Gate (Pass Criteria)

- [ ] OpenAPI covers MVP flows and all defined edge states
- [ ] Error schema standardized across endpoints
- [ ] Error codes exist for UX-relevant restriction states (RBAC/limits/billing)
- [ ] Tenant scoping is consistent and documented
- [ ] Idempotency defined for retryable operations
- [ ] Pagination standard defined and used
- [ ] Observability fields are included (requestId; logs include tenantId)

---

## 6.8 Templates Appendix (API)

### 6.8.1 Template — Error Schema (Example)

```json
{
  "error": {
    "code": "SEAT_LIMIT_REACHED",
    "type": "limit",
    "message": "Seat limit reached. Upgrade to invite more users.",
    "details": {
      "limit": 10,
      "current": 10,
      "meter": "seats"
    }
  },
  "requestId": "req_abc123"
}
```

### 6.8.2 Template — Validation Error Schema (Example)

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "type": "validation",
    "message": "Some fields are invalid.",
    "details": {
      "fields": [
        {
          "path": "email",
          "rule": "email",
          "message": "Email format is invalid."
        }
      ]
    }
  },
  "requestId": "req_def456"
}
```

### 6.8.3 Template — OpenAPI Skeleton (Minimal)

```yaml
openapi: 3.0.3
info:
  title: Product API
  version: 1.0.0

paths: {}

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer

  schemas:
    ErrorResponse:
      type: object
      properties:
        error:
          type: object
          properties:
            code:
              type: string
            type:
              type: string
            message:
              type: string
            details:
              type: object
              additionalProperties: true
        requestId:
          type: string

security:
  - bearerAuth: []
```

### 6.8.4 Template — API Conventions Document

**File:** `/03-architecture/API_Conventions.md`

```markdown
# API Conventions

## Base URL

- Production: `https://api.example.com/v1`
- Staging: `https://api.staging.example.com/v1`

## Authentication

- Bearer token in Authorization header
- Token includes tenantId claim

## Tenant Scoping

- Pattern: [explicit/implicit]
- Enforcement: server-side validation on every request

## Pagination

- Standard: cursor-based
- Parameters: `limit`, `cursor`
- Response: `items`, `nextCursor`

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| AUTH_REQUIRED | 401 | Missing authentication |
| FORBIDDEN_ROLE | 403 | Insufficient permissions |
| TENANT_MISMATCH | 403/404 | Wrong tenant context |
| SEAT_LIMIT_REACHED | 403 | Seat quota exceeded |
| TRIAL_ENDED | 403 | Trial period expired |
| PAYMENT_REQUIRED | 402 | Payment needed |
| RATE_LIMITED | 429 | Too many requests |
| VALIDATION_FAILED | 400 | Invalid input |
| CONFLICT_VERSION | 409 | Concurrency conflict |

## Idempotency

- Header: `Idempotency-Key`
- Required for: POST /invites, POST /payments, POST /exports
- TTL: 24 hours

## Rate Limits

| Endpoint Type | Limit |
|---------------|-------|
| Default | 100 req/min per tenant |
| Auth endpoints | 10 req/min per IP |
| Export endpoints | 5 req/min per tenant |

## Observability

- All responses include `requestId`
- All logs include: requestId, tenantId, userId, endpoint, statusCode, latencyMs
```
