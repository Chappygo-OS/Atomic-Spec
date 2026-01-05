# Station 13 — Security Baseline + AppSec Workflow

> Controls, Processes, and "No-Regret" Defaults

## 13.1 Objective

Establish a security baseline and AppSec workflow that:

- Prevents the most common SaaS vulnerabilities (OWASP class issues)
- Guarantees tenant isolation as a first-class invariant
- Minimizes breach blast radius (least privilege, segmentation, scoped tokens)
- Makes security a continuous engineering workflow (PR gates, automation, runbooks)
- Supports "enterprise-ready" requirements later without redesign (SSO, audit, data controls)

**Operational target:** when something suspicious happens, you can answer:
- What happened?
- Who?
- Which tenant?
- What data?

...within minutes.

## 13.2 Threat Model (MVP Version You Can Actually Maintain)

### 13.2.1 Assets to Protect

Rank assets by impact:

| Priority | Asset |
|----------|-------|
| 1 | Tenant data (core domain entities, files, exports) |
| 2 | Identity (accounts, sessions, resets, invites) |
| 3 | Billing (Stripe customer/subscription integrity) |
| 4 | Secrets (API keys, webhook secrets, session signing keys) |
| 5 | Operational integrity (jobs, queues, admin tooling) |

### 13.2.2 Primary Attacker Goals

- Cross-tenant access (read/write)
- Account takeover
- Privilege escalation (become Admin)
- Fraud / billing manipulation
- Data exfiltration through exports or file links
- Disruption (DoS via expensive operations)

### 13.2.3 Entry Points (Typical SaaS)

- Login/reset/magic-link endpoints
- Invite endpoints
- API endpoints (especially list + export)
- File upload/download and signed URLs
- Stripe webhooks and portal session endpoints
- Admin/support tooling
- CI/CD pipeline and secrets store

### 13.2.4 MVP Threat Ranking (Recommended)

Focus on top 6 threats for MVP:

| Rank | Threat |
|------|--------|
| 1 | Tenant isolation failure (cross-tenant leak) |
| 2 | Credential stuffing / account takeover |
| 3 | RBAC bypass (missing authZ checks) |
| 4 | Webhook spoofing / event replay |
| 5 | Export abuse (exfiltration) + signed URL leakage |
| 6 | Supply-chain / secret leakage (CI or repo) |

> **Rule:** "Threat model" is a living doc with 10-20 bullets, not a 40-page report.

## 13.3 Security Ownership + Governance (Lightweight, Real)

| Role | Responsibility |
|------|----------------|
| **Accountable** | Tech Lead (final call on security gates) |
| **Reviewer role** | Someone must be designated to review "sensitive PRs" |

**Sensitive PR definition:** any change touching:

- Auth/authZ/RBAC
- Tenant scoping / DAL
- Billing/webhooks
- Exports/files
- Admin tooling
- Secrets/config

> **Rule:** Sensitive PRs require an explicit "security checklist" in the PR description.

## 13.4 Baseline Security Controls (MVP Non-Negotiables)

### 13.4.1 Identity + Session Safety

**Controls:**

- Rate limit login + reset + magic link + invite endpoints
- Prevent account enumeration (same response for "email exists" vs not)
- Session invalidation on password change and role change
- Short-lived reset/magic/invite tokens, single-use, stored hashed
- Optional: require email verification before granting membership (product decision)

**Defaults:**

| Endpoint | Rate Limit Strategy |
|----------|---------------------|
| Login | Per IP + per email (two dimensions) |
| Reset/magic link | Cooldown and daily caps |
| Invite creation | Per tenant cap + per admin cap |

### 13.4.2 Authorization Invariants (Tenant Isolation is the Invariant)

**Invariants:**

- Every request is evaluated under a tenant context
- Every DB access is tenant-scoped ("no naked queries")
- Every privileged action has a permission check + audit log

**Concrete Enforcement:**

- Central `authorize(principal, action, resource)` (Part 8)
- DAL/repository requires tenantId or resolves tenant safely
- Test suite includes join leakage tests (Part 7)

> **Rule:** Tenant isolation failures are SEV1 security incidents.

### 13.4.3 Web Security Hardening (Browser SaaS)

**Mandatory:**

- HTTPS + HSTS
- Secure cookies (httpOnly, secure, sameSite)
- CSRF protection for cookie auth (token or double submit)
- CSP baseline (start strict, loosen only when required)
- CORS: explicit allowlist of origins, no wildcard in prod

**Recommended Headers:**

| Header | Value |
|--------|-------|
| Referrer-Policy | strict-origin-when-cross-origin |
| X-Content-Type-Options | nosniff |
| Permissions-Policy | minimal |
| frame-ancestors (CSP) | Prevent clickjacking |

> **Rule:** Any rich-text user input requires an explicit sanitization policy.

### 13.4.4 API Security Patterns (Practical)

- Schema validation on inputs (request DTO schema)
- Strict request size limits (body size, file size)
- Consistent error envelope (Part 6) - avoid leaking internals
- Idempotency keys for side-effect endpoints (Part 6)
- Per-route rate limiting for expensive routes (exports/AI jobs)

> **Rule:** Expensive endpoints must have both rate limits and usage limits (Part 10).

### 13.4.5 Data Security + Privacy Basics

- Encryption at rest (managed DB) + encrypted backups
- Least privilege DB credentials (separate for app vs migrations if possible)
- PII classification + retention (Part 7)
- Audit logs stored separately from operational logs if needed later
- Protect "exported data" as high risk (watermarking later)

> **Rule:** "Export" is a sensitive action: always permission check + audit.

### 13.4.6 Stripe Security (Tight Integration Rules)

**Webhook Endpoint:**

- Signature verification mandatory
- Event ledger + idempotency (Part 9)
- Reject unknown customers (no tenant mapping) with alerting, not silent failure
- Do not process events without resolved tenantId

**Portal Session Endpoint:**

- Admin-only
- Logs must include tenantId + actorUserId
- No caching of portal URLs beyond TTL

> **Rule:** All billing state transitions must be traceable (audit + event ledger).

### 13.4.7 Storage + File Security (If Uploads Exist)

**Controls:**

- Private buckets by default
- Signed URLs short TTL (minutes)
- Tenant-scoped authorization check before issuing signed URL
- Content-type validation + size limits
- Malware scanning if uploads are public-facing (recommended)

**Common Pitfalls:**

- Exposing object keys publicly
- Long-lived signed URLs shared across tenants
- Missing authorization checks on download endpoints

### 13.4.8 Anti-Abuse Controls (Often Forgotten)

- Throttling on expensive endpoints (AI jobs, exports)
- Per-tenant quotas (Part 10)
- Anomaly detection signals:
  - Spikes in export volume
  - Spikes in failed logins
  - Spikes in cross-tenant 404s on resources (probing)
  - Spikes in 403s (privilege escalation attempts)

> **Rule:** Abuse prevention is part of security, not "growth."

## 13.5 Secure Development Workflow (AppSec as Part of Engineering)

### 13.5.1 Security Gates in CI (Minimum)

- Dependency vulnerability scanning (block critical/high)
- Secret scanning (block merges if detected)
- Lint/type/unit tests
- OpenAPI schema validation (Part 6)
- Optional: SAST baseline (lightweight)

> **Rule:** Failing security checks blocks merge.

### 13.5.2 PR Security Checklist (Operational)

Every PR that adds/modifies an endpoint must answer:

- What tenant scope applies?
- What permission is required?
- Is this action audited?
- Can this be abused (rate/usage limits)?
- What error codes can be returned?

**Endpoint Checklist (Expanded):**

| Question | Answer Required |
|----------|-----------------|
| Auth required (or explicitly public)? | Yes/No |
| Tenant context derived/validated? | Yes/No |
| RBAC permission check (which action string)? | Action name |
| Input schema validation added? | Yes/No |
| Rate limiting configured if sensitive/expensive? | Yes/No/NA |
| Usage meter impact considered (Part 10)? | Yes/No |
| Audit logging added if sensitive? | Yes/No/NA |
| Idempotency keys used if retryable side effects? | Yes/No/NA |
| Tests include cross-tenant access attempt? | Yes/No |

### 13.5.3 "Security-Sensitive Change" Review Protocol

Sensitive PRs require:

- One additional reviewer
- Mandatory test plan notes
- Explicit "threat surface changed?" section

### 13.5.4 Secrets Management Workflow (Repeatable)

- Secrets live in secret manager
- Env vars validated at boot
- Rotation plan (Stripe webhook secret, session/JWT keys)
- Local dev uses `.env.local` excluded from repo
- Periodic scans for leaked secrets in git history (schedule)

> **Rule:** Treat secrets rotation as a normal operational task.

## 13.6 Vulnerability Management (Simple, Strict)

Define SLA by severity:

| Severity | Response |
|----------|----------|
| Critical | Fix immediately, block release |
| High | Fix within 7 days |
| Medium | Fix within 30 days |
| Low | Backlog, review quarterly |

Additional requirements:

- Weekly dependency update window
- Security advisory monitoring (automated if possible)

## 13.7 Security Incident Response (SaaS-Ready)

### 13.7.1 Detection Signals (Alerts)

- Spike in login failures (credential stuffing)
- Spike in password reset requests
- Spike in tenant mismatch / cross-tenant resource probes
- Webhook signature failures spike
- Abnormal export volume by tenant
- Sudden RBAC deny spikes on admin actions

> **Rule:** Security detection relies on Part 11 observability.

### 13.7.2 Containment Controls You Must Have

- Suspend user
- Suspend tenant
- Revoke sessions
- Rotate secrets (webhook/session keys)
- Disable risky features via flags (Part 12)

> **Rule:** Containment must be executable without deploying code (flags/admin actions).

### 13.7.3 Post-Incident Requirements

- Timeline
- Blast radius analysis (which tenant(s), which data)
- Root cause + contributing factors
- Remediation items with owners and deadlines
- Add a test/alert to prevent recurrence

## 13.8 SaaS Enterprise Readiness (Design Now, Ship Later)

Design with future requirements in mind:

- Audit logs accessible to tenant admins
- Role model compatible with SSO mapping later
- Data export controls (per-role, per-tenant)
- Secure admin tooling boundary
- Documented security baseline for questionnaires

## 13.9 Deliverables (Must Exist)

- `Threat_Model_MVP.md`
- `Security_Baseline_Checklist.md`
- `PR_Security_Checklists.md`
- `Secrets_Management_Policy.md`
- `Vulnerability_Management_Policy.md`
- `Security_Incident_Runbook.md`

## 13.10 Templates

### 13.10.1 Security Baseline Checklist (Starter)

| Area | Controls |
|------|----------|
| Identity | Rate limits, enumeration protection, token TTL rules |
| AuthZ | Deny-by-default, tenant scoping, audited sensitive actions |
| Web | Cookies/CSRF/CSP/CORS/headers |
| API | Schema validation, size limits, idempotency |
| Billing | Webhook signature + ledger + idempotency |
| Storage | Private by default + short-lived signed URLs |
| CI | Secret scan + vuln scan + tests |

### 13.10.2 Sensitive PR Section (Add to PR Template)

```markdown
## Security Checklist

- **Tenant scope:**
- **Permission required:**
- **Abuse vectors + mitigations:**
- **Audit event added:**
- **Tests added:**
```
