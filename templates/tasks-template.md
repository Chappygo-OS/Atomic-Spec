---
description: "Atomic Task Factory - generates tasks/ directory with individual task files, index.md, and traceability.md"
---

# Atomic Task Factory: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

<!--
  ============================================================================
  ATOMIC TRACEABILITY MODEL - CONSTITUTION ARTICLE IX COMPLIANCE

  Per the Atomic Injunction (Directive 2), this template generates a tasks/
  DIRECTORY with individual task files, NOT a single tasks.md file.

  Output Structure:
  specs/[###-feature-name]/
  ├── index.md              # Feature dashboard (navigation & status)
  ├── traceability.md       # Requirement-to-task matrix
  └── tasks/                # Atomic task directory
      ├── T-001-[name].md   # Individual task files
      ├── T-002-[name].md
      └── ...

  Each atomic task file MUST contain:
  1. ID: Unique task identifier
  2. Requirement Mapping: Link to FR-XXX from spec.md
  3. Technical Implementation Detail: Specific code actions with file paths
  4. Verification Command: Exact, executable command to verify completion

  FORBIDDEN: Creating a single tasks.md file with checkbox lists
  ============================================================================
-->

## Phase 1: Extract & Analyze

### 1.1 Requirements Extraction

From `spec.md`, extract:

| Req ID | Requirement | User Story | Priority |
|--------|-------------|------------|----------|
| FR-001 | [Extract from spec] | US1 | P1 |
| FR-002 | [Extract from spec] | US1 | P1 |
| FR-003 | [Extract from spec] | US2 | P2 |

### 1.2 Technical Components

From `plan.md`, extract:

- **Data Models**: [List entities from data-model.md]
- **API Endpoints**: [List from contracts/]
- **Infrastructure**: [List setup requirements]
- **Dependencies**: [List external dependencies]

## Phase 2: Task Decomposition

### Task Naming Convention

```
T-[XXX]-[action]-[subject].md

Format:
- XXX = Sequential 3-digit number (001, 002, 003...)
- action = verb (setup, create, implement, integrate, verify)
- subject = noun (project, model, service, endpoint, auth)

Examples:
- T-001-setup-project.md
- T-010-create-user-model.md
- T-020-implement-login-endpoint.md
- T-030-integrate-auth-middleware.md
- T-090-verify-user-registration.md
```

### Task Number Ranges

| Phase | Range | Purpose |
|-------|-------|---------|
| Setup | T-001 to T-009 | Project initialization, dependencies |
| Foundation | T-010 to T-019 | Core models, base infrastructure |
| US1 (P1) | T-020 to T-039 | User Story 1 - MVP implementation |
| US2 (P2) | T-040 to T-059 | User Story 2 implementation |
| US3 (P3) | T-060 to T-079 | User Story 3 implementation |
| Integration | T-080 to T-089 | Cross-cutting concerns |
| Verification | T-090 to T-099 | Final verification & polish |

## Phase 3: Generate Atomic Structure

### Directory Creation Script

Execute this script to create the atomic task structure:

```bash
#!/bin/bash
# Atomic Task Factory - Directory Creation
# Run from repository root

FEATURE_DIR="specs/[###-feature-name]"
TASKS_DIR="$FEATURE_DIR/tasks"

# Create tasks directory
mkdir -p "$TASKS_DIR"

echo "Created: $TASKS_DIR"
echo "Now generate individual task files..."
```

### Individual Task File Template

For EACH task, create a file in `tasks/` using this structure:

```markdown
# T-[XXX]-[task-name]

**Status**: Pending
**Created**: [DATE] | **Completed**: N/A

## Requirement Mapping

| Requirement | Description | Priority |
|-------------|-------------|----------|
| FR-[XXX] | [Exact text from spec.md] | P[N] |

**User Story**: US-[X]: [Story title from spec.md]

## Task Objective

[Single sentence: what this task accomplishes]

## Technical Implementation Detail

### Files to Modify/Create

- `[path/to/file.ext]` - [what changes]
- `[path/to/another.ext]` - [what changes]

### Dependencies

- [T-XXX-dependency](./T-XXX-dependency.md) - [why needed]
- Or: None (if no dependencies)

### Implementation Steps

1. [Specific action with code location]
2. [Next action]
3. [Final action]

### Acceptance Criteria

- [ ] [Testable criterion from spec.md]
- [ ] [Another criterion]

## Verification Command

```bash
[EXACT executable command - no placeholders]
```

**Expected Output**:
```
[What success looks like]
```

## Completion Checklist

- [ ] Implementation complete
- [ ] Acceptance criteria met
- [ ] Verification command passes
- [ ] Updated traceability.md
```

## Phase 4: Generate Support Files

### 4.1 Generate index.md

Create `index.md` in the feature directory using `templates/index-template.md`:

- Fill in feature name and branch
- Populate Quick Navigation table
- List all requirements with status
- Set initial phase to "Task Generation"
- List all tasks in Task Queue

### 4.2 Generate traceability.md

Create `traceability.md` using `templates/traceability-template.md`:

- Map every FR-XXX to its task(s)
- Map every task to its requirement(s)
- Initialize all statuses to "Pending"
- Calculate coverage metrics (should be 100%)

## Verification Command Requirements

**Every task MUST have an executable verification command.**

### Good Examples

```bash
# Run specific test
npm test -- --grep "UserModel creates valid user"

# API endpoint test
curl -s -X POST http://localhost:3000/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq '.id != null'

# Type checking
npx tsc --noEmit src/models/user.ts

# Lint specific file
npm run lint -- src/services/auth.ts

# Database migration check
npm run db:migrate:status | grep "up-to-date"

# Integration test
npm run test:integration -- --filter="user-registration"
```

### Forbidden Patterns

```bash
# TOO VAGUE - no specific target
npm test

# MANUAL - not executable
"Visually verify the UI renders correctly"

# PLACEHOLDER - not complete
[TODO: add verification]

# DEPENDENT ON HUMAN - not automatable
"Ask QA to verify"
```

## Output Validation Checklist

After generating the atomic structure, validate:

- [ ] `index.md` exists with complete navigation
- [ ] `traceability.md` exists with 100% coverage
- [ ] `tasks/` directory exists
- [ ] Each task file has:
  - [ ] Unique ID (T-XXX-name format)
  - [ ] Requirement Mapping (FR-XXX reference)
  - [ ] Technical Implementation Detail (file paths)
  - [ ] Verification Command (executable, no placeholders)
- [ ] No orphan tasks (every task maps to a requirement)
- [ ] No uncovered requirements (every requirement has tasks)
- [ ] Task dependencies form a valid DAG (no cycles)

## Handoff to Implementation

When task generation is complete:

1. **Update index.md**: Set phase to "Implementation", populate task counts
2. **Verify traceability.md**: Confirm 100% coverage
3. **Ready for `/atomicspec.implement`**

### Context Pinning Reminder

Per Constitution Article IX, Directive 3:

During implementation, the AI may ONLY read:
- `index.md` (for navigation)
- The specific `T-XXX-[name].md` file for the current task
- `traceability.md` (to update status)

**FORBIDDEN**: Reading `plan.md` during implementation phase.
