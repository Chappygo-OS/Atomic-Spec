# Station 06: Authentication & RBAC

## 1. Objective

Design secure, tenant-aware AuthN/AuthZ that is auditable and consistent.

## 2. Inputs

- API Contract.
- Tenancy ADR.

## 3. Trigger

Implementing login, registration, invites, or permissions.

## 4. The "How-To"

### AuthN

- Choose Session (Cookie) vs JWT.
- Use strict rate limits on login/invites.

### Membership

- Users must have an active `Membership` to a `Tenant` to access resources.

### RBAC

- Use fixed roles for MVP (Admin, Member).
- Map **Roles** → **Permissions** (action strings like `org.update`).

### Policy Engine

- Centralize `authorize(principal, action, resource)` logic.

### Access Gating

- Integrate **Billing status** (Trial ended) and **Limit status** (Seat limit) into the authorization check.

### Audit Logging

- Log sensitive actions (login, role change, billing change).
- Include `tenantId` and `actorUserId`.

## 5. Gate Criteria

- [ ] ADRs for Auth Strategy and RBAC Strategy exist.
- [ ] Permission Matrix defined.
- [ ] Auth flows (Login, Invite Acceptance) specified.
- [ ] List of audited actions defined.
