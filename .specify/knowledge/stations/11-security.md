# Station 11: Security Baseline

## 1. Objective

Guarantee tenant isolation and minimize breach blast radius.

## 2. Inputs

- Threat model.
- Architecture docs.

## 3. Trigger

Performing security reviews or implementing sensitive modules.

## 4. The "How-To"

### Threat Model

- Identify top threats (Tenant isolation failure, Account takeover, RBAC bypass).

### Controls

- Rate limit all auth endpoints.
- Enforce tenant isolation in DAL.
- Use secure headers (HSTS, CSP).
- Validate API schemas.

### Workflow

- Block PRs on failed security scans.
- Require "Security Checklist" on sensitive PRs (Auth, Billing, Exports).

### Secrets

- Rotate keys regularly.
- Scan for secrets in git.

## 5. Gate Criteria

- [ ] Threat Model MVP defined.
- [ ] Security Baseline Checklist completed.
- [ ] PR Security Checklists integrated into workflow.
- [ ] Secrets Management Policy exists.
