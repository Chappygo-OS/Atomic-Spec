---
name: Mobile Social Login Integration
platform: mobile
description: Social authentication integration with Apple, Google, Facebook, and other OAuth providers for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Social Login Integration

## Purpose

Implement secure social authentication flows that provide seamless sign-in experiences using Apple, Google, Facebook, and other identity providers. The authentication layer should handle token management, account linking, and graceful fallbacks while complying with platform requirements.

## Social Login Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Social Auth Flow                               │
├─────────────────────────────────────────────────────────────────┤
│  1. User taps provider button                                   │
│  2. SDK presents auth UI (native or web)                        │
│  3. User authenticates with provider                            │
│  4. Provider returns tokens/credentials                         │
│  5. App sends credentials to backend                            │
│  6. Backend validates with provider                             │
│  7. Backend creates/links user account                          │
│  8. Backend returns app tokens                                  │
│  9. App stores tokens and authenticates user                    │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Social Login

### Sign in with Apple

```swift
// AppleSignInManager.swift
import AuthenticationServices

@Observable
final class AppleSignInManager: NSObject {
    private var currentNonce: String?
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    struct AppleSignInResult {
        let identityToken: String
        let authorizationCode: String
        let user: String
        let email: String?
        let fullName: PersonNameComponents?
    }

    func signIn() async throws -> AppleSignInResult {
        let nonce = generateNonce()
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    func checkCredentialState(userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userId) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCodeData = credential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            continuation?.resume(throwing: SocialAuthError.invalidCredentials)
            return
        }

        let result = AppleSignInResult(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            user: credential.user,
            email: credential.email,
            fullName: credential.fullName
        )

        continuation?.resume(returning: result)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                continuation?.resume(throwing: SocialAuthError.cancelled)
            case .invalidResponse:
                continuation?.resume(throwing: SocialAuthError.invalidResponse)
            case .notHandled:
                continuation?.resume(throwing: SocialAuthError.notHandled)
            case .failed:
                continuation?.resume(throwing: SocialAuthError.failed)
            default:
                continuation?.resume(throwing: SocialAuthError.unknown(error))
            }
        } else {
            continuation?.resume(throwing: SocialAuthError.unknown(error))
        }
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
}
```

### Google Sign-In

```swift
// GoogleSignInManager.swift
import GoogleSignIn

@Observable
final class GoogleSignInManager {
    struct GoogleSignInResult {
        let idToken: String
        let accessToken: String
        let userId: String
        let email: String?
        let fullName: String?
        let profileImageURL: URL?
    }

    func signIn() async throws -> GoogleSignInResult {
        guard let presentingViewController = await getPresentingViewController() else {
            throw SocialAuthError.noPresentingViewController
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error {
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        continuation.resume(throwing: SocialAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: SocialAuthError.unknown(error))
                    }
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: SocialAuthError.invalidCredentials)
                    return
                }

                let result = GoogleSignInResult(
                    idToken: idToken,
                    accessToken: user.accessToken.tokenString,
                    userId: user.userID ?? "",
                    email: user.profile?.email,
                    fullName: user.profile?.name,
                    profileImageURL: user.profile?.imageURL(withDimension: 200)
                )

                continuation.resume(returning: result)
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func restorePreviousSignIn() async throws -> GoogleSignInResult? {
        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error {
                    continuation.resume(throwing: SocialAuthError.unknown(error))
                    return
                }

                guard let user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(returning: nil)
                    return
                }

                let result = GoogleSignInResult(
                    idToken: idToken,
                    accessToken: user.accessToken.tokenString,
                    userId: user.userID ?? "",
                    email: user.profile?.email,
                    fullName: user.profile?.name,
                    profileImageURL: user.profile?.imageURL(withDimension: 200)
                )

                continuation.resume(returning: result)
            }
        }
    }

    @MainActor
    private func getPresentingViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }

        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }

        return topController
    }
}
```

### Social Auth Manager

```swift
// SocialAuthManager.swift
@Observable
final class SocialAuthManager {
    private let appleSignIn = AppleSignInManager()
    private let googleSignIn = GoogleSignInManager()
    private let authService: AuthService

    var isLoading: Bool = false
    var error: SocialAuthError?

    init(authService: AuthService = .shared) {
        self.authService = authService
    }

    func signInWithApple() async throws {
        isLoading = true
        error = nil

        do {
            let result = try await appleSignIn.signIn()

            // Send to backend
            try await authService.authenticateWithApple(
                identityToken: result.identityToken,
                authorizationCode: result.authorizationCode,
                userId: result.user,
                email: result.email,
                fullName: result.fullName
            )
        } catch {
            self.error = error as? SocialAuthError ?? .unknown(error)
            throw error
        }

        isLoading = false
    }

    func signInWithGoogle() async throws {
        isLoading = true
        error = nil

        do {
            let result = try await googleSignIn.signIn()

            // Send to backend
            try await authService.authenticateWithGoogle(
                idToken: result.idToken,
                accessToken: result.accessToken
            )
        } catch {
            self.error = error as? SocialAuthError ?? .unknown(error)
            throw error
        }

        isLoading = false
    }

    func signOut() async {
        googleSignIn.signOut()
        await authService.logout()
    }
}

// SocialAuthError.swift
enum SocialAuthError: LocalizedError {
    case cancelled
    case invalidCredentials
    case invalidResponse
    case notHandled
    case failed
    case noPresentingViewController
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .invalidCredentials:
            return "Invalid credentials received"
        case .invalidResponse:
            return "Invalid response from provider"
        case .notHandled:
            return "Sign in request was not handled"
        case .failed:
            return "Sign in failed"
        case .noPresentingViewController:
            return "Unable to present sign in"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
```

### SwiftUI Sign In Buttons

```swift
// SocialSignInButtons.swift
import AuthenticationServices

struct AppleSignInButton: View {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            onRequest(request)
        } onCompletion: { result in
            onCompletion(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct GoogleSignInButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image("google_logo")
                    .resizable()
                    .frame(width: 24, height: 24)

                Text("Continue with Google")
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.white)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct SocialLoginView: View {
    @State private var socialAuth = SocialAuthManager()

    var body: some View {
        VStack(spacing: 16) {
            AppleSignInButton { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    switch result {
                    case .success:
                        try? await socialAuth.signInWithApple()
                    case .failure(let error):
                        print("Apple sign in error: \(error)")
                    }
                }
            }

            GoogleSignInButton {
                Task {
                    try? await socialAuth.signInWithGoogle()
                }
            }

            if socialAuth.isLoading {
                ProgressView()
            }

            if let error = socialAuth.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}
```

## Android Social Login

### Credential Manager (Android 14+)

```kotlin
// SocialAuthManager.kt
@Singleton
class SocialAuthManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val authRepository: AuthRepository
) {
    private val credentialManager = CredentialManager.create(context)

    data class SocialSignInResult(
        val provider: String,
        val idToken: String,
        val email: String?,
        val displayName: String?,
        val profilePictureUrl: String?
    )

    suspend fun signInWithGoogle(activity: Activity): SocialSignInResult {
        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setAutoSelectEnabled(true)
            .setNonce(generateNonce())
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        val result = credentialManager.getCredential(
            request = request,
            context = activity
        )

        return processCredentialResult(result)
    }

    suspend fun signInWithPasskey(activity: Activity): SocialSignInResult {
        val passkeyOption = GetPublicKeyCredentialOption(
            requestJson = buildPasskeyRequestJson()
        )

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(passkeyOption)
            .build()

        val result = credentialManager.getCredential(
            request = request,
            context = activity
        )

        return processCredentialResult(result)
    }

    private fun processCredentialResult(result: GetCredentialResponse): SocialSignInResult {
        return when (val credential = result.credential) {
            is GoogleIdTokenCredential -> {
                SocialSignInResult(
                    provider = "google",
                    idToken = credential.idToken,
                    email = credential.id,
                    displayName = credential.displayName,
                    profilePictureUrl = credential.profilePictureUri?.toString()
                )
            }
            is PublicKeyCredential -> {
                SocialSignInResult(
                    provider = "passkey",
                    idToken = credential.authenticationResponseJson,
                    email = null,
                    displayName = null,
                    profilePictureUrl = null
                )
            }
            else -> throw SocialAuthException("Unsupported credential type")
        }
    }

    private fun generateNonce(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }

    private fun buildPasskeyRequestJson(): String {
        return """
            {
                "challenge": "${generateNonce()}",
                "rpId": "${BuildConfig.RP_ID}",
                "userVerification": "required",
                "timeout": 60000
            }
        """.trimIndent()
    }
}

// Legacy Google Sign-In (for older Android versions)
@Singleton
class GoogleSignInManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val googleSignInClient: GoogleSignInClient by lazy {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .requestEmail()
            .requestProfile()
            .build()

        GoogleSignIn.getClient(context, gso)
    }

    fun getSignInIntent(): Intent = googleSignInClient.signInIntent

    suspend fun handleSignInResult(data: Intent?): GoogleSignInResult {
        return withContext(Dispatchers.IO) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            val account = task.getResult(ApiException::class.java)

            GoogleSignInResult(
                idToken = account.idToken ?: throw SocialAuthException("No ID token"),
                email = account.email,
                displayName = account.displayName,
                profilePictureUrl = account.photoUrl?.toString()
            )
        }
    }

    fun signOut() {
        googleSignInClient.signOut()
    }

    fun revokeAccess() {
        googleSignInClient.revokeAccess()
    }

    data class GoogleSignInResult(
        val idToken: String,
        val email: String?,
        val displayName: String?,
        val profilePictureUrl: String?
    )
}
```

### Compose Social Login Buttons

```kotlin
// SocialSignInButtons.kt
@Composable
fun GoogleSignInButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp),
        enabled = !isLoading,
        shape = RoundedCornerShape(8.dp),
        border = BorderStroke(1.dp, Color.LightGray),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = Color.White
        )
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(24.dp),
                strokeWidth = 2.dp
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Image(
                    painter = painterResource(id = R.drawable.ic_google),
                    contentDescription = null,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Continue with Google",
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.Black
                )
            }
        }
    }
}

@Composable
fun FacebookSignInButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp),
        enabled = !isLoading,
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF1877F2)
        )
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(24.dp),
                strokeWidth = 2.dp,
                color = Color.White
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_facebook),
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    tint = Color.White
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Continue with Facebook",
                    style = MaterialTheme.typography.labelLarge,
                    color = Color.White
                )
            }
        }
    }
}

// SocialLoginScreen.kt
@Composable
fun SocialLoginScreen(
    viewModel: SocialLoginViewModel = hiltViewModel(),
    onLoginSuccess: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = context as Activity

    val googleSignInLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        viewModel.handleGoogleSignInResult(result.data)
    }

    LaunchedEffect(uiState.isAuthenticated) {
        if (uiState.isAuthenticated) {
            onLoginSuccess()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Welcome",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Sign in to continue",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(48.dp))

        // Google Sign In
        GoogleSignInButton(
            onClick = {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    viewModel.signInWithCredentialManager(activity)
                } else {
                    googleSignInLauncher.launch(viewModel.getGoogleSignInIntent())
                }
            },
            isLoading = uiState.isLoading && uiState.loadingProvider == "google"
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Facebook Sign In
        FacebookSignInButton(
            onClick = { viewModel.signInWithFacebook(activity) },
            isLoading = uiState.isLoading && uiState.loadingProvider == "facebook"
        )

        // Error message
        AnimatedVisibility(visible = uiState.error != null) {
            Text(
                text = uiState.error ?: "",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 16.dp)
            )
        }
    }
}
```

## React Native Social Login

### Social Auth Hooks

```typescript
// hooks/useSocialAuth.ts
import { GoogleSignin, statusCodes } from '@react-native-google-signin/google-signin';
import { appleAuth } from '@invertase/react-native-apple-authentication';
import { LoginManager, AccessToken, Profile } from 'react-native-fbsdk-next';
import { useAuthStore } from '../stores/authStore';

// Configure Google Sign-In
GoogleSignin.configure({
  webClientId: Config.GOOGLE_WEB_CLIENT_ID,
  offlineAccess: true,
  scopes: ['profile', 'email'],
});

interface SocialAuthResult {
  provider: 'google' | 'apple' | 'facebook';
  idToken?: string;
  accessToken?: string;
  user: {
    id: string;
    email?: string;
    name?: string;
    photo?: string;
  };
}

export const useSocialAuth = () => {
  const { loginWithSocial } = useAuthStore();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const signInWithGoogle = async (): Promise<SocialAuthResult | null> => {
    setIsLoading(true);
    setError(null);

    try {
      await GoogleSignin.hasPlayServices();
      const userInfo = await GoogleSignin.signIn();
      const tokens = await GoogleSignin.getTokens();

      const result: SocialAuthResult = {
        provider: 'google',
        idToken: userInfo.idToken || undefined,
        accessToken: tokens.accessToken,
        user: {
          id: userInfo.user.id,
          email: userInfo.user.email,
          name: userInfo.user.name || undefined,
          photo: userInfo.user.photo || undefined,
        },
      };

      await loginWithSocial(result);
      return result;
    } catch (error: any) {
      if (error.code === statusCodes.SIGN_IN_CANCELLED) {
        // User cancelled
      } else if (error.code === statusCodes.IN_PROGRESS) {
        setError('Sign in is already in progress');
      } else if (error.code === statusCodes.PLAY_SERVICES_NOT_AVAILABLE) {
        setError('Google Play Services not available');
      } else {
        setError(error.message || 'Google sign in failed');
      }
      return null;
    } finally {
      setIsLoading(false);
    }
  };

  const signInWithApple = async (): Promise<SocialAuthResult | null> => {
    if (!appleAuth.isSupported) {
      setError('Apple Sign-In not supported on this device');
      return null;
    }

    setIsLoading(true);
    setError(null);

    try {
      const appleAuthRequestResponse = await appleAuth.performRequest({
        requestedOperation: appleAuth.Operation.LOGIN,
        requestedScopes: [appleAuth.Scope.EMAIL, appleAuth.Scope.FULL_NAME],
      });

      const credentialState = await appleAuth.getCredentialStateForUser(
        appleAuthRequestResponse.user
      );

      if (credentialState !== appleAuth.State.AUTHORIZED) {
        throw new Error('Apple Sign-In not authorized');
      }

      const result: SocialAuthResult = {
        provider: 'apple',
        idToken: appleAuthRequestResponse.identityToken || undefined,
        user: {
          id: appleAuthRequestResponse.user,
          email: appleAuthRequestResponse.email || undefined,
          name: appleAuthRequestResponse.fullName
            ? `${appleAuthRequestResponse.fullName.givenName || ''} ${
                appleAuthRequestResponse.fullName.familyName || ''
              }`.trim()
            : undefined,
        },
      };

      await loginWithSocial(result);
      return result;
    } catch (error: any) {
      if (error.code === appleAuth.Error.CANCELED) {
        // User cancelled
      } else {
        setError(error.message || 'Apple sign in failed');
      }
      return null;
    } finally {
      setIsLoading(false);
    }
  };

  const signInWithFacebook = async (): Promise<SocialAuthResult | null> => {
    setIsLoading(true);
    setError(null);

    try {
      const result = await LoginManager.logInWithPermissions([
        'public_profile',
        'email',
      ]);

      if (result.isCancelled) {
        return null;
      }

      const accessToken = await AccessToken.getCurrentAccessToken();
      if (!accessToken) {
        throw new Error('Failed to get access token');
      }

      const profile = await Profile.getCurrentProfile();

      const authResult: SocialAuthResult = {
        provider: 'facebook',
        accessToken: accessToken.accessToken,
        user: {
          id: accessToken.userID,
          email: profile?.email || undefined,
          name: profile?.name || undefined,
          photo: profile?.imageURL || undefined,
        },
      };

      await loginWithSocial(authResult);
      return authResult;
    } catch (error: any) {
      setError(error.message || 'Facebook sign in failed');
      return null;
    } finally {
      setIsLoading(false);
    }
  };

  const signOut = async () => {
    try {
      await GoogleSignin.signOut();
      LoginManager.logOut();
    } catch (error) {
      console.error('Sign out error:', error);
    }
  };

  return {
    signInWithGoogle,
    signInWithApple,
    signInWithFacebook,
    signOut,
    isLoading,
    error,
    clearError: () => setError(null),
  };
};
```

### Social Login Buttons Component

```typescript
// components/SocialLoginButtons.tsx
import React from 'react';
import {
  View,
  TouchableOpacity,
  Text,
  StyleSheet,
  Platform,
  ActivityIndicator,
} from 'react-native';
import { AppleButton } from '@invertase/react-native-apple-authentication';
import { useSocialAuth } from '../hooks/useSocialAuth';
import { Icon } from './Icon';
import { tokens } from '../design/theme';

interface SocialLoginButtonsProps {
  onSuccess?: () => void;
}

export const SocialLoginButtons: React.FC<SocialLoginButtonsProps> = ({
  onSuccess,
}) => {
  const {
    signInWithGoogle,
    signInWithApple,
    signInWithFacebook,
    isLoading,
    error,
  } = useSocialAuth();

  const handleGoogleSignIn = async () => {
    const result = await signInWithGoogle();
    if (result) onSuccess?.();
  };

  const handleAppleSignIn = async () => {
    const result = await signInWithApple();
    if (result) onSuccess?.();
  };

  const handleFacebookSignIn = async () => {
    const result = await signInWithFacebook();
    if (result) onSuccess?.();
  };

  return (
    <View style={styles.container}>
      {/* Apple Sign-In (iOS only) */}
      {Platform.OS === 'ios' && (
        <AppleButton
          buttonStyle={AppleButton.Style.BLACK}
          buttonType={AppleButton.Type.SIGN_IN}
          style={styles.appleButton}
          onPress={handleAppleSignIn}
        />
      )}

      {/* Google Sign-In */}
      <TouchableOpacity
        style={styles.googleButton}
        onPress={handleGoogleSignIn}
        disabled={isLoading}
      >
        {isLoading ? (
          <ActivityIndicator size="small" color={tokens.colors.neutral[900]} />
        ) : (
          <>
            <Icon name="google" size={24} />
            <Text style={styles.googleButtonText}>Continue with Google</Text>
          </>
        )}
      </TouchableOpacity>

      {/* Facebook Sign-In */}
      <TouchableOpacity
        style={styles.facebookButton}
        onPress={handleFacebookSignIn}
        disabled={isLoading}
      >
        {isLoading ? (
          <ActivityIndicator size="small" color="#FFFFFF" />
        ) : (
          <>
            <Icon name="facebook" size={24} color="#FFFFFF" />
            <Text style={styles.facebookButtonText}>Continue with Facebook</Text>
          </>
        )}
      </TouchableOpacity>

      {error && <Text style={styles.errorText}>{error}</Text>}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: 12,
  },
  appleButton: {
    width: '100%',
    height: 50,
  },
  googleButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 50,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: tokens.colors.neutral[200],
    gap: 12,
  },
  googleButtonText: {
    fontSize: 16,
    fontWeight: '500',
    color: tokens.colors.neutral[900],
  },
  facebookButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 50,
    backgroundColor: '#1877F2',
    borderRadius: 8,
    gap: 12,
  },
  facebookButtonText: {
    fontSize: 16,
    fontWeight: '500',
    color: '#FFFFFF',
  },
  errorText: {
    color: tokens.colors.semantic.error,
    fontSize: 14,
    textAlign: 'center',
    marginTop: 8,
  },
});
```

## Flutter Social Login

### Social Auth Service

```dart
// social_auth_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class SocialAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
  );

  Future<SocialAuthResult?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authentication = await account.authentication;

      return SocialAuthResult(
        provider: 'google',
        idToken: authentication.idToken,
        accessToken: authentication.accessToken,
        user: SocialUser(
          id: account.id,
          email: account.email,
          name: account.displayName,
          photoUrl: account.photoUrl,
        ),
      );
    } catch (e) {
      throw SocialAuthException('Google sign in failed: $e');
    }
  }

  Future<SocialAuthResult?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      return SocialAuthResult(
        provider: 'apple',
        idToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        user: SocialUser(
          id: credential.userIdentifier ?? '',
          email: credential.email,
          name: credential.givenName != null
              ? '${credential.givenName} ${credential.familyName ?? ''}'.trim()
              : null,
        ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw SocialAuthException('Apple sign in failed: ${e.message}');
    }
  }

  Future<SocialAuthResult?> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        return null;
      }

      if (result.status != LoginStatus.success) {
        throw SocialAuthException('Facebook sign in failed: ${result.message}');
      }

      final accessToken = result.accessToken!;
      final userData = await FacebookAuth.instance.getUserData();

      return SocialAuthResult(
        provider: 'facebook',
        accessToken: accessToken.token,
        user: SocialUser(
          id: userData['id'] as String,
          email: userData['email'] as String?,
          name: userData['name'] as String?,
          photoUrl: userData['picture']?['data']?['url'] as String?,
        ),
      );
    } catch (e) {
      throw SocialAuthException('Facebook sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }
}

class SocialAuthResult {
  final String provider;
  final String? idToken;
  final String? accessToken;
  final String? authorizationCode;
  final SocialUser user;

  SocialAuthResult({
    required this.provider,
    this.idToken,
    this.accessToken,
    this.authorizationCode,
    required this.user,
  });
}

class SocialUser {
  final String id;
  final String? email;
  final String? name;
  final String? photoUrl;

  SocialUser({
    required this.id,
    this.email,
    this.name,
    this.photoUrl,
  });
}

class SocialAuthException implements Exception {
  final String message;
  SocialAuthException(this.message);

  @override
  String toString() => message;
}
```

## Output Expectations

When implementing social login, the subagent should:

1. Configure OAuth credentials for each provider
2. Implement Sign in with Apple (required for iOS)
3. Set up Google Sign-In with proper client IDs
4. Configure Facebook Login SDK
5. Handle token exchange with backend
6. Implement account linking logic
7. Support credential restoration
8. Handle cancellation gracefully
9. Display proper error messages
10. Follow platform design guidelines
