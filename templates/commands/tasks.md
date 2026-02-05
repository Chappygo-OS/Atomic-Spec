---
description: Generate atomic task files in tasks/ directory with index.md and traceability.md (Atomic Traceability Model)
handoffs:
  - label: Analyze For Consistency
    agent: speckit.analyze
    prompt: Run a project analysis for consistency
    send: true
  - label: Implement Project
    agent: speckit.implement
    prompt: Start the implementation in phases
    send: true
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --check-gates --gate-context tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -CheckGates -GateContext tasks
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## ⛔ MANDATORY STRUCTURAL REQUIREMENTS

**STOP. Read this section before generating ANY output.**

Per Constitution Article IX, this command has NON-NEGOTIABLE constraints:

| Constraint | Required | Forbidden |
|------------|----------|-----------|
| Task storage | `tasks/` directory with `T-XXX-[name].md` files | Single `tasks.md` file |
| Dashboard | `index.md` in FEATURE_DIR | No navigation file |
| Traceability | `traceability.md` mapping requirements ↔ tasks | Unmapped tasks |
| Task content | All 4 elements (ID, Mapping, Detail, Verification) | Incomplete tasks |

**If you are about to create a file called `tasks.md`, STOP. You are violating the Constitution.**

## Outline

### 1. Setup & Gate Compliance Check

Run `{SCRIPT}` from repo root. This script will:
1. Parse FEATURE_DIR and AVAILABLE_DOCS list
2. **Automatically validate gate criteria** (spec.md, plan.md, HITL approval)
3. **BLOCK execution if gates fail** - you will see error output

If the script outputs gate failures, report them to the user and **DO NOT PROCEED**.

### 1.5 Load Project Defaults Registry

**Per Constitution Article IX, Directive 7 - Load registry before generating tasks.**

Read `specs/_defaults/registry.yaml` to ensure tasks follow project standards:

1. **Extract relevant standards for task generation**:
   - `conventions.*` - File naming, function naming for task file paths
   - `backend.*` - Language/framework for verification commands
   - `frontend.*` - Framework for component task patterns
   - `testing.*` - Test framework for verification commands

2. **Apply to task generation**:
   - Use registry conventions for file paths in tasks (e.g., `kebab-case` vs `snake_case`)
   - Use registry test framework in verification commands (e.g., `npm test` vs `pytest`)
   - Reference registry patterns when specifying implementation steps

3. **Include registry reference in tasks** (when applicable):
   ```markdown
   ### Project Standards (from registry)
   - Naming: [conventions.files] for files, [conventions.variables] for code
   - Testing: [testing.unit_framework]
   ```

### 2. Load Design Documents

Read from FEATURE_DIR:
- **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
- **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions)

### 3. Extract Requirements Inventory

From `spec.md`, create a requirements table:

| Req ID | Requirement | User Story | Priority | Acceptance Criteria |
|--------|-------------|------------|----------|---------------------|
| FR-001 | ... | US1 | P1 | Given/When/Then |
| FR-002 | ... | US1 | P1 | Given/When/Then |

### 4. Create Atomic Task Structure

**CRITICAL: Do NOT create a single tasks.md file.**

#### 4.1 Create tasks/ Directory

```bash
mkdir -p "$FEATURE_DIR/tasks"
```

#### 4.2 Generate Individual Task Files

For EACH task, create a separate file in `tasks/`:

**File naming**: `T-XXX-[action]-[subject].md`

**Task number ranges**:
| Phase | Range | Purpose |
|-------|-------|---------|
| Setup | T-001 to T-009 | Project initialization |
| Foundation | T-010 to T-019 | Core models, base infrastructure |
| US1 (P1) | T-020 to T-036 | User Story 1 - MVP features |
| US1 Wiring | T-037 to T-039 | **Wire US1: routes, nav, stores** |
| US2 (P2) | T-040 to T-056 | User Story 2 features |
| US2 Wiring | T-057 to T-059 | **Wire US2: routes, nav, stores** |
| US3 (P3) | T-060 to T-076 | User Story 3 features |
| US3 Wiring | T-077 to T-079 | **Wire US3: routes, nav, stores** |
| Cross-cutting | T-080 to T-089 | Shared concerns (auth, error handling) |
| Final Verification | T-090 to T-099 | End-to-end integration tests |

**⚠️ WIRING TASKS ARE MANDATORY** - Every user story MUST have wiring tasks that:
- Register backend routes in the main app file
- Add frontend routes to the app router
- Add navigation links to sidebar/nav components
- Connect frontend stores/hooks to backend endpoints

**Each task file MUST contain**:

```markdown
# T-XXX-[task-name]

**Status**: Pending
**Created**: [DATE] | **Completed**: N/A

## Requirement Mapping

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-XXX | [Exact text from spec.md] | P[N] |

**User Story**: US-X: [Story title]

## Task Objective

[Single sentence objective]

## Technical Implementation Detail

### Files to Modify/Create
- `[exact/path/to/file.ext]` - [what changes]

### Dependencies
- [T-XXX-dep](./T-XXX-dep.md) - [why needed]

### Implementation Steps
1. [Specific action]
2. [Next action]
3. [Final action]

### Acceptance Criteria
- [ ] [Testable criterion]

### Wiring Checklist (if applicable)

<!--
  CRITICAL: If this task creates a new file, it MUST specify what existing files
  need to be updated to "wire" the new file into the application.
-->

- [ ] Route registered in main app file (if backend route)
- [ ] Page added to app router (if frontend page)
- [ ] Navigation link added (if user-facing page)
- [ ] Store/hook connected to API endpoint (if API endpoint)
- [ ] Component rendered by parent (if new component)

## Verification Command

\`\`\`bash
[EXACT executable command - NO placeholders]
\`\`\`

**Expected Output**:
\`\`\`
[What success looks like]
\`\`\`

## Completion Checklist
- [ ] Implementation complete
- [ ] Acceptance criteria met
- [ ] Verification passes
- [ ] Wiring checklist complete (if applicable)
- [ ] Updated traceability.md
```

#### 4.2.1 Wiring Requirements (MANDATORY)

⚠️ **CRITICAL: This section prevents the #1 cause of incomplete implementations.**

For EVERY task that creates a new artifact, you MUST either:
1. Include wiring steps in the same task, OR
2. Create a dedicated wiring task that depends on it

**Wiring Matrix - What Creates What Updates:**

| When You Create... | You MUST Also Update... |
|-------------------|------------------------|
| Backend route file (`routes/clients.py`) | Main app file to register router (`main.py`, `app.py`) |
| Frontend page (`pages/clients/page.tsx`) | App router config, navigation component |
| API endpoint | Frontend store/hook to call it |
| New component | Parent component to render it |
| Database model | Migration file, optionally seed data |
| New service | Dependency injection / service registry |
| Environment variable usage | `.env.example`, deployment configs |

**Wiring Task Template:**

For each User Story, the LAST task(s) in its range (T-X37 to T-X39) should be wiring tasks:

```markdown
# T-037-wire-us1-backend

## Task Objective
Register all US1 backend routes and verify API accessibility.

## Files to Update (NOT create)
- `backend/main.py` - Add: `app.include_router(feature_router, prefix="/api/feature")`
- `backend/app/routes/__init__.py` - Export new router

## Verification Command
curl -s http://localhost:8000/api/feature/health | jq '.status == "ok"'
```

```markdown
# T-038-wire-us1-frontend

## Task Objective
Add US1 pages to router and navigation.

## Files to Update (NOT create)
- `frontend/src/App.tsx` - Add Route for /feature
- `frontend/src/components/Sidebar.tsx` - Add "Feature" nav link
- `frontend/src/stores/featureStore.ts` - Connect to /api/feature endpoint

## Verification Command
# Start frontend, navigate to /feature, verify page loads
npm run dev & sleep 5 && curl -s http://localhost:3000/feature | grep -q "Feature Page"
```

**DO NOT proceed to Section 4.3 until every User Story has wiring tasks.**

#### 4.3 Generate index.md

Create `FEATURE_DIR/index.md` using `templates/index-template.md`:
- Feature name and branch
- Quick Navigation table with all documents
- Requirements summary table
- Current phase set to "Implementation"
- Task progress (Total/Completed/In Progress)
- Task queue listing

#### 4.4 Generate traceability.md

Create `FEATURE_DIR/traceability.md` using `templates/traceability-template.md`:
- Map every FR-XXX to its task ID(s)
- Map every task to its requirement(s)
- Initialize all statuses to "Pending"
- Calculate coverage metrics (MUST be 100%)

### 5. Validation

Before completing, verify:

- [ ] `index.md` exists with complete navigation
- [ ] `traceability.md` exists with 100% requirement coverage
- [ ] `tasks/` directory exists with individual task files
- [ ] Each task file has all 4 required elements:
  - [ ] ID (T-XXX-name format)
  - [ ] Requirement Mapping (FR-XXX)
  - [ ] Technical Implementation Detail (file paths)
  - [ ] Verification Command (executable, no placeholders)
- [ ] No orphan tasks (all tasks map to requirements)
- [ ] No uncovered requirements (all requirements have tasks)
- [ ] All verification commands are executable

### 6. Report

Output summary:
- Path to index.md
- Total task count
- Task count per user story
- Coverage percentage (should be 100%)
- List of task files created

**FORBIDDEN outputs** (Constitution violation):
- ❌ A single tasks.md file with checkbox lists
- ❌ Tasks without verification commands
- ❌ Tasks without requirement mappings

## Verification Command Requirements

**Every task MUST have an executable verification command.**

### Good Examples

```bash
# Specific test
npm test -- --grep "UserModel creates valid user"

# API test
curl -s -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq '.id != null'

# Type check
npx tsc --noEmit src/models/user.ts

# Lint check
npm run lint -- src/services/auth.ts
```

### Forbidden Patterns

```bash
# TOO VAGUE
npm test

# MANUAL
"Check the UI manually"

# PLACEHOLDER
[TODO: add verification]
```

## Context Pinning Reminder

Per Constitution Article IX, Directive 3, the subsequent `/speckit.implement` command will:
- Read ONLY `index.md` for navigation
- Read ONLY the specific `T-XXX-[name].md` for the current task
- Update `traceability.md` after each completion
- **NEVER** read the full `plan.md` during implementation

Context for task generation: {ARGS}
