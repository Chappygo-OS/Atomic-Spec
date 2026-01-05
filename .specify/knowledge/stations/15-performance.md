# Station 15 — Performance + Scalability Basics

> Fast UX, Predictable Costs, Safe Growth

## 15.1 Objective

Design performance and scalability so you can:

- Keep UX consistently fast under real load (not just in dev)
- Prevent multi-tenant "noisy neighbor" issues
- Control cost-to-serve as usage grows (especially for AI/exports)
- Scale safely with predictable operational patterns (queues, caching, indexes, limits)
- Avoid premature complexity while still being enterprise-extensible

> **Performance is a system property:** DB, API design, queues, caches, external dependencies, and limits all interact.

## 15.2 Performance Targets (Make Them Measurable and Actionable)

### 15.2.1 Define Targets by Surface

**API:**

- p50, p95, p99 latency per route group (read/write/expensive)
- Error rates by group (2xx/4xx/5xx)
- Timeouts to external providers (Stripe, AI)

**Frontend:**

- Initial page load performance (core pages)
- List render time (first content)
- Interaction latency (creating/editing core entities)

**Async:**

- Queue wait time p95 by job type
- Job runtime p95 by job type
- Job failure rate and retry rate

### 15.2.2 Example MVP Targets (Adjust to Your Product)

| Metric | Target |
|--------|--------|
| Core reads | p95 < 400ms, p99 < 1500ms |
| Core writes | p95 < 800ms, p99 < 2000ms |
| Expensive endpoints (exports) | Return jobId in < 500ms |
| Job queue wait | p95 < 2 min (or define a realistic bound) |
| "Activation loop" (upgrade -> active) | Reflects webhook latency + polling design |

> **Rule:** If you don't have p95/p99 targets, you can't detect regressions.

## 15.3 Multi-Tenant Performance Risk Model ("Noisy Neighbor")

### 15.3.1 Noisy Neighbor Vectors

- High-cardinality list queries with weak indexes
- Abusive export usage / AI calls
- Repeated polling by many users
- Large payloads and heavy serialization
- Expensive joins across large tenant datasets
- Queue starvation (one tenant floods jobs)

### 15.3.2 Required Controls (Tie to Earlier Parts)

| Control | Reference |
|---------|-----------|
| Per-tenant quotas | Part 10 |
| Per-tenant rate limits | Part 10 + Part 13 |
| Tenant-scoped caching keys | |
| Tenant-aware job scheduling or fairness | See 15.7 |
| Strict pagination and bounded queries | See 15.4 |
| Observability by tenant | Part 11 |

> **Rule:** Every "expensive" feature must declare its noisy-neighbor mitigation.

## 15.4 Database Performance (Most SaaS Bottlenecks Live Here)

### 15.4.1 Query Contract Rules (Standardize These)

- Every query must include tenantId filter (and tenantId is indexed)
- No unbounded list endpoints (always paginate)
- Avoid deep offsets for large lists; prefer cursor-based pagination
- Prefer explicit selected columns over `SELECT *` for large tables
- Cap "include relations" depth (avoid accidental join explosions)
- Avoid per-row queries (N+1); use batching

### 15.4.2 Pagination Strategy (Define One)

**Cursor Pagination (Recommended):**

- Stable, performant at scale
- Requires ordering key (createdAt + id or monotonically increasing id)

**Offset Pagination (MVP Acceptable for Small Datasets):**

- Simple but degrades badly at scale
- Must still have max page size caps

> **Rule:** Define default limit max (e.g., 50/100) and enforce server-side.

### 15.4.3 Indexing Patterns (Tenant-First)

Start with predictable indexes:

| Use Case | Index Pattern |
|----------|---------------|
| Lists by time | `(tenant_id, created_at DESC, id)` |
| Active states | `(tenant_id, status, updated_at DESC)` |
| Ownership filters | `(tenant_id, owner_id, created_at DESC)` |
| Uniqueness constraints | `unique(tenant_id, slug)` or `unique(tenant_id, external_id)` |

**Index Hygiene:**

- Add indexes as part of feature delivery (definition of done)
- Monitor slow queries (Part 11) and add indexes based on evidence
- Avoid over-indexing early; indexes slow writes and increase storage

### 15.4.4 Transaction and Lock Discipline

- Keep transactions short
- Avoid "read-modify-write" loops without atomic ops
- Use optimistic concurrency where appropriate
- Be careful with bulk updates/deletes (batch them)

> **Rule:** Lock contention is a stealth performance killer.

### 15.4.5 Connection Pool Discipline

- Set pool size intentionally (per instance)
- Ensure workers have separate pools if needed
- Prevent "one request uses many connections"
- Alert on pool saturation (Part 11)

> **Rule:** DB connection exhaustion causes cascading failure fast.

## 15.5 Caching (High ROI, Low Risk)

### 15.5.1 Caching Goals

- Reduce repeated reads (especially config/entitlements/permissions)
- Reduce load from polling
- Reduce external API calls
- Accelerate repeated derived computations (exports, AI results) where allowed

### 15.5.2 What to Cache First (MVP-Safe)

- Tenant entitlements and billing status summary (short TTL)
- RBAC permission sets (short TTL + invalidation on role change)
- Feature flags config
- "Read models" for dashboards (precomputed aggregates)

### 15.5.3 What to Avoid Caching Early (Risk)

- Anything that can violate access revocation (permissions) if TTL too long
- Core entities with frequent edits unless you implement invalidation correctly
- Any cached object without tenantId in the cache key

### 15.5.4 Cache Invalidation Rules (Explicit)

Define invalidation triggers:

| Event | Invalidation |
|-------|--------------|
| Plan change | Invalidate entitlement cache |
| Role change | Invalidate permission cache |
| Tenant suspension | Invalidate everything |
| Entity update/delete | Invalidate derived views only |

> **Rule:** Cache keys must include tenantId; otherwise you risk cross-tenant leakage.

## 15.6 Async Work and Job Architecture (The Performance Lever)

### 15.6.1 What Belongs in Async Jobs

- Exports (PDF/video)
- AI processing / embeddings
- Imports / backfills
- Large recalculations (analytics aggregation)
- Webhook-heavy operations (if you need durable processing)

### 15.6.2 Job UX Contract

- Request returns quickly with jobId
- Job has states: queued, running, succeeded, failed, blocked
- Provide progress if possible (optional)
- Result artifacts stored and retrievable

> **Rule:** Users should never wait on a long request if you can queue it.

### 15.6.3 Job Correctness Constraints

- **Idempotency:** Job must be safe to retry
- **Deduplication:** Repeated requests shouldn't create repeated compute unless desired
- **Worker must re-check:**
  - Billing state (Part 9)
  - Usage limits (Part 10)
  - Tenant scope and permissions (Part 8/7)

> **Rule:** Retries are normal; your design must assume retries.

## 15.7 Rate Limiting + Fairness + Backpressure (Stability Tools)

### 15.7.1 Rate Limiting Layers

| Layer | Scope |
|-------|-------|
| Edge/API gateway | Coarse |
| Application-level | Fine-grained, action-specific |
| Per-tenant limits | Protect multi-tenant fairness |

### 15.7.2 Fairness Strategies for Queues (Avoid Tenant Starvation)

MVP options (in increasing complexity):

1. Separate queues by job type (exports vs AI)
2. Per-tenant concurrency caps (max N running jobs per tenant)
3. Priority tiers by plan (pro vs free)
4. Weighted fair scheduling (later)

> **Rule:** You don't need perfect fairness; you need to avoid one tenant taking all capacity.

### 15.7.3 Backpressure Patterns (What You Return)

| Response | Meaning |
|----------|---------|
| 429 + Retry-After | Rate limit hit |
| "queued" response | Async work accepted |
| Degrade (optional) | Smaller output, lower quality, delayed processing |

> **Rule:** Backpressure is better than timeouts.

## 15.8 External Dependencies (Stripe, AI Providers) — Performance and Resilience

### 15.8.1 Client Rules for External APIs

- Strict timeouts
- Bounded retries with jitter
- Circuit breaker (even simple)
- Bulkhead separation (don't let one dependency crash everything)

> **Rule:** External dependency slowness must not take down your entire SaaS.

## 15.9 Cost-to-Serve (Unit Economics) — Connect to Performance

Performance work should reduce cost too:

- Cache or deduplicate expensive operations (exports, AI)
- Store artifacts (generated PDFs) rather than recompute
- Control usage via quotas/limits (Part 10)
- Identify top cost drivers by tenant (Part 11 dashboards)

### 15.9.1 Practical Cost Controls for AI-Heavy SaaS

- Token budgeting per request
- Prompt/result caching where safe
- Store intermediate results (embeddings, summaries)
- Batch operations where possible

> **Rule:** If AI calls dominate cost, "performance" includes cost profiling.

## 15.10 Load Testing and Capacity Planning (MVP-Friendly but Real)

### 15.10.1 Define Representative Scenarios (Must Be Tenant-Aware)

At minimum:

1. Login -> list core entities
2. Create core entity -> refresh list
3. Trigger export/AI job -> poll status -> download result
4. Billing: upgrade flow check (non-payment path in staging)

### 15.10.2 What to Measure During Load Tests

- p95 latency by route
- Error rates by type
- DB pool saturation, slow queries
- Queue depth and job runtimes
- External API latency (stub or real staging)

### 15.10.3 Regression Policy

- Run a small load test on staging before major releases
- Compare to baseline metrics
- Block release if core p95 regresses beyond threshold

> **Rule:** You don't need massive load testing; you need to prevent surprises.

## 15.11 Deliverables (Must Exist)

- `Performance_Targets.md` (p95/p99 targets + measurement)
- `Query_and_Pagination_Contract.md` (rules, max limits, cursor strategy)
- `Indexing_Strategy.md` (initial indexes + how to add new)
- `Caching_Policy.md` (what/TTL/invalidation)
- `Async_Jobs_Catalog.md` (job types + SLAs + idempotency rules)
- `Rate_Limit_and_Fairness.md` (per-tenant caps + queue strategy)
- `Load_Test_Scenarios.md` (scripts + baseline expectations)
