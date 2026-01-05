# Station 14 — Data Lifecycle

> Backups, Retention, Deletion, and GDPR Basics

## 14.1 Objective

Define a data lifecycle that is:

- Operationally safe (backups, restore drills)
- Legally defensible (retention + deletion policy)
- Tenant-aware (tenant-scoped export/delete)
- Aligned with product needs (audit logs vs user deletion)
- Compatible with "enterprise readiness" later

> **Rule:** You don't have a deletion feature until you can prove it deletes (and you can restore safely).

## 14.2 Data Classification (What Data You Have)

Create a simple classification table for your SaaS.

### 14.2.1 Categories

| Category | Examples |
|----------|----------|
| Core tenant data | Domain entities |
| User profile data | PII: email, name |
| Auth/security data | Sessions, reset tokens |
| Billing identifiers | Stripe IDs, invoice URLs |
| Audit logs | Security + admin actions |
| Operational logs | App logs, metrics |
| Files/exports | Uploads, generated PDFs, etc. |
| Analytics events | Product telemetry |

> **Rule:** Different categories have different retention and deletion rules.

## 14.3 Backups (Design + Policy)

### 14.3.1 Backup Scope

You must back up:

- Primary database
- File storage metadata (DB) and object storage (if not versioned)
- Critical config (not secrets)
- Audit log store (if separate)

### 14.3.2 Backup Frequency (MVP Baseline)

| Backup Type | Frequency |
|-------------|-----------|
| DB full backup | Daily |
| DB point-in-time recovery (PITR) | Enabled if available |
| Object storage | Versioning or daily snapshot strategy |
| Retention of backups | e.g., 30 days (adjust by business need) |

> **Rule:** PITR is a huge safety net; enable it early if supported.

### 14.3.3 Restore Drills (Non-Negotiable)

At least monthly (or per release early):

- Restore a backup into staging
- Verify integrity (basic checks)
- Time the RTO (how long restore takes)

Define:

| Metric | Description | Example Target |
|--------|-------------|----------------|
| RPO | Max acceptable data loss | 1 hour |
| RTO | Max acceptable downtime | 4 hours |

Even if you don't commit to strict numbers, write targets.

## 14.4 Retention Policy (What You Keep, How Long)

### 14.4.1 Default Retention Suggestions (MVP)

These are typical starting points - adjust as needed:

| Data Type | Retention | Notes |
|-----------|-----------|-------|
| Core tenant data | While tenant active | |
| Audit logs | 12-24 months | Or longer for enterprise |
| Operational logs | 7-30 days | Cost control |
| Analytics | 13 months | Common practice, adjust |
| Billing identifiers | As long as needed | For accounting/support |
| Reset tokens | Hours/days | Then purge |
| Sessions | Days/weeks | Then expire |

> **Rule:** Retention is both legal and cost-driven.

### 14.4.2 "Minimum Necessary" Principle

- Store only what you need
- Do not keep sensitive data "just in case"
- Avoid duplicating PII across systems

## 14.5 Deletion Policy (What "Delete" Means)

### 14.5.1 Types of Deletion

| Type | Description |
|------|-------------|
| Soft delete | Hidden from user, recoverable |
| Hard delete | Physically removed |
| Anonymization | Remove PII but keep aggregate/audit record |

> **Rule:** Decide per entity category.

### 14.5.2 Tenant Deletion (Workspace/Org)

Tenant deletion must cover:

- Domain entities
- Membership records
- Files and exports
- API keys/integrations
- Usage snapshots (optional, can aggregate/anonymize)

> **Important:** Audit logs may need retention for security/legal reasons; define that explicitly.

### 14.5.3 User Deletion (Account)

User deletion must consider:

- Memberships in other tenants
- Audit logs referencing the user
- Billing (often tenant-level)

**Common Approach:**

- Remove PII fields (anonymize user)
- Keep audit log records but replace actor with "deleted user" id reference

> **Rule:** Deletion is not necessarily "erase every trace"; define and justify.

## 14.6 GDPR Basics (Practical, Not Legal Advice)

### 14.6.1 Rights You Must Support (Typical SaaS)

| Right | Description |
|-------|-------------|
| Access | User can request their data |
| Rectification | Update incorrect data |
| Deletion | Delete/anonymize under policy |
| Portability | Export data in common format |
| Objection/restriction | Specific cases (often rare in B2B) |

**MVP Approach:**

- Define a support workflow even if UI isn't built yet
- Log requests and actions taken

### 14.6.2 Data Processing Roles

- You are typically a **processor** for tenant data
- The tenant (org) is typically the **controller**

This influences who can request what.

## 14.7 Data Export (Portability and Support)

Define export scopes:

- Per user
- Per tenant
- Per entity (projects/reports)

**Rules:**

- Export must respect RBAC permissions
- Exports are sensitive - audit log + short-lived download links
- Watermarking later (optional)

## 14.8 Implementation Patterns (MVP-Friendly)

### 14.8.1 Deletion Jobs

Deletion is often async:

1. Create deletion request record
2. Enqueue job
3. Job deletes in batches
4. Job emits audit events
5. Job produces a deletion report (what was deleted)

> **Rule:** Deletion should be idempotent and restartable.

### 14.8.2 "Tombstone" Strategy for Hard Deletes

For referential integrity:

- Keep a minimal tombstone record for a short time
- Or rely on audit logs for traceability

## 14.9 Operational Runbooks

You must have runbooks for:

- Restore from backup (step-by-step)
- Tenant deletion request handling
- User deletion request handling
- "Customer claims data missing" investigation
- "Delete vs retention conflict" escalation path

## 14.10 Deliverables

- `Data_Classification.md`
- `Backup_and_Restore_Policy.md`
- `Retention_Policy.md`
- `Deletion_Policy.md`
- `GDPR_Request_Workflow.md`
- `Data_Export_Spec.md`
- `Restore_Runbook.md`

## 14.11 Templates

### 14.11.1 Retention Table (Starter)

| Data Category | Examples | Retention | Notes |
|---------------|----------|-----------|-------|
| Operational logs | API logs | 14 days | Cost control |
| Audit logs | Role changes | 24 months | Security/legal |
| Reset tokens | Password reset | 24h | Purge automatically |

### 14.11.2 Deletion Request Record (Fields)

```typescript
interface DeletionRequest {
  requestId: string;
  tenantId?: string;
  userId?: string;
  requestedBy: string;
  requestedAt: Date;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  completedAt?: Date;
  reportLink?: string; // Optional
}
```
