---
name: Mobile Navigation and Routing
platform: mobile
description: Navigation architecture, routing patterns, and screen flow management for iOS, Android, and cross-platform mobile applications
model: opus
category: mobile/frontend
---

# Mobile Navigation and Routing

## Purpose

Implement robust, type-safe navigation systems that handle complex screen flows, deep linking, authentication guards, and state preservation across all mobile platforms. Navigation architecture must support tab-based layouts, modal presentations, nested navigators, and seamless transitions.

## iOS Navigation (SwiftUI)

### NavigationStack Architecture

```swift
// Router.swift
import SwiftUI

enum Route: Hashable {
    case home
    case productList(categoryId: String)
    case productDetail(productId: String)
    case cart
    case checkout
    case orderConfirmation(orderId: String)
    case profile
    case settings
    case editProfile
}

@Observable
final class NavigationRouter {
    var path = NavigationPath()
    var presentedSheet: SheetDestination?
    var presentedFullScreenCover: FullScreenDestination?

    enum SheetDestination: Identifiable {
        case filter(onApply: (FilterOptions) -> Void)
        case sort(current: SortOption, onSelect: (SortOption) -> Void)
        case addToCart(product: Product)

        var id: String {
            switch self {
            case .filter: return "filter"
            case .sort: return "sort"
            case .addToCart(let product): return "addToCart-\(product.id)"
            }
        }
    }

    enum FullScreenDestination: Identifiable {
        case imageGallery(images: [URL], startIndex: Int)
        case video(url: URL)
        case onboarding

        var id: String {
            switch self {
            case .imageGallery: return "imageGallery"
            case .video: return "video"
            case .onboarding: return "onboarding"
            }
        }
    }

    func navigate(to route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func replace(with routes: [Route]) {
        path.removeLast(path.count)
        routes.forEach { path.append($0) }
    }

    func present(sheet: SheetDestination) {
        presentedSheet = sheet
    }

    func present(fullScreen: FullScreenDestination) {
        presentedFullScreenCover = fullScreen
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func dismissFullScreen() {
        presentedFullScreenCover = nil
    }
}

// ContentView.swift
struct ContentView: View {
    @State private var router = NavigationRouter()
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, search, cart, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: Route.self) { route in
                        destinationView(for: route)
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(Tab.home)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(Tab.search)

            NavigationStack {
                CartView()
            }
            .tabItem { Label("Cart", systemImage: "cart") }
            .tag(Tab.cart)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(Tab.profile)
        }
        .environment(router)
        .sheet(item: $router.presentedSheet) { destination in
            sheetView(for: destination)
        }
        .fullScreenCover(item: $router.presentedFullScreenCover) { destination in
            fullScreenView(for: destination)
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView()
        case .productList(let categoryId):
            ProductListView(categoryId: categoryId)
        case .productDetail(let productId):
            ProductDetailView(productId: productId)
        case .cart:
            CartView()
        case .checkout:
            CheckoutView()
        case .orderConfirmation(let orderId):
            OrderConfirmationView(orderId: orderId)
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        case .editProfile:
            EditProfileView()
        }
    }

    @ViewBuilder
    private func sheetView(for destination: NavigationRouter.SheetDestination) -> some View {
        switch destination {
        case .filter(let onApply):
            FilterSheet(onApply: onApply)
        case .sort(let current, let onSelect):
            SortSheet(currentSort: current, onSelect: onSelect)
        case .addToCart(let product):
            AddToCartSheet(product: product)
        }
    }

    @ViewBuilder
    private func fullScreenView(for destination: NavigationRouter.FullScreenDestination) -> some View {
        switch destination {
        case .imageGallery(let images, let startIndex):
            ImageGalleryView(images: images, startIndex: startIndex)
        case .video(let url):
            VideoPlayerView(url: url)
        case .onboarding:
            OnboardingView()
        }
    }
}
```

### Coordinator Pattern (UIKit Interop)

```swift
// Coordinator.swift
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get }

    func start()
    func finish()
}

extension Coordinator {
    func addChild(_ coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }

    func removeChild(_ coordinator: Coordinator) {
        childCoordinators.removeAll { $0 === coordinator }
    }
}

// AppCoordinator.swift
final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    let window: UIWindow

    private let authService: AuthService

    init(window: UIWindow, authService: AuthService) {
        self.window = window
        self.navigationController = UINavigationController()
        self.authService = authService
    }

    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        if authService.isAuthenticated {
            showMainFlow()
        } else {
            showAuthFlow()
        }
    }

    func finish() {
        // App coordinator doesn't finish
    }

    private func showAuthFlow() {
        let authCoordinator = AuthCoordinator(
            navigationController: navigationController,
            onAuthComplete: { [weak self] in
                self?.showMainFlow()
            }
        )
        addChild(authCoordinator)
        authCoordinator.start()
    }

    private func showMainFlow() {
        childCoordinators.removeAll()

        let tabBarController = UITabBarController()

        let homeCoordinator = HomeCoordinator()
        let searchCoordinator = SearchCoordinator()
        let profileCoordinator = ProfileCoordinator()

        [homeCoordinator, searchCoordinator, profileCoordinator].forEach {
            addChild($0)
            $0.start()
        }

        tabBarController.viewControllers = [
            homeCoordinator.navigationController,
            searchCoordinator.navigationController,
            profileCoordinator.navigationController
        ]

        navigationController.setViewControllers([tabBarController], animated: true)
    }
}
```

## Android Navigation (Jetpack Compose)

### Navigation Compose Setup

```kotlin
// NavGraph.kt
sealed class Screen(val route: String) {
    data object Home : Screen("home")
    data object Search : Screen("search")
    data object Cart : Screen("cart")
    data object Profile : Screen("profile")
    data object Settings : Screen("settings")

    data object ProductList : Screen("products/{categoryId}") {
        fun createRoute(categoryId: String) = "products/$categoryId"
    }

    data object ProductDetail : Screen("product/{productId}") {
        fun createRoute(productId: String) = "product/$productId"
    }

    data object Checkout : Screen("checkout")

    data object OrderConfirmation : Screen("order/{orderId}") {
        fun createRoute(orderId: String) = "order/$orderId"
    }
}

sealed class AuthScreen(val route: String) {
    data object Login : AuthScreen("auth/login")
    data object Register : AuthScreen("auth/register")
    data object ForgotPassword : AuthScreen("auth/forgot-password")
    data object VerifyOtp : AuthScreen("auth/verify-otp/{phone}") {
        fun createRoute(phone: String) = "auth/verify-otp/$phone"
    }
}

// MainNavGraph.kt
@Composable
fun MainNavGraph(
    navController: NavHostController,
    startDestination: String = Screen.Home.route,
    onNavigateToAuth: () -> Unit
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(Screen.Home.route) {
            HomeScreen(
                onProductClick = { productId ->
                    navController.navigate(Screen.ProductDetail.createRoute(productId))
                },
                onCategoryClick = { categoryId ->
                    navController.navigate(Screen.ProductList.createRoute(categoryId))
                }
            )
        }

        composable(
            route = Screen.ProductList.route,
            arguments = listOf(
                navArgument("categoryId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val categoryId = backStackEntry.arguments?.getString("categoryId") ?: return@composable
            ProductListScreen(
                categoryId = categoryId,
                onProductClick = { productId ->
                    navController.navigate(Screen.ProductDetail.createRoute(productId))
                },
                onBackClick = { navController.popBackStack() }
            )
        }

        composable(
            route = Screen.ProductDetail.route,
            arguments = listOf(
                navArgument("productId") { type = NavType.StringType }
            ),
            deepLinks = listOf(
                navDeepLink { uriPattern = "https://example.com/product/{productId}" }
            )
        ) { backStackEntry ->
            val productId = backStackEntry.arguments?.getString("productId") ?: return@composable
            ProductDetailScreen(
                productId = productId,
                onBackClick = { navController.popBackStack() },
                onCartClick = { navController.navigate(Screen.Cart.route) }
            )
        }

        composable(Screen.Cart.route) {
            CartScreen(
                onCheckoutClick = { navController.navigate(Screen.Checkout.route) },
                onBackClick = { navController.popBackStack() }
            )
        }

        composable(Screen.Checkout.route) {
            CheckoutScreen(
                onOrderComplete = { orderId ->
                    navController.navigate(Screen.OrderConfirmation.createRoute(orderId)) {
                        popUpTo(Screen.Home.route) { inclusive = false }
                    }
                },
                onBackClick = { navController.popBackStack() }
            )
        }

        composable(
            route = Screen.OrderConfirmation.route,
            arguments = listOf(
                navArgument("orderId") { type = NavType.StringType }
            )
        ) { backStackEntry ->
            val orderId = backStackEntry.arguments?.getString("orderId") ?: return@composable
            OrderConfirmationScreen(
                orderId = orderId,
                onContinueShopping = {
                    navController.navigate(Screen.Home.route) {
                        popUpTo(Screen.Home.route) { inclusive = true }
                    }
                }
            )
        }

        composable(Screen.Profile.route) {
            ProfileScreen(
                onSettingsClick = { navController.navigate(Screen.Settings.route) },
                onLogout = onNavigateToAuth
            )
        }

        composable(Screen.Settings.route) {
            SettingsScreen(
                onBackClick = { navController.popBackStack() }
            )
        }
    }
}
```

### Type-Safe Navigation with Serialization

```kotlin
// TypeSafeNavigation.kt
@Serializable
sealed class TypeSafeRoute {
    @Serializable
    data object Home : TypeSafeRoute()

    @Serializable
    data class ProductDetail(
        val productId: String,
        val source: String = "direct"
    ) : TypeSafeRoute()

    @Serializable
    data class OrderConfirmation(
        val orderId: String,
        val total: Double
    ) : TypeSafeRoute()
}

// Extension for type-safe navigation
inline fun <reified T : TypeSafeRoute> NavController.navigateTypeSafe(route: T) {
    val json = Json.encodeToString(route)
    navigate("typesafe/${T::class.simpleName}?data=${Uri.encode(json)}")
}

// Nested Navigation Graphs
@Composable
fun RootNavGraph(
    navController: NavHostController = rememberNavController(),
    isAuthenticated: Boolean
) {
    NavHost(
        navController = navController,
        startDestination = if (isAuthenticated) "main" else "auth"
    ) {
        // Auth nested graph
        navigation(
            startDestination = AuthScreen.Login.route,
            route = "auth"
        ) {
            composable(AuthScreen.Login.route) {
                LoginScreen(
                    onLoginSuccess = {
                        navController.navigate("main") {
                            popUpTo("auth") { inclusive = true }
                        }
                    },
                    onRegisterClick = {
                        navController.navigate(AuthScreen.Register.route)
                    }
                )
            }

            composable(AuthScreen.Register.route) {
                RegisterScreen(
                    onRegisterSuccess = {
                        navController.navigate("main") {
                            popUpTo("auth") { inclusive = true }
                        }
                    },
                    onBackClick = { navController.popBackStack() }
                )
            }
        }

        // Main app nested graph
        navigation(
            startDestination = Screen.Home.route,
            route = "main"
        ) {
            composable(Screen.Home.route) { HomeScreen() }
            // ... other screens
        }
    }
}
```

### Bottom Navigation with State Preservation

```kotlin
// MainScreen.kt
@Composable
fun MainScreen(
    onNavigateToAuth: () -> Unit
) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomNavItems = listOf(
        BottomNavItem(Screen.Home.route, "Home", Icons.Default.Home),
        BottomNavItem(Screen.Search.route, "Search", Icons.Default.Search),
        BottomNavItem(Screen.Cart.route, "Cart", Icons.Default.ShoppingCart),
        BottomNavItem(Screen.Profile.route, "Profile", Icons.Default.Person)
    )

    Scaffold(
        bottomBar = {
            NavigationBar {
                bottomNavItems.forEach { item ->
                    NavigationBarItem(
                        icon = { Icon(item.icon, contentDescription = item.label) },
                        label = { Text(item.label) },
                        selected = currentRoute == item.route,
                        onClick = {
                            navController.navigate(item.route) {
                                // Pop up to the start destination of the graph to
                                // avoid building up a large stack of destinations
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                // Avoid multiple copies of the same destination
                                launchSingleTop = true
                                // Restore state when reselecting a previously selected item
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { paddingValues ->
        MainNavGraph(
            navController = navController,
            modifier = Modifier.padding(paddingValues),
            onNavigateToAuth = onNavigateToAuth
        )
    }
}

data class BottomNavItem(
    val route: String,
    val label: String,
    val icon: ImageVector
)
```

## React Native Navigation

### React Navigation Setup

```typescript
// navigation/types.ts
import { NavigatorScreenParams } from '@react-navigation/native';

export type RootStackParamList = {
  Auth: NavigatorScreenParams<AuthStackParamList>;
  Main: NavigatorScreenParams<MainTabParamList>;
  Onboarding: undefined;
};

export type AuthStackParamList = {
  Login: undefined;
  Register: undefined;
  ForgotPassword: undefined;
  VerifyOtp: { phone: string };
  ResetPassword: { token: string };
};

export type MainTabParamList = {
  HomeTab: NavigatorScreenParams<HomeStackParamList>;
  SearchTab: NavigatorScreenParams<SearchStackParamList>;
  CartTab: NavigatorScreenParams<CartStackParamList>;
  ProfileTab: NavigatorScreenParams<ProfileStackParamList>;
};

export type HomeStackParamList = {
  Home: undefined;
  ProductList: { categoryId: string; categoryName: string };
  ProductDetail: { productId: string };
  AllCategories: undefined;
};

export type SearchStackParamList = {
  Search: undefined;
  SearchResults: { query: string };
  ProductDetail: { productId: string };
};

export type CartStackParamList = {
  Cart: undefined;
  Checkout: undefined;
  PaymentMethod: undefined;
  OrderConfirmation: { orderId: string };
};

export type ProfileStackParamList = {
  Profile: undefined;
  EditProfile: undefined;
  Settings: undefined;
  OrderHistory: undefined;
  OrderDetail: { orderId: string };
  Addresses: undefined;
  AddAddress: { addressId?: string };
};

// navigation/RootNavigator.tsx
import React from 'react';
import { NavigationContainer, LinkingOptions } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useAuth } from '../features/auth/hooks/useAuth';

const Stack = createNativeStackNavigator<RootStackParamList>();

const linking: LinkingOptions<RootStackParamList> = {
  prefixes: ['myapp://', 'https://myapp.com'],
  config: {
    screens: {
      Main: {
        screens: {
          HomeTab: {
            screens: {
              ProductDetail: 'product/:productId',
              ProductList: 'category/:categoryId',
            },
          },
          CartTab: {
            screens: {
              OrderConfirmation: 'order/:orderId',
            },
          },
        },
      },
      Auth: {
        screens: {
          ResetPassword: 'reset-password/:token',
        },
      },
    },
  },
};

export const RootNavigator: React.FC = () => {
  const { isAuthenticated, isLoading, hasCompletedOnboarding } = useAuth();

  if (isLoading) {
    return <SplashScreen />;
  }

  return (
    <NavigationContainer linking={linking}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {!hasCompletedOnboarding && (
          <Stack.Screen name="Onboarding" component={OnboardingScreen} />
        )}
        {isAuthenticated ? (
          <Stack.Screen name="Main" component={MainNavigator} />
        ) : (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};
```

### Tab Navigator with Badge

```typescript
// navigation/MainNavigator.tsx
import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useCartStore } from '../features/cart/store';
import { TabBarIcon } from '../shared/components/TabBarIcon';
import { colors } from '../design/theme';

const Tab = createBottomTabNavigator<MainTabParamList>();

export const MainNavigator: React.FC = () => {
  const cartItemCount = useCartStore((state) => state.items.length);

  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textSecondary,
        tabBarStyle: {
          borderTopWidth: 0,
          elevation: 8,
          shadowColor: '#000',
          shadowOffset: { width: 0, height: -2 },
          shadowOpacity: 0.1,
          shadowRadius: 8,
        },
      }}
    >
      <Tab.Screen
        name="HomeTab"
        component={HomeNavigator}
        options={{
          tabBarLabel: 'Home',
          tabBarIcon: ({ color, size }) => (
            <TabBarIcon name="home" color={color} size={size} />
          ),
        }}
      />
      <Tab.Screen
        name="SearchTab"
        component={SearchNavigator}
        options={{
          tabBarLabel: 'Search',
          tabBarIcon: ({ color, size }) => (
            <TabBarIcon name="search" color={color} size={size} />
          ),
        }}
      />
      <Tab.Screen
        name="CartTab"
        component={CartNavigator}
        options={{
          tabBarLabel: 'Cart',
          tabBarIcon: ({ color, size }) => (
            <TabBarIcon name="cart" color={color} size={size} />
          ),
          tabBarBadge: cartItemCount > 0 ? cartItemCount : undefined,
          tabBarBadgeStyle: {
            backgroundColor: colors.error,
            fontSize: 10,
          },
        }}
      />
      <Tab.Screen
        name="ProfileTab"
        component={ProfileNavigator}
        options={{
          tabBarLabel: 'Profile',
          tabBarIcon: ({ color, size }) => (
            <TabBarIcon name="person" color={color} size={size} />
          ),
        }}
      />
    </Tab.Navigator>
  );
};

// navigation/HomeNavigator.tsx
import { createNativeStackNavigator } from '@react-navigation/native-stack';

const Stack = createNativeStackNavigator<HomeStackParamList>();

export const HomeNavigator: React.FC = () => {
  return (
    <Stack.Navigator
      screenOptions={{
        headerBackTitleVisible: false,
        headerTintColor: colors.primary,
      }}
    >
      <Stack.Screen
        name="Home"
        component={HomeScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="ProductList"
        component={ProductListScreen}
        options={({ route }) => ({
          title: route.params.categoryName,
        })}
      />
      <Stack.Screen
        name="ProductDetail"
        component={ProductDetailScreen}
        options={{
          headerTransparent: true,
          headerTitle: '',
        }}
      />
    </Stack.Navigator>
  );
};
```

### Navigation Hooks

```typescript
// hooks/useAppNavigation.ts
import { useNavigation, useRoute, CommonActions } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList, HomeStackParamList } from '../navigation/types';

type RootNavigation = NativeStackNavigationProp<RootStackParamList>;

export const useAppNavigation = () => {
  const navigation = useNavigation<RootNavigation>();

  const navigateToProduct = (productId: string) => {
    navigation.navigate('Main', {
      screen: 'HomeTab',
      params: {
        screen: 'ProductDetail',
        params: { productId },
      },
    });
  };

  const navigateToCategory = (categoryId: string, categoryName: string) => {
    navigation.navigate('Main', {
      screen: 'HomeTab',
      params: {
        screen: 'ProductList',
        params: { categoryId, categoryName },
      },
    });
  };

  const navigateToCart = () => {
    navigation.navigate('Main', {
      screen: 'CartTab',
      params: {
        screen: 'Cart',
      },
    });
  };

  const navigateToOrderConfirmation = (orderId: string) => {
    navigation.dispatch(
      CommonActions.reset({
        index: 0,
        routes: [
          {
            name: 'Main',
            state: {
              routes: [
                {
                  name: 'CartTab',
                  state: {
                    routes: [
                      { name: 'Cart' },
                      { name: 'OrderConfirmation', params: { orderId } },
                    ],
                  },
                },
              ],
            },
          },
        ],
      })
    );
  };

  const logout = () => {
    navigation.dispatch(
      CommonActions.reset({
        index: 0,
        routes: [{ name: 'Auth' }],
      })
    );
  };

  return {
    navigateToProduct,
    navigateToCategory,
    navigateToCart,
    navigateToOrderConfirmation,
    logout,
  };
};
```

## Flutter Navigation (GoRouter)

### GoRouter Configuration

```dart
// app_router.dart
import 'package:go_router/go_router.dart';
import 'package:riverpod/riverpod.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authState,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation.startsWith('/auth');
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!authState.hasCompletedOnboarding && !isOnboarding) {
        return '/onboarding';
      }

      if (!isLoggedIn && !isLoggingIn) {
        return '/auth/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/auth',
        redirect: (context, state) => '/auth/login',
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: 'verify-otp/:phone',
            builder: (context, state) => VerifyOtpScreen(
              phone: state.pathParameters['phone']!,
            ),
          ),
        ],
      ),

      // Main app shell
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
            routes: [
              GoRoute(
                path: 'category/:categoryId',
                builder: (context, state) => ProductListScreen(
                  categoryId: state.pathParameters['categoryId']!,
                ),
              ),
              GoRoute(
                path: 'product/:productId',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['productId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
            routes: [
              GoRoute(
                path: 'results',
                builder: (context, state) => SearchResultsScreen(
                  query: state.uri.queryParameters['q'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/cart',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CartScreen(),
            ),
            routes: [
              GoRoute(
                path: 'checkout',
                builder: (context, state) => const CheckoutScreen(),
              ),
              GoRoute(
                path: 'order/:orderId',
                builder: (context, state) => OrderConfirmationScreen(
                  orderId: state.pathParameters['orderId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfileScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const OrderHistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':orderId',
                    builder: (context, state) => OrderDetailScreen(
                      orderId: state.pathParameters['orderId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
});

// Main shell with bottom navigation
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AppBottomNavBar(),
    );
  }
}

class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/search')) currentIndex = 1;
    if (location.startsWith('/cart')) currentIndex = 2;
    if (location.startsWith('/profile')) currentIndex = 3;

    final cartItemCount = ref.watch(cartProvider).items.length;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go('/');
          case 1:
            context.go('/search');
          case 2:
            context.go('/cart');
          case 3:
            context.go('/profile');
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: cartItemCount > 0,
            label: Text('$cartItemCount'),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: cartItemCount > 0,
            label: Text('$cartItemCount'),
            child: const Icon(Icons.shopping_cart),
          ),
          label: 'Cart',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
```

## Navigation Patterns

### Authentication Guard

```swift
// iOS
struct AuthenticatedView<Content: View>: View {
    @Environment(AuthState.self) private var authState
    let content: () -> Content

    var body: some View {
        Group {
            if authState.isAuthenticated {
                content()
            } else {
                LoginView()
            }
        }
    }
}
```

```kotlin
// Android
@Composable
fun AuthGuard(
    isAuthenticated: Boolean,
    onNavigateToAuth: () -> Unit,
    content: @Composable () -> Unit
) {
    LaunchedEffect(isAuthenticated) {
        if (!isAuthenticated) {
            onNavigateToAuth()
        }
    }

    if (isAuthenticated) {
        content()
    }
}
```

### Modal Navigation

```typescript
// React Native - Modal presentation
const Stack = createNativeStackNavigator();

<Stack.Navigator>
  <Stack.Group screenOptions={{ presentation: 'card' }}>
    {/* Regular screens */}
  </Stack.Group>
  <Stack.Group screenOptions={{ presentation: 'modal' }}>
    <Stack.Screen name="CreatePost" component={CreatePostScreen} />
    <Stack.Screen name="Settings" component={SettingsScreen} />
  </Stack.Group>
  <Stack.Group screenOptions={{ presentation: 'transparentModal' }}>
    <Stack.Screen name="Alert" component={AlertModal} />
  </Stack.Group>
</Stack.Navigator>
```

## Output Expectations

When implementing navigation, the subagent should:

1. Create type-safe route definitions
2. Implement proper navigation state management
3. Configure deep linking support
4. Set up authentication guards where needed
5. Handle bottom tab navigation with state preservation
6. Implement modal presentation patterns
7. Create reusable navigation hooks/utilities
8. Configure transition animations
9. Handle back navigation properly
10. Support navigation state restoration
