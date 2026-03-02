# T-020-implement-ios-auth-service

**Status**: Pending
**Created**: 2026-03-02 | **Completed**: N/A
**User Story**: US1: User Authentication
**Requirement**: FR-003

---

## Embedded Context (READ THIS FIRST)

<!--
  SELF-CONTAINED TASK (Constitution Directive 8):
  This section contains ALL context needed to implement this task.
  Do NOT read plan.md, spec.md, stations, or subagents.
-->

### Project Standards (from registry)

| Key | Value |
|-----|-------|
| `target_platform.primary` | mobile |
| `target_platform.mobile_platforms` | ios |
| `target_platform.mobile_framework` | native |
| `backend.language` | python |
| `backend.framework` | fastapi |
| `code_patterns.error_handling` | result_type |
| `code_patterns.async_pattern` | async_await |
| `conventions.files` | PascalCase |
| **Verification Platform** | **ios** (uses xcodebuild, swift test, swiftlint) |

### Domain Rules (from ios-developer subagent)

- **Architecture**: MVVM with SwiftUI, using `@MainActor` for UI updates
- **Keychain**: Store tokens in Keychain, NEVER UserDefaults
- **Biometrics**: Support Face ID/Touch ID with LAContext fallback
- **Error Handling**: Use Swift Result type with typed errors
- **Async**: Use async/await with Task for concurrency
- **Dependency Injection**: Use environment objects or protocol-based injection

### API Context (from contracts/)

```yaml
POST /api/v1/auth/login
  Request:
    - email: string (required)
    - password: string (required)
  Response:
    - access_token: string (JWT)
    - refresh_token: string
    - expires_in: int (seconds)
    - user: { id, email, name }
  Errors:
    - 401: Invalid credentials
    - 422: Validation error
    - 429: Rate limited

POST /api/v1/auth/refresh
  Request:
    - refresh_token: string (required)
  Response:
    - access_token: string
    - expires_in: int

POST /api/v1/auth/logout
  Headers:
    - Authorization: Bearer {access_token}
  Response:
    - success: boolean
```

### Feature Summary

This feature implements user authentication for the iOS app, allowing users to securely
log in with email/password, persist sessions using Keychain storage, and optionally
use Face ID/Touch ID for quick re-authentication. The authentication state is managed
centrally and available throughout the app via SwiftUI environment.

### Gate Criteria (from ios-developer subagent)

- [ ] Tokens stored in Keychain (NOT UserDefaults)
- [ ] Biometric authentication implemented with fallback
- [ ] Result type used for error handling
- [ ] All async operations use async/await
- [ ] AuthService protocol defined for testability
- [ ] Unit tests cover success and error paths
- [ ] No force unwraps in authentication code

---

## Objective

Create the AuthService that handles login, logout, token management, and biometric authentication
using async/await patterns and Keychain storage.

## Technical Implementation Detail

### Files to Create

- `Sources/Services/Auth/AuthService.swift` - Main authentication service protocol and implementation
- `Sources/Services/Auth/KeychainManager.swift` - Keychain wrapper for secure token storage
- `Sources/Services/Auth/BiometricAuthManager.swift` - Face ID/Touch ID handling
- `Sources/Models/Auth/AuthToken.swift` - Token model with expiration logic
- `Sources/Models/Auth/AuthError.swift` - Typed authentication errors
- `Sources/Models/Auth/User.swift` - User model
- `Tests/Services/AuthServiceTests.swift` - Unit tests for AuthService
- `Tests/Services/MockAuthService.swift` - Mock for testing dependent components

### Files to Update (REQUIRED)

- `Sources/App/Dependencies.swift` - Register AuthService in dependency container
- `Sources/App/Environment+Auth.swift` - Add authService environment key
- `Sources/Network/APIClient.swift` - Add auth token injection to requests
- `Sources/App/MyApp.swift` - Provide AuthService to environment

### Code/Logic Requirements

**AuthService Protocol:**
```swift
protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get async }
    var currentUser: User? { get async }

    func login(email: String, password: String) async -> Result<User, AuthError>
    func logout() async -> Result<Void, AuthError>
    func refreshTokenIfNeeded() async -> Result<Void, AuthError>
    func authenticateWithBiometrics() async -> Result<User, AuthError>
}
```

**AuthError Types:**
```swift
enum AuthError: Error, Equatable {
    case invalidCredentials
    case networkError(String)
    case tokenExpired
    case biometricNotAvailable
    case biometricFailed
    case keychainError(String)
    case serverError(Int, String)
}
```

**Keychain Storage Keys:**
- `com.myapp.auth.accessToken`
- `com.myapp.auth.refreshToken`
- `com.myapp.auth.tokenExpiry`

**Implementation Notes:**
- Use `@MainActor` for AuthService to ensure thread-safe state updates
- Implement automatic token refresh when access token is within 5 minutes of expiry
- Store biometric preference in UserDefaults (NOT the tokens)
- Log authentication events but NEVER log tokens or passwords

---

## Wiring Checklist

**iOS Native:**
- [ ] AuthService registered in dependency container (Dependencies.swift)
- [ ] AuthService added to SwiftUI environment (MyApp.swift)
- [ ] Environment key created for authService access
- [ ] APIClient updated to inject Bearer token
- [ ] No Info.plist changes needed (Face ID permission already configured)

---

## Verification Command

**Primary** (requires xcodebuild + xcpretty):
```bash
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MyAppTests/AuthServiceTests \
  | xcpretty
```

**Alternative** (Swift Package Manager - if AuthService is in a package):
```bash
swift test --filter "AuthServiceTests"
```

**Fallback** (build-only verification if tests not ready):
```bash
xcodebuild build \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED)" | tail -1
```

**Lint Check:**
```bash
swiftlint lint Sources/Services/Auth/ --strict
```

**Expected Output**:
```
Test Suite 'AuthServiceTests' started at 2026-03-02 10:30:00.000
Test Case 'AuthServiceTests.testLoginWithValidCredentials' passed (0.15 seconds)
Test Case 'AuthServiceTests.testLoginWithInvalidCredentials' passed (0.08 seconds)
Test Case 'AuthServiceTests.testTokenStoredInKeychain' passed (0.12 seconds)
Test Case 'AuthServiceTests.testLogoutClearsTokens' passed (0.05 seconds)
Test Case 'AuthServiceTests.testBiometricAuthWhenEnabled' passed (0.20 seconds)
Test Suite 'AuthServiceTests' passed at 2026-03-02 10:30:01.000
    Executed 5 tests, with 0 failures (0 unexpected) in 0.60 (0.65) seconds
```

**Tool Availability Check:**
```bash
xcodebuild -version && (swiftlint version || echo "swiftlint not installed - using fallback")
```

---

## Integration Verification

After wiring is complete, verify the service is accessible:

```bash
# Build and run app in simulator
xcodebuild build \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  && xcrun simctl boot "iPhone 15" 2>/dev/null || true \
  && xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/MyApp.app \
  && xcrun simctl launch booted com.mycompany.myapp

# Verify app launches without crash (check Console.app for auth-related logs)
```

---

## Completion Checklist

- [ ] AuthService protocol defined
- [ ] AuthService implementation complete
- [ ] KeychainManager stores/retrieves tokens
- [ ] BiometricAuthManager handles Face ID/Touch ID
- [ ] Error types fully defined
- [ ] Unit tests written and passing
- [ ] Mock service created for other tests
- [ ] Service wired into dependency container
- [ ] Service available in SwiftUI environment
- [ ] APIClient injects auth token
- [ ] SwiftLint passes with no warnings
- [ ] Gate criteria verified (Keychain, biometrics, Result type)
- [ ] Updated traceability.md

---

## Test Cases to Implement

```swift
final class AuthServiceTests: XCTestCase {

    // MARK: - Login Tests

    func testLoginWithValidCredentials() async {
        // Given: Valid email and password
        // When: login() is called
        // Then: Returns .success with User
        // And: Tokens are stored in Keychain
    }

    func testLoginWithInvalidCredentials() async {
        // Given: Invalid password
        // When: login() is called
        // Then: Returns .failure(.invalidCredentials)
        // And: No tokens stored
    }

    func testLoginWithNetworkError() async {
        // Given: Network is unavailable
        // When: login() is called
        // Then: Returns .failure(.networkError)
    }

    // MARK: - Token Management Tests

    func testTokenStoredInKeychain() async {
        // Given: Successful login
        // When: Checking Keychain
        // Then: Access and refresh tokens are stored
    }

    func testTokenRefreshWhenNearExpiry() async {
        // Given: Token expires in 3 minutes
        // When: refreshTokenIfNeeded() is called
        // Then: New token is fetched and stored
    }

    // MARK: - Logout Tests

    func testLogoutClearsTokens() async {
        // Given: User is logged in
        // When: logout() is called
        // Then: All tokens removed from Keychain
        // And: isAuthenticated returns false
    }

    // MARK: - Biometric Tests

    func testBiometricAuthWhenEnabled() async {
        // Given: Biometrics available and user preference enabled
        // When: authenticateWithBiometrics() is called
        // Then: Returns .success after biometric verification
    }

    func testBiometricAuthWhenNotAvailable() async {
        // Given: Biometrics not available on device
        // When: authenticateWithBiometrics() is called
        // Then: Returns .failure(.biometricNotAvailable)
    }
}
```

---

## Notes for Implementer

1. **Security First**: Never log tokens, passwords, or sensitive data. Use `os_log` with appropriate privacy levels.

2. **Keychain Access**: Use `kSecAttrAccessible` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for tokens.

3. **Error Messages**: User-facing error messages should be generic ("Login failed") while internal errors can be detailed.

4. **Token Refresh Race Condition**: Ensure only one refresh operation happens at a time using an actor or lock.

5. **Testing**: Use dependency injection to allow mock Keychain and mock network in tests.
