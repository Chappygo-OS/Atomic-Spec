# Station 08 — Authentication + RBAC (SaaS)

> Patterns, Pitfalls, and Checklists

---

## 8.1 Objective

Design authentication (AuthN) and authorization (AuthZ) so they are:

- **Secure by default**: least privilege, server-enforced, no UI-only security
- **Tenant-aware**: membership + tenant context propagation on every request
- **Product-consistent**: clear UX states for forbidden, billing, limits
- **Operable**: auditable, observable, resilient to retries/abuse
- **Extensible**: can evolve to SSO/SAML/SCIM without rewriting fundamentals

> **Deliverable goal**: A minimal, repeatable "auth platform" you can reuse across products.

---

## 8.2 Scope and Sequencing

### 8.2.1 MVP Baseline (Recommended for B2B SaaS)

- AuthN: email login (password or magic link) + optional OAuth (Google)
- Session/JWT strategy + refresh/revocation plan
- Tenant membership resolution (user <-> tenant)
- RBAC with fixed roles (Admin/Member, optionally Viewer)
- Access restrictions beyond RBAC: billing/limits/suspension
- Rate limiting + anti-abuse for auth endpoints
- Audit logs for sensitive actions
- Security tests for tenant isolation + RBAC

### 8.2.2 Later (Enterprise)

- SSO/SAML, SCIM provisioning
- Fine-grained permissions (ABAC / custom roles)
- Conditional access, device posture
- Org-level security settings (2FA enforcement, IP allowlists)

> **Rule**: Do not start with enterprise features. Start with correct fundamentals.

---

## 8.3 Required ADRs

Create ADRs for:

| Decision | Options |
|----------|---------|
| Auth transport | cookie-based sessions vs JWT access + refresh |
| Login methods | password vs magic link vs OAuth (or combination) |
| Tenant context strategy | explicit tenant in route vs derived from session + resource lookup |
| RBAC strategy | fixed roles vs roles+permissions |
| Token/session lifecycle | expiry, refresh rotation, revocation strategy |
| Account lifecycle | invited/pending, active, suspended, removed |
| Audit + retention | what you log, how long, who can view it |

---

## 8.4 Authentication (AuthN)

### 8.4.1 Sessions vs JWT — Decision Guide

#### Option A — Cookie-Based Sessions (Typical Web SaaS Default)

**How it works**: Backend sets an httpOnly session cookie; session state stored server-side (DB/Redis).

**Pros**:
- Strong browser security posture (httpOnly, secure cookies)
- Easier revocation (delete session)
- Simpler mental model for web apps

**Cons**:
- Needs CSRF protection
- Multi-region/session store adds ops complexity if you scale globally
- Native/mobile clients require extra handling

**Best for**:
- Web-first SaaS (Next.js, React SPA + API)
- Teams wanting simple revocation

#### Option B — JWT Access Tokens + Refresh Tokens

**How it works**: Short-lived access token + longer-lived refresh token; refresh rotates.

**Pros**:
- Works well across web/mobile/desktop
- Stateless request auth validation (for access tokens)

**Cons**:
- Revocation is harder (requires deny list / token versioning)
- Storage mistakes are common (XSS risk)

**Best for**:
- Multiple client types early
- APIs exposed to third parties

#### Practical MVP Recommendation

- If web-only: cookie session is usually safest/easiest
- If web + extension + mobile: JWT + refresh is often pragmatic

#### Non-Negotiables (Both)

- TLS everywhere
- No secrets in client
- Explicit expiry rules
- Rate limits + abuse prevention

### 8.4.2 Credential Storage (Password-Based Auth)

**Minimum requirements**:
- Hashing: argon2id (preferred) or bcrypt
- Password reset: single-use token, short TTL, rate-limited
- Lockout/throttling on repeated failures
- Avoid account enumeration (same error message for unknown email vs wrong password)

**Policy tips**:
- Don't force crazy password complexity; use length-based guidance
- Consider breach-password checks later (optional)

### 8.4.3 Magic Link Auth (Passwordless)

**Rules**:
- Token single-use, short TTL (10-20 min)
- Store token as hash; never store raw token
- Include tenant selection step if user belongs to multiple tenants
- Resend cooldown + rate limiting to prevent spam

**Edge cases to spec**:
- Link opened on different device/browser
- Token already used
- Token expired
- User clicked link but has no tenant membership yet (invited vs active)

### 8.4.4 OAuth Login (Google/Microsoft)

> OAuth gives identity, not authorization.

**Rules**:
- Treat OAuth email as identity evidence
- Still require membership to tenant
- If no membership exists: show "request access" or invite-only flow
- Log identity provider used (audit + analytics)

---

## 8.5 Account Lifecycle + Tenant Membership

### 8.5.1 Required Data Model (Baseline)

| Entity | Description |
|--------|-------------|
| User | Core user record |
| Tenant | Organization/workspace |
| Membership | (userId, tenantId, role, status) |
| Invite (optional) | (email, tenantId, role, tokenHash, expiresAt, status) |

**Membership statuses (recommended)**:
- `invited` / `pending`
- `active`
- `suspended`
- `removed`

> **Rule**: Access requires an active membership.

### 8.5.2 Tenant Context Selection (UX + System Rules)

You must define:

- **Single-tenant user**: auto-select tenant
- **Multi-tenant user**: show tenant switcher or "choose org"
- **Deep link behavior**: if link points to tenant A, but user last used tenant B:
  - Either auto-switch (with confirmation)
  - Or show an interstitial "Switch organization to continue"

**Security policy**:
- Cross-tenant resource: prefer 404 to avoid leaking existence
- Same-tenant but insufficient role: 403

### 8.5.3 Invite Acceptance and Membership Activation

**Invite flow must specify**:
- Token TTL (e.g., 7 days)
- Token single-use
- Seat limit checks at accept time (not only send time)
- Idempotency (accept should not create duplicate membership)

**Invite states**:
- `sent`
- `accepted`
- `expired`
- `revoked`

> **Rule**: Invite acceptance must create/activate membership in a tenant-safe way and log it.

---

## 8.6 Authorization (AuthZ) and RBAC

### 8.6.1 Start with Fixed Roles (MVP)

**Recommended roles**:
- **Admin**: manage org, members, billing, security settings
- **Member**: core product usage, limited admin
- **Viewer** (optional): read-only (useful if you share outputs)

> **Rule**: Fixed roles avoid an explosion of edge cases.

### 8.6.2 Permission Model (Must Exist)

Define permissions as action strings, grouped by domain:

**Examples**:
- `org.view`, `org.update`
- `member.invite`, `member.remove`, `member.role.change`
- `billing.view`, `billing.update`
- `usage.view`
- `report.create`, `report.update`, `report.delete`, `report.export`

Then map roles -> permissions.

> **Rule**: Permissions should match product surfaces, not endpoints.

### 8.6.3 Policy Engine Pattern (Recommended)

Create a centralized `authorize()` decision that returns:
- allow/deny
- error code (stable)
- optional reason details (for logging)

**Inputs**:
```
principal: { userId, tenantId, role, membershipStatus, planStatus, limitsSnapshot }
action: string
resource (optional): { tenantId, ownerId, status }
```

**Outputs**:
```
decision: { allowed: boolean, code?: string }
```

> **Rule**: Do not scatter RBAC logic across handlers.

### 8.6.4 Enforcement Layers (Defense in Depth)

Authorization must be enforced in:
- **API layer**: endpoint guard
- **Service layer**: business rules and sensitive operations
- **Data layer**: tenant scoping, optional RLS

**Anti-patterns**:
- "Frontend hides admin buttons" as security
- "Check role only in UI"
- "Use userId without verifying tenant membership"

### 8.6.5 401 vs 403 vs 404 (Standard Policy)

| Code | Meaning |
|------|---------|
| 401 | No/invalid auth |
| 403 | Authenticated, correct tenant context, but insufficient permission |
| 404 | Resource not found in this tenant scope (prevents leakage) |

> **Rule**: Document which endpoints return 404 vs 403 for cross-tenant access attempts.

---

## 8.7 Access Restrictions Beyond RBAC

> RBAC is only one gate. In SaaS, access can also be restricted by:

### 8.7.1 Billing State Gating

Define a global gating policy:

| State | Access |
|-------|--------|
| trial active | full access |
| trial ended | block creates? read-only? block everything? |
| payment failed | grace period then restrict |
| canceled | end-of-term vs immediate |

**Return stable error codes**:
- `TRIAL_ENDED`
- `PAYMENT_REQUIRED`
- `ACCOUNT_PAST_DUE`

**UX alignment**:
- Show consistent messaging and CTAs
- Do not "randomly fail" actions without clear reason

### 8.7.2 Limits Gating

**Define**:
- Meters: seats, storage, requests, tokens, projects
- Warn threshold (e.g., 80%)
- Hard limit (100%)
- What gets blocked vs degraded

**Return stable codes**:
- `SEAT_LIMIT_REACHED`
- `USAGE_LIMIT_REACHED`
- `STORAGE_LIMIT_REACHED`

> **Rule**: Enforce limits server-side, not only in UI.

### 8.7.3 Suspension / Compliance Restrictions

**Statuses**:
- Tenant suspended (contract, abuse, compliance): restrict most actions
- User suspended: block login or restrict access

**Codes**:
- `TENANT_SUSPENDED`
- `USER_SUSPENDED`

---

## 8.8 Security Hardening (MVP Checklist)

### 8.8.1 Threats You Explicitly Defend Against

- Credential stuffing / brute force
- Account enumeration
- Token replay (magic links, reset links)
- Invite abuse/spam
- Cross-tenant data leakage
- Privilege escalation (role confusion, missing checks)
- CSRF (if cookie sessions)
- XSS leading to token theft (if tokens stored poorly)

### 8.8.2 Minimum Controls

- [ ] TLS everywhere
- [ ] Secure cookies (httpOnly, secure, sameSite) if sessions
- [ ] CSRF protection for cookie-auth (token or sameSite strategy)
- [ ] Rate limiting on:
  - Login
  - Reset requests
  - Magic links
  - Invites
- [ ] Uniform error messages on login (avoid enumeration)
- [ ] Short TTL, single-use tokens for reset/magic links/invites
- [ ] Session invalidation on password change
- [ ] Deny-by-default authorization
- [ ] Tenant isolation tests in CI
- [ ] Secrets management and rotation policy

---

## 8.9 Audit Logging (Security + Product Reality)

### 8.9.1 What Must Be Audited (Minimum)

- Login success/failure (include rate-limit metadata)
- Password reset requested/completed
- Magic link requested/used
- Invites sent/accepted/revoked
- Role changes
- Membership removals
- Billing events (upgrade/downgrade/cancel)
- Exports of sensitive data
- Destructive actions (delete, bulk actions)

### 8.9.2 Required Audit Fields

| Field | Description |
|-------|-------------|
| tenantId | Tenant context |
| actorUserId | Who performed the action |
| actionType | What action was taken |
| targetType + targetId | What was affected |
| timestamp | When it happened |
| requestId | Correlation ID |
| ip + userAgent | (if allowed by policy) |
| metadata | (old/new role, provider, plan, etc.) |

> **Rule**: Audit logs are tenant-scoped and accessible to Admin.

---

## 8.10 Observability + Operations (Auth-Focused)

**Minimum metrics to track**:
- Login attempts / success rate
- Password reset requested/completed
- Invite sent/accepted/expired
- Rate limit hits
- 401/403/404 distribution by endpoint
- Spikes in auth failures (alert)

**Logging rules**:
- Always include requestId
- Include tenantId + userId when known
- Never log raw tokens or passwords

---

## 8.11 "Golden Path" Specs

### 8.11.1 Login Flow Spec (Password)

1. User submits email/password
2. Server validates; responds with session/JWT
3. Server resolves memberships
4. If single tenant -> enter product
5. If multiple tenants -> tenant chooser
6. Activation guidance shown (if first session)

**Edge states**:
- Invalid credentials -> generic error
- Too many attempts -> 429 `RATE_LIMITED`
- Suspended user/tenant -> deny with explicit UX state

### 8.11.2 Invite Acceptance Flow Spec

1. Invitee opens link
2. Token validated (TTL, single-use)
3. Seat limit check
4. Membership created/activated
5. User enters tenant context
6. Audit + analytics events fired

**Edge states**:
- Expired -> `INVITE_EXPIRED`
- Used -> `INVITE_USED`
- Seat limit -> `SEAT_LIMIT_REACHED`
- Revoked -> `INVITE_REVOKED`

---

## 8.12 Templates

### 8.12.1 Permission Matrix (Expanded)

| Action | Admin | Member | Viewer | Notes |
|--------|-------|--------|--------|-------|
| org.view | Yes | Yes | Yes | |
| org.update | Yes | No | No | audited |
| member.invite | Yes | No | No | audited + rate limit |
| member.remove | Yes | No | No | audited |
| member.role.change | Yes | No | No | audited |
| billing.view | Yes | No | No | |
| billing.update | Yes | No | No | audited |
| usage.view | Yes | Yes | Yes | |
| core.create | Yes | Yes | No | limit gated |
| core.export | Yes | Yes/No | Yes/No | decide by product |
| core.delete | Yes | Yes/No | No | audited |

### 8.12.2 Standard Error Codes (Auth + Access)

| Code | Description |
|------|-------------|
| `AUTH_REQUIRED` | No authentication provided |
| `INVALID_CREDENTIALS` | (optional; careful with enumeration) |
| `RATE_LIMITED` | Too many attempts |
| `USER_SUSPENDED` | User account suspended |
| `TENANT_SUSPENDED` | Tenant/org suspended |
| `MEMBERSHIP_INACTIVE` | User not active member |
| `FORBIDDEN_ROLE` | Insufficient permissions |
| `TENANT_MISMATCH` | Wrong tenant context |
| `TRIAL_ENDED` | Trial period expired |
| `PAYMENT_REQUIRED` | Payment needed |
| `SEAT_LIMIT_REACHED` | No more seats available |
| `USAGE_LIMIT_REACHED` | Usage limit exceeded |
| `INVITE_EXPIRED` | Invite link expired |
| `INVITE_USED` | Invite already used |
| `INVITE_REVOKED` | Invite was revoked |

### 8.12.3 Authorization Decision Structure (Template)

```
principal: { userId, tenantId, role, membershipStatus, planStatus }
action: string
resource: { tenantId, ownerId, status }
decision: { allowed: boolean, code?: string, details?: object }
```

---

## 8.13 Deliverables (What Must Exist)

- `ADR_Auth_Strategy.md`
- `ADR_RBAC_Strategy.md`
- `Permission_Matrix.md`
- `Auth_Flows.md` (login/reset/invite acceptance)
- `Audit_Action_List.md` (what gets audited + fields)
