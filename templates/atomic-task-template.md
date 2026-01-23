# Task: [ID] - [NAME]

**User Story**: [STORY ID] (e.g., US1)
**Requirement**: [REQ ID] (e.g., FR-005)
**Station Reference**: [e.g., Station 04 for API rules]

## 🎯 Objective

[Specific, atomic goal of this single task]

## 🛠️ Implementation Details

<!--
  CONTEXT PINNING:
  This section contains ALL the info needed to write code.
  Do not look at plan.md.
-->

### Files to Create

<!--
  List NEW files this task creates from scratch.
  Include the full path from repo root.
-->

- `src/path/to/new-file.ts` - [purpose of this file]
- `tests/path/to/new-test.ts` - [what it tests]

### Files to Update (REQUIRED)

<!--
  ⚠️ CRITICAL: This section prevents orphan code.

  If you create a new file, something MUST import/use it.
  List ALL existing files that need changes to wire in the new code.

  If this section is empty, ask: "How will users access this feature?"
-->

- `src/main.ts` - [what to add, e.g., "Register new router"]
- `src/components/Navigation.tsx` - [what to add, e.g., "Add link to new page"]
- `src/stores/index.ts` - [what to add, e.g., "Export new store"]

### Code/Logic Requirements

- [Requirement 1]
- [Requirement 2]
- [Input/Output signature]
- [Station Rule: e.g., "Must use tenant_id in query"]

## 🔌 Wiring Checklist

<!--
  Check all that apply. If any are checked, the "Files to Update" section
  MUST contain the corresponding file.
-->

- [ ] **Backend route** → Registered in main app/router file
- [ ] **Frontend page** → Added to app router configuration
- [ ] **Navigation** → Link added to sidebar/nav component
- [ ] **API endpoint** → Frontend store/hook calls this endpoint
- [ ] **Component** → Rendered by a parent component
- [ ] **Database model** → Migration created
- [ ] **Environment var** → Added to .env.example

## ✅ Verification

**Command**: `[Exact command to run]`
**Success Criteria**: [What output confirms success]

### Integration Verification (if wiring items checked)

<!--
  If this task includes wiring, add verification that the wiring works.
-->

```bash
# Example: Verify route is accessible
curl -s http://localhost:8000/api/new-endpoint | jq '.status'

# Example: Verify page is navigable
curl -s http://localhost:3000/new-page | grep -q "Expected Title"
```

## 📝 Completion Log

- [ ] Code implemented
- [ ] Tests passed
- [ ] Linter passed
- [ ] Wiring checklist verified
- [ ] Integration verification passed
