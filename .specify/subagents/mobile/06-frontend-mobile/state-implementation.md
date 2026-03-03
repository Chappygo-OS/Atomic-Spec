---
name: Mobile State Management Implementation
platform: mobile
description: State management patterns and implementations using SwiftUI Observation, Kotlin Flow, Redux, Zustand, Riverpod, and BLoC for mobile applications
model: opus
category: mobile/frontend
---

# Mobile State Management Implementation

## Purpose

Implement scalable, maintainable state management solutions that handle application state, UI state, and data synchronization across mobile platforms. The state layer should provide predictable state updates, support reactive UI binding, and enable efficient testing.

## State Architecture Patterns

### State Categories

```
┌─────────────────────────────────────────────────────────────────┐
│                      State Types                                 │
├─────────────────────────────────────────────────────────────────┤
│  App State              │  Feature State        │  UI State      │
│  - Authentication       │  - Screen data        │  - Loading     │
│  - User preferences     │  - Form state         │  - Errors      │
│  - Theme/locale         │  - Navigation         │  - Visibility  │
│  - Global settings      │  - Business logic     │  - Animations  │
├─────────────────────────────────────────────────────────────────┤
│                      Data Flow                                   │
│  User Action → State Update → UI Rerender → Side Effects        │
└─────────────────────────────────────────────────────────────────┘
```

## iOS State Management

### SwiftUI Observation Framework

```swift
// AppState.swift
import SwiftUI

@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var currentUser: User?
    var theme: AppTheme = .system
    var locale: Locale = .current

    private let authService: AuthService
    private let userService: UserService

    init(authService: AuthService = .shared, userService: UserService = .shared) {
        self.authService = authService
        self.userService = userService

        // Initialize from stored state
        Task {
            await loadInitialState()
        }
    }

    private func loadInitialState() async {
        isAuthenticated = await authService.isAuthenticated
        if isAuthenticated {
            currentUser = try? await userService.getCurrentUser()
        }
    }

    func login(email: String, password: String) async throws {
        try await authService.login(email: email, password: password)
        currentUser = try await userService.getCurrentUser()
        isAuthenticated = true
    }

    func logout() async {
        await authService.logout()
        currentUser = nil
        isAuthenticated = false
    }

    func updateTheme(_ theme: AppTheme) {
        self.theme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "theme")
    }
}

// Feature State - Product Catalog
@Observable
final class ProductCatalogState {
    private(set) var products: [Product] = []
    private(set) var categories: [Category] = []
    private(set) var selectedCategory: Category?
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    var filteredProducts: [Product] {
        guard let category = selectedCategory else { return products }
        return products.filter { $0.categoryId == category.id }
    }

    private let productService: ProductService

    init(productService: ProductService = .shared) {
        self.productService = productService
    }

    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            async let productsTask = productService.getProducts()
            async let categoriesTask = productService.getCategories()

            let (loadedProducts, loadedCategories) = try await (productsTask, categoriesTask)
            products = loadedProducts
            categories = loadedCategories
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func selectCategory(_ category: Category?) {
        selectedCategory = category
    }

    func refreshProducts() async {
        await loadProducts()
    }
}

// Cart State
@Observable
final class CartState {
    private(set) var items: [CartItem] = []
    private(set) var isUpdating: Bool = false

    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var subtotal: Decimal {
        items.reduce(0) { $0 + ($1.product.price * Decimal($1.quantity)) }
    }

    var tax: Decimal {
        subtotal * 0.1 // 10% tax
    }

    var total: Decimal {
        subtotal + tax
    }

    private let cartService: CartService

    init(cartService: CartService = .shared) {
        self.cartService = cartService
        loadCart()
    }

    private func loadCart() {
        Task {
            items = await cartService.getCartItems()
        }
    }

    func addToCart(_ product: Product, quantity: Int = 1) async {
        isUpdating = true

        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += quantity
        } else {
            items.append(CartItem(product: product, quantity: quantity))
        }

        await cartService.saveCart(items)
        isUpdating = false
    }

    func updateQuantity(for productId: String, quantity: Int) async {
        guard let index = items.firstIndex(where: { $0.product.id == productId }) else { return }

        isUpdating = true

        if quantity <= 0 {
            items.remove(at: index)
        } else {
            items[index].quantity = quantity
        }

        await cartService.saveCart(items)
        isUpdating = false
    }

    func removeFromCart(_ productId: String) async {
        items.removeAll { $0.product.id == productId }
        await cartService.saveCart(items)
    }

    func clearCart() async {
        items.removeAll()
        await cartService.clearCart()
    }
}

// ViewModels with Observation
@Observable
final class ProductListViewModel {
    private(set) var viewState: ViewState = .idle
    private(set) var products: [Product] = []
    private(set) var searchQuery: String = ""

    var filteredProducts: [Product] {
        guard !searchQuery.isEmpty else { return products }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.description?.localizedCaseInsensitiveContains(searchQuery) == true
        }
    }

    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
        case empty
    }

    private let productRepository: ProductRepository
    private var loadTask: Task<Void, Never>?

    init(productRepository: ProductRepository) {
        self.productRepository = productRepository
    }

    func onAppear() {
        guard viewState == .idle else { return }
        loadProducts()
    }

    func loadProducts() {
        loadTask?.cancel()
        loadTask = Task {
            viewState = .loading

            do {
                let loadedProducts = try await productRepository.getProducts()

                if Task.isCancelled { return }

                products = loadedProducts
                viewState = loadedProducts.isEmpty ? .empty : .loaded
            } catch {
                if Task.isCancelled { return }
                viewState = .error(error.localizedDescription)
            }
        }
    }

    func refresh() async {
        do {
            products = try await productRepository.getProducts()
            viewState = products.isEmpty ? .empty : .loaded
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    func search(_ query: String) {
        searchQuery = query
    }
}
```

### The Composable Architecture (TCA)

```swift
// ProductListFeature.swift
import ComposableArchitecture

@Reducer
struct ProductListFeature {
    @ObservableState
    struct State: Equatable {
        var products: IdentifiedArrayOf<Product> = []
        var searchQuery: String = ""
        var isLoading: Bool = false
        var error: String?

        @Presents var destination: Destination.State?

        var filteredProducts: IdentifiedArrayOf<Product> {
            guard !searchQuery.isEmpty else { return products }
            return products.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case refresh
        case productsResponse(Result<[Product], Error>)
        case productTapped(Product)
        case destination(PresentationAction<Destination.Action>)
    }

    @Reducer(state: .equatable)
    enum Destination {
        case detail(ProductDetailFeature)
        case cart(CartFeature)
    }

    @Dependency(\.productClient) var productClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.products.isEmpty else { return .none }
                return loadProducts(state: &state)

            case .refresh:
                return loadProducts(state: &state)

            case .productsResponse(.success(let products)):
                state.isLoading = false
                state.products = IdentifiedArray(uniqueElements: products)
                state.error = nil
                return .none

            case .productsResponse(.failure(let error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .productTapped(let product):
                state.destination = .detail(ProductDetailFeature.State(product: product))
                return .none

            case .binding, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func loadProducts(state: inout State) -> Effect<Action> {
        state.isLoading = true
        state.error = nil

        return .run { send in
            await send(.productsResponse(
                Result { try await productClient.getProducts() }
            ))
        }
    }
}

// ProductListView.swift
struct ProductListView: View {
    @Bindable var store: StoreOf<ProductListFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.products.isEmpty {
                    ProgressView()
                } else if let error = store.error, store.products.isEmpty {
                    ErrorView(message: error) {
                        store.send(.refresh)
                    }
                } else if store.filteredProducts.isEmpty {
                    EmptyStateView(
                        title: "No Products",
                        message: "No products match your search."
                    )
                } else {
                    productList
                }
            }
            .navigationTitle("Products")
            .searchable(text: $store.searchQuery)
            .refreshable {
                await store.send(.refresh).finish()
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
        .sheet(item: $store.scope(state: \.destination?.detail, action: \.destination.detail)) { store in
            ProductDetailView(store: store)
        }
    }

    private var productList: some View {
        List(store.filteredProducts) { product in
            ProductRow(product: product)
                .onTapGesture {
                    store.send(.productTapped(product))
                }
        }
    }
}
```

## Android State Management

### ViewModel with StateFlow

```kotlin
// ProductListViewModel.kt
@HiltViewModel
class ProductListViewModel @Inject constructor(
    private val productRepository: ProductRepository,
    private val savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProductListUiState())
    val uiState: StateFlow<ProductListUiState> = _uiState.asStateFlow()

    private val _events = Channel<ProductListEvent>(Channel.BUFFERED)
    val events: Flow<ProductListEvent> = _events.receiveAsFlow()

    private var searchJob: Job? = null

    init {
        loadProducts()
    }

    fun loadProducts() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            productRepository.getProducts()
                .catch { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = error.message)
                    }
                }
                .collect { products ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            products = products,
                            error = null
                        )
                    }
                }
        }
    }

    fun onSearchQueryChange(query: String) {
        _uiState.update { it.copy(searchQuery = query) }

        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300) // Debounce
            performSearch(query)
        }
    }

    private suspend fun performSearch(query: String) {
        if (query.isBlank()) {
            loadProducts()
            return
        }

        productRepository.searchProducts(query)
            .collect { products ->
                _uiState.update { it.copy(products = products) }
            }
    }

    fun onProductClick(product: Product) {
        viewModelScope.launch {
            _events.send(ProductListEvent.NavigateToDetail(product.id))
        }
    }

    fun onRefresh() {
        loadProducts()
    }

    fun onRetry() {
        loadProducts()
    }
}

data class ProductListUiState(
    val products: List<Product> = emptyList(),
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val error: String? = null
) {
    val isEmpty: Boolean
        get() = products.isEmpty() && !isLoading && error == null

    val showEmptyState: Boolean
        get() = isEmpty && searchQuery.isNotBlank()
}

sealed class ProductListEvent {
    data class NavigateToDetail(val productId: String) : ProductListEvent()
    data class ShowSnackbar(val message: String) : ProductListEvent()
}

// ProductListScreen.kt
@Composable
fun ProductListScreen(
    viewModel: ProductListViewModel = hiltViewModel(),
    onNavigateToDetail: (String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is ProductListEvent.NavigateToDetail -> {
                    onNavigateToDetail(event.productId)
                }
                is ProductListEvent.ShowSnackbar -> {
                    // Show snackbar
                }
            }
        }
    }

    ProductListContent(
        uiState = uiState,
        onSearchQueryChange = viewModel::onSearchQueryChange,
        onProductClick = viewModel::onProductClick,
        onRefresh = viewModel::onRefresh,
        onRetry = viewModel::onRetry
    )
}

@Composable
private fun ProductListContent(
    uiState: ProductListUiState,
    onSearchQueryChange: (String) -> Unit,
    onProductClick: (Product) -> Unit,
    onRefresh: () -> Unit,
    onRetry: () -> Unit
) {
    Scaffold(
        topBar = {
            SearchTopBar(
                query = uiState.searchQuery,
                onQueryChange = onSearchQueryChange
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading && uiState.products.isEmpty() -> {
                    LoadingIndicator()
                }
                uiState.error != null && uiState.products.isEmpty() -> {
                    ErrorContent(
                        message = uiState.error,
                        onRetry = onRetry
                    )
                }
                uiState.showEmptyState -> {
                    EmptyStateContent(
                        title = "No Results",
                        message = "No products match your search."
                    )
                }
                else -> {
                    ProductList(
                        products = uiState.products,
                        isRefreshing = uiState.isRefreshing,
                        onProductClick = onProductClick,
                        onRefresh = onRefresh
                    )
                }
            }
        }
    }
}
```

### MVI Pattern with Sealed Classes

```kotlin
// CartContract.kt
object CartContract {
    data class State(
        val items: List<CartItem> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null
    ) {
        val totalItems: Int get() = items.sumOf { it.quantity }
        val subtotal: Double get() = items.sumOf { it.product.price * it.quantity }
        val tax: Double get() = subtotal * 0.1
        val total: Double get() = subtotal + tax
        val isEmpty: Boolean get() = items.isEmpty()
    }

    sealed class Intent {
        data class AddToCart(val product: Product, val quantity: Int = 1) : Intent()
        data class UpdateQuantity(val productId: String, val quantity: Int) : Intent()
        data class RemoveItem(val productId: String) : Intent()
        data object ClearCart : Intent()
        data object LoadCart : Intent()
        data object Checkout : Intent()
    }

    sealed class Effect {
        data class ShowSnackbar(val message: String) : Effect()
        data object NavigateToCheckout : Effect()
        data class NavigateToProduct(val productId: String) : Effect()
    }
}

// CartViewModel.kt
@HiltViewModel
class CartViewModel @Inject constructor(
    private val cartRepository: CartRepository
) : ViewModel() {

    private val _state = MutableStateFlow(CartContract.State())
    val state: StateFlow<CartContract.State> = _state.asStateFlow()

    private val _effects = Channel<CartContract.Effect>(Channel.BUFFERED)
    val effects: Flow<CartContract.Effect> = _effects.receiveAsFlow()

    init {
        processIntent(CartContract.Intent.LoadCart)
    }

    fun processIntent(intent: CartContract.Intent) {
        viewModelScope.launch {
            when (intent) {
                is CartContract.Intent.LoadCart -> loadCart()
                is CartContract.Intent.AddToCart -> addToCart(intent.product, intent.quantity)
                is CartContract.Intent.UpdateQuantity -> updateQuantity(intent.productId, intent.quantity)
                is CartContract.Intent.RemoveItem -> removeItem(intent.productId)
                is CartContract.Intent.ClearCart -> clearCart()
                is CartContract.Intent.Checkout -> checkout()
            }
        }
    }

    private suspend fun loadCart() {
        _state.update { it.copy(isLoading = true) }

        try {
            val items = cartRepository.getCartItems()
            _state.update { it.copy(items = items, isLoading = false) }
        } catch (e: Exception) {
            _state.update { it.copy(error = e.message, isLoading = false) }
        }
    }

    private suspend fun addToCart(product: Product, quantity: Int) {
        val currentItems = _state.value.items.toMutableList()
        val existingIndex = currentItems.indexOfFirst { it.product.id == product.id }

        if (existingIndex != -1) {
            val existingItem = currentItems[existingIndex]
            currentItems[existingIndex] = existingItem.copy(
                quantity = existingItem.quantity + quantity
            )
        } else {
            currentItems.add(CartItem(product = product, quantity = quantity))
        }

        _state.update { it.copy(items = currentItems) }
        cartRepository.saveCart(currentItems)

        _effects.send(CartContract.Effect.ShowSnackbar("Added to cart"))
    }

    private suspend fun updateQuantity(productId: String, quantity: Int) {
        val currentItems = _state.value.items.toMutableList()
        val index = currentItems.indexOfFirst { it.product.id == productId }

        if (index != -1) {
            if (quantity <= 0) {
                currentItems.removeAt(index)
            } else {
                currentItems[index] = currentItems[index].copy(quantity = quantity)
            }

            _state.update { it.copy(items = currentItems) }
            cartRepository.saveCart(currentItems)
        }
    }

    private suspend fun removeItem(productId: String) {
        val currentItems = _state.value.items.filter { it.product.id != productId }
        _state.update { it.copy(items = currentItems) }
        cartRepository.saveCart(currentItems)

        _effects.send(CartContract.Effect.ShowSnackbar("Item removed"))
    }

    private suspend fun clearCart() {
        _state.update { it.copy(items = emptyList()) }
        cartRepository.clearCart()
    }

    private suspend fun checkout() {
        if (_state.value.isEmpty) {
            _effects.send(CartContract.Effect.ShowSnackbar("Cart is empty"))
            return
        }
        _effects.send(CartContract.Effect.NavigateToCheckout)
    }
}
```

## React Native State Management

### Zustand Store

```typescript
// stores/authStore.ts
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { mmkvStorage } from '../services/storage';

interface User {
  id: string;
  email: string;
  name: string;
  avatar?: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
}

interface AuthActions {
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  updateUser: (updates: Partial<User>) => void;
  clearError: () => void;
}

type AuthStore = AuthState & AuthActions;

export const useAuthStore = create<AuthStore>()(
  persist(
    (set, get) => ({
      // State
      user: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,

      // Actions
      login: async (email: string, password: string) => {
        set({ isLoading: true, error: null });

        try {
          const response = await authService.login(email, password);
          await tokenStorage.setTokens(
            response.accessToken,
            response.refreshToken
          );

          set({
            user: response.user,
            isAuthenticated: true,
            isLoading: false,
          });
        } catch (error) {
          set({
            error: error instanceof Error ? error.message : 'Login failed',
            isLoading: false,
          });
          throw error;
        }
      },

      logout: async () => {
        await tokenStorage.clearTokens();
        set({
          user: null,
          isAuthenticated: false,
          error: null,
        });
      },

      updateUser: (updates: Partial<User>) => {
        const currentUser = get().user;
        if (currentUser) {
          set({ user: { ...currentUser, ...updates } });
        }
      },

      clearError: () => set({ error: null }),
    }),
    {
      name: 'auth-storage',
      storage: createJSONStorage(() => ({
        getItem: (key: string) => mmkvStorage.getString(key) ?? null,
        setItem: (key: string, value: string) => mmkvStorage.setString(key, value),
        removeItem: (key: string) => mmkvStorage.delete(key),
      })),
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);

// stores/cartStore.ts
import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';

interface CartItem {
  product: Product;
  quantity: number;
}

interface CartState {
  items: CartItem[];
  isUpdating: boolean;
}

interface CartComputed {
  totalItems: number;
  subtotal: number;
  tax: number;
  total: number;
  isEmpty: boolean;
}

interface CartActions {
  addToCart: (product: Product, quantity?: number) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  removeFromCart: (productId: string) => void;
  clearCart: () => void;
}

type CartStore = CartState & CartActions;

export const useCartStore = create<CartStore>()(
  immer((set, get) => ({
    // State
    items: [],
    isUpdating: false,

    // Actions
    addToCart: (product: Product, quantity = 1) => {
      set((state) => {
        const existingIndex = state.items.findIndex(
          (item) => item.product.id === product.id
        );

        if (existingIndex !== -1) {
          state.items[existingIndex].quantity += quantity;
        } else {
          state.items.push({ product, quantity });
        }
      });
    },

    updateQuantity: (productId: string, quantity: number) => {
      set((state) => {
        const index = state.items.findIndex(
          (item) => item.product.id === productId
        );

        if (index !== -1) {
          if (quantity <= 0) {
            state.items.splice(index, 1);
          } else {
            state.items[index].quantity = quantity;
          }
        }
      });
    },

    removeFromCart: (productId: string) => {
      set((state) => {
        state.items = state.items.filter(
          (item) => item.product.id !== productId
        );
      });
    },

    clearCart: () => {
      set((state) => {
        state.items = [];
      });
    },
  }))
);

// Computed selectors
export const useCartTotalItems = () =>
  useCartStore((state) =>
    state.items.reduce((sum, item) => sum + item.quantity, 0)
  );

export const useCartSubtotal = () =>
  useCartStore((state) =>
    state.items.reduce(
      (sum, item) => sum + item.product.price * item.quantity,
      0
    )
  );

export const useCartTotal = () => {
  const subtotal = useCartSubtotal();
  const tax = subtotal * 0.1;
  return subtotal + tax;
};

export const useCartItem = (productId: string) =>
  useCartStore((state) =>
    state.items.find((item) => item.product.id === productId)
  );
```

### React Query for Server State

```typescript
// hooks/useProducts.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../services/api';

interface ProductFilters {
  categoryId?: string;
  minPrice?: number;
  maxPrice?: number;
  sortBy?: 'name' | 'price' | 'rating';
  sortOrder?: 'asc' | 'desc';
}

export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
  favorites: () => [...productKeys.all, 'favorites'] as const,
};

export const useProducts = (filters: ProductFilters = {}) => {
  return useQuery({
    queryKey: productKeys.list(filters),
    queryFn: () => apiClient.get<Product[]>('/products', { params: filters }),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes (formerly cacheTime)
  });
};

export const useProduct = (productId: string) => {
  return useQuery({
    queryKey: productKeys.detail(productId),
    queryFn: () => apiClient.get<Product>(`/products/${productId}`),
    enabled: !!productId,
    staleTime: 10 * 60 * 1000,
  });
};

export const useFavoriteProducts = () => {
  return useQuery({
    queryKey: productKeys.favorites(),
    queryFn: () => apiClient.get<Product[]>('/products/favorites'),
  });
};

export const useToggleFavorite = () => {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (productId: string) =>
      apiClient.post(`/products/${productId}/toggle-favorite`),
    onMutate: async (productId) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: productKeys.all });

      // Snapshot previous value
      const previousProducts = queryClient.getQueryData<Product[]>(
        productKeys.lists()
      );

      // Optimistically update
      queryClient.setQueriesData<Product[]>(
        { queryKey: productKeys.lists() },
        (old) =>
          old?.map((product) =>
            product.id === productId
              ? { ...product, isFavorite: !product.isFavorite }
              : product
          )
      );

      return { previousProducts };
    },
    onError: (err, productId, context) => {
      // Rollback on error
      if (context?.previousProducts) {
        queryClient.setQueriesData(
          { queryKey: productKeys.lists() },
          context.previousProducts
        );
      }
    },
    onSettled: () => {
      // Refetch after mutation
      queryClient.invalidateQueries({ queryKey: productKeys.all });
    },
  });
};

// hooks/useInfiniteProducts.ts
export const useInfiniteProducts = (categoryId?: string) => {
  return useInfiniteQuery({
    queryKey: ['products', 'infinite', categoryId],
    queryFn: ({ pageParam = 1 }) =>
      apiClient.get<PaginatedResponse<Product>>('/products', {
        params: { page: pageParam, limit: 20, categoryId },
      }),
    getNextPageParam: (lastPage) =>
      lastPage.hasNextPage ? lastPage.page + 1 : undefined,
    initialPageParam: 1,
  });
};
```

## Flutter State Management

### Riverpod

```dart
// providers/product_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_providers.g.dart';

// Async Notifier for products
@riverpod
class ProductList extends _$ProductList {
  @override
  Future<List<Product>> build() async {
    return _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final repository = ref.watch(productRepositoryProvider);
    return repository.getProducts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchProducts());
  }

  Future<void> toggleFavorite(String productId) async {
    final currentProducts = state.valueOrNull ?? [];

    // Optimistic update
    state = AsyncData(
      currentProducts.map((product) {
        if (product.id == productId) {
          return product.copyWith(isFavorite: !product.isFavorite);
        }
        return product;
      }).toList(),
    );

    try {
      final repository = ref.read(productRepositoryProvider);
      await repository.toggleFavorite(productId);
    } catch (e) {
      // Revert on error
      state = AsyncData(currentProducts);
      rethrow;
    }
  }
}

// Product detail provider
@riverpod
Future<Product> productDetail(ProductDetailRef ref, String productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(productId);
}

// Favorite products provider
@riverpod
List<Product> favoriteProducts(FavoriteProductsRef ref) {
  final productsAsync = ref.watch(productListProvider);
  return productsAsync.maybeWhen(
    data: (products) => products.where((p) => p.isFavorite).toList(),
    orElse: () => [],
  );
}

// Search provider with debounce
@riverpod
class ProductSearch extends _$ProductSearch {
  Timer? _debounce;

  @override
  AsyncValue<List<Product>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return const AsyncData([]);
  }

  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      state = const AsyncData([]);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(productRepositoryProvider);
      return repository.searchProducts(query);
    });
  }
}

// Cart providers
@riverpod
class Cart extends _$Cart {
  @override
  List<CartItem> build() {
    _loadCart();
    return [];
  }

  Future<void> _loadCart() async {
    final storage = ref.read(cartStorageProvider);
    final items = await storage.getCartItems();
    state = items;
  }

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      final updatedItems = [...state];
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + quantity,
      );
      state = updatedItems;
    } else {
      state = [...state, CartItem(product: product, quantity: quantity)];
    }

    await _saveCart();
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      state = state.where((item) => item.product.id != productId).toList();
    } else {
      state = state.map((item) {
        if (item.product.id == productId) {
          return item.copyWith(quantity: quantity);
        }
        return item;
      }).toList();
    }

    await _saveCart();
  }

  Future<void> removeFromCart(String productId) async {
    state = state.where((item) => item.product.id != productId).toList();
    await _saveCart();
  }

  Future<void> clearCart() async {
    state = [];
    final storage = ref.read(cartStorageProvider);
    await storage.clearCart();
  }

  Future<void> _saveCart() async {
    final storage = ref.read(cartStorageProvider);
    await storage.saveCart(state);
  }
}

// Computed cart values
@riverpod
int cartTotalItems(CartTotalItemsRef ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
}

@riverpod
double cartSubtotal(CartSubtotalRef ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + (item.product.price * item.quantity));
}

@riverpod
double cartTotal(CartTotalRef ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final tax = subtotal * 0.1;
  return subtotal + tax;
}
```

### BLoC Pattern

```dart
// blocs/product_list/product_list_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_list_event.dart';
part 'product_list_state.dart';
part 'product_list_bloc.freezed.dart';

class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  final ProductRepository _productRepository;

  ProductListBloc({required ProductRepository productRepository})
      : _productRepository = productRepository,
        super(const ProductListState.initial()) {
    on<ProductListEvent>((event, emit) async {
      await event.map(
        load: (e) => _onLoad(e, emit),
        refresh: (e) => _onRefresh(e, emit),
        search: (e) => _onSearch(e, emit),
        toggleFavorite: (e) => _onToggleFavorite(e, emit),
      );
    });
  }

  Future<void> _onLoad(
    _Load event,
    Emitter<ProductListState> emit,
  ) async {
    emit(const ProductListState.loading());

    try {
      final products = await _productRepository.getProducts();
      emit(ProductListState.loaded(products: products));
    } catch (e) {
      emit(ProductListState.error(message: e.toString()));
    }
  }

  Future<void> _onRefresh(
    _Refresh event,
    Emitter<ProductListState> emit,
  ) async {
    final currentProducts = state.maybeMap(
      loaded: (s) => s.products,
      orElse: () => <Product>[],
    );

    emit(ProductListState.loaded(
      products: currentProducts,
      isRefreshing: true,
    ));

    try {
      final products = await _productRepository.getProducts();
      emit(ProductListState.loaded(products: products));
    } catch (e) {
      emit(ProductListState.loaded(
        products: currentProducts,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onSearch(
    _Search event,
    Emitter<ProductListState> emit,
  ) async {
    if (event.query.isEmpty) {
      add(const ProductListEvent.load());
      return;
    }

    emit(const ProductListState.loading());

    try {
      final products = await _productRepository.searchProducts(event.query);
      emit(ProductListState.loaded(products: products, searchQuery: event.query));
    } catch (e) {
      emit(ProductListState.error(message: e.toString()));
    }
  }

  Future<void> _onToggleFavorite(
    _ToggleFavorite event,
    Emitter<ProductListState> emit,
  ) async {
    final currentState = state;
    if (currentState is! _Loaded) return;

    // Optimistic update
    final updatedProducts = currentState.products.map((product) {
      if (product.id == event.productId) {
        return product.copyWith(isFavorite: !product.isFavorite);
      }
      return product;
    }).toList();

    emit(currentState.copyWith(products: updatedProducts));

    try {
      await _productRepository.toggleFavorite(event.productId);
    } catch (e) {
      // Revert on error
      emit(currentState);
    }
  }
}

// Events
@freezed
class ProductListEvent with _$ProductListEvent {
  const factory ProductListEvent.load() = _Load;
  const factory ProductListEvent.refresh() = _Refresh;
  const factory ProductListEvent.search(String query) = _Search;
  const factory ProductListEvent.toggleFavorite(String productId) = _ToggleFavorite;
}

// States
@freezed
class ProductListState with _$ProductListState {
  const factory ProductListState.initial() = _Initial;
  const factory ProductListState.loading() = _Loading;
  const factory ProductListState.loaded({
    required List<Product> products,
    @Default(false) bool isRefreshing,
    @Default('') String searchQuery,
    String? error,
  }) = _Loaded;
  const factory ProductListState.error({required String message}) = _Error;
}
```

## Output Expectations

When implementing state management, the subagent should:

1. Create clearly defined state structures
2. Implement proper state initialization
3. Handle loading, success, and error states
4. Support optimistic updates where appropriate
5. Implement proper state persistence
6. Create computed/derived state selectors
7. Handle side effects appropriately
8. Support state debugging and logging
9. Implement proper cleanup on disposal
10. Enable easy testing of state logic
