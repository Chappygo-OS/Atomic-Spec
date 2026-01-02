# Station 12: Data Lifecycle

## 1. Objective

Ensure operational safety (backups) and compliance (retention/deletion).

## 2. Inputs

- Data model.
- Compliance requirements (GDPR).

## 3. Trigger

Configuring storage, backups, or deletion features.

## 4. The "How-To"

### Classification

- Categorize data (Core, PII, Logs, Audit).

### Backups

- Daily full + PITR (Point-in-Time Recovery).
- Perform monthly restore drills.

### Retention

- Define policy per category (e.g., Audit logs 24 months, Ops logs 14 days).

### Deletion

- Define "Delete" (Soft vs Hard).
- Handle Tenant deletion (cascade) vs User deletion (anonymize).

### Exports

- Audit all exports.
- Use short-lived links.

## 5. Gate Criteria

- [ ] Data Classification exists.
- [ ] Backup & Restore Policy defined.
- [ ] Retention & Deletion Policies defined.
- [ ] Restore Runbook exists.
