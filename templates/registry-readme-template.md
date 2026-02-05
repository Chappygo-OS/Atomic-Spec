# Project Defaults Registry

This folder contains the **single source of truth** for project-wide technical decisions.

## Purpose

Ensure consistency across all features by:
1. **Storing decisions once** - When a tech choice is made, it's recorded here
2. **Enforcing defaults** - All specs/plans must use these values or explicitly deviate
3. **Tracking changes** - Every modification is logged with full audit trail
4. **Requiring approval** - No silent updates; humans must approve all changes

## Files

| File | Purpose |
|------|---------|
| `registry.yaml` | The structured source of truth for all defaults |
| `changelog.md` | Audit trail of all changes (what/when/why/who) |
| `README.md` | This file - explains the system |

## How It Works

### For AI Agents / Commands

**Before generating any spec, plan, or code:**

1. Read `registry.yaml`
2. Filter to relevant sections (backend work → read `api`, `backend`, `database`)
3. Use these values as defaults
4. If deviating → include explicit `DEVIATION:` block with justification

**When a new decision is detected:**

1. Check if it's project-wide (not feature-specific)
2. Use `AskUserQuestion` to confirm:
   - "Add to project defaults?"
   - "Keep as feature-specific?"
   - "Reject?"
3. If approved → Update registry.yaml AND changelog.md

### For Humans

**To change a default:**
1. Never edit `registry.yaml` directly
2. Use a SpecKit command that will prompt for the change
3. Approve via the HITL checkpoint
4. Change is logged automatically

**To review history:**
- Check `changelog.md` for full audit trail
- Each entry shows: what changed, when, why, and who approved

## Registry Sections

| Section | Covers |
|---------|--------|
| `api` | Versioning, pagination, error format, rate limiting |
| `backend` | Language, framework, ORM, auth method |
| `frontend` | Framework, UI library, state management, forms |
| `database` | Type, tenancy model, soft delete, migrations |
| `testing` | Frameworks, coverage targets |
| `infrastructure` | CI/CD, containers, cloud, deployment |
| `conventions` | Naming conventions, commit format |
| `ui_specs` | Dark mode, responsive, accessibility, animations |

## Deviation Protocol

If a feature MUST deviate from a registry default:

1. Get human approval via `AskUserQuestion`
2. Include in the spec/plan:

```markdown
DEVIATION from project-registry:
- Key: backend.orm
- Default: prisma
- This spec uses: drizzle
- Reason: Legacy system requires Drizzle for compatibility
- Approved: Human (2026-02-05)
```

3. Log in `changelog.md` under "Deviation Log"

## Why This Matters

Without a registry:
- API versioning gets inconsistent (some `/v1/`, some without)
- Different features use different state management
- Auth patterns vary across services
- Debugging becomes harder due to inconsistency

With a registry:
- One source of truth
- Explicit deviations (not accidental drift)
- Full audit trail
- Faster onboarding (read registry to understand stack)
