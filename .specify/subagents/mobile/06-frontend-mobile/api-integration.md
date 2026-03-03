---
name: Mobile API Integration
platform: mobile
description: HTTP client configuration, request interceptors, retry logic, error handling, and API layer architecture for mobile applications
model: opus
category: mobile/frontend
---

# Mobile API Integration

## Purpose

Implement robust, type-safe API communication layers with proper error handling, authentication, retry mechanisms, caching, and offline support. The API layer should abstract network complexities while providing excellent developer experience and user feedback.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      UI / ViewModel                          │
├─────────────────────────────────────────────────────────────┤
│                      Repository Layer                        │
├─────────────────────────────────────────────────────────────┤
│                      API Client                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ Interceptors│  │ Serializers │  │ Error Mapping       │  │
│  │ - Auth      │  │ - JSON      │  │ - Network → Domain  │  │
│  │ - Logging   │  │ - Custom    │  │ - HTTP → App Error  │  │
│  │ - Retry     │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                      HTTP Client                             │
│              (URLSession / OkHttp / Axios / Dio)            │
└─────────────────────────────────────────────────────────────┘
```

## iOS API Client (Swift)

### Network Layer Setup

```swift
// NetworkClient.swift
import Foundation

protocol NetworkClient {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func request(_ endpoint: Endpoint) async throws -> Data
    func upload<T: Decodable>(_ endpoint: Endpoint, data: Data, mimeType: String) async throws -> T
    func download(_ endpoint: Endpoint) async throws -> URL
}

// Endpoint.swift
struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?
    let body: Encodable?
    let timeout: TimeInterval
    let cachePolicy: URLRequest.CachePolicy

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        timeout: TimeInterval = 30,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.timeout = timeout
        self.cachePolicy = cachePolicy
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// APIClient.swift
final class APIClient: NetworkClient {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let interceptors: [RequestInterceptor]
    private let tokenProvider: TokenProvider

    init(
        baseURL: URL,
        tokenProvider: TokenProvider,
        interceptors: [RequestInterceptor] = [],
        configuration: URLSessionConfiguration = .default
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.interceptors = interceptors
        self.session = URLSession(configuration: configuration)

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await request(endpoint)
        return try decoder.decode(T.self, from: data)
    }

    func request(_ endpoint: Endpoint) async throws -> Data {
        var request = try buildRequest(for: endpoint)

        // Apply interceptors
        for interceptor in interceptors {
            request = try await interceptor.intercept(request)
        }

        // Add auth token
        if let token = try await tokenProvider.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await executeWithRetry(request, endpoint: endpoint)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)

        return data
    }

    func upload<T: Decodable>(_ endpoint: Endpoint, data: Data, mimeType: String) async throws -> T {
        var request = try buildRequest(for: endpoint)
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        if let token = try await tokenProvider.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        try validateResponse(httpResponse, data: responseData)

        return try decoder.decode(T.self, from: responseData)
    }

    func download(_ endpoint: Endpoint) async throws -> URL {
        var request = try buildRequest(for: endpoint)

        if let token = try await tokenProvider.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (url, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.downloadFailed
        }

        return url
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout
        request.cachePolicy = endpoint.cachePolicy

        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Custom headers
        endpoint.headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        // Body
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func executeWithRetry(
        _ request: URLRequest,
        endpoint: Endpoint,
        retryCount: Int = 0
    ) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            let shouldRetry = retryCount < 3 &&
                              (error as? URLError)?.code == .timedOut ||
                              (error as? URLError)?.code == .networkConnectionLost

            if shouldRetry {
                let delay = pow(2.0, Double(retryCount)) // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(request, endpoint: endpoint, retryCount: retryCount + 1)
            }

            throw APIError.networkError(error)
        }
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 422:
            let errors = try? decoder.decode(ValidationErrors.self, from: data)
            throw APIError.validationError(errors?.errors ?? [:])
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError(response.statusCode)
        default:
            throw APIError.httpError(response.statusCode)
        }
    }
}

// Wrapper for type erasure
struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        self.encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
```

### Interceptors

```swift
// RequestInterceptor.swift
protocol RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

// LoggingInterceptor.swift
final class LoggingInterceptor: RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        #if DEBUG
        print("────────────────────────────────────")
        print("➡️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")

        if let headers = request.allHTTPHeaderFields {
            print("Headers: \(headers)")
        }

        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
        print("────────────────────────────────────")
        #endif

        return request
    }
}

// AuthInterceptor.swift
final class AuthInterceptor: RequestInterceptor {
    private let tokenProvider: TokenProvider
    private let tokenRefresher: TokenRefresher

    init(tokenProvider: TokenProvider, tokenRefresher: TokenRefresher) {
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
    }

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        // Check if token is expired and refresh if needed
        if tokenProvider.isTokenExpired {
            try await tokenRefresher.refreshToken()
        }

        if let token = try await tokenProvider.getAccessToken() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return modifiedRequest
    }
}

// RetryInterceptor.swift
final class RetryInterceptor: RequestInterceptor {
    private let maxRetries: Int
    private let retryStatusCodes: Set<Int>

    init(maxRetries: Int = 3, retryStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]) {
        self.maxRetries = maxRetries
        self.retryStatusCodes = retryStatusCodes
    }

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        // Interceptor just marks the request as retryable
        // Actual retry logic is in APIClient
        return request
    }
}
```

### Error Handling

```swift
// APIError.swift
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case validationError([String: [String]])
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case decodingError(Error)
    case downloadFailed
    case noInternetConnection

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .forbidden:
            return "You don't have permission to access this resource"
        case .notFound:
            return "Resource not found"
        case .validationError(let errors):
            return errors.values.flatMap { $0 }.joined(separator: "\n")
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError:
            return "Server error. Please try again later."
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError:
            return "Failed to process server response"
        case .downloadFailed:
            return "Download failed"
        case .noInternetConnection:
            return "No internet connection"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited, .serverError:
            return true
        default:
            return false
        }
    }
}

// NetworkMonitor.swift
import Network

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    var isConnected: Bool = true
    var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
}
```

## Android API Client (Kotlin)

### Retrofit Setup

```kotlin
// ApiService.kt
interface ApiService {
    @GET("users/me")
    suspend fun getCurrentUser(): UserResponse

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    @POST("auth/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): AuthResponse

    @GET("products")
    suspend fun getProducts(
        @Query("page") page: Int,
        @Query("limit") limit: Int,
        @Query("category") category: String? = null
    ): PaginatedResponse<ProductResponse>

    @GET("products/{id}")
    suspend fun getProduct(@Path("id") id: String): ProductResponse

    @POST("orders")
    suspend fun createOrder(@Body request: CreateOrderRequest): OrderResponse

    @Multipart
    @POST("upload")
    suspend fun uploadImage(
        @Part image: MultipartBody.Part
    ): UploadResponse
}

// NetworkModule.kt
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        loggingInterceptor: HttpLoggingInterceptor,
        networkMonitor: NetworkMonitor
    ): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(ConnectivityInterceptor(networkMonitor))
            .addInterceptor(authInterceptor)
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .retryOnConnectionFailure(true)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(
        okHttpClient: OkHttpClient,
        json: Json
    ): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()
    }

    @Provides
    @Singleton
    fun provideApiService(retrofit: Retrofit): ApiService {
        return retrofit.create(ApiService::class.java)
    }

    @Provides
    @Singleton
    fun provideJson(): Json {
        return Json {
            ignoreUnknownKeys = true
            coerceInputValues = true
            encodeDefaults = true
            isLenient = true
        }
    }

    @Provides
    @Singleton
    fun provideLoggingInterceptor(): HttpLoggingInterceptor {
        return HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) {
                HttpLoggingInterceptor.Level.BODY
            } else {
                HttpLoggingInterceptor.Level.NONE
            }
        }
    }
}
```

### Interceptors

```kotlin
// AuthInterceptor.kt
class AuthInterceptor @Inject constructor(
    private val tokenManager: TokenManager
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()

        // Skip auth for public endpoints
        if (originalRequest.header("No-Auth") != null) {
            return chain.proceed(
                originalRequest.newBuilder()
                    .removeHeader("No-Auth")
                    .build()
            )
        }

        val token = runBlocking { tokenManager.getAccessToken() }
            ?: return chain.proceed(originalRequest)

        val authenticatedRequest = originalRequest.newBuilder()
            .header("Authorization", "Bearer $token")
            .build()

        val response = chain.proceed(authenticatedRequest)

        // Handle 401 - attempt token refresh
        if (response.code == 401) {
            response.close()

            val newToken = runBlocking {
                try {
                    tokenManager.refreshToken()
                    tokenManager.getAccessToken()
                } catch (e: Exception) {
                    tokenManager.clearTokens()
                    null
                }
            }

            return if (newToken != null) {
                val retryRequest = originalRequest.newBuilder()
                    .header("Authorization", "Bearer $newToken")
                    .build()
                chain.proceed(retryRequest)
            } else {
                response
            }
        }

        return response
    }
}

// ConnectivityInterceptor.kt
class ConnectivityInterceptor @Inject constructor(
    private val networkMonitor: NetworkMonitor
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        if (!networkMonitor.isConnected.value) {
            throw NoConnectivityException()
        }
        return chain.proceed(chain.request())
    }
}

class NoConnectivityException : IOException("No internet connection")

// RetryInterceptor.kt
class RetryInterceptor(
    private val maxRetries: Int = 3,
    private val initialDelayMs: Long = 1000
) : Interceptor {

    private val retryableStatusCodes = setOf(408, 429, 500, 502, 503, 504)

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        var response: Response? = null
        var exception: IOException? = null

        for (attempt in 0..maxRetries) {
            try {
                response?.close()
                response = chain.proceed(request)

                if (response.isSuccessful || !retryableStatusCodes.contains(response.code)) {
                    return response
                }

                if (attempt < maxRetries) {
                    response.close()
                    val delay = initialDelayMs * (1 shl attempt) // Exponential backoff
                    Thread.sleep(delay)
                }
            } catch (e: IOException) {
                exception = e
                if (attempt < maxRetries) {
                    val delay = initialDelayMs * (1 shl attempt)
                    Thread.sleep(delay)
                }
            }
        }

        return response ?: throw exception ?: IOException("Unknown error")
    }
}
```

### Error Handling

```kotlin
// ApiResult.kt
sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val error: ApiError) : ApiResult<Nothing>()

    inline fun <R> map(transform: (T) -> R): ApiResult<R> {
        return when (this) {
            is Success -> Success(transform(data))
            is Error -> this
        }
    }

    inline fun onSuccess(action: (T) -> Unit): ApiResult<T> {
        if (this is Success) action(data)
        return this
    }

    inline fun onError(action: (ApiError) -> Unit): ApiResult<T> {
        if (this is Error) action(error)
        return this
    }

    fun getOrNull(): T? = (this as? Success)?.data

    fun getOrThrow(): T = when (this) {
        is Success -> data
        is Error -> throw error.toException()
    }
}

// ApiError.kt
sealed class ApiError {
    data object NoConnection : ApiError()
    data object Timeout : ApiError()
    data object Unauthorized : ApiError()
    data object Forbidden : ApiError()
    data object NotFound : ApiError()
    data class Validation(val errors: Map<String, List<String>>) : ApiError()
    data object RateLimited : ApiError()
    data class Server(val code: Int) : ApiError()
    data class Unknown(val message: String?) : ApiError()

    fun toException(): Exception = when (this) {
        is NoConnection -> NoConnectivityException()
        is Timeout -> SocketTimeoutException("Request timed out")
        is Unauthorized -> UnauthorizedException()
        is Forbidden -> ForbiddenException()
        is NotFound -> NotFoundException()
        is Validation -> ValidationException(errors)
        is RateLimited -> RateLimitedException()
        is Server -> ServerException(code)
        is Unknown -> Exception(message ?: "Unknown error")
    }

    val userMessage: String
        get() = when (this) {
            is NoConnection -> "No internet connection. Please check your connection and try again."
            is Timeout -> "Request timed out. Please try again."
            is Unauthorized -> "Your session has expired. Please log in again."
            is Forbidden -> "You don't have permission to perform this action."
            is NotFound -> "The requested resource was not found."
            is Validation -> errors.values.flatten().joinToString("\n")
            is RateLimited -> "Too many requests. Please wait a moment and try again."
            is Server -> "Server error. Please try again later."
            is Unknown -> message ?: "An unexpected error occurred."
        }
}

// SafeApiCall.kt
suspend fun <T> safeApiCall(apiCall: suspend () -> T): ApiResult<T> {
    return try {
        ApiResult.Success(apiCall())
    } catch (e: NoConnectivityException) {
        ApiResult.Error(ApiError.NoConnection)
    } catch (e: SocketTimeoutException) {
        ApiResult.Error(ApiError.Timeout)
    } catch (e: HttpException) {
        val error = when (e.code()) {
            401 -> ApiError.Unauthorized
            403 -> ApiError.Forbidden
            404 -> ApiError.NotFound
            422 -> {
                val body = e.response()?.errorBody()?.string()
                val validationErrors = parseValidationErrors(body)
                ApiError.Validation(validationErrors)
            }
            429 -> ApiError.RateLimited
            in 500..599 -> ApiError.Server(e.code())
            else -> ApiError.Unknown(e.message())
        }
        ApiResult.Error(error)
    } catch (e: Exception) {
        ApiResult.Error(ApiError.Unknown(e.message))
    }
}

private fun parseValidationErrors(body: String?): Map<String, List<String>> {
    return try {
        body?.let {
            Json.decodeFromString<ValidationErrorResponse>(it).errors
        } ?: emptyMap()
    } catch (e: Exception) {
        emptyMap()
    }
}
```

## React Native API Client

### Axios Setup

```typescript
// apiClient.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosError } from 'axios';
import { tokenStorage } from '../storage/tokenStorage';
import { config } from '../../app/config';

class ApiClient {
  private client: AxiosInstance;
  private isRefreshing = false;
  private refreshSubscribers: ((token: string) => void)[] = [];

  constructor() {
    this.client = axios.create({
      baseURL: config.apiUrl,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor
    this.client.interceptors.request.use(
      async (config) => {
        const token = await tokenStorage.getAccessToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }

        if (__DEV__) {
          console.log(`[API] ${config.method?.toUpperCase()} ${config.url}`);
          if (config.data) {
            console.log('[API] Body:', config.data);
          }
        }

        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        if (__DEV__) {
          console.log(`[API] Response ${response.status}:`, response.data);
        }
        return response;
      },
      async (error: AxiosError) => {
        const originalRequest = error.config as AxiosRequestConfig & {
          _retry?: boolean;
        };

        // Handle 401 - Token refresh
        if (error.response?.status === 401 && !originalRequest._retry) {
          if (this.isRefreshing) {
            return new Promise((resolve) => {
              this.refreshSubscribers.push((token) => {
                originalRequest.headers = {
                  ...originalRequest.headers,
                  Authorization: `Bearer ${token}`,
                };
                resolve(this.client(originalRequest));
              });
            });
          }

          originalRequest._retry = true;
          this.isRefreshing = true;

          try {
            const newToken = await this.refreshToken();
            this.refreshSubscribers.forEach((callback) => callback(newToken));
            this.refreshSubscribers = [];

            originalRequest.headers = {
              ...originalRequest.headers,
              Authorization: `Bearer ${newToken}`,
            };
            return this.client(originalRequest);
          } catch (refreshError) {
            this.refreshSubscribers = [];
            await tokenStorage.clearTokens();
            // Emit logout event
            return Promise.reject(refreshError);
          } finally {
            this.isRefreshing = false;
          }
        }

        return Promise.reject(this.handleError(error));
      }
    );
  }

  private async refreshToken(): Promise<string> {
    const refreshToken = await tokenStorage.getRefreshToken();
    if (!refreshToken) {
      throw new Error('No refresh token');
    }

    const response = await axios.post(`${config.apiUrl}/auth/refresh`, {
      refreshToken,
    });

    const { accessToken, refreshToken: newRefreshToken } = response.data;
    await tokenStorage.setTokens(accessToken, newRefreshToken);

    return accessToken;
  }

  private handleError(error: AxiosError): ApiError {
    if (!error.response) {
      if (error.code === 'ECONNABORTED') {
        return new ApiError('timeout', 'Request timed out');
      }
      return new ApiError('network', 'No internet connection');
    }

    const { status, data } = error.response;

    switch (status) {
      case 400:
        return new ApiError('bad_request', 'Invalid request', data);
      case 401:
        return new ApiError('unauthorized', 'Session expired');
      case 403:
        return new ApiError('forbidden', 'Access denied');
      case 404:
        return new ApiError('not_found', 'Resource not found');
      case 422:
        return new ApiError(
          'validation',
          'Validation failed',
          (data as any)?.errors
        );
      case 429:
        return new ApiError('rate_limited', 'Too many requests');
      default:
        if (status >= 500) {
          return new ApiError('server', 'Server error');
        }
        return new ApiError('unknown', 'An error occurred');
    }
  }

  async get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.get<T>(url, config);
    return response.data;
  }

  async post<T>(
    url: string,
    data?: unknown,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response = await this.client.post<T>(url, data, config);
    return response.data;
  }

  async put<T>(
    url: string,
    data?: unknown,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response = await this.client.put<T>(url, data, config);
    return response.data;
  }

  async patch<T>(
    url: string,
    data?: unknown,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response = await this.client.patch<T>(url, data, config);
    return response.data;
  }

  async delete<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response = await this.client.delete<T>(url, config);
    return response.data;
  }

  async upload<T>(
    url: string,
    formData: FormData,
    onProgress?: (progress: number) => void
  ): Promise<T> {
    const response = await this.client.post<T>(url, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      onUploadProgress: (progressEvent) => {
        if (progressEvent.total && onProgress) {
          const progress = Math.round(
            (progressEvent.loaded * 100) / progressEvent.total
          );
          onProgress(progress);
        }
      },
    });
    return response.data;
  }
}

// ApiError.ts
export class ApiError extends Error {
  constructor(
    public code: string,
    message: string,
    public details?: Record<string, string[]>
  ) {
    super(message);
    this.name = 'ApiError';
  }

  get isRetryable(): boolean {
    return ['timeout', 'network', 'server'].includes(this.code);
  }

  get userMessage(): string {
    switch (this.code) {
      case 'network':
        return 'No internet connection. Please check your connection and try again.';
      case 'timeout':
        return 'Request timed out. Please try again.';
      case 'unauthorized':
        return 'Your session has expired. Please log in again.';
      case 'forbidden':
        return "You don't have permission to perform this action.";
      case 'not_found':
        return 'The requested resource was not found.';
      case 'validation':
        if (this.details) {
          return Object.values(this.details).flat().join('\n');
        }
        return 'Please check your input and try again.';
      case 'rate_limited':
        return 'Too many requests. Please wait a moment and try again.';
      case 'server':
        return 'Server error. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

export const apiClient = new ApiClient();
```

### React Query Integration

```typescript
// useApi.ts
import { useQuery, useMutation, UseQueryOptions, UseMutationOptions } from '@tanstack/react-query';
import { apiClient, ApiError } from '../services/api';

// Generic query hook
export function useApiQuery<T>(
  key: string[],
  fetcher: () => Promise<T>,
  options?: Omit<UseQueryOptions<T, ApiError>, 'queryKey' | 'queryFn'>
) {
  return useQuery<T, ApiError>({
    queryKey: key,
    queryFn: fetcher,
    retry: (failureCount, error) => {
      if (error.isRetryable && failureCount < 3) {
        return true;
      }
      return false;
    },
    ...options,
  });
}

// Generic mutation hook
export function useApiMutation<TData, TVariables>(
  mutationFn: (variables: TVariables) => Promise<TData>,
  options?: Omit<UseMutationOptions<TData, ApiError, TVariables>, 'mutationFn'>
) {
  return useMutation<TData, ApiError, TVariables>({
    mutationFn,
    ...options,
  });
}

// Example: Products hooks
export const useProducts = (categoryId?: string) => {
  return useApiQuery(
    ['products', categoryId ?? 'all'],
    () => apiClient.get<Product[]>(`/products${categoryId ? `?category=${categoryId}` : ''}`),
    {
      staleTime: 5 * 60 * 1000, // 5 minutes
    }
  );
};

export const useProduct = (productId: string) => {
  return useApiQuery(
    ['product', productId],
    () => apiClient.get<Product>(`/products/${productId}`),
    {
      enabled: !!productId,
    }
  );
};

export const useCreateOrder = () => {
  return useApiMutation(
    (orderData: CreateOrderInput) => apiClient.post<Order>('/orders', orderData),
    {
      onSuccess: () => {
        // Invalidate relevant queries
        queryClient.invalidateQueries({ queryKey: ['orders'] });
        queryClient.invalidateQueries({ queryKey: ['cart'] });
      },
    }
  );
};
```

## Flutter API Client (Dio)

### Dio Setup

```dart
// api_client.dart
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@singleton
class ApiClient {
  late final Dio _dio;
  final TokenStorage _tokenStorage;
  final NetworkInfo _networkInfo;

  ApiClient(this._tokenStorage, this._networkInfo) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.addAll([
      _ConnectivityInterceptor(_networkInfo),
      _AuthInterceptor(_tokenStorage, _dio),
      _RetryInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
    ]);
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _dio.put(path, data: data);
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> patch<T>(
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _dio.patch(path, data: data);
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> delete<T>(
    String path, {
    T Function(dynamic)? fromJson,
  }) async {
    final response = await _dio.delete(path);
    return fromJson != null ? fromJson(response.data) : response.data as T;
  }

  Future<T> upload<T>(
    String path,
    File file, {
    String? fileName,
    Map<String, dynamic>? extraData,
    void Function(int, int)? onProgress,
    T Function(dynamic)? fromJson,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName ?? file.path.split('/').last,
      ),
      ...?extraData,
    });

    final response = await _dio.post(
      path,
      data: formData,
      onSendProgress: onProgress,
    );

    return fromJson != null ? fromJson(response.data) : response.data as T;
  }
}

// Interceptors
class _AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final Dio _dio;
  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];

  _AuthInterceptor(this._tokenStorage, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      if (!_isRefreshing) {
        _isRefreshing = true;

        try {
          final newToken = await _refreshToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

          // Retry original request
          final response = await _dio.fetch(err.requestOptions);
          handler.resolve(response);

          // Retry pending requests
          for (final request in _pendingRequests) {
            request.headers['Authorization'] = 'Bearer $newToken';
            _dio.fetch(request);
          }
          _pendingRequests.clear();
        } catch (e) {
          await _tokenStorage.clearTokens();
          handler.reject(err);
        } finally {
          _isRefreshing = false;
        }
      } else {
        _pendingRequests.add(err.requestOptions);
      }
    } else {
      handler.next(err);
    }
  }

  Future<String> _refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token');

    final response = await Dio().post(
      '${AppConfig.baseUrl}/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final newAccessToken = response.data['accessToken'] as String;
    final newRefreshToken = response.data['refreshToken'] as String;

    await _tokenStorage.setTokens(newAccessToken, newRefreshToken);

    return newAccessToken;
  }
}

class _RetryInterceptor extends Interceptor {
  static const maxRetries = 3;
  static const retryStatusCodes = {408, 429, 500, 502, 503, 504};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;

    if (statusCode != null &&
        retryStatusCodes.contains(statusCode) &&
        retryCount < maxRetries) {
      final delay = Duration(milliseconds: 1000 * (1 << retryCount));
      await Future.delayed(delay);

      err.requestOptions.extra['retryCount'] = retryCount + 1;

      try {
        final response = await Dio().fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // Continue with original error handling
      }
    }

    handler.next(err);
  }
}
```

## Output Expectations

When implementing API integration, the subagent should:

1. Create type-safe API client with proper configuration
2. Implement request/response interceptors
3. Set up authentication token management
4. Configure automatic token refresh
5. Implement exponential backoff retry logic
6. Create comprehensive error handling
7. Map network errors to domain errors
8. Set up network connectivity monitoring
9. Configure request logging for debugging
10. Support file upload with progress tracking
