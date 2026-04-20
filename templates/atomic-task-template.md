# Task: [ID] - [NAME]

**Status**: Pending
**Created**: [DATE] | **Completed**: N/A
**User Story**: [STORY ID] (e.g., US1)
**Requirement**: [REQ ID] (e.g., FR-005)

---

## 📋 Embedded Context (READ THIS FIRST)

<!--
  SELF-CONTAINED TASK (Constitution Directive 8):
  This section contains ALL context needed to implement this task.
  Do NOT read plan.md, spec.md, stations, or subagents.

  If this section is empty or insufficient, report as task quality issue.
-->

### Project Standards (from registry)

<!--
  Extracted from specs/_defaults/registry.yaml during /atomicspec.tasks
  If no registry exists, this section will note "No registry - using plan.md decisions"
-->

| Key | Value |
|-----|-------|
| `architecture.pattern` | [e.g., monolith, microservices] |
| `architecture.layers` | [e.g., clean, vertical_slice, mvc] |
| `code_patterns.data_access` | [e.g., repository, active_record, query_builder] |
| `code_patterns.error_handling` | [e.g., exceptions, result_type, error_codes] |
| `code_patterns.validation_approach` | [e.g., schema, manual, decorator] |
| `database.tenancy_model` | [e.g., shared_db_tenant_id, separate_schema] |
| `conventions.files` | [e.g., kebab-case, snake_case, PascalCase] |
| `conventions.variables` | [e.g., camelCase, snake_case] |

### Domain Rules (from subagent/station)

<!--
  Extracted from relevant .specify/subagents/[domain].md or
  .specify/knowledge/stations/[XX]-[domain].md during /atomicspec.tasks

  If no domain knowledge exists, note: "No domain knowledge - using plan.md decisions"
-->

- **[Rule Category]**: [Rule description]
- **[Rule Category]**: [Rule description]
- **Example**: Tenancy: Every query MUST filter by `tenant_id`
- **Example**: No naked queries: All DB access through repository methods only

### API Context (from contracts/)

<!--
  Extracted from FEATURE_DIR/contracts/ if this task involves API endpoints.
  If no contracts exist or not applicable, this section can be removed.
-->

```yaml
# Relevant endpoints for this task
[METHOD] [PATH] → [function](params)
```

### Feature Summary

<!--
  One paragraph summarizing the feature this task belongs to.
  Extracted from plan.md during /atomicspec.tasks generation.
-->

[Brief description of the feature and its purpose]

### Gate Criteria (from subagent/station)

<!--
  Checklist items extracted from the relevant subagent or station.
  These MUST be verified before marking the task complete.
-->

- [ ] [Gate criterion 1]
- [ ] [Gate criterion 2]
- [ ] [Gate criterion 3]

---

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

  Use the section matching your platform. Skip sections that don't apply.
-->

### Web (React/Vue/Next.js/etc.)
- [ ] **Backend route** → Registered in main app/router file
- [ ] **Frontend page** → Added to app router configuration
- [ ] **Navigation** → Link added to sidebar/nav component
- [ ] **API endpoint** → Frontend store/hook calls this endpoint
- [ ] **Component** → Rendered by a parent component

### iOS Native (Swift/SwiftUI)
- [ ] **View/Screen** → Added to NavigationStack/NavigationView
- [ ] **Tab bar item** → Added to TabView (if top-level feature)
- [ ] **Deep link route** → Registered in onOpenURL handler
- [ ] **Entitlement** → Added to .entitlements file (push, IAP, etc.)
- [ ] **Permission** → NS*UsageDescription added to Info.plist
- [ ] **StoreKit config** → Product IDs added (if IAP)

### Android Native (Kotlin/Compose)
- [ ] **Activity/Fragment** → Registered in AndroidManifest.xml
- [ ] **Composable route** → Added to NavHost/NavGraph
- [ ] **Navigation item** → Added to BottomNavigation/Drawer
- [ ] **Deep link route** → Intent filter added to manifest
- [ ] **Permission** → Added to AndroidManifest.xml
- [ ] **ProGuard rule** → Added for new dependencies

### React Native
- [ ] **Screen** → Added to Navigator (Stack/Tab/Drawer)
- [ ] **Navigation item** → Added to tab bar or drawer
- [ ] **Deep link route** → Added to linking config
- [ ] **iOS URL scheme** → Added to Info.plist
- [ ] **Android intent filter** → Added to AndroidManifest.xml
- [ ] **Native module** → Linked (pod install + gradle sync)

### Flutter
- [ ] **Route** → Added to MaterialApp routes or GoRouter
- [ ] **Navigation item** → Added to BottomNavigationBar/Drawer
- [ ] **Deep link route** → Added to GoRouter/Navigator config
- [ ] **iOS permission** → Added to Info.plist
- [ ] **Android permission** → Added to AndroidManifest.xml
- [ ] **Dependency** → Added to pubspec.yaml

### Shared (All Platforms)
- [ ] **Database model** → Migration created
- [ ] **Environment var** → Added to .env.example
- [ ] **API client** → Endpoint added to service layer

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
