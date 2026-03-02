# Platform Resolution Integration for plan.md

This document provides the exact changes needed to integrate platform-aware station loading into the `/speckit.plan` command.

---

## Summary of Changes

| Location | Change Type | Description |
|----------|-------------|-------------|
| Phase 0.1 | **Add step 0** | Detect target platform before loading stations |
| Phase 0.1 | **Modify step 5** | Use platform resolution when loading stations |
| Phase 0.1 | **Modify report** | Show variant vs base station loading |
| New section | **Add** | Phase 0.05: Platform Detection (before 0.1) |

---

## Change 1: Add Phase 0.05 (Platform Detection)

Insert this new phase **between Phase 0.0 and Phase 0.1**:

```markdown
### Phase 0.05: Detect Target Platform

**Per Constitution Article IX, Directive 8 - Platform-aware station loading.**

Before loading domain knowledge, detect the target platform to load correct station variants.

1. **Check explicit platform in spec.md**:

   Look for platform specification in the feature spec:
   ```yaml
   # In spec.md frontmatter or body:
   target_platform: ios | android | react-native | flutter | mobile-web | electron | pwa | web
   ```

   If found, use this value.

2. **Infer platform from registry**:

   If no explicit platform, check `specs/_defaults/registry.yaml`:
   ```yaml
   frontend:
     framework: react-native  # → platform = react-native
     framework: flutter       # → platform = flutter
     framework: react         # → platform = web (default)
   ```

   Platform inference rules:
   | Registry Value | Inferred Platform |
   |---------------|-------------------|
   | `frontend.framework: react-native` | `react-native` |
   | `frontend.framework: flutter` | `flutter` |
   | `frontend.framework: electron` | `electron` |
   | `backend.deployment: app-store` | Check further for ios/android |
   | Any other | `web` |

3. **Ask user if ambiguous**:

   If platform cannot be determined, use AskUserQuestion:

   ```
   Question: "What is the target platform for this feature?"
   Header: "Platform"
   Options:
     - Label: "Web application (Default)"
       Description: "Browser-based, uses Stripe for billing"
     - Label: "iOS (App Store)"
       Description: "iPhone/iPad app, requires Apple IAP"
     - Label: "Android (Google Play)"
       Description: "Android app, requires Google Play Billing"
     - Label: "React Native (iOS + Android)"
       Description: "Cross-platform mobile, needs both IAP implementations"
     - Label: "Flutter (iOS + Android)"
       Description: "Cross-platform mobile, needs both IAP implementations"
     - Label: "Mobile + Web (hybrid backend)"
       Description: "Single backend serving both web and mobile clients"
     - Label: "Desktop (Electron)"
       Description: "Desktop app, can use Stripe directly"
   ```

4. **Load platform registry**:

   ```
   Read: .specify/knowledge/_platform-registry.yaml
   ```

   If file doesn't exist:
   - Log: "No platform registry found. Using base stations."
   - Set `platform_overrides_available = false`

5. **Store platform context**:

   Record in plan.md:
   ```markdown
   ## Platform Configuration

   | Setting | Value |
   |---------|-------|
   | Target Platform | [detected/selected] |
   | Platform Source | [spec/registry/user] |
   | Billing Provider | [stripe/iap_apple/iap_google/both/hybrid] |
   | Overrides Available | [Yes/No] |
   ```

**Output**: Target platform detected and stored for Phase 0.1 station resolution
```

---

## Change 2: Modify Phase 0.1 Step 5 (Station Loading)

Replace the current step 5 in Phase 0.1:

**CURRENT** (line ~275-282):
```markdown
5. **If no subagents exist but stations might help**:

   Fall back to station discovery:
   ```
   Read: .specify/knowledge/stations/00-station-map.md
   → Find relevant station for unmatched domain
   → Read: .specify/knowledge/stations/[XX]-[domain].md
   ```
```

**REPLACE WITH**:
```markdown
5. **Load stations with platform resolution**:

   When loading stations (either as fallback or alongside subagents):

   a. **Read station map**:
      ```
      Read: .specify/knowledge/stations/00-station-map.md
      ```

   b. **For each relevant station**, apply platform resolution:
      ```
      FOR EACH station_id IN relevant_stations:
          result = resolveStationPath(station_id, target_platform)

          IF result.warning IS NOT NULL:
              Log warning to user

          Read: result.path
          Store: station content with metadata {
              station_id: station_id,
              loaded_from: result.path,
              is_variant: result.isVariant,
              platform: target_platform
          }
      ```

   c. **Resolution algorithm** (from `_platform-resolution.md`):
      1. If platform is null or "web" → use base station
      2. Load `_platform-registry.yaml`
      3. Look up `platforms[platform].station_overrides[station_id]`
      4. If override exists AND file exists → load variant
      5. Else → load base station (with warning if override was expected)

   d. **Example resolutions**:
      ```
      # iOS platform, Station 09 (Billing)
      Input: station_id="09", platform="ios"
      Registry: platforms.ios.station_overrides["09"] = "platforms/ios/09-billing-ios.md"
      Output: .specify/knowledge/platforms/ios/09-billing-ios.md

      # iOS platform, Station 03 (Discovery) - no override
      Input: station_id="03", platform="ios"
      Registry: platforms.ios.station_overrides["03"] = null
      Output: .specify/knowledge/stations/03-discovery.md
      ```
```

---

## Change 3: Modify Phase 0.1 Report Section

Update the knowledge loaded report (line ~299-320):

**CURRENT**:
```markdown
4. **Report loaded knowledge**:

   ```
   ══════════════════════════════════════════════════════════════
   📚 DOMAIN KNOWLEDGE LOADED
   ══════════════════════════════════════════════════════════════

   Detected domains from spec:
   - [domain 1]: Loaded from [subagent/station]
   ...
   ```
```

**REPLACE WITH**:
```markdown
7. **Report loaded knowledge**:

   ```
   ══════════════════════════════════════════════════════════════
   📚 DOMAIN KNOWLEDGE LOADED
   ══════════════════════════════════════════════════════════════

   Target Platform: [platform]
   Billing Provider: [stripe | iap_apple | iap_google | both | hybrid]

   Detected domains from spec:
   - [domain 1]: Loaded from [subagent/station]
   - [domain 2]: Loaded from [subagent/station]
   - [domain 3]: No knowledge available - using general practices

   Station Resolution:
   | Station | Source | Type | Path |
   |---------|--------|------|------|
   | 03-Discovery | Base | Base | stations/03-discovery.md |
   | 09-Billing | iOS Variant | Variant | platforms/ios/09-billing-ios.md |
   | 10-Metering | iOS Variant | Variant | platforms/ios/10-metering-ios.md |

   Platform-specific rules loaded:
   - [Rule from variant, e.g., "Use StoreKit 2 for IAP"]
   - [Rule from variant, e.g., "Receipts must be validated server-side"]

   ⚠️ WARNINGS (if any):
   - [Variant missing warning, if occurred]

   Key rules that will be applied:
   - [Rule 1 from domain 1]
   - [Rule 2 from domain 1]
   - [Rule 3 from domain 2]

   Gate criteria to verify:
   - [ ] [Gate from domain 1]
   - [ ] [Gate from domain 2]
   - [ ] [Platform-specific gate, e.g., "App Store compliance verified"]
   ══════════════════════════════════════════════════════════════
   ```
```

---

## Full Updated Phase 0.1

Here is the complete updated Phase 0.1 with all changes integrated:

```markdown
### Phase 0.05: Detect Target Platform

**Per Constitution Article IX, Directive 8 - Platform-aware station loading.**

Before loading domain knowledge, detect the target platform to load correct station variants.

1. **Check explicit platform in spec.md**:

   Look for platform specification in the feature spec:
   ```yaml
   # In spec.md frontmatter or body:
   target_platform: ios | android | react-native | flutter | mobile-web | electron | pwa | web
   ```

   If found, use this value.

2. **Infer platform from registry**:

   If no explicit platform, check `specs/_defaults/registry.yaml`:

   Platform inference rules:
   | Registry Value | Inferred Platform |
   |---------------|-------------------|
   | `frontend.framework: react-native` | `react-native` |
   | `frontend.framework: flutter` | `flutter` |
   | `frontend.framework: electron` | `electron` |
   | Any other | `web` |

3. **Ask user if ambiguous**:

   If platform cannot be determined, use AskUserQuestion:

   ```
   Question: "What is the target platform for this feature?"
   Header: "Platform"
   Options:
     - Label: "Web application (Default)"
       Description: "Browser-based, uses Stripe for billing"
     - Label: "iOS (App Store)"
       Description: "iPhone/iPad app, requires Apple IAP"
     - Label: "Android (Google Play)"
       Description: "Android app, requires Google Play Billing"
     - Label: "React Native (iOS + Android)"
       Description: "Cross-platform mobile, needs both IAP implementations"
     - Label: "Flutter (iOS + Android)"
       Description: "Cross-platform mobile, needs both IAP implementations"
     - Label: "Mobile + Web (hybrid backend)"
       Description: "Single backend serving both web and mobile clients"
     - Label: "Desktop (Electron)"
       Description: "Desktop app, can use Stripe directly"
   ```

4. **Load platform registry**:

   ```
   Read: .specify/knowledge/_platform-registry.yaml
   ```

   If file doesn't exist:
   - Log: "No platform registry found. Using base stations (web default)."
   - Set `platform_overrides_available = false`

5. **Store platform context**:

   Record in plan.md:
   ```markdown
   ## Platform Configuration

   | Setting | Value |
   |---------|-------|
   | Target Platform | [detected/selected] |
   | Platform Source | [spec/registry/user] |
   | Billing Provider | [stripe/iap_apple/iap_google/both/hybrid] |
   | Overrides Available | [Yes/No] |
   ```

**Output**: Target platform detected and stored for Phase 0.1 station resolution

### Phase 0.1: Load Domain Knowledge (Assembly Line Manual)

**Per Constitution Article IX, Directive 8 - This step is MANDATORY.**

Before designing, load relevant stations and subagents based on feature domains.

**⚠️ DO NOT hard-code agent names. Use dynamic discovery.**
**⚠️ APPLY PLATFORM RESOLUTION to all station loads.**

1. **Discover available subagents**:

   a. **Scan the subagents folder** at `.specify/subagents/`:
      - List all `*.md` files in the folder
      - **Exclude** files starting with `_` (e.g., `_index.md`, `_template.md`)
      - Also scan `.specify/subagents/custom/` for project-specific agents

   b. **For each subagent file found**, read the YAML frontmatter to extract:
      - `name`: The subagent identifier
      - `description`: What it does and when to use it (contains matching keywords)

   c. **Build an agent catalog** with extracted descriptions:
      ```
      | Agent Name | Description (for matching) |
      |------------|---------------------------|
      | [name from frontmatter] | [description from frontmatter] |
      | ... | ... |
      ```

2. **Extract domain keywords from spec.md**:

   Scan the feature specification for domain-relevant terms:
   - Technical terms: API, database, auth, payment, UI, tests, deploy, etc.
   - User story contexts: "user can pay", "admin dashboard", "login flow"
   - Entity mentions: users, orders, subscriptions, products, etc.
   - Actions: create, update, delete, search, filter, etc.

3. **Match spec keywords to agent descriptions** (semantic similarity):

   For each agent in the catalog:
   a. Check if agent's `description` contains keywords from the spec
   b. Check if spec context relates to agent's stated purpose
   c. **Score match quality**:
      - Multiple keyword matches → Strong match (load this agent)
      - Single keyword match → Moderate match (consider loading)
      - No overlap → Do not load

   **Example matching**:
   - Spec mentions "REST API", "endpoints" → Agent with "REST, API, microservice" in description → Match
   - Spec mentions "payment", "subscription" → Agent with "payment, billing, stripe" → Match
   - Spec mentions "React components" → Agent with "components, UI, frontend" → Match

4. **For each matched agent**:

   a. **Load the subagent file**:
      ```
      Read: .specify/subagents/[matched-agent-name].md
      ```

   b. **Extract and store**:
      - Key patterns/rules (e.g., "Every query MUST filter by tenant_id")
      - Gate criteria checklists
      - Common pitfalls to avoid
      - Required outputs/artifacts

5. **Load stations with platform resolution**:

   When loading stations (either as fallback or alongside subagents):

   a. **Read station map**:
      ```
      Read: .specify/knowledge/stations/00-station-map.md
      ```

   b. **For each relevant station**, apply platform resolution:
      ```
      FOR EACH station_id IN relevant_stations:
          result = resolveStationPath(station_id, target_platform)

          IF result.warning IS NOT NULL:
              Log warning to user

          Read: result.path
          Store: station content with metadata {
              station_id: station_id,
              loaded_from: result.path,
              is_variant: result.isVariant,
              platform: target_platform
          }
      ```

   c. **Resolution algorithm** (from `_platform-resolution.md`):
      1. If platform is null or "web" → use base station
      2. Load `_platform-registry.yaml`
      3. Look up `platforms[platform].station_overrides[station_id]`
      4. If override exists AND file exists → load variant
      5. Else → load base station (with warning if override was expected)

   d. **Example resolutions**:
      ```
      # iOS platform, Station 09 (Billing)
      Input: station_id="09", platform="ios"
      Registry: platforms.ios.station_overrides["09"] = "platforms/ios/09-billing-ios.md"
      Output: .specify/knowledge/platforms/ios/09-billing-ios.md

      # iOS platform, Station 03 (Discovery) - no override
      Input: station_id="03", platform="ios"
      Registry: platforms.ios.station_overrides["03"] = null
      Output: .specify/knowledge/stations/03-discovery.md
      ```

6. **If NO knowledge base exists** (no stations, no subagents):

   Use AskUserQuestion:
   ```
   Question: "No Assembly Line knowledge base found. How should we proceed?"
   Header: "Knowledge"
   Options:
     - Label: "Use general best practices (Recommended)"
       Description: "AI will use training knowledge - less SaaS-specific"
     - Label: "Set up defaults now"
       Description: "I'll answer questions to establish patterns"
     - Label: "Import from template"
       Description: "Use a standard SaaS template as starting point"
   ```

7. **Report loaded knowledge**:

   ```
   ══════════════════════════════════════════════════════════════
   📚 DOMAIN KNOWLEDGE LOADED
   ══════════════════════════════════════════════════════════════

   Target Platform: [platform]
   Billing Provider: [stripe | iap_apple | iap_google | both | hybrid]

   Detected domains from spec:
   - [domain 1]: Loaded from [subagent/station]
   - [domain 2]: Loaded from [subagent/station]
   - [domain 3]: No knowledge available - using general practices

   Station Resolution:
   | Station | Source | Type | Path |
   |---------|--------|------|------|
   | 03-Discovery | Base | Base | stations/03-discovery.md |
   | 09-Billing | iOS Variant | Variant | platforms/ios/09-billing-ios.md |
   | 10-Metering | iOS Variant | Variant | platforms/ios/10-metering-ios.md |

   Platform-specific rules loaded:
   - [Rule from variant, e.g., "Use StoreKit 2 for IAP"]
   - [Rule from variant, e.g., "Receipts must be validated server-side"]

   ⚠️ WARNINGS (if any):
   - [Variant missing warning, if occurred]

   Key rules that will be applied:
   - [Rule 1 from domain 1]
   - [Rule 2 from domain 1]
   - [Rule 3 from domain 2]

   Gate criteria to verify:
   - [ ] [Gate from domain 1]
   - [ ] [Gate from domain 2]
   - [ ] [Platform-specific gate, e.g., "App Store compliance verified"]
   ══════════════════════════════════════════════════════════════
   ```

8. **Store loaded knowledge** for use in subsequent phases:
   - These patterns inform data model design
   - Gate criteria will be embedded in task files during `/speckit.tasks`
   - Rules will be applied during code review
   - **Platform context is passed to all downstream phases**

**Output**: Domain knowledge loaded into planning context, rules documented, platform resolution applied
```

---

## Files Created/Modified Summary

| File | Action | Purpose |
|------|--------|---------|
| `.specify/knowledge/_platform-registry.yaml` | CREATE | Platform definitions and override mappings |
| `.specify/knowledge/_platform-resolution.md` | CREATE | Resolution algorithm documentation |
| `templates/commands/plan.md` | MODIFY | Add Phase 0.05 and update Phase 0.1 |

---

## Backward Compatibility Verification

| Scenario | Behavior |
|----------|----------|
| No `_platform-registry.yaml` exists | Uses base stations silently (web default) |
| Platform not specified anywhere | Defaults to "web", uses base stations |
| Platform specified but variant missing | Uses base station + logs warning |
| Existing projects without platform field | Work exactly as before (no breaking changes) |
