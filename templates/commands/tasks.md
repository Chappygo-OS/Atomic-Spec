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

**See also**: `.specify/knowledge/_platform-resolution.md` for registry validation requirements.

Read `specs/_defaults/registry.yaml` to ensure tasks follow project standards:

1. **Extract relevant standards for task generation**:
   - `architecture.*` - System pattern, layers (determines task structure)
   - `code_patterns.*` - Data access, DI patterns (affects implementation steps)
   - `conventions.*` - File naming, function naming for task file paths
   - `backend.*` - Language/framework for verification commands
   - `frontend.*` - Framework for component task patterns
   - `database.*` - Query style, naming for database tasks
   - `testing.*` - Test framework for verification commands

2. **Apply to task generation**:
   - Use registry conventions for file paths in tasks (e.g., `kebab-case` vs `snake_case`)
   - Use registry test framework in verification commands (e.g., `npm test` vs `pytest`)
   - Reference registry patterns when specifying implementation steps

3. **Include registry reference in tasks** (when applicable):
   ```markdown
   ### Project Standards (from registry)
   - Architecture: [architecture.pattern], [architecture.layers]
   - Code Patterns: [code_patterns.data_access], [code_patterns.error_handling]
   - Naming: [conventions.files] for files, [conventions.variables] for code
   - Testing: [testing.unit_framework]
   ```

4. **Architecture affects task structure**:
   - `architecture.layers: clean` → Tasks should specify which layer (use case, entity, interface)
   - `architecture.layers: vertical_slice` → Tasks organized by feature folder
   - `code_patterns.data_access: repository` → Include repository interface + implementation tasks
   - `code_patterns.error_handling: result_type` → Verification should check Result returns

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

## Implementation Context

<!--
  This section is set during task generation from plan.md and registry.yaml.
  During /speckit.implement, this is the AUTHORITATIVE source for platform
  and subagent configuration. DO NOT read plan.md or registry during implementation.
-->

- **Platform**: [web/mobile/both - from plan.md Platform field]
- **Mobile Framework**: [native/react-native/flutter - if mobile, else N/A]
- **Mobile Platforms**: [ios/android/both - if mobile, else N/A]
- **Subagents Enabled**: [yes/no - from plan.md Planning Configuration]
- **Available Subagents**: [list from plan.md, filtered to task domain]

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

  Include ONLY the checklist matching the platform from plan.md.
-->

<!--
  ### Wiring Checklist Selection Rule

  Based on platform from plan.md:
  - `web` -> Include ONLY Web checklist
  - `ios` -> Include ONLY iOS Native checklist
  - `android` -> Include ONLY Android Native checklist
  - `react-native` -> Include ONLY React Native checklist
  - `flutter` -> Include ONLY Flutter checklist

  NEVER include all platform checklists in a single task.
  Delete the checklists that do not match the target platform.
-->

**Web:** (include only if platform=web)
- [ ] Route registered in main app file (if backend route)
- [ ] Page added to app router (if frontend page)
- [ ] Navigation link added (if user-facing page)
- [ ] Store/hook connected to API endpoint (if API endpoint)
- [ ] Component rendered by parent (if new component)

**iOS Native:** (include only if platform=ios)
- [ ] View added to NavigationStack/TabView
- [ ] Deep link route in onOpenURL handler
- [ ] Entitlement added (if capability needed)
- [ ] Permission description in Info.plist

**Android Native:** (include only if platform=android)
- [ ] Activity registered in AndroidManifest.xml
- [ ] Screen in NavHost/Navigation graph
- [ ] Permission in manifest (if needed)
- [ ] ProGuard rule (if new dependency)

**React Native:** (include only if platform=react-native)
- [ ] Screen in Navigator (Stack/Tab/Drawer)
- [ ] Deep link in linking config
- [ ] Native module linked (pod install + gradle)

**Flutter:** (include only if platform=flutter)
- [ ] Route in MaterialApp/GoRouter
- [ ] Dependency in pubspec.yaml

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

### Wiring Matrix Platform Selection

Based on platform from plan.md, use ONLY the corresponding matrix:
- `web` -> "Web Platform" matrix
- `ios` -> "iOS Native Platform" matrix
- `android` -> "Android Native Platform" matrix
- `react-native` -> "React Native Platform" matrix
- `flutter` -> "Flutter Platform" matrix

Include ONLY the relevant matrix. Do NOT include all platforms.

*Web Platform:* (include only if platform=web)
| When You Create... | You MUST Also Update... |
|-------------------|------------------------|
| Backend route file (`routes/clients.py`) | Main app file to register router (`main.py`, `app.py`) |
| Frontend page (`pages/clients/page.tsx`) | App router config, navigation component |
| API endpoint | Frontend store/hook to call it |
| New component | Parent component to render it |
| Database model | Migration file, optionally seed data |
| New service | Dependency injection / service registry |
| Environment variable usage | `.env.example`, deployment configs |

*iOS Native Platform:* (include only if platform=ios)
| When You Create... | You MUST Also Update... |
|-------------------|------------------------|
| View/ViewController (`ClientsView.swift`) | NavigationStack, TabView if top-level |
| API service (`ClientsService.swift`) | Dependency container, environment object |
| Core Data model | `.xcdatamodeld` file, generate classes |
| Push notification handler | `AppDelegate` / `UNUserNotificationCenter` setup |
| Deep link handler | `onOpenURL` modifier, URL scheme in Info.plist |
| StoreKit product | `.storekit` configuration file |
| Capability (Push, IAP, etc.) | `.entitlements` file |
| Permission usage | `NS*UsageDescription` in Info.plist |

*Android Native Platform:* (include only if platform=android)
| When You Create... | You MUST Also Update... |
|-------------------|------------------------|
| Activity/Fragment | `AndroidManifest.xml` registration |
| Composable screen (`ClientsScreen.kt`) | `NavHost` routes, BottomNavigation if top-level |
| ViewModel | Hilt/Koin module for DI |
| Room entity | `@Database` entities list, migration |
| Deep link handler | Intent filter in `AndroidManifest.xml` |
| Billing product | Play Console product IDs |
| Permission | `<uses-permission>` in manifest |
| New dependency with reflection | ProGuard/R8 keep rules |

*React Native Platform:* (include only if platform=react-native)
| When You Create... | You MUST Also Update... |
|-------------------|------------------------|
| Screen component (`ClientsScreen.tsx`) | Navigator (Stack/Tab/Drawer) |
| API hook (`useClients.ts`) | Parent component to call it |
| Native module | iOS Podfile (`pod install`), Android gradle |
| Deep link route | Linking config, iOS Info.plist, Android manifest |
| Push notifications | iOS entitlements, Android manifest |
| Environment variable | `.env`, `react-native-config` |

*Flutter Platform:* (include only if platform=flutter)
| When You Create... | You MUST Also Update... |
|-------------------|------------------------|
| Screen widget (`clients_screen.dart`) | MaterialApp routes OR GoRouter |
| Repository/Service | `GetIt`/`Provider` registration |
| Drift/Hive model | Schema version, migration |
| Deep link route | GoRouter paths, iOS/Android configs |
| Platform channel | iOS `AppDelegate`, Android `MainActivity` |
| Package dependency | `pubspec.yaml`, run `flutter pub get` |

**Wiring Task Template:**

For each User Story, the LAST task(s) in its range (T-X37 to T-X39) should be wiring tasks:

**Web Wiring Example:**
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

**iOS Native Wiring Example:**
```markdown
# T-037-wire-us1-navigation

## Task Objective
Add US1 views to navigation stack and tab bar.

## Files to Update (NOT create)
- `App/Navigation/MainTabView.swift` - Add FeatureTab case and view
- `App/Navigation/AppCoordinator.swift` - Register feature navigation flow
- `App/Info.plist` - Add deep link URL scheme (if applicable)

## Verification Command
xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | grep "BUILD SUCCEEDED"
```

**Android Native Wiring Example:**
```markdown
# T-037-wire-us1-navigation

## Task Objective
Add US1 screens to navigation graph and bottom navigation.

## Files to Update (NOT create)
- `app/src/main/java/.../navigation/NavGraph.kt` - Add composable route
- `app/src/main/java/.../ui/BottomNavBar.kt` - Add FeatureTab item
- `app/src/main/AndroidManifest.xml` - Register deep link intent filter (if applicable)

## Verification Command
./gradlew assembleDebug 2>&1 | grep "BUILD SUCCESSFUL"
```

**React Native Wiring Example:**
```markdown
# T-037-wire-us1-navigation

## Task Objective
Add US1 screens to navigator and tab bar.

## Files to Update (NOT create)
- `src/navigation/AppNavigator.tsx` - Add FeatureScreen to Stack.Navigator
- `src/navigation/TabNavigator.tsx` - Add Feature tab
- `src/navigation/linking.ts` - Add feature deep link route

## Verification Command
npx react-native bundle --entry-file index.js --platform ios --dev false --bundle-output /tmp/test.bundle 2>&1 | grep -v "^$"
```

**Flutter Wiring Example:**
```markdown
# T-037-wire-us1-navigation

## Task Objective
Add US1 routes to GoRouter and bottom navigation.

## Files to Update (NOT create)
- `lib/router/app_router.dart` - Add GoRoute for /feature
- `lib/widgets/bottom_nav.dart` - Add Feature destination
- `lib/router/deep_links.dart` - Add feature path (if applicable)

## Verification Command
flutter analyze && flutter build apk --debug 2>&1 | grep "Built"
```

**DO NOT proceed to Section 4.3 until every User Story has wiring tasks.**

#### 4.2.2 Embed Context into Task Files (MANDATORY)

⚠️ **CRITICAL: This section enables self-contained implementation (Constitution Directive 8).**

Per the Knowledge Wiring Plan, during `/speckit.implement`, Context Pinning prevents subagents from reading:
- `plan.md`, `spec.md`
- `.specify/knowledge/stations/*`
- `.specify/subagents/*`
- Other task files

**Therefore, ALL context must be embedded INTO each task file during generation.**

**Context Embedding Process:**

1. **Load Registry Standards** (if `specs/_defaults/registry.yaml` exists):
   ```markdown
   ### Project Standards (from registry)
   | Key | Value |
   |-----|-------|
   | `architecture.pattern` | [value from registry] |
   | `architecture.layers` | [value from registry] |
   | `code_patterns.data_access` | [value from registry] |
   | `code_patterns.error_handling` | [value from registry] |
   | `database.tenancy_model` | [value from registry] |
   | `conventions.files` | [value from registry] |
   ```

   If registry doesn't exist: Note "No registry - using plan.md decisions"

2. **Load Domain Rules** based on task type (DYNAMIC DISCOVERY):

   **⚠️ DO NOT hard-code agent names. Match dynamically.**

   a. **Scan available subagents** at `.specify/subagents/`:
      - List all `*.md` files (exclude files starting with `_`)
      - Read YAML frontmatter to get `name` and `description` for each

   b. **For each task**, extract domain keywords:
      - Task objective keywords (e.g., "create repository", "add API endpoint")
      - Files being created/modified (e.g., `repositories/`, `routes/`, `components/`)
      - Technical terms in implementation steps

   c. **Match task keywords to agent descriptions**:
      - Compare task keywords against each agent's `description` field
      - Select the agent with best keyword overlap
      - **Example matches**:
        - Task creates `repositories/*.ts` → Agent with "database", "data access" in description
        - Task creates `routes/*.ts` → Agent with "API", "REST", "endpoints" in description
        - Task creates `components/*.tsx` → Agent with "frontend", "UI", "components" in description

   d. **Load matched agent and extract**:
      - Key patterns/rules (e.g., "Every query MUST filter by tenant_id")
      - Required checks (e.g., "No naked queries")
      - Gate criteria checklist

   e. **If no agent matches**, try station fallback:
      - Read `.specify/knowledge/stations/00-station-map.md`
      - Find relevant station based on task domain
      - Extract rules from station file

   If neither subagent nor station exists: Note "No domain knowledge - using plan.md decisions"

3. **Load API Context** (if task involves API):
   - Read `FEATURE_DIR/contracts/*.yaml` or `contracts/*.md`
   - Extract relevant endpoint signatures
   - Embed as YAML snippet in task file

4. **Load Feature Summary**:
   - Read `plan.md` (this is during /speckit.tasks, not /speckit.implement)
   - Extract one-paragraph feature summary
   - Embed in task file

5. **Load Gate Criteria**:
   - From the subagent loaded in step 2
   - Extract the "Gate Criteria" checklist
   - Embed as checkboxes in task file

**Graceful Degradation (when knowledge sources don't exist):**

| Missing Source | Action |
|----------------|--------|
| Registry | Embed: "No registry - using plan.md decisions" + extract patterns from plan.md |
| Subagent | Check for full station file, extract key rules |
| Station | Embed: "No domain knowledge available" |
| Contracts | Skip API Context section |
| Everything | Embed plan.md decisions directly, note limited context |

**NEVER fail task generation due to missing knowledge. Always produce tasks with whatever context is available.**

**Example Embedded Context:**

```markdown
## 📋 Embedded Context (READ THIS FIRST)

### Project Standards (from registry)
| Key | Value |
|-----|-------|
| `architecture.layers` | clean |
| `code_patterns.data_access` | repository |
| `code_patterns.error_handling` | result_type |
| `database.tenancy_model` | shared_db_tenant_id |
| `conventions.files` | kebab-case |

### Domain Rules (from data-architecture subagent)
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
This feature implements user management for the multi-tenant SaaS platform,
allowing administrators to create, update, and manage user accounts within
their organization.

### Gate Criteria (from data-architecture subagent)
- [ ] Repository interface defined with tenant-scoped methods
- [ ] No direct ORM calls outside repository
- [ ] All queries filter by tenant_id
- [ ] Audit columns handled automatically
```

#### 4.2.3 Spawn Subagents for Task Generation (IF ENABLED)

**Check plan.md's "Planning Configuration" section first.**

1. **Read the user's subagent preference** from plan.md:

   ```markdown
   ## Planning Configuration
   | Setting | Value |
   |---------|-------|
   | Subagents | Enabled/Disabled |
   | Available Subagents | [list of matched agent names] |
   ```

2. **If Subagents = "Disabled"**: Skip this section, generate tasks yourself.

3. **If Subagents = "Enabled"**: Filter and spawn matched agents.

   **Step 1: Load platform from plan.md**

   Read `FEATURE_DIR/plan.md` and extract the `Platform:` field from header.

   **Step 2: Filter available subagents by platform**

   For each subagent in `.specify/subagents/`:
   - Read frontmatter `platform:` field
   - If platform includes current target OR field is absent (universal) -> INCLUDE
   - If platform does NOT include current target -> EXCLUDE

   Example: Target=ios
   - mobile-developer.md (platform: mobile) -> INCLUDE
   - frontend-developer.md (platform: web) -> EXCLUDE
   - backend-architect.md (no platform) -> INCLUDE (universal)

   **For each task that matches a filtered subagent's domain:**

   ```
   Task(
     subagent_type: "[agent-name-from-filtered-list]",
     prompt: "Generate atomic task file for: [task objective].

       Task ID: T-XXX-[name]
       Requirement: FR-XXX

       Include in task file:
       - Embedded Context section (registry, domain rules, gates)
       - Implementation steps with file paths
       - Verification command

       Use templates/atomic-task-template.md structure.",
     description: "Generate T-XXX with [agent-name]"
   )
   ```

5. **Match tasks to agents dynamically**:

   For each task, check which agent from the "Available Subagents" list matches:
   - Task creates database/models → Agent with "data" in name/description
   - Task creates API/routes → Agent with "backend" or "api" in name/description
   - Task creates UI/components → Agent with "frontend" in name/description
   - Task involves payments → Agent with "payment" in name/description

6. **Spawn agents in parallel** for efficiency:

   ```
   # Multiple tasks can be generated simultaneously
   Task(subagent_type: "data-architecture", prompt: "Generate T-010...", ...)
   Task(subagent_type: "backend-architect", prompt: "Generate T-020...", ...)
   Task(subagent_type: "frontend-developer", prompt: "Generate T-030...", ...)
   ```

7. **Fallback**: If a task doesn't match any available agent, generate it yourself using the embedded context approach from Section 4.2.2.

#### 4.2.4 Platform-Aware Verification Commands (MANDATORY)

**CRITICAL: Verification commands MUST match the project's target platform.**

**See also**: `.specify/knowledge/_platform-resolution.md` for the canonical platform resolution algorithm.

Using `npm test` for an iOS task will cause verification failures. This section ensures every task has executable verification commands appropriate to its platform.

**Step 1: Load Platform from Plan**

Per the canonical platform resolution in `_platform-resolution.md`:
- For /speckit.tasks, plan.md is the **authoritative source**
- If plan.md has no platform recorded, this is an ERROR - do not proceed
- ERROR message: "Plan.md missing Platform: field. Re-run /speckit.plan to set platform."

Read `FEATURE_DIR/plan.md` and extract the `Platform:` field from header.

DO NOT re-detect platform from file patterns - plan.md is authoritative.

The platform value from plan.md will be one of:
- `web` - Web/Node.js application
- `ios` - iOS native application
- `android` - Android native application
- `react-native` - React Native cross-platform
- `flutter` - Flutter cross-platform

**Step 1b: Load Additional Details from Registry (Optional)**

If `specs/_defaults/registry.yaml` exists, read additional context:

```yaml
# Backend language detection (supplements plan.md platform)
backend.language: typescript | python | go | java | csharp | rust
backend.framework: express | fastapi | gin | spring-boot | etc.
```

This provides framework-specific details but does NOT override plan.md platform.

**Step 2: Load Platform Verification Templates**

Read `templates/verification-commands.yaml` and select the appropriate platform section:

| Detected Platform | Template Section | Primary Tools |
|-------------------|------------------|---------------|
| iOS native | `ios.*` | `xcodebuild`, `swift test`, `swiftlint` |
| Android native | `android.*` | `./gradlew`, `adb`, `ktlint` |
| React Native | `react_native.*` | `jest`, `detox`, `npx react-native` |
| Flutter | `flutter.*` | `flutter test`, `dart analyze` |
| Node.js/TypeScript | `web_node.*` | `npm test`, `tsc`, `eslint` |
| Python | `python.*` | `pytest`, `ruff`, `mypy` |
| Go | `go.*` | `go test`, `golangci-lint` |

**Step 3: Generate Platform-Specific Commands**

For each task, select the appropriate verification type and replace placeholders:

| Task Type | Select Template | Replace Placeholders |
|-----------|-----------------|---------------------|
| Model/Entity | `[platform].unit_tests.primary` | `{{TEST_NAME}}`, `{{FILE_PATH}}`, `{{MODULE}}` |
| API Endpoint | `[platform].api_health.primary` | `{{ENDPOINT}}`, `{{PORT}}` |
| UI Component/View | `[platform].unit_tests.primary` + `lint` | `{{TEST_NAME}}`, `{{SCHEME}}` |
| Service/Logic | `[platform].unit_tests.primary` | `{{TEST_NAME}}`, `{{FILE_PATH}}` |
| Database Migration | `[platform].migration.*` | Platform-specific |
| Build/Config | `[platform].build.primary` | `{{SCHEME}}` (iOS), module (Android) |

**Step 4: Include Fallback Commands**

Always include a fallback in case the primary tool is unavailable:

```markdown
## Verification Command

**Primary** (requires swiftlint):
\`\`\`bash
swiftlint lint Sources/Auth/AuthService.swift --strict
\`\`\`

**Fallback** (if swiftlint unavailable):
\`\`\`bash
swift -typecheck Sources/Auth/AuthService.swift
\`\`\`

**Expected Output**: No errors or warnings
```

**Platform-Specific Examples:**

**iOS Task:**
```bash
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MyAppTests/AuthServiceTests \
  | xcpretty
# Expected: Test Succeeded
```

**Android Task:**
```bash
./gradlew test --tests "com.myapp.auth.AuthServiceTest"
# Expected: BUILD SUCCESSFUL
```

**Flutter Task:**
```bash
flutter test --name "AuthService"
# Expected: All tests passed!
```

**Python Task:**
```bash
pytest -xvs -k "test_auth_service"
# Expected: passed
```

**Go Task:**
```bash
go test -v -run "TestAuthService" ./internal/auth/...
# Expected: PASS
```

**Step 5: Embed Detected Platform in Task Context**

Include the detected platform in the task's Embedded Context section:

```markdown
### Project Standards (from registry)
| Key | Value |
|-----|-------|
| `target_platform.primary` | mobile |
| `target_platform.mobile_platforms` | ios |
| `backend.language` | python |
| **Verification Platform** | **ios** (uses xcodebuild, swift test) |
```

**Graceful Degradation:**

| Scenario | Action |
|----------|--------|
| Registry missing | Scan file patterns, default to web_node |
| Platform ambiguous (multiple detected) | Ask user via AskUserQuestion |
| Primary tool unavailable | Use fallback from verification-commands.yaml |
| No fallback exists | Provide manual verification checklist with clear criteria |
| Hybrid project (web + mobile) | Generate platform-specific verification per task type |

**FORBIDDEN: Generating web/Node.js verification commands for mobile tasks.**

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

**Every task MUST have an executable verification command appropriate to the project's platform.**

See Section 4.2.4 for platform detection and `templates/verification-commands.yaml` for complete templates.

### Good Examples by Platform

**Web/Node.js:**
```bash
npm test -- --grep "UserModel creates valid user"
npx tsc --noEmit src/models/user.ts
curl -s http://localhost:3000/api/users | jq '.data | length > 0'
```

**iOS (Swift/Xcode):**
```bash
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MyAppTests/UserModelTests | xcpretty
swift test --filter UserModelTests
swiftlint lint Sources/Models/User.swift --strict
```

**Android (Kotlin/Gradle):**
```bash
./gradlew test --tests "com.myapp.models.UserModelTest"
./gradlew ktlintCheck
./gradlew lintDebug
```

**React Native:**
```bash
npx jest --testNamePattern="UserModel"
npx detox test --configuration ios.sim.debug --testNamePattern "User"
```

**Flutter:**
```bash
flutter test --name "UserModel"
dart analyze lib/models/user.dart
```

**Python:**
```bash
pytest -xvs -k "test_user_model"
ruff check src/models/user.py
mypy src/models/user.py --strict
```

**Go:**
```bash
go test -v -run "TestUserModel" ./internal/models/...
golangci-lint run ./internal/models/user.go
```

### Forbidden Patterns

```bash
# TOO VAGUE - no specific target
npm test
./gradlew test
flutter test

# WRONG PLATFORM - using npm for iOS project
npm test -- --grep "AuthService"  # WRONG for iOS!

# MANUAL - not executable
"Check the UI manually"
"Verify in Xcode that..."

# PLACEHOLDER - not complete
[TODO: add verification]
```

## Context Pinning Reminder

Per Constitution Article IX, Directive 3, the subsequent `/speckit.implement` command will:
- Read ONLY `index.md` for navigation
- Read ONLY the specific `T-XXX-[name].md` for the current task
- Update `traceability.md` after each completion
- **NEVER** read the full `plan.md` during implementation

Context for task generation: {ARGS}
