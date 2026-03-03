# Data Architecture Subagent

**Domain**: Database design, tenancy models, data isolation, and migrations
**Source Stations**: Station 07 (Tenancy + Data Architecture)
**Use When**: Feature involves database/storage design
**Priority**: 1

## Core Knowledge

### Key Decisions

1. **Tenancy Model** (choose one, document why):

   | Model | Description | Best For | MVP? |
   |-------|-------------|----------|------|
   | A: Shared DB, tenant_id | One DB, all tables have tenant_id column | MVP, many small tenants | YES |
   | B: Shared DB, separate schema | One DB, each tenant has own schema | Moderate tenants, more isolation | Maybe |
   | C: Separate DB per tenant | Each tenant gets own database | Enterprise, regulated | No |
   | D: Hybrid | Default shared, enterprise on dedicated | Long tail + whales | Later |

   **Strong default**: Model A for MVP, but enforcement is NON-NEGOTIABLE.

2. **Enforcement Pattern** (all three required):
   - **Middleware**: Extract tenant from auth, inject into request context
   - **DAL (Data Access Layer)**: All queries go through tenant-scoped methods
   - **No naked queries**: Direct SQL without tenant filter is FORBIDDEN

3. **Baseline Entities** (every SaaS needs these):
   ```
   Tenant → has many → Users (via Membership)
   User → belongs to many → Tenants (via Membership)
   Membership → has → Role
   Role → has many → Permissions
   ```

### Required Patterns

- **Every table with tenant data**: MUST have `tenant_id` column
- **Every query**: MUST filter by tenant (no exceptions)
- **Joins across tenants**: FORBIDDEN (even for analytics)
- **Audit columns**: `created_at`, `updated_at`, `created_by` on all entities
- **Soft deletes**: Prefer `deleted_at` over hard deletes for audit trail

### Common Pitfalls

- **Pitfall**: Forgetting tenant_id on a new table
  → **Fix**: Code review checklist, migration linter

- **Pitfall**: Direct SQL queries bypassing DAL
  → **Fix**: "No naked queries" rule, static analysis

- **Pitfall**: Leaking data in error messages
  → **Fix**: Never include IDs from other tenants in errors

- **Pitfall**: Analytics queries across tenants
  → **Fix**: Separate read replica with explicit cross-tenant flag

## Gate Criteria

- [ ] Tenancy model selected and documented with ADR
- [ ] Enforcement pattern defined (middleware + DAL + no naked queries)
- [ ] Baseline SaaS entities included in data model
- [ ] Every table with tenant data has `tenant_id` column
- [ ] Tenant isolation test plan exists (read/write/join leakage tests)
- [ ] Triggers to revisit tenancy model are documented

## Output Format

When this subagent is used, produce:

1. **data-model.md**: Entity definitions with relationships
   - Include tenant_id on all tenant-scoped entities
   - Define baseline entities (Tenant, User, Membership, Role)
   - Add audit columns

2. **ADR for tenancy model**: In `FEATURE_DIR/adr/` or document inline
   - Which model chosen
   - Why chosen
   - Triggers to revisit

3. **Test plan section** in data-model.md:
   - Read isolation test (User A can't read User B's data)
   - Write isolation test (User A can't write to User B's records)
   - Join isolation test (queries don't leak across tenants)

## Integration Points

- **Feeds into**: `/speckit.tasks` for database setup tasks, `/speckit.implement` for schema creation
- **Depends on**: spec.md (requirements), API contracts (what data flows through endpoints)
- **Validates with**: Gate checklist above, tenant isolation test plan execution
