---
description: Detect and remove orphaned code, unused components, dead routes, and stale database artifacts
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Purpose

This command identifies orphaned/unused code across the codebase and helps safely remove it. It adapts to the project's tech stack and gives the user full control over detection methods and cleanup actions.

## ⚠️ CRITICAL PRINCIPLES

1. **Report first, delete later** - NEVER auto-delete. Always show findings, get user approval.
2. **Per-domain control** - User chooses approach for each domain (frontend, backend, database) independently.
3. **Adapt to what exists** - Only offer cleanup for domains that actually exist in the project.
4. **External tools are optional** - User can always choose AI-based detection instead.

---

## Phase 1: Project Analysis

### 1.1 Detect Project Structure

Read `plan.md` from the current feature directory (or project root) to extract tech stack.

**Determine which domains exist:**

```
┌─────────────────────────────────────────────────────────────┐
│ Domain Detection                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ FRONTEND exists if ANY of:                                  │
│ ├── frontend/ directory exists                              │
│ ├── src/components/ exists                                  │
│ ├── package.json has react/vue/angular/svelte               │
│ └── plan.md mentions frontend framework                     │
│                                                             │
│ BACKEND exists if ANY of:                                   │
│ ├── backend/ directory exists                               │
│ ├── app/ or src/ with routes/api folders                    │
│ ├── requirements.txt / pyproject.toml / go.mod              │
│ └── plan.md mentions backend framework                      │
│                                                             │
│ DATABASE exists if ANY of:                                  │
│ ├── migrations/ directory exists                            │
│ ├── prisma/ or drizzle/ or alembic/ directories             │
│ ├── models/ with ORM definitions                            │
│ └── plan.md mentions database/ORM                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Identify Tech Stack Per Domain

For each domain that exists, identify the specific technologies:

| Domain | Detect | Examples |
|--------|--------|----------|
| Frontend | Framework | React, Vue, Angular, Svelte, Next.js, Nuxt |
| Frontend | Language | TypeScript, JavaScript |
| Frontend | State | Zustand, Redux, Pinia, Context |
| Backend | Framework | FastAPI, Express, Django, Flask, Go Chi, Gin |
| Backend | Language | Python, Node.js, Go, Rust |
| Database | Type | PostgreSQL, MySQL, SQLite, MongoDB |
| Database | ORM | SQLAlchemy, Prisma, Drizzle, TypeORM, Django ORM |

### 1.3 Report Project Analysis

Output to user:

```
══════════════════════════════════════════════════════════════
🔍 PROJECT ANALYSIS - Cleanup Preparation
══════════════════════════════════════════════════════════════

Detected Domains:

| Domain    | Exists | Tech Stack                      |
|-----------|--------|---------------------------------|
| Frontend  | ✓      | React + TypeScript + Zustand    |
| Backend   | ✓      | FastAPI + Python 3.11           |
| Database  | ✓      | PostgreSQL + SQLAlchemy         |

Domains to scan: Frontend, Backend, Database
══════════════════════════════════════════════════════════════
```

---

## Phase 2: Tool Discovery & Selection (Per Domain)

**For EACH domain that exists**, perform tool discovery and ask user for preference.

### 2.1 Tool Discovery

#### Known Tools by Stack

**Frontend (JS/TS):**
| Tool | Purpose | Install | Pros | Cons |
|------|---------|---------|------|------|
| knip | Unused files, exports, deps | `npm i -D knip` | Comprehensive, 100+ plugins | Requires config for monorepos |
| ts-prune | Unused TS exports | `npm i -D ts-prune` | Fast, simple | TS only |
| depcheck | Unused npm deps | `npm i -D depcheck` | Quick scan | Dependencies only |

**Backend (Python):**
| Tool | Purpose | Install | Pros | Cons |
|------|---------|---------|------|------|
| vulture | Dead code detection | `pip install vulture` | Confidence scores | False positives on decorators |
| deadcode | Unused code + fix | `pip install deadcode` | Has --fix option | Newer, less tested |

**Backend (Node.js):**
| Tool | Purpose | Install | Pros | Cons |
|------|---------|---------|------|------|
| knip | Same as frontend | `npm i -D knip` | Works for full-stack | Same config needed |

**Database:**
| Tool | Purpose | Notes |
|------|---------|-------|
| (AI-based) | Schema vs code audit | No standard tool - AI analysis recommended |

#### Unknown Stack - Web Search

If tech stack is not in the known list above:

```
🔍 Searching for cleanup tools for [STACK_NAME]...
```

Use WebSearch to find: "[STACK_NAME] dead code detection unused code tool"

Present findings to user with discovered tools.

### 2.2 Per-Domain User Choice (HITL)

**CRITICAL: Ask user separately for EACH domain.**

Use AskUserQuestion for each domain that exists:

---

**Frontend Cleanup Method:**

```
Question: "How would you like to detect orphaned frontend code?"
Header: "Frontend"
Options:
  - Label: "Use knip (Recommended)"
    Description: "Comprehensive detection of unused files, exports, and dependencies. Requires: npm i -D knip"
  - Label: "Use ts-prune"
    Description: "Focused on unused TypeScript exports. Lighter weight. Requires: npm i -D ts-prune"
  - Label: "AI-based detection"
    Description: "No tools needed. AI will grep/search for orphaned components, dead routes, unused stores"
  - Label: "Skip frontend cleanup"
    Description: "Don't scan frontend for orphaned code"
```

---

**Backend Cleanup Method:**

For Python:
```
Question: "How would you like to detect orphaned backend code?"
Header: "Backend"
Options:
  - Label: "Use vulture (Recommended)"
    Description: "Finds unused functions, classes, variables with confidence scores. Requires: pip install vulture"
  - Label: "Use deadcode"
    Description: "Similar to vulture with --fix option. Requires: pip install deadcode"
  - Label: "AI-based detection"
    Description: "No tools needed. AI will search for unregistered routes, unused services, dead endpoints"
  - Label: "Skip backend cleanup"
    Description: "Don't scan backend for orphaned code"
```

For Node.js:
```
Question: "How would you like to detect orphaned backend code?"
Header: "Backend"
Options:
  - Label: "Use knip (Recommended)"
    Description: "Same tool as frontend - can scan entire project. Requires: npm i -D knip"
  - Label: "AI-based detection"
    Description: "No tools needed. AI will search for unused routes, services, and exports"
  - Label: "Skip backend cleanup"
    Description: "Don't scan backend for orphaned code"
```

---

**Database Cleanup Method:**

```
Question: "How would you like to audit database schema for orphaned tables/columns?"
Header: "Database"
Options:
  - Label: "AI-based audit (Recommended)"
    Description: "AI will compare schema/migrations against codebase to find unused tables and columns"
  - Label: "Skip database audit"
    Description: "Don't scan database schema for orphaned artifacts"
```

---

### 2.3 Record Choices

Store user selections:

```markdown
## Cleanup Configuration

| Domain   | Method      | Tool/Approach |
|----------|-------------|---------------|
| Frontend | Tool        | knip          |
| Backend  | AI-based    | -             |
| Database | AI-based    | -             |
```

---

## Phase 3: Detection Execution

Execute detection based on user's choices for each domain.

### 3.1 Tool-Based Detection

#### If user chose external tool:

**knip (JS/TS):**
```bash
npx knip --reporter json > .cleanup-knip-output.json
```

Parse output for:
- Unused files
- Unused exports
- Unused dependencies
- Unused types

**vulture (Python):**
```bash
vulture . --min-confidence 80 --exclude ".venv,migrations" > .cleanup-vulture-output.txt
```

Parse output for:
- Unused functions
- Unused classes
- Unused variables
- Unused imports

**Configure decorators to ignore:**
```bash
vulture --ignore-decorators "@app.get" "@app.post" "@router.get" "@router.post" "@router.put" "@router.delete"
```

### 3.2 AI-Based Detection

#### If user chose AI-based OR no tool available:

**Frontend Orphan Detection:**

```markdown
## AI Detection: Frontend

### Step 1: List all components
Find all files in: components/, pages/, views/, features/

### Step 2: Check imports for each component
For each component file:
1. Extract component name from filename
2. Grep entire frontend codebase for imports of this component
3. If 0 imports (excluding self and index files): FLAG as orphan

### Step 3: Check route usage
1. Extract all routes from router config (App.tsx, router.ts, etc.)
2. For each route path:
   - Grep for navigation links (href, to=, navigate())
   - If 0 links: FLAG as dead route

### Step 4: Check store usage
For each store file:
1. Grep for useStore hooks or store imports
2. If 0 usages: FLAG as unused store

### Detection Commands:
# Find components
find frontend/src -name "*.tsx" -o -name "*.vue" | head -50

# Check if component is imported (example)
grep -r "import.*ComponentName" frontend/src --include="*.tsx" --include="*.ts"

# Find route definitions
grep -r "path:" frontend/src/router frontend/src/App.tsx

# Find navigation links
grep -r "to=\|href=\|navigate(" frontend/src/components
```

**Backend Orphan Detection:**

```markdown
## AI Detection: Backend

### Step 1: List all route files
Find all files in: routes/, api/, endpoints/, routers/

### Step 2: Check route registration
For each route file:
1. Check main app file (main.py, app.py, index.ts) for registration
2. Look for: include_router, app.use, register
3. If not registered: FLAG as unregistered route

### Step 3: Check endpoint usage
For each API endpoint:
1. Extract endpoint path (@app.get("/path"), router.get("/path"))
2. Grep frontend codebase for fetch/axios calls to this path
3. If 0 frontend calls AND not documented as external API: FLAG as unused endpoint

### Step 4: Check service usage
For each service class/module:
1. Grep codebase for imports/instantiation
2. If 0 usages: FLAG as unused service

### Detection Commands:
# Find route files
find backend -name "*.py" -path "*/routes/*" -o -name "*.py" -path "*/api/*"

# Check route registration
grep -r "include_router\|app.add_route" backend/main.py

# Find endpoint definitions
grep -r "@app\.\|@router\." backend/routes

# Check if endpoint is called from frontend
grep -r "fetch.*endpoint\|axios.*endpoint" frontend/src
```

**Database Orphan Detection:**

```markdown
## AI Detection: Database

### Step 1: Extract schema
Get all table names from:
- migrations/ files
- models/ ORM definitions
- prisma/schema.prisma
- drizzle schemas

### Step 2: Check table usage
For each table:
1. Grep entire backend codebase for table name (as string and as model)
2. Exclude migrations directory from search
3. If 0 references: FLAG as orphan table

### Step 3: Check column usage
For frequently-used tables, check individual columns:
1. Extract column names from schema
2. Grep backend code for column references
3. If 0 references: FLAG as potentially unused column
   (Note: ORMs may use columns implicitly - mark as REVIEW not SAFE)

### Step 4: Check for stale migrations
1. List all migration files
2. Check for migrations that were reverted or are no-ops
3. FLAG as cleanup candidates

### Detection Commands:
# Find all table definitions (SQLAlchemy example)
grep -r "class.*Base\|__tablename__" backend/models

# Check if table is used
grep -r "TableName\|table_name" backend --exclude-dir=migrations

# Find migrations
ls -la backend/migrations/versions/ || ls -la prisma/migrations/
```

### 3.3 Feature History Enhancement (AI-Based Only)

⚠️ **IMPORTANT: This is an ENHANCEMENT, not a replacement.**

When using AI-based detection, ALWAYS perform the full detection described above (3.2). The feature history enhancement provides ADDITIONAL context to boost confidence on findings - it does NOT replace or limit the full scan.

#### When to Use Feature History

Check if `specs/` directory contains multiple feature directories:

```bash
ls -d specs/*/
# If you see: specs/001-initial/, specs/002-users/, specs/003-new-workflow/
# Then feature history is available
```

If only one feature exists or `specs/` is empty, skip this enhancement.

#### Enhancement A: Feature Relationship Detection

Read the CURRENT feature's `spec.md` and look for language indicating replacement/deprecation:

**Keywords to search for:**
- "replaces", "deprecates", "supersedes"
- "instead of", "no longer", "removes"
- "migrates from", "upgrades from"

**Example from spec.md:**
```markdown
## Scope
This feature replaces the old workflow system from 001-initial-setup.
The OldWorkflow component will be deprecated in favor of NewWorkflow.
```

**Action:** If found, files mentioned as replaced get **BOOSTED confidence** as orphan candidates.

#### Enhancement B: Stale File Detection

For each file flagged by the standard detection (3.2):

1. **Check which feature created it** - Read previous features' `tasks/*.md` files, look for "Files to Create" sections
2. **Check if any newer feature touched it** - Search newer features' tasks for the file path
3. **If created in old feature AND never mentioned in newer features** → Boost confidence

**Example:**
```
File: frontend/src/components/OldWorkflow.tsx

Standard detection: 0 imports found → flagged as potential orphan (60% confidence)
Feature history: Created in 001, never mentioned in 002 or 003 → boost to 85% confidence
```

**Detection Commands:**
```bash
# List all feature directories
ls -d specs/*/ | sort

# Search for file mentions in a feature's tasks
grep -r "OldWorkflow" specs/001-initial/tasks/

# Check if newer features mention the file
grep -r "OldWorkflow" specs/002-users/tasks/ specs/003-new-workflow/tasks/
```

#### Enhancement C: Cross-Reference Previous Tasks

For older features, read their `tasks/*.md` files and extract "Files to Create" sections:

1. Build a list of all files that SpecKit was supposed to create
2. Compare against files actually in the codebase
3. Files that exist but weren't created by any SpecKit task → Mark as "untracked" (REVIEW category)

**Note:** This helps identify files that might have been added manually or by other means.

#### How Confidence Boosting Works

| Standard Detection Result | Feature History Signal | Final Confidence |
|--------------------------|------------------------|------------------|
| 0 imports (60%) | Created in old feature, never touched | **85%** (SAFE) |
| 0 imports (60%) | Current spec says "replaces X" | **90%** (SAFE) |
| 0 imports (60%) | No history available | **60%** (REVIEW) |
| 1 dynamic import (40%) | Created in old feature, never touched | **55%** (REVIEW) |
| Multiple imports (10%) | Spec says "deprecated" | **30%** (KEEP, but note deprecation) |

#### Output Enhancement

When feature history is used, include provenance in the report:

```markdown
## Frontend Findings

### SAFE - Recommend Delete

| # | File | Confidence | Reason | Provenance |
|---|------|------------|--------|------------|
| 1 | `components/OldWorkflow.tsx` | 90% | 0 imports, spec says "replaces" | Created in 001, replaced by 003 |
| 2 | `stores/legacyStore.ts` | 85% | 0 usages, stale since 001 | Created in 001, never touched |
```

---

## Phase 4: Report Generation

### 4.1 Categorize Findings

All findings are categorized by confidence level:

| Category | Confidence | Criteria | Action |
|----------|------------|----------|--------|
| **SAFE** | High (90%+) | No references found anywhere, not in public API | Recommend delete |
| **REVIEW** | Medium (60-89%) | Few references, might be dynamic, might be external API | User decides |
| **KEEP** | Low (<60%) | Likely used dynamically, part of public API, framework magic | Explain why kept |

### 4.2 Generate Report File

Create `specs/[branch]/cleanup-report.md`:

```markdown
# Cleanup Report

**Generated**: [timestamp]
**Branch**: [branch-name]
**Feature**: [feature-name]

## Configuration

| Domain   | Method   | Tool      |
|----------|----------|-----------|
| Frontend | Tool     | knip      |
| Backend  | AI-based | -         |
| Database | AI-based | -         |

## Summary

| Domain   | SAFE | REVIEW | KEEP | Total |
|----------|------|--------|------|-------|
| Frontend | 5    | 2      | 1    | 8     |
| Backend  | 3    | 1      | 0    | 4     |
| Database | 1    | 2      | 0    | 3     |
| **Total**| 9    | 5      | 1    | 15    |

---

## Frontend Findings

### SAFE - Recommend Delete

| # | File | Type | Reason | Last Modified |
|---|------|------|--------|---------------|
| 1 | `components/OldButton.tsx` | Component | 0 imports found | 2024-12-01 |
| 2 | `stores/legacyStore.ts` | Store | 0 usages found | 2024-11-15 |

### REVIEW - User Decision Needed

| # | File | Type | Reason | Notes |
|---|------|------|--------|-------|
| 1 | `components/DynamicLoader.tsx` | Component | Only 1 dynamic import | Might be lazy loaded |

### KEEP - Not Removing

| # | File | Type | Reason |
|---|------|------|--------|
| 1 | `components/index.ts` | Barrel export | Re-exports other components |

---

## Backend Findings

### SAFE - Recommend Delete

| # | File | Type | Reason |
|---|------|------|--------|
| 1 | `routes/deprecated_v1.py` | Route | Not registered in main.py |
| 2 | `services/unused_helper.py` | Service | 0 imports found |

### REVIEW - User Decision Needed

| # | File | Type | Reason | Notes |
|---|------|------|--------|-------|
| 1 | `routes/webhook.py` | Endpoint | No frontend calls | Might be external webhook |

---

## Database Findings

### SAFE - Recommend Delete

| # | Table/Column | Type | Reason |
|---|--------------|------|--------|
| 1 | `legacy_logs` | Table | 0 code references |

### REVIEW - User Decision Needed

| # | Table/Column | Type | Reason | Notes |
|---|--------------|------|--------|-------|
| 1 | `users.old_email` | Column | 0 code references | Might be for data migration |
| 2 | `temp_cache` | Table | 0 code references | Might be used by cron job |

---

## Actions Log

_This section will be updated after cleanup execution._

| Action | File | Result | Timestamp |
|--------|------|--------|-----------|
| - | - | - | - |
```

### 4.3 Present Summary to User

Output:

```
══════════════════════════════════════════════════════════════
🧹 CLEANUP REPORT GENERATED
══════════════════════════════════════════════════════════════

Report saved to: specs/[branch]/cleanup-report.md

Summary:
┌──────────┬──────┬────────┬──────┬───────┐
│ Domain   │ SAFE │ REVIEW │ KEEP │ Total │
├──────────┼──────┼────────┼──────┼───────┤
│ Frontend │ 5    │ 2      │ 1    │ 8     │
│ Backend  │ 3    │ 1      │ 0    │ 4     │
│ Database │ 1    │ 2      │ 0    │ 3     │
├──────────┼──────┼────────┼──────┼───────┤
│ TOTAL    │ 9    │ 5      │ 1    │ 15    │
└──────────┴──────┴────────┴──────┴───────┘

Ready for review.
══════════════════════════════════════════════════════════════
```

---

## Phase 5: Review & Approval (HITL)

### 5.1 Review SAFE Items

Present SAFE items to user:

```
Question: "Delete these SAFE items? (High confidence - no references found)"
Header: "SAFE Delete"
Options:
  - Label: "Yes, delete all SAFE items"
    Description: "Delete all 9 items marked SAFE. Tests will run after deletion."
  - Label: "Let me review the list first"
    Description: "Show the detailed list, then ask again"
  - Label: "No, keep everything"
    Description: "Don't delete anything"
```

### 5.2 Review REVIEW Items

For each REVIEW item, ask user individually:

```
Question: "What to do with: components/DynamicLoader.tsx (only 1 dynamic import)"
Header: "Review #1"
Options:
  - Label: "Delete it"
    Description: "Remove this file"
  - Label: "Keep it"
    Description: "This is used, keep it"
  - Label: "Investigate more"
    Description: "Show me where it might be used"
```

### 5.3 Compile Final Deletion List

After all reviews:

```
══════════════════════════════════════════════════════════════
📋 FINAL DELETION LIST
══════════════════════════════════════════════════════════════

Approved for deletion:

Frontend (6 files):
  - components/OldButton.tsx
  - components/DynamicLoader.tsx (user approved)
  - stores/legacyStore.ts
  - ...

Backend (3 files):
  - routes/deprecated_v1.py
  - services/unused_helper.py
  - ...

Database (1 item):
  - DROP TABLE legacy_logs (migration will be generated)

Total: 10 items

Proceed with deletion?
══════════════════════════════════════════════════════════════
```

Use AskUserQuestion for final confirmation:

```
Question: "Proceed with deleting these 10 items?"
Header: "Confirm"
Options:
  - Label: "Yes, delete and run tests"
    Description: "Delete all approved items. Tests will run after each batch. Rollback if tests fail."
  - Label: "No, cancel"
    Description: "Don't delete anything. Report is saved for later."
```

---

## Phase 6: Cleanup Execution

### 6.1 Execute Deletion

**Delete in batches by domain:**

1. **Frontend first** (least risky)
   - Delete approved frontend files
   - Run: `npm run build` or `npm run typecheck`
   - If fails: ROLLBACK, report error

2. **Backend second**
   - Delete approved backend files
   - Run: `pytest` or `npm test`
   - If fails: ROLLBACK, report error

3. **Database last** (most risky)
   - Generate migration for table/column drops
   - Show migration to user for approval
   - Do NOT auto-run migration

### 6.2 Update Report

Update `cleanup-report.md` Actions Log:

```markdown
## Actions Log

| Action | File | Result | Timestamp |
|--------|------|--------|-----------|
| DELETE | components/OldButton.tsx | Success | 2024-01-15 14:30 |
| DELETE | stores/legacyStore.ts | Success | 2024-01-15 14:30 |
| DELETE | routes/deprecated_v1.py | Success | 2024-01-15 14:31 |
| GENERATE | migrations/drop_legacy_logs.py | Pending user run | 2024-01-15 14:31 |
```

### 6.3 Final Report

```
══════════════════════════════════════════════════════════════
✅ CLEANUP COMPLETE
══════════════════════════════════════════════════════════════

Actions taken:
  - Deleted 6 frontend files
  - Deleted 3 backend files
  - Generated 1 database migration (pending)

Tests: ✓ All passed

Database migration generated but NOT executed:
  migrations/versions/xxx_drop_legacy_logs.py

To apply: alembic upgrade head

Full report: specs/[branch]/cleanup-report.md
══════════════════════════════════════════════════════════════
```

---

## Phase 7: Optional - Post-Implementation Cleanup

At the end of `/speckit.implement`, after all tasks are complete, ask:

```
Question: "Would you like to run cleanup scan to detect any orphaned code?"
Header: "Cleanup"
Options:
  - Label: "Yes, run /speckit.cleanup"
    Description: "Scan for orphaned components, dead routes, unused code"
  - Label: "No, skip for now"
    Description: "Feature is complete, skip cleanup scan"
```

This integrates cleanup as an optional final step without forcing it.

---

## Appendix: Tool Reference

### knip Configuration

Create `knip.json` if using knip:

```json
{
  "entry": ["src/index.ts", "src/main.tsx"],
  "project": ["src/**/*.{ts,tsx}"],
  "ignore": ["**/*.test.ts", "**/*.spec.ts"],
  "ignoreDependencies": ["@types/*"]
}
```

### vulture Configuration

Create `.vulture.ini` or use CLI flags:

```ini
[vulture]
exclude = .venv,migrations,tests
min_confidence = 80
ignore_decorators = @app.get,@app.post,@router.get,@router.post
```

### Database Migration Templates

**SQLAlchemy/Alembic:**
```python
"""Drop orphaned table: legacy_logs

Revision ID: xxx
"""

def upgrade():
    op.drop_table('legacy_logs')

def downgrade():
    # Recreate table if needed
    pass
```

**Prisma:**
```prisma
// Remove from schema.prisma, then run:
// npx prisma migrate dev --name drop_legacy_logs
```
