---
name: Mobile Deep Linking
platform: mobile
description: Deep linking, universal links, app links, and URL scheme handling for iOS, Android, and cross-platform mobile applications
model: opus
category: mobile/frontend
---

# Mobile Deep Linking

## Purpose

Implement comprehensive deep linking systems that enable seamless navigation into specific app content from external sources including web links, push notifications, emails, and other apps. Support both custom URL schemes and HTTP-based universal/app links for a unified user experience.

## Deep Linking Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Deep Link Types                             │
├─────────────────────────────────────────────────────────────────┤
│  Custom URL Scheme     │  Universal Links      │  App Links     │
│  myapp://product/123   │  https://myapp.com/   │  Android equiv │
│  - Always opens app    │  - Web fallback       │  - Web fallback│
│  - No verification     │  - Apple verified     │  - Google verify│
│  - Legacy support      │  - Preferred iOS      │  - Preferred   │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Deep Linking

### URL Scheme Configuration

```xml
<!-- Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>myapp</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.company.myapp</string>
    </dict>
</array>
```

### Universal Links Configuration

```json
// apple-app-site-association (hosted at /.well-known/)
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.company.myapp",
        "paths": [
          "/product/*",
          "/category/*",
          "/order/*",
          "/user/*",
          "/share/*",
          "/invite/*",
          "/reset-password/*"
        ]
      }
    ]
  },
  "webcredentials": {
    "apps": ["TEAMID.com.company.myapp"]
  }
}
```

```xml
<!-- Entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:myapp.com</string>
    <string>applinks:www.myapp.com</string>
    <string>webcredentials:myapp.com</string>
</array>
```

### SwiftUI Deep Link Handler

```swift
// DeepLinkHandler.swift
import Foundation

enum DeepLink: Equatable {
    case home
    case product(id: String)
    case category(id: String)
    case cart
    case checkout
    case order(id: String)
    case profile
    case settings
    case resetPassword(token: String)
    case invite(code: String)
    case share(type: String, id: String)

    init?(url: URL) {
        // Handle custom scheme: myapp://
        if url.scheme == "myapp" {
            self.init(path: url.host ?? "", queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            return
        }

        // Handle universal links: https://myapp.com/
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        self.init(path: components.path, queryItems: components.queryItems)
    }

    private init?(path: String, queryItems: [URLQueryItem]?) {
        let pathComponents = path.split(separator: "/").map(String.init)
        let params = queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]

        switch pathComponents.first {
        case "product":
            guard pathComponents.count > 1 else { return nil }
            self = .product(id: pathComponents[1])
        case "category":
            guard pathComponents.count > 1 else { return nil }
            self = .category(id: pathComponents[1])
        case "cart":
            self = .cart
        case "checkout":
            self = .checkout
        case "order":
            guard pathComponents.count > 1 else { return nil }
            self = .order(id: pathComponents[1])
        case "profile":
            self = .profile
        case "settings":
            self = .settings
        case "reset-password":
            guard let token = params["token"] else { return nil }
            self = .resetPassword(token: token)
        case "invite":
            guard pathComponents.count > 1 else { return nil }
            self = .invite(code: pathComponents[1])
        case "share":
            guard pathComponents.count > 2 else { return nil }
            self = .share(type: pathComponents[1], id: pathComponents[2])
        default:
            self = .home
        }
    }
}

// DeepLinkManager.swift
@Observable
final class DeepLinkManager {
    var pendingDeepLink: DeepLink?

    private let router: NavigationRouter
    private let authManager: AuthManager

    init(router: NavigationRouter, authManager: AuthManager) {
        self.router = router
        self.authManager = authManager
    }

    func handle(_ url: URL) {
        guard let deepLink = DeepLink(url: url) else {
            print("Invalid deep link URL: \(url)")
            return
        }

        handle(deepLink)
    }

    func handle(_ deepLink: DeepLink) {
        // Check if authentication is required
        if requiresAuthentication(deepLink) && !authManager.isAuthenticated {
            pendingDeepLink = deepLink
            router.navigate(to: .login)
            return
        }

        navigate(to: deepLink)
    }

    func handlePendingDeepLink() {
        guard let pending = pendingDeepLink else { return }
        pendingDeepLink = nil
        navigate(to: pending)
    }

    private func requiresAuthentication(_ deepLink: DeepLink) -> Bool {
        switch deepLink {
        case .order, .checkout, .profile, .settings:
            return true
        default:
            return false
        }
    }

    private func navigate(to deepLink: DeepLink) {
        // Reset navigation stack if needed
        router.popToRoot()

        switch deepLink {
        case .home:
            break // Already at home

        case .product(let id):
            router.navigate(to: .productDetail(productId: id))

        case .category(let id):
            router.navigate(to: .productList(categoryId: id))

        case .cart:
            router.navigate(to: .cart)

        case .checkout:
            router.navigate(to: .cart)
            router.navigate(to: .checkout)

        case .order(let id):
            router.navigate(to: .profile)
            router.navigate(to: .orderConfirmation(orderId: id))

        case .profile:
            router.navigate(to: .profile)

        case .settings:
            router.navigate(to: .profile)
            router.navigate(to: .settings)

        case .resetPassword(let token):
            router.present(fullScreen: .resetPassword(token: token))

        case .invite(let code):
            router.present(sheet: .applyInviteCode(code))

        case .share(let type, let id):
            handleShare(type: type, id: id)
        }
    }

    private func handleShare(type: String, id: String) {
        switch type {
        case "product":
            router.navigate(to: .productDetail(productId: id))
        case "collection":
            router.navigate(to: .productList(categoryId: id))
        default:
            break
        }
    }
}

// App.swift
@main
struct MyApp: App {
    @State private var deepLinkManager: DeepLinkManager

    init() {
        // Initialize dependencies
        let router = NavigationRouter()
        let authManager = AuthManager()
        _deepLinkManager = State(initialValue: DeepLinkManager(
            router: router,
            authManager: authManager
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deepLinkManager)
                .onOpenURL { url in
                    deepLinkManager.handle(url)
                }
        }
    }
}
```

### UIKit AppDelegate Integration

```swift
// AppDelegate.swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    var deepLinkManager: DeepLinkManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Handle cold start deep link
        if let url = launchOptions?[.url] as? URL {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.deepLinkManager?.handle(url)
            }
        }
        return true
    }

    // Custom URL scheme
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        deepLinkManager?.handle(url)
        return true
    }

    // Universal links
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        deepLinkManager?.handle(url)
        return true
    }
}
```

## Android Deep Linking

### Manifest Configuration

```xml
<!-- AndroidManifest.xml -->
<manifest>
    <application>
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask">

            <!-- Custom URL scheme -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="myapp" />
            </intent-filter>

            <!-- App Links (verified) -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data
                    android:scheme="https"
                    android:host="myapp.com"
                    android:pathPattern="/product/.*" />
                <data
                    android:scheme="https"
                    android:host="myapp.com"
                    android:pathPattern="/category/.*" />
                <data
                    android:scheme="https"
                    android:host="myapp.com"
                    android:pathPattern="/order/.*" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### Digital Asset Links

```json
// /.well-known/assetlinks.json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.company.myapp",
      "sha256_cert_fingerprints": [
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
      ]
    }
  }
]
```

### Jetpack Compose Deep Link Handler

```kotlin
// DeepLink.kt
sealed class DeepLink {
    data object Home : DeepLink()
    data class Product(val id: String) : DeepLink()
    data class Category(val id: String) : DeepLink()
    data object Cart : DeepLink()
    data object Checkout : DeepLink()
    data class Order(val id: String) : DeepLink()
    data object Profile : DeepLink()
    data object Settings : DeepLink()
    data class ResetPassword(val token: String) : DeepLink()
    data class Invite(val code: String) : DeepLink()
    data class Share(val type: String, val id: String) : DeepLink()

    companion object {
        fun parse(uri: Uri): DeepLink? {
            val pathSegments = uri.pathSegments

            // Handle custom scheme: myapp://
            if (uri.scheme == "myapp") {
                return parseFromPath(uri.host ?: "", uri.queryParameterNames.associateWith {
                    uri.getQueryParameter(it)
                })
            }

            // Handle app links: https://myapp.com/
            return parseFromPath(
                pathSegments.joinToString("/"),
                uri.queryParameterNames.associateWith { uri.getQueryParameter(it) }
            )
        }

        private fun parseFromPath(path: String, params: Map<String, String?>): DeepLink? {
            val segments = path.split("/").filter { it.isNotEmpty() }

            return when (segments.firstOrNull()) {
                "product" -> segments.getOrNull(1)?.let { Product(it) }
                "category" -> segments.getOrNull(1)?.let { Category(it) }
                "cart" -> Cart
                "checkout" -> Checkout
                "order" -> segments.getOrNull(1)?.let { Order(it) }
                "profile" -> Profile
                "settings" -> Settings
                "reset-password" -> params["token"]?.let { ResetPassword(it) }
                "invite" -> segments.getOrNull(1)?.let { Invite(it) }
                "share" -> if (segments.size >= 3) Share(segments[1], segments[2]) else null
                else -> Home
            }
        }
    }
}

// DeepLinkHandler.kt
@Singleton
class DeepLinkHandler @Inject constructor(
    private val authRepository: AuthRepository
) {
    private val _pendingDeepLink = MutableStateFlow<DeepLink?>(null)
    val pendingDeepLink: StateFlow<DeepLink?> = _pendingDeepLink.asStateFlow()

    fun handle(intent: Intent): DeepLink? {
        val uri = intent.data ?: return null
        return DeepLink.parse(uri)?.also { deepLink ->
            if (requiresAuthentication(deepLink) && !authRepository.isAuthenticated.value) {
                _pendingDeepLink.value = deepLink
            }
        }
    }

    fun handlePendingDeepLink(): DeepLink? {
        val pending = _pendingDeepLink.value
        _pendingDeepLink.value = null
        return pending
    }

    private fun requiresAuthentication(deepLink: DeepLink): Boolean {
        return when (deepLink) {
            is DeepLink.Order,
            is DeepLink.Checkout,
            is DeepLink.Profile,
            is DeepLink.Settings -> true
            else -> false
        }
    }
}

// MainActivity.kt
@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject
    lateinit var deepLinkHandler: DeepLinkHandler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            val navController = rememberNavController()

            // Handle initial deep link
            LaunchedEffect(Unit) {
                val deepLink = deepLinkHandler.handle(intent)
                deepLink?.let { navigateToDeepLink(navController, it) }
            }

            // Handle new intents (when app is already running)
            DisposableEffect(Unit) {
                val listener = Consumer<Intent> { newIntent ->
                    deepLinkHandler.handle(newIntent)?.let {
                        navigateToDeepLink(navController, it)
                    }
                }
                addOnNewIntentListener(listener)
                onDispose { removeOnNewIntentListener(listener) }
            }

            AppTheme {
                AppNavHost(navController = navController)
            }
        }
    }

    private fun navigateToDeepLink(navController: NavController, deepLink: DeepLink) {
        when (deepLink) {
            is DeepLink.Home -> {
                navController.navigate(Screen.Home.route) {
                    popUpTo(navController.graph.startDestinationId) { inclusive = true }
                }
            }
            is DeepLink.Product -> {
                navController.navigate(Screen.ProductDetail.createRoute(deepLink.id))
            }
            is DeepLink.Category -> {
                navController.navigate(Screen.ProductList.createRoute(deepLink.id))
            }
            is DeepLink.Cart -> {
                navController.navigate(Screen.Cart.route)
            }
            is DeepLink.Checkout -> {
                navController.navigate(Screen.Cart.route)
                navController.navigate(Screen.Checkout.route)
            }
            is DeepLink.Order -> {
                navController.navigate(Screen.OrderConfirmation.createRoute(deepLink.id))
            }
            is DeepLink.Profile -> {
                navController.navigate(Screen.Profile.route)
            }
            is DeepLink.Settings -> {
                navController.navigate(Screen.Settings.route)
            }
            is DeepLink.ResetPassword -> {
                // Show reset password dialog or screen
            }
            is DeepLink.Invite -> {
                // Apply invite code
            }
            is DeepLink.Share -> {
                when (deepLink.type) {
                    "product" -> navController.navigate(Screen.ProductDetail.createRoute(deepLink.id))
                    "collection" -> navController.navigate(Screen.ProductList.createRoute(deepLink.id))
                }
            }
        }
    }
}

// Navigation with deep links
@Composable
fun AppNavHost(navController: NavHostController) {
    NavHost(
        navController = navController,
        startDestination = Screen.Home.route
    ) {
        composable(
            route = Screen.ProductDetail.route,
            arguments = listOf(navArgument("productId") { type = NavType.StringType }),
            deepLinks = listOf(
                navDeepLink { uriPattern = "myapp://product/{productId}" },
                navDeepLink { uriPattern = "https://myapp.com/product/{productId}" }
            )
        ) { backStackEntry ->
            val productId = backStackEntry.arguments?.getString("productId") ?: return@composable
            ProductDetailScreen(productId = productId)
        }

        composable(
            route = Screen.ProductList.route,
            arguments = listOf(navArgument("categoryId") { type = NavType.StringType }),
            deepLinks = listOf(
                navDeepLink { uriPattern = "myapp://category/{categoryId}" },
                navDeepLink { uriPattern = "https://myapp.com/category/{categoryId}" }
            )
        ) { backStackEntry ->
            val categoryId = backStackEntry.arguments?.getString("categoryId") ?: return@composable
            ProductListScreen(categoryId = categoryId)
        }
    }
}
```

## React Native Deep Linking

### Configuration

```typescript
// app.json (Expo)
{
  "expo": {
    "scheme": "myapp",
    "ios": {
      "associatedDomains": [
        "applinks:myapp.com",
        "applinks:www.myapp.com"
      ]
    },
    "android": {
      "intentFilters": [
        {
          "action": "VIEW",
          "autoVerify": true,
          "data": [
            {
              "scheme": "https",
              "host": "myapp.com",
              "pathPrefix": "/product"
            },
            {
              "scheme": "https",
              "host": "myapp.com",
              "pathPrefix": "/category"
            }
          ],
          "category": ["BROWSABLE", "DEFAULT"]
        }
      ]
    }
  }
}
```

### Deep Link Handler

```typescript
// navigation/linking.ts
import { LinkingOptions } from '@react-navigation/native';
import { RootStackParamList } from './types';

export const linking: LinkingOptions<RootStackParamList> = {
  prefixes: ['myapp://', 'https://myapp.com', 'https://www.myapp.com'],
  config: {
    screens: {
      Main: {
        screens: {
          HomeTab: {
            screens: {
              Home: '',
              ProductDetail: 'product/:productId',
              ProductList: 'category/:categoryId',
            },
          },
          CartTab: {
            screens: {
              Cart: 'cart',
              Checkout: 'checkout',
              OrderConfirmation: 'order/:orderId',
            },
          },
          ProfileTab: {
            screens: {
              Profile: 'profile',
              Settings: 'settings',
            },
          },
        },
      },
      Auth: {
        screens: {
          Login: 'login',
          Register: 'register',
          ResetPassword: 'reset-password',
        },
      },
    },
  },
  async getInitialURL() {
    // Handle cold start deep links
    const url = await Linking.getInitialURL();
    return url;
  },
  subscribe(listener) {
    // Handle deep links when app is running
    const subscription = Linking.addEventListener('url', ({ url }) => {
      listener(url);
    });

    return () => subscription.remove();
  },
};

// hooks/useDeepLink.ts
import { useEffect } from 'react';
import { Linking } from 'react-native';
import { useNavigation, CommonActions } from '@react-navigation/native';
import { useAuthStore } from '../stores/authStore';

interface DeepLink {
  type: string;
  params: Record<string, string>;
}

export const useDeepLinkHandler = () => {
  const navigation = useNavigation();
  const { isAuthenticated } = useAuthStore();

  useEffect(() => {
    const handleDeepLink = async (url: string | null) => {
      if (!url) return;

      const deepLink = parseDeepLink(url);
      if (!deepLink) return;

      // Check authentication requirements
      if (requiresAuth(deepLink) && !isAuthenticated) {
        // Store pending deep link and redirect to login
        await AsyncStorage.setItem('pendingDeepLink', url);
        navigation.dispatch(
          CommonActions.navigate({ name: 'Auth', params: { screen: 'Login' } })
        );
        return;
      }

      navigateToDeepLink(deepLink);
    };

    // Check for initial URL
    Linking.getInitialURL().then(handleDeepLink);

    // Listen for URL events
    const subscription = Linking.addEventListener('url', ({ url }) => {
      handleDeepLink(url);
    });

    return () => subscription.remove();
  }, [isAuthenticated]);

  const parseDeepLink = (url: string): DeepLink | null => {
    try {
      const parsed = new URL(url);
      const pathSegments = parsed.pathname.split('/').filter(Boolean);

      const type = pathSegments[0] || 'home';
      const params: Record<string, string> = {};

      // Parse path params
      if (pathSegments.length > 1) {
        params.id = pathSegments[1];
      }

      // Parse query params
      parsed.searchParams.forEach((value, key) => {
        params[key] = value;
      });

      return { type, params };
    } catch {
      return null;
    }
  };

  const requiresAuth = (deepLink: DeepLink): boolean => {
    return ['order', 'checkout', 'profile', 'settings'].includes(deepLink.type);
  };

  const navigateToDeepLink = (deepLink: DeepLink) => {
    switch (deepLink.type) {
      case 'product':
        navigation.dispatch(
          CommonActions.navigate({
            name: 'Main',
            params: {
              screen: 'HomeTab',
              params: {
                screen: 'ProductDetail',
                params: { productId: deepLink.params.id },
              },
            },
          })
        );
        break;
      case 'category':
        navigation.dispatch(
          CommonActions.navigate({
            name: 'Main',
            params: {
              screen: 'HomeTab',
              params: {
                screen: 'ProductList',
                params: { categoryId: deepLink.params.id },
              },
            },
          })
        );
        break;
      case 'cart':
        navigation.dispatch(
          CommonActions.navigate({
            name: 'Main',
            params: { screen: 'CartTab' },
          })
        );
        break;
      case 'order':
        navigation.dispatch(
          CommonActions.navigate({
            name: 'Main',
            params: {
              screen: 'CartTab',
              params: {
                screen: 'OrderConfirmation',
                params: { orderId: deepLink.params.id },
              },
            },
          })
        );
        break;
      default:
        navigation.dispatch(CommonActions.navigate({ name: 'Main' }));
    }
  };

  const handlePendingDeepLink = async () => {
    const pendingUrl = await AsyncStorage.getItem('pendingDeepLink');
    if (pendingUrl) {
      await AsyncStorage.removeItem('pendingDeepLink');
      const deepLink = parseDeepLink(pendingUrl);
      if (deepLink) {
        navigateToDeepLink(deepLink);
      }
    }
  };

  return { handlePendingDeepLink };
};
```

## Flutter Deep Linking

### Configuration

```yaml
# pubspec.yaml
dependencies:
  go_router: ^13.0.0
  app_links: ^3.5.0
```

```dart
// android/app/src/main/AndroidManifest.xml
<activity>
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="myapp.com" />
        <data android:scheme="myapp" />
    </intent-filter>
</activity>
```

### Deep Link Handler

```dart
// deep_link_handler.dart
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  final GoRouter _router;
  final AuthRepository _authRepository;

  String? _pendingDeepLink;

  DeepLinkHandler(this._router, this._authRepository);

  Future<void> initialize() async {
    // Handle initial link (cold start)
    final initialLink = await _appLinks.getInitialAppLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }

    // Handle links when app is running
    _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    final deepLink = _parseDeepLink(uri);
    if (deepLink == null) return;

    if (_requiresAuth(deepLink) && !_authRepository.isAuthenticated) {
      _pendingDeepLink = uri.toString();
      _router.go('/auth/login');
      return;
    }

    _navigateTo(deepLink);
  }

  DeepLinkData? _parseDeepLink(Uri uri) {
    final pathSegments = uri.pathSegments;
    if (pathSegments.isEmpty) return DeepLinkData('home', {});

    final type = pathSegments.first;
    final params = <String, String>{};

    if (pathSegments.length > 1) {
      params['id'] = pathSegments[1];
    }

    uri.queryParameters.forEach((key, value) {
      params[key] = value;
    });

    return DeepLinkData(type, params);
  }

  bool _requiresAuth(DeepLinkData deepLink) {
    return ['order', 'checkout', 'profile', 'settings'].contains(deepLink.type);
  }

  void _navigateTo(DeepLinkData deepLink) {
    switch (deepLink.type) {
      case 'product':
        _router.go('/product/${deepLink.params['id']}');
      case 'category':
        _router.go('/category/${deepLink.params['id']}');
      case 'cart':
        _router.go('/cart');
      case 'order':
        _router.go('/cart/order/${deepLink.params['id']}');
      case 'profile':
        _router.go('/profile');
      case 'settings':
        _router.go('/profile/settings');
      case 'reset-password':
        _router.go('/auth/reset-password?token=${deepLink.params['token']}');
      default:
        _router.go('/');
    }
  }

  void handlePendingDeepLink() {
    if (_pendingDeepLink != null) {
      final uri = Uri.parse(_pendingDeepLink!);
      _pendingDeepLink = null;
      _handleDeepLink(uri);
    }
  }
}

class DeepLinkData {
  final String type;
  final Map<String, String> params;

  DeepLinkData(this.type, this.params);
}
```

## Deferred Deep Linking

```typescript
// Handling deep links for app install attribution
import { getDeepLink, trackInstall } from 'react-native-branch';

export const handleDeferredDeepLink = async () => {
  try {
    // Check if this is a first launch from install
    const isFirstLaunch = await AsyncStorage.getItem('isFirstLaunch');

    if (isFirstLaunch === null) {
      await AsyncStorage.setItem('isFirstLaunch', 'false');

      // Get deferred deep link
      const deepLink = await getDeepLink();

      if (deepLink) {
        // Track install attribution
        await trackInstall({
          channel: deepLink.channel,
          campaign: deepLink.campaign,
        });

        // Navigate to content
        return deepLink.contentPath;
      }
    }

    return null;
  } catch (error) {
    console.error('Deferred deep link error:', error);
    return null;
  }
};
```

## Output Expectations

When implementing deep linking, the subagent should:

1. Configure URL schemes for custom deep links
2. Set up universal links (iOS) and app links (Android)
3. Host required verification files on web server
4. Create comprehensive deep link parsing
5. Handle authentication-required deep links
6. Implement deferred deep linking for installs
7. Support both cold start and warm start scenarios
8. Create type-safe deep link definitions
9. Handle invalid or malformed deep links gracefully
10. Integrate with analytics for link tracking
