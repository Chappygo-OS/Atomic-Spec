---
description: Execute implementation by processing atomic task files one at a time with Context Pinning (Atomic Traceability Model)
scripts:
  sh: scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks --check-gates --gate-context implement
  ps: scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks -CheckGates -GateContext implement
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## ⛔ CONTEXT PINNING RULES

**STOP. Read this section before reading ANY files.**

Per Constitution Article IX, Directive 3, during implementation you are:

| Action | Allowed | Forbidden |
|--------|---------|-----------|
| Read for navigation | `index.md` | N/A |
| Read for current task | `T-XXX-[name].md` (ONE file only) | Other task files |
| Update after completion | `traceability.md` | N/A |
| Read project defaults | `specs/_defaults/registry.yaml` | N/A |
| Read full specs | ❌ NEVER | `plan.md`, `spec.md` |

**If you are about to read plan.md or spec.md, STOP. You are violating Context Pinning.**

## Outline

### 1. Setup & Structure Verification

Run `{SCRIPT}` from repo root. This script will:
1. Parse FEATURE_DIR and available documents
2. **Automatically validate gate criteria** (tasks/, index.md, traceability.md)
3. **BLOCK execution if gates fail** - you will see error output

If the script outputs gate failures, report them to the user and **DO NOT PROCEED**.

### 1.5 Load Project Defaults Registry

**Per Constitution Article IX, Directive 7 - Load registry before implementation.**

Read `specs/_defaults/registry.yaml` to get project-wide implementation standards:

1. **Extract relevant implementation defaults**:
   - `architecture.*` - System pattern, layers (determines code structure)
   - `code_patterns.*` - **CRITICAL**: Data access, DI, error handling, validation
   - `conventions.*` - Naming conventions for code
   - `backend.*` - Language, framework patterns
   - `frontend.*` - Component patterns, styling approach
   - `database.*` - Query style, naming conventions
   - `error_handling.*` - Logging format, correlation headers
   - `testing.*` - Test framework, coverage requirements

2. **Apply during implementation**:
   - Use registry naming conventions for new files/functions
   - Follow registry patterns for code structure
   - If task requires a decision not in task file, check registry first

   **Code patterns drive implementation style**:
   - `code_patterns.data_access: repository` → Use repository interfaces, not direct ORM calls
   - `code_patterns.error_handling: result_type` → Return Result<T,E>, don't throw exceptions
   - `code_patterns.dependency_injection: constructor` → Pass dependencies via constructor
   - `code_patterns.validation_approach: schema` → Use Zod/Yup schemas, not manual checks
   - `architecture.layers: clean` → Separate use cases from entities from interfaces

3. **If implementation would deviate from registry**:
   - The task file should contain explicit DEVIATION block
   - If no DEVIATION block but code pattern differs, flag for review
   - Do NOT silently deviate from registry standards

**Note**: Context Pinning still applies - registry is a reference document, not a planning document.

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

#### 4.2.5 Subagent Context Loading

**Task files contain an embedded configuration section set during task generation.**

1. **Read the Implementation Context section from the CURRENT TASK FILE**:

   ```markdown
   ## Implementation Context
   - Platform: [inherited from plan.md during task generation]
   - Subagents Enabled: [yes/no]
   - Available Subagents: [list relevant to this task's domain and platform]
   ```

   **This maintains Context Pinning compliance - DO NOT read plan.md.**

2. **If Subagents Enabled = "no"**: Skip to 4.3, implement the task yourself.

3. **If Subagents Enabled = "yes"**: Match task to an available agent from the list.

   **Extract domain from current task file**:
   - Check "Domain Rules" section header (e.g., "from data-architecture subagent")
   - Check file paths in "Files to Create" (e.g., `repositories/` → data-architecture)
   - Check task objective keywords

4. **Match to an available subagent via Dynamic Discovery**:

   **Follow `_subagent-discovery.md`** — do NOT hardcode agent names in this step. The discovery protocol scans `.specify/subagents/`, reads YAML frontmatter, and scores each agent's `description` against the task's keywords and file paths. Whichever agent scores highest is the match.

   If no agent scores above the minimum threshold, fall back to the Knowledge Station for the task's domain (via `.specify/knowledge/stations/00-station-map.md`). If neither resolves, implement the task yourself using the embedded context from the task file.

5. **Spawn the matched subagent using Task tool**:

   ```
   Task(
     subagent_type: "[matched-agent-name]",
     prompt: "Implement task T-XXX-[name].

       Read the task file at: [FEATURE_DIR]/tasks/T-XXX-[name].md

       Follow the Embedded Context section for:
       - Project Standards (registry values)
       - Domain Rules (patterns to follow)
       - Gate Criteria (must verify before done)

       Implement the code, run verification command, report result.",
     description: "Implement T-XXX with [agent-name]"
   )
   ```

6. **Handle subagent result**:
   - If subagent reports success → Proceed to 4.4 (verification already done)
   - If subagent reports failure → Report to user, ask for guidance
   - If no agent matches → Fall back to 4.3 (implement yourself)

#### 4.3 Execute Implementation (Fallback / No Subagent)

**Use this section if subagents are disabled OR no agent matches the task domain.**

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

#### 8.1 Integration Verification (MANDATORY)

⚠️ **CRITICAL: This step prevents the #1 cause of "feature done but not working" issues.**

Before marking the feature complete, run platform-appropriate integration checks.

**Step 1: Load Platform from Task Context**

Read platform from the task file's Implementation Context section.
This was set during task generation and reflects the project's platform.

**DO NOT re-read registry - the task file is authoritative for this implementation.**

```markdown
## Implementation Context
- Platform: [web/mobile/both]
- Mobile Framework: [native/react-native/flutter] (if mobile)
- Mobile Platforms: [ios/android/both] (if mobile)
```

Based on the Implementation Context:
- If Platform = `web` → Run Web Integration checks
- If Platform = `mobile` → Check Mobile Framework:
  - `native` + `ios` → Run iOS Native checks
  - `native` + `android` → Run Android Native checks
  - `react-native` → Run React Native checks
  - `flutter` → Run Flutter checks
- If Platform = `both` → Run Web + appropriate Mobile checks

---

##### Web Integration (Default)

```bash
# Backend: Verify all routes are registered (Python/FastAPI example)
grep -r "include_router\|app.add_api_route" backend/main.py backend/app.py 2>/dev/null

# Backend: Verify API docs accessible
curl -s http://localhost:8000/api/docs | grep -q "openapi" && echo "API docs accessible"

# Frontend: Verify all pages are in router
grep -r "Route\|path:" frontend/src/App.tsx frontend/src/router 2>/dev/null

# Frontend: Verify navigation has links to new pages
grep -r "href=\|to=\|navigate(" frontend/src/components/*Nav* frontend/src/components/*Sidebar* 2>/dev/null
```

**Web Wiring Checklist:**
- [ ] All backend routes registered in main app file
- [ ] All frontend pages accessible via navigation
- [ ] All API endpoints callable from frontend stores/hooks
- [ ] No orphan components (everything rendered somewhere)
- [ ] No dead routes (all routes lead to working pages)
- [ ] Navigation reflects all user-facing features

---

##### iOS Native Integration

```bash
# Navigation: Verify views are in navigation stack
grep -rE "NavigationStack|NavigationView|NavigationLink|UINavigationController" ios/ --include="*.swift" 2>/dev/null

# Deep Links: Verify URL schemes configured
grep -rE "CFBundleURLSchemes|CFBundleURLTypes" ios/ --include="*.plist" 2>/dev/null
# OR for SwiftUI App structure
grep -rE "onOpenURL|\.onContinueUserActivity" ios/ --include="*.swift" 2>/dev/null

# Entitlements: Verify capabilities configured (if feature requires them)
grep -rE "aps-environment|com\.apple\.developer" ios/ --include="*.entitlements" 2>/dev/null

# Permissions: Verify Info.plist has required usage descriptions
grep -rE "NS.*UsageDescription" ios/ --include="*.plist" 2>/dev/null

# Build Verification: Verify project builds for simulator
xcodebuild -scheme [SCHEME] -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -5

# TestFlight Readiness (if applicable)
xcodebuild -scheme [SCHEME] -configuration Release archive -archivePath build/App.xcarchive 2>&1 | grep -E "ARCHIVE SUCCEEDED|error:"
```

**iOS Wiring Checklist:**
- [ ] All views accessible via NavigationStack/NavigationView
- [ ] Tab bar items added for new top-level features
- [ ] Deep link routes registered (if URL scheme used)
- [ ] Required entitlements added (Push, IAP, etc.)
- [ ] Info.plist has all required permission descriptions
- [ ] App builds without errors for simulator
- [ ] No missing asset catalog entries
- [ ] StoreKit configuration file present (if IAP feature)

**iOS Tool Availability Handling:**
```bash
# Check if Xcode tools available
if ! command -v xcodebuild &> /dev/null; then
    echo "WARN: xcodebuild not available - skipping build verification"
    echo "Manual verification required: Open project in Xcode and build"
fi
```

---

##### Android Native Integration

```bash
# Manifest: Verify all activities/services registered
grep -rE "<activity|<service|<receiver|<provider" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Navigation: Verify composable routes (Jetpack Compose)
grep -rE "composable\(|NavHost|navController" android/ --include="*.kt" 2>/dev/null
# OR for XML navigation
grep -rE "<fragment|<action|app:destination" android/ --include="*.xml" 2>/dev/null

# Deep Links: Verify intent filters configured
grep -rE "intent-filter|android:scheme|android:host" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Permissions: Verify required permissions declared
grep -rE "uses-permission" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Build Verification: Verify project builds
./gradlew assembleDebug 2>&1 | tail -10

# Signing: Verify release signing configured (for Play Console readiness)
grep -rE "signingConfigs|storeFile|keyAlias" android/app/build.gradle* 2>/dev/null

# Play Console Readiness (if applicable)
./gradlew bundleRelease 2>&1 | grep -E "BUILD SUCCESSFUL|BUILD FAILED"
```

**Android Wiring Checklist:**
- [ ] All activities registered in AndroidManifest.xml
- [ ] Navigation graph includes all screens
- [ ] Deep link intent filters configured (if applicable)
- [ ] Required permissions declared in manifest
- [ ] Bottom navigation/drawer updated for new features
- [ ] ProGuard/R8 rules added for new dependencies
- [ ] App builds without errors (assembleDebug)
- [ ] Release signing configured (if publishing)
- [ ] Billing client configured (if IAP feature)

**Android Tool Availability Handling:**
```bash
# Check if Gradle wrapper available
if [ ! -f "./gradlew" ]; then
    echo "WARN: gradlew not found - skipping build verification"
    echo "Manual verification required: Open project in Android Studio and build"
fi
```

---

##### React Native Integration (Both Platforms)

```bash
# Navigation: Verify screens in navigation structure
grep -rE "Screen|createStackNavigator|createBottomTabNavigator|NavigationContainer" src/ --include="*.tsx" --include="*.ts" 2>/dev/null

# Deep Links: Verify linking configuration
grep -rE "linking:|prefixes:|config:" src/ --include="*.tsx" --include="*.ts" 2>/dev/null

# iOS: Verify URL schemes in Info.plist
grep -rE "CFBundleURLSchemes" ios/ --include="*.plist" 2>/dev/null

# Android: Verify intent filters in manifest
grep -rE "intent-filter|android:scheme" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Native Modules: Verify linked properly
npx react-native config 2>&1 | grep -E "dependencies|Missing"

# Metro Bundle: Verify JS bundle builds
npx react-native bundle --entry-file index.js --platform ios --dev false --bundle-output /tmp/test.bundle 2>&1 | tail -5

# iOS Build Test
npx react-native run-ios --simulator="iPhone 15" 2>&1 | grep -E "success|error|BUILD"
# OR
cd ios && xcodebuild -workspace *.xcworkspace -scheme [SCHEME] build 2>&1 | tail -5

# Android Build Test
npx react-native run-android 2>&1 | grep -E "BUILD SUCCESSFUL|BUILD FAILED"
# OR
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

**React Native Wiring Checklist:**
- [ ] All screens registered in navigation container
- [ ] Tab/drawer navigation updated for new features
- [ ] Deep linking config includes new routes
- [ ] iOS Info.plist has URL schemes (if deep links)
- [ ] Android manifest has intent filters (if deep links)
- [ ] Native modules linked (pod install + gradle sync)
- [ ] Metro bundler builds without errors
- [ ] iOS simulator build succeeds
- [ ] Android emulator build succeeds
- [ ] Environment variables in .env (if using react-native-config)

**React Native Tool Availability Handling:**
```bash
# Check for RN CLI
if ! command -v npx &> /dev/null; then
    echo "WARN: npx not available - skipping RN build verification"
fi

# Check for iOS tools (macOS only)
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "INFO: iOS verification skipped (not on macOS)"
fi
```

---

##### Flutter Integration (Both Platforms)

```bash
# Navigation: Verify routes defined
grep -rE "MaterialPageRoute|GoRoute|routes:|onGenerateRoute" lib/ --include="*.dart" 2>/dev/null

# Deep Links: Verify GoRouter or Navigator 2.0 deep link handling
grep -rE "GoRouter|redirect:|onDeepLink|uriLinkStream" lib/ --include="*.dart" 2>/dev/null

# iOS: Verify URL schemes
grep -rE "CFBundleURLSchemes" ios/ --include="*.plist" 2>/dev/null

# Android: Verify intent filters
grep -rE "intent-filter|android:scheme" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Permissions: iOS Info.plist
grep -rE "NS.*UsageDescription" ios/ --include="*.plist" 2>/dev/null

# Permissions: Android manifest
grep -rE "uses-permission" android/app/src/main/AndroidManifest.xml 2>/dev/null

# Analyze: Check for issues
flutter analyze 2>&1 | tail -20

# Build iOS (macOS only)
flutter build ios --debug --no-codesign 2>&1 | grep -E "Built|Error"

# Build Android
flutter build apk --debug 2>&1 | grep -E "Built|Error"

# Test
flutter test 2>&1 | tail -10
```

**Flutter Wiring Checklist:**
- [ ] All routes registered in MaterialApp/GoRouter
- [ ] Bottom navigation/drawer includes new features
- [ ] Deep link routes configured (if applicable)
- [ ] iOS URL schemes in Info.plist (if deep links)
- [ ] Android intent filters in manifest (if deep links)
- [ ] iOS permission descriptions in Info.plist
- [ ] Android permissions in manifest
- [ ] `flutter analyze` passes with no errors
- [ ] iOS build succeeds (--no-codesign for CI)
- [ ] Android APK build succeeds
- [ ] Pubspec.yaml has all required dependencies

**Flutter Tool Availability Handling:**
```bash
# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "WARN: flutter not available - skipping Flutter verification"
    echo "Install Flutter: https://docs.flutter.dev/get-started/install"
fi

# Check Flutter doctor
flutter doctor --android-licenses 2>&1 | grep -E "licenses accepted|error"
```

---

##### Graceful Degradation (All Platforms)

When verification tools are unavailable:

1. **Log the skip**: `echo "WARN: [tool] not available - verification skipped"`
2. **Document manual steps**: Add to completion report what needs manual verification
3. **Do NOT fail the feature**: Missing tools = deferred verification, not blocking failure
4. **Create follow-up task**: If build tools missing, note "Verify build on CI" as pending item

**Example Graceful Output:**
```text
Integration Verification Results:
- [x] Navigation wiring: PASSED (grep found all routes)
- [ ] iOS build: SKIPPED (xcodebuild not available)
- [ ] Android build: SKIPPED (not on macOS/Linux with Android SDK)
- [x] Deep links: PASSED (URL schemes configured)

Manual verification required:
- Build and run on iOS simulator
- Build and run on Android emulator
```

---

**If ANY wiring check fails:**
1. Identify which task should have done the wiring
2. Create a fix task or update the incomplete task
3. Do NOT mark feature complete until wiring is verified

#### 8.2 Final Verification

1. **Task Verification**:
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
   - Integration verification status
   - Feature ready for review

### 9. Registry Sync — On Exit (MANDATORY)

> ⛔ **Do NOT begin Phase 9 until all tasks in Phases 1–8 are marked `DONE` in `index.md`.** Do NOT read `plan.md` or `registry.yaml` during any task in Phases 1–8 — the Context Pinning exception below is scoped to Phase 9 only and does not activate until every preceding task is complete.

**Per Constitution Article IX, Directive 7 "Protocol — On Exit"** — feature-level registry sync is required after every successful implementation. This is what keeps the registry accurate as the codebase evolves; without it, the registry freezes at plan time and drifts over subsequent features.

This step satisfies the "On Exit" obligation for the implement phase. It runs ONCE at feature completion, not per-task. Task-loop momentum is preserved.

**Exception to Context Pinning**: this phase is the ONLY implement-phase operation permitted to read `plan.md` — specifically to extract the registry-relevant decisions recorded during planning. Scan only the Tech Stack / Decisions sections; do NOT re-read requirements or specs. This exception exists because registry sync is definitionally a cross-task operation and cannot be self-contained in a single task file.

#### 9.1 Scan the implementation for new project-wide patterns

Review the completed work for decisions that APPLY PROJECT-WIDE (not feature-specific). Signals to look for:

| Signal in code/config | Registry candidate |
|----------------------|--------------------|
| Every query filters by `tenant_id` / `org_id` | `database.tenancy_model = shared_db_tenant_id` |
| New ORM / data-access pattern used consistently | `backend.orm`, `code_patterns.data_access` |
| New auth middleware or JWT pattern | `backend.auth_method`, `backend.auth_pattern` |
| New logging format (structured JSON, correlation IDs) | `error_handling.logging_format`, `error_handling.correlation_header` |
| New error-response envelope adopted | `api.error_format`, `api.response_envelope` |
| New testing framework / helpers introduced | `testing.unit_framework`, `testing.integration_framework`, `testing.mocking` |
| New rate-limit / caching middleware | `api.rate_limiting`, `backend.cache` |
| New migration tool adopted | `database.migration_strategy` |
| New secret-management pattern | `infrastructure.secrets` |
| New CI workflow added | `infrastructure.ci_cd`, `infrastructure.deployment_strategy` |
| Consistent directory/file naming across new code | `conventions.files`, `conventions.variables` |

Compare each signal against the current registry (read `specs/_defaults/registry.yaml`). A signal is a CANDIDATE if:
- Its registry field is `null` OR
- Its registry field has a different value AND the code legitimately deviates from it (this is a deviation-documentation case, not a registry update)

Filter out feature-specific details. If something was true only for this feature, it does NOT belong in the registry.

#### 9.2 Present candidates for HITL confirmation

If there are no candidates, skip to 9.4 and report "registry sync: no new candidates."

Otherwise, present a single table:

```
Post-implementation registry sync — candidates:

┌────────────────────────────────┬────────────────────────┬──────────────────────────────────────┐
│ Registry Field                 │ Proposed Value         │ Evidence                             │
├────────────────────────────────┼────────────────────────┼──────────────────────────────────────┤
│ database.tenancy_model         │ shared_db_tenant_id    │ 7 queries in src/users/ filter tid   │
│ error_handling.logging_format  │ structured             │ logger.ts switched to pino JSON      │
│ api.error_format               │ rfc7807                │ All new endpoints return Problem+JSON│
│ testing.integration_framework  │ supertest              │ Added in T-020, used by 4 tests      │
└────────────────────────────────┴────────────────────────┴──────────────────────────────────────┘
```

Use `AskUserQuestion` with these choices:

- **Add all to registry** — accept every candidate as shown
- **Select which to add** — user lists specific row numbers
- **Skip — keep feature-specific** — mark everything as feature-scoped, no registry update

For each accepted candidate, verify the proposed value with the user if any ambiguity exists. Allow `custom: <value>` as an override per row.

#### 9.3 Atomic write + audit trail

For every accepted candidate, perform an atomic update:

1. Read current `specs/_defaults/registry.yaml`
2. Merge accepted values in memory (do NOT touch fields not in the candidate set)
3. Update metadata: `last_updated: YYYY-MM-DD`, `last_updated_by: human`, append the current feature slug to `applied_to`
4. Write to `registry.yaml.tmp`, verify it is well-formed (re-read and check for YAML syntax errors), then write `registry.yaml` from the same content and delete `registry.yaml.tmp` (AI agents may not have a rename tool; explicit write + delete achieves the same atomicity guarantee)
5. Append to `specs/_defaults/changelog.md`:

```markdown
## [YYYY-MM-DD] — Registry sync after implementing <feature-slug>

- **Changed**: `database.tenancy_model`: null → `shared_db_tenant_id`
  - **Why**: 7 queries in src/users/ filter by tenant_id; pattern is project-wide
  - **Source**: /atomicspec.implement Phase 9 sync (feature: 001-user-onboarding)
  - **Approved by**: Human (Add all, Phase 9.2)
```

#### 9.4 Report

Final summary to the user:

```
Registry sync complete.
  Candidates detected: 4
  Added to registry: 3
  Skipped (feature-specific): 1
  Registry file: specs/_defaults/registry.yaml (last_updated: 2026-04-24)
  Audit entry: specs/_defaults/changelog.md
```

If the user had the registry gate overridden via `ATOMIC_SPEC_NO_REGISTRY=1` at task-gate time, remind them: "registry override was active; consider running /atomicspec.registry to create the registry before the next feature."

## Context Pinning Reminder

**During task execution (Phases 1–8), you may ONLY read**:
- `index.md` - Navigation and status
- Current `T-XXX-[name].md` - Active task details
- `traceability.md` - To update completion status

**FORBIDDEN during task execution**:
- Reading `plan.md` during implementation
- Reading `spec.md` during implementation
- Reading task files other than the current one
- Making architectural decisions not in the task file

**Single carved exception — Phase 9 (Registry Sync on Exit)**:
Phase 9 may read `plan.md` to extract the registry-relevant decisions recorded during planning, and may read `specs/_defaults/registry.yaml` to compute the diff. This exception is scoped to Phase 9 only; it exists because registry sync is inherently cross-task. Phase 9 must NOT read `spec.md` or any task file other than those already completed.

If during Phases 1–8 you need information not in the current task file, the task file is incomplete. Report this as a task quality issue rather than reading forbidden files.
