---
name: Mobile Local Storage
platform: mobile
description: Local data persistence using SQLite, Realm, Core Data, Room, Keychain, and secure storage solutions for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Local Storage

## Purpose

Implement robust local data persistence strategies for mobile applications, including structured database storage, key-value stores, secure credential storage, and file system management. The storage layer should support offline-first architecture, data synchronization, and efficient querying.

## Storage Strategy Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Storage Types                             │
├─────────────────────────────────────────────────────────────────┤
│  Secure Storage        │  Key-Value Store    │  Database        │
│  - Keychain (iOS)      │  - UserDefaults     │  - Core Data     │
│  - Keystore (Android)  │  - DataStore        │  - Room          │
│  - Credentials         │  - MMKV             │  - SQLite        │
│  - Tokens              │  - Preferences      │  - Realm         │
│  - Secrets             │  - Settings         │  - Complex data  │
├─────────────────────────────────────────────────────────────────┤
│                        File Storage                              │
│  - Documents           │  - Cache            │  - Temp          │
│  - Images              │  - Downloads        │  - Media         │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Storage Solutions

### Keychain (Secure Storage)

```swift
// KeychainManager.swift
import Foundation
import Security

actor KeychainManager {
    static let shared = KeychainManager()

    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "app") {
        self.service = service
    }

    // MARK: - Generic CRUD Operations

    func save<T: Codable>(_ item: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(item)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]

            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// TokenStorage.swift
actor TokenStorage {
    private let keychain = KeychainManager.shared

    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"
    private let tokenExpirationKey = "tokenExpiration"

    struct AuthTokens: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
    }

    func saveTokens(_ tokens: AuthTokens) async throws {
        try await keychain.save(tokens, forKey: "authTokens")
    }

    func getAccessToken() async -> String? {
        try? await keychain.retrieve(AuthTokens.self, forKey: "authTokens").accessToken
    }

    func getRefreshToken() async -> String? {
        try? await keychain.retrieve(AuthTokens.self, forKey: "authTokens").refreshToken
    }

    var isTokenExpired: Bool {
        get async {
            guard let tokens = try? await keychain.retrieve(AuthTokens.self, forKey: "authTokens") else {
                return true
            }
            return tokens.expiresAt < Date()
        }
    }

    func clearTokens() async throws {
        try await keychain.delete(forKey: "authTokens")
    }
}
```

### UserDefaults (Key-Value Storage)

```swift
// UserDefaultsManager.swift
import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let container: UserDefaults

    init(key: String, defaultValue: T, container: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.container = container
    }

    var wrappedValue: T {
        get {
            container.object(forKey: key) as? T ?? defaultValue
        }
        set {
            container.set(newValue, forKey: key)
        }
    }
}

@propertyWrapper
struct CodableUserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    let container: UserDefaults

    init(key: String, defaultValue: T, container: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.container = container
    }

    var wrappedValue: T {
        get {
            guard let data = container.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                container.set(data, forKey: key)
            }
        }
    }
}

// AppSettings.swift
final class AppSettings {
    static let shared = AppSettings()

    @UserDefault(key: "hasCompletedOnboarding", defaultValue: false)
    var hasCompletedOnboarding: Bool

    @UserDefault(key: "notificationsEnabled", defaultValue: true)
    var notificationsEnabled: Bool

    @UserDefault(key: "selectedTheme", defaultValue: "system")
    var selectedTheme: String

    @UserDefault(key: "selectedLanguage", defaultValue: "en")
    var selectedLanguage: String

    @CodableUserDefault(key: "lastSyncDate", defaultValue: nil)
    var lastSyncDate: Date?

    @CodableUserDefault(key: "recentSearches", defaultValue: [])
    var recentSearches: [String]

    func reset() {
        hasCompletedOnboarding = false
        notificationsEnabled = true
        selectedTheme = "system"
        selectedLanguage = "en"
        lastSyncDate = nil
        recentSearches = []
    }
}
```

### Core Data

```swift
// CoreDataStack.swift
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    private init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")

        // Configure for background contexts
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error)")
            }
        }
    }
}

// ProductEntity+CoreDataClass.swift
@objc(ProductEntity)
public class ProductEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var desc: String?
    @NSManaged public var price: Double
    @NSManaged public var imageURL: String?
    @NSManaged public var categoryId: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isFavorite: Bool
}

extension ProductEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProductEntity> {
        return NSFetchRequest<ProductEntity>(entityName: "ProductEntity")
    }

    static func findOrCreate(id: String, in context: NSManagedObjectContext) -> ProductEntity {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let entity = ProductEntity(context: context)
        entity.id = id
        return entity
    }
}

// ProductRepository.swift
protocol ProductRepository {
    func getProducts(categoryId: String?) async throws -> [Product]
    func getProduct(id: String) async throws -> Product?
    func saveProducts(_ products: [Product]) async throws
    func toggleFavorite(productId: String) async throws
    func getFavorites() async throws -> [Product]
}

final class CoreDataProductRepository: ProductRepository {
    private let coreData: CoreDataStack

    init(coreData: CoreDataStack = .shared) {
        self.coreData = coreData
    }

    func getProducts(categoryId: String?) async throws -> [Product] {
        try await withCheckedThrowingContinuation { continuation in
            coreData.performBackgroundTask { context in
                let request = ProductEntity.fetchRequest()

                if let categoryId {
                    request.predicate = NSPredicate(format: "categoryId == %@", categoryId)
                }

                request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

                do {
                    let entities = try context.fetch(request)
                    let products = entities.map { Product(entity: $0) }
                    continuation.resume(returning: products)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getProduct(id: String) async throws -> Product? {
        try await withCheckedThrowingContinuation { continuation in
            coreData.performBackgroundTask { context in
                let request = ProductEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id)
                request.fetchLimit = 1

                do {
                    if let entity = try context.fetch(request).first {
                        continuation.resume(returning: Product(entity: entity))
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveProducts(_ products: [Product]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            coreData.performBackgroundTask { context in
                for product in products {
                    let entity = ProductEntity.findOrCreate(id: product.id, in: context)
                    entity.name = product.name
                    entity.desc = product.description
                    entity.price = product.price
                    entity.imageURL = product.imageURL?.absoluteString
                    entity.categoryId = product.categoryId
                    entity.updatedAt = Date()
                }

                do {
                    try context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func toggleFavorite(productId: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            coreData.performBackgroundTask { context in
                let request = ProductEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", productId)

                do {
                    if let entity = try context.fetch(request).first {
                        entity.isFavorite.toggle()
                        try context.save()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func getFavorites() async throws -> [Product] {
        try await withCheckedThrowingContinuation { continuation in
            coreData.performBackgroundTask { context in
                let request = ProductEntity.fetchRequest()
                request.predicate = NSPredicate(format: "isFavorite == true")

                do {
                    let entities = try context.fetch(request)
                    let products = entities.map { Product(entity: $0) }
                    continuation.resume(returning: products)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

## Android Storage Solutions

### EncryptedSharedPreferences (Secure Storage)

```kotlin
// SecureStorage.kt
@Singleton
class SecureStorage @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val encryptedPrefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            context,
            "secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    private val json = Json { ignoreUnknownKeys = true }

    fun saveString(key: String, value: String) {
        encryptedPrefs.edit().putString(key, value).apply()
    }

    fun getString(key: String): String? {
        return encryptedPrefs.getString(key, null)
    }

    inline fun <reified T> save(key: String, value: T) {
        val jsonString = json.encodeToString(value)
        saveString(key, jsonString)
    }

    inline fun <reified T> get(key: String): T? {
        return getString(key)?.let {
            try {
                json.decodeFromString<T>(it)
            } catch (e: Exception) {
                null
            }
        }
    }

    fun remove(key: String) {
        encryptedPrefs.edit().remove(key).apply()
    }

    fun clear() {
        encryptedPrefs.edit().clear().apply()
    }
}

// TokenManager.kt
@Singleton
class TokenManager @Inject constructor(
    private val secureStorage: SecureStorage
) {
    @Serializable
    data class AuthTokens(
        val accessToken: String,
        val refreshToken: String,
        val expiresAt: Long
    )

    companion object {
        private const val AUTH_TOKENS_KEY = "auth_tokens"
    }

    suspend fun saveTokens(
        accessToken: String,
        refreshToken: String,
        expiresIn: Long
    ) = withContext(Dispatchers.IO) {
        val tokens = AuthTokens(
            accessToken = accessToken,
            refreshToken = refreshToken,
            expiresAt = System.currentTimeMillis() + (expiresIn * 1000)
        )
        secureStorage.save(AUTH_TOKENS_KEY, tokens)
    }

    suspend fun getAccessToken(): String? = withContext(Dispatchers.IO) {
        secureStorage.get<AuthTokens>(AUTH_TOKENS_KEY)?.accessToken
    }

    suspend fun getRefreshToken(): String? = withContext(Dispatchers.IO) {
        secureStorage.get<AuthTokens>(AUTH_TOKENS_KEY)?.refreshToken
    }

    suspend fun isTokenExpired(): Boolean = withContext(Dispatchers.IO) {
        val tokens = secureStorage.get<AuthTokens>(AUTH_TOKENS_KEY)
        tokens?.let {
            System.currentTimeMillis() >= it.expiresAt
        } ?: true
    }

    suspend fun clearTokens() = withContext(Dispatchers.IO) {
        secureStorage.remove(AUTH_TOKENS_KEY)
    }
}
```

### DataStore (Key-Value Storage)

```kotlin
// AppPreferences.kt
@Serializable
data class AppPreferences(
    val hasCompletedOnboarding: Boolean = false,
    val notificationsEnabled: Boolean = true,
    val theme: String = "system",
    val language: String = "en",
    val lastSyncTimestamp: Long = 0,
    val recentSearches: List<String> = emptyList()
)

@Singleton
class AppPreferencesManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val Context.dataStore by preferencesDataStore(name = "app_preferences")

    private object PreferencesKeys {
        val HAS_COMPLETED_ONBOARDING = booleanPreferencesKey("has_completed_onboarding")
        val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
        val THEME = stringPreferencesKey("theme")
        val LANGUAGE = stringPreferencesKey("language")
        val LAST_SYNC_TIMESTAMP = longPreferencesKey("last_sync_timestamp")
        val RECENT_SEARCHES = stringPreferencesKey("recent_searches")
    }

    val preferences: Flow<AppPreferences> = context.dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { prefs ->
            AppPreferences(
                hasCompletedOnboarding = prefs[PreferencesKeys.HAS_COMPLETED_ONBOARDING] ?: false,
                notificationsEnabled = prefs[PreferencesKeys.NOTIFICATIONS_ENABLED] ?: true,
                theme = prefs[PreferencesKeys.THEME] ?: "system",
                language = prefs[PreferencesKeys.LANGUAGE] ?: "en",
                lastSyncTimestamp = prefs[PreferencesKeys.LAST_SYNC_TIMESTAMP] ?: 0,
                recentSearches = prefs[PreferencesKeys.RECENT_SEARCHES]?.let {
                    Json.decodeFromString(it)
                } ?: emptyList()
            )
        }

    suspend fun setOnboardingCompleted(completed: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.HAS_COMPLETED_ONBOARDING] = completed
        }
    }

    suspend fun setNotificationsEnabled(enabled: Boolean) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.NOTIFICATIONS_ENABLED] = enabled
        }
    }

    suspend fun setTheme(theme: String) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.THEME] = theme
        }
    }

    suspend fun setLanguage(language: String) {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.LANGUAGE] = language
        }
    }

    suspend fun updateLastSyncTimestamp() {
        context.dataStore.edit { prefs ->
            prefs[PreferencesKeys.LAST_SYNC_TIMESTAMP] = System.currentTimeMillis()
        }
    }

    suspend fun addRecentSearch(query: String) {
        context.dataStore.edit { prefs ->
            val currentSearches = prefs[PreferencesKeys.RECENT_SEARCHES]?.let {
                Json.decodeFromString<List<String>>(it)
            } ?: emptyList()

            val updatedSearches = listOf(query) + currentSearches
                .filter { it != query }
                .take(9)

            prefs[PreferencesKeys.RECENT_SEARCHES] = Json.encodeToString(updatedSearches)
        }
    }

    suspend fun clearRecentSearches() {
        context.dataStore.edit { prefs ->
            prefs.remove(PreferencesKeys.RECENT_SEARCHES)
        }
    }

    suspend fun reset() {
        context.dataStore.edit { prefs ->
            prefs.clear()
        }
    }
}
```

### Room Database

```kotlin
// AppDatabase.kt
@Database(
    entities = [
        ProductEntity::class,
        CategoryEntity::class,
        CartItemEntity::class,
        OrderEntity::class,
        OrderItemEntity::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun productDao(): ProductDao
    abstract fun categoryDao(): CategoryDao
    abstract fun cartDao(): CartDao
    abstract fun orderDao(): OrderDao
}

// DatabaseModule.kt
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context
    ): AppDatabase {
        return Room.databaseBuilder(
            context,
            AppDatabase::class.java,
            "app_database"
        )
            .addMigrations(MIGRATION_1_2)
            .fallbackToDestructiveMigration()
            .build()
    }

    @Provides
    fun provideProductDao(database: AppDatabase): ProductDao {
        return database.productDao()
    }

    @Provides
    fun provideCategoryDao(database: AppDatabase): CategoryDao {
        return database.categoryDao()
    }

    @Provides
    fun provideCartDao(database: AppDatabase): CartDao {
        return database.cartDao()
    }
}

// ProductEntity.kt
@Entity(tableName = "products")
data class ProductEntity(
    @PrimaryKey
    val id: String,
    val name: String,
    val description: String?,
    val price: Double,
    val imageUrl: String?,
    val categoryId: String,
    val isFavorite: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

// ProductDao.kt
@Dao
interface ProductDao {
    @Query("SELECT * FROM products ORDER BY name ASC")
    fun getAllProducts(): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE categoryId = :categoryId ORDER BY name ASC")
    fun getProductsByCategory(categoryId: String): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE id = :id")
    suspend fun getProductById(id: String): ProductEntity?

    @Query("SELECT * FROM products WHERE isFavorite = 1")
    fun getFavoriteProducts(): Flow<List<ProductEntity>>

    @Query("SELECT * FROM products WHERE name LIKE '%' || :query || '%' OR description LIKE '%' || :query || '%'")
    fun searchProducts(query: String): Flow<List<ProductEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProduct(product: ProductEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProducts(products: List<ProductEntity>)

    @Update
    suspend fun updateProduct(product: ProductEntity)

    @Query("UPDATE products SET isFavorite = :isFavorite WHERE id = :productId")
    suspend fun updateFavoriteStatus(productId: String, isFavorite: Boolean)

    @Query("DELETE FROM products WHERE id = :id")
    suspend fun deleteProduct(id: String)

    @Query("DELETE FROM products")
    suspend fun deleteAllProducts()

    @Transaction
    suspend fun upsertProducts(products: List<ProductEntity>) {
        deleteAllProducts()
        insertProducts(products)
    }
}

// Converters.kt
class Converters {
    @TypeConverter
    fun fromTimestamp(value: Long?): Date? {
        return value?.let { Date(it) }
    }

    @TypeConverter
    fun dateToTimestamp(date: Date?): Long? {
        return date?.time
    }

    @TypeConverter
    fun fromStringList(value: List<String>): String {
        return Json.encodeToString(value)
    }

    @TypeConverter
    fun toStringList(value: String): List<String> {
        return Json.decodeFromString(value)
    }
}

// ProductRepository.kt
@Singleton
class ProductRepository @Inject constructor(
    private val productDao: ProductDao,
    private val apiService: ApiService
) {
    fun getProducts(categoryId: String? = null): Flow<List<Product>> {
        return if (categoryId != null) {
            productDao.getProductsByCategory(categoryId)
        } else {
            productDao.getAllProducts()
        }.map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun getFavorites(): Flow<List<Product>> {
        return productDao.getFavoriteProducts().map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun searchProducts(query: String): Flow<List<Product>> {
        return productDao.searchProducts(query).map { entities ->
            entities.map { it.toDomain() }
        }
    }

    suspend fun refreshProducts() {
        val response = apiService.getProducts(page = 1, limit = 100)
        val entities = response.data.map { it.toEntity() }
        productDao.upsertProducts(entities)
    }

    suspend fun toggleFavorite(productId: String) {
        val product = productDao.getProductById(productId)
        product?.let {
            productDao.updateFavoriteStatus(productId, !it.isFavorite)
        }
    }
}
```

## React Native Storage

### MMKV (High-Performance Key-Value)

```typescript
// storage.ts
import { MMKV } from 'react-native-mmkv';

export const storage = new MMKV({
  id: 'app-storage',
  encryptionKey: 'your-encryption-key', // Use secure key management
});

// Secure storage for sensitive data
export const secureStorage = new MMKV({
  id: 'secure-storage',
  encryptionKey: 'secure-encryption-key',
});

// Type-safe storage wrapper
export const mmkvStorage = {
  getString: (key: string): string | undefined => {
    return storage.getString(key);
  },

  setString: (key: string, value: string): void => {
    storage.set(key, value);
  },

  getNumber: (key: string): number | undefined => {
    return storage.getNumber(key);
  },

  setNumber: (key: string, value: number): void => {
    storage.set(key, value);
  },

  getBoolean: (key: string): boolean | undefined => {
    return storage.getBoolean(key);
  },

  setBoolean: (key: string, value: boolean): void => {
    storage.set(key, value);
  },

  getObject: <T>(key: string): T | undefined => {
    const jsonString = storage.getString(key);
    if (jsonString) {
      try {
        return JSON.parse(jsonString) as T;
      } catch {
        return undefined;
      }
    }
    return undefined;
  },

  setObject: <T>(key: string, value: T): void => {
    storage.set(key, JSON.stringify(value));
  },

  delete: (key: string): void => {
    storage.delete(key);
  },

  clearAll: (): void => {
    storage.clearAll();
  },

  getAllKeys: (): string[] => {
    return storage.getAllKeys();
  },
};

// tokenStorage.ts
const ACCESS_TOKEN_KEY = 'access_token';
const REFRESH_TOKEN_KEY = 'refresh_token';
const TOKEN_EXPIRY_KEY = 'token_expiry';

export const tokenStorage = {
  setTokens: async (
    accessToken: string,
    refreshToken: string,
    expiresIn?: number
  ): Promise<void> => {
    secureStorage.set(ACCESS_TOKEN_KEY, accessToken);
    secureStorage.set(REFRESH_TOKEN_KEY, refreshToken);
    if (expiresIn) {
      secureStorage.set(TOKEN_EXPIRY_KEY, Date.now() + expiresIn * 1000);
    }
  },

  getAccessToken: async (): Promise<string | undefined> => {
    return secureStorage.getString(ACCESS_TOKEN_KEY);
  },

  getRefreshToken: async (): Promise<string | undefined> => {
    return secureStorage.getString(REFRESH_TOKEN_KEY);
  },

  isTokenExpired: (): boolean => {
    const expiry = secureStorage.getNumber(TOKEN_EXPIRY_KEY);
    if (!expiry) return true;
    return Date.now() >= expiry;
  },

  clearTokens: async (): Promise<void> => {
    secureStorage.delete(ACCESS_TOKEN_KEY);
    secureStorage.delete(REFRESH_TOKEN_KEY);
    secureStorage.delete(TOKEN_EXPIRY_KEY);
  },
};
```

### SQLite with TypeORM or Watermelon DB

```typescript
// database.ts (WatermelonDB)
import { Database } from '@nozbe/watermelondb';
import SQLiteAdapter from '@nozbe/watermelondb/adapters/sqlite';
import { schema } from './schema';
import { Product, Category, CartItem, Order } from './models';

const adapter = new SQLiteAdapter({
  schema,
  dbName: 'app_database',
  jsi: true,
  onSetUpError: (error) => {
    console.error('Database setup error:', error);
  },
});

export const database = new Database({
  adapter,
  modelClasses: [Product, Category, CartItem, Order],
});

// schema.ts
import { appSchema, tableSchema } from '@nozbe/watermelondb';

export const schema = appSchema({
  version: 1,
  tables: [
    tableSchema({
      name: 'products',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'description', type: 'string', isOptional: true },
        { name: 'price', type: 'number' },
        { name: 'image_url', type: 'string', isOptional: true },
        { name: 'category_id', type: 'string', isIndexed: true },
        { name: 'is_favorite', type: 'boolean' },
        { name: 'created_at', type: 'number' },
        { name: 'updated_at', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'categories',
      columns: [
        { name: 'name', type: 'string' },
        { name: 'image_url', type: 'string', isOptional: true },
        { name: 'sort_order', type: 'number' },
      ],
    }),
    tableSchema({
      name: 'cart_items',
      columns: [
        { name: 'product_id', type: 'string', isIndexed: true },
        { name: 'quantity', type: 'number' },
        { name: 'created_at', type: 'number' },
      ],
    }),
  ],
});

// models/Product.ts
import { Model } from '@nozbe/watermelondb';
import { field, text, date, readonly, relation } from '@nozbe/watermelondb/decorators';

export class Product extends Model {
  static table = 'products';

  static associations = {
    categories: { type: 'belongs_to' as const, key: 'category_id' },
  };

  @text('name') name!: string;
  @text('description') description?: string;
  @field('price') price!: number;
  @text('image_url') imageUrl?: string;
  @text('category_id') categoryId!: string;
  @field('is_favorite') isFavorite!: boolean;
  @readonly @date('created_at') createdAt!: Date;
  @readonly @date('updated_at') updatedAt!: Date;

  @relation('categories', 'category_id') category!: Category;

  async toggleFavorite() {
    await this.update((product) => {
      product.isFavorite = !this.isFavorite;
    });
  }
}

// hooks/useProducts.ts
import { useDatabase } from '@nozbe/watermelondb/hooks';
import { Q } from '@nozbe/watermelondb';
import { Product } from '../models';

export const useProducts = (categoryId?: string) => {
  const database = useDatabase();

  return useObservable(() => {
    let query = database.get<Product>('products').query();

    if (categoryId) {
      query = query.extend(Q.where('category_id', categoryId));
    }

    return query.observe();
  }, [categoryId]);
};

export const useFavoriteProducts = () => {
  const database = useDatabase();

  return useObservable(
    () =>
      database
        .get<Product>('products')
        .query(Q.where('is_favorite', true))
        .observe(),
    []
  );
};

export const useProductSync = () => {
  const database = useDatabase();
  const queryClient = useQueryClient();

  const syncProducts = async () => {
    const response = await apiClient.get<ProductResponse[]>('/products');

    await database.write(async () => {
      const productsCollection = database.get<Product>('products');

      // Batch create/update
      const operations = response.map((productData) =>
        productsCollection.prepareCreate((product) => {
          product._raw.id = productData.id;
          product.name = productData.name;
          product.description = productData.description;
          product.price = productData.price;
          product.imageUrl = productData.imageUrl;
          product.categoryId = productData.categoryId;
        })
      );

      await database.batch(...operations);
    });

    queryClient.invalidateQueries({ queryKey: ['products'] });
  };

  return { syncProducts };
};
```

## Flutter Storage

### Flutter Secure Storage

```dart
// secure_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  Future<void> writeObject<T>(String key, T object) async {
    final jsonString = jsonEncode(object);
    await write(key, jsonString);
  }

  Future<T?> readObject<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final jsonString = await read(key);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      return null;
    }
  }
}

// token_storage.dart
class TokenStorage {
  final SecureStorageService _secureStorage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiryKey = 'token_expiry';

  TokenStorage(this._secureStorage);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
  }) async {
    await Future.wait([
      _secureStorage.write(_accessTokenKey, accessToken),
      _secureStorage.write(_refreshTokenKey, refreshToken),
      if (expiresIn != null)
        _secureStorage.write(
          _tokenExpiryKey,
          DateTime.now()
              .add(Duration(seconds: expiresIn))
              .millisecondsSinceEpoch
              .toString(),
        ),
    ]);
  }

  Future<String?> getAccessToken() async {
    return _secureStorage.read(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(_refreshTokenKey);
  }

  Future<bool> isTokenExpired() async {
    final expiryString = await _secureStorage.read(_tokenExpiryKey);
    if (expiryString == null) return true;

    final expiry = int.tryParse(expiryString);
    if (expiry == null) return true;

    return DateTime.now().millisecondsSinceEpoch >= expiry;
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _secureStorage.delete(_accessTokenKey),
      _secureStorage.delete(_refreshTokenKey),
      _secureStorage.delete(_tokenExpiryKey),
    ]);
  }
}
```

### Drift (SQLite)

```dart
// database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get price => real()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get categoryId => text()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get imageUrl => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CartItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Products, Categories, CartItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle migrations
      },
    );
  }

  // Product queries
  Stream<List<Product>> watchAllProducts() {
    return select(products).watch();
  }

  Stream<List<Product>> watchProductsByCategory(String categoryId) {
    return (select(products)..where((p) => p.categoryId.equals(categoryId)))
        .watch();
  }

  Stream<List<Product>> watchFavoriteProducts() {
    return (select(products)..where((p) => p.isFavorite.equals(true))).watch();
  }

  Future<Product?> getProductById(String id) {
    return (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertProduct(ProductsCompanion product) {
    return into(products).insertOnConflictUpdate(product);
  }

  Future<void> insertProducts(List<ProductsCompanion> productList) {
    return batch((batch) {
      batch.insertAllOnConflictUpdate(products, productList);
    });
  }

  Future<void> toggleFavorite(String productId) async {
    final product = await getProductById(productId);
    if (product != null) {
      await (update(products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(
          isFavorite: Value(!product.isFavorite),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> deleteAllProducts() {
    return delete(products).go();
  }

  // Cart queries
  Stream<List<CartItemWithProduct>> watchCartItems() {
    final query = select(cartItems).join([
      innerJoin(products, products.id.equalsExp(cartItems.productId)),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return CartItemWithProduct(
          cartItem: row.readTable(cartItems),
          product: row.readTable(products),
        );
      }).toList();
    });
  }

  Future<void> addToCart(String productId, {int quantity = 1}) async {
    final existingItem = await (select(cartItems)
          ..where((c) => c.productId.equals(productId)))
        .getSingleOrNull();

    if (existingItem != null) {
      await (update(cartItems)..where((c) => c.id.equals(existingItem.id)))
          .write(CartItemsCompanion(
        quantity: Value(existingItem.quantity + quantity),
      ));
    } else {
      await into(cartItems).insert(CartItemsCompanion(
        productId: Value(productId),
        quantity: Value(quantity),
      ));
    }
  }

  Future<void> updateCartItemQuantity(int cartItemId, int quantity) {
    if (quantity <= 0) {
      return (delete(cartItems)..where((c) => c.id.equals(cartItemId))).go();
    }
    return (update(cartItems)..where((c) => c.id.equals(cartItemId)))
        .write(CartItemsCompanion(quantity: Value(quantity)));
  }

  Future<void> clearCart() {
    return delete(cartItems).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app.db'));
    return NativeDatabase.createInBackground(file);
  });
}

class CartItemWithProduct {
  final CartItem cartItem;
  final Product product;

  CartItemWithProduct({required this.cartItem, required this.product});

  double get totalPrice => product.price * cartItem.quantity;
}
```

## Output Expectations

When implementing local storage, the subagent should:

1. Configure secure storage for sensitive data (tokens, credentials)
2. Set up key-value storage for preferences and settings
3. Implement database schema for structured data
4. Create repository pattern for data access
5. Support offline-first data strategies
6. Implement data synchronization logic
7. Handle database migrations properly
8. Set up proper encryption for sensitive data
9. Create type-safe storage wrappers
10. Implement data expiration and cleanup strategies
