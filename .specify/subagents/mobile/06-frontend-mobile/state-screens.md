---
name: Mobile State Screens Implementation
platform: mobile
description: Implement comprehensive loading, empty, error, and offline state screens with proper UX patterns
model: opus
category: mobile/frontend
---

# Mobile State Screens Implementation

## Purpose

This subagent implements polished state screens for loading, empty, error, and offline states that provide clear feedback, guide users toward actions, and maintain engagement during edge cases. Covers skeleton loaders, shimmer effects, error recovery, and graceful degradation.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    State Screen System                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   State Orchestrator                         ││
│  │  • State detection    • Transition animations                ││
│  │  • Retry logic        • Fallback content                     ││
│  └───────────────────────────┬─────────────────────────────────┘│
│                              │                                   │
│  ┌───────────┬───────────────┼───────────────┬─────────────────┐│
│  ▼           ▼               ▼               ▼                 ▼│
│┌─────────┐┌─────────┐┌─────────────┐┌────────────┐┌────────────┐│
││ Loading ││ Shimmer ││   Empty     ││   Error    ││  Offline   ││
││ States  ││ Effects ││   States    ││   States   ││   State    ││
│└─────────┘└─────────┘└─────────────┘└────────────┘└────────────┘│
│     │          │            │              │             │       │
│     ▼          ▼            ▼              ▼             ▼       │
│┌─────────────────────────────────────────────────────────────┐  │
││                    UI Components                             │  │
││  • Progress indicators  • Skeleton views   • Action buttons │  │
││  • Lottie animations    • Illustrations    • Retry handlers │  │
│└─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Implementation (Swift/SwiftUI)

### State Definition

```swift
// Sources/Core/StateScreen/ViewState.swift
import Foundation

enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case empty(EmptyStateConfig)
    case error(ErrorStateConfig)
    case offline

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }
}

struct EmptyStateConfig {
    let illustration: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    static func noResults(searchQuery: String, onClear: @escaping () -> Void) -> EmptyStateConfig {
        EmptyStateConfig(
            illustration: "empty_search",
            title: "No Results Found",
            message: "We couldn't find anything matching \"\(searchQuery)\"",
            actionTitle: "Clear Search",
            action: onClear
        )
    }

    static func noData(title: String, message: String, onCreate: (() -> Void)? = nil) -> EmptyStateConfig {
        EmptyStateConfig(
            illustration: "empty_data",
            title: title,
            message: message,
            actionTitle: onCreate != nil ? "Create First" : nil,
            action: onCreate
        )
    }
}

struct ErrorStateConfig {
    let type: ErrorType
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    let secondaryAction: SecondaryAction?

    enum ErrorType {
        case network
        case server
        case authentication
        case notFound
        case generic

        var illustration: String {
            switch self {
            case .network: return "error_network"
            case .server: return "error_server"
            case .authentication: return "error_auth"
            case .notFound: return "error_404"
            case .generic: return "error_generic"
            }
        }
    }

    struct SecondaryAction {
        let title: String
        let action: () -> Void
    }

    static func network(onRetry: @escaping () -> Void) -> ErrorStateConfig {
        ErrorStateConfig(
            type: .network,
            title: "Connection Problem",
            message: "Please check your internet connection and try again",
            retryAction: onRetry,
            secondaryAction: nil
        )
    }

    static func server(onRetry: @escaping () -> Void) -> ErrorStateConfig {
        ErrorStateConfig(
            type: .server,
            title: "Something Went Wrong",
            message: "We're having trouble connecting to our servers. Please try again later.",
            retryAction: onRetry,
            secondaryAction: nil
        )
    }

    static func authentication(onLogin: @escaping () -> Void) -> ErrorStateConfig {
        ErrorStateConfig(
            type: .authentication,
            title: "Session Expired",
            message: "Please sign in again to continue",
            retryAction: nil,
            secondaryAction: SecondaryAction(title: "Sign In", action: onLogin)
        )
    }
}
```

### State Container View

```swift
// Sources/Core/StateScreen/StateContainerView.swift
import SwiftUI

struct StateContainerView<T, Content: View, LoadingView: View>: View {
    let state: ViewState<T>
    let loadingView: () -> LoadingView
    let content: (T) -> Content

    init(
        state: ViewState<T>,
        @ViewBuilder loadingView: @escaping () -> LoadingView = { DefaultLoadingView() },
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.state = state
        self.loadingView = loadingView
        self.content = content
    }

    var body: some View {
        ZStack {
            switch state {
            case .idle:
                Color.clear

            case .loading:
                loadingView()
                    .transition(.opacity)

            case .loaded(let data):
                content(data)
                    .transition(.opacity)

            case .empty(let config):
                EmptyStateView(config: config)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .error(let config):
                ErrorStateView(config: config)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .offline:
                OfflineStateView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3), value: stateIdentifier)
    }

    private var stateIdentifier: String {
        switch state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .empty: return "empty"
        case .error: return "error"
        case .offline: return "offline"
        }
    }
}

// Default loading view
struct DefaultLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Loading States

```swift
// Sources/Core/StateScreen/LoadingViews.swift
import SwiftUI

// Shimmer effect modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 3)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// Skeleton placeholder
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// Skeleton card
struct SkeletonCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image placeholder
            SkeletonView(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Title placeholder
            SkeletonView(width: 200, height: 20)

            // Description placeholders
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 14)
                SkeletonView(width: 250, height: 14)
            }

            // Footer placeholder
            HStack {
                SkeletonView(width: 80, height: 12)
                Spacer()
                SkeletonView(width: 60, height: 12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// Skeleton list
struct SkeletonListView: View {
    let itemCount: Int

    init(itemCount: Int = 5) {
        self.itemCount = itemCount
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    SkeletonListItemView()
                }
            }
            .padding(16)
        }
    }
}

struct SkeletonListItemView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            SkeletonView(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 150, height: 16)
                SkeletonView(width: 200, height: 12)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// Full screen loading with Lottie
struct FullScreenLoadingView: View {
    let message: String?

    init(message: String? = nil) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 24) {
            // Lottie animation
            LottieView(name: "loading_animation", loopMode: .loop)
                .frame(width: 150, height: 150)

            if let message {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// Pull to refresh loading
struct RefreshLoadingView: View {
    @Binding var isRefreshing: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                ProgressView()
                    .transition(.scale.combined(with: .opacity))
            }
            Text(isRefreshing ? "Refreshing..." : "Pull to refresh")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .animation(.spring(response: 0.3), value: isRefreshing)
    }
}
```

### Empty State Views

```swift
// Sources/Core/StateScreen/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    let config: EmptyStateConfig
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Illustration
            Image(config.illustration)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

            // Text content
            VStack(spacing: 12) {
                Text(config.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(config.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            // Action button
            if let actionTitle = config.actionTitle, let action = config.action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .frame(maxWidth: 200)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }

            Spacer()
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// Specific empty state variants
struct NoSearchResultsView: View {
    let searchQuery: String
    let onClear: () -> Void

    var body: some View {
        EmptyStateView(
            config: .noResults(searchQuery: searchQuery, onClear: onClear)
        )
    }
}

struct NoItemsView: View {
    let itemType: String
    let onCreate: (() -> Void)?

    var body: some View {
        EmptyStateView(
            config: .noData(
                title: "No \(itemType) Yet",
                message: "Create your first \(itemType.lowercased()) to get started",
                onCreate: onCreate
            )
        )
    }
}

// Animated empty state with Lottie
struct AnimatedEmptyStateView: View {
    let animationName: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            LottieView(name: animationName, loopMode: .loop)
                .frame(width: 250, height: 250)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .frame(maxWidth: 200)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
    }
}
```

### Error State Views

```swift
// Sources/Core/StateScreen/ErrorStateView.swift
import SwiftUI

struct ErrorStateView: View {
    let config: ErrorStateConfig
    @State private var appeared = false
    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Error illustration
            Image(config.type.illustration)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)

            // Error text
            VStack(spacing: 12) {
                Text(config.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(config.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            // Actions
            VStack(spacing: 12) {
                if let retryAction = config.retryAction {
                    Button(action: {
                        performRetry(retryAction)
                    }) {
                        HStack(spacing: 8) {
                            if isRetrying {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRetrying ? "Retrying..." : "Try Again")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .frame(maxWidth: 200)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .disabled(isRetrying)
                }

                if let secondary = config.secondaryAction {
                    Button(action: secondary.action) {
                        Text(secondary.title)
                            .font(.headline)
                            .foregroundStyle(.accentColor)
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private func performRetry(_ action: @escaping () -> Void) {
        isRetrying = true
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            action()
            isRetrying = false
        }
    }
}

// Network error view
struct NetworkErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        ErrorStateView(config: .network(onRetry: onRetry))
    }
}

// Server error view
struct ServerErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        ErrorStateView(config: .server(onRetry: onRetry))
    }
}

// Generic error view with custom message
struct GenericErrorView: View {
    let title: String
    let message: String
    let onRetry: (() -> Void)?

    var body: some View {
        ErrorStateView(
            config: ErrorStateConfig(
                type: .generic,
                title: title,
                message: message,
                retryAction: onRetry,
                secondaryAction: nil
            )
        )
    }
}
```

### Offline State View

```swift
// Sources/Core/StateScreen/OfflineStateView.swift
import SwiftUI
import Network

struct OfflineStateView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Offline illustration with animation
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 160, height: 160)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)

            VStack(spacing: 12) {
                Text("You're Offline")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Please check your internet connection.\nSome features may be limited.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            // Connection status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(networkMonitor.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)

                Text(networkMonitor.isConnected ? "Connected" : "No Connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// Network monitor
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// Offline banner
struct OfflineBanner: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var showBanner = false

    var body: some View {
        VStack {
            if showBanner {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .medium))

                    Text("No internet connection")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.orange)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            withAnimation(.spring(response: 0.3)) {
                showBanner = !isConnected
            }
        }
    }
}
```

## Android Implementation (Kotlin/Jetpack Compose)

### State Definition

```kotlin
// app/src/main/java/com/app/core/state/ViewState.kt
package com.app.core.state

sealed class ViewState<out T> {
    data object Idle : ViewState<Nothing>()
    data object Loading : ViewState<Nothing>()
    data class Loaded<T>(val data: T) : ViewState<T>()
    data class Empty(val config: EmptyStateConfig) : ViewState<Nothing>()
    data class Error(val config: ErrorStateConfig) : ViewState<Nothing>()
    data object Offline : ViewState<Nothing>()

    val isLoading: Boolean get() = this is Loading
    val dataOrNull: T? get() = (this as? Loaded)?.data
}

data class EmptyStateConfig(
    val illustration: Int,
    val title: String,
    val message: String,
    val actionTitle: String? = null,
    val action: (() -> Unit)? = null
) {
    companion object {
        fun noResults(searchQuery: String, onClear: () -> Unit) = EmptyStateConfig(
            illustration = R.drawable.empty_search,
            title = "No Results Found",
            message = "We couldn't find anything matching \"$searchQuery\"",
            actionTitle = "Clear Search",
            action = onClear
        )

        fun noData(title: String, message: String, onCreate: (() -> Unit)? = null) = EmptyStateConfig(
            illustration = R.drawable.empty_data,
            title = title,
            message = message,
            actionTitle = if (onCreate != null) "Create First" else null,
            action = onCreate
        )
    }
}

data class ErrorStateConfig(
    val type: ErrorType,
    val title: String,
    val message: String,
    val retryAction: (() -> Unit)? = null,
    val secondaryAction: SecondaryAction? = null
) {
    enum class ErrorType(val illustration: Int) {
        NETWORK(R.drawable.error_network),
        SERVER(R.drawable.error_server),
        AUTHENTICATION(R.drawable.error_auth),
        NOT_FOUND(R.drawable.error_404),
        GENERIC(R.drawable.error_generic)
    }

    data class SecondaryAction(
        val title: String,
        val action: () -> Unit
    )

    companion object {
        fun network(onRetry: () -> Unit) = ErrorStateConfig(
            type = ErrorType.NETWORK,
            title = "Connection Problem",
            message = "Please check your internet connection and try again",
            retryAction = onRetry
        )

        fun server(onRetry: () -> Unit) = ErrorStateConfig(
            type = ErrorType.SERVER,
            title = "Something Went Wrong",
            message = "We're having trouble connecting to our servers. Please try again later.",
            retryAction = onRetry
        )

        fun authentication(onLogin: () -> Unit) = ErrorStateConfig(
            type = ErrorType.AUTHENTICATION,
            title = "Session Expired",
            message = "Please sign in again to continue",
            secondaryAction = SecondaryAction("Sign In", onLogin)
        )
    }
}
```

### State Container

```kotlin
// app/src/main/java/com/app/core/state/StateContainer.kt
package com.app.core.state

import androidx.compose.animation.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
fun <T> StateContainer(
    state: ViewState<T>,
    modifier: Modifier = Modifier,
    loadingContent: @Composable () -> Unit = { DefaultLoadingView() },
    content: @Composable (T) -> Unit
) {
    AnimatedContent(
        targetState = state,
        modifier = modifier,
        transitionSpec = {
            fadeIn() + scaleIn(initialScale = 0.95f) togetherWith
                fadeOut() + scaleOut(targetScale = 0.95f)
        },
        label = "state_transition"
    ) { targetState ->
        when (targetState) {
            is ViewState.Idle -> {}
            is ViewState.Loading -> loadingContent()
            is ViewState.Loaded -> content(targetState.data)
            is ViewState.Empty -> EmptyStateView(config = targetState.config)
            is ViewState.Error -> ErrorStateView(config = targetState.config)
            is ViewState.Offline -> OfflineStateView()
        }
    }
}

@Composable
private fun DefaultLoadingView() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            CircularProgressIndicator()
            Text(
                text = "Loading...",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
```

### Shimmer and Skeleton

```kotlin
// app/src/main/java/com/app/core/state/ShimmerEffect.kt
package com.app.core.state

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun Modifier.shimmer(): Modifier {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim = transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmer_translate"
    )

    return this.background(
        brush = Brush.linearGradient(
            colors = listOf(
                Color.LightGray.copy(alpha = 0.6f),
                Color.LightGray.copy(alpha = 0.2f),
                Color.LightGray.copy(alpha = 0.6f)
            ),
            start = Offset(translateAnim.value - 500f, translateAnim.value - 500f),
            end = Offset(translateAnim.value, translateAnim.value)
        )
    )
}

@Composable
fun SkeletonView(
    modifier: Modifier = Modifier,
    width: Dp? = null,
    height: Dp = 16.dp
) {
    Box(
        modifier = modifier
            .then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth())
            .height(height)
            .clip(RoundedCornerShape(height / 4))
            .shimmer()
    )
}

@Composable
fun SkeletonCard(modifier: Modifier = Modifier) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Image placeholder
            SkeletonView(height = 150.dp)

            // Title placeholder
            SkeletonView(width = 200.dp, height = 20.dp)

            // Description placeholders
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                SkeletonView(height = 14.dp)
                SkeletonView(width = 250.dp, height = 14.dp)
            }

            // Footer placeholder
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                SkeletonView(width = 80.dp, height = 12.dp)
                SkeletonView(width = 60.dp, height = 12.dp)
            }
        }
    }
}

@Composable
fun SkeletonListItem(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar placeholder
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .shimmer()
        )

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SkeletonView(width = 150.dp, height = 16.dp)
            SkeletonView(width = 200.dp, height = 12.dp)
        }
    }
}

@Composable
fun SkeletonList(
    itemCount: Int = 5,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        items(itemCount) {
            SkeletonListItem()
        }
    }
}
```

### Empty State View

```kotlin
// app/src/main/java/com/app/core/state/EmptyStateView.kt
package com.app.core.state

import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun EmptyStateView(
    config: EmptyStateConfig,
    modifier: Modifier = Modifier
) {
    var appeared by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        appeared = true
    }

    val scale by animateFloatAsState(
        targetValue = if (appeared) 1f else 0.8f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "empty_scale"
    )

    val alpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(400),
        label = "empty_alpha"
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Illustration
        Image(
            painter = painterResource(id = config.illustration),
            contentDescription = null,
            modifier = Modifier
                .size(200.dp)
                .scale(scale)
                .alpha(alpha)
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Title
        Text(
            text = config.title,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.alpha(alpha)
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Message
        Text(
            text = config.message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(horizontal = 32.dp)
                .alpha(alpha)
        )

        // Action button
        config.actionTitle?.let { actionTitle ->
            Spacer(modifier = Modifier.height(24.dp))

            Button(
                onClick = { config.action?.invoke() },
                shape = RoundedCornerShape(25.dp),
                modifier = Modifier
                    .height(50.dp)
                    .widthIn(min = 200.dp)
                    .alpha(alpha)
            ) {
                Text(text = actionTitle)
            }
        }
    }
}

@Composable
fun NoSearchResultsView(
    searchQuery: String,
    onClear: () -> Unit,
    modifier: Modifier = Modifier
) {
    EmptyStateView(
        config = EmptyStateConfig.noResults(searchQuery, onClear),
        modifier = modifier
    )
}

@Composable
fun NoItemsView(
    itemType: String,
    onCreate: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    EmptyStateView(
        config = EmptyStateConfig.noData(
            title = "No $itemType Yet",
            message = "Create your first ${itemType.lowercase()} to get started",
            onCreate = onCreate
        ),
        modifier = modifier
    )
}
```

### Error State View

```kotlin
// app/src/main/java/com/app/core/state/ErrorStateView.kt
package com.app.core.state

import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay

@Composable
fun ErrorStateView(
    config: ErrorStateConfig,
    modifier: Modifier = Modifier
) {
    var appeared by remember { mutableStateOf(false) }
    var isRetrying by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        appeared = true
    }

    val scale by animateFloatAsState(
        targetValue = if (appeared) 1f else 0.8f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "error_scale"
    )

    val alpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(400),
        label = "error_alpha"
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Error illustration
        Image(
            painter = painterResource(id = config.type.illustration),
            contentDescription = null,
            modifier = Modifier
                .size(180.dp)
                .scale(scale)
                .alpha(alpha)
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Title
        Text(
            text = config.title,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.alpha(alpha)
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Message
        Text(
            text = config.message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(horizontal = 32.dp)
                .alpha(alpha)
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Retry button
        config.retryAction?.let { retryAction ->
            Button(
                onClick = {
                    isRetrying = true
                    retryAction()
                },
                enabled = !isRetrying,
                shape = RoundedCornerShape(25.dp),
                modifier = Modifier
                    .height(50.dp)
                    .widthIn(min = 200.dp)
                    .alpha(alpha)
            ) {
                if (isRetrying) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Retrying...")
                } else {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Try Again")
                }
            }
        }

        // Secondary action
        config.secondaryAction?.let { secondary ->
            Spacer(modifier = Modifier.height(12.dp))

            TextButton(
                onClick = secondary.action,
                modifier = Modifier.alpha(alpha)
            ) {
                Text(text = secondary.title)
            }
        }
    }

    // Reset retry state after delay
    LaunchedEffect(isRetrying) {
        if (isRetrying) {
            delay(500)
            isRetrying = false
        }
    }
}

@Composable
fun NetworkErrorView(
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    ErrorStateView(
        config = ErrorStateConfig.network(onRetry),
        modifier = modifier
    )
}

@Composable
fun ServerErrorView(
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    ErrorStateView(
        config = ErrorStateConfig.server(onRetry),
        modifier = modifier
    )
}
```

### Offline State View

```kotlin
// app/src/main/java/com/app/core/state/OfflineStateView.kt
package com.app.core.state

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

@Composable
fun OfflineStateView(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val isConnected by rememberNetworkState()
    var appeared by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        appeared = true
    }

    val scale by animateFloatAsState(
        targetValue = if (appeared) 1f else 0.8f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "offline_scale"
    )

    val alpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(400),
        label = "offline_alpha"
    )

    // Pulsing animation for icon background
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse_scale"
    )

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Offline icon with pulse effect
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .scale(scale)
                .alpha(alpha)
        ) {
            Box(
                modifier = Modifier
                    .size(160.dp)
                    .scale(pulseScale)
                    .background(
                        color = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f),
                        shape = CircleShape
                    )
            )

            Icon(
                imageVector = Icons.Default.WifiOff,
                contentDescription = null,
                modifier = Modifier.size(60.dp),
                tint = MaterialTheme.colorScheme.error
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Title
        Text(
            text = "You're Offline",
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.alpha(alpha)
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Message
        Text(
            text = "Please check your internet connection.\nSome features may be limited.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.alpha(alpha)
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Connection status indicator
        val statusColor by animateColorAsState(
            targetValue = if (isConnected) Color.Green else Color.Red,
            label = "status_color"
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .background(
                    MaterialTheme.colorScheme.surfaceVariant,
                    RoundedCornerShape(16.dp)
                )
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .alpha(alpha)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(statusColor, CircleShape)
            )
            Text(
                text = if (isConnected) "Connected" else "No Connection",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun rememberNetworkState(): State<Boolean> {
    val context = LocalContext.current
    val connectivityManager = remember {
        context.getSystemService(ConnectivityManager::class.java)
    }

    val networkState = remember { mutableStateOf(true) }

    DisposableEffect(connectivityManager) {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                networkState.value = true
            }

            override fun onLost(network: Network) {
                networkState.value = false
            }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        connectivityManager.registerNetworkCallback(request, callback)

        onDispose {
            connectivityManager.unregisterNetworkCallback(callback)
        }
    }

    return networkState
}

// Offline banner composable
@Composable
fun OfflineBanner(modifier: Modifier = Modifier) {
    val isConnected by rememberNetworkState()

    AnimatedVisibility(
        visible = !isConnected,
        enter = slideInVertically() + fadeIn(),
        exit = slideOutVertically() + fadeOut(),
        modifier = modifier
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.error)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.WifiOff,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onError,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = "No internet connection",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onError
            )
        }
    }
}
```

## React Native Implementation

### State Types

```typescript
// src/core/state/ViewState.ts
export type ViewState<T> =
  | { type: 'idle' }
  | { type: 'loading' }
  | { type: 'loaded'; data: T }
  | { type: 'empty'; config: EmptyStateConfig }
  | { type: 'error'; config: ErrorStateConfig }
  | { type: 'offline' };

export interface EmptyStateConfig {
  illustration: string;
  title: string;
  message: string;
  actionTitle?: string;
  action?: () => void;
}

export interface ErrorStateConfig {
  type: ErrorType;
  title: string;
  message: string;
  retryAction?: () => void;
  secondaryAction?: {
    title: string;
    action: () => void;
  };
}

export type ErrorType = 'network' | 'server' | 'authentication' | 'notFound' | 'generic';

export const EmptyStateConfigs = {
  noResults: (searchQuery: string, onClear: () => void): EmptyStateConfig => ({
    illustration: 'empty_search',
    title: 'No Results Found',
    message: `We couldn't find anything matching "${searchQuery}"`,
    actionTitle: 'Clear Search',
    action: onClear,
  }),

  noData: (title: string, message: string, onCreate?: () => void): EmptyStateConfig => ({
    illustration: 'empty_data',
    title,
    message,
    actionTitle: onCreate ? 'Create First' : undefined,
    action: onCreate,
  }),
};

export const ErrorStateConfigs = {
  network: (onRetry: () => void): ErrorStateConfig => ({
    type: 'network',
    title: 'Connection Problem',
    message: 'Please check your internet connection and try again',
    retryAction: onRetry,
  }),

  server: (onRetry: () => void): ErrorStateConfig => ({
    type: 'server',
    title: 'Something Went Wrong',
    message: "We're having trouble connecting to our servers. Please try again later.",
    retryAction: onRetry,
  }),

  authentication: (onLogin: () => void): ErrorStateConfig => ({
    type: 'authentication',
    title: 'Session Expired',
    message: 'Please sign in again to continue',
    secondaryAction: { title: 'Sign In', action: onLogin },
  }),
};

// Helper functions
export const isLoading = <T>(state: ViewState<T>): boolean => state.type === 'loading';
export const getData = <T>(state: ViewState<T>): T | undefined =>
  state.type === 'loaded' ? state.data : undefined;
```

### State Container

```typescript
// src/core/state/StateContainer.tsx
import React from 'react';
import { StyleSheet } from 'react-native';
import Animated, { FadeIn, FadeOut, Layout } from 'react-native-reanimated';
import { ViewState } from './ViewState';
import { LoadingView } from './LoadingView';
import { EmptyStateView } from './EmptyStateView';
import { ErrorStateView } from './ErrorStateView';
import { OfflineStateView } from './OfflineStateView';

interface StateContainerProps<T> {
  state: ViewState<T>;
  loadingComponent?: React.ReactNode;
  children: (data: T) => React.ReactNode;
}

export function StateContainer<T>({
  state,
  loadingComponent,
  children,
}: StateContainerProps<T>) {
  const renderContent = () => {
    switch (state.type) {
      case 'idle':
        return null;

      case 'loading':
        return loadingComponent || <LoadingView />;

      case 'loaded':
        return children(state.data);

      case 'empty':
        return <EmptyStateView config={state.config} />;

      case 'error':
        return <ErrorStateView config={state.config} />;

      case 'offline':
        return <OfflineStateView />;
    }
  };

  return (
    <Animated.View
      style={styles.container}
      entering={FadeIn.duration(300)}
      exiting={FadeOut.duration(200)}
      layout={Layout.springify()}
    >
      {renderContent()}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
```

### Shimmer and Skeleton

```typescript
// src/core/state/Shimmer.tsx
import React, { useEffect } from 'react';
import { StyleSheet, View, ViewStyle } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import LinearGradient from 'react-native-linear-gradient';

interface ShimmerProps {
  width?: number | string;
  height?: number;
  borderRadius?: number;
  style?: ViewStyle;
}

export const Shimmer: React.FC<ShimmerProps> = ({
  width = '100%',
  height = 16,
  borderRadius = 4,
  style,
}) => {
  const translateX = useSharedValue(-1);

  useEffect(() => {
    translateX.value = withRepeat(
      withTiming(1, { duration: 1500 }),
      -1,
      false
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      {
        translateX: interpolate(
          translateX.value,
          [-1, 1],
          [-200, 200]
        ),
      },
    ],
  }));

  return (
    <View
      style={[
        styles.shimmerContainer,
        { width, height, borderRadius },
        style,
      ]}
    >
      <Animated.View style={[styles.shimmerOverlay, animatedStyle]}>
        <LinearGradient
          colors={['transparent', 'rgba(255,255,255,0.4)', 'transparent']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
          style={StyleSheet.absoluteFill}
        />
      </Animated.View>
    </View>
  );
};

// Skeleton components
export const SkeletonCard: React.FC = () => (
  <View style={styles.skeletonCard}>
    <Shimmer height={150} borderRadius={12} />
    <View style={styles.skeletonCardContent}>
      <Shimmer width={200} height={20} />
      <View style={styles.skeletonCardLines}>
        <Shimmer height={14} />
        <Shimmer width={250} height={14} />
      </View>
      <View style={styles.skeletonCardFooter}>
        <Shimmer width={80} height={12} />
        <Shimmer width={60} height={12} />
      </View>
    </View>
  </View>
);

export const SkeletonListItem: React.FC = () => (
  <View style={styles.skeletonListItem}>
    <Shimmer width={48} height={48} borderRadius={24} />
    <View style={styles.skeletonListItemContent}>
      <Shimmer width={150} height={16} />
      <Shimmer width={200} height={12} />
    </View>
  </View>
);

export const SkeletonList: React.FC<{ itemCount?: number }> = ({
  itemCount = 5,
}) => (
  <View style={styles.skeletonList}>
    {Array.from({ length: itemCount }).map((_, index) => (
      <SkeletonListItem key={index} />
    ))}
  </View>
);

const styles = StyleSheet.create({
  shimmerContainer: {
    backgroundColor: '#E0E0E0',
    overflow: 'hidden',
  },
  shimmerOverlay: {
    ...StyleSheet.absoluteFillObject,
    width: 200,
  },
  skeletonCard: {
    backgroundColor: '#fff',
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
    overflow: 'hidden',
  },
  skeletonCardContent: {
    padding: 16,
    gap: 12,
  },
  skeletonCardLines: {
    gap: 8,
  },
  skeletonCardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  skeletonListItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingVertical: 8,
  },
  skeletonListItemContent: {
    flex: 1,
    gap: 8,
  },
  skeletonList: {
    padding: 16,
    gap: 16,
  },
});
```

### Empty State View

```typescript
// src/core/state/EmptyStateView.tsx
import React, { useEffect } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, Image } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withDelay,
} from 'react-native-reanimated';
import { EmptyStateConfig } from './ViewState';

const ILLUSTRATIONS: Record<string, any> = {
  empty_search: require('@/assets/illustrations/empty_search.png'),
  empty_data: require('@/assets/illustrations/empty_data.png'),
};

interface EmptyStateViewProps {
  config: EmptyStateConfig;
}

export const EmptyStateView: React.FC<EmptyStateViewProps> = ({ config }) => {
  const scale = useSharedValue(0.8);
  const opacity = useSharedValue(0);
  const translateY = useSharedValue(20);

  useEffect(() => {
    scale.value = withSpring(1, { damping: 12, stiffness: 100 });
    opacity.value = withSpring(1);
    translateY.value = withDelay(200, withSpring(0));
  }, []);

  const imageStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  const textStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));

  return (
    <View style={styles.container}>
      <Animated.View style={imageStyle}>
        <Image
          source={ILLUSTRATIONS[config.illustration]}
          style={styles.illustration}
          resizeMode="contain"
        />
      </Animated.View>

      <Animated.View style={[styles.textContainer, textStyle]}>
        <Text style={styles.title}>{config.title}</Text>
        <Text style={styles.message}>{config.message}</Text>
      </Animated.View>

      {config.actionTitle && config.action && (
        <Animated.View style={textStyle}>
          <TouchableOpacity style={styles.button} onPress={config.action}>
            <Text style={styles.buttonText}>{config.actionTitle}</Text>
          </TouchableOpacity>
        </Animated.View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  illustration: {
    width: 200,
    height: 200,
  },
  textContainer: {
    alignItems: 'center',
    marginTop: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#1a1a1a',
    textAlign: 'center',
  },
  message: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginTop: 12,
    paddingHorizontal: 32,
    lineHeight: 24,
  },
  button: {
    marginTop: 24,
    backgroundColor: '#007AFF',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 25,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

### Error State View

```typescript
// src/core/state/ErrorStateView.tsx
import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  Image,
  ActivityIndicator,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import { ErrorStateConfig, ErrorType } from './ViewState';

const ERROR_ILLUSTRATIONS: Record<ErrorType, any> = {
  network: require('@/assets/illustrations/error_network.png'),
  server: require('@/assets/illustrations/error_server.png'),
  authentication: require('@/assets/illustrations/error_auth.png'),
  notFound: require('@/assets/illustrations/error_404.png'),
  generic: require('@/assets/illustrations/error_generic.png'),
};

interface ErrorStateViewProps {
  config: ErrorStateConfig;
}

export const ErrorStateView: React.FC<ErrorStateViewProps> = ({ config }) => {
  const [isRetrying, setIsRetrying] = useState(false);
  const scale = useSharedValue(0.8);
  const opacity = useSharedValue(0);

  useEffect(() => {
    scale.value = withSpring(1, { damping: 12, stiffness: 100 });
    opacity.value = withSpring(1);
  }, []);

  const handleRetry = async () => {
    if (!config.retryAction) return;

    setIsRetrying(true);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    // Simulated delay for UX
    await new Promise((resolve) => setTimeout(resolve, 500));
    config.retryAction();
    setIsRetrying(false);
  };

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  return (
    <View style={styles.container}>
      <Animated.View style={animatedStyle}>
        <Image
          source={ERROR_ILLUSTRATIONS[config.type]}
          style={styles.illustration}
          resizeMode="contain"
        />
      </Animated.View>

      <Animated.View style={[styles.textContainer, animatedStyle]}>
        <Text style={styles.title}>{config.title}</Text>
        <Text style={styles.message}>{config.message}</Text>
      </Animated.View>

      <View style={styles.actionsContainer}>
        {config.retryAction && (
          <TouchableOpacity
            style={[styles.primaryButton, isRetrying && styles.buttonDisabled]}
            onPress={handleRetry}
            disabled={isRetrying}
          >
            {isRetrying ? (
              <>
                <ActivityIndicator size="small" color="#fff" />
                <Text style={styles.primaryButtonText}>Retrying...</Text>
              </>
            ) : (
              <Text style={styles.primaryButtonText}>Try Again</Text>
            )}
          </TouchableOpacity>
        )}

        {config.secondaryAction && (
          <TouchableOpacity
            style={styles.secondaryButton}
            onPress={config.secondaryAction.action}
          >
            <Text style={styles.secondaryButtonText}>
              {config.secondaryAction.title}
            </Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  illustration: {
    width: 180,
    height: 180,
  },
  textContainer: {
    alignItems: 'center',
    marginTop: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#1a1a1a',
    textAlign: 'center',
  },
  message: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginTop: 12,
    paddingHorizontal: 32,
    lineHeight: 24,
  },
  actionsContainer: {
    marginTop: 24,
    alignItems: 'center',
    gap: 12,
  },
  primaryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#007AFF',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 25,
    minWidth: 200,
    justifyContent: 'center',
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  secondaryButton: {
    padding: 12,
  },
  secondaryButtonText: {
    color: '#007AFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

### Offline State View

```typescript
// src/core/state/OfflineStateView.tsx
import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { useNetInfo } from '@react-native-community/netinfo';
import Icon from 'react-native-vector-icons/MaterialIcons';

export const OfflineStateView: React.FC = () => {
  const netInfo = useNetInfo();
  const scale = useSharedValue(0.8);
  const opacity = useSharedValue(0);
  const pulseScale = useSharedValue(1);

  useEffect(() => {
    scale.value = withSpring(1, { damping: 12, stiffness: 100 });
    opacity.value = withSpring(1);
    pulseScale.value = withRepeat(
      withTiming(1.2, { duration: 1000 }),
      -1,
      true
    );
  }, []);

  const containerStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  const pulseStyle = useAnimatedStyle(() => ({
    transform: [{ scale: pulseScale.value }],
    opacity: 2 - pulseScale.value,
  }));

  const isConnected = netInfo.isConnected ?? false;

  return (
    <View style={styles.container}>
      <Animated.View style={containerStyle}>
        <View style={styles.iconContainer}>
          <Animated.View style={[styles.pulseCircle, pulseStyle]} />
          <View style={styles.iconBackground}>
            <Icon name="wifi-off" size={60} color="#FF9500" />
          </View>
        </View>
      </Animated.View>

      <Animated.View style={[styles.textContainer, containerStyle]}>
        <Text style={styles.title}>You're Offline</Text>
        <Text style={styles.message}>
          Please check your internet connection.{'\n'}
          Some features may be limited.
        </Text>
      </Animated.View>

      <Animated.View style={[styles.statusContainer, containerStyle]}>
        <View
          style={[
            styles.statusDot,
            { backgroundColor: isConnected ? '#34C759' : '#FF3B30' },
          ]}
        />
        <Text style={styles.statusText}>
          {isConnected ? 'Connected' : 'No Connection'}
        </Text>
      </Animated.View>
    </View>
  );
};

// Offline Banner component
export const OfflineBanner: React.FC = () => {
  const netInfo = useNetInfo();
  const translateY = useSharedValue(-50);

  useEffect(() => {
    translateY.value = withSpring(netInfo.isConnected ? -50 : 0);
  }, [netInfo.isConnected]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
  }));

  return (
    <Animated.View style={[styles.banner, animatedStyle]}>
      <Icon name="wifi-off" size={18} color="#fff" />
      <Text style={styles.bannerText}>No internet connection</Text>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  iconContainer: {
    width: 160,
    height: 160,
    justifyContent: 'center',
    alignItems: 'center',
  },
  pulseCircle: {
    position: 'absolute',
    width: 160,
    height: 160,
    borderRadius: 80,
    backgroundColor: 'rgba(255, 149, 0, 0.1)',
  },
  iconBackground: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: 'rgba(255, 149, 0, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  textContainer: {
    alignItems: 'center',
    marginTop: 24,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#1a1a1a',
  },
  message: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginTop: 12,
    lineHeight: 24,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 24,
    backgroundColor: '#f5f5f5',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 16,
    gap: 8,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statusText: {
    fontSize: 14,
    color: '#666',
  },
  banner: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    backgroundColor: '#FF9500',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    gap: 8,
  },
  bannerText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
});
```

## Flutter Implementation

### State Definition

```dart
// lib/core/state/view_state.dart
import 'package:flutter/material.dart';

sealed class ViewState<T> {
  const ViewState();

  bool get isLoading => this is LoadingState;
  T? get dataOrNull => this is LoadedState<T> ? (this as LoadedState<T>).data : null;
}

class IdleState<T> extends ViewState<T> {
  const IdleState();
}

class LoadingState<T> extends ViewState<T> {
  const LoadingState();
}

class LoadedState<T> extends ViewState<T> {
  final T data;
  const LoadedState(this.data);
}

class EmptyState<T> extends ViewState<T> {
  final EmptyStateConfig config;
  const EmptyState(this.config);
}

class ErrorState<T> extends ViewState<T> {
  final ErrorStateConfig config;
  const ErrorState(this.config);
}

class OfflineState<T> extends ViewState<T> {
  const OfflineState();
}

class EmptyStateConfig {
  final String illustration;
  final String title;
  final String message;
  final String? actionTitle;
  final VoidCallback? action;

  const EmptyStateConfig({
    required this.illustration,
    required this.title,
    required this.message,
    this.actionTitle,
    this.action,
  });

  factory EmptyStateConfig.noResults(String searchQuery, VoidCallback onClear) {
    return EmptyStateConfig(
      illustration: 'assets/illustrations/empty_search.svg',
      title: 'No Results Found',
      message: 'We couldn\'t find anything matching "$searchQuery"',
      actionTitle: 'Clear Search',
      action: onClear,
    );
  }

  factory EmptyStateConfig.noData(String title, String message, [VoidCallback? onCreate]) {
    return EmptyStateConfig(
      illustration: 'assets/illustrations/empty_data.svg',
      title: title,
      message: message,
      actionTitle: onCreate != null ? 'Create First' : null,
      action: onCreate,
    );
  }
}

enum ErrorType {
  network('assets/illustrations/error_network.svg'),
  server('assets/illustrations/error_server.svg'),
  authentication('assets/illustrations/error_auth.svg'),
  notFound('assets/illustrations/error_404.svg'),
  generic('assets/illustrations/error_generic.svg');

  final String illustration;
  const ErrorType(this.illustration);
}

class ErrorStateConfig {
  final ErrorType type;
  final String title;
  final String message;
  final VoidCallback? retryAction;
  final SecondaryAction? secondaryAction;

  const ErrorStateConfig({
    required this.type,
    required this.title,
    required this.message,
    this.retryAction,
    this.secondaryAction,
  });

  factory ErrorStateConfig.network(VoidCallback onRetry) {
    return ErrorStateConfig(
      type: ErrorType.network,
      title: 'Connection Problem',
      message: 'Please check your internet connection and try again',
      retryAction: onRetry,
    );
  }

  factory ErrorStateConfig.server(VoidCallback onRetry) {
    return ErrorStateConfig(
      type: ErrorType.server,
      title: 'Something Went Wrong',
      message: 'We\'re having trouble connecting to our servers. Please try again later.',
      retryAction: onRetry,
    );
  }

  factory ErrorStateConfig.authentication(VoidCallback onLogin) {
    return ErrorStateConfig(
      type: ErrorType.authentication,
      title: 'Session Expired',
      message: 'Please sign in again to continue',
      secondaryAction: SecondaryAction('Sign In', onLogin),
    );
  }
}

class SecondaryAction {
  final String title;
  final VoidCallback action;

  const SecondaryAction(this.title, this.action);
}
```

### State Container Widget

```dart
// lib/core/state/state_container.dart
import 'package:flutter/material.dart';
import 'view_state.dart';
import 'loading_view.dart';
import 'empty_state_view.dart';
import 'error_state_view.dart';
import 'offline_state_view.dart';

class StateContainer<T> extends StatelessWidget {
  final ViewState<T> state;
  final Widget Function()? loadingBuilder;
  final Widget Function(T data) builder;

  const StateContainer({
    super.key,
    required this.state,
    this.loadingBuilder,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return switch (state) {
      IdleState() => const SizedBox.shrink(key: ValueKey('idle')),
      LoadingState() => KeyedSubtree(
          key: const ValueKey('loading'),
          child: loadingBuilder?.call() ?? const DefaultLoadingView(),
        ),
      LoadedState<T>(data: final data) => KeyedSubtree(
          key: const ValueKey('loaded'),
          child: builder(data),
        ),
      EmptyState(config: final config) => KeyedSubtree(
          key: const ValueKey('empty'),
          child: EmptyStateView(config: config),
        ),
      ErrorState(config: final config) => KeyedSubtree(
          key: const ValueKey('error'),
          child: ErrorStateView(config: config),
        ),
      OfflineState() => const KeyedSubtree(
          key: ValueKey('offline'),
          child: OfflineStateView(),
        ),
    };
  }
}
```

### Shimmer and Skeleton

```dart
// lib/core/state/shimmer.dart
import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonView extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonView({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonView(height: 150, borderRadius: 12),
            const SizedBox(height: 12),
            const SkeletonView(width: 200, height: 20),
            const SizedBox(height: 12),
            const SkeletonView(height: 14),
            const SizedBox(height: 8),
            const SkeletonView(width: 250, height: 14),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonView(width: 80, height: 12),
                SkeletonView(width: 60, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SkeletonView(width: 48, height: 48, borderRadius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonView(width: 150, height: 16),
                SizedBox(height: 8),
                SkeletonView(width: 200, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;

  const SkeletonList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonListItem(),
    );
  }
}
```

### Empty, Error, and Offline Views

```dart
// lib/core/state/empty_state_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'view_state.dart';

class EmptyStateView extends StatefulWidget {
  final EmptyStateConfig config;

  const EmptyStateView({super.key, required this.config});

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SvgPicture.asset(
                  widget.config.illustration,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Text content
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      widget.config.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.config.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Action button
            if (widget.config.actionTitle != null) ...[
              const SizedBox(height: 24),
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ElevatedButton(
                    onPressed: widget.config.action,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(widget.config.actionTitle!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// lib/core/state/error_state_view.dart
class ErrorStateView extends StatefulWidget {
  final ErrorStateConfig config;

  const ErrorStateView({super.key, required this.config});

  @override
  State<ErrorStateView> createState() => _ErrorStateViewState();
}

class _ErrorStateViewState extends State<ErrorStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (widget.config.retryAction == null) return;

    setState(() => _isRetrying = true);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.config.retryAction!();
    if (mounted) {
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              widget.config.type.illustration,
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 24),
            Text(
              widget.config.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.config.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.config.retryAction != null)
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _handleRetry,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isRetrying ? 'Retrying...' : 'Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            if (widget.config.secondaryAction != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.config.secondaryAction!.action,
                child: Text(widget.config.secondaryAction!.title),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// lib/core/state/offline_state_view.dart
class OfflineStateView extends StatefulWidget {
  const OfflineStateView({super.key});

  @override
  State<OfflineStateView> createState() => _OfflineStateViewState();
}

class _OfflineStateViewState extends State<OfflineStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1 + _pulseController.value * 0.2,
                      child: Opacity(
                        opacity: 1 - _pulseController.value * 0.5,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 60,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'You\'re Offline',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please check your internet connection.\nSome features may be limited.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

## Output Expectations

When this subagent completes execution, expect:

1. **State Type System**: Comprehensive sealed types/enums for idle, loading, loaded, empty, error, and offline states
2. **State Container**: Generic container widget that renders appropriate UI for each state
3. **Loading States**: Default loading views, skeleton screens, shimmer effects, and pull-to-refresh indicators
4. **Empty State Screens**: Illustrated empty states with configurable titles, messages, and action buttons
5. **Error State Screens**: Error-specific illustrations with retry logic and secondary actions
6. **Offline State Screens**: Network monitoring with connection status indicators
7. **Offline Banner**: Non-intrusive banner that appears when connectivity is lost
8. **Smooth Transitions**: Animated state transitions with spring physics
9. **Haptic Feedback**: Tactile feedback on retry actions
10. **Accessibility**: Screen reader support and accessible touch targets
