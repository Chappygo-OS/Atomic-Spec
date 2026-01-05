# Station 11 — Observability + Incident Readiness (SaaS)

> Logging, Metrics, Tracing, and Runbooks

---

## 11.1 Objective

Build observability so you can:

- Detect issues before users report them
- Debug production problems quickly (minutes, not hours)
- Prove tenant isolation and explain billing/limit decisions
- Reduce support load with self-serve diagnostics
- Run incidents with clear ownership and repeatable playbooks

> **Rule**: If you can't observe it, you can't operate it.

---

## 11.2 Scope

### 11.2.1 MVP (Non-Negotiable Baseline)

- Structured logs with correlation (requestId)
- Tenant-aware logging (tenantId, userId)
- Core metrics (HTTP, jobs, DB, webhooks)
- Alerts for high-severity conditions
- Minimal tracing (even if just request timing breakdown)
- Incident runbooks for top failure modes
- Dashboards for product-critical flows (auth, billing, limits)

### 11.2.2 Later

- Distributed tracing across services
- SLOs/SLIs with error budgets
- Advanced anomaly detection
- Per-tenant performance and cost attribution

---

## 11.3 Observability Design Principles

- One request -> one requestId everywhere (API, jobs, webhooks)
- Tenant context everywhere (tenantId is required in logs/traces)
- Stable error codes are first-class dimensions (from Part 6)
- Measure the business-critical paths (activation, core wedge, billing, limits)
- Dashboards before incidents (you don't build them during outages)

---

## 11.4 Logging Standards (Structured, Searchable)

### 11.4.1 Log Format (Structured JSON)

Every log line should include:

| Field | Description |
|-------|-------------|
| timestamp | When the event occurred |
| level | Log level (info, warn, error) |
| message | Human-readable description |
| requestId | Correlation ID |
| tenantId | Nullable only if truly unknown |
| userId | Nullable |
| route / endpoint | Which endpoint |
| method | HTTP method |
| statusCode | Response code |
| latencyMs | Request duration |
| error.code | When applicable |
| environment | prod/stage/dev |
| service | If multiple services |

> **Rule**: Never rely on free-text logs for production debugging.

### 11.4.2 PII and Secrets Logging Policy

- Never log passwords, tokens, raw webhook payload secrets
- Avoid storing full request/response bodies in logs
- If you must log payload fields, whitelist safe fields only
- Mask emails if your policy requires it

> **Rule**: Logs are a liability if you leak sensitive data.

### 11.4.3 Required Log Events (MVP)

| Event | Notes |
|-------|-------|
| auth: login attempt/success/failure | without sensitive data |
| RBAC denies | action + role + error code |
| tenant mismatch attempts | security signal |
| billing webhooks received/processed/failed | |
| usage limit warnings and blocks | |
| background job start/success/fail | |
| external API calls (Stripe, AI provider) | latency + status + retries |
| DB query slow logs | threshold-based |

---

## 11.5 Metrics (What You Must Measure)

### 11.5.1 HTTP/API Metrics

| Metric | Description |
|--------|-------------|
| request count | by route + status code |
| p50/p95/p99 latency | by route |
| error rate | by route |
| 401/403/404/429 rate | security and UX signals |

**Dimensions (tags)**:
- route
- statusCode
- error.code (if present)
- tenantTier (optional: planId)

### 11.5.2 Job/Queue Metrics (If You Have Async Work)

| Metric | Description |
|--------|-------------|
| job enqueue rate | |
| queue depth | |
| job duration p95 | |
| job failure rate | |
| retry rate | |

**Dimensions**:
- jobType
- error.code

### 11.5.3 Billing Metrics (Stripe)

| Metric | Description |
|--------|-------------|
| webhook receive rate | |
| webhook processing failure rate | |
| reconciliation drift count | |
| tenants in past_due / restricted | |
| checkout conversion funnel | |

### 11.5.4 Limits/Metering Metrics

| Metric | Description |
|--------|-------------|
| warnings emitted per meter | |
| blocks per meter | |
| top tenants by usage | sampled |
| "blocked action" counts by endpoint | |

### 11.5.5 Database Metrics (Minimum)

| Metric | Description |
|--------|-------------|
| connection pool saturation | |
| query latency (p95) | |
| slow query count | |
| CPU/memory/disk utilization | |
| lock contention | if applicable |

---

## 11.6 Tracing (MVP-Friendly)

Even if you don't have full distributed tracing, you can capture:

**Request timing breakdown**:
- Auth middleware
- DB time
- External API time (Stripe, LLM)
- Serialization time

**Correlation across**:
- request -> job -> webhook processing (via requestId/jobId)

> **Rule**: Tracing should help answer "where did the time go?" quickly.

---

## 11.7 Alerting (What Wakes You Up)

### 11.7.1 Severity Levels

| Level | Description |
|-------|-------------|
| SEV1 | System down / major revenue impact / security incident |
| SEV2 | Partial outage / degraded performance affecting many |
| SEV3 | Localized issue / elevated errors |

### 11.7.2 MVP Alert Conditions (Recommended)

**SEV1 examples**:
- API error rate > X% for Y minutes on core routes
- p95 latency > threshold on core routes
- Stripe webhook failures sustained
- DB connections exhausted
- Authentication failures spike (possible attack)
- Tenant isolation anomaly detected (cross-tenant access attempts spike)

**SEV2 examples**:
- Queue depth growing + job failures rising
- Increased 429 rates (throttling too aggressive or abuse)
- Billing drift increasing (reconciliation fixing too much)

---

## 11.8 Incident Readiness (Process + Runbooks)

### 11.8.1 Required Runbooks (MVP)

| Runbook | Description |
|---------|-------------|
| Auth outage / login failures | |
| Stripe webhook failures | |
| Users locked after payment | |
| Usage limit blocking unexpectedly | |
| Database performance degradation | |
| Suspected tenant data leakage | security incident |

**Each runbook must include**:
- Symptoms
- Dashboards/queries to check
- Likely causes
- Immediate mitigations
- How to communicate status
- How to verify resolution
- Post-incident follow-up checklist

### 11.8.2 Post-Incident Review (Lightweight)

For any SEV1/SEV2:
- Timeline
- Root cause
- Contributing factors
- Action items with owners + deadlines
- "How we detect earlier next time"

---

## 11.9 Support-Facing Diagnostics (Optional But High Leverage)

Add an internal admin/support view:
- Tenant billing status + last Stripe events
- Usage per meter + reset time + last usage events
- Recent errors by tenantId (sampled)
- Last login attempts (limited visibility)

> **Rule**: This reduces support time drastically if done safely.

---

## 11.10 Deliverables (What Must Exist)

- `Logging_Standard.md` (fields + PII rules)
- `Metrics_Catalog.md` (what metrics exist, tags, thresholds)
- `Dashboards_List.md` (links + owners)
- `Alert_Policy.md` (SEV levels + triggers)
- `Runbooks/` folder with MVP runbooks

---

## 11.11 Templates

### 11.11.1 Log Event Example

```json
{
  "timestamp": "2026-01-02T10:15:30Z",
  "level": "error",
  "message": "Stripe webhook processing failed",
  "requestId": "req_123",
  "tenantId": "tnt_456",
  "userId": null,
  "route": "/webhooks/stripe",
  "method": "POST",
  "statusCode": 200,
  "latencyMs": 42,
  "error": { "code": "WEBHOOK_PROCESSING_FAILED" },
  "service": "api",
  "environment": "prod"
}
```

### 11.11.2 Runbook Skeleton

```markdown
# Title

## Symptoms
- [What alerts fire]
- [What users report]

## Immediate Checks
- [ ] Dashboard: [link]
- [ ] Log query: [query]

## Likely Causes
1. [Cause 1]
2. [Cause 2]

## Mitigation Steps
1. [Step 1]
2. [Step 2]

## Verification
- [ ] [How to confirm resolution]

## Communication Template
> [Status message template]

## Follow-ups
- [ ] [Post-incident action]
```
