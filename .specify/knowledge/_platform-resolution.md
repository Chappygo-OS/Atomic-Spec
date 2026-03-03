# Platform Station Resolution Algorithm

This document defines the algorithm for resolving which station file to load based on the target platform.

---

## Registry Validation (Required by All Commands)

Before any platform-dependent operation, validate:

1. Check if `specs/_defaults/registry.yaml` exists
2. If missing, warn user and create minimal registry with platform question
3. Check if `target_platform.primary` is set
4. If not set:
   - Display warning: "No target platform defined"
   - Ask user to specify platform
   - Store in registry before proceeding

**Never silently default to web** - always inform user of the assumption.

### Validation Pseudocode

```
FUNCTION validateRegistry():
    REGISTRY_PATH = "specs/_defaults/registry.yaml"

    # Step 1: Check registry exists
    IF NOT fileExists(REGISTRY_PATH):
        WARN("Registry not found at {REGISTRY_PATH}")
        ASK_USER("Create minimal registry with platform question?")
        IF user_confirms:
            createMinimalRegistry(REGISTRY_PATH)
        ELSE:
            WARN("No registry created - but platform is still required")
            platform = ASK_USER("What is the target platform?", options=[
                "web", "ios", "android", "react-native", "flutter", "backend-only", "both"
            ])
            IF platform == "both":
                mobile_framework = ASK_USER("Which mobile framework?", options=[
                    "ios", "android", "react-native", "flutter"
                ])
                LOG("Platform: both, mobile_framework: {mobile_framework}")
            LOG("Platform selected without registry: {platform}")
            RETURN { platform: platform, source: "user_prompted_no_registry" }

    # Step 2: Load registry
    registry = loadYAML(REGISTRY_PATH)

    # Step 3: Check target_platform.primary
    IF registry.target_platform IS NULL OR registry.target_platform.primary IS NULL:
        WARN("No target platform defined in registry")
        platform = ASK_USER("What is the target platform?", options=[
            "web", "ios", "android", "react-native", "flutter", "backend-only", "both"
        ])
        IF platform == "both":
            mobile_framework = ASK_USER("Which mobile framework?", options=[
                "ios", "android", "react-native", "flutter"
            ])
            updateRegistry(REGISTRY_PATH, "target_platform.mobile_framework", mobile_framework)
        # Store in registry
        updateRegistry(REGISTRY_PATH, "target_platform.primary", platform)
        LOG("Platform stored in registry: {platform}")
        RETURN { platform: platform, source: "user_prompted" }

    # Step 4: Return existing platform
    RETURN {
        platform: registry.target_platform.primary,
        source: "registry"
    }

END FUNCTION
```

---

## Canonical Platform Resolution (All Commands MUST Use This)

Platform is determined in this priority order:

1. **Task file context** (during /implement): Read from task's Implementation Context
2. **Plan.md header** (during /tasks): Read Platform: field
3. **Spec.md header** (during /plan): Read Platform: field
4. **Registry** (during /specify): Read target_platform.primary
5. **User prompt** (if all above missing): Ask once, store in registry
6. **Default** (last resort): "web" with logged warning

### Command-Specific Sources

| Command | Primary Source | Fallback |
|---------|---------------|----------|
| /speckit.specify | Registry -> Ask user | Store in spec.md |
| /speckit.plan | spec.md -> Registry -> Ask user | Store in plan.md |
| /speckit.tasks | plan.md | ERROR if missing |
| /speckit.implement | task file | ERROR if missing |

Each command should read from its primary source. If missing, it's an error for downstream commands (they should have inherited it).

> **Composite Platform (`both`)**: When `platform = "both"`, all commands must also read
> `mobile_framework` from the registry to determine the mobile sub-platform. The `backend.*`
> registry section provides backend specifics. Do NOT introduce new fields like
> Platform-Frontend or Platform-Backend — use the existing registry structure.

### Resolution Pseudocode

```
FUNCTION resolvePlatform(command, context):

    SWITCH command:
        CASE "/speckit.implement":
            # Task file is authoritative - ERROR if missing
            IF context.task_file.platform IS NOT NULL:
                RETURN context.task_file.platform
            ELSE:
                ERROR("Task file missing platform. This is a /speckit.tasks generation error.")

        CASE "/speckit.tasks":
            # Plan.md is authoritative - ERROR if missing
            IF context.plan_md.platform IS NOT NULL:
                RETURN context.plan_md.platform
            ELSE:
                ERROR("Plan.md missing Platform: field. Re-run /speckit.plan.")

        CASE "/speckit.plan":
            # Check spec.md first, then registry, then ask
            IF context.spec_md.platform IS NOT NULL:
                RETURN context.spec_md.platform
            IF context.registry.target_platform.primary IS NOT NULL:
                RETURN context.registry.target_platform.primary
            # Ask user and store
            platform = ASK_USER("Target platform?")
            STORE_IN(context.plan_md, "Platform: {platform}")
            RETURN platform

        CASE "/speckit.specify":
            # Registry is primary, ask if missing
            result = validateRegistry()  # See above
            STORE_IN(context.spec_md, "Platform: {result.platform}")
            RETURN result.platform

    # Should never reach here
    WARN("Unknown command - defaulting to web with warning")
    LOG("Platform assumption: web (unknown command)")
    RETURN "web"

END FUNCTION
```

### Error Messages

| Scenario | Command | Message |
|----------|---------|---------|
| Missing in task file | /implement | "ERROR: Task file missing platform context. Re-generate tasks with /speckit.tasks." |
| Missing in plan.md | /tasks | "ERROR: Plan.md missing Platform: field. Re-run /speckit.plan to set platform." |
| Missing everywhere | /plan | "WARNING: No platform found in spec.md or registry. Please specify target platform." |
| Defaulting to web | Any | "WARNING: Defaulting to 'web' platform. Run /speckit.specify to set explicit platform." |

---

## Overview

When the AI loads domain knowledge (stations), it must consider the target platform to load the correct variant. For example, when building an iOS app, Station 09 (Billing) should load the iOS IAP variant instead of the base Stripe web variant.

---

## Algorithm: `resolveStationPath(stationId, platform)`

### Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `stationId` | string | Yes | Station ID (e.g., "09", "10") |
| `platform` | string | No | Target platform (e.g., "ios", "android", "react-native") |

### Output

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Absolute path to station file to load |
| `isVariant` | boolean | True if loading a variant, false if base |
| `warning` | string | null | Warning message if degradation occurred |

---

## Pseudocode

```
FUNCTION resolveStationPath(stationId, platform):

    # Step 0: Define base paths
    KNOWLEDGE_ROOT = ".specify/knowledge"
    STATIONS_DIR = KNOWLEDGE_ROOT + "/stations"
    REGISTRY_PATH = KNOWLEDGE_ROOT + "/_platform-registry.yaml"

    # Step 1: Construct base station path
    baseStationPath = findStationFile(STATIONS_DIR, stationId)
    # e.g., "09" -> ".specify/knowledge/stations/09-billing.md"

    IF baseStationPath IS NULL:
        ERROR("Station {stationId} not found in {STATIONS_DIR}")

    # Step 2: Check if platform resolution is needed
    IF platform IS NULL OR platform == "" OR platform == "web":
        RETURN {
            path: baseStationPath,
            isVariant: false,
            warning: null
        }

    # Step 3: Load platform registry
    TRY:
        registry = loadYAML(REGISTRY_PATH)
    CATCH FileNotFound:
        # Registry doesn't exist - backward compatible default
        RETURN {
            path: baseStationPath,
            isVariant: false,
            warning: null  # Silent - registry is optional
        }

    # Step 4: Look up platform in registry
    platformConfig = registry.platforms[platform]

    IF platformConfig IS NULL:
        # Unknown platform - graceful degradation
        action = registry.fallback_behavior.unknown_platform.action
        IF action == "error":
            ERROR("Unknown platform: {platform}")
        ELSE:
            warning = formatWarning(registry.fallback_behavior.unknown_platform.warning_template, {
                platform: platform
            })
            RETURN {
                path: baseStationPath,
                isVariant: false,
                warning: IF action == "load_base_with_warning" THEN warning ELSE null
            }

    # Step 5: Check for station override
    variantRelativePath = platformConfig.station_overrides[stationId]

    IF variantRelativePath IS NULL OR variantRelativePath == "":
        # No override for this station - use base
        RETURN {
            path: baseStationPath,
            isVariant: false,
            warning: null
        }

    # Step 6: Resolve variant path
    variantAbsolutePath = KNOWLEDGE_ROOT + "/" + variantRelativePath
    # e.g., ".specify/knowledge/platforms/ios/09-billing-ios.md"

    # Step 7: Check if variant file exists
    IF NOT fileExists(variantAbsolutePath):
        # Variant missing - graceful degradation
        action = registry.fallback_behavior.missing_variant.action
        IF action == "error":
            ERROR("Platform variant not found: {variantAbsolutePath}")
        ELSE:
            warning = formatWarning(registry.fallback_behavior.missing_variant.warning_template, {
                platform: platform,
                station_id: stationId,
                variant_path: variantAbsolutePath,
                base_path: baseStationPath
            })
            RETURN {
                path: baseStationPath,
                isVariant: false,
                warning: IF action == "load_base_with_warning" THEN warning ELSE null
            }

    # Step 8: Return variant path
    RETURN {
        path: variantAbsolutePath,
        isVariant: true,
        warning: null
    }

END FUNCTION


FUNCTION findStationFile(stationsDir, stationId):
    # Find station file matching pattern: {stationId}-*.md
    # e.g., "09" -> "09-billing.md"

    pattern = stationId + "-*.md"
    matches = glob(stationsDir + "/" + pattern)

    IF matches.length == 0:
        RETURN NULL
    ELSE IF matches.length == 1:
        RETURN matches[0]
    ELSE:
        # Multiple matches - shouldn't happen, return first
        LOG_WARNING("Multiple stations match {stationId}: {matches}")
        RETURN matches[0]

END FUNCTION
```

---

## Resolution Flow Diagram

```
                    +------------------+
                    | resolveStation() |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    | platform == null |
                    | or "web"?        |
                    +--------+---------+
                             |
              +--------------+--------------+
              | YES                         | NO
              v                             v
    +------------------+          +------------------+
    | Return base      |          | Load registry    |
    | station path     |          | file             |
    +------------------+          +--------+---------+
                                           |
                                           v
                                  +------------------+
                                  | Registry exists? |
                                  +--------+---------+
                                           |
                        +------------------+------------------+
                        | NO                                  | YES
                        v                                     v
              +------------------+               +------------------+
              | Return base      |               | Platform in      |
              | (silent)         |               | registry?        |
              +------------------+               +--------+---------+
                                                          |
                                      +-------------------+-------------------+
                                      | NO                                    | YES
                                      v                                       v
                            +------------------+                 +------------------+
                            | Apply fallback   |                 | Override for     |
                            | (unknown_platform)|                | station exists?  |
                            +------------------+                 +--------+---------+
                                                                          |
                                                    +---------------------+---------------------+
                                                    | NO                                        | YES
                                                    v                                           v
                                          +------------------+                    +------------------+
                                          | Return base      |                    | Variant file     |
                                          | (no override)    |                    | exists?          |
                                          +------------------+                    +--------+---------+
                                                                                           |
                                                                    +----------------------+----------------------+
                                                                    | NO                                          | YES
                                                                    v                                             v
                                                          +------------------+                      +------------------+
                                                          | Apply fallback   |                      | Return variant   |
                                                          | (missing_variant)|                      | path             |
                                                          +------------------+                      +------------------+
```

---

## Example Resolutions

### Example 1: iOS App Building Station 09

```
Input:
  stationId: "09"
  platform: "ios"

Registry lookup:
  platforms.ios.station_overrides["09"] = "platforms/ios/09-billing-ios.md"

File check:
  ".specify/knowledge/platforms/ios/09-billing-ios.md" EXISTS

Output:
  path: ".specify/knowledge/platforms/ios/09-billing-ios.md"
  isVariant: true
  warning: null
```

### Example 2: iOS App, Variant Missing

```
Input:
  stationId: "09"
  platform: "ios"

Registry lookup:
  platforms.ios.station_overrides["09"] = "platforms/ios/09-billing-ios.md"

File check:
  ".specify/knowledge/platforms/ios/09-billing-ios.md" NOT FOUND

Fallback:
  action: "load_base_with_warning"

Output:
  path: ".specify/knowledge/stations/09-billing.md"
  isVariant: false
  warning: "WARNING: Platform variant not found..."
```

### Example 3: Web App (No Platform Specified)

```
Input:
  stationId: "09"
  platform: null

Output:
  path: ".specify/knowledge/stations/09-billing.md"
  isVariant: false
  warning: null
```

### Example 4: Unknown Platform

```
Input:
  stationId: "09"
  platform: "roku"

Registry lookup:
  platforms.roku = null (not defined)

Fallback:
  action: "load_base_with_warning"

Output:
  path: ".specify/knowledge/stations/09-billing.md"
  isVariant: false
  warning: "WARNING: Unknown platform 'roku'..."
```

### Example 5: Station With No Override

```
Input:
  stationId: "03"  # Discovery - platform-agnostic
  platform: "ios"

Registry lookup:
  platforms.ios.station_overrides["03"] = null (no override)

Output:
  path: ".specify/knowledge/stations/03-discovery.md"
  isVariant: false
  warning: null
```

---

## Multi-Station Batch Resolution

When loading multiple stations (e.g., during Phase 0.1), use batch resolution:

```
FUNCTION resolveStationsForPlatform(stationIds[], platform):
    results = []
    warnings = []

    FOR EACH stationId IN stationIds:
        result = resolveStationPath(stationId, platform)
        results.append({
            stationId: stationId,
            path: result.path,
            isVariant: result.isVariant
        })
        IF result.warning IS NOT NULL:
            warnings.append(result.warning)

    # Report aggregated results
    variantCount = count(results WHERE isVariant == true)
    baseCount = count(results WHERE isVariant == false)

    RETURN {
        stations: results,
        summary: {
            total: results.length,
            variants_loaded: variantCount,
            base_loaded: baseCount,
            platform: platform
        },
        warnings: warnings
    }

END FUNCTION
```

---

## Integration Points

### Where Resolution Happens

1. **plan.md Phase 0.1** - Load Domain Knowledge
2. **Subagent invocation** - When spawning domain-specific agents
3. **Task generation** - When wiring knowledge into tasks
4. **Code review** - When validating against domain rules

### How Platform is Determined

Platform should be detected from (in priority order):

1. **Explicit spec field**: `spec.md` contains `target_platform: ios`
2. **Registry inference**: `registry.yaml` has `frontend.framework: react-native`
3. **User prompt**: User explicitly states "building an iOS app"
4. **Default**: `web` (backward compatible)

---

## Error Handling Summary

| Condition | Default Action | Alternative Actions |
|-----------|---------------|---------------------|
| Registry missing | Load base (silent) | n/a |
| Platform unknown | Load base + warning | error, load_base_silent |
| Variant missing | Load base + warning | error, load_base_silent |
| Station missing | ERROR | n/a (always error) |

---

## Testing the Algorithm

Create test cases covering:

1. Happy path - variant exists and loads
2. No registry file - falls back silently
3. Unknown platform - falls back with warning
4. Missing variant - falls back with warning
5. No override defined - uses base
6. Web platform - uses base
7. Null platform - uses base
8. Multiple stations batch - aggregates correctly
