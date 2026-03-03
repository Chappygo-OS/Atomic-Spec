---
name: Mobile In-App Purchase Integration
platform: mobile
description: In-app purchases, subscriptions, receipt validation, and purchase restoration for iOS, Android, and cross-platform applications
model: opus
category: mobile/frontend
---

# Mobile In-App Purchase Integration

## Purpose

Implement robust in-app purchase systems that handle consumables, non-consumables, auto-renewable subscriptions, and non-renewing subscriptions. The IAP layer should manage purchase flows, receipt validation, subscription status tracking, and graceful error handling across platforms.

## IAP Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    IAP Flow Overview                             │
├─────────────────────────────────────────────────────────────────┤
│  1. Fetch Products    → Query store for available products      │
│  2. Display Products  → Show prices in user's currency          │
│  3. Initiate Purchase → User confirms purchase                  │
│  4. Process Payment   → Store processes transaction             │
│  5. Validate Receipt  → Server validates with store             │
│  6. Grant Entitlement → Unlock content/features                 │
│  7. Finish Transaction → Mark transaction complete              │
├─────────────────────────────────────────────────────────────────┤
│  Product Types:                                                  │
│  - Consumable: Can be purchased multiple times                  │
│  - Non-consumable: One-time purchase, permanent                 │
│  - Auto-renewable subscription: Recurring billing               │
│  - Non-renewing subscription: Fixed duration, manual renewal    │
└─────────────────────────────────────────────────────────────────┘
```

## iOS StoreKit 2 Implementation

### Store Manager

```swift
// StoreManager.swift
import StoreKit

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private(set) var products: [Product] = []
    private(set) var purchasedProducts: Set<String> = []
    private(set) var subscriptionStatus: SubscriptionStatus?
    private(set) var isLoading: Bool = false
    private(set) var error: StoreError?

    private var updateListenerTask: Task<Void, Error>?

    enum ProductIdentifier {
        static let premiumMonthly = "com.app.premium.monthly"
        static let premiumYearly = "com.app.premium.yearly"
        static let removeAds = "com.app.removeads"
        static let coinPack100 = "com.app.coins.100"
        static let coinPack500 = "com.app.coins.500"

        static let subscriptions = [premiumMonthly, premiumYearly]
        static let all = [premiumMonthly, premiumYearly, removeAds, coinPack100, coinPack500]
    }

    struct SubscriptionStatus {
        let isActive: Bool
        let productId: String?
        let expirationDate: Date?
        let willRenew: Bool
        let isInGracePeriod: Bool
        let isInBillingRetry: Bool
    }

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            products = try await Product.products(for: ProductIdentifier.all)
            products.sort { $0.price < $1.price }
        } catch {
            self.error = .productLoadFailed(error)
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Validate receipt on server
                await validateReceiptOnServer(transaction)

                // Update local state
                await updatePurchasedProducts()

                // Finish transaction
                await transaction.finish()

                isLoading = false
                return transaction

            case .userCancelled:
                isLoading = false
                return nil

            case .pending:
                isLoading = false
                throw StoreError.purchasePending

            @unknown default:
                isLoading = false
                throw StoreError.unknown
            }
        } catch {
            isLoading = false
            if let storeError = error as? StoreError {
                throw storeError
            }
            throw StoreError.purchaseFailed(error)
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            self.error = .restoreFailed(error)
            throw error
        }

        isLoading = false
    }

    // MARK: - Subscription Management

    func checkSubscriptionStatus() async {
        var status = SubscriptionStatus(
            isActive: false,
            productId: nil,
            expirationDate: nil,
            willRenew: false,
            isInGracePeriod: false,
            isInBillingRetry: false
        )

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if ProductIdentifier.subscriptions.contains(transaction.productID) {
                if let subscriptionStatus = await transaction.subscriptionStatus {
                    let renewalInfo = try? subscriptionStatus.renewalInfo.payloadValue

                    status = SubscriptionStatus(
                        isActive: subscriptionStatus.state == .subscribed ||
                                  subscriptionStatus.state == .inGracePeriod ||
                                  subscriptionStatus.state == .inBillingRetryPeriod,
                        productId: transaction.productID,
                        expirationDate: transaction.expirationDate,
                        willRenew: renewalInfo?.willAutoRenew ?? false,
                        isInGracePeriod: subscriptionStatus.state == .inGracePeriod,
                        isInBillingRetry: subscriptionStatus.state == .inBillingRetryPeriod
                    )
                    break
                }
            }
        }

        subscriptionStatus = status
    }

    func manageSubscription() async {
        if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
            } catch {
                print("Failed to show subscription management: \(error)")
            }
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    await self.validateReceiptOnServer(transaction)
                    await self.updatePurchasedProducts()

                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProducts = purchased
        await checkSubscriptionStatus()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let signedType):
            return signedType
        }
    }

    private func validateReceiptOnServer(_ transaction: Transaction) async {
        // Send to your backend for validation
        do {
            let receiptData = try await transaction.payloadData
            let receiptString = receiptData.base64EncodedString()

            let endpoint = Endpoint(
                path: "/purchases/validate",
                method: .post,
                body: ReceiptValidationRequest(
                    receipt: receiptString,
                    productId: transaction.productID,
                    transactionId: String(transaction.id)
                )
            )

            try await APIClient.shared.request(endpoint)
        } catch {
            print("Server validation failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    func isPurchased(_ productId: String) -> Bool {
        purchasedProducts.contains(productId)
    }

    func product(for identifier: String) -> Product? {
        products.first { $0.id == identifier }
    }

    var hasActiveSubscription: Bool {
        subscriptionStatus?.isActive ?? false
    }
}

// StoreError.swift
enum StoreError: LocalizedError {
    case productLoadFailed(Error)
    case purchaseFailed(Error)
    case purchasePending
    case verificationFailed
    case restoreFailed(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .productLoadFailed:
            return "Failed to load products. Please try again."
        case .purchaseFailed:
            return "Purchase failed. Please try again."
        case .purchasePending:
            return "Purchase is pending approval."
        case .verificationFailed:
            return "Could not verify purchase."
        case .restoreFailed:
            return "Failed to restore purchases. Please try again."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
```

### Subscription View

```swift
// SubscriptionView.swift
struct SubscriptionView: View {
    @State private var store = StoreManager.shared
    @State private var selectedProduct: Product?
    @State private var showError: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)

                        Text("Upgrade to Premium")
                            .font(.title.bold())

                        Text("Unlock all features and remove ads")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(icon: "checkmark.circle.fill", text: "Unlimited access")
                        FeatureRow(icon: "xmark.circle.fill", text: "No advertisements")
                        FeatureRow(icon: "cloud.fill", text: "Cloud sync")
                        FeatureRow(icon: "person.2.fill", text: "Family sharing")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Subscription options
                    VStack(spacing: 12) {
                        ForEach(subscriptionProducts, id: \.id) { product in
                            SubscriptionOptionCard(
                                product: product,
                                isSelected: selectedProduct?.id == product.id
                            ) {
                                selectedProduct = product
                            }
                        }
                    }

                    // Purchase button
                    AppButton(
                        "Subscribe Now",
                        isLoading: store.isLoading,
                        isDisabled: selectedProduct == nil
                    ) {
                        Task {
                            await purchase()
                        }
                    }

                    // Restore purchases
                    Button("Restore Purchases") {
                        Task {
                            try? await store.restorePurchases()
                        }
                    }
                    .font(.subheadline)

                    // Legal text
                    Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(store.error?.errorDescription ?? "An error occurred")
            }
        }
    }

    private var subscriptionProducts: [Product] {
        store.products.filter { StoreManager.ProductIdentifier.subscriptions.contains($0.id) }
    }

    private func purchase() async {
        guard let product = selectedProduct else { return }

        do {
            _ = try await store.purchase(product)
        } catch {
            showError = true
        }
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)

                    if let subscription = product.subscription {
                        Text(subscription.subscriptionPeriod.displayString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.headline)

                    if product.id == StoreManager.ProductIdentifier.premiumYearly {
                        Text("Save 50%")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

extension Product.SubscriptionPeriod {
    var displayString: String {
        switch unit {
        case .day:
            return value == 1 ? "Daily" : "Every \(value) days"
        case .week:
            return value == 1 ? "Weekly" : "Every \(value) weeks"
        case .month:
            return value == 1 ? "Monthly" : "Every \(value) months"
        case .year:
            return value == 1 ? "Yearly" : "Every \(value) years"
        @unknown default:
            return ""
        }
    }
}
```

## Android Billing Library Implementation

### Billing Manager

```kotlin
// BillingManager.kt
@Singleton
class BillingManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val purchaseRepository: PurchaseRepository
) {
    private val _products = MutableStateFlow<List<ProductDetails>>(emptyList())
    val products: StateFlow<List<ProductDetails>> = _products.asStateFlow()

    private val _purchases = MutableStateFlow<List<Purchase>>(emptyList())
    val purchases: StateFlow<List<Purchase>> = _purchases.asStateFlow()

    private val _subscriptionStatus = MutableStateFlow<SubscriptionStatus?>(null)
    val subscriptionStatus: StateFlow<SubscriptionStatus?> = _subscriptionStatus.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private var billingClient: BillingClient? = null

    object ProductIds {
        const val PREMIUM_MONTHLY = "premium_monthly"
        const val PREMIUM_YEARLY = "premium_yearly"
        const val REMOVE_ADS = "remove_ads"
        const val COINS_100 = "coins_100"
        const val COINS_500 = "coins_500"

        val subscriptions = listOf(PREMIUM_MONTHLY, PREMIUM_YEARLY)
        val inAppProducts = listOf(REMOVE_ADS, COINS_100, COINS_500)
    }

    data class SubscriptionStatus(
        val isActive: Boolean,
        val productId: String?,
        val expirationDate: Long?,
        val willRenew: Boolean,
        val isInGracePeriod: Boolean
    )

    private val purchasesUpdatedListener = PurchasesUpdatedListener { billingResult, purchases ->
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                purchases?.let { processPurchases(it) }
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> {
                // User cancelled
            }
            else -> {
                // Handle error
            }
        }
    }

    fun initialize() {
        billingClient = BillingClient.newBuilder(context)
            .setListener(purchasesUpdatedListener)
            .enablePendingPurchases()
            .build()

        startConnection()
    }

    private fun startConnection() {
        billingClient?.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    CoroutineScope(Dispatchers.IO).launch {
                        queryProducts()
                        queryPurchases()
                    }
                }
            }

            override fun onBillingServiceDisconnected() {
                // Retry connection
                startConnection()
            }
        })
    }

    suspend fun queryProducts() {
        _isLoading.value = true

        val subParams = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ProductIds.subscriptions.map { productId ->
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                }
            )
            .build()

        val inAppParams = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ProductIds.inAppProducts.map { productId ->
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.INAPP)
                        .build()
                }
            )
            .build()

        val subResult = billingClient?.queryProductDetails(subParams)
        val inAppResult = billingClient?.queryProductDetails(inAppParams)

        val allProducts = mutableListOf<ProductDetails>()
        subResult?.productDetailsList?.let { allProducts.addAll(it) }
        inAppResult?.productDetailsList?.let { allProducts.addAll(it) }

        _products.value = allProducts
        _isLoading.value = false
    }

    suspend fun queryPurchases() {
        val subResult = billingClient?.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        )

        val inAppResult = billingClient?.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        )

        val allPurchases = mutableListOf<Purchase>()
        subResult?.purchasesList?.let { allPurchases.addAll(it) }
        inAppResult?.purchasesList?.let { allPurchases.addAll(it) }

        _purchases.value = allPurchases
        updateSubscriptionStatus(allPurchases)

        // Process any unacknowledged purchases
        allPurchases.filter { !it.isAcknowledged }.forEach { purchase ->
            processPurchases(listOf(purchase))
        }
    }

    fun launchPurchaseFlow(activity: Activity, productDetails: ProductDetails) {
        val offerToken = productDetails.subscriptionOfferDetails?.firstOrNull()?.offerToken

        val productDetailsParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(productDetails)
            .apply {
                offerToken?.let { setOfferToken(it) }
            }
            .build()

        val billingFlowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParams))
            .build()

        billingClient?.launchBillingFlow(activity, billingFlowParams)
    }

    private fun processPurchases(purchases: List<Purchase>) {
        CoroutineScope(Dispatchers.IO).launch {
            purchases.forEach { purchase ->
                when (purchase.purchaseState) {
                    Purchase.PurchaseState.PURCHASED -> {
                        // Validate on server
                        val isValid = validatePurchaseOnServer(purchase)

                        if (isValid && !purchase.isAcknowledged) {
                            acknowledgePurchase(purchase)
                        }
                    }
                    Purchase.PurchaseState.PENDING -> {
                        // Handle pending purchase
                    }
                }
            }

            queryPurchases()
        }
    }

    private suspend fun validatePurchaseOnServer(purchase: Purchase): Boolean {
        return try {
            purchaseRepository.validatePurchase(
                purchaseToken = purchase.purchaseToken,
                productId = purchase.products.firstOrNull() ?: "",
                orderId = purchase.orderId ?: ""
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private suspend fun acknowledgePurchase(purchase: Purchase) {
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()

        billingClient?.acknowledgePurchase(params) { billingResult ->
            if (billingResult.responseCode != BillingClient.BillingResponseCode.OK) {
                // Handle error
            }
        }
    }

    suspend fun consumePurchase(purchase: Purchase) {
        val params = ConsumeParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()

        billingClient?.consumePurchase(params)
    }

    private fun updateSubscriptionStatus(purchases: List<Purchase>) {
        val activeSub = purchases.firstOrNull { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
            purchase.products.any { it in ProductIds.subscriptions }
        }

        _subscriptionStatus.value = if (activeSub != null) {
            SubscriptionStatus(
                isActive = true,
                productId = activeSub.products.firstOrNull(),
                expirationDate = activeSub.purchaseTime + 30 * 24 * 60 * 60 * 1000L, // Approximate
                willRenew = activeSub.isAutoRenewing,
                isInGracePeriod = false
            )
        } else {
            SubscriptionStatus(
                isActive = false,
                productId = null,
                expirationDate = null,
                willRenew = false,
                isInGracePeriod = false
            )
        }
    }

    fun isPurchased(productId: String): Boolean {
        return _purchases.value.any { purchase ->
            purchase.purchaseState == Purchase.PurchaseState.PURCHASED &&
            purchase.products.contains(productId)
        }
    }

    val hasActiveSubscription: Boolean
        get() = _subscriptionStatus.value?.isActive == true

    fun endConnection() {
        billingClient?.endConnection()
    }
}
```

## React Native IAP

### Setup with react-native-iap

```typescript
// services/iapService.ts
import {
  initConnection,
  endConnection,
  getProducts,
  getSubscriptions,
  requestPurchase,
  requestSubscription,
  finishTransaction,
  purchaseUpdatedListener,
  purchaseErrorListener,
  getAvailablePurchases,
  Purchase,
  SubscriptionPurchase,
  Product,
  Subscription,
} from 'react-native-iap';
import { Platform } from 'react-native';

const PRODUCT_IDS = {
  subscriptions: ['premium_monthly', 'premium_yearly'],
  products: ['remove_ads', 'coins_100', 'coins_500'],
};

class IAPService {
  private purchaseUpdateSubscription: any;
  private purchaseErrorSubscription: any;

  async initialize(): Promise<boolean> {
    try {
      await initConnection();
      this.setupListeners();
      return true;
    } catch (error) {
      console.error('IAP init error:', error);
      return false;
    }
  }

  private setupListeners() {
    this.purchaseUpdateSubscription = purchaseUpdatedListener(
      async (purchase: Purchase | SubscriptionPurchase) => {
        await this.processPurchase(purchase);
      }
    );

    this.purchaseErrorSubscription = purchaseErrorListener((error) => {
      console.error('Purchase error:', error);
    });
  }

  async getProductsAndSubscriptions(): Promise<{
    products: Product[];
    subscriptions: Subscription[];
  }> {
    try {
      const [products, subscriptions] = await Promise.all([
        getProducts({ skus: PRODUCT_IDS.products }),
        getSubscriptions({ skus: PRODUCT_IDS.subscriptions }),
      ]);

      return { products, subscriptions };
    } catch (error) {
      console.error('Failed to get products:', error);
      return { products: [], subscriptions: [] };
    }
  }

  async purchaseProduct(productId: string): Promise<void> {
    try {
      await requestPurchase({ sku: productId });
    } catch (error) {
      console.error('Purchase error:', error);
      throw error;
    }
  }

  async purchaseSubscription(subscriptionId: string): Promise<void> {
    try {
      if (Platform.OS === 'android') {
        await requestSubscription({
          sku: subscriptionId,
          subscriptionOffers: [
            {
              sku: subscriptionId,
              offerToken: '', // Get from subscription details
            },
          ],
        });
      } else {
        await requestSubscription({ sku: subscriptionId });
      }
    } catch (error) {
      console.error('Subscription error:', error);
      throw error;
    }
  }

  private async processPurchase(
    purchase: Purchase | SubscriptionPurchase
  ): Promise<void> {
    try {
      // Validate on server
      const isValid = await this.validatePurchaseOnServer(purchase);

      if (isValid) {
        // Finish transaction
        await finishTransaction({ purchase, isConsumable: false });
      }
    } catch (error) {
      console.error('Process purchase error:', error);
    }
  }

  private async validatePurchaseOnServer(
    purchase: Purchase | SubscriptionPurchase
  ): Promise<boolean> {
    try {
      const response = await apiClient.post('/purchases/validate', {
        productId: purchase.productId,
        transactionId: purchase.transactionId,
        receipt: Platform.OS === 'ios'
          ? purchase.transactionReceipt
          : purchase.purchaseToken,
        platform: Platform.OS,
      });

      return response.valid;
    } catch (error) {
      console.error('Server validation error:', error);
      return false;
    }
  }

  async restorePurchases(): Promise<Purchase[]> {
    try {
      const purchases = await getAvailablePurchases();

      // Validate each purchase
      for (const purchase of purchases) {
        await this.processPurchase(purchase);
      }

      return purchases;
    } catch (error) {
      console.error('Restore error:', error);
      throw error;
    }
  }

  async checkSubscriptionStatus(): Promise<{
    isActive: boolean;
    productId?: string;
    expirationDate?: Date;
  }> {
    try {
      const purchases = await getAvailablePurchases();

      const activeSubscription = purchases.find(
        (p) =>
          PRODUCT_IDS.subscriptions.includes(p.productId) &&
          new Date(p.transactionDate).getTime() > Date.now() - 30 * 24 * 60 * 60 * 1000
      );

      if (activeSubscription) {
        return {
          isActive: true,
          productId: activeSubscription.productId,
          expirationDate: new Date(activeSubscription.transactionDate),
        };
      }

      return { isActive: false };
    } catch (error) {
      console.error('Check subscription error:', error);
      return { isActive: false };
    }
  }

  cleanup() {
    this.purchaseUpdateSubscription?.remove();
    this.purchaseErrorSubscription?.remove();
    endConnection();
  }
}

export const iapService = new IAPService();
```

### IAP Store Hook

```typescript
// hooks/useIAP.ts
import { create } from 'zustand';
import { iapService } from '../services/iapService';
import { Product, Subscription } from 'react-native-iap';

interface IAPState {
  products: Product[];
  subscriptions: Subscription[];
  isLoading: boolean;
  error: string | null;
  subscriptionStatus: {
    isActive: boolean;
    productId?: string;
    expirationDate?: Date;
  };
}

interface IAPActions {
  initialize: () => Promise<void>;
  loadProducts: () => Promise<void>;
  purchaseProduct: (productId: string) => Promise<void>;
  purchaseSubscription: (subscriptionId: string) => Promise<void>;
  restorePurchases: () => Promise<void>;
  checkSubscriptionStatus: () => Promise<void>;
}

export const useIAPStore = create<IAPState & IAPActions>((set, get) => ({
  products: [],
  subscriptions: [],
  isLoading: false,
  error: null,
  subscriptionStatus: { isActive: false },

  initialize: async () => {
    set({ isLoading: true, error: null });
    try {
      await iapService.initialize();
      await get().loadProducts();
      await get().checkSubscriptionStatus();
    } catch (error) {
      set({ error: 'Failed to initialize IAP' });
    } finally {
      set({ isLoading: false });
    }
  },

  loadProducts: async () => {
    set({ isLoading: true });
    try {
      const { products, subscriptions } =
        await iapService.getProductsAndSubscriptions();
      set({ products, subscriptions });
    } catch (error) {
      set({ error: 'Failed to load products' });
    } finally {
      set({ isLoading: false });
    }
  },

  purchaseProduct: async (productId: string) => {
    set({ isLoading: true, error: null });
    try {
      await iapService.purchaseProduct(productId);
    } catch (error) {
      set({ error: 'Purchase failed' });
      throw error;
    } finally {
      set({ isLoading: false });
    }
  },

  purchaseSubscription: async (subscriptionId: string) => {
    set({ isLoading: true, error: null });
    try {
      await iapService.purchaseSubscription(subscriptionId);
      await get().checkSubscriptionStatus();
    } catch (error) {
      set({ error: 'Subscription failed' });
      throw error;
    } finally {
      set({ isLoading: false });
    }
  },

  restorePurchases: async () => {
    set({ isLoading: true, error: null });
    try {
      await iapService.restorePurchases();
      await get().checkSubscriptionStatus();
    } catch (error) {
      set({ error: 'Restore failed' });
      throw error;
    } finally {
      set({ isLoading: false });
    }
  },

  checkSubscriptionStatus: async () => {
    const status = await iapService.checkSubscriptionStatus();
    set({ subscriptionStatus: status });
  },
}));
```

## Output Expectations

When implementing IAP, the subagent should:

1. Configure products in App Store Connect / Google Play Console
2. Implement product fetching and display
3. Handle purchase flows for all product types
4. Validate receipts on backend server
5. Implement purchase restoration
6. Track subscription status
7. Handle pending transactions
8. Support promotional offers and trials
9. Implement proper error handling
10. Comply with store guidelines
