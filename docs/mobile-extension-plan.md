# Plan: Extend Custom Speckit for Mobile App Development

**Status**: Draft - Saved for future implementation
**Created**: 2026-03-02
**Author**: AI Planning Session

## Executive Summary

Extend the existing web-focused Custom Speckit framework to support mobile app development (iOS, Android, cross-platform) while maintaining full backward compatibility with existing web workflows.

**Approach**: Modular platform architecture - NOT a fork. Shared stations remain unchanged, platform-specific knowledge loaded dynamically based on target platform.

---

## Problem Statement

Custom Speckit is currently **~20% mobile-ready**:
- **Works for mobile**: Workflow structure, atomic tasks, HITL checkpoints, registry protocol
- **Web-only**: 7 of 18 stations assume REST/browser/Stripe, all 25 subagents are web-focused
- **Missing entirely**: Push notifications, offline sync, deep linking, app store deployment, IAP billing

---

## Proposed Architecture

### Folder Structure

```
.specify/
├── knowledge/
│   ├── stations/                    # SHARED (no change to existing)
│   │   ├── 00-station-map.md        # Add platform selector
│   │   ├── 01-18-*.md               # Unchanged
│   │
│   └── platforms/                   # NEW - Platform extensions
│       ├── _platform-registry.yaml  # Platform detection rules
│       │
│       ├── web/                     # Web-specific (current behavior)
│       │   ├── 06-api-contracts-web.md
│       │   ├── 09-billing-web.md
│       │   ├── 12-cicd-web.md
│       │   ├── 13-security-web.md
│       │   └── 15-performance-web.md
│       │
│       └── mobile/                  # NEW - Mobile-specific
│           ├── _mobile-common.md
│           ├── 05-user-flows-mobile.md
│           ├── 06-api-contracts-mobile.md
│           ├── 08-auth-mobile.md
│           ├── 09-billing-mobile.md      # IAP (critical difference)
│           ├── 12-cicd-mobile.md         # App store deployment
│           ├── 13-security-mobile.md     # Cert pinning, keychain
│           ├── 15-performance-mobile.md
│           │
│           ├── M01-push-notifications.md # NEW mobile-only
│           ├── M02-offline-sync.md       # NEW mobile-only
│           ├── M03-deep-linking.md       # NEW mobile-only
│           ├── M04-app-lifecycle.md      # NEW mobile-only
│           ├── M05-device-capabilities.md# NEW mobile-only
│           ├── M06-app-store-review.md   # NEW mobile-only
│           │
│           ├── ios/                      # iOS-specific
│           └── android/                  # Android-specific
│
├── subagents/
│   ├── (existing 25 agents)
│   │
│   ├── # NEW MOBILE SUBAGENTS
│   ├── ios-developer.md
│   ├── android-developer.md
│   ├── mobile-ux-designer.md
│   ├── cross-platform-developer.md
│   ├── push-notification-engineer.md
│   ├── mobile-devops.md
│   └── app-store-specialist.md
```

---

## Station Classification

| Station | Status | Notes |
|---------|--------|-------|
| 01-04 | **SHARED** | Discovery, PRD - platform-agnostic |
| 05 | **NEEDS VARIANT** | Mobile navigation patterns differ |
| 06 | **NEEDS VARIANT** | Mobile API patterns (offline, compression) |
| 07 | **SHARED** | Data architecture - same tenancy patterns |
| 08 | **NEEDS VARIANT** | Mobile auth (biometrics, keychain) |
| 09 | **NEEDS VARIANT** | **CRITICAL**: IAP vs Stripe |
| 10-11 | **SHARED** | Metering, observability - backend-focused |
| 12 | **NEEDS VARIANT** | **CRITICAL**: App store deployment |
| 13 | **NEEDS VARIANT** | Mobile security (cert pinning, jailbreak) |
| 14 | **SHARED** | Data lifecycle - same GDPR patterns |
| 15 | **NEEDS VARIANT** | Mobile metrics (battery, startup time) |
| 16-18 | **SHARED** | Analytics, admin, docs - platform-agnostic |

**Summary**: 11 shared, 7 need variants, 6 new mobile-only

---

## Critical Mobile Differences

### Billing (Station 09) - MOST CRITICAL

| Aspect | Web (Stripe) | Mobile (IAP) |
|--------|--------------|--------------|
| Revenue share | ~2.9% | 15-30% |
| Checkout | Stripe Checkout | Native IAP UI |
| Subscription mgmt | Stripe Portal | Settings app |
| Refunds | Full control | Store refunds |
| Price changes | Immediate | Store review |

### CI/CD (Station 12)

| Aspect | Web | Mobile |
|--------|-----|--------|
| Build output | Containers | .ipa, .aab |
| Signing | HTTPS certs | Code signing (complex) |
| Distribution | CDN | App stores |
| Review | None | 1-7 days |
| Updates | Instant | Store + user action |

### Security (Station 13)

| Aspect | Web | Mobile |
|--------|-----|--------|
| Threats | XSS, CSRF | Jailbreak, reverse eng |
| Token storage | httpOnly cookies | Keychain/Keystore |
| Network | TLS + CORS | TLS + cert pinning |
| Code protection | Minification | Obfuscation |

---

## New Mobile-Only Stations

### M01: Push Notifications
- APNs/FCM setup, token management, payload design
- Silent push for background sync
- Permission flows, engagement strategies

### M02: Offline-First Data Sync
- Local storage (SQLite, Realm, Core Data, Room)
- Sync strategies (CRDT, last-write-wins)
- Conflict resolution, network detection

### M03: Deep Linking
- Universal Links (iOS), App Links (Android)
- Deferred deep links for attribution
- Auth-required deep link handling

### M04: App Lifecycle Management
- Background tasks, state restoration
- Memory pressure, process death recovery
- Cold/warm start optimization

### M05: Device Capabilities
- Feature detection, permissions
- Graceful degradation
- Responsive layouts (phones, tablets, foldables)

### M06: App Store Review
- Guidelines compliance checklists
- Metadata preparation
- Rejection handling, appeals

---

## Workflow Changes

### `/speckit.specify`
Add Step 0: Platform Detection
- Scan for keywords: "iOS", "Android", "mobile", "app"
- Confirm with user via AskUserQuestion
- Store in spec.md header: `platform: mobile`

### `/speckit.plan`
Add Phase 0.2: Platform Knowledge Loading
- Read platform from spec.md
- Load platform-specific station variants
- Load mobile subagents

Add Phase 0.85: Mobile Configuration HITL
- IAP strategy (RevenueCat vs native)
- Offline capability level
- Push notification provider

### `/speckit.tasks`
Add mobile task patterns:
- T-010-019: Native project setup
- T-040-049: Push notification infrastructure
- T-050-059: Offline/sync logic
- T-060-069: IAP integration
- T-090-099: App store submission prep

Add mobile wiring checklist:
- Screen in navigation stack
- Deep link route registered
- Offline data source connected

### `/speckit.implement`
Add mobile verification commands:
- `xcodebuild` for iOS
- `./gradlew` for Android
- Platform-specific integration checks

---

## New Mobile Subagents (7)

| Subagent | Purpose |
|----------|---------|
| `ios-developer` | Swift/SwiftUI, StoreKit, Core Data |
| `android-developer` | Kotlin/Compose, Play Billing, Room |
| `mobile-ux-designer` | HIG, Material Design, touch patterns |
| `cross-platform-developer` | React Native, Flutter |
| `push-notification-engineer` | APNs, FCM, token management |
| `mobile-devops` | Fastlane, signing, store deployment |
| `app-store-specialist` | Guidelines, ASO, rejection handling |

---

## Registry Updates

Add to `registry-template.yaml`:

```yaml
target_platform:
  primary: null           # web | mobile | both
  mobile_platforms: null  # ios | android | both
  mobile_framework: null  # native | react-native | flutter

mobile:
  push_service: null      # apns_fcm | onesignal | firebase
  offline_strategy: null  # offline_first | online_first | none
  local_database: null    # sqlite | realm | core_data | room
  deep_linking: null      # universal_links | branch | firebase
  iap_framework: null     # storekit2 | billing_client | revenuecat
  crash_reporting: null   # crashlytics | sentry | bugsnag
  cert_pinning: null      # enabled | disabled
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (2 days)
1. Create `_platform-registry.yaml`
2. Update `plan.md` for platform detection (Phase 0.2)
3. Add mobile registry sections

### Phase 2: Critical Stations (2 days)
1. `09-billing-mobile.md` (IAP - highest impact)
2. `12-cicd-mobile.md` (store deployment)
3. `M06-app-store-review.md` (launch-critical)

### Phase 3: Subagents (1 day)
1. `mobile-devops.md` (CI/CD subagent)
2. `ios-developer.md`
3. `android-developer.md`
4. `app-store-specialist.md`

### Phase 4: Remaining Stations (2 days)
1. Station variants: 05, 06, 08, 13, 15
2. New stations: M01-M05 (push, offline, deep links, lifecycle, capabilities)

### Phase 5: Command Updates (1 day)
1. Update `specify.md` for platform detection
2. Update `tasks.md` for mobile patterns
3. Update `implement.md` for mobile verification

**Total estimated time**: 8 days

---

## Graceful Degradation

If mobile knowledge is missing:
1. Check for `_platform-registry.yaml` → if missing, use base stations
2. Warn user about limited mobile support
3. Fall back to general best practices
4. Never fail - always produce tasks with available context

---

## Files to Create/Modify

### New Files (20+)
- `.specify/knowledge/platforms/_platform-registry.yaml`
- `.specify/knowledge/platforms/mobile/09-billing-mobile.md`
- `.specify/knowledge/platforms/mobile/12-cicd-mobile.md`
- `.specify/knowledge/platforms/mobile/13-security-mobile.md`
- `.specify/knowledge/platforms/mobile/M01-M06-*.md` (6 files)
- `.specify/subagents/ios-developer.md`
- `.specify/subagents/android-developer.md`
- `.specify/subagents/mobile-ux-designer.md`
- `.specify/subagents/mobile-devops.md`
- `.specify/subagents/app-store-specialist.md`
- Plus station variants for 05, 06, 08, 15

### Modified Files (5)
- `templates/commands/specify.md` - Add platform detection
- `templates/commands/plan.md` - Add Phase 0.2, 0.85
- `templates/commands/tasks.md` - Add mobile patterns
- `templates/commands/implement.md` - Add mobile verification
- `templates/registry-template.yaml` - Add mobile sections

---

## Verification

After implementation:
1. Run `/speckit.specify "Build a mobile app with push notifications and in-app purchases"` → should detect mobile, load mobile stations
2. Run `/speckit.plan` → should show Phase 0.85 mobile HITL
3. Run `/speckit.tasks` → should generate mobile-specific tasks with embedded mobile context
4. Verify existing web workflow unchanged: `/speckit.specify "Build a REST API"` → should work as before

---

## Research Sources

This plan was developed by analyzing:
- All 18 Knowledge Stations in `.specify/knowledge/stations/`
- All command templates in `templates/commands/`
- All 25 subagents in `.specify/subagents/`
- Industry research on Kiro "Powers" and BMAD modular architecture approaches
