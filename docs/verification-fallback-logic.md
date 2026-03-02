# Verification Command Fallback Logic

**Purpose**: Ensure every atomic task has a working verification command, even when primary tools are unavailable.

---

## Overview

The verification system follows a three-tier fallback strategy:

```
Primary Tool → Alternative Tools → Language-Native Fallback → Manual Checklist
```

Each task's verification command should include at least the primary and one fallback option.

---

## Fallback Decision Tree

```
                    ┌─────────────────────┐
                    │  Detect Platform    │
                    │  (Section 4.2.4)    │
                    └─────────┬───────────┘
                              │
                    ┌─────────▼───────────┐
                    │  Load Template from │
                    │  verification-      │
                    │  commands.yaml      │
                    └─────────┬───────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼─────┐ ┌───────▼───────┐ ┌─────▼─────────┐
    │ Unit Tests    │ │ Lint/Format   │ │ Build/Compile │
    └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
            │                 │                 │
    ┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
    │ Primary:      │ │ Primary:      │ │ Primary:      │
    │ Framework     │ │ Dedicated     │ │ Framework     │
    │ Test Runner   │ │ Linter        │ │ Build Tool    │
    └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
            │ fail            │ fail            │ fail
    ┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
    │ Alternative:  │ │ Alternative:  │ │ Alternative:  │
    │ Language      │ │ Syntax        │ │ Compiler      │
    │ Test Tool     │ │ Checker       │ │ Only          │
    └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
            │ fail            │ fail            │ fail
    ┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
    │ Fallback:     │ │ Fallback:     │ │ Fallback:     │
    │ Compile Check │ │ Parse Check   │ │ File Exists   │
    └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
            │ fail            │ fail            │ fail
    ┌───────▼─────────────────▼─────────────────▼───────┐
    │              Manual Verification                   │
    │              (with explicit criteria)              │
    └───────────────────────────────────────────────────┘
```

---

## Platform-Specific Fallback Chains

### iOS (Swift/Xcode)

| Verification Type | Primary | Alternative | Fallback |
|-------------------|---------|-------------|----------|
| Unit Tests | `xcodebuild test -only-testing:...` | `swift test --filter` | `xcodebuild build` (compile check) |
| Lint | `swiftlint lint --strict` | `swiftformat --lint` | `swift -parse` (syntax check) |
| Build | `xcodebuild build` | `swift build` | `swift -typecheck` |
| Type Check | `xcodebuild build` | `swift -typecheck` | File exists |

**iOS Fallback Example:**
```markdown
## Verification Command

**Primary** (xcodebuild + xcpretty):
```bash
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MyAppTests/AuthServiceTests \
  | xcpretty
```

**Alternative** (swift test - for SPM projects):
```bash
swift test --filter AuthServiceTests
```

**Fallback** (compile check only):
```bash
xcodebuild build \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  | xcpretty
```

**Expected Output**: `Test Succeeded` or `Build Succeeded`
```

### Android (Kotlin/Gradle)

| Verification Type | Primary | Alternative | Fallback |
|-------------------|---------|-------------|----------|
| Unit Tests | `./gradlew test --tests "..."` | `./gradlew testDebugUnitTest` | `./gradlew compileDebugKotlin` |
| Lint | `./gradlew ktlintCheck` | `./gradlew detekt` | `./gradlew compileDebugKotlin` |
| Build | `./gradlew assembleDebug` | `./gradlew compileDebugKotlin` | File exists |

### Flutter

| Verification Type | Primary | Alternative | Fallback |
|-------------------|---------|-------------|----------|
| Unit Tests | `flutter test --name "..."` | `flutter test [file]` | `dart analyze` |
| Lint | `dart analyze` | `flutter analyze` | `dart format --set-exit-if-changed` |
| Build | `flutter build ios/apk` | `flutter build` | `flutter pub get` |

### React Native

| Verification Type | Primary | Alternative | Fallback |
|-------------------|---------|-------------|----------|
| Unit Tests | `npx jest --testNamePattern` | `npm test -- --testNamePattern` | `npx tsc --noEmit` |
| Lint | `npx eslint` | `npx tsc --noEmit` | `node --check` |
| Build (iOS) | `npx react-native build-ios` | `cd ios && xcodebuild build` | `npx tsc --noEmit` |
| Build (Android) | `npx react-native build-android` | `cd android && ./gradlew assembleDebug` | `npx tsc --noEmit` |

### Python

| Verification Type | Primary | Alternative | Fallback |
|-------------------|---------|-------------|----------|
| Unit Tests | `pytest -k "..."` | `python -m unittest` | `python -m py_compile` |
| Lint | `ruff check` | `flake8` | `python -m py_compile` |
| Type Check | `mypy --strict` | `pyright` | `python -c "import module"` |

### Go

| Verification Type | Primary | Alternative | Fallback |
|-------------------|---------|-------------|----------|
| Unit Tests | `go test -run "..."` | `go test ./...` | `go build ./...` |
| Lint | `golangci-lint run` | `staticcheck` | `go vet ./...` |
| Build | `go build -o ./bin/app` | `go build ./...` | File exists |

---

## Tool Availability Detection

Before generating verification commands, check tool availability using these patterns:

```yaml
# From verification-commands.yaml tool_detection section

# iOS
xcodebuild: "command -v xcodebuild >/dev/null 2>&1"
swift: "command -v swift >/dev/null 2>&1"
swiftlint: "command -v swiftlint >/dev/null 2>&1"

# Android
gradle: "./gradlew --version 2>/dev/null || command -v gradle >/dev/null 2>&1"
adb: "command -v adb >/dev/null 2>&1"

# Flutter
flutter: "command -v flutter >/dev/null 2>&1"
dart: "command -v dart >/dev/null 2>&1"

# Node/Web
npm: "command -v npm >/dev/null 2>&1"
npx: "command -v npx >/dev/null 2>&1"

# Python
pytest: "python -m pytest --version 2>/dev/null"
ruff: "command -v ruff >/dev/null 2>&1"

# Go
go: "command -v go >/dev/null 2>&1"
golangci-lint: "command -v golangci-lint >/dev/null 2>&1"
```

---

## Manual Verification Template

When all automated options fail, provide a structured manual verification:

```markdown
## Verification Command

**Automated verification unavailable.**

Reason: [e.g., "No iOS simulator available in CI environment"]

### Manual Verification Steps

1. Open the project in [IDE/tool]
2. Navigate to [file/location]
3. Perform [specific action]
4. Verify [expected behavior]

### Success Criteria

- [ ] [Criterion 1 - specific and measurable]
- [ ] [Criterion 2 - specific and measurable]
- [ ] [Criterion 3 - specific and measurable]

### Evidence Required

- Screenshot showing [specific state]
- Log output containing [specific text]
- Build artifact at [path]
```

---

## Fallback Selection Algorithm

When generating tasks, use this algorithm to select verification commands:

```python
def select_verification_command(platform, task_type, available_tools):
    """
    Select the best verification command with fallbacks.

    Args:
        platform: Detected platform (ios, android, flutter, etc.)
        task_type: Type of task (unit_test, lint, build, etc.)
        available_tools: Set of tools confirmed available

    Returns:
        dict with 'primary', 'fallback', and 'expected_output'
    """
    templates = load_yaml("templates/verification-commands.yaml")
    platform_templates = templates[platform][task_type]

    result = {
        'primary': None,
        'fallback': None,
        'expected_output': None
    }

    # Try primary
    primary = platform_templates.get('primary', {})
    if primary.get('tool') in available_tools or not available_tools:
        result['primary'] = primary.get('command')
        result['expected_output'] = primary.get('expected_output')

    # Try alternatives in order
    for alt in platform_templates.get('alternatives', []):
        if alt.get('tool') in available_tools or result['primary'] is None:
            if result['primary'] is None:
                result['primary'] = alt.get('command')
                result['expected_output'] = alt.get('expected_output')
            elif result['fallback'] is None:
                result['fallback'] = alt.get('command')

    # Use language-native fallback
    if result['fallback'] is None:
        fallback = platform_templates.get('fallback', {})
        result['fallback'] = fallback.get('command')

    # If still no fallback, use universal fallbacks
    if result['fallback'] is None:
        result['fallback'] = templates['fallback_strategy']['universal_fallbacks']['file_exists']['command']

    return result
```

---

## Integration with Task Generation

During `/speckit.tasks`, the task generator should:

1. **Detect platform** (Section 4.2.4 Step 1)
2. **Load verification templates** from `verification-commands.yaml`
3. **For each task:**
   - Determine task type (unit test, lint, build, etc.)
   - Select primary command from platform templates
   - Select at least one fallback command
   - Replace placeholders with task-specific values
4. **Embed in task file:**
   ```markdown
   ## Verification Command

   **Primary**:
   ```bash
   [primary command]
   ```

   **Fallback**:
   ```bash
   [fallback command]
   ```

   **Expected Output**: [success criteria]
   ```

---

## Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "xcodebuild: command not found" | Running on non-macOS CI | Use `swift test` if SPM, or skip iOS tests in CI |
| "./gradlew: Permission denied" | Missing execute permission | Run `chmod +x gradlew` first |
| "flutter: command not found" | Flutter not in PATH | Add Flutter bin to PATH or use full path |
| "pytest: No module named pytest" | pytest not installed | Use `python -m py_compile` fallback |
| Simulator not booted | iOS Simulator not running | Add `xcrun simctl boot "iPhone 15"` before test |

---

## CI/CD Considerations

Different CI environments have different tools available:

| CI Platform | iOS | Android | Flutter | Node | Python | Go |
|-------------|-----|---------|---------|------|--------|-----|
| GitHub Actions macOS | Full | Full | Manual | Full | Full | Full |
| GitHub Actions Linux | None | Full | Manual | Full | Full | Full |
| GitLab CI | Varies | Full | Manual | Full | Full | Full |
| Bitrise | Full | Full | Full | Full | Varies | Varies |
| CircleCI | Optional | Full | Manual | Full | Full | Full |

**Recommendation**: For mobile projects, include both primary (full test) and fallback (compile check) commands so tasks can be verified in any CI environment.
