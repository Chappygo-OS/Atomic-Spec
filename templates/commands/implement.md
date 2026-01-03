---
description: Execute implementation by processing atomic task files one at a time with Context Pinning (Atomic Traceability Model)
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

<!--
  ============================================================================
  CONSTITUTION ARTICLE IX COMPLIANCE: CONTEXT PINNING

  Per Directive 3 (Context Pinning), during implementation you are:

  ALLOWED to read:
  - index.md (for navigation and context)
  - The specific T-XXX-[name].md file for the CURRENT task only
  - traceability.md (to update status after completion)

  FORBIDDEN from reading:
  - plan.md (full technical plan)
  - spec.md (full specification)
  - Other task files not currently being executed

  This prevents context pollution and ensures focused, verifiable execution.
  ============================================================================
-->

## Outline

### 1. Setup & Structure Verification

Run `{SCRIPT}` from repo root and parse FEATURE_DIR.

**Verify Atomic Traceability structure exists**:
- [ ] `FEATURE_DIR/index.md` exists
- [ ] `FEATURE_DIR/traceability.md` exists
- [ ] `FEATURE_DIR/tasks/` directory exists with T-XXX-*.md files

If structure is missing: **STOP** and instruct user to run `/speckit.tasks` first.

### 2. Check Checklists Status

If `FEATURE_DIR/checklists/` exists:
- Scan all checklist files
- Count completed vs incomplete items
- Display status table:

```text
| Checklist | Total | Completed | Incomplete | Status |
|-----------|-------|-----------|------------|--------|
| ux.md     | 12    | 12        | 0          | ✓ PASS |
| test.md   | 8     | 5         | 3          | ✗ FAIL |
```

If any incomplete: Ask user to proceed or wait.

### 3. Load Navigation Context (Context Pinning)

**🛑 CONTEXT PINNING ENFORCED**

Read ONLY these files for context:

1. **Read `index.md`** - Get:
   - Feature summary
   - Current phase
   - Task progress (Total/Completed/In Progress)
   - Active task ID
   - Task queue

2. **Read `traceability.md`** - Get:
   - Pending tasks list
   - Task → Requirement mapping
   - Current coverage status

**DO NOT READ**:
- ❌ `plan.md` - Forbidden during implementation
- ❌ `spec.md` - Forbidden during implementation
- ❌ Other task files - Only read current task

### 4. Task Execution Loop

For each pending task in order:

#### 4.1 Load Current Task

Read ONLY `tasks/T-XXX-[name].md` for the current task.

Extract from task file:
- **Task ID**: T-XXX
- **Requirement Mapping**: FR-XXX links
- **Files to modify**: Exact paths
- **Dependencies**: Prerequisite tasks
- **Implementation Steps**: Specific actions
- **Verification Command**: Exact command to run
- **Acceptance Criteria**: Checklist items

#### 4.2 Verify Dependencies

Check `traceability.md` to confirm all dependency tasks are marked "Done".

If dependencies not met: **SKIP** task, move to next, report blocked status.

#### 4.3 Execute Implementation

Follow the Implementation Steps from the task file:
1. Create/modify files as specified
2. Follow exact paths provided
3. Implement according to acceptance criteria

#### 4.4 Run Verification

Execute the **Verification Command** from the task file.

```bash
# Example: Run the exact command specified in the task
npm test -- --grep "UserModel creates valid user"
```

**If verification passes**:
- Mark task as complete
- Update traceability.md
- Proceed to next task

**If verification fails**:
- Report failure with output
- Ask user: Fix and retry, or skip?
- Do NOT mark as complete

#### 4.5 Update Traceability

After each task completion, update `traceability.md`:
- Set task Status to "Done"
- Set Verified to "Y"
- Add entry to Verification Log
- Update parent Requirement status if all tasks complete

#### 4.6 Update Index

After each task, update `index.md`:
- Increment Completed count
- Update Active Task to next in queue
- Move completed task from queue

### 5. Project Setup Verification

During first Setup phase task, create/verify ignore files:

**Detection & Creation**:
- Git repo → `.gitignore`
- Dockerfile → `.dockerignore`
- ESLint → `.eslintignore`
- Prettier → `.prettierignore`

**Common Patterns by Technology**:
- **Node.js**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
- **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `dist/`
- **Go**: `*.exe`, `*.test`, `vendor/`
- **Rust**: `target/`, `debug/`, `release/`

### 6. Error Handling

**Task Failure**:
- Report which task failed
- Show verification command output
- Offer options: Retry, Skip, Abort

**Dependency Blocked**:
- List blocked tasks
- Show which dependencies are incomplete
- Suggest completing dependencies first

**Context Pinning Violation**:
- If tempted to read plan.md or spec.md: **STOP**
- All needed context is in the current task file
- If task file is insufficient: Report as task quality issue

### 7. Progress Reporting

After each task, report:
```text
✓ T-XXX-[name] completed
  Verification: PASSED
  Progress: [X/N] tasks complete
  Next: T-YYY-[next-task]
```

### 8. Completion

When all tasks in `traceability.md` are "Done":

1. **Final Verification**:
   - All verification commands passed
   - All acceptance criteria met
   - 100% task completion

2. **Update index.md**:
   - Set phase to "Complete"
   - Final task counts

3. **Report Summary**:
   - Total tasks completed
   - Total time (if tracked)
   - Any skipped/blocked tasks
   - Feature ready for review

## Context Pinning Reminder

**During implementation, you may ONLY read**:
- `index.md` - Navigation and status
- Current `T-XXX-[name].md` - Active task details
- `traceability.md` - To update completion status

**FORBIDDEN**:
- Reading `plan.md` during implementation
- Reading `spec.md` during implementation
- Reading task files other than the current one
- Making architectural decisions not in the task file

If you need information not in the current task file, the task file is incomplete. Report this as a task quality issue rather than reading forbidden files.
