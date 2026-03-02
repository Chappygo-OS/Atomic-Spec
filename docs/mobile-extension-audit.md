# Mobile Extension Plan - Audit Report

**Audited**: 2026-03-02
**Status**: Critical issues identified - Plan needs revision before implementation

---

## Executive Summary

The mobile extension plan has **significant gaps** that will cause platform confusion. The AI can easily:
1. Match web agents when mobile agents are needed
2. Generate web verification commands for mobile tasks
3. Skip mobile-only stations entirely
4. Collect incompatible tech stack decisions

**Total Issues Found**: 31 problems across 8 categories
- **Critical**: 12 (will break mobile workflow)
- **High**: 11 (will cause confusion/rework)
- **Medium**: 8 (will degrade quality)

---

## PART 1: GAPS IN THE PLAN ITSELF

### 1.1 Missing: Platform Context Persistence

**Issue**: Plan says "Store in spec.md header: `platform: mobile`" but doesn't define:
- How this value flows through ALL subsequent phases
- Where it's read by each command
- How it's enforced in subagent matching

**Risk**: Platform detected in `/speckit.specify`, forgotten by `/speckit.tasks`.

**Fix Needed**: Add explicit "Platform Context Propagation" section showing:
```
spec.md header → plan.md reads → registry stores → tasks.md reads → implement.md reads
```

---

### 1.2 Missing: "Both" Platform Handling

**Issue**: Plan mentions `target_platform.primary: web | mobile | both` but never explains:
- What happens when platform is "both"?
- Do we generate TWO sets of tasks?
- Which stations load?
- How do wiring checklists work?

**Risk**: User selects "both" (common for apps with web + mobile). Undefined behavior.

**Fix Needed**: Add section "Multi-Platform Projects" covering:
- Shared backend (same for both)
- Separate frontend tracks (web tasks + mobile tasks)
- Cross-platform frameworks (React Native serving both)

---

### 1.3 Missing: Station Override Mechanism

**Issue**: Plan says "Load platform-specific station variants" but doesn't define:
- HOW does the AI know to load `09-billing-mobile.md` instead of base `09-billing.md`?
- What file tells it the mapping?
- What happens if variant is missing?

**Current state**: Base stations 01-18 exist in `.specify/knowledge/stations/`. Plan adds variants in `platforms/mobile/`. But **no mechanism connects them**.

**Risk**: AI loads base Station 09 (Stripe), ignores mobile variant (IAP).

**Fix Needed**: Define `_platform-registry.yaml` schema with explicit station_overrides:
```yaml
mobile:
  station_overrides:
    09: "platforms/mobile/09-billing-mobile.md"  # Instead of stations/09-billing.md
```

---

### 1.4 Missing: Subagent Platform Tags

**Issue**: Plan creates 7 new mobile subagents but doesn't define:
- How are they distinguished from web subagents?
- What prevents `frontend-developer` (web) from matching React Native tasks?

**Risk**: Agent catalog has 32 agents. Keyword matching picks wrong platform's agent.

**Fix Needed**: Add platform tag to subagent frontmatter:
```yaml
---
name: ios-developer
platform: ios           # NEW FIELD
description: ...
---
```

Then update matching logic: "Only match agents where `platform` matches spec platform OR platform is null (generic)."

---

### 1.5 Missing: Verification Command Templates by Platform

**Issue**: Plan says "Add mobile verification commands" but only shows 2 examples:
- `xcodebuild` for iOS
- `./gradlew` for Android

**What's missing**:
- Full verification command templates per platform
- How tasks.md knows which to embed
- Fallback when command unavailable

**Fix Needed**: Create verification command templates:
```yaml
# In _platform-registry.yaml or separate file
verification_templates:
  web:
    unit_test: "npm test -- --grep \"{test_name}\""
    build: "npm run build"
    lint: "npm run lint"
    type_check: "npx tsc --noEmit"
    api_health: "curl -s http://localhost:{port}/health"
  ios:
    unit_test: "xcodebuild test -scheme {scheme} -destination 'platform=iOS Simulator,name=iPhone 15'"
    build: "xcodebuild -scheme {scheme} build"
    lint: "swiftlint lint"
  android:
    unit_test: "./gradlew test{module}DebugUnitTest"
    build: "./gradlew assemble{module}Debug"
    lint: "./gradlew lint"
  flutter:
    unit_test: "flutter test test/{test_file}"
    build: "flutter build apk --debug"
    lint: "flutter analyze"
  react_native:
    unit_test: "npm test -- {test_pattern}"
    build_ios: "npx react-native run-ios --simulator='iPhone 15'"
    build_android: "npx react-native run-android"
```

---

### 1.6 Missing: Mobile-Only Stations in Planning Phase

**Issue**: Plan lists M01-M06 as "mobile-only stations" but doesn't explain:
- WHEN are they loaded? Phase 0.1? Phase 1?
- Are they MANDATORY for all mobile projects?
- What if user doesn't need push notifications?

**Risk**: AI loads all 6 mobile stations for simple app. Overkill. Or loads none. Missing critical steps.

**Fix Needed**: Define conditional loading rules:
```yaml
mobile_stations:
  M01-push-notifications:
    load_when: "spec mentions push, notification, alert, engagement"
    mandatory: false
  M02-offline-sync:
    load_when: "spec mentions offline, sync, local storage, cache"
    mandatory: false
  M06-app-store-review:
    load_when: "platform is ios OR android"
    mandatory: true  # ALWAYS needed for store apps
```

---

### 1.7 Missing: Phase 0.85 Question Details

**Issue**: Plan says "Add Phase 0.85: Mobile Configuration HITL" with 3 questions but doesn't provide:
- Full AskUserQuestion format
- All options with descriptions
- Registry keys to store answers

**Risk**: Implementation guesses question format. Inconsistent with other HITL phases.

**Fix Needed**: Full specification:
```markdown
### Phase 0.85: Mobile Configuration Checkpoint (HITL)

**Question 1**:
```
Question: "How will you handle in-app purchases?"
Header: "Billing"
Options:
  - Label: "RevenueCat (Recommended)"
    Description: "Abstraction over StoreKit/Play Billing - simpler integration"
  - Label: "Native StoreKit 2 + Play Billing"
    Description: "Direct Apple/Google APIs - more control, more complexity"
  - Label: "Web-only payments"
    Description: "Link to web for purchases - avoids store fees"
  - Label: "No purchases"
    Description: "Free app, no monetization"
```
Registry key: `mobile.iap_framework`
```

---

### 1.8 Missing: Task Numbering for Mobile

**Issue**: Plan shows mobile task ranges (T-040-049 for push, T-050-059 for offline) but current `tasks.md` has different numbering:
- T-001-009: Setup
- T-010-019: Foundation
- T-020-036: US1
- T-037-039: US1 Wiring
- etc.

**Risk**: Mobile ranges conflict with existing scheme. Which takes precedence?

**Fix Needed**: Define integrated numbering OR platform-prefixed numbering:
```
Option A: Platform prefix
  WEB-001, WEB-020, etc.
  IOS-001, IOS-020, etc.
  AND-001, AND-020, etc.

Option B: Extended ranges
  T-001-099: Shared (current)
  T-100-199: Web-specific
  T-200-299: iOS-specific
  T-300-399: Android-specific
  T-400-499: Cross-platform
```

---

## PART 2: CONFUSION POINTS IN CURRENT TEMPLATES

### 2.1 CRITICAL: Phase 0.8 Hardcodes Web Frameworks

**File**: `templates/commands/plan.md` lines 555-743
**Issue**: Frontend/UI HITL checkpoint only shows web options:
- UI Libraries: "Tailwind CSS", "Material UI", "Shadcn/ui", "Chakra UI"
- State Mgmt: "React Context", "Zustand", "Redux", "TanStack Query"
- Forms: "React Hook Form", "Formik"

**What happens for mobile**: User building iOS app reaches Phase 0.8. Sees only web options. Must select "Other" for everything. No guidance.

**Fix**: Branch Phase 0.8 by platform:
```
IF registry.platform.type == "web":
  Show current web options
ELSE IF registry.platform.type == "ios":
  UI: "SwiftUI (Recommended)", "UIKit"
  State: "Observable/ObservedObject", "The Composable Architecture", "Combine"
  Navigation: "NavigationStack", "UINavigationController"
ELSE IF registry.platform.type == "android":
  UI: "Jetpack Compose (Recommended)", "XML Views"
  State: "ViewModel + StateFlow", "MVI", "Redux"
  Navigation: "Navigation Compose", "Fragment Navigation"
```

---

### 2.2 CRITICAL: Verification Commands Assume Node.js

**File**: `templates/commands/tasks.md` lines 493-525
**Issue**: All verification examples are web/Node.js:
- `npm test -- --grep "test name"`
- `curl -s http://localhost:8000/api/endpoint`
- `npx tsc --noEmit`
- `npm run lint`

**What happens for mobile**: Task generator creates iOS task. Embeds `npm test` command. iOS developer can't run it.

**Fix**: Add platform-conditional verification templates in Section 4.2.2.

---

### 2.3 CRITICAL: Integration Verification is Web-Only

**File**: `templates/commands/implement.md` lines 287-324
**Issue**: Integration checks assume:
- `grep -r "include_router"` - Python/FastAPI
- `curl http://localhost:8000/api/docs` - Local HTTP server
- `grep -r "Route"` in frontend - React Router
- `frontend/src/App.tsx` - React file structure

**What happens for mobile**: Mobile feature completes. Integration verification runs. All checks fail or are skipped. Feature marked "done" without actual verification.

**Fix**: Add mobile integration verification:
```markdown
**Mobile Integration (if platform = mobile):**
```bash
# iOS - Verify all view controllers are in storyboard/navigation
grep -r "NavigationStack\|NavigationView\|UINavigationController" ios/

# Android - Verify all activities are in manifest
grep -r "activity.*android:name" android/app/src/main/AndroidManifest.xml

# Verify deep links configured
grep -r "CFBundleURLSchemes\|intent-filter.*VIEW" ios/ android/
```
```

---

### 2.4 HIGH: Subagent Matching Has No Platform Filter

**File**: `templates/commands/plan.md` lines 246-260
**Issue**: Agent matching is keyword-only:
```
Spec mentions "React components" → Agent with "components, UI, frontend" → Match
```

**Problem**: "React components" could mean:
- React web components
- React Native components

Both match `frontend-developer` agent, which has web expertise.

**Fix**: Two-stage matching:
1. Filter agents by platform compatibility
2. Then match by domain keywords

---

### 2.5 HIGH: Registry Has No Platform Section

**File**: `templates/commands/plan.md` lines 156-167
**Issue**: Registry sections loaded: architecture, code_patterns, api, backend, frontend, database.
**Missing**: `platform`, `mobile`, `target_platform`

**What happens**: First mobile project creates plan. Makes decisions. Registry sync (Phase 0.9) saves them without platform context. Next project (could be web) inherits mobile decisions.

**Fix**: Add platform sections to registry template and load them.

---

### 2.6 HIGH: Wiring Checklist Assumes Web Structure

**File**: `templates/commands/tasks.md` lines 236-257
**Issue**: Wiring examples:
- `frontend/src/components/Sidebar.tsx` - React
- `frontend/src/stores/featureStore.ts` - Zustand/Redux
- `backend/app/routes/__init__.py` - Python/FastAPI

**What happens for mobile**: Task says "Wire component into navigation". Example paths don't exist in iOS/Android projects.

**Fix**: Add platform-specific wiring examples:
```markdown
**iOS Wiring:**
- `App/Views/Navigation/MainTabView.swift` - Add tab bar item
- `App/Services/` - Register service in container

**Android Wiring:**
- `app/src/main/java/.../navigation/NavGraph.kt` - Add composable route
- `app/src/main/AndroidManifest.xml` - Register activity/permissions
```

---

### 2.7 MEDIUM: Task Template Examples Are Web-Centric

**File**: `templates/atomic-task-template.md` lines 99-122
**Issue**: "Files to Create" and "Files to Update" examples use web paths:
- `src/path/to/new-file.ts`
- `src/main.ts`
- `src/components/Navigation.tsx`

**Fix**: Add platform-specific comments or examples.

---

## PART 3: FAILURE SCENARIOS

### Scenario 1: "Billing Disaster"

**User request**: "Build an iOS subscription app"
**What happens**:
1. `/speckit.specify` detects "iOS" → sets `platform: mobile`
2. `/speckit.plan` Phase 0.5 collects tech stack (no platform-specific billing question)
3. Phase 0.8 shows web UI options (user selects "Other")
4. Phase 0.85 doesn't exist yet → skipped
5. `/speckit.tasks` loads base Station 09 (Stripe) not mobile variant
6. Tasks generated: "Integrate Stripe Checkout", "Create Stripe webhooks"
7. Developer implements Stripe for iOS
8. **App rejected by App Store** - must use IAP for digital goods

**Root cause**: No station override mechanism. Base station always loads.

---

### Scenario 2: "Agent Mismatch"

**User request**: "Build a React Native app with payments"
**What happens**:
1. `/speckit.plan` Phase 0.1 discovers subagents
2. Spec has keywords: "React", "components", "payments"
3. Agent matching: "React" → `frontend-developer` (web React specialist)
4. Agent matching: "payments" → `payment-integration` (Stripe/web)
5. Neither knows React Native or RevenueCat
6. Tasks generated with web patterns
7. Code doesn't compile (web APIs in mobile project)

**Root cause**: Subagents have no platform tag. Keyword matching is ambiguous.

---

### Scenario 3: "Verification Failure"

**User request**: "Build an Android authentication feature"
**What happens**:
1. Tasks generated with correct objectives
2. Verification command embedded: `npm test -- --grep "AuthService"`
3. Developer implements in Kotlin
4. Runs verification: `npm test` → "npm: command not found"
5. Task cannot be marked complete
6. Developer manually verifies, marks done anyway
7. **Traceability broken** - no automated verification

**Root cause**: Verification templates are web-only.

---

### Scenario 4: "Platform Amnesia"

**User request**: "Build a mobile app" (project 1)
**Later**: "Add user profiles feature" (project 2, same repo)
**What happens**:
1. Project 1: Platform detected as mobile, saved nowhere
2. Project 2: `/speckit.specify` runs, no platform keywords in "user profiles"
3. Platform defaults to web (per graceful degradation)
4. Web tasks generated for mobile project
5. Developer confused - "Why is this generating React code?"

**Root cause**: Platform not persisted in registry. Each feature re-detects.

---

### Scenario 5: "Half-and-Half Confusion"

**User request**: "Build a product with web dashboard and mobile app"
**What happens**:
1. `/speckit.specify` detects "mobile" AND "web"
2. Sets `platform: both` (or unclear behavior)
3. `/speckit.plan` doesn't know what to do with "both"
4. Shows web frameworks (ignores mobile half)
5. Tasks generated for web only
6. Mobile app never gets planned

**Root cause**: "Both" platform handling undefined.

---

## PART 4: RECOMMENDED FIXES

### Priority 1 (Must Fix Before Implementation)

| # | Issue | Fix |
|---|-------|-----|
| 1 | Platform context lost between phases | Add `platform` to registry, persist through workflow |
| 2 | No station override mechanism | Define `_platform-registry.yaml` with explicit mappings |
| 3 | Phase 0.8 hardcodes web | Branch by platform with mobile-specific options |
| 4 | Subagents have no platform tag | Add `platform:` field to frontmatter |
| 5 | Verification commands are web-only | Add platform-specific templates |

### Priority 2 (Should Fix)

| # | Issue | Fix |
|---|-------|-----|
| 6 | "Both" platform undefined | Add multi-platform handling section |
| 7 | Mobile stations loading rules unclear | Define conditional loading in registry |
| 8 | Phase 0.85 questions not specified | Write full AskUserQuestion format |
| 9 | Integration verification web-only | Add mobile integration checks |
| 10 | Wiring examples web-centric | Add iOS/Android path examples |

### Priority 3 (Nice to Have)

| # | Issue | Fix |
|---|-------|-----|
| 11 | Task numbering conflict | Define platform-prefixed numbering |
| 12 | Agent matching ambiguous | Add two-stage matching (platform then domain) |

---

## PART 5: REVISED IMPLEMENTATION CHECKLIST

Before starting implementation, ensure these prerequisites:

- [ ] **P1**: Define `_platform-registry.yaml` schema with `station_overrides`
- [ ] **P1**: Add `platform:` field to subagent frontmatter schema
- [ ] **P1**: Add `target_platform` and `mobile` sections to registry template
- [ ] **P1**: Write platform-branched Phase 0.8 (not generic)
- [ ] **P1**: Create verification command templates per platform
- [ ] **P2**: Define "both" platform behavior
- [ ] **P2**: Write full Phase 0.85 HITL specification
- [ ] **P2**: Define mobile station conditional loading rules
- [ ] **P2**: Add mobile integration verification to implement.md
- [ ] **P3**: Resolve task numbering scheme

---

## Conclusion

The plan has a solid high-level architecture but lacks critical implementation details that will cause platform confusion. The most dangerous gaps:

1. **No mechanism to load platform-specific stations** - Base stations always win
2. **Subagents can't be filtered by platform** - Wrong agent matches likely
3. **Phase 0.8 shows web-only options** - Every mobile project starts confused
4. **Verification commands are web-only** - Mobile tasks can't be verified

**Recommendation**: Address Priority 1 items before any implementation. These are foundational - everything else builds on them.
