---
name: Mobile Onboarding Flow Implementation
platform: mobile
description: Implement engaging onboarding experiences with walkthroughs, permissions, and progressive disclosure
model: opus
category: mobile/frontend
---

# Mobile Onboarding Flow Implementation

## Purpose

This subagent implements comprehensive onboarding experiences including welcome screens, feature walkthroughs, permission requests, account setup, and progressive disclosure patterns that convert new users into engaged users.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Onboarding System                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │               Onboarding Coordinator                         ││
│  │  • Flow orchestration    • Progress tracking                 ││
│  │  • Skip/resume logic     • Completion handling               ││
│  └───────────────────────────┬─────────────────────────────────┘│
│                              │                                   │
│  ┌───────────┬───────────────┼───────────────┬─────────────────┐│
│  ▼           ▼               ▼               ▼                 ▼│
│┌─────────┐┌─────────┐┌─────────────┐┌────────────┐┌────────────┐│
││ Welcome ││ Feature ││ Permission  ││  Account   ││Progressive ││
││ Screens ││Walkthru ││  Requests   ││   Setup    ││ Disclosure ││
│└─────────┘└─────────┘└─────────────┘└────────────┘└────────────┘│
│                              │                                   │
│  ┌───────────────────────────┴─────────────────────────────────┐│
│  │                    Analytics Layer                           ││
│  │  • Step completion rates  • Drop-off tracking                ││
│  │  • A/B test variants      • Conversion metrics               ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## iOS Implementation (Swift/SwiftUI)

### Onboarding Coordinator

```swift
// Sources/Features/Onboarding/OnboardingCoordinator.swift
import SwiftUI
import Combine

@Observable
final class OnboardingCoordinator {
    enum Step: Int, CaseIterable {
        case welcome
        case featureHighlights
        case notifications
        case personalization
        case accountSetup
        case completion

        var analyticsName: String {
            switch self {
            case .welcome: return "welcome"
            case .featureHighlights: return "features"
            case .notifications: return "notifications"
            case .personalization: return "personalization"
            case .accountSetup: return "account"
            case .completion: return "completion"
            }
        }
    }

    private(set) var currentStep: Step = .welcome
    private(set) var progress: Double = 0
    private(set) var isComplete = false

    private let userDefaults: UserDefaults
    private let analytics: AnalyticsService

    private static let hasCompletedKey = "onboarding_completed"
    private static let lastStepKey = "onboarding_last_step"

    init(
        userDefaults: UserDefaults = .standard,
        analytics: AnalyticsService = .shared
    ) {
        self.userDefaults = userDefaults
        self.analytics = analytics
        restoreProgress()
    }

    var shouldShowOnboarding: Bool {
        !userDefaults.bool(forKey: Self.hasCompletedKey)
    }

    func nextStep() {
        guard let nextIndex = Step.allCases.firstIndex(of: currentStep)
            .map({ $0 + 1 }),
              nextIndex < Step.allCases.count else {
            completeOnboarding()
            return
        }

        let next = Step.allCases[nextIndex]
        navigateTo(next)
    }

    func previousStep() {
        guard let prevIndex = Step.allCases.firstIndex(of: currentStep)
            .map({ $0 - 1 }),
              prevIndex >= 0 else { return }

        let prev = Step.allCases[prevIndex]
        navigateTo(prev)
    }

    func skipToStep(_ step: Step) {
        navigateTo(step)
        analytics.track(.onboardingSkipped(from: currentStep.analyticsName, to: step.analyticsName))
    }

    func skip() {
        completeOnboarding()
        analytics.track(.onboardingSkipped(from: currentStep.analyticsName, to: "skip"))
    }

    private func navigateTo(_ step: Step) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentStep = step
            updateProgress()
        }
        saveProgress()
        analytics.track(.onboardingStepViewed(step: step.analyticsName))
    }

    private func updateProgress() {
        let totalSteps = Double(Step.allCases.count - 1)
        let currentIndex = Double(Step.allCases.firstIndex(of: currentStep) ?? 0)
        progress = currentIndex / totalSteps
    }

    private func completeOnboarding() {
        userDefaults.set(true, forKey: Self.hasCompletedKey)
        isComplete = true
        analytics.track(.onboardingCompleted)
    }

    private func saveProgress() {
        userDefaults.set(currentStep.rawValue, forKey: Self.lastStepKey)
    }

    private func restoreProgress() {
        let savedStep = userDefaults.integer(forKey: Self.lastStepKey)
        if let step = Step(rawValue: savedStep) {
            currentStep = step
            updateProgress()
        }
    }

    func reset() {
        userDefaults.removeObject(forKey: Self.hasCompletedKey)
        userDefaults.removeObject(forKey: Self.lastStepKey)
        currentStep = .welcome
        progress = 0
        isComplete = false
    }
}
```

### Onboarding Container View

```swift
// Sources/Features/Onboarding/OnboardingContainerView.swift
import SwiftUI

struct OnboardingContainerView: View {
    @State private var coordinator = OnboardingCoordinator()
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: coordinator.currentStep)

            VStack(spacing: 0) {
                // Progress indicator
                OnboardingProgressBar(progress: coordinator.progress)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Skip button
                HStack {
                    Spacer()
                    if coordinator.currentStep != .completion {
                        Button("Skip") {
                            coordinator.skip()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Content
                TabView(selection: Binding(
                    get: { coordinator.currentStep },
                    set: { coordinator.skipToStep($0) }
                )) {
                    WelcomeStepView()
                        .tag(OnboardingCoordinator.Step.welcome)

                    FeatureHighlightsView()
                        .tag(OnboardingCoordinator.Step.featureHighlights)

                    NotificationPermissionView()
                        .tag(OnboardingCoordinator.Step.notifications)

                    PersonalizationView()
                        .tag(OnboardingCoordinator.Step.personalization)

                    AccountSetupView()
                        .tag(OnboardingCoordinator.Step.accountSetup)

                    CompletionView()
                        .tag(OnboardingCoordinator.Step.completion)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation buttons
                OnboardingNavigationButtons(
                    currentStep: coordinator.currentStep,
                    onNext: coordinator.nextStep,
                    onPrevious: coordinator.previousStep
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .environment(coordinator)
    }

    private var backgroundColors: [Color] {
        switch coordinator.currentStep {
        case .welcome:
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        case .featureHighlights:
            return [Color(hex: "#f093fb"), Color(hex: "#f5576c")]
        case .notifications:
            return [Color(hex: "#4facfe"), Color(hex: "#00f2fe")]
        case .personalization:
            return [Color(hex: "#43e97b"), Color(hex: "#38f9d7")]
        case .accountSetup:
            return [Color(hex: "#fa709a"), Color(hex: "#fee140")]
        case .completion:
            return [Color(hex: "#a8edea"), Color(hex: "#fed6e3")]
        }
    }
}

// Progress bar component
struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)

                Capsule()
                    .fill(.white)
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.spring(response: 0.4), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// Navigation buttons
struct OnboardingNavigationButtons: View {
    let currentStep: OnboardingCoordinator.Step
    let onNext: () -> Void
    let onPrevious: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if currentStep != .welcome {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }

            Spacer()

            Button(action: onNext) {
                HStack(spacing: 8) {
                    Text(currentStep == .completion ? "Get Started" : "Continue")
                        .font(.system(size: 18, weight: .semibold))

                    if currentStep != .completion {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.black)
                .frame(height: 56)
                .frame(maxWidth: currentStep == .welcome ? .infinity : 180)
                .background(.white)
                .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white)
    }
}
```

### Welcome Step

```swift
// Sources/Features/Onboarding/Steps/WelcomeStepView.swift
import SwiftUI

struct WelcomeStepView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .scaleEffect(logoScale)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        logoScale = 1
                    }
                }

            VStack(spacing: 16) {
                Text("Welcome to AppName")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                            titleOpacity = 1
                        }
                    }

                Text("Your journey to productivity\nstarts here")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .opacity(subtitleOpacity)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                            subtitleOpacity = 1
                        }
                    }
            }

            Spacer()
            Spacer()
        }
        .padding(24)
    }
}
```

### Feature Highlights with Pager

```swift
// Sources/Features/Onboarding/Steps/FeatureHighlightsView.swift
import SwiftUI

struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct FeatureHighlightsView: View {
    @State private var currentPage = 0
    @State private var appeared = false

    private let features: [Feature] = [
        Feature(
            icon: "bolt.fill",
            title: "Lightning Fast",
            description: "Experience blazing fast performance with our optimized engine",
            color: .yellow
        ),
        Feature(
            icon: "lock.shield.fill",
            title: "Secure by Design",
            description: "Your data is encrypted and protected at all times",
            color: .green
        ),
        Feature(
            icon: "sparkles",
            title: "Smart Suggestions",
            description: "AI-powered recommendations tailored just for you",
            color: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Feature cards pager
            TabView(selection: $currentPage) {
                ForEach(features.indices, id: \.self) { index in
                    FeatureCard(feature: features[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 350)

            // Page indicators
            HStack(spacing: 8) {
                ForEach(features.indices, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? .white : .white.opacity(0.4))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            Spacer()
        }
        .padding(24)
    }
}

struct FeatureCard: View {
    let feature: Feature
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon container
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: feature.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(feature.color)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(feature.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
```

### Permission Request View

```swift
// Sources/Features/Onboarding/Steps/NotificationPermissionView.swift
import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequesting = false
    @State private var showBenefits = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated bell icon
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                        .frame(
                            width: 80 + CGFloat(index) * 40,
                            height: 80 + CGFloat(index) * 40
                        )
                        .scaleEffect(showBenefits ? 1.2 : 1)
                        .opacity(showBenefits ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: showBenefits
                        )
                }

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: showBenefits)
            }
            .frame(width: 200, height: 200)
            .onAppear {
                showBenefits = true
            }

            VStack(spacing: 16) {
                Text("Stay in the Loop")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Get notified about important updates,\nmessages, and reminders")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            // Benefits list
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "clock.fill", text: "Timely reminders")
                BenefitRow(icon: "message.fill", text: "New message alerts")
                BenefitRow(icon: "star.fill", text: "Exclusive offers")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Permission button
            if permissionStatus == .notDetermined {
                Button(action: requestPermission) {
                    HStack(spacing: 8) {
                        if isRequesting {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Enable Notifications")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .disabled(isRequesting)
            } else if permissionStatus == .authorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Notifications Enabled")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            }

            Spacer()
        }
        .task {
            await checkPermissionStatus()
        }
    }

    private func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            permissionStatus = settings.authorizationStatus
        }
    }

    private func requestPermission() {
        isRequesting = true
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])

                await MainActor.run {
                    permissionStatus = granted ? .authorized : .denied
                    isRequesting = false
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.2))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
```

### Personalization View

```swift
// Sources/Features/Onboarding/Steps/PersonalizationView.swift
import SwiftUI

struct PersonalizationView: View {
    @State private var selectedInterests: Set<String> = []
    @State private var selectedGoal: String?

    private let interests = [
        ("chart.line.uptrend.xyaxis", "Analytics"),
        ("dollarsign.circle", "Finance"),
        ("heart.fill", "Health"),
        ("brain.head.profile", "Productivity"),
        ("graduationcap.fill", "Learning"),
        ("person.3.fill", "Social"),
        ("paintpalette.fill", "Creative"),
        ("gamecontroller.fill", "Gaming")
    ]

    private let goals = [
        "Stay organized",
        "Build habits",
        "Track progress",
        "Save time"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text("Personalize Your Experience")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Tell us about yourself so we can\ncustomize the app for you")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Interests selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("What interests you?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(interests, id: \.1) { icon, title in
                            InterestChip(
                                icon: icon,
                                title: title,
                                isSelected: selectedInterests.contains(title)
                            ) {
                                if selectedInterests.contains(title) {
                                    selectedInterests.remove(title)
                                } else {
                                    selectedInterests.insert(title)
                                }
                            }
                        }
                    }
                }

                // Goal selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("What's your main goal?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    VStack(spacing: 8) {
                        ForEach(goals, id: \.self) { goal in
                            GoalOption(
                                title: goal,
                                isSelected: selectedGoal == goal
                            ) {
                                selectedGoal = goal
                            }
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct InterestChip: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isSelected ? .white : .white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct GoalOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(isSelected ? .white : .white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}
```

### Completion View

```swift
// Sources/Features/Onboarding/Steps/CompletionView.swift
import SwiftUI

struct CompletionView: View {
    @State private var showConfetti = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                Spacer()

                // Success checkmark
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.green)
                }
                .scaleEffect(checkmarkScale)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2)) {
                        checkmarkScale = 1
                        showConfetti = true
                    }
                }

                VStack(spacing: 16) {
                    Text("You're All Set!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Your personalized experience\nis ready")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                        textOpacity = 1
                    }
                }

                Spacer()
                Spacer()
            }

            // Confetti effect
            if showConfetti {
                ConfettiView()
            }
        }
        .padding(24)
    }
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
                animateParticles()
            }
        }
    }

    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink]

        particles = (0..<50).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...12),
                position: CGPoint(
                    x: size.width / 2,
                    y: size.height / 2
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -200...200),
                    y: CGFloat.random(in: -400...(-100))
                ),
                opacity: 1
            )
        }
    }

    private func animateParticles() {
        withAnimation(.easeOut(duration: 2)) {
            particles = particles.map { particle in
                var updated = particle
                updated.position = CGPoint(
                    x: particle.position.x + particle.velocity.x,
                    y: particle.position.y + particle.velocity.y + 400
                )
                updated.opacity = 0
                return updated
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var position: CGPoint
    var velocity: CGPoint
    var opacity: Double
}
```

## Android Implementation (Kotlin/Jetpack Compose)

### Onboarding Coordinator

```kotlin
// app/src/main/java/com/app/features/onboarding/OnboardingCoordinator.kt
package com.app.features.onboarding

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

val Context.onboardingDataStore: DataStore<Preferences> by preferencesDataStore(name = "onboarding")

enum class OnboardingStep(val analyticsName: String) {
    WELCOME("welcome"),
    FEATURE_HIGHLIGHTS("features"),
    NOTIFICATIONS("notifications"),
    PERSONALIZATION("personalization"),
    ACCOUNT_SETUP("account"),
    COMPLETION("completion");

    companion object {
        fun fromOrdinal(ordinal: Int): OnboardingStep? {
            return entries.getOrNull(ordinal)
        }
    }
}

@Singleton
class OnboardingCoordinator @Inject constructor(
    private val dataStore: DataStore<Preferences>,
    private val analytics: AnalyticsService
) {
    companion object {
        private val HAS_COMPLETED = booleanPreferencesKey("onboarding_completed")
        private val LAST_STEP = intPreferencesKey("onboarding_last_step")
    }

    val hasCompletedOnboarding: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[HAS_COMPLETED] ?: false
    }

    val lastStep: Flow<OnboardingStep> = dataStore.data.map { preferences ->
        val stepOrdinal = preferences[LAST_STEP] ?: 0
        OnboardingStep.fromOrdinal(stepOrdinal) ?: OnboardingStep.WELCOME
    }

    suspend fun saveProgress(step: OnboardingStep) {
        dataStore.edit { preferences ->
            preferences[LAST_STEP] = step.ordinal
        }
        analytics.track(OnboardingEvent.StepViewed(step.analyticsName))
    }

    suspend fun completeOnboarding() {
        dataStore.edit { preferences ->
            preferences[HAS_COMPLETED] = true
        }
        analytics.track(OnboardingEvent.Completed)
    }

    suspend fun skipOnboarding(fromStep: OnboardingStep) {
        dataStore.edit { preferences ->
            preferences[HAS_COMPLETED] = true
        }
        analytics.track(OnboardingEvent.Skipped(fromStep.analyticsName))
    }

    suspend fun reset() {
        dataStore.edit { preferences ->
            preferences.remove(HAS_COMPLETED)
            preferences.remove(LAST_STEP)
        }
    }
}
```

### Onboarding ViewModel

```kotlin
// app/src/main/java/com/app/features/onboarding/OnboardingViewModel.kt
package com.app.features.onboarding

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val coordinator: OnboardingCoordinator
) : ViewModel() {

    private val _currentStep = MutableStateFlow(OnboardingStep.WELCOME)
    val currentStep: StateFlow<OnboardingStep> = _currentStep.asStateFlow()

    private val _isComplete = MutableStateFlow(false)
    val isComplete: StateFlow<Boolean> = _isComplete.asStateFlow()

    val progress: StateFlow<Float> = _currentStep.map { step ->
        step.ordinal.toFloat() / (OnboardingStep.entries.size - 1)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0f)

    init {
        viewModelScope.launch {
            coordinator.lastStep.collect { step ->
                _currentStep.value = step
            }
        }
    }

    fun nextStep() {
        val nextOrdinal = _currentStep.value.ordinal + 1
        val nextStep = OnboardingStep.fromOrdinal(nextOrdinal)

        if (nextStep != null) {
            navigateTo(nextStep)
        } else {
            completeOnboarding()
        }
    }

    fun previousStep() {
        val prevOrdinal = _currentStep.value.ordinal - 1
        OnboardingStep.fromOrdinal(prevOrdinal)?.let { prevStep ->
            navigateTo(prevStep)
        }
    }

    fun skipToStep(step: OnboardingStep) {
        navigateTo(step)
    }

    fun skip() {
        viewModelScope.launch {
            coordinator.skipOnboarding(_currentStep.value)
            _isComplete.value = true
        }
    }

    private fun navigateTo(step: OnboardingStep) {
        _currentStep.value = step
        viewModelScope.launch {
            coordinator.saveProgress(step)
        }
    }

    private fun completeOnboarding() {
        viewModelScope.launch {
            coordinator.completeOnboarding()
            _isComplete.value = true
        }
    }
}
```

### Onboarding Screen

```kotlin
// app/src/main/java/com/app/features/onboarding/OnboardingScreen.kt
package com.app.features.onboarding

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
    viewModel: OnboardingViewModel = hiltViewModel()
) {
    val currentStep by viewModel.currentStep.collectAsState()
    val progress by viewModel.progress.collectAsState()
    val isComplete by viewModel.isComplete.collectAsState()

    val pagerState = rememberPagerState(
        initialPage = currentStep.ordinal,
        pageCount = { OnboardingStep.entries.size }
    )

    // Sync pager with view model
    LaunchedEffect(currentStep) {
        pagerState.animateScrollToPage(currentStep.ordinal)
    }

    LaunchedEffect(pagerState.currentPage) {
        val step = OnboardingStep.fromOrdinal(pagerState.currentPage)
        step?.let { viewModel.skipToStep(it) }
    }

    LaunchedEffect(isComplete) {
        if (isComplete) {
            onComplete()
        }
    }

    val backgroundColors = remember(currentStep) {
        when (currentStep) {
            OnboardingStep.WELCOME -> listOf(Color(0xFF667eea), Color(0xFF764ba2))
            OnboardingStep.FEATURE_HIGHLIGHTS -> listOf(Color(0xFFf093fb), Color(0xFFf5576c))
            OnboardingStep.NOTIFICATIONS -> listOf(Color(0xFF4facfe), Color(0xFF00f2fe))
            OnboardingStep.PERSONALIZATION -> listOf(Color(0xFF43e97b), Color(0xFF38f9d7))
            OnboardingStep.ACCOUNT_SETUP -> listOf(Color(0xFFfa709a), Color(0xFFfee140))
            OnboardingStep.COMPLETION -> listOf(Color(0xFFa8edea), Color(0xFFfed6e3))
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(backgroundColors)
            )
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Progress bar
            OnboardingProgressBar(
                progress = progress,
                modifier = Modifier
                    .padding(horizontal = 24.dp)
                    .padding(top = 16.dp)
            )

            // Skip button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.End
            ) {
                if (currentStep != OnboardingStep.COMPLETION) {
                    TextButton(onClick = viewModel::skip) {
                        Text(
                            text = "Skip",
                            color = Color.White.copy(alpha = 0.8f)
                        )
                    }
                }
            }

            // Content pager
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { page ->
                when (OnboardingStep.fromOrdinal(page)) {
                    OnboardingStep.WELCOME -> WelcomeStep()
                    OnboardingStep.FEATURE_HIGHLIGHTS -> FeatureHighlightsStep()
                    OnboardingStep.NOTIFICATIONS -> NotificationPermissionStep()
                    OnboardingStep.PERSONALIZATION -> PersonalizationStep()
                    OnboardingStep.ACCOUNT_SETUP -> AccountSetupStep()
                    OnboardingStep.COMPLETION -> CompletionStep()
                    null -> Box(Modifier)
                }
            }

            // Navigation buttons
            OnboardingNavigationButtons(
                currentStep = currentStep,
                onNext = viewModel::nextStep,
                onPrevious = viewModel::previousStep,
                modifier = Modifier
                    .padding(horizontal = 24.dp)
                    .padding(bottom = 32.dp)
            )
        }
    }
}

@Composable
private fun OnboardingProgressBar(
    progress: Float,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "progress"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(4.dp)
            .clip(RoundedCornerShape(2.dp))
            .background(Color.White.copy(alpha = 0.3f))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(animatedProgress)
                .fillMaxHeight()
                .clip(RoundedCornerShape(2.dp))
                .background(Color.White)
        )
    }
}

@Composable
private fun OnboardingNavigationButtons(
    currentStep: OnboardingStep,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        AnimatedVisibility(
            visible = currentStep != OnboardingStep.WELCOME,
            enter = fadeIn() + slideInHorizontally(),
            exit = fadeOut() + slideOutHorizontally()
        ) {
            IconButton(
                onClick = onPrevious,
                modifier = Modifier
                    .size(56.dp)
                    .background(
                        Color.White.copy(alpha = 0.2f),
                        CircleShape
                    )
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronLeft,
                    contentDescription = "Previous",
                    tint = Color.White
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = onNext,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color.Black
            ),
            shape = RoundedCornerShape(28.dp),
            modifier = Modifier
                .height(56.dp)
                .widthIn(min = if (currentStep == OnboardingStep.WELCOME) 200.dp else 160.dp)
        ) {
            Text(
                text = if (currentStep == OnboardingStep.COMPLETION) "Get Started" else "Continue",
                style = MaterialTheme.typography.titleMedium
            )
            if (currentStep != OnboardingStep.COMPLETION) {
                Spacer(modifier = Modifier.width(8.dp))
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null
                )
            }
        }
    }
}
```

### Welcome Step

```kotlin
// app/src/main/java/com/app/features/onboarding/steps/WelcomeStep.kt
package com.app.features.onboarding.steps

import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun WelcomeStep() {
    var appeared by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        appeared = true
    }

    val logoScale by animateFloatAsState(
        targetValue = if (appeared) 1f else 0.5f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "logo_scale"
    )

    val titleAlpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(durationMillis = 500, delayMillis = 300),
        label = "title_alpha"
    )

    val subtitleAlpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(durationMillis = 500, delayMillis = 500),
        label = "subtitle_alpha"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(modifier = Modifier.weight(1f))

        // Logo
        Image(
            painter = painterResource(id = R.drawable.app_logo),
            contentDescription = "App Logo",
            modifier = Modifier
                .size(120.dp)
                .scale(logoScale)
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Title
        Text(
            text = "Welcome to AppName",
            style = MaterialTheme.typography.headlineLarge.copy(
                fontSize = 32.sp
            ),
            color = Color.White.copy(alpha = titleAlpha),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Subtitle
        Text(
            text = "Your journey to productivity\nstarts here",
            style = MaterialTheme.typography.bodyLarge,
            color = Color.White.copy(alpha = subtitleAlpha * 0.9f),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.weight(2f))
    }
}
```

### Feature Highlights Step

```kotlin
// app/src/main/java/com/app/features/onboarding/steps/FeatureHighlightsStep.kt
package com.app.features.onboarding.steps

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.pager.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

data class Feature(
    val icon: ImageVector,
    val title: String,
    val description: String,
    val color: Color
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun FeatureHighlightsStep() {
    val features = remember {
        listOf(
            Feature(
                Icons.Default.Bolt,
                "Lightning Fast",
                "Experience blazing fast performance with our optimized engine",
                Color(0xFFFFD700)
            ),
            Feature(
                Icons.Default.Security,
                "Secure by Design",
                "Your data is encrypted and protected at all times",
                Color(0xFF4CAF50)
            ),
            Feature(
                Icons.Default.AutoAwesome,
                "Smart Suggestions",
                "AI-powered recommendations tailored just for you",
                Color(0xFF9C27B0)
            )
        )
    }

    val pagerState = rememberPagerState(pageCount = { features.size })

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.weight(1f))

        // Feature pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.height(350.dp)
        ) { page ->
            FeatureCard(feature = features[page])
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Page indicators
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            features.forEachIndexed { index, _ ->
                val isSelected = pagerState.currentPage == index
                val width by animateDpAsState(
                    targetValue = if (isSelected) 24.dp else 8.dp,
                    label = "indicator_width"
                )

                Box(
                    modifier = Modifier
                        .height(8.dp)
                        .width(width)
                        .background(
                            if (isSelected) Color.White else Color.White.copy(alpha = 0.4f),
                            CircleShape
                        )
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun FeatureCard(feature: Feature) {
    var appeared by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        appeared = true
    }

    val scale by animateFloatAsState(
        targetValue = if (appeared) 1f else 0.5f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy
        ),
        label = "card_scale"
    )

    val alpha by animateFloatAsState(
        targetValue = if (appeared) 1f else 0f,
        animationSpec = tween(300),
        label = "card_alpha"
    )

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .scale(scale)
            .alpha(alpha),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.15f)
        ),
        shape = RoundedCornerShape(24.dp)
    ) {
        Column(
            modifier = Modifier.padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Icon
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .background(
                        feature.color.copy(alpha = 0.2f),
                        CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = feature.icon,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = feature.color
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = feature.title,
                style = MaterialTheme.typography.headlineSmall,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = feature.description,
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.8f),
                textAlign = TextAlign.Center
            )
        }
    }
}
```

## React Native Implementation

### Onboarding Context

```typescript
// src/features/onboarding/OnboardingContext.tsx
import React, { createContext, useContext, useReducer, useCallback, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { analytics } from '@/services/analytics';

export enum OnboardingStep {
  WELCOME = 'welcome',
  FEATURE_HIGHLIGHTS = 'features',
  NOTIFICATIONS = 'notifications',
  PERSONALIZATION = 'personalization',
  ACCOUNT_SETUP = 'account',
  COMPLETION = 'completion',
}

const STEPS_ORDER: OnboardingStep[] = [
  OnboardingStep.WELCOME,
  OnboardingStep.FEATURE_HIGHLIGHTS,
  OnboardingStep.NOTIFICATIONS,
  OnboardingStep.PERSONALIZATION,
  OnboardingStep.ACCOUNT_SETUP,
  OnboardingStep.COMPLETION,
];

interface OnboardingState {
  currentStep: OnboardingStep;
  isComplete: boolean;
  isLoading: boolean;
}

type OnboardingAction =
  | { type: 'SET_STEP'; step: OnboardingStep }
  | { type: 'COMPLETE' }
  | { type: 'RESTORE'; state: Partial<OnboardingState> }
  | { type: 'SET_LOADING'; loading: boolean };

const initialState: OnboardingState = {
  currentStep: OnboardingStep.WELCOME,
  isComplete: false,
  isLoading: true,
};

const STORAGE_KEYS = {
  COMPLETED: 'onboarding_completed',
  LAST_STEP: 'onboarding_last_step',
};

function onboardingReducer(state: OnboardingState, action: OnboardingAction): OnboardingState {
  switch (action.type) {
    case 'SET_STEP':
      return { ...state, currentStep: action.step };
    case 'COMPLETE':
      return { ...state, isComplete: true };
    case 'RESTORE':
      return { ...state, ...action.state, isLoading: false };
    case 'SET_LOADING':
      return { ...state, isLoading: action.loading };
    default:
      return state;
  }
}

interface OnboardingContextValue {
  state: OnboardingState;
  progress: number;
  nextStep: () => void;
  previousStep: () => void;
  skipToStep: (step: OnboardingStep) => void;
  skip: () => void;
  reset: () => Promise<void>;
}

const OnboardingContext = createContext<OnboardingContextValue | null>(null);

export const OnboardingProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(onboardingReducer, initialState);

  const progress = STEPS_ORDER.indexOf(state.currentStep) / (STEPS_ORDER.length - 1);

  // Restore state on mount
  useEffect(() => {
    const restore = async () => {
      try {
        const [completed, lastStep] = await Promise.all([
          AsyncStorage.getItem(STORAGE_KEYS.COMPLETED),
          AsyncStorage.getItem(STORAGE_KEYS.LAST_STEP),
        ]);

        dispatch({
          type: 'RESTORE',
          state: {
            isComplete: completed === 'true',
            currentStep: (lastStep as OnboardingStep) || OnboardingStep.WELCOME,
          },
        });
      } catch (error) {
        dispatch({ type: 'SET_LOADING', loading: false });
      }
    };

    restore();
  }, []);

  const saveProgress = useCallback(async (step: OnboardingStep) => {
    await AsyncStorage.setItem(STORAGE_KEYS.LAST_STEP, step);
    analytics.track('onboarding_step_viewed', { step });
  }, []);

  const nextStep = useCallback(() => {
    const currentIndex = STEPS_ORDER.indexOf(state.currentStep);
    const nextIndex = currentIndex + 1;

    if (nextIndex < STEPS_ORDER.length) {
      const next = STEPS_ORDER[nextIndex];
      dispatch({ type: 'SET_STEP', step: next });
      saveProgress(next);
    } else {
      completeOnboarding();
    }
  }, [state.currentStep]);

  const previousStep = useCallback(() => {
    const currentIndex = STEPS_ORDER.indexOf(state.currentStep);
    const prevIndex = currentIndex - 1;

    if (prevIndex >= 0) {
      const prev = STEPS_ORDER[prevIndex];
      dispatch({ type: 'SET_STEP', step: prev });
      saveProgress(prev);
    }
  }, [state.currentStep]);

  const skipToStep = useCallback((step: OnboardingStep) => {
    dispatch({ type: 'SET_STEP', step });
    saveProgress(step);
  }, []);

  const skip = useCallback(async () => {
    await AsyncStorage.setItem(STORAGE_KEYS.COMPLETED, 'true');
    analytics.track('onboarding_skipped', { from: state.currentStep });
    dispatch({ type: 'COMPLETE' });
  }, [state.currentStep]);

  const completeOnboarding = useCallback(async () => {
    await AsyncStorage.setItem(STORAGE_KEYS.COMPLETED, 'true');
    analytics.track('onboarding_completed');
    dispatch({ type: 'COMPLETE' });
  }, []);

  const reset = useCallback(async () => {
    await Promise.all([
      AsyncStorage.removeItem(STORAGE_KEYS.COMPLETED),
      AsyncStorage.removeItem(STORAGE_KEYS.LAST_STEP),
    ]);
    dispatch({
      type: 'RESTORE',
      state: { currentStep: OnboardingStep.WELCOME, isComplete: false },
    });
  }, []);

  return (
    <OnboardingContext.Provider
      value={{
        state,
        progress,
        nextStep,
        previousStep,
        skipToStep,
        skip,
        reset,
      }}
    >
      {children}
    </OnboardingContext.Provider>
  );
};

export const useOnboarding = () => {
  const context = useContext(OnboardingContext);
  if (!context) {
    throw new Error('useOnboarding must be used within OnboardingProvider');
  }
  return context;
};
```

### Onboarding Screen

```typescript
// src/features/onboarding/OnboardingScreen.tsx
import React, { useRef, useEffect } from 'react';
import {
  View,
  StyleSheet,
  Dimensions,
  TouchableOpacity,
  Text,
  StatusBar,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  interpolateColor,
  useDerivedValue,
} from 'react-native-reanimated';
import PagerView from 'react-native-pager-view';
import LinearGradient from 'react-native-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useOnboarding, OnboardingStep } from './OnboardingContext';
import { WelcomeStep } from './steps/WelcomeStep';
import { FeatureHighlightsStep } from './steps/FeatureHighlightsStep';
import { NotificationPermissionStep } from './steps/NotificationPermissionStep';
import { PersonalizationStep } from './steps/PersonalizationStep';
import { AccountSetupStep } from './steps/AccountSetupStep';
import { CompletionStep } from './steps/CompletionStep';

const { width } = Dimensions.get('window');

const STEPS = [
  OnboardingStep.WELCOME,
  OnboardingStep.FEATURE_HIGHLIGHTS,
  OnboardingStep.NOTIFICATIONS,
  OnboardingStep.PERSONALIZATION,
  OnboardingStep.ACCOUNT_SETUP,
  OnboardingStep.COMPLETION,
];

const BACKGROUND_COLORS = {
  [OnboardingStep.WELCOME]: ['#667eea', '#764ba2'],
  [OnboardingStep.FEATURE_HIGHLIGHTS]: ['#f093fb', '#f5576c'],
  [OnboardingStep.NOTIFICATIONS]: ['#4facfe', '#00f2fe'],
  [OnboardingStep.PERSONALIZATION]: ['#43e97b', '#38f9d7'],
  [OnboardingStep.ACCOUNT_SETUP]: ['#fa709a', '#fee140'],
  [OnboardingStep.COMPLETION]: ['#a8edea', '#fed6e3'],
};

const AnimatedPagerView = Animated.createAnimatedComponent(PagerView);

export const OnboardingScreen: React.FC = () => {
  const insets = useSafeAreaInsets();
  const pagerRef = useRef<PagerView>(null);
  const { state, progress, nextStep, previousStep, skipToStep, skip } = useOnboarding();

  const currentIndex = STEPS.indexOf(state.currentStep);
  const animatedIndex = useSharedValue(currentIndex);

  useEffect(() => {
    animatedIndex.value = withSpring(currentIndex);
    pagerRef.current?.setPage(currentIndex);
  }, [currentIndex]);

  const backgroundColors = useDerivedValue(() => {
    const step = STEPS[Math.round(animatedIndex.value)];
    return BACKGROUND_COLORS[step];
  });

  const handlePageSelected = (e: any) => {
    const page = e.nativeEvent.position;
    const step = STEPS[page];
    if (step !== state.currentStep) {
      skipToStep(step);
    }
  };

  const renderStep = (step: OnboardingStep) => {
    switch (step) {
      case OnboardingStep.WELCOME:
        return <WelcomeStep />;
      case OnboardingStep.FEATURE_HIGHLIGHTS:
        return <FeatureHighlightsStep />;
      case OnboardingStep.NOTIFICATIONS:
        return <NotificationPermissionStep />;
      case OnboardingStep.PERSONALIZATION:
        return <PersonalizationStep />;
      case OnboardingStep.ACCOUNT_SETUP:
        return <AccountSetupStep />;
      case OnboardingStep.COMPLETION:
        return <CompletionStep />;
    }
  };

  return (
    <LinearGradient
      colors={BACKGROUND_COLORS[state.currentStep]}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
      style={styles.container}
    >
      <StatusBar barStyle="light-content" />

      <View style={[styles.content, { paddingTop: insets.top + 16 }]}>
        {/* Progress bar */}
        <ProgressBar progress={progress} />

        {/* Skip button */}
        <View style={styles.skipContainer}>
          {state.currentStep !== OnboardingStep.COMPLETION && (
            <TouchableOpacity onPress={skip}>
              <Text style={styles.skipText}>Skip</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Pager */}
        <AnimatedPagerView
          ref={pagerRef}
          style={styles.pager}
          initialPage={currentIndex}
          onPageSelected={handlePageSelected}
        >
          {STEPS.map((step) => (
            <View key={step} style={styles.page}>
              {renderStep(step)}
            </View>
          ))}
        </AnimatedPagerView>

        {/* Navigation buttons */}
        <NavigationButtons
          currentStep={state.currentStep}
          onNext={nextStep}
          onPrevious={previousStep}
          style={{ paddingBottom: insets.bottom + 32 }}
        />
      </View>
    </LinearGradient>
  );
};

const ProgressBar: React.FC<{ progress: number }> = ({ progress }) => {
  const animatedWidth = useSharedValue(progress);

  useEffect(() => {
    animatedWidth.value = withSpring(progress);
  }, [progress]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${animatedWidth.value * 100}%`,
  }));

  return (
    <View style={styles.progressContainer}>
      <View style={styles.progressTrack}>
        <Animated.View style={[styles.progressFill, animatedStyle]} />
      </View>
    </View>
  );
};

interface NavigationButtonsProps {
  currentStep: OnboardingStep;
  onNext: () => void;
  onPrevious: () -> void;
  style?: any;
}

const NavigationButtons: React.FC<NavigationButtonsProps> = ({
  currentStep,
  onNext,
  onPrevious,
  style,
}) => {
  const showBackButton = currentStep !== OnboardingStep.WELCOME;
  const buttonText = currentStep === OnboardingStep.COMPLETION ? 'Get Started' : 'Continue';

  return (
    <View style={[styles.navigationContainer, style]}>
      {showBackButton && (
        <TouchableOpacity style={styles.backButton} onPress={onPrevious}>
          <Text style={styles.backButtonIcon}>{'<'}</Text>
        </TouchableOpacity>
      )}

      <View style={{ flex: 1 }} />

      <TouchableOpacity
        style={[
          styles.nextButton,
          currentStep === OnboardingStep.WELCOME && styles.nextButtonWide,
        ]}
        onPress={onNext}
      >
        <Text style={styles.nextButtonText}>{buttonText}</Text>
        {currentStep !== OnboardingStep.COMPLETION && (
          <Text style={styles.nextButtonIcon}>{'>'}</Text>
        )}
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
  },
  progressContainer: {
    marginBottom: 8,
  },
  progressTrack: {
    height: 4,
    backgroundColor: 'rgba(255, 255, 255, 0.3)',
    borderRadius: 2,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#fff',
    borderRadius: 2,
  },
  skipContainer: {
    alignItems: 'flex-end',
    paddingVertical: 8,
  },
  skipText: {
    color: 'rgba(255, 255, 255, 0.8)',
    fontSize: 16,
    fontWeight: '500',
  },
  pager: {
    flex: 1,
  },
  page: {
    flex: 1,
  },
  navigationContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  backButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  backButtonIcon: {
    color: '#fff',
    fontSize: 20,
    fontWeight: '600',
  },
  nextButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 56,
    paddingHorizontal: 32,
    backgroundColor: '#fff',
    borderRadius: 28,
    minWidth: 160,
  },
  nextButtonWide: {
    minWidth: 200,
  },
  nextButtonText: {
    color: '#000',
    fontSize: 18,
    fontWeight: '600',
  },
  nextButtonIcon: {
    color: '#000',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
});
```

## Flutter Implementation

### Onboarding Provider

```dart
// lib/features/onboarding/onboarding_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingStep {
  welcome,
  featureHighlights,
  notifications,
  personalization,
  accountSetup,
  completion;

  String get analyticsName => name;
}

class OnboardingState {
  final OnboardingStep currentStep;
  final bool isComplete;
  final bool isLoading;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.isComplete = false,
    this.isLoading = true,
  });

  double get progress {
    return OnboardingStep.values.indexOf(currentStep) /
        (OnboardingStep.values.length - 1);
  }

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    bool? isComplete,
    bool? isLoading,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isComplete: isComplete ?? this.isComplete,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  static const _completedKey = 'onboarding_completed';
  static const _lastStepKey = 'onboarding_last_step';

  final SharedPreferences _prefs;
  final AnalyticsService _analytics;

  OnboardingNotifier(this._prefs, this._analytics)
      : super(const OnboardingState()) {
    _restore();
  }

  Future<void> _restore() async {
    final completed = _prefs.getBool(_completedKey) ?? false;
    final lastStepIndex = _prefs.getInt(_lastStepKey) ?? 0;
    final lastStep = OnboardingStep.values[lastStepIndex];

    state = state.copyWith(
      currentStep: lastStep,
      isComplete: completed,
      isLoading: false,
    );
  }

  void nextStep() {
    final currentIndex = OnboardingStep.values.indexOf(state.currentStep);
    final nextIndex = currentIndex + 1;

    if (nextIndex < OnboardingStep.values.length) {
      final nextStep = OnboardingStep.values[nextIndex];
      _navigateTo(nextStep);
    } else {
      _complete();
    }
  }

  void previousStep() {
    final currentIndex = OnboardingStep.values.indexOf(state.currentStep);
    final prevIndex = currentIndex - 1;

    if (prevIndex >= 0) {
      final prevStep = OnboardingStep.values[prevIndex];
      _navigateTo(prevStep);
    }
  }

  void skipToStep(OnboardingStep step) {
    _navigateTo(step);
  }

  void skip() {
    _analytics.track('onboarding_skipped', {
      'from': state.currentStep.analyticsName,
    });
    _complete();
  }

  void _navigateTo(OnboardingStep step) {
    state = state.copyWith(currentStep: step);
    _prefs.setInt(_lastStepKey, OnboardingStep.values.indexOf(step));
    _analytics.track('onboarding_step_viewed', {
      'step': step.analyticsName,
    });
  }

  void _complete() {
    state = state.copyWith(isComplete: true);
    _prefs.setBool(_completedKey, true);
    _analytics.track('onboarding_completed');
  }

  Future<void> reset() async {
    await _prefs.remove(_completedKey);
    await _prefs.remove(_lastStepKey);
    state = const OnboardingState(isLoading: false);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final analytics = ref.watch(analyticsServiceProvider);
  return OnboardingNotifier(prefs, analytics);
});
```

### Onboarding Screen

```dart
// lib/features/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_provider.dart';
import 'steps/welcome_step.dart';
import 'steps/feature_highlights_step.dart';
import 'steps/notification_permission_step.dart';
import 'steps/personalization_step.dart';
import 'steps/account_setup_step.dart';
import 'steps/completion_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;

  static const _backgroundColors = {
    OnboardingStep.welcome: [Color(0xFF667eea), Color(0xFF764ba2)],
    OnboardingStep.featureHighlights: [Color(0xFFf093fb), Color(0xFFf5576c)],
    OnboardingStep.notifications: [Color(0xFF4facfe), Color(0xFF00f2fe)],
    OnboardingStep.personalization: [Color(0xFF43e97b), Color(0xFF38f9d7)],
    OnboardingStep.accountSetup: [Color(0xFFfa709a), Color(0xFFfee140)],
    OnboardingStep.completion: [Color(0xFFa8edea), Color(0xFFfed6e3)],
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    // Handle completion
    ref.listen<OnboardingState>(onboardingProvider, (previous, next) {
      if (next.isComplete && !previous!.isComplete) {
        widget.onComplete();
      }
    });

    // Sync page controller with state
    final currentIndex = OnboardingStep.values.indexOf(state.currentStep);
    if (_pageController.hasClients &&
        _pageController.page?.round() != currentIndex) {
      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }

    final colors = _backgroundColors[state.currentStep]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: OnboardingProgressBar(progress: state.progress),
            ),

            // Skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (state.currentStep != OnboardingStep.completion)
                    TextButton(
                      onPressed: notifier.skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  final step = OnboardingStep.values[index];
                  if (step != state.currentStep) {
                    notifier.skipToStep(step);
                  }
                },
                children: const [
                  WelcomeStep(),
                  FeatureHighlightsStep(),
                  NotificationPermissionStep(),
                  PersonalizationStep(),
                  AccountSetupStep(),
                  CompletionStep(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: OnboardingNavigationButtons(
                currentStep: state.currentStep,
                onNext: notifier.nextStep,
                onPrevious: notifier.previousStep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingProgressBar extends StatelessWidget {
  final double progress;

  const OnboardingProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingNavigationButtons extends StatelessWidget {
  final OnboardingStep currentStep;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const OnboardingNavigationButtons({
    super.key,
    required this.currentStep,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final showBackButton = currentStep != OnboardingStep.welcome;
    final buttonText = currentStep == OnboardingStep.completion
        ? 'Get Started'
        : 'Continue';

    return Row(
      children: [
        AnimatedOpacity(
          opacity: showBackButton ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedSlide(
            offset: showBackButton ? Offset.zero : const Offset(-0.5, 0),
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: showBackButton ? onPrevious : null,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onNext,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            constraints: BoxConstraints(
              minWidth: currentStep == OnboardingStep.welcome ? 200 : 160,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (currentStep != OnboardingStep.completion) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.black,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

## Output Expectations

When this subagent completes execution, expect:

1. **Onboarding Coordinator**: State management for tracking progress, step navigation, and persistence
2. **Welcome Screens**: Animated introduction with branding and value proposition
3. **Feature Highlights**: Paged carousel showcasing key app features with animations
4. **Permission Requests**: Native permission prompts with benefit explanations for notifications, location, etc.
5. **Personalization Flow**: Interest selection, goal setting, and preference capture
6. **Account Setup**: Optional sign-up/sign-in integration during onboarding
7. **Completion Animation**: Celebratory success state with confetti or similar effects
8. **Progress Tracking**: Visual progress indicators and analytics event logging
9. **Skip/Resume Logic**: Allow skipping while preserving progress for later
10. **A/B Testing Support**: Infrastructure for testing different onboarding variations
