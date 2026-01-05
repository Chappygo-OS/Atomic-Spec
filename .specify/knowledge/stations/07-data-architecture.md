# Station 07 — Tenancy + Data Architecture (SaaS)

> ADRs, Enforcement, and Modeling

---

## 7.1 Objective

Make tenancy and data architecture explicit early because these decisions:

- Are expensive to change later (schema, queries, migrations, authZ patterns)
- Directly impact security, performance, cost, compliance, and product constraints
- Determine how RBAC, billing, limits, auditability, and analytics will actually work

> **Outcome of Part 7**: A small set of ADR-backed decisions, plus a data model v1 that aligns with flows, API contract, and SaaS fundamentals.

---

## 7.2 Roles and Responsibilities

**Accountable**: Tech Lead

**Consulted (mandatory)**:
- Security owner: tenant isolation, authZ model, PII posture
- Ops: reliability, scaling model, backups/restores, cost

**Consulted (strongly recommended)**:
- Product + UX: product constraints that impact data (billing states, limits, audit needs, collaboration)

> **Rule**: No "implicit architecture". If it impacts tenant isolation, it must be written.

---

## 7.3 Inputs

### 7.3.1 Required

- PRD v1 (Part 4)
- User flows + screen/state inventory (Part 5)
- API contract v1 (Part 6)

### 7.3.2 Optional but Very Useful

- Expected tenant sizes (min/median/max users, records, uploads)
- Compliance constraints (PII, residency, retention)
- Growth assumptions (number of orgs in 6-12 months)

---

## 7.4 Tenancy Model Selection

### 7.4.1 Tenancy Models (Common Patterns)

> You must choose one explicitly and document why.

#### Model A — Shared DB, Shared Schema (tenant_id column)

**Description**: One database, same tables for everyone, every row has `tenant_id`.

**Pros**:
- Fastest to ship (best MVP default)
- Cheapest operationally
- Easiest migrations (single schema)

**Cons**:
- Highest impact if enforcement is weak (data leakage risk)
- Noisy neighbor risks if not careful with indexing/quotas
- Some enterprise customers may object later

**Best for**:
- MVP / early-stage SaaS
- Many small tenants, cost sensitive
- You can enforce tenant isolation strictly

#### Model B — Shared DB, Separate Schema per Tenant

**Description**: One database, each tenant has its own schema/namespace.

**Pros**:
- Stronger isolation than Model A
- Easier per-tenant backup/restore (sometimes)

**Cons**:
- Schema migrations are painful at scale (N schemas)
- Operational complexity increases early

**Best for**:
- Moderate number of tenants
- More "enterprise-ish" isolation requirements without full per-DB cost

#### Model C — Separate DB per Tenant

**Description**: Each tenant gets its own database.

**Pros**:
- Strongest isolation
- Per-tenant tuning, easier "noisy neighbor" control
- Easier data residency and some compliance stories

**Cons**:
- Expensive and operationally heavy
- Onboarding and migrations become complex
- Not MVP-friendly unless you have strong ops maturity

**Best for**:
- High-value enterprise tenants
- Regulated environments
- Low tenant count, high revenue per tenant

#### Model D — Hybrid (Tiered Isolation)

**Description**: Default tenants on shared DB; large/enterprise tenants on dedicated DB or schema.

**Pros**:
- Pragmatic growth path
- Keep MVP cost low while serving big customers later

**Cons**:
- You must build migration tooling and operational playbooks
- Increases complexity in routing and ops

**Best for**:
- SaaS expecting a long tail + a few whales
- B2B where enterprise asks for isolation eventually

### 7.4.2 Decision Criteria (Scorecard)

Create a simple scorecard (1-5) and pick the best MVP decision:

| Criterion | Score (1-5) |
|-----------|-------------|
| Security risk (leak blast radius) | |
| Operational complexity | |
| Cost-to-serve | |
| Scaling ceiling | |
| Migration complexity | |
| Customer requirements (enterprise/security questionnaires) | |
| Team maturity (ops capacity) | |

> **Strong default for most MVPs**: Model A, but only if Part 7.5 enforcement is non-negotiable.

### 7.4.3 Triggers to Revisit the Tenancy Model

Document triggers so you don't "accidentally stay" in a model forever.

**Examples**:
- Single tenant exceeds X% of DB CPU or storage for Y days
- Enterprise customer requires dedicated isolation
- Regulatory requirement appears (residency / strict segregation)
- Incident risk: you detect repeated near-misses in tenant isolation

---

## 7.5 Tenancy Enforcement (Non-Negotiable)

### 7.5.1 Principle: Tenant Isolation is Enforced Server-Side

Tenant boundaries must be enforced in:
- **Auth middleware**: extract tenant context, validate membership
- **Authorization layer**: role/permission checks
- **Data access layer (DAL)**: every query is tenant-scoped
- **Service layer**: domain logic, cross-entity checks

> Never rely on client-side filtering. The client can be wrong or malicious.

### 7.5.2 Tenant Context Propagation

Define exactly how the server knows which tenant the request belongs to.

**Two valid approaches**:

**A) Tenant in URL + validated against auth**
- Request: `/tenants/{tenantId}/...`
- Server checks: user is member of `{tenantId}`

**B) Tenant inferred from session + resource ownership**
- Request: `/reports/{reportId}`
- Server resolves report → tenantId → verifies membership

> **Rule**: Choose one default approach and apply consistently. Mixed patterns are allowed only with explicit rules.

### 7.5.3 "No Naked Queries" Rule (DAL Discipline)

All DB access must go through tenant-scoped functions.

**Examples**:
```
getReport(tenantId, reportId)
listReports(tenantId, cursor, limit)
createReport(tenantId, payload)
```

**Ban**:
- `getReport(reportId)` without tenant context (unless it internally resolves tenant and enforces)
- Raw queries that forget tenant constraints

**If using an ORM, enforce via**:
- Global scopes (where supported)
- Repository pattern requiring tenantId
- Database Row Level Security (RLS) (optional; strong control if feasible)

### 7.5.4 Tenant Isolation Test Plan (Minimum Set)

> This is mandatory, and these tests should run in CI.

**Read isolation**:
- Cannot fetch resource by id from another tenant (expect 404 or 403 per policy)
- List endpoints never include cross-tenant resources

**Write isolation**:
- Cannot mutate another tenant's resource
- Cannot create relations across tenants (e.g., attach a file from another tenant)

**Join leakage**:
- Multi-table joins must include tenant constraints on all relevant tables
- Tests specifically cover "report + project + membership" joins

**Auth edge cases**:
- User removed from tenant → access revoked immediately
- Role change takes effect correctly

---

## 7.6 Data Architecture Baseline (SaaS Foundation)

### 7.6.1 Baseline Entities (Most B2B SaaS)

These are almost always needed and should be designed early:

| Entity | Key Fields |
|--------|------------|
| Tenant (Organization/Workspace) | id, name, createdAt, status |
| User | id, email, name, auth identifiers |
| Membership | userId, tenantId, role, status, createdAt |
| Role / Permission model | either fixed roles, or role + permission set |
| Subscription / Plan | tenantId, planId, status, currentPeriodEnd, etc. |
| Usage / Metering | tenantId, meterName, currentValue, periodStart/end |
| Audit Log | tenantId, actorUserId, actionType, target, metadata, timestamp |

> **Rule**: If you do "teams", membership is not optional.

### 7.6.2 Domain Entities (Your Product)

Define entities that map to the core wedge flow.

For each domain entity, write:
- What problem it represents
- Lifecycle states (draft/published/archived, etc.)
- Relationships (tenant, owner, project, files)
- Access rules (who can see/edit/delete)

> **Rule**: Model the domain around workflows and states, not screens.

---

## 7.7 Modeling Guidelines

### 7.7.1 Keys and Uniqueness (Tenant-First Design)

For tenant-scoped resources:
- Always include `tenant_id`
- Add composite uniqueness where needed:
  - `unique(tenant_id, external_id)`
  - `unique(tenant_id, slug)` for human-readable identifiers

**Indexing rule of thumb**:
- Nearly every query filters by `tenant_id` → index it
- For list endpoints: index `(tenant_id, created_at)` or `(tenant_id, updated_at)` depending on sort

### 7.7.2 Soft Delete vs Hard Delete

Decide early:
- Do you soft-delete domain entities? (recommended for most B2B)
- Retention windows (e.g., 30/90 days)
- How restore works (if supported)

> **Audit + legal note**: Deleting data may conflict with audit requirements; define exceptions.

### 7.7.3 Auditability (What Must Be Traceable)

**Minimum recommended audited actions**:
- Membership changes (invite, role change, remove)
- Permission changes
- Billing events (upgrade, downgrade, cancellation)
- Exports/downloads of sensitive data
- Destructive actions (delete, bulk operations)

**Define**:
- Who performed it (actor)
- What they did (actionType)
- What was affected (entity type/id)
- Metadata (old/new role, plan, etc.)

### 7.7.4 PII and Retention

**Define**:
- What fields are PII (email, name, IPs, addresses, etc.)
- Retention policy (how long logs are kept)
- Deletion policy (user deletion, tenant deletion)
- Encryption requirements (at rest, sensitive fields)

> **Rule**: Retention and deletion must be aligned with product promises and compliance.

### 7.7.5 Files and Storage (If Applicable)

If you support uploads:
- Storage strategy (object storage + metadata table)
- Virus scanning / content validation policy
- Signed URLs policy
- Tenant scoping on file access (metadata must contain tenantId)

### 7.7.6 Analytics and Event Integrity

Ensure the data model supports analytics properties:
- `tenantId` everywhere
- plan/status accessible for events
- membership role available when events fire

> **Rule**: Analytics should not require expensive joins or fragile assumptions.

---

## 7.8 ADR Workflow (Mandatory)

### 7.8.1 What is an ADR and Why It Matters

**ADR = short decision record**:
- What we decided
- Why
- Alternatives
- Consequences
- Triggers to revisit

> This prevents "architecture by memory" and onboarding pain.

### 7.8.2 Required ADRs for SaaS MVP

At minimum:
- **ADR-0001**: Tenancy model
- **ADR**: Auth strategy (JWT, sessions, magic links)
- **ADR**: RBAC strategy (fixed roles vs permissions)
- **ADR**: Billing provider + webhook processing approach
- **ADR**: Storage strategy (if uploads)
- **ADR**: Observability baseline (logging/metrics/tracing fields)

---

## 7.9 Deliverables (What Must Exist on Disk)

**Required**:
- `/03-architecture/ADR_0001_Tenancy.md`
- `/03-architecture/Data_Model_v1.md`
- `/03-architecture/Tenant_Isolation_Test_Plan.md`

**Recommended**:
- `/03-architecture/Indexing_Strategy.md`
- `/03-architecture/Data_Retention_Policy.md`

---

## 7.10 Gate (Pass Criteria)

Part 7 is "done" only if:
- [ ] Tenancy model selected + documented + triggers defined
- [ ] Enforcement pattern defined (middleware + authZ + DAL)
- [ ] "No naked queries" rule adopted
- [ ] Baseline SaaS entities included in the model
- [ ] Tenant isolation test plan exists (read/write/join leakage)
- [ ] At least one ADR accepted (tenancy)

---

## 7.11 Templates

### 7.11.1 ADR — Tenancy (Template)

**File**: `/03-architecture/ADR_0001_Tenancy.md`

```markdown
# Title: Tenancy Model Decision

**Status**: Proposed / Accepted / Deprecated

## Context
[Why we need to decide this]

## Decision
[What we chose]

## Options Considered
[List alternatives]

## Pros/Cons
[Analysis of chosen option]

## Consequences
- Security:
- Cost:
- Ops:

## Enforcement Plan
- Middleware:
- DAL:
- Tests:

## Triggers to Revisit
[When to reconsider this decision]
```

### 7.11.2 Data Model v1 (Template)

**File**: `/03-architecture/Data_Model_v1.md`

For each entity:

| Field | Description |
|-------|-------------|
| Name / Purpose | |
| Tenant scope | (tenant-scoped? global?) |
| Keys | (PK, unique constraints) |
| Fields | (core fields only) |
| Relationships | |
| Indexes | |
| Lifecycle states | (if applicable) |
| Access rules | (RBAC + tenant constraints) |

### 7.11.3 Tenant Isolation Test Plan (Template)

**File**: `/03-architecture/Tenant_Isolation_Test_Plan.md`

```markdown
## Read Isolation Tests
- [ ] Test case 1
- [ ] Test case 2

## Write Isolation Tests
- [ ] Test case 1
- [ ] Test case 2

## Join Leakage Tests
- [ ] Test case 1
- [ ] Test case 2

## Role Change Tests
- [ ] Test case 1
- [ ] Test case 2

## Membership Removal Tests
- [ ] Test case 1
- [ ] Test case 2

## Boundary Behavior
- 404 vs 403 policy: [define]
```
