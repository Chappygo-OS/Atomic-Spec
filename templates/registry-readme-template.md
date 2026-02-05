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
2. Filter to relevant sections (backend work → `architecture`, `api`, `backend`, `database`, `code_patterns`)
3. Use these values as non-negotiable defaults
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

### Core Architecture (Set First!)

| Section | Covers | Impact |
|---------|--------|--------|
| `architecture` | System pattern, layers, API style, communication | **HIGHEST** - affects everything |
| `code_patterns` | Data access, DI, error handling, validation | **HIGH** - affects all code |

### Technology Choices

| Section | Covers |
|---------|--------|
| `api` | Versioning, pagination, error format, resource naming, auth headers |
| `backend` | Language, framework, ORM, auth, caching, job queues |
| `frontend` | Framework, rendering, UI library, state management, routing |
| `database` | Type, tenancy, naming conventions, primary keys, query style |

### Quality & Operations

| Section | Covers |
|---------|--------|
| `error_handling` | Logging format, error tracking, tracing |
| `testing` | Frameworks, coverage targets, test organization |
| `infrastructure` | CI/CD, containers, cloud, deployment, IaC |
| `security` | CORS, CSRF, CSP, rate limiting, password policy |

### Standards

| Section | Covers |
|---------|--------|
| `conventions` | Naming (variables, files, classes), commit format, branches |
| `ui_specs` | Dark mode, responsive, accessibility, icons, animations |

## Architecture Section (Critical)

The `architecture` section is the **most important** - it must be set before any feature development:

```yaml
architecture:
  pattern: modular_monolith    # How the system is structured
  layers: clean                 # How code is organized
  api_style: rest               # How APIs are designed
  communication: sync           # How services communicate
  repo_structure: monorepo      # How code is stored
```

**Why this matters:**
- `pattern: microservices` → Each feature may be a separate service
- `pattern: monolith` → All features in one codebase
- `layers: clean` → Use cases, entities, interfaces separation
- `layers: vertical_slice` → Feature folders with all layers inside

## Code Patterns Section

Defines HOW code is written, not WHAT tools are used:

```yaml
code_patterns:
  data_access: repository       # Repository pattern with interfaces
  dependency_injection: constructor  # Dependencies via constructor
  error_handling: result_type   # Result<T, E> instead of exceptions
  validation_approach: schema   # Zod/Yup schemas
  null_handling: strict_null    # No nulls in domain
```

## Deviation Protocol

If a feature MUST deviate from a registry default:

1. Get human approval via `AskUserQuestion`
2. Include in the spec/plan:

```markdown
DEVIATION from project-registry:
- Key: architecture.layers
- Default: clean
- This spec uses: vertical_slice
- Reason: Self-contained microservice with simple domain
- Approved: Human (2026-02-05)
```

3. Log in `changelog.md` under "Deviation Log"

## Decision Priority

When multiple sources exist:

1. **Registry** - Project-wide default (highest priority)
2. **Spec** - Feature explicitly states different requirement
3. **Assumed** - AI inference (must be confirmed)

```
Registry has api.versioning = url
Spec says "use header versioning"
→ Spec wins, but DEVIATION block required
```

## Why This Matters

Without a registry:
- API versioning inconsistent (some `/v1/`, some without)
- Different features use different state management
- Auth patterns vary across services
- Code organization differs per developer
- Debugging harder due to inconsistency

With a registry:
- One source of truth
- Explicit deviations (not accidental drift)
- Full audit trail
- Faster onboarding (read registry to understand stack)
- AI generates consistent code across all features
