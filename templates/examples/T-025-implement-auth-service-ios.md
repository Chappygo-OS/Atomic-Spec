# T-025-implement-auth-service

**Status**: Pending
**Created**: 2026-03-02 | **Completed**: N/A
**User Story**: US1: User Authentication
**Requirement**: FR-005

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
| `architecture.pattern` | clean |
| `architecture.layers` | clean |
| `code_patterns.data_access` | repository |
| `code_patterns.error_handling` | result_type |
| `conventions.files` | PascalCase |
| `conventions.variables` | camelCase |
| **Verification Platform** | **ios** (uses xcodebuild, swift test, swiftlint) |

### Domain Rules (from ios-developer subagent)

- **Architecture**: Use Clean Architecture with Use Cases, Entities, and Repositories
- **Error Handling**: Return `Result<T, Error>` types, never throw exceptions in service layer
- **Async Pattern**: Use async/await with Swift Concurrency
- **Keychain Storage**: Use Keychain for storing authentication tokens securely
- **Token Refresh**: Implement automatic token refresh before expiration
- **Biometrics**: Support Face ID/Touch ID for re-authentication
- **State Management**: Use `@Observable` macro for iOS 17+ or `ObservableObject` for older versions

### API Context (from contracts/)

```yaml
POST /api/v1/auth/login:
  request:
    email: string (required)
    password: string (required)
  response:
    accessToken: string
    refreshToken: string
    expiresIn: number (seconds)
    user:
      id: string
      email: string
      name: string

POST /api/v1/auth/refresh:
  request:
    refreshToken: string (required)
  response:
    accessToken: string
    refreshToken: string
    expiresIn: number

POST /api/v1/auth/logout:
  request:
    refreshToken: string (required)
  response:
    success: boolean
```

### Feature Summary

This feature implements user authentication for the iOS mobile app, allowing users to log in with email/password, maintain sessions using JWT tokens stored securely in Keychain, and support biometric re-authentication. The auth service handles token refresh automatically and provides a clean interface for the rest of the app.

### Gate Criteria (from ios-developer subagent)

- [ ] Service uses async/await (Swift Concurrency)
- [ ] Tokens stored in Keychain, never UserDefaults
- [ ] Error handling uses Result type
- [ ] Unit tests cover success and failure paths
- [ ] No force unwrapping (!) in production code

---

## Objective

Implement the `AuthService` class that handles user authentication including login, logout, and automatic token refresh, with secure Keychain storage.

---

## Technical Implementation Detail

### Files to Create

- `Sources/Services/Auth/AuthService.swift` - Main authentication service
- `Sources/Services/Auth/AuthServiceProtocol.swift` - Protocol/interface definition
- `Sources/Services/Auth/KeychainManager.swift` - Keychain wrapper for secure storage
- `Sources/Models/Auth/AuthTokens.swift` - Token models
- `Sources/Models/Auth/AuthUser.swift` - User model
- `Sources/Models/Auth/AuthError.swift` - Authentication error types
- `Tests/ServicesTests/AuthServiceTests.swift` - Unit tests

### Files to Update (REQUIRED)

- `Sources/App/DependencyContainer.swift` - Register `AuthService` in DI container
- `Sources/Services/ServiceRegistry.swift` - Export `AuthService` and protocol

### Dependencies

- [T-010-setup-project](./T-010-setup-project.md) - Project structure and dependencies
- [T-020-create-api-client](./T-020-create-api-client.md) - Base API client for network requests

### Implementation Steps

1. **Create AuthError enum** (`AuthError.swift`):
   ```swift
   enum AuthError: Error {
       case invalidCredentials
       case networkError(Error)
       case tokenExpired
       case keychainError(Error)
       case unauthorized
       case unknown(Error)
   }
   ```

2. **Create token models** (`AuthTokens.swift`):
   ```swift
   struct AuthTokens: Codable {
       let accessToken: String
       let refreshToken: String
       let expiresIn: Int
       var expirationDate: Date { ... }
   }
   ```

3. **Create KeychainManager** (`KeychainManager.swift`):
   - `save(tokens: AuthTokens)`
   - `getTokens() -> AuthTokens?`
   - `deleteTokens()`
   - Use Security framework, not third-party libraries

4. **Create AuthServiceProtocol** (`AuthServiceProtocol.swift`):
   ```swift
   protocol AuthServiceProtocol {
       func login(email: String, password: String) async -> Result<AuthUser, AuthError>
       func logout() async -> Result<Void, AuthError>
       func refreshTokenIfNeeded() async -> Result<Void, AuthError>
       var isAuthenticated: Bool { get }
       var currentUser: AuthUser? { get }
   }
   ```

5. **Implement AuthService** (`AuthService.swift`):
   - Inject `APIClient` and `KeychainManager`
   - Implement all protocol methods
   - Handle token refresh 5 minutes before expiration
   - Publish authentication state changes

6. **Write unit tests** (`AuthServiceTests.swift`):
   - Test successful login stores tokens
   - Test failed login returns error
   - Test logout clears tokens
   - Test token refresh on expiration
   - Use mock API client and keychain

7. **Register in DI container** (`DependencyContainer.swift`):
   ```swift
   container.register(AuthServiceProtocol.self) { resolver in
       AuthService(
           apiClient: resolver.resolve(APIClientProtocol.self)!,
           keychainManager: KeychainManager()
       )
   }
   ```

### Acceptance Criteria

- [ ] User can log in with valid email/password
- [ ] Authentication tokens stored securely in Keychain
- [ ] Invalid credentials return appropriate error
- [ ] Token automatically refreshes before expiration
- [ ] Logout clears all stored tokens
- [ ] `isAuthenticated` accurately reflects auth state
- [ ] All unit tests pass

---

## Wiring Checklist

- [x] **Backend route** → N/A (this is client-side)
- [ ] **Service** → Registered in `DependencyContainer.swift`
- [ ] **Protocol** → Exported from `ServiceRegistry.swift`
- [ ] **Environment** → Add `AUTH_API_BASE_URL` to `.env.example` (if needed)

---

## Verification Command

**Platform**: iOS (detected from registry)
**Tools**: xcodebuild, swift test, swiftlint

### Primary Verification (Full Test Suite)

```bash
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MyAppTests/AuthServiceTests \
  | xcpretty
```

**Expected Output**:
```
Test Suite 'AuthServiceTests' started
  Test Case 'testLoginSuccess' passed (0.023 seconds)
  Test Case 'testLoginInvalidCredentials' passed (0.015 seconds)
  Test Case 'testLogoutClearsTokens' passed (0.012 seconds)
  Test Case 'testTokenRefreshBeforeExpiration' passed (0.018 seconds)
Test Suite 'AuthServiceTests' passed
Test Succeeded
```

### Alternative Verification (Swift Package Manager)

```bash
swift test --filter AuthServiceTests
```

**Expected Output**:
```
Test Suite 'All tests' started
Test Suite 'AuthServiceTests' started
...
Test Suite 'All tests' passed
```

### Fallback Verification (Compile Check)

If testing tools are unavailable, verify the code compiles:

```bash
xcodebuild build \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  | xcpretty
```

**Expected Output**:
```
Build Succeeded
```

### Lint Verification

```bash
swiftlint lint Sources/Services/Auth/ --strict
```

**Expected Output**:
```
Linting Swift files in Sources/Services/Auth/
Done linting! Found 0 violations, 0 serious.
```

**Lint Fallback** (if swiftlint unavailable):

```bash
swift -parse Sources/Services/Auth/AuthService.swift && echo "Syntax OK"
```

---

## Completion Checklist

- [ ] Implementation complete
- [ ] Acceptance criteria met
- [ ] All verification commands pass (at least primary OR fallback)
- [ ] Wiring checklist complete
- [ ] Updated traceability.md
- [ ] Gate criteria verified

---

## Notes for Implementer

1. **Keychain Access**: On macOS (for testing), you may need to add Keychain entitlements to the test target.

2. **Simulator vs Device**: Tests should work on both simulator and device. The verification command uses simulator for CI compatibility.

3. **Token Storage**: Never log or print tokens. Use redacted descriptions in debug output.

4. **Concurrency**: Ensure thread safety when accessing `currentUser` and `isAuthenticated` properties.

5. **Testing**: Mock both `APIClient` and `KeychainManager` in tests to isolate the service logic.
