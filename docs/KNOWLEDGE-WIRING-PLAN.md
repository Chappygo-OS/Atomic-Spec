# Knowledge Wiring Plan: Fixing the Assembly Line Manual Integration

**Date**: 2026-02-06
**Status**: Proposed
**Problem**: Assembly Line Manual exists but is not being read or applied

---

## Executive Summary

The Assembly Line Manual (18 stations of SaaS best practices) exists and is copied to user projects, but **no command actually reads it**. The model has been "figuring things out" using general knowledge instead of the curated expertise in the stations.

Additionally, during implementation, subagents are **clueless** about project patterns because Context Pinning prevents them from reading anything except the current task file.

**Solution**:
1. Wire stations into planning commands
2. Embed all necessary context INTO task files (self-contained tasks)

---

## Part 1: The Problem

### 1.1 What We Have

```
.specify/
├── knowledge/
│   └── stations/           # 18 detailed SaaS guides (THE ASSEMBLY LINE MANUAL)
│       ├── 00-station-map.md
│       ├── 06-api-contracts.md      # API versioning, tenant scoping, error schemas
│       ├── 07-data-architecture.md  # Tenancy models, "no naked queries"
│       ├── 08-auth-rbac.md          # JWT vs sessions, RBAC patterns
│       └── ... (15 more stations)
└── subagents/              # Distilled versions of station knowledge
    ├── backend-architect.md
    ├── data-architecture.md
    └── ... (19 more subagents)
```

### 1.2 What the Constitution Says

```markdown
# memory/constitution.md - Article X

2. **Mandatory Reference**: Before generating any artifact (Plan, Task list, or Code),
   you MUST read the specific Station file corresponding to that domain
   (e.g., read `06-api-contracts.md` before planning APIs).
```

### 1.3 What Actually Happens

| Command | References to Stations | Actually Reads Station Files? |
|---------|----------------------|------------------------------|
| `plan.md` | 0 | **NO** |
| `tasks.md` | 0 | **NO** |
| `implement.md` | 0 | **NO** |
| `specify.md` | 0 | **NO** |
| `cleanup.md` | 0 | **NO** |
| `analyze-competitors.md` | 8 | YES (only one!) |

**Result**: The model uses general training knowledge instead of the curated SaaS expertise.

### 1.4 The Subagent Problem

During `/atomicspec.implement`, Context Pinning restricts what can be read:

```
Allowed:
├── index.md (navigation)
├── T-XXX-current-task.md (current task only)
├── traceability.md (to update)
└── specs/_defaults/registry.yaml (project defaults)

FORBIDDEN:
├── plan.md
├── spec.md
├── Other task files
├── .specify/knowledge/stations/*
└── .specify/subagents/*
```

**Problem**: A subagent implementing `T-025-create-user-repository.md` has NO access to:
- Tenancy rules ("every query must filter by tenant_id")
- Code patterns (repository vs active record)
- Gate criteria from stations
- Naming conventions

---

## Part 2: The Solution

### 2.1 Two-Part Fix

| Part | What | When |
|------|------|------|
| **A. Wire Stations into Planning** | Read stations/subagents before designing | During `/atomicspec.plan` |
| **B. Self-Contained Tasks** | Embed ALL context INTO task files | During `/atomicspec.tasks` |

### 2.2 Part A: Wire Stations into Planning

**New Phase in `plan.md`:**

```markdown
### Phase 0.1: Load Domain Knowledge

Before Phase 1 (Design & Contracts), load relevant knowledge:

1. **Detect feature domains** from spec.md:
   - Has API endpoints? → Load Station 06 + backend-architect subagent
   - Has database/entities? → Load Station 07 + data-architecture subagent
   - Has authentication? → Load Station 08 + auth subagent
   - Has billing? → Load Station 09 + payment-integration subagent

2. **For each relevant domain**:
   a. Read subagent: `.specify/subagents/[domain].md`
   b. If more detail needed: Read station: `.specify/knowledge/stations/[XX]-[name].md`
   c. Apply patterns and gate criteria to design

3. **If NO knowledge base exists** (no stations, no subagents):
   → Use AskUserQuestion to ask user how to proceed
   → Options: Use general practices / Set up defaults now / Import template
```

### 2.3 Part B: Self-Contained Tasks

**Current Task File (Missing Context):**

```markdown
# T-025-create-user-repository

## Task Objective
Create the UserRepository class.

## Files to Create
- src/repositories/user-repository.ts

## Verification Command
npm test -- --grep "UserRepository"
```

**Problem**: Implementer has NO IDEA about patterns, tenancy, conventions.

---

**New Task File (Self-Contained):**

```markdown
# T-025-create-user-repository

**Status**: Pending

## Embedded Context (READ THIS FIRST)

This section contains ALL context needed to implement this task.
Do NOT read plan.md, spec.md, or other files.

### Project Standards (from registry)
| Key | Value |
|-----|-------|
| `architecture.layers` | clean |
| `code_patterns.data_access` | repository |
| `code_patterns.error_handling` | result_type |
| `database.tenancy_model` | shared_db_tenant_id |
| `conventions.files` | kebab-case |

### Domain Rules (from Station 07 + data-architecture subagent)
- **Tenancy**: Every query MUST filter by `tenant_id`
- **No naked queries**: All DB access through repository methods only
- **Audit columns**: Include `created_at`, `updated_at`, `created_by`
- **Soft delete**: Use `deleted_at` instead of hard delete

### API Context (from contracts/)
```yaml
POST /api/v1/users → createUser(data, tenantId)
GET /api/v1/users/:id → getUserById(id, tenantId)
```

### Feature Summary
This feature implements user management for multi-tenant SaaS...

### Gate Criteria (from data-architecture subagent)
- [ ] Repository interface defined with tenant-scoped methods
- [ ] No direct ORM calls outside repository
- [ ] All queries filter by tenant_id
- [ ] Audit columns handled automatically

## Requirement Mapping
| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-003 | Users can be created with email validation | P1 |

## Task Objective
Create the UserRepository class implementing the repository pattern...

## Technical Implementation Detail
...

## Verification Command
npm test -- --grep "UserRepository"
```

**Result**: Implementer has EVERYTHING needed. No guessing.

---

## Part 3: Handling Missing Knowledge

### 3.1 When Registry Doesn't Exist

**In `plan.md`:**

```markdown
If `specs/_defaults/registry.yaml` doesn't exist or is empty:

Use AskUserQuestion:
┌─────────────────────────────────────────────────────────────┐
│ No project defaults registry found. What should we do?      │
├─────────────────────────────────────────────────────────────┤
│ ○ Create from this plan                                     │
│   Decisions made here become project defaults               │
│                                                             │
│ ○ Skip registry                                             │
│   Keep all decisions feature-specific                       │
│                                                             │
│ ○ Import SaaS template                                      │
│   Use standard SaaS defaults as starting point              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 When Subagents Don't Exist

**In `tasks.md`:**

```markdown
If `.specify/subagents/[domain].md` doesn't exist:

1. Check for full station: `.specify/knowledge/stations/[XX]-[domain].md`
2. If station exists → Extract key rules and embed in task
3. If neither exists → Embed note in task:
   "No domain knowledge available. Using plan.md decisions."

Do NOT fail. Always produce tasks with whatever context is available.
```

### 3.3 When Nothing Exists (Fresh Project)

**In `plan.md`:**

```markdown
If NO registry AND NO stations/subagents exist:

Use AskUserQuestion:
┌─────────────────────────────────────────────────────────────┐
│ No project knowledge base found. How should we proceed?     │
├─────────────────────────────────────────────────────────────┤
│ ○ Use general best practices                                │
│   AI will use training knowledge (less SaaS-specific)       │
│                                                             │
│ ○ Set up defaults now                                       │
│   I'll answer questions to establish patterns               │
│                                                             │
│ ○ Import from template                                      │
│   Use a standard SaaS template                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 4: Implementation Checklist

### Files to Update

| File | Changes |
|------|---------|
| `templates/atomic-task-template.md` | Add "Embedded Context" section |
| `templates/commands/plan.md` | Add Phase 0.1 (Load Domain Knowledge) |
| `templates/commands/tasks.md` | Add context embedding logic (Section 4.2.2) |
| `memory/constitution.md` | Add Directive 8 (Self-Contained Tasks) |

### New Directive for Constitution

```markdown
#### Directive 8: Self-Contained Tasks

Task files generated by `/atomicspec.tasks` MUST be self-contained:

1. **Embedded Context Section**: Every task MUST include:
   - Registry standards (if registry exists)
   - Domain rules (from relevant subagent/station)
   - API context (from contracts/, if applicable)
   - Feature summary (one paragraph)
   - Gate criteria (from subagent/station)

2. **Rationale**: During implementation, Context Pinning prevents reading
   plan.md, spec.md, stations, and subagents. The task file must contain
   everything the implementer needs.

3. **Graceful Degradation**: If knowledge sources don't exist:
   - Missing registry → Embed "No registry" note + plan.md decisions
   - Missing subagent → Embed station excerpt or "No domain knowledge" note
   - Missing everything → Embed plan.md decisions directly

**Violation**: Generating task files without embedded context is a Constitution violation.
```

---

## Part 5: Before vs After

### Before (Current State)

```
/atomicspec.plan
├── Reads: spec.md, constitution.md
├── Does NOT read: stations, subagents
└── Output: plan.md with decisions (but not informed by stations)

/atomicspec.tasks
├── Reads: spec.md, plan.md
├── Does NOT read: stations, subagents, registry
└── Output: Task files (missing context)

/atomicspec.implement
├── Reads: current task file only
├── Cannot read: stations, subagents, plan.md
└── Result: Subagent guesses patterns, makes mistakes
```

### After (Proposed)

```
/atomicspec.plan
├── Reads: spec.md, constitution.md
├── NEW: Reads registry (if exists)
├── NEW: Reads relevant stations/subagents based on feature domains
└── Output: plan.md INFORMED by curated SaaS knowledge

/atomicspec.tasks
├── Reads: spec.md, plan.md
├── NEW: Reads registry, subagents, contracts/
├── NEW: EMBEDS context into each task file
└── Output: Self-contained task files

/atomicspec.implement
├── Reads: current task file only (unchanged)
├── BUT: Task file now contains everything needed
└── Result: Subagent has full context, follows patterns correctly
```

---

## Part 6: Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Stations read during planning | 0 | All relevant |
| Subagents applied | 0 | All relevant |
| Task files with embedded context | 0% | 100% |
| Implementer knowledge of patterns | Guessing | Full context |
| Gate criteria in task files | 0% | 100% |
| Consistency across features | Low | High |

---

## Part 7: Timeline

| Phase | Task | Estimate |
|-------|------|----------|
| 1 | Update `atomic-task-template.md` | 30 min |
| 2 | Update `tasks.md` (embed context logic) | 1 hour |
| 3 | Update `plan.md` (load domain knowledge) | 1 hour |
| 4 | Update `constitution.md` (Directive 8) | 30 min |
| 5 | Test with sample feature | 1 hour |
| **Total** | | **4 hours** |

---

## Conclusion

The Assembly Line Manual was written with valuable SaaS expertise, but it was never wired into the commands. The model has been operating blind.

This plan fixes that by:
1. **Reading** stations/subagents during planning
2. **Embedding** all context into task files for implementation

The result: Consistent, pattern-following code that applies the curated knowledge instead of guessing.

---

**Prepared by**: Development Team
**Review requested from**: [Boss Name]
**Decision needed**: Approve implementation plan
