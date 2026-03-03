---
name: Mobile Animations & Transitions
platform: mobile
description: Implement smooth animations, transitions, and micro-interactions for engaging mobile UX
model: opus
category: mobile/frontend
---

# Mobile Animations & Transitions

## Purpose

This subagent implements fluid animations, screen transitions, and micro-interactions that enhance user experience while maintaining performance. Covers gesture-driven animations, shared element transitions, and physics-based motion.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Animation System                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Timing    │  │   Spring    │  │    Gesture-Driven       │ │
│  │  Animations │  │   Physics   │  │      Animations         │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                      │               │
│         ▼                ▼                      ▼               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Animation Controller Layer                     ││
│  │  • Value interpolation    • Gesture velocity tracking       ││
│  │  • Keyframe management    • Interruptible transitions       ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│         ┌────────────────────┼────────────────────┐             │
│         ▼                    ▼                    ▼             │
│  ┌────────────┐      ┌────────────┐      ┌────────────────┐    │
│  │   View     │      │  Shared    │      │     Hero       │    │
│  │ Animations │      │  Element   │      │  Transitions   │    │
│  └────────────┘      └────────────┘      └────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## iOS Implementation (Swift/SwiftUI)

### Animation Utilities

```swift
// Sources/Core/Animation/AnimationConfig.swift
import SwiftUI

enum AnimationConfig {
    // Standard timing curves
    static let quick = Animation.easeOut(duration: 0.2)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 0.5)

    // Spring animations
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.9)

    // Interactive spring for gesture-driven animations
    static let interactive = Animation.interactiveSpring(
        response: 0.3,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
}

// Custom timing curves
extension Animation {
    static func customCurve(
        controlPoint1: UnitPoint = UnitPoint(x: 0.4, y: 0),
        controlPoint2: UnitPoint = UnitPoint(x: 0.2, y: 1),
        duration: Double = 0.3
    ) -> Animation {
        .timingCurve(
            controlPoint1.x, controlPoint1.y,
            controlPoint2.x, controlPoint2.y,
            duration: duration
        )
    }

    // Material Design curves
    static let emphasized = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.5)
    static let emphasizedDecelerate = Animation.timingCurve(0.05, 0.7, 0.1, 1, duration: 0.4)
    static let emphasizedAccelerate = Animation.timingCurve(0.3, 0, 0.8, 0.15, duration: 0.2)
}
```

### View Transition Modifiers

```swift
// Sources/Core/Animation/ViewTransitions.swift
import SwiftUI

// Custom transition modifier
struct SlideAndFadeTransition: ViewModifier {
    let isActive: Bool
    let edge: Edge

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(
                x: isActive ? 0 : (edge == .leading ? -50 : edge == .trailing ? 50 : 0),
                y: isActive ? 0 : (edge == .top ? -50 : edge == .bottom ? 50 : 0)
            )
    }
}

extension View {
    func slideAndFade(isActive: Bool, edge: Edge = .bottom) -> some View {
        modifier(SlideAndFadeTransition(isActive: isActive, edge: edge))
    }
}

// Staggered animation helper
struct StaggeredAnimation<Content: View>: View {
    let items: Int
    let delay: Double
    let animation: Animation
    @ViewBuilder let content: (Int) -> Content

    @State private var appeared = false

    var body: some View {
        ForEach(0..<items, id: \.self) { index in
            content(index)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(
                    animation.delay(Double(index) * delay),
                    value: appeared
                )
        }
        .onAppear {
            appeared = true
        }
    }
}

// Scale transition with anchor
extension AnyTransition {
    static func scaleFromPoint(_ anchor: UnitPoint) -> AnyTransition {
        .modifier(
            active: ScaleModifier(scale: 0, anchor: anchor),
            identity: ScaleModifier(scale: 1, anchor: anchor)
        )
    }
}

struct ScaleModifier: ViewModifier {
    let scale: CGFloat
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content.scaleEffect(scale, anchor: anchor)
    }
}
```

### Gesture-Driven Animations

```swift
// Sources/Core/Animation/GestureAnimations.swift
import SwiftUI

struct DraggableCard: View {
    @State private var offset: CGSize = .zero
    @State private var isDragging = false
    @GestureState private var dragState = DragState.inactive

    enum DragState {
        case inactive
        case pressing
        case dragging(translation: CGSize)

        var translation: CGSize {
            switch self {
            case .inactive, .pressing: return .zero
            case .dragging(let translation): return translation
            }
        }

        var isActive: Bool {
            switch self {
            case .inactive: return false
            case .pressing, .dragging: return true
            }
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white)
            .frame(width: 300, height: 200)
            .shadow(
                color: .black.opacity(dragState.isActive ? 0.2 : 0.1),
                radius: dragState.isActive ? 20 : 10,
                y: dragState.isActive ? 10 : 5
            )
            .scaleEffect(dragState.isActive ? 1.05 : 1)
            .offset(
                x: offset.width + dragState.translation.width,
                y: offset.height + dragState.translation.height
            )
            .rotationEffect(
                .degrees(Double(dragState.translation.width / 20)),
                anchor: .bottom
            )
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .sequenced(before: DragGesture())
                    .updating($dragState) { value, state, _ in
                        switch value {
                        case .first(true):
                            state = .pressing
                        case .second(true, let drag):
                            state = .dragging(translation: drag?.translation ?? .zero)
                        default:
                            state = .inactive
                        }
                    }
                    .onEnded { value in
                        guard case .second(true, let drag?) = value else { return }

                        // Apply velocity for momentum
                        let velocity = drag.predictedEndTranslation
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            offset = CGSize(
                                width: offset.width + velocity.width * 0.5,
                                height: offset.height + velocity.height * 0.5
                            )
                        }
                    }
            )
            .animation(.interactiveSpring(), value: dragState.isActive)
    }
}

// Swipe-to-dismiss gesture
struct SwipeToDismiss: ViewModifier {
    @Binding var isPresented: Bool
    let threshold: CGFloat
    let onDismiss: (() -> Void)?

    @GestureState private var dragOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: max(0, dragOffset))
            .opacity(1 - Double(dragOffset / 500))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if value.translation.height > 0 {
                            state = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > threshold ||
                           value.predictedEndTranslation.height > threshold * 2 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                            onDismiss?()
                        }
                    }
            )
    }
}

extension View {
    func swipeToDismiss(
        isPresented: Binding<Bool>,
        threshold: CGFloat = 100,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(SwipeToDismiss(
            isPresented: isPresented,
            threshold: threshold,
            onDismiss: onDismiss
        ))
    }
}
```

### Shared Element Transitions (iOS 18+)

```swift
// Sources/Core/Animation/SharedElementTransition.swift
import SwiftUI

struct PhotoGrid: View {
    @Namespace private var animation
    @State private var selectedPhoto: Photo?

    let photos: [Photo]

    var body: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 2) {
                    ForEach(photos) { photo in
                        PhotoThumbnail(photo: photo)
                            .matchedGeometryEffect(
                                id: photo.id,
                                in: animation
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedPhoto = photo
                                }
                            }
                    }
                }
            }
            .opacity(selectedPhoto == nil ? 1 : 0)

            if let photo = selectedPhoto {
                PhotoDetail(photo: photo)
                    .matchedGeometryEffect(
                        id: photo.id,
                        in: animation
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedPhoto = nil
                        }
                    }
                    .transition(.opacity)
            }
        }
    }
}

// Navigation transition with matched geometry
struct HeroNavigationLink<Destination: View, Label: View>: View {
    @Namespace private var heroNamespace
    let destination: () -> Destination
    let label: () -> Label
    let id: String

    @State private var isActive = false

    var body: some View {
        ZStack {
            label()
                .matchedGeometryEffect(id: id, in: heroNamespace, isSource: !isActive)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        isActive = true
                    }
                }

            if isActive {
                destination()
                    .matchedGeometryEffect(id: id, in: heroNamespace, isSource: isActive)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.1)),
                        removal: .opacity.animation(.easeOut(duration: 0.2))
                    ))
            }
        }
    }
}
```

### Keyframe Animations (iOS 17+)

```swift
// Sources/Core/Animation/KeyframeAnimations.swift
import SwiftUI

struct ShakeAnimation: View {
    @State private var shake = false

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 50))
            .keyframeAnimator(
                initialValue: ShakeKeyframes(),
                trigger: shake
            ) { content, value in
                content
                    .rotationEffect(.degrees(value.angle))
                    .scaleEffect(value.scale)
            } keyframes: { _ in
                KeyframeTrack(\.angle) {
                    CubicKeyframe(15, duration: 0.1)
                    CubicKeyframe(-15, duration: 0.1)
                    CubicKeyframe(10, duration: 0.1)
                    CubicKeyframe(-10, duration: 0.1)
                    CubicKeyframe(5, duration: 0.1)
                    CubicKeyframe(0, duration: 0.1)
                }

                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.2, duration: 0.15, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.35, spring: .smooth)
                }
            }
            .onTapGesture {
                shake.toggle()
            }
    }
}

struct ShakeKeyframes {
    var angle: Double = 0
    var scale: Double = 1
}

// Phase animator for complex sequences
struct LoadingDots: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.blue)
                    .frame(width: 12, height: 12)
                    .phaseAnimator(
                        [false, true],
                        trigger: true
                    ) { content, phase in
                        content
                            .offset(y: phase ? -10 : 0)
                            .opacity(phase ? 1 : 0.5)
                    } animation: { phase in
                        .easeInOut(duration: 0.3)
                            .delay(Double(index) * 0.15)
                            .repeatForever(autoreverses: true)
                    }
            }
        }
    }
}
```

### Lottie Integration

```swift
// Sources/Core/Animation/LottieView.swift
import SwiftUI
import Lottie

struct LottieAnimationView: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    let contentMode: UIView.ContentMode
    @Binding var play: Bool

    init(
        name: String,
        loopMode: LottieLoopMode = .playOnce,
        animationSpeed: CGFloat = 1,
        contentMode: UIView.ContentMode = .scaleAspectFit,
        play: Binding<Bool> = .constant(true)
    ) {
        self.name = name
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.contentMode = contentMode
        self._play = play
    }

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: name)
        animationView.loopMode = loopMode
        animationView.animationSpeed = animationSpeed
        animationView.contentMode = contentMode
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if play {
            uiView.play()
        } else {
            uiView.pause()
        }
    }
}

// Progress-controlled Lottie
struct LottieProgressView: UIViewRepresentable {
    let name: String
    let progress: CGFloat

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: name)
        animationView.contentMode = .scaleAspectFit
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.currentProgress = progress
    }
}
```

## Android Implementation (Kotlin/Jetpack Compose)

### Animation Utilities

```kotlin
// app/src/main/java/com/app/core/animation/AnimationSpecs.kt
package com.app.core.animation

import androidx.compose.animation.core.*

object AnimationSpecs {
    // Standard timing specs
    val quick = tween<Float>(durationMillis = 200, easing = FastOutSlowInEasing)
    val standard = tween<Float>(durationMillis = 300, easing = FastOutSlowInEasing)
    val slow = tween<Float>(durationMillis = 500, easing = FastOutSlowInEasing)

    // Spring specs
    val bouncy = spring<Float>(
        dampingRatio = Spring.DampingRatioMediumBouncy,
        stiffness = Spring.StiffnessMedium
    )

    val snappy = spring<Float>(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = Spring.StiffnessHigh
    )

    val smooth = spring<Float>(
        dampingRatio = Spring.DampingRatioNoBouncy,
        stiffness = Spring.StiffnessLow
    )

    // Material Design emphasized easing
    val emphasized = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    val emphasizedDecelerate = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
    val emphasizedAccelerate = CubicBezierEasing(0.3f, 0f, 0.8f, 0.15f)
}

// Keyframe animations
object KeyframeSpecs {
    fun <T> shake(): KeyframesSpec<T> where T : Number = keyframes {
        durationMillis = 600
        // Define keyframes here
    }
}

// Animation extensions
fun <T> springSpec(
    dampingRatio: Float = Spring.DampingRatioNoBouncy,
    stiffness: Float = Spring.StiffnessMedium,
    visibilityThreshold: T? = null
): SpringSpec<T> = spring(
    dampingRatio = dampingRatio,
    stiffness = stiffness,
    visibilityThreshold = visibilityThreshold
)
```

### View Animations

```kotlin
// app/src/main/java/com/app/core/animation/ViewAnimations.kt
package com.app.core.animation

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer

// Slide and fade animation
@Composable
fun SlideAndFade(
    visible: Boolean,
    direction: SlideDirection = SlideDirection.Bottom,
    modifier: Modifier = Modifier,
    content: @Composable AnimatedVisibilityScope.() -> Unit
) {
    val offsetY = when (direction) {
        SlideDirection.Top -> -50
        SlideDirection.Bottom -> 50
        else -> 0
    }
    val offsetX = when (direction) {
        SlideDirection.Start -> -50
        SlideDirection.End -> 50
        else -> 0
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(animationSpec = tween(300)) +
                slideInVertically(
                    animationSpec = tween(300),
                    initialOffsetY = { offsetY }
                ) +
                slideInHorizontally(
                    animationSpec = tween(300),
                    initialOffsetX = { offsetX }
                ),
        exit = fadeOut(animationSpec = tween(200)) +
               slideOutVertically(
                   animationSpec = tween(200),
                   targetOffsetY = { offsetY }
               ) +
               slideOutHorizontally(
                   animationSpec = tween(200),
                   targetOffsetX = { offsetX }
               ),
        modifier = modifier,
        content = content
    )
}

enum class SlideDirection { Top, Bottom, Start, End }

// Staggered animation
@Composable
fun <T> StaggeredAnimatedColumn(
    items: List<T>,
    staggerDelayMillis: Int = 50,
    modifier: Modifier = Modifier,
    content: @Composable (T, Int) -> Unit
) {
    var appeared by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        appeared = true
    }

    Column(modifier = modifier) {
        items.forEachIndexed { index, item ->
            val animatedAlpha by animateFloatAsState(
                targetValue = if (appeared) 1f else 0f,
                animationSpec = tween(
                    durationMillis = 300,
                    delayMillis = index * staggerDelayMillis
                ),
                label = "stagger_alpha_$index"
            )

            val animatedOffset by animateDpAsState(
                targetValue = if (appeared) 0.dp else 20.dp,
                animationSpec = tween(
                    durationMillis = 300,
                    delayMillis = index * staggerDelayMillis
                ),
                label = "stagger_offset_$index"
            )

            Box(
                modifier = Modifier
                    .graphicsLayer { alpha = animatedAlpha }
                    .offset(y = animatedOffset)
            ) {
                content(item, index)
            }
        }
    }
}

// Scale animation with anchor
@Composable
fun ScaleFromAnchor(
    visible: Boolean,
    anchor: TransformOrigin = TransformOrigin.Center,
    modifier: Modifier = Modifier,
    content: @Composable AnimatedVisibilityScope.() -> Unit
) {
    AnimatedVisibility(
        visible = visible,
        enter = scaleIn(
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessMedium
            ),
            transformOrigin = anchor
        ) + fadeIn(),
        exit = scaleOut(
            animationSpec = tween(200),
            transformOrigin = anchor
        ) + fadeOut(),
        modifier = modifier,
        content = content
    )
}
```

### Gesture-Driven Animations

```kotlin
// app/src/main/java/com/app/core/animation/GestureAnimations.kt
package com.app.core.animation

import androidx.compose.animation.core.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.unit.IntOffset
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
fun DraggableCard(
    modifier: Modifier = Modifier,
    onDismiss: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    var isDragging by remember { mutableStateOf(false) }

    val animatedScale by animateFloatAsState(
        targetValue = if (isDragging) 1.05f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy
        ),
        label = "card_scale"
    )

    val animatedElevation by animateDpAsState(
        targetValue = if (isDragging) 16.dp else 4.dp,
        animationSpec = spring(),
        label = "card_elevation"
    )

    val rotation = offsetX / 20f

    Card(
        modifier = modifier
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .graphicsLayer {
                scaleX = animatedScale
                scaleY = animatedScale
                rotationZ = rotation
            }
            .pointerInput(Unit) {
                val velocityTracker = VelocityTracker()

                detectDragGestures(
                    onDragStart = {
                        isDragging = true
                    },
                    onDragEnd = {
                        isDragging = false
                        val velocity = velocityTracker.calculateVelocity()

                        // Check for dismiss threshold
                        if (kotlin.math.abs(offsetX) > 200 ||
                            kotlin.math.abs(velocity.x) > 1000) {
                            onDismiss?.invoke()
                        } else {
                            // Animate back to center
                            // Note: Use animateDecay or animate* functions
                        }
                    },
                    onDragCancel = {
                        isDragging = false
                    }
                ) { change, dragAmount ->
                    change.consume()
                    velocityTracker.addPosition(
                        change.uptimeMillis,
                        change.position
                    )
                    offsetX += dragAmount.x
                    offsetY += dragAmount.y
                }
            },
        elevation = CardDefaults.cardElevation(defaultElevation = animatedElevation)
    ) {
        content()
    }
}

// Swipe to dismiss modifier
@Composable
fun Modifier.swipeToDismiss(
    enabled: Boolean = true,
    threshold: Float = 0.4f,
    onDismiss: () -> Unit
): Modifier {
    var offsetY by remember { mutableFloatStateOf(0f) }
    val animatable = remember { Animatable(0f) }

    return this
        .offset { IntOffset(0, animatable.value.roundToInt()) }
        .graphicsLayer {
            alpha = 1f - (kotlin.math.abs(animatable.value) / 500f).coerceIn(0f, 0.5f)
        }
        .pointerInput(enabled) {
            if (!enabled) return@pointerInput

            detectVerticalDragGestures(
                onDragEnd = {
                    if (animatable.value > size.height * threshold) {
                        onDismiss()
                    } else {
                        // Animate back
                        coroutineScope {
                            animatable.animateTo(
                                0f,
                                animationSpec = spring(
                                    dampingRatio = Spring.DampingRatioMediumBouncy
                                )
                            )
                        }
                    }
                }
            ) { change, dragAmount ->
                change.consume()
                if (animatable.value + dragAmount >= 0) {
                    coroutineScope {
                        animatable.snapTo(animatable.value + dragAmount)
                    }
                }
            }
        }
}
```

### Shared Element Transitions

```kotlin
// app/src/main/java/com/app/core/animation/SharedElementTransition.kt
package com.app.core.animation

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun PhotoGalleryWithSharedTransition() {
    var selectedPhoto by remember { mutableStateOf<Photo?>(null) }

    SharedTransitionLayout {
        AnimatedContent(
            targetState = selectedPhoto,
            transitionSpec = {
                fadeIn(tween(300)) togetherWith fadeOut(tween(300))
            },
            label = "photo_transition"
        ) { photo ->
            if (photo == null) {
                PhotoGrid(
                    photos = samplePhotos,
                    onPhotoClick = { selectedPhoto = it },
                    animatedVisibilityScope = this@AnimatedContent,
                    sharedTransitionScope = this@SharedTransitionLayout
                )
            } else {
                PhotoDetail(
                    photo = photo,
                    onBack = { selectedPhoto = null },
                    animatedVisibilityScope = this@AnimatedContent,
                    sharedTransitionScope = this@SharedTransitionLayout
                )
            }
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.PhotoGrid(
    photos: List<Photo>,
    onPhotoClick: (Photo) -> Unit,
    animatedVisibilityScope: AnimatedVisibilityScope,
    sharedTransitionScope: SharedTransitionScope
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(3),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        items(photos) { photo ->
            AsyncImage(
                model = photo.url,
                contentDescription = photo.description,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .aspectRatio(1f)
                    .sharedElement(
                        state = rememberSharedContentState(key = "photo_${photo.id}"),
                        animatedVisibilityScope = animatedVisibilityScope,
                        boundsTransform = { _, _ ->
                            spring(
                                dampingRatio = Spring.DampingRatioLowBouncy,
                                stiffness = Spring.StiffnessLow
                            )
                        }
                    )
                    .clickable { onPhotoClick(photo) }
            )
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun SharedTransitionScope.PhotoDetail(
    photo: Photo,
    onBack: () -> Unit,
    animatedVisibilityScope: AnimatedVisibilityScope,
    sharedTransitionScope: SharedTransitionScope
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clickable { onBack() }
    ) {
        AsyncImage(
            model = photo.url,
            contentDescription = photo.description,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .fillMaxSize()
                .sharedElement(
                    state = rememberSharedContentState(key = "photo_${photo.id}"),
                    animatedVisibilityScope = animatedVisibilityScope
                )
        )
    }
}
```

### Lottie Integration

```kotlin
// app/src/main/java/com/app/core/animation/LottieAnimation.kt
package com.app.core.animation

import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.airbnb.lottie.compose.*

@Composable
fun LottieAnimationView(
    animationRes: Int,
    modifier: Modifier = Modifier,
    iterations: Int = LottieConstants.IterateForever,
    isPlaying: Boolean = true,
    speed: Float = 1f,
    restartOnPlay: Boolean = true
) {
    val composition by rememberLottieComposition(
        LottieCompositionSpec.RawRes(animationRes)
    )

    val progress by animateLottieCompositionAsState(
        composition = composition,
        iterations = iterations,
        isPlaying = isPlaying,
        speed = speed,
        restartOnPlay = restartOnPlay
    )

    LottieAnimation(
        composition = composition,
        progress = { progress },
        modifier = modifier
    )
}

// Progress-controlled Lottie
@Composable
fun LottieProgressAnimation(
    animationRes: Int,
    progress: Float,
    modifier: Modifier = Modifier
) {
    val composition by rememberLottieComposition(
        LottieCompositionSpec.RawRes(animationRes)
    )

    LottieAnimation(
        composition = composition,
        progress = { progress },
        modifier = modifier
    )
}

// Interactive Lottie with gesture control
@Composable
fun InteractiveLottieAnimation(
    animationRes: Int,
    modifier: Modifier = Modifier
) {
    val composition by rememberLottieComposition(
        LottieCompositionSpec.RawRes(animationRes)
    )

    var progress by remember { mutableFloatStateOf(0f) }

    LottieAnimation(
        composition = composition,
        progress = { progress },
        modifier = modifier.pointerInput(Unit) {
            detectHorizontalDragGestures { change, dragAmount ->
                change.consume()
                progress = (progress + dragAmount / size.width).coerceIn(0f, 1f)
            }
        }
    )
}
```

## React Native Implementation

### Animation Utilities

```typescript
// src/core/animation/animationConfig.ts
import { Easing } from 'react-native-reanimated';

export const AnimationConfig = {
  // Timing configurations
  timing: {
    quick: { duration: 200, easing: Easing.out(Easing.ease) },
    standard: { duration: 300, easing: Easing.inOut(Easing.ease) },
    slow: { duration: 500, easing: Easing.inOut(Easing.ease) },
  },

  // Spring configurations
  spring: {
    bouncy: { damping: 10, stiffness: 100, mass: 0.5 },
    snappy: { damping: 20, stiffness: 300, mass: 0.8 },
    smooth: { damping: 25, stiffness: 150, mass: 1 },
  },

  // Material Design curves
  easing: {
    emphasized: Easing.bezier(0.2, 0, 0, 1),
    emphasizedDecelerate: Easing.bezier(0.05, 0.7, 0.1, 1),
    emphasizedAccelerate: Easing.bezier(0.3, 0, 0.8, 0.15),
  },
};

// Animation presets
export const createSpringAnimation = (
  config: 'bouncy' | 'snappy' | 'smooth' = 'smooth'
) => {
  return {
    ...AnimationConfig.spring[config],
    restDisplacementThreshold: 0.01,
    restSpeedThreshold: 0.01,
  };
};
```

### Reanimated Animations

```typescript
// src/core/animation/useAnimations.ts
import { useCallback } from 'react';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  withSequence,
  withDelay,
  withRepeat,
  interpolate,
  Extrapolation,
  runOnJS,
  useDerivedValue,
  cancelAnimation,
} from 'react-native-reanimated';
import { AnimationConfig, createSpringAnimation } from './animationConfig';

// Slide and fade animation hook
export const useSlideAndFade = (
  direction: 'up' | 'down' | 'left' | 'right' = 'up'
) => {
  const progress = useSharedValue(0);

  const offsetValue = useCallback(() => {
    switch (direction) {
      case 'up': return { x: 0, y: 50 };
      case 'down': return { x: 0, y: -50 };
      case 'left': return { x: 50, y: 0 };
      case 'right': return { x: -50, y: 0 };
    }
  }, [direction]);

  const animatedStyle = useAnimatedStyle(() => {
    const offset = offsetValue();
    return {
      opacity: progress.value,
      transform: [
        {
          translateX: interpolate(
            progress.value,
            [0, 1],
            [offset.x, 0],
            Extrapolation.CLAMP
          ),
        },
        {
          translateY: interpolate(
            progress.value,
            [0, 1],
            [offset.y, 0],
            Extrapolation.CLAMP
          ),
        },
      ],
    };
  });

  const show = useCallback(() => {
    progress.value = withSpring(1, createSpringAnimation('smooth'));
  }, []);

  const hide = useCallback(() => {
    progress.value = withTiming(0, AnimationConfig.timing.quick);
  }, []);

  return { animatedStyle, show, hide, progress };
};

// Staggered animation hook
export const useStaggeredAnimation = (itemCount: number, delayMs: number = 50) => {
  const progresses = Array.from({ length: itemCount }, () => useSharedValue(0));

  const show = useCallback(() => {
    progresses.forEach((progress, index) => {
      progress.value = withDelay(
        index * delayMs,
        withSpring(1, createSpringAnimation('smooth'))
      );
    });
  }, [delayMs]);

  const hide = useCallback(() => {
    progresses.forEach((progress) => {
      progress.value = withTiming(0, AnimationConfig.timing.quick);
    });
  }, []);

  const getItemStyle = useCallback((index: number) => {
    return useAnimatedStyle(() => ({
      opacity: progresses[index].value,
      transform: [
        {
          translateY: interpolate(
            progresses[index].value,
            [0, 1],
            [20, 0],
            Extrapolation.CLAMP
          ),
        },
      ],
    }));
  }, []);

  return { show, hide, getItemStyle };
};

// Scale from anchor animation
export const useScaleFromAnchor = (
  anchorX: number = 0.5,
  anchorY: number = 0.5
) => {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [
      { translateX: -(anchorX - 0.5) * 100 * (1 - scale.value) },
      { translateY: -(anchorY - 0.5) * 100 * (1 - scale.value) },
      { scale: scale.value },
    ],
  }));

  const show = useCallback(() => {
    scale.value = withSpring(1, createSpringAnimation('bouncy'));
    opacity.value = withTiming(1, { duration: 150 });
  }, []);

  const hide = useCallback(() => {
    scale.value = withTiming(0, AnimationConfig.timing.quick);
    opacity.value = withTiming(0, { duration: 100 });
  }, []);

  return { animatedStyle, show, hide };
};
```

### Gesture-Driven Animations

```typescript
// src/core/animation/GestureAnimations.tsx
import React, { useCallback } from 'react';
import { StyleSheet, Dimensions } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  useAnimatedGestureHandler,
  withSpring,
  withTiming,
  runOnJS,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated';
import {
  PanGestureHandler,
  PanGestureHandlerGestureEvent,
} from 'react-native-gesture-handler';
import { createSpringAnimation } from './animationConfig';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const SWIPE_THRESHOLD = SCREEN_WIDTH * 0.3;

interface DraggableCardProps {
  children: React.ReactNode;
  onDismissLeft?: () => void;
  onDismissRight?: () => void;
}

export const DraggableCard: React.FC<DraggableCardProps> = ({
  children,
  onDismissLeft,
  onDismissRight,
}) => {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);
  const scale = useSharedValue(1);
  const isPressed = useSharedValue(false);

  const gestureHandler = useAnimatedGestureHandler<
    PanGestureHandlerGestureEvent,
    { startX: number; startY: number }
  >({
    onStart: (_, ctx) => {
      ctx.startX = translateX.value;
      ctx.startY = translateY.value;
      isPressed.value = true;
      scale.value = withSpring(1.05, createSpringAnimation('bouncy'));
    },
    onActive: (event, ctx) => {
      translateX.value = ctx.startX + event.translationX;
      translateY.value = ctx.startY + event.translationY;
    },
    onEnd: (event) => {
      isPressed.value = false;
      scale.value = withSpring(1, createSpringAnimation('smooth'));

      const shouldDismissLeft =
        translateX.value < -SWIPE_THRESHOLD || event.velocityX < -500;
      const shouldDismissRight =
        translateX.value > SWIPE_THRESHOLD || event.velocityX > 500;

      if (shouldDismissLeft && onDismissLeft) {
        translateX.value = withTiming(-SCREEN_WIDTH * 1.5, { duration: 300 });
        runOnJS(onDismissLeft)();
      } else if (shouldDismissRight && onDismissRight) {
        translateX.value = withTiming(SCREEN_WIDTH * 1.5, { duration: 300 });
        runOnJS(onDismissRight)();
      } else {
        translateX.value = withSpring(0, createSpringAnimation('smooth'));
        translateY.value = withSpring(0, createSpringAnimation('smooth'));
      }
    },
  });

  const animatedStyle = useAnimatedStyle(() => {
    const rotate = interpolate(
      translateX.value,
      [-SCREEN_WIDTH / 2, 0, SCREEN_WIDTH / 2],
      [-15, 0, 15],
      Extrapolation.CLAMP
    );

    return {
      transform: [
        { translateX: translateX.value },
        { translateY: translateY.value },
        { scale: scale.value },
        { rotateZ: `${rotate}deg` },
      ],
    };
  });

  return (
    <PanGestureHandler onGestureEvent={gestureHandler}>
      <Animated.View style={[styles.card, animatedStyle]}>
        {children}
      </Animated.View>
    </PanGestureHandler>
  );
};

// Swipe to dismiss
interface SwipeToDismissProps {
  children: React.ReactNode;
  onDismiss: () => void;
  threshold?: number;
}

export const SwipeToDismiss: React.FC<SwipeToDismissProps> = ({
  children,
  onDismiss,
  threshold = 100,
}) => {
  const translateY = useSharedValue(0);

  const gestureHandler = useAnimatedGestureHandler<
    PanGestureHandlerGestureEvent
  >({
    onActive: (event) => {
      if (event.translationY > 0) {
        translateY.value = event.translationY;
      }
    },
    onEnd: (event) => {
      if (
        translateY.value > threshold ||
        event.velocityY > 500
      ) {
        translateY.value = withTiming(500, { duration: 200 });
        runOnJS(onDismiss)();
      } else {
        translateY.value = withSpring(0, createSpringAnimation('smooth'));
      }
    },
  });

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value }],
    opacity: interpolate(
      translateY.value,
      [0, 300],
      [1, 0.5],
      Extrapolation.CLAMP
    ),
  }));

  return (
    <PanGestureHandler onGestureEvent={gestureHandler}>
      <Animated.View style={animatedStyle}>{children}</Animated.View>
    </PanGestureHandler>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#fff',
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
    elevation: 8,
  },
});
```

### Shared Element Transitions

```typescript
// src/core/animation/SharedElementTransition.tsx
import React from 'react';
import { StyleSheet, Pressable } from 'react-native';
import Animated, {
  SharedTransition,
  withSpring,
} from 'react-native-reanimated';
import { createSharedElementStackNavigator } from 'react-navigation-shared-element';
import { NavigationContainer } from '@react-navigation/native';

// Custom shared transition
const customTransition = SharedTransition.custom((values) => {
  'worklet';
  return {
    width: withSpring(values.targetWidth, { damping: 20, stiffness: 200 }),
    height: withSpring(values.targetHeight, { damping: 20, stiffness: 200 }),
    originX: withSpring(values.targetOriginX, { damping: 20, stiffness: 200 }),
    originY: withSpring(values.targetOriginY, { damping: 20, stiffness: 200 }),
  };
});

// Photo gallery with shared element
interface Photo {
  id: string;
  uri: string;
  title: string;
}

interface PhotoGridProps {
  photos: Photo[];
  onPhotoPress: (photo: Photo) => void;
}

export const PhotoGrid: React.FC<PhotoGridProps> = ({ photos, onPhotoPress }) => {
  return (
    <Animated.FlatList
      data={photos}
      numColumns={3}
      keyExtractor={(item) => item.id}
      renderItem={({ item }) => (
        <Pressable onPress={() => onPhotoPress(item)}>
          <Animated.Image
            source={{ uri: item.uri }}
            style={styles.thumbnail}
            sharedTransitionTag={`photo-${item.id}`}
            sharedTransitionStyle={customTransition}
          />
        </Pressable>
      )}
    />
  );
};

interface PhotoDetailProps {
  photo: Photo;
}

export const PhotoDetail: React.FC<PhotoDetailProps> = ({ photo }) => {
  return (
    <Animated.View style={styles.detailContainer}>
      <Animated.Image
        source={{ uri: photo.uri }}
        style={styles.detailImage}
        sharedTransitionTag={`photo-${photo.id}`}
        sharedTransitionStyle={customTransition}
      />
      <Animated.Text
        style={styles.detailTitle}
        sharedTransitionTag={`title-${photo.id}`}
      >
        {photo.title}
      </Animated.Text>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  thumbnail: {
    width: '33.33%',
    aspectRatio: 1,
  },
  detailContainer: {
    flex: 1,
    backgroundColor: '#000',
  },
  detailImage: {
    width: '100%',
    height: '70%',
    resizeMode: 'contain',
  },
  detailTitle: {
    color: '#fff',
    fontSize: 24,
    fontWeight: 'bold',
    padding: 16,
  },
});
```

### Lottie Integration

```typescript
// src/core/animation/LottieAnimation.tsx
import React, { useRef, useEffect } from 'react';
import { StyleSheet, ViewStyle } from 'react-native';
import LottieView from 'lottie-react-native';
import Animated, {
  useAnimatedProps,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

const AnimatedLottieView = Animated.createAnimatedComponent(LottieView);

interface LottieAnimationProps {
  source: string | object;
  autoPlay?: boolean;
  loop?: boolean;
  speed?: number;
  style?: ViewStyle;
  onAnimationFinish?: () => void;
}

export const LottieAnimation: React.FC<LottieAnimationProps> = ({
  source,
  autoPlay = true,
  loop = true,
  speed = 1,
  style,
  onAnimationFinish,
}) => {
  const animationRef = useRef<LottieView>(null);

  useEffect(() => {
    if (autoPlay) {
      animationRef.current?.play();
    }
  }, [autoPlay]);

  return (
    <LottieView
      ref={animationRef}
      source={typeof source === 'string' ? { uri: source } : source}
      autoPlay={autoPlay}
      loop={loop}
      speed={speed}
      style={[styles.animation, style]}
      onAnimationFinish={onAnimationFinish}
    />
  );
};

// Progress-controlled Lottie
interface LottieProgressProps {
  source: string | object;
  progress: number;
  style?: ViewStyle;
}

export const LottieProgress: React.FC<LottieProgressProps> = ({
  source,
  progress,
  style,
}) => {
  const animatedProgress = useSharedValue(progress);

  useEffect(() => {
    animatedProgress.value = withTiming(progress, { duration: 300 });
  }, [progress]);

  const animatedProps = useAnimatedProps(() => ({
    progress: animatedProgress.value,
  }));

  return (
    <AnimatedLottieView
      source={typeof source === 'string' ? { uri: source } : source}
      animatedProps={animatedProps}
      style={[styles.animation, style]}
    />
  );
};

const styles = StyleSheet.create({
  animation: {
    width: 200,
    height: 200,
  },
});
```

## Flutter Implementation

### Animation Utilities

```dart
// lib/core/animation/animation_config.dart
import 'package:flutter/material.dart';

class AnimationConfig {
  // Timing configurations
  static const quickDuration = Duration(milliseconds: 200);
  static const standardDuration = Duration(milliseconds: 300);
  static const slowDuration = Duration(milliseconds: 500);

  // Curves
  static const quick = Curves.easeOut;
  static const standard = Curves.easeInOut;
  static const slow = Curves.easeInOut;

  // Spring configurations
  static final bouncy = SpringDescription(
    mass: 0.5,
    stiffness: 100,
    damping: 10,
  );

  static final snappy = SpringDescription(
    mass: 0.8,
    stiffness: 300,
    damping: 20,
  );

  static final smooth = SpringDescription(
    mass: 1,
    stiffness: 150,
    damping: 25,
  );

  // Material Design curves
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
}

// Animation helper extensions
extension AnimationExtensions on AnimationController {
  Animation<double> withCurve(Curve curve) {
    return CurvedAnimation(parent: this, curve: curve);
  }

  void animateWith(SpringDescription spring) {
    final simulation = SpringSimulation(spring, value, 1, velocity);
    animateWith(simulation);
  }
}
```

### Animated Widgets

```dart
// lib/core/animation/animated_widgets.dart
import 'package:flutter/material.dart';
import 'animation_config.dart';

// Slide and fade animation
class SlideAndFade extends StatefulWidget {
  final Widget child;
  final bool isVisible;
  final Duration duration;
  final Offset slideOffset;
  final Curve curve;

  const SlideAndFade({
    super.key,
    required this.child,
    required this.isVisible,
    this.duration = AnimationConfig.standardDuration,
    this.slideOffset = const Offset(0, 0.1),
    this.curve = AnimationConfig.standard,
  });

  @override
  State<SlideAndFade> createState() => _SlideAndFadeState();
}

class _SlideAndFadeState extends State<SlideAndFade>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SlideAndFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// Staggered animation list
class StaggeredAnimatedList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final Curve curve;

  const StaggeredAnimatedList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 50),
    this.itemDuration = AnimationConfig.standardDuration,
    this.curve = AnimationConfig.standard,
  });

  @override
  State<StaggeredAnimatedList> createState() => _StaggeredAnimatedListState();
}

class _StaggeredAnimatedListState extends State<StaggeredAnimatedList>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        vsync: this,
        duration: widget.itemDuration,
      ),
    );

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: widget.curve),
      );
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: controller, curve: widget.curve),
      );
    }).toList();
  }

  void _startAnimations() async {
    for (int i = 0; i < _controllers.length; i++) {
      await Future.delayed(widget.itemDelay);
      if (mounted) {
        _controllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.children.length, (index) {
        return FadeTransition(
          opacity: _fadeAnimations[index],
          child: SlideTransition(
            position: _slideAnimations[index],
            child: widget.children[index],
          ),
        );
      }),
    );
  }
}

// Scale from anchor
class ScaleFromAnchor extends StatefulWidget {
  final Widget child;
  final bool isVisible;
  final Alignment anchor;
  final Duration duration;
  final Curve curve;

  const ScaleFromAnchor({
    super.key,
    required this.child,
    required this.isVisible,
    this.anchor = Alignment.center,
    this.duration = AnimationConfig.standardDuration,
    this.curve = Curves.easeOutBack,
  });

  @override
  State<ScaleFromAnchor> createState() => _ScaleFromAnchorState();
}

class _ScaleFromAnchorState extends State<ScaleFromAnchor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ScaleFromAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: widget.anchor,
        child: widget.child,
      ),
    );
  }
}
```

### Gesture-Driven Animations

```dart
// lib/core/animation/gesture_animations.dart
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class DraggableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDismissLeft;
  final VoidCallback? onDismissRight;

  const DraggableCard({
    super.key,
    required this.child,
    this.onDismissLeft,
    this.onDismissRight,
  });

  @override
  State<DraggableCard> createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _dragOffset = Offset.zero;
  Offset _dragVelocity = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _controller.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _dragVelocity = details.velocity.pixelsPerSecond;
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;

    if (_dragOffset.dx < -threshold || _dragVelocity.dx < -500) {
      _animateTo(Offset(-screenWidth * 1.5, _dragOffset.dy));
      widget.onDismissLeft?.call();
    } else if (_dragOffset.dx > threshold || _dragVelocity.dx > 500) {
      _animateTo(Offset(screenWidth * 1.5, _dragOffset.dy));
      widget.onDismissRight?.call();
    } else {
      _animateBack();
    }
  }

  void _animateTo(Offset target) {
    final spring = SpringDescription(
      mass: 1,
      stiffness: 200,
      damping: 25,
    );

    final simulationX = SpringSimulation(
      spring,
      _dragOffset.dx,
      target.dx,
      _dragVelocity.dx,
    );

    _controller.animateWith(simulationX);
  }

  void _animateBack() {
    final spring = SpringDescription(
      mass: 1,
      stiffness: 300,
      damping: 20,
    );

    final simulationX = SpringSimulation(spring, _dragOffset.dx, 0, _dragVelocity.dx);
    final simulationY = SpringSimulation(spring, _dragOffset.dy, 0, _dragVelocity.dy);

    _controller.addListener(() {
      setState(() {
        _dragOffset = Offset(
          simulationX.x(_controller.value),
          simulationY.x(_controller.value),
        );
      });
    });

    _controller.animateWith(simulationX);
  }

  @override
  Widget build(BuildContext context) {
    final rotation = _dragOffset.dx / 1000;
    final scale = _isDragging ? 1.05 : 1.0;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()
          ..translate(_dragOffset.dx, _dragOffset.dy)
          ..rotateZ(rotation)
          ..scale(scale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDragging ? 0.2 : 0.1),
                blurRadius: _isDragging ? 20 : 10,
                offset: Offset(0, _isDragging ? 10 : 5),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// Swipe to dismiss
class SwipeToDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final double threshold;

  const SwipeToDismiss({
    super.key,
    required this.child,
    required this.onDismiss,
    this.threshold = 100,
  });

  @override
  State<SwipeToDismiss> createState() => _SwipeToDismissState();
}

class _SwipeToDismissState extends State<SwipeToDismiss>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragOffset > widget.threshold || details.velocity.pixelsPerSecond.dy > 500) {
      widget.onDismiss();
    } else {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: Opacity(
          opacity: (1 - _dragOffset / 500).clamp(0.5, 1),
          child: widget.child,
        ),
      ),
    );
  }
}
```

### Hero Transitions

```dart
// lib/core/animation/hero_transitions.dart
import 'package:flutter/material.dart';

class PhotoGallery extends StatelessWidget {
  final List<Photo> photos;

  const PhotoGallery({super.key, required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return PhotoDetailScreen(photo: photo);
                },
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
          child: Hero(
            tag: 'photo_${photo.id}',
            child: Image.network(
              photo.thumbnailUrl,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class PhotoDetailScreen extends StatelessWidget {
  final Photo photo;

  const PhotoDetailScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: 'photo_${photo.id}',
            child: Image.network(
              photo.fullUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom hero flight shader
class CustomHeroFlightShuttleBuilder extends StatelessWidget {
  final Animation<double> animation;
  final HeroFlightDirection flightDirection;
  final BuildContext fromHeroContext;
  final BuildContext toHeroContext;

  const CustomHeroFlightShuttleBuilder({
    super.key,
    required this.animation,
    required this.flightDirection,
    required this.fromHeroContext,
    required this.toHeroContext,
  });

  @override
  Widget build(BuildContext context) {
    final Hero toHero = toHeroContext.widget as Hero;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.lerp(
              BorderRadius.circular(16),
              BorderRadius.circular(0),
              animation.value,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2 * (1 - animation.value)),
                blurRadius: 20 * (1 - animation.value),
                offset: Offset(0, 10 * (1 - animation.value)),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.lerp(
              BorderRadius.circular(16),
              BorderRadius.circular(0),
              animation.value,
            )!,
            child: toHero.child,
          ),
        );
      },
    );
  }
}

class Photo {
  final String id;
  final String thumbnailUrl;
  final String fullUrl;

  const Photo({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
  });
}
```

### Lottie Integration

```dart
// lib/core/animation/lottie_animation.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieAnimationWidget extends StatefulWidget {
  final String asset;
  final bool autoPlay;
  final bool loop;
  final double? width;
  final double? height;
  final BoxFit fit;
  final VoidCallback? onComplete;

  const LottieAnimationWidget({
    super.key,
    required this.asset,
    this.autoPlay = true,
    this.loop = true,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.onComplete,
  });

  @override
  State<LottieAnimationWidget> createState() => _LottieAnimationWidgetState();
}

class _LottieAnimationWidgetState extends State<LottieAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    if (!widget.loop) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.asset,
      controller: _controller,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      repeat: widget.loop,
      animate: widget.autoPlay,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        if (widget.autoPlay) {
          if (widget.loop) {
            _controller.repeat();
          } else {
            _controller.forward();
          }
        }
      },
    );
  }
}

// Progress-controlled Lottie
class LottieProgressWidget extends StatelessWidget {
  final String asset;
  final double progress;
  final double? width;
  final double? height;

  const LottieProgressWidget({
    super.key,
    required this.asset,
    required this.progress,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      asset,
      width: width,
      height: height,
      animate: false,
      frameBuilder: (context, child, composition) {
        if (composition == null) return child;
        return AnimatedBuilder(
          animation: AlwaysStoppedAnimation(progress),
          builder: (context, _) {
            return Lottie(
              composition: composition,
              progress: progress,
              width: width,
              height: height,
            );
          },
        );
      },
    );
  }
}
```

## Output Expectations

When this subagent completes execution, expect:

1. **Animation Utilities**: Centralized configuration for timing curves, spring physics, and easing functions
2. **View Transitions**: Reusable slide, fade, scale, and staggered animation components
3. **Gesture Animations**: Drag, swipe-to-dismiss, and velocity-based physics animations
4. **Shared Element Transitions**: Hero animations and matched geometry effects between screens
5. **Keyframe Animations**: Complex multi-property animations with keyframe control
6. **Lottie Integration**: JSON-based animations with playback and progress control
7. **Performance Optimization**: 60fps animations using native animation APIs
8. **Interruptible Animations**: Gesture-driven animations that can be interrupted and redirected
