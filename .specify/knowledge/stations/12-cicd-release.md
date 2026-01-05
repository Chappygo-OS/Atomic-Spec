# Station 12 — Environments + CI/CD + Release Discipline (SaaS)

> Reliable Shipping Without Chaos

---

## 12.1 Objective

Set up environments and a release pipeline that:

- Enables fast iteration without breaking production
- Makes deployments repeatable and reversible
- Reduces "works on my machine" issues
- Enforces quality gates (tests, security checks, schema checks)
- Supports SaaS realities: migrations, feature flags, gradual rollout

---

## 12.2 Environments

### 12.2.1 Minimum Environment Set

| Environment | Description |
|-------------|-------------|
| Local | Developer machine |
| Dev | Shared integration for the team |
| Staging | Prod-like for final validation |
| Prod | Real users |

> **Rule**: Staging must be as close to prod as possible (infra, config, auth, webhooks).

### 12.2.2 Data Strategy Per Environment

| Environment | Data Strategy |
|-------------|---------------|
| Local | Synthetic + seed scripts |
| Dev | Synthetic + shared fixtures (resettable) |
| Staging | Anonymized or synthetic (avoid real PII) |
| Prod | Real data with backups + retention policy |

> **Rule**: Never use production data in dev/staging unless anonymized and approved.

### 12.2.3 Environment Configuration Discipline

Use a single config system with:
- Required env vars validated at startup
- Explicit config per environment
- Secret management (no secrets in repo)

**Non-negotiable**:
- Separate Stripe keys + webhook secrets per environment
- Separate OAuth credentials per environment
- Separate storage buckets per environment

---

## 12.3 CI Pipeline (Quality Gates)

### 12.3.1 What Runs on Every PR

- [ ] lint/format
- [ ] type checks
- [ ] unit tests
- [ ] API contract checks (OpenAPI schema validation)
- [ ] security scanning (dependencies)
- [ ] build (to catch compilation issues)

> **Rule**: PRs should not merge if CI is red.

### 12.3.2 What Runs on Main Branch / Nightly

- [ ] integration tests (DB + API)
- [ ] migration tests (apply + rollback if supported)
- [ ] end-to-end smoke tests (core flows)
- [ ] performance sanity checks (basic)

---

## 12.4 CD Pipeline (Deployments)

### 12.4.1 Deployment Triggers

**Typical approach**:
- Merge to main deploys to dev
- Tagged release deploys to staging
- Promotion from staging deploys to prod

**Alternative**: Trunk-based with progressive delivery (fine, but needs strong flags/rollbacks).

### 12.4.2 Progressive Delivery (Strongly Recommended)

Use at least one:
- Feature flags
- Percentage rollout
- Tenant-based rollout (enable for internal tenants first)

> **Rule**: Large changes ship dark, then activate.

### 12.4.3 Rollback Strategy (Non-Negotiable)

You must be able to roll back:
- App code quickly
- Config safely
- Feature flags instantly

> **Rule**: Schema changes must be backward-compatible to allow code rollback.

---

## 12.5 Database Migrations (Where Releases Fail)

### 12.5.1 The "Expand/Contract" Pattern (Recommended)

To avoid breaking deploys:

1. **Expand**: Add new columns/tables without removing old
2. Deploy code that writes both or reads new with fallback
3. Backfill data (async job)
4. Switch reads fully to new
5. **Contract**: Remove old columns later (separate release)

> **Rule**: Never do destructive migrations in the same release as a big code change.

### 12.5.2 Migration Gates

Before prod deploy:
- [ ] Migration runs successfully on staging with prod-like data volume
- [ ] Rollback plan exists (even if "forward fix" only)

> **Rule**: Test migrations like you test code.

---

## 12.6 Testing Strategy Aligned to Releases

### 12.6.1 Test Pyramid (Practical)

| Layer | Focus |
|-------|-------|
| Unit tests | Domain logic, policy engine (RBAC), billing mapping |
| Integration tests | DB + API endpoints |
| E2E smoke tests | Login, core wedge, upgrade, limit block |

> **Rule**: Automate smoke tests for top 3 flows.

---

## 12.7 Release Checklist (Repeatable)

Every release must have:

- [ ] Version/tag
- [ ] Changelog (internal)
- [ ] Migration plan (if any)
- [ ] Feature flags list + default states
- [ ] Monitoring plan (dashboards/alerts to watch)
- [ ] Rollback plan (code + flags)

---

## 12.8 Observability Hooks in the Pipeline

- Deployment marker events (so graphs show deploy times)
- Post-deploy checks:
  - Error rate
  - p95 latency
  - Webhook processing health
  - Queue depth

> **Rule**: If post-deploy health fails, auto-rollback or pause rollout.

---

## 12.9 SaaS-Specific Pitfalls + Fixes

| Pitfall | Fix |
|---------|-----|
| Staging not prod-like -> surprises in prod | Mirror auth/webhooks/storage configs and sizes |
| Breaking migrations block rollback | Expand/contract + backward-compatible releases |
| No gradual rollout -> big-bang outages | Tenant-based rollout + flags |
| Secrets drift across envs | Centralized secret manager + validation at boot |

---

## 12.10 Deliverables (What Must Exist)

- `Environments_Spec.md`
- `CI_Pipeline_Spec.md`
- `CD_Release_Process.md`
- `Migration_Playbook.md`
- `Release_Checklist.md`
- `Feature_Flags_Policy.md`
