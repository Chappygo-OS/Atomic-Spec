---
name: Mobile Internationalization
platform: mobile
description: i18n and l10n implementation including string localization, date/number formatting, and plural handling for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Internationalization

## Purpose

Implement comprehensive internationalization (i18n) and localization (l10n) systems that support multiple languages, regional formats, pluralization rules, and dynamic content. The localization layer should integrate seamlessly with the UI and support runtime language switching.

## Localization Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Localization Components                        │
├─────────────────────────────────────────────────────────────────┤
│  String Resources     │  Formatters          │  Configuration   │
│  - Translation files  │  - Date/Time         │  - Locale detect │
│  - Pluralization      │  - Numbers           │  - Fallback chain│
│  - Interpolation      │  - Currency          │  - Storage       │
│  - Context strings    │  - Relative time     │  - Runtime switch│
└─────────────────────────────────────────────────────────────────┘
```

## iOS Localization

### String Catalog Setup

```swift
// Localizable.xcstrings (String Catalog format - Xcode 15+)
// Automatically generated, edit through Xcode

// String extension for localization
extension String {
    var localized: String {
        String(localized: LocalizationValue(self))
    }

    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }

    func localized(comment: String) -> String {
        NSLocalizedString(self, comment: comment)
    }
}

// LocalizedStrings.swift - Type-safe string keys
enum L10n {
    enum Common {
        static let ok = String(localized: "common.ok", defaultValue: "OK")
        static let cancel = String(localized: "common.cancel", defaultValue: "Cancel")
        static let save = String(localized: "common.save", defaultValue: "Save")
        static let delete = String(localized: "common.delete", defaultValue: "Delete")
        static let loading = String(localized: "common.loading", defaultValue: "Loading...")
        static let error = String(localized: "common.error", defaultValue: "Error")
        static let retry = String(localized: "common.retry", defaultValue: "Retry")
    }

    enum Auth {
        static let signIn = String(localized: "auth.signIn", defaultValue: "Sign In")
        static let signUp = String(localized: "auth.signUp", defaultValue: "Sign Up")
        static let signOut = String(localized: "auth.signOut", defaultValue: "Sign Out")
        static let email = String(localized: "auth.email", defaultValue: "Email")
        static let password = String(localized: "auth.password", defaultValue: "Password")
        static let forgotPassword = String(localized: "auth.forgotPassword", defaultValue: "Forgot Password?")

        static func welcomeBack(name: String) -> String {
            String(localized: "auth.welcomeBack \(name)", defaultValue: "Welcome back, \(name)!")
        }
    }

    enum Product {
        static let addToCart = String(localized: "product.addToCart", defaultValue: "Add to Cart")
        static let outOfStock = String(localized: "product.outOfStock", defaultValue: "Out of Stock")
        static let inStock = String(localized: "product.inStock", defaultValue: "In Stock")

        static func itemsCount(_ count: Int) -> String {
            String(localized: "product.itemsCount \(count)", defaultValue: "\(count) items")
        }

        static func priceRange(min: String, max: String) -> String {
            String(localized: "product.priceRange \(min) \(max)", defaultValue: "\(min) - \(max)")
        }
    }

    enum Cart {
        static let title = String(localized: "cart.title", defaultValue: "Shopping Cart")
        static let empty = String(localized: "cart.empty", defaultValue: "Your cart is empty")
        static let checkout = String(localized: "cart.checkout", defaultValue: "Checkout")

        static func subtotal(amount: String) -> String {
            String(localized: "cart.subtotal \(amount)", defaultValue: "Subtotal: \(amount)")
        }
    }

    enum Settings {
        static let title = String(localized: "settings.title", defaultValue: "Settings")
        static let language = String(localized: "settings.language", defaultValue: "Language")
        static let notifications = String(localized: "settings.notifications", defaultValue: "Notifications")
        static let theme = String(localized: "settings.theme", defaultValue: "Theme")
        static let about = String(localized: "settings.about", defaultValue: "About")
    }
}
```

### Locale Manager

```swift
// LocaleManager.swift
import Foundation

@Observable
final class LocaleManager {
    static let shared = LocaleManager()

    var currentLocale: Locale {
        didSet {
            saveLocale()
            NotificationCenter.default.post(name: .localeDidChange, object: nil)
        }
    }

    var currentLanguage: String {
        currentLocale.language.languageCode?.identifier ?? "en"
    }

    private let supportedLanguages = ["en", "es", "fr", "de", "ja", "zh-Hans", "ar"]

    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage"),
           let locale = Locale(identifier: savedLanguage) as Locale? {
            self.currentLocale = locale
        } else {
            self.currentLocale = Locale.current
        }
    }

    func setLanguage(_ languageCode: String) {
        guard supportedLanguages.contains(languageCode) else { return }
        currentLocale = Locale(identifier: languageCode)

        // Update app bundle
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    func getSupportedLanguages() -> [(code: String, name: String)] {
        supportedLanguages.map { code in
            let locale = Locale(identifier: code)
            let name = locale.localizedString(forIdentifier: code) ?? code
            return (code, name)
        }
    }

    private func saveLocale() {
        UserDefaults.standard.set(currentLocale.identifier, forKey: "appLanguage")
    }
}

extension Notification.Name {
    static let localeDidChange = Notification.Name("localeDidChange")
}
```

### Formatters

```swift
// Formatters.swift
import Foundation

enum AppFormatters {
    // MARK: - Date Formatters

    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: date)
    }

    static func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: date)
    }

    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: date)
    }

    static func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocaleManager.shared.currentLocale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Number Formatters

    static func formatNumber(_ number: Double, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    static func formatCurrency(_ amount: Double, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: NSNumber(value: amount)) ?? String(amount)
    }

    static func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func formatCompactNumber(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.notation = .compactName
        formatter.locale = LocaleManager.shared.currentLocale
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    // MARK: - Distance & Measurement

    static func formatDistance(_ meters: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.locale = LocaleManager.shared.currentLocale
        formatter.unitOptions = .naturalScale

        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }

    static func formatWeight(_ kilograms: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.locale = LocaleManager.shared.currentLocale

        let measurement = Measurement(value: kilograms, unit: UnitMass.kilograms)
        return formatter.string(from: measurement)
    }
}
```

## Android Localization

### String Resources

```xml
<!-- res/values/strings.xml (English - Default) -->
<resources>
    <string name="app_name">MyApp</string>

    <!-- Common -->
    <string name="common_ok">OK</string>
    <string name="common_cancel">Cancel</string>
    <string name="common_save">Save</string>
    <string name="common_delete">Delete</string>
    <string name="common_loading">Loading…</string>
    <string name="common_error">Error</string>
    <string name="common_retry">Retry</string>

    <!-- Auth -->
    <string name="auth_sign_in">Sign In</string>
    <string name="auth_sign_up">Sign Up</string>
    <string name="auth_sign_out">Sign Out</string>
    <string name="auth_email">Email</string>
    <string name="auth_password">Password</string>
    <string name="auth_forgot_password">Forgot Password?</string>
    <string name="auth_welcome_back">Welcome back, %1$s!</string>

    <!-- Product -->
    <string name="product_add_to_cart">Add to Cart</string>
    <string name="product_out_of_stock">Out of Stock</string>
    <string name="product_in_stock">In Stock</string>
    <string name="product_price_range">%1$s - %2$s</string>

    <!-- Plurals -->
    <plurals name="product_items_count">
        <item quantity="one">%d item</item>
        <item quantity="other">%d items</item>
    </plurals>

    <plurals name="cart_items">
        <item quantity="zero">No items</item>
        <item quantity="one">%d item</item>
        <item quantity="other">%d items</item>
    </plurals>

    <!-- Cart -->
    <string name="cart_title">Shopping Cart</string>
    <string name="cart_empty">Your cart is empty</string>
    <string name="cart_checkout">Checkout</string>
    <string name="cart_subtotal">Subtotal: %1$s</string>

    <!-- Settings -->
    <string name="settings_title">Settings</string>
    <string name="settings_language">Language</string>
    <string name="settings_notifications">Notifications</string>
    <string name="settings_theme">Theme</string>
    <string name="settings_about">About</string>
</resources>

<!-- res/values-es/strings.xml (Spanish) -->
<resources>
    <string name="app_name">MiApp</string>

    <string name="common_ok">Aceptar</string>
    <string name="common_cancel">Cancelar</string>
    <string name="common_save">Guardar</string>
    <string name="common_delete">Eliminar</string>
    <string name="common_loading">Cargando…</string>
    <string name="common_error">Error</string>
    <string name="common_retry">Reintentar</string>

    <string name="auth_sign_in">Iniciar Sesión</string>
    <string name="auth_sign_up">Registrarse</string>
    <string name="auth_sign_out">Cerrar Sesión</string>
    <string name="auth_email">Correo Electrónico</string>
    <string name="auth_password">Contraseña</string>
    <string name="auth_forgot_password">¿Olvidaste tu contraseña?</string>
    <string name="auth_welcome_back">¡Bienvenido de nuevo, %1$s!</string>

    <plurals name="product_items_count">
        <item quantity="one">%d artículo</item>
        <item quantity="other">%d artículos</item>
    </plurals>
</resources>
```

### Locale Manager

```kotlin
// LocaleManager.kt
@Singleton
class LocaleManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val preferencesManager: AppPreferencesManager
) {
    private val _currentLocale = MutableStateFlow(getSystemLocale())
    val currentLocale: StateFlow<Locale> = _currentLocale.asStateFlow()

    val supportedLanguages = listOf(
        LanguageOption("en", "English"),
        LanguageOption("es", "Español"),
        LanguageOption("fr", "Français"),
        LanguageOption("de", "Deutsch"),
        LanguageOption("ja", "日本語"),
        LanguageOption("zh", "中文"),
        LanguageOption("ar", "العربية")
    )

    data class LanguageOption(
        val code: String,
        val displayName: String
    )

    init {
        loadSavedLocale()
    }

    private fun loadSavedLocale() {
        val savedLanguage = runBlocking {
            preferencesManager.preferences.first().language
        }
        _currentLocale.value = Locale(savedLanguage)
    }

    suspend fun setLanguage(languageCode: String) {
        val locale = Locale(languageCode)
        _currentLocale.value = locale
        preferencesManager.setLanguage(languageCode)

        // Update app configuration
        updateConfiguration(locale)
    }

    fun updateConfiguration(locale: Locale) {
        Locale.setDefault(locale)

        val config = context.resources.configuration
        config.setLocale(locale)
        config.setLayoutDirection(locale)

        @Suppress("DEPRECATION")
        context.resources.updateConfiguration(config, context.resources.displayMetrics)
    }

    fun wrapContext(context: Context): Context {
        val locale = _currentLocale.value
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        config.setLayoutDirection(locale)
        return context.createConfigurationContext(config)
    }

    private fun getSystemLocale(): Locale {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            context.resources.configuration.locale
        }
    }
}

// StringResources.kt - Type-safe string access
object Strings {
    @Composable
    fun common_ok() = stringResource(R.string.common_ok)

    @Composable
    fun common_cancel() = stringResource(R.string.common_cancel)

    @Composable
    fun auth_welcome_back(name: String) = stringResource(R.string.auth_welcome_back, name)

    @Composable
    fun product_items_count(count: Int) = pluralStringResource(
        R.plurals.product_items_count,
        count,
        count
    )

    @Composable
    fun cart_subtotal(amount: String) = stringResource(R.string.cart_subtotal, amount)
}
```

### Formatters

```kotlin
// Formatters.kt
object AppFormatters {

    // Date/Time Formatters
    fun formatDate(
        date: LocalDate,
        style: FormatStyle = FormatStyle.MEDIUM,
        locale: Locale = Locale.getDefault()
    ): String {
        return date.format(DateTimeFormatter.ofLocalizedDate(style).withLocale(locale))
    }

    fun formatTime(
        time: LocalTime,
        style: FormatStyle = FormatStyle.SHORT,
        locale: Locale = Locale.getDefault()
    ): String {
        return time.format(DateTimeFormatter.ofLocalizedTime(style).withLocale(locale))
    }

    fun formatDateTime(
        dateTime: LocalDateTime,
        locale: Locale = Locale.getDefault()
    ): String {
        return dateTime.format(
            DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
                .withLocale(locale)
        )
    }

    fun formatRelativeTime(
        dateTime: LocalDateTime,
        locale: Locale = Locale.getDefault()
    ): String {
        val now = LocalDateTime.now()
        val duration = Duration.between(dateTime, now)

        return when {
            duration.toMinutes() < 1 -> "just now"
            duration.toMinutes() < 60 -> "${duration.toMinutes()} minutes ago"
            duration.toHours() < 24 -> "${duration.toHours()} hours ago"
            duration.toDays() < 7 -> "${duration.toDays()} days ago"
            else -> formatDate(dateTime.toLocalDate(), locale = locale)
        }
    }

    // Number Formatters
    fun formatNumber(
        number: Double,
        decimals: Int = 0,
        locale: Locale = Locale.getDefault()
    ): String {
        return NumberFormat.getNumberInstance(locale).apply {
            minimumFractionDigits = decimals
            maximumFractionDigits = decimals
        }.format(number)
    }

    fun formatCurrency(
        amount: Double,
        currencyCode: String = "USD",
        locale: Locale = Locale.getDefault()
    ): String {
        val format = NumberFormat.getCurrencyInstance(locale)
        format.currency = Currency.getInstance(currencyCode)
        return format.format(amount)
    }

    fun formatPercent(
        value: Double,
        locale: Locale = Locale.getDefault()
    ): String {
        return NumberFormat.getPercentInstance(locale).apply {
            minimumFractionDigits = 0
            maximumFractionDigits = 1
        }.format(value)
    }

    fun formatCompactNumber(
        number: Long,
        locale: Locale = Locale.getDefault()
    ): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            NumberFormat.getCompactNumberInstance(locale, NumberFormat.Style.SHORT)
                .format(number)
        } else {
            when {
                number >= 1_000_000_000 -> "${number / 1_000_000_000}B"
                number >= 1_000_000 -> "${number / 1_000_000}M"
                number >= 1_000 -> "${number / 1_000}K"
                else -> number.toString()
            }
        }
    }
}
```

## React Native Localization

### i18n Setup with i18next

```typescript
// i18n/index.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import * as RNLocalize from 'react-native-localize';
import { mmkvStorage } from '../services/storage';

import en from './locales/en.json';
import es from './locales/es.json';
import fr from './locales/fr.json';
import de from './locales/de.json';
import ja from './locales/ja.json';
import ar from './locales/ar.json';

const resources = {
  en: { translation: en },
  es: { translation: es },
  fr: { translation: fr },
  de: { translation: de },
  ja: { translation: ja },
  ar: { translation: ar },
};

const supportedLanguages = Object.keys(resources);

const getDeviceLanguage = (): string => {
  const locales = RNLocalize.getLocales();
  const deviceLanguage = locales[0]?.languageCode || 'en';
  return supportedLanguages.includes(deviceLanguage) ? deviceLanguage : 'en';
};

const getSavedLanguage = (): string | null => {
  return mmkvStorage.getString('appLanguage');
};

i18n.use(initReactI18next).init({
  resources,
  lng: getSavedLanguage() || getDeviceLanguage(),
  fallbackLng: 'en',
  interpolation: {
    escapeValue: false,
  },
  react: {
    useSuspense: false,
  },
});

export const changeLanguage = async (languageCode: string) => {
  if (supportedLanguages.includes(languageCode)) {
    await i18n.changeLanguage(languageCode);
    mmkvStorage.setString('appLanguage', languageCode);
  }
};

export const getSupportedLanguages = () => [
  { code: 'en', name: 'English', nativeName: 'English' },
  { code: 'es', name: 'Spanish', nativeName: 'Español' },
  { code: 'fr', name: 'French', nativeName: 'Français' },
  { code: 'de', name: 'German', nativeName: 'Deutsch' },
  { code: 'ja', name: 'Japanese', nativeName: '日本語' },
  { code: 'ar', name: 'Arabic', nativeName: 'العربية' },
];

export default i18n;
```

### Translation Files

```json
// i18n/locales/en.json
{
  "common": {
    "ok": "OK",
    "cancel": "Cancel",
    "save": "Save",
    "delete": "Delete",
    "loading": "Loading...",
    "error": "Error",
    "retry": "Retry"
  },
  "auth": {
    "signIn": "Sign In",
    "signUp": "Sign Up",
    "signOut": "Sign Out",
    "email": "Email",
    "password": "Password",
    "forgotPassword": "Forgot Password?",
    "welcomeBack": "Welcome back, {{name}}!"
  },
  "product": {
    "addToCart": "Add to Cart",
    "outOfStock": "Out of Stock",
    "inStock": "In Stock",
    "itemsCount_one": "{{count}} item",
    "itemsCount_other": "{{count}} items",
    "priceRange": "{{min}} - {{max}}"
  },
  "cart": {
    "title": "Shopping Cart",
    "empty": "Your cart is empty",
    "checkout": "Checkout",
    "subtotal": "Subtotal: {{amount}}"
  },
  "settings": {
    "title": "Settings",
    "language": "Language",
    "notifications": "Notifications",
    "theme": "Theme",
    "about": "About"
  }
}

// i18n/locales/es.json
{
  "common": {
    "ok": "Aceptar",
    "cancel": "Cancelar",
    "save": "Guardar",
    "delete": "Eliminar",
    "loading": "Cargando...",
    "error": "Error",
    "retry": "Reintentar"
  },
  "auth": {
    "signIn": "Iniciar Sesión",
    "signUp": "Registrarse",
    "signOut": "Cerrar Sesión",
    "email": "Correo Electrónico",
    "password": "Contraseña",
    "forgotPassword": "¿Olvidaste tu contraseña?",
    "welcomeBack": "¡Bienvenido de nuevo, {{name}}!"
  },
  "product": {
    "addToCart": "Añadir al Carrito",
    "outOfStock": "Agotado",
    "inStock": "En Stock",
    "itemsCount_one": "{{count}} artículo",
    "itemsCount_other": "{{count}} artículos",
    "priceRange": "{{min}} - {{max}}"
  }
}
```

### Formatters

```typescript
// utils/formatters.ts
import i18n from '../i18n';

export const formatDate = (
  date: Date | string,
  options: Intl.DateTimeFormatOptions = { dateStyle: 'medium' }
): string => {
  const d = typeof date === 'string' ? new Date(date) : date;
  return new Intl.DateTimeFormat(i18n.language, options).format(d);
};

export const formatTime = (
  date: Date | string,
  options: Intl.DateTimeFormatOptions = { timeStyle: 'short' }
): string => {
  const d = typeof date === 'string' ? new Date(date) : date;
  return new Intl.DateTimeFormat(i18n.language, options).format(d);
};

export const formatDateTime = (date: Date | string): string => {
  return formatDate(date, { dateStyle: 'medium', timeStyle: 'short' });
};

export const formatRelativeTime = (date: Date | string): string => {
  const d = typeof date === 'string' ? new Date(date) : date;
  const now = new Date();
  const diffInSeconds = Math.floor((now.getTime() - d.getTime()) / 1000);

  const rtf = new Intl.RelativeTimeFormat(i18n.language, { numeric: 'auto' });

  if (diffInSeconds < 60) return rtf.format(-diffInSeconds, 'second');
  if (diffInSeconds < 3600) return rtf.format(-Math.floor(diffInSeconds / 60), 'minute');
  if (diffInSeconds < 86400) return rtf.format(-Math.floor(diffInSeconds / 3600), 'hour');
  if (diffInSeconds < 604800) return rtf.format(-Math.floor(diffInSeconds / 86400), 'day');
  if (diffInSeconds < 2592000) return rtf.format(-Math.floor(diffInSeconds / 604800), 'week');
  return formatDate(date);
};

export const formatNumber = (
  number: number,
  options: Intl.NumberFormatOptions = {}
): string => {
  return new Intl.NumberFormat(i18n.language, options).format(number);
};

export const formatCurrency = (
  amount: number,
  currency: string = 'USD'
): string => {
  return new Intl.NumberFormat(i18n.language, {
    style: 'currency',
    currency,
  }).format(amount);
};

export const formatPercent = (value: number): string => {
  return new Intl.NumberFormat(i18n.language, {
    style: 'percent',
    minimumFractionDigits: 0,
    maximumFractionDigits: 1,
  }).format(value);
};

export const formatCompactNumber = (number: number): string => {
  return new Intl.NumberFormat(i18n.language, {
    notation: 'compact',
    compactDisplay: 'short',
  }).format(number);
};
```

### Usage Hook

```typescript
// hooks/useLocalization.ts
import { useTranslation } from 'react-i18next';
import { useCallback } from 'react';
import { changeLanguage, getSupportedLanguages } from '../i18n';
import * as formatters from '../utils/formatters';

export const useLocalization = () => {
  const { t, i18n } = useTranslation();

  const setLanguage = useCallback(async (languageCode: string) => {
    await changeLanguage(languageCode);
  }, []);

  return {
    t,
    currentLanguage: i18n.language,
    setLanguage,
    supportedLanguages: getSupportedLanguages(),
    formatDate: formatters.formatDate,
    formatTime: formatters.formatTime,
    formatDateTime: formatters.formatDateTime,
    formatRelativeTime: formatters.formatRelativeTime,
    formatNumber: formatters.formatNumber,
    formatCurrency: formatters.formatCurrency,
    formatPercent: formatters.formatPercent,
    formatCompactNumber: formatters.formatCompactNumber,
  };
};
```

## Flutter Localization

### Setup with flutter_localizations

```dart
// l10n/app_localizations.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('ja'),
    Locale('ar'),
  ];

  // Translations loaded from ARB files
  late final Map<String, String> _localizedStrings;

  Future<void> load() async {
    // Load from generated ARB files
  }

  String translate(String key) => _localizedStrings[key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
```

### ARB Files

```json
// l10n/app_en.arb
{
  "@@locale": "en",
  "commonOk": "OK",
  "commonCancel": "Cancel",
  "commonSave": "Save",
  "commonDelete": "Delete",
  "commonLoading": "Loading...",
  "commonError": "Error",
  "commonRetry": "Retry",

  "authSignIn": "Sign In",
  "authSignUp": "Sign Up",
  "authSignOut": "Sign Out",
  "authEmail": "Email",
  "authPassword": "Password",
  "authForgotPassword": "Forgot Password?",
  "authWelcomeBack": "Welcome back, {name}!",
  "@authWelcomeBack": {
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  },

  "productAddToCart": "Add to Cart",
  "productOutOfStock": "Out of Stock",
  "productInStock": "In Stock",
  "productItemsCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "@productItemsCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "productPriceRange": "{min} - {max}",
  "@productPriceRange": {
    "placeholders": {
      "min": {"type": "String"},
      "max": {"type": "String"}
    }
  }
}
```

### Locale Manager

```dart
// locale_manager.dart
class LocaleManager extends ChangeNotifier {
  static final LocaleManager _instance = LocaleManager._internal();
  factory LocaleManager() => _instance;
  LocaleManager._internal();

  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  final List<LocaleInfo> supportedLocales = [
    LocaleInfo(const Locale('en'), 'English', 'English'),
    LocaleInfo(const Locale('es'), 'Spanish', 'Español'),
    LocaleInfo(const Locale('fr'), 'French', 'Français'),
    LocaleInfo(const Locale('de'), 'German', 'Deutsch'),
    LocaleInfo(const Locale('ja'), 'Japanese', '日本語'),
    LocaleInfo(const Locale('ar'), 'Arabic', 'العربية'),
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('appLanguage');

    if (savedLanguage != null) {
      _currentLocale = Locale(savedLanguage);
    } else {
      final deviceLocale = PlatformDispatcher.instance.locale;
      if (supportedLocales.any((l) => l.locale.languageCode == deviceLocale.languageCode)) {
        _currentLocale = Locale(deviceLocale.languageCode);
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLanguage', locale.languageCode);
    notifyListeners();
  }
}

class LocaleInfo {
  final Locale locale;
  final String name;
  final String nativeName;

  LocaleInfo(this.locale, this.name, this.nativeName);
}
```

## Output Expectations

When implementing internationalization, the subagent should:

1. Set up localization framework and resource files
2. Create type-safe string access patterns
3. Implement pluralization rules
4. Support string interpolation
5. Create date/time formatters for locale
6. Create number/currency formatters
7. Implement runtime language switching
8. Support locale detection
9. Handle RTL language detection
10. Store user language preference
