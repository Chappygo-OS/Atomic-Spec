---
name: Mobile Project Scaffolding
platform: mobile
description: Project setup, folder structure, and initial configuration for mobile applications across iOS, Android, and cross-platform frameworks
model: opus
category: mobile/frontend
---

# Mobile Project Scaffolding

## Purpose

Establish consistent, scalable project structures for mobile applications. This subagent handles initial project setup, folder organization, dependency management, and foundational configuration across native and cross-platform development approaches.

## Platform-Specific Scaffolding

### iOS (Swift/SwiftUI)

```
ProjectName/
├── App/
│   ├── ProjectNameApp.swift          # App entry point
│   ├── AppDelegate.swift             # UIKit lifecycle (if needed)
│   └── SceneDelegate.swift           # Scene management
├── Sources/
│   ├── Features/
│   │   ├── Authentication/
│   │   │   ├── Views/
│   │   │   ├── ViewModels/
│   │   │   ├── Models/
│   │   │   └── Services/
│   │   ├── Home/
│   │   ├── Profile/
│   │   └── Settings/
│   ├── Core/
│   │   ├── Network/
│   │   │   ├── APIClient.swift
│   │   │   ├── Endpoints.swift
│   │   │   └── NetworkMonitor.swift
│   │   ├── Storage/
│   │   │   ├── KeychainManager.swift
│   │   │   ├── UserDefaultsManager.swift
│   │   │   └── CoreDataStack.swift
│   │   ├── Navigation/
│   │   │   ├── Router.swift
│   │   │   └── DeepLinkHandler.swift
│   │   └── Utilities/
│   │       ├── Extensions/
│   │       ├── Helpers/
│   │       └── Constants.swift
│   ├── Design/
│   │   ├── Components/
│   │   │   ├── Buttons/
│   │   │   ├── Cards/
│   │   │   ├── Inputs/
│   │   │   └── Modals/
│   │   ├── Theme/
│   │   │   ├── Colors.swift
│   │   │   ├── Typography.swift
│   │   │   └── Spacing.swift
│   │   └── Assets.xcassets/
│   └── Shared/
│       ├── Protocols/
│       ├── Coordinators/
│       └── DependencyInjection/
├── Resources/
│   ├── Localizable.strings
│   ├── Info.plist
│   └── Entitlements/
├── Tests/
│   ├── UnitTests/
│   ├── IntegrationTests/
│   └── UITests/
└── Packages/
    └── LocalPackages/               # Swift Package Manager local packages
```

### Android (Kotlin/Jetpack Compose)

```
app/
├── src/
│   ├── main/
│   │   ├── java/com/company/projectname/
│   │   │   ├── ProjectNameApplication.kt
│   │   │   ├── MainActivity.kt
│   │   │   ├── features/
│   │   │   │   ├── authentication/
│   │   │   │   │   ├── ui/
│   │   │   │   │   │   ├── LoginScreen.kt
│   │   │   │   │   │   └── LoginViewModel.kt
│   │   │   │   │   ├── domain/
│   │   │   │   │   │   ├── models/
│   │   │   │   │   │   └── usecases/
│   │   │   │   │   └── data/
│   │   │   │   │       ├── repository/
│   │   │   │   │       └── datasource/
│   │   │   │   ├── home/
│   │   │   │   ├── profile/
│   │   │   │   └── settings/
│   │   │   ├── core/
│   │   │   │   ├── network/
│   │   │   │   │   ├── ApiService.kt
│   │   │   │   │   ├── NetworkModule.kt
│   │   │   │   │   └── interceptors/
│   │   │   │   ├── storage/
│   │   │   │   │   ├── DataStoreManager.kt
│   │   │   │   │   ├── RoomDatabase.kt
│   │   │   │   │   └── SecureStorage.kt
│   │   │   │   ├── navigation/
│   │   │   │   │   ├── NavGraph.kt
│   │   │   │   │   └── DeepLinkHandler.kt
│   │   │   │   └── utils/
│   │   │   │       ├── extensions/
│   │   │   │       └── Constants.kt
│   │   │   ├── design/
│   │   │   │   ├── components/
│   │   │   │   │   ├── buttons/
│   │   │   │   │   ├── cards/
│   │   │   │   │   └── inputs/
│   │   │   │   └── theme/
│   │   │   │       ├── Color.kt
│   │   │   │       ├── Type.kt
│   │   │   │       └── Theme.kt
│   │   │   └── di/
│   │   │       ├── AppModule.kt
│   │   │       ├── NetworkModule.kt
│   │   │       └── RepositoryModule.kt
│   │   ├── res/
│   │   │   ├── drawable/
│   │   │   ├── values/
│   │   │   │   ├── strings.xml
│   │   │   │   ├── colors.xml
│   │   │   │   └── themes.xml
│   │   │   └── xml/
│   │   └── AndroidManifest.xml
│   ├── test/                         # Unit tests
│   └── androidTest/                  # Instrumented tests
├── build.gradle.kts
└── proguard-rules.pro
```

### React Native

```
ProjectName/
├── src/
│   ├── app/
│   │   ├── App.tsx
│   │   ├── navigation/
│   │   │   ├── RootNavigator.tsx
│   │   │   ├── AuthNavigator.tsx
│   │   │   └── MainNavigator.tsx
│   │   └── providers/
│   │       ├── ThemeProvider.tsx
│   │       └── AuthProvider.tsx
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   ├── components/
│   │   │   ├── hooks/
│   │   │   ├── services/
│   │   │   └── types.ts
│   │   ├── home/
│   │   ├── profile/
│   │   └── settings/
│   ├── shared/
│   │   ├── components/
│   │   │   ├── buttons/
│   │   │   ├── inputs/
│   │   │   ├── cards/
│   │   │   └── modals/
│   │   ├── hooks/
│   │   │   ├── useApi.ts
│   │   │   ├── useStorage.ts
│   │   │   └── usePermissions.ts
│   │   ├── services/
│   │   │   ├── api/
│   │   │   ├── storage/
│   │   │   └── analytics/
│   │   ├── utils/
│   │   │   ├── helpers.ts
│   │   │   ├── validators.ts
│   │   │   └── formatters.ts
│   │   └── types/
│   │       ├── api.ts
│   │       ├── navigation.ts
│   │       └── common.ts
│   ├── design/
│   │   ├── theme/
│   │   │   ├── colors.ts
│   │   │   ├── typography.ts
│   │   │   ├── spacing.ts
│   │   │   └── index.ts
│   │   └── tokens/
│   ├── assets/
│   │   ├── images/
│   │   ├── fonts/
│   │   └── icons/
│   └── i18n/
│       ├── locales/
│       │   ├── en.json
│       │   └── es.json
│       └── index.ts
├── __tests__/
├── ios/
├── android/
├── metro.config.js
├── babel.config.js
├── tsconfig.json
└── package.json
```

### Flutter

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── routes.dart
│   └── bindings/
├── features/
│   ├── authentication/
│   │   ├── presentation/
│   │   │   ├── pages/
│   │   │   ├── widgets/
│   │   │   └── controllers/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── data/
│   │       ├── models/
│   │       ├── repositories/
│   │       └── datasources/
│   ├── home/
│   ├── profile/
│   └── settings/
├── core/
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── interceptors/
│   │   └── endpoints.dart
│   ├── storage/
│   │   ├── secure_storage.dart
│   │   ├── local_storage.dart
│   │   └── database/
│   ├── navigation/
│   │   ├── app_router.dart
│   │   └── route_guards.dart
│   ├── di/
│   │   └── injection_container.dart
│   └── utils/
│       ├── extensions/
│       ├── helpers/
│       └── constants.dart
├── design/
│   ├── components/
│   │   ├── buttons/
│   │   ├── cards/
│   │   ├── inputs/
│   │   └── modals/
│   └── theme/
│       ├── app_colors.dart
│       ├── app_typography.dart
│       ├── app_spacing.dart
│       └── app_theme.dart
├── shared/
│   ├── widgets/
│   ├── models/
│   └── services/
└── l10n/
    ├── app_en.arb
    └── app_es.arb
```

## Dependency Configuration

### iOS - Package.swift / SPM

```swift
// Package.swift for local packages
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ProjectNameCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.5.0")
    ],
    targets: [
        .target(name: "Networking", dependencies: ["Alamofire"]),
        .target(name: "Storage", dependencies: []),
        .target(name: "DesignSystem", dependencies: [])
    ]
)
```

### Android - build.gradle.kts

```kotlin
// app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
    id("com.google.dagger.hilt.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.company.projectname"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.company.projectname"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
}

dependencies {
    // Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.01.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")

    // Navigation
    implementation("androidx.navigation:navigation-compose:2.7.6")

    // Dependency Injection
    implementation("com.google.dagger:hilt-android:2.50")
    ksp("com.google.dagger:hilt-compiler:2.50")

    // Networking
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.2")

    // Image Loading
    implementation("io.coil-kt:coil-compose:2.5.0")

    // Storage
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")
    implementation("androidx.datastore:datastore-preferences:1.0.0")
}
```

### React Native - package.json

```json
{
  "name": "ProjectName",
  "version": "1.0.0",
  "dependencies": {
    "react": "18.2.0",
    "react-native": "0.73.2",
    "@react-navigation/native": "^6.1.9",
    "@react-navigation/native-stack": "^6.9.17",
    "@tanstack/react-query": "^5.17.0",
    "zustand": "^4.4.7",
    "react-native-mmkv": "^2.11.0",
    "react-native-reanimated": "^3.6.1",
    "react-native-gesture-handler": "^2.14.0",
    "axios": "^1.6.5",
    "zod": "^3.22.4",
    "react-hook-form": "^7.49.3",
    "@hookform/resolvers": "^3.3.4"
  },
  "devDependencies": {
    "@types/react": "^18.2.48",
    "typescript": "^5.3.3",
    "jest": "^29.7.0",
    "@testing-library/react-native": "^12.4.3"
  }
}
```

### Flutter - pubspec.yaml

```yaml
name: project_name
description: A new Flutter project.
version: 1.0.0+1

environment:
  sdk: ">=3.2.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.4.9

  # Navigation
  go_router: ^13.0.1

  # Networking
  dio: ^5.4.0
  retrofit: ^4.0.3

  # Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0

  # DI
  get_it: ^7.6.4
  injectable: ^2.3.2

  # Utilities
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1
  intl: ^0.18.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.8
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  retrofit_generator: ^8.0.6
  injectable_generator: ^2.4.1
  hive_generator: ^2.0.1
```

## Environment Configuration

### iOS Environment Setup

```swift
// Configuration.swift
import Foundation

enum Environment {
    case development
    case staging
    case production

    static var current: Environment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    var baseURL: URL {
        switch self {
        case .development:
            return URL(string: "https://dev-api.example.com")!
        case .staging:
            return URL(string: "https://staging-api.example.com")!
        case .production:
            return URL(string: "https://api.example.com")!
        }
    }

    var analyticsEnabled: Bool {
        self == .production
    }
}
```

### Android Build Variants

```kotlin
// build.gradle.kts
android {
    buildTypes {
        debug {
            isDebuggable = true
            buildConfigField("String", "BASE_URL", "\"https://dev-api.example.com\"")
            buildConfigField("Boolean", "ANALYTICS_ENABLED", "false")
        }

        create("staging") {
            initWith(getByName("debug"))
            buildConfigField("String", "BASE_URL", "\"https://staging-api.example.com\"")
        }

        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            buildConfigField("String", "BASE_URL", "\"https://api.example.com\"")
            buildConfigField("Boolean", "ANALYTICS_ENABLED", "true")
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
        }
        create("prod") {
            dimension = "environment"
        }
    }
}
```

### Cross-Platform Environment

```typescript
// env.config.ts (React Native)
const ENV = {
  development: {
    apiUrl: 'https://dev-api.example.com',
    analyticsEnabled: false,
    logLevel: 'debug'
  },
  staging: {
    apiUrl: 'https://staging-api.example.com',
    analyticsEnabled: false,
    logLevel: 'info'
  },
  production: {
    apiUrl: 'https://api.example.com',
    analyticsEnabled: true,
    logLevel: 'error'
  }
} as const;

type EnvName = keyof typeof ENV;

const currentEnv: EnvName = __DEV__ ? 'development' : 'production';

export const config = ENV[currentEnv];
```

## Initial Setup Checklist

### Pre-Development Setup

1. **Version Control**
   - Initialize git repository
   - Configure .gitignore with platform-specific entries
   - Set up branch protection rules
   - Configure commit hooks (Husky for RN, SwiftLint/Ktlint for native)

2. **Code Quality**
   - Configure linters (SwiftLint, Ktlint, ESLint)
   - Set up formatters (SwiftFormat, Spotless, Prettier)
   - Configure pre-commit hooks

3. **CI/CD Foundation**
   - Create build scripts
   - Configure fastlane lanes (iOS)
   - Set up Gradle tasks (Android)
   - Define environment configurations

4. **Documentation**
   - Create README.md with setup instructions
   - Document architecture decisions
   - Create contribution guidelines

### Post-Scaffold Verification

```bash
# iOS verification
xcodebuild -list -project ProjectName.xcodeproj
swift build  # for SPM packages

# Android verification
./gradlew tasks --all
./gradlew assembleDebug

# React Native verification
npm install && npm run start
npx react-native run-ios
npx react-native run-android

# Flutter verification
flutter pub get
flutter analyze
flutter run
```

## Template Files

### App Entry Points

```swift
// iOS - ProjectNameApp.swift
import SwiftUI

@main
struct ProjectNameApp: App {
    @StateObject private var appState = AppState()

    init() {
        setupDependencies()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }

    private func setupDependencies() {
        DependencyContainer.shared.registerDefaults()
    }
}
```

```kotlin
// Android - ProjectNameApplication.kt
@HiltAndroidApp
class ProjectNameApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        initializeLogging()
        initializeCrashReporting()
    }

    private fun initializeLogging() {
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
    }
}
```

## Output Expectations

When scaffolding a project, the subagent should:

1. Create complete folder structure based on target platform
2. Generate all boilerplate configuration files
3. Set up dependency management with commonly needed libraries
4. Configure multiple build environments
5. Create initial theme/design system files
6. Set up navigation infrastructure
7. Configure dependency injection containers
8. Generate README with setup instructions
9. Create .gitignore appropriate for platform
10. Set up testing infrastructure
