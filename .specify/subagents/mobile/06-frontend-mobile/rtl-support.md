---
name: Mobile RTL Language Support
platform: mobile
description: Right-to-left (RTL) layout support for Arabic, Hebrew, and other RTL languages in mobile applications
model: opus
category: mobile/frontend
---

# Mobile RTL Language Support

## Purpose

Implement comprehensive right-to-left (RTL) layout support for languages like Arabic, Hebrew, Persian, and Urdu. The RTL layer should automatically mirror layouts, handle bidirectional text, manage directional icons, and provide a seamless experience for RTL language users.

## RTL Design Principles

```
┌─────────────────────────────────────────────────────────────────┐
│                   RTL Layout Considerations                      │
├─────────────────────────────────────────────────────────────────┤
│  Mirrored Elements:          │  Non-Mirrored Elements:         │
│  - Navigation flow           │  - Media playback controls      │
│  - Reading direction         │  - Progress indicators          │
│  - List items                │  - Checkmarks                   │
│  - Form layouts              │  - Phone number fields          │
│  - Navigation icons          │  - Brand logos                  │
│  - Back/forward arrows       │  - Clock hands                  │
├─────────────────────────────────────────────────────────────────┤
│  Text Handling:                                                  │
│  - Bidirectional text (BiDi) support                           │
│  - Text alignment based on content                             │
│  - Number display direction                                     │
└─────────────────────────────────────────────────────────────────┘
```

## iOS RTL Support

### Layout Direction Manager

```swift
// RTLManager.swift
import SwiftUI

@Observable
final class RTLManager {
    static let shared = RTLManager()

    var isRTL: Bool {
        UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft
    }

    var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }

    func forceLayoutDirection(_ direction: LayoutDirection) {
        UIView.appearance().semanticContentAttribute =
            direction == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    }
}

// View extension for RTL-aware layouts
extension View {
    @ViewBuilder
    func rtlAware() -> some View {
        self.environment(\.layoutDirection, RTLManager.shared.layoutDirection)
    }

    @ViewBuilder
    func flipForRTL() -> some View {
        if RTLManager.shared.isRTL {
            self.scaleEffect(x: -1, y: 1)
        } else {
            self
        }
    }

    @ViewBuilder
    func ignoreRTL() -> some View {
        self.environment(\.layoutDirection, .leftToRight)
    }
}
```

### RTL-Aware Components

```swift
// RTLStack.swift
struct RTLHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content

    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
        .environment(\.layoutDirection, RTLManager.shared.layoutDirection)
    }
}

// RTLIcon.swift
struct RTLIcon: View {
    let systemName: String
    let shouldFlip: Bool

    init(_ systemName: String, shouldFlip: Bool = true) {
        self.systemName = systemName
        self.shouldFlip = shouldFlip
    }

    var body: some View {
        Image(systemName: systemName)
            .if(shouldFlip && RTLManager.shared.isRTL) { view in
                view.scaleEffect(x: -1, y: 1)
            }
    }
}

// Directional icons that should flip
extension RTLIcon {
    static var back: RTLIcon { RTLIcon("chevron.left") }
    static var forward: RTLIcon { RTLIcon("chevron.right") }
    static var arrowLeft: RTLIcon { RTLIcon("arrow.left") }
    static var arrowRight: RTLIcon { RTLIcon("arrow.right") }

    // Icons that should NOT flip
    static var play: RTLIcon { RTLIcon("play.fill", shouldFlip: false) }
    static var checkmark: RTLIcon { RTLIcon("checkmark", shouldFlip: false) }
}

// View extension for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// RTLText.swift
struct RTLText: View {
    let text: String
    let alignment: TextAlignment

    init(_ text: String, alignment: TextAlignment = .leading) {
        self.text = text
        self.alignment = alignment
    }

    var body: some View {
        Text(text)
            .multilineTextAlignment(rtlAlignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var rtlAlignment: TextAlignment {
        guard RTLManager.shared.isRTL else { return alignment }

        switch alignment {
        case .leading: return .trailing
        case .trailing: return .leading
        default: return alignment
        }
    }

    private var frameAlignment: Alignment {
        guard RTLManager.shared.isRTL else {
            switch alignment {
            case .leading: return .leading
            case .trailing: return .trailing
            default: return .center
            }
        }

        switch alignment {
        case .leading: return .trailing
        case .trailing: return .leading
        default: return .center
        }
    }
}
```

### RTL-Aware List Item

```swift
// ListItem.swift
struct ListItem: View {
    let title: String
    let subtitle: String?
    let leadingIcon: String?
    let showChevron: Bool

    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        showChevron: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if showChevron {
                RTLIcon.forward
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
```

### RTL Navigation

```swift
// RTLNavigationView.swift
struct RTLNavigationStack<Content: View>: View {
    @Binding var path: NavigationPath
    let content: Content

    init(
        path: Binding<NavigationPath>,
        @ViewBuilder content: () -> Content
    ) {
        self._path = path
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
        }
        .environment(\.layoutDirection, RTLManager.shared.layoutDirection)
    }
}

// Custom back button for RTL
struct RTLBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                RTLIcon.back
                Text("Back")
            }
        }
    }
}
```

## Android RTL Support

### Layout Configuration

```xml
<!-- AndroidManifest.xml -->
<application
    android:supportsRtl="true"
    android:name=".MainApplication">
    ...
</application>
```

### RTL-Aware Composables

```kotlin
// RTLManager.kt
@Composable
fun isRtl(): Boolean {
    return LocalLayoutDirection.current == LayoutDirection.Rtl
}

@Composable
fun rtlLayoutDirection(): LayoutDirection {
    val locale = LocalConfiguration.current.locales[0]
    return if (TextUtilsCompat.getLayoutDirectionFromLocale(locale) == ViewCompat.LAYOUT_DIRECTION_RTL) {
        LayoutDirection.Rtl
    } else {
        LayoutDirection.Ltr
    }
}

// Force specific layout direction
@Composable
fun ForceLayoutDirection(
    direction: LayoutDirection,
    content: @Composable () -> Unit
) {
    CompositionLocalProvider(LocalLayoutDirection provides direction) {
        content()
    }
}

// RTLIcon.kt
@Composable
fun RTLIcon(
    imageVector: ImageVector,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    shouldMirror: Boolean = true,
    tint: Color = LocalContentColor.current
) {
    val isRtl = isRtl()

    Icon(
        imageVector = imageVector,
        contentDescription = contentDescription,
        modifier = modifier.then(
            if (shouldMirror && isRtl) {
                Modifier.scale(scaleX = -1f, scaleY = 1f)
            } else {
                Modifier
            }
        ),
        tint = tint
    )
}

// Predefined RTL-aware icons
object RTLIcons {
    @Composable
    fun Back(
        contentDescription: String? = null,
        modifier: Modifier = Modifier
    ) = RTLIcon(
        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
        contentDescription = contentDescription,
        modifier = modifier,
        shouldMirror = false // Already auto-mirrored
    )

    @Composable
    fun Forward(
        contentDescription: String? = null,
        modifier: Modifier = Modifier
    ) = RTLIcon(
        imageVector = Icons.AutoMirrored.Filled.ArrowForward,
        contentDescription = contentDescription,
        modifier = modifier,
        shouldMirror = false
    )

    @Composable
    fun ChevronRight(
        contentDescription: String? = null,
        modifier: Modifier = Modifier
    ) = RTLIcon(
        imageVector = Icons.Default.ChevronRight,
        contentDescription = contentDescription,
        modifier = modifier,
        shouldMirror = true
    )

    // Non-mirrored icons
    @Composable
    fun Play(
        contentDescription: String? = null,
        modifier: Modifier = Modifier
    ) = RTLIcon(
        imageVector = Icons.Default.PlayArrow,
        contentDescription = contentDescription,
        modifier = modifier,
        shouldMirror = false
    )
}
```

### RTL-Aware Layouts

```kotlin
// RTLRow.kt
@Composable
fun RTLRow(
    modifier: Modifier = Modifier,
    horizontalArrangement: Arrangement.Horizontal = Arrangement.Start,
    verticalAlignment: Alignment.Vertical = Alignment.CenterVertically,
    content: @Composable RowScope.() -> Unit
) {
    Row(
        modifier = modifier,
        horizontalArrangement = horizontalArrangement,
        verticalAlignment = verticalAlignment,
        content = content
    )
}

// RTLListItem.kt
@Composable
fun RTLListItem(
    headlineContent: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    overlineContent: @Composable (() -> Unit)? = null,
    supportingContent: @Composable (() -> Unit)? = null,
    leadingContent: @Composable (() -> Unit)? = null,
    trailingContent: @Composable (() -> Unit)? = null
) {
    ListItem(
        headlineContent = headlineContent,
        modifier = modifier,
        overlineContent = overlineContent,
        supportingContent = supportingContent,
        leadingContent = leadingContent,
        trailingContent = trailingContent
    )
}

// RTLTextField.kt
@Composable
fun RTLTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: @Composable (() -> Unit)? = null,
    placeholder: @Composable (() -> Unit)? = null,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    isError: Boolean = false,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    singleLine: Boolean = false
) {
    val isRtl = isRtl()

    // Determine text direction based on content
    val textDirection = remember(value) {
        if (value.isEmpty()) {
            if (isRtl) TextDirection.Rtl else TextDirection.Ltr
        } else {
            // Detect direction from first strong character
            TextDirection.Content
        }
    }

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        label = label,
        placeholder = placeholder,
        leadingIcon = leadingIcon,
        trailingIcon = trailingIcon,
        isError = isError,
        keyboardOptions = keyboardOptions,
        singleLine = singleLine,
        textStyle = LocalTextStyle.current.copy(
            textDirection = textDirection
        )
    )
}
```

### RTL Padding and Margins

```kotlin
// RTL-aware padding
fun Modifier.rtlPadding(
    start: Dp = 0.dp,
    top: Dp = 0.dp,
    end: Dp = 0.dp,
    bottom: Dp = 0.dp
): Modifier = this.padding(
    start = start,
    top = top,
    end = end,
    bottom = bottom
)

// Absolute padding (ignores RTL)
fun Modifier.absolutePadding(
    left: Dp = 0.dp,
    top: Dp = 0.dp,
    right: Dp = 0.dp,
    bottom: Dp = 0.dp
): Modifier = composed {
    val isRtl = isRtl()
    if (isRtl) {
        this.padding(
            start = right,
            top = top,
            end = left,
            bottom = bottom
        )
    } else {
        this.padding(
            start = left,
            top = top,
            end = right,
            bottom = bottom
        )
    }
}
```

## React Native RTL Support

### RTL Manager

```typescript
// utils/rtl.ts
import { I18nManager, Platform } from 'react-native';
import i18n from '../i18n';

const RTL_LANGUAGES = ['ar', 'he', 'fa', 'ur'];

export const isRTL = (): boolean => {
  return I18nManager.isRTL;
};

export const shouldBeRTL = (languageCode: string): boolean => {
  return RTL_LANGUAGES.includes(languageCode);
};

export const setRTL = async (languageCode: string): Promise<void> => {
  const shouldRTL = shouldBeRTL(languageCode);

  if (I18nManager.isRTL !== shouldRTL) {
    I18nManager.allowRTL(shouldRTL);
    I18nManager.forceRTL(shouldRTL);

    // On Android, we need to restart the app for RTL to take effect
    if (Platform.OS === 'android') {
      // You might want to show a dialog asking user to restart
      // or use react-native-restart
    }
  }
};

// Hook for RTL-aware values
export const useRTL = () => {
  const rtl = isRTL();

  return {
    isRTL: rtl,
    start: rtl ? 'right' : 'left',
    end: rtl ? 'left' : 'right',
    flexStart: rtl ? 'flex-end' : 'flex-start',
    flexEnd: rtl ? 'flex-start' : 'flex-end',
    transform: rtl ? [{ scaleX: -1 }] : [],
  };
};
```

### RTL-Aware Styles

```typescript
// styles/rtlStyles.ts
import { StyleSheet, I18nManager } from 'react-native';

const isRTL = I18nManager.isRTL;

// Create RTL-aware styles
export const createRTLStyles = <T extends StyleSheet.NamedStyles<T>>(
  styles: T | StyleSheet.NamedStyles<T>
): T => {
  const processedStyles: any = {};

  Object.keys(styles).forEach((key) => {
    const style = (styles as any)[key];
    processedStyles[key] = processRTLStyle(style);
  });

  return StyleSheet.create(processedStyles) as T;
};

const processRTLStyle = (style: any): any => {
  if (!style || typeof style !== 'object') return style;

  const processed: any = { ...style };

  // Swap left/right properties
  if (isRTL) {
    // Margins
    if ('marginLeft' in processed || 'marginRight' in processed) {
      const left = processed.marginLeft;
      const right = processed.marginRight;
      processed.marginLeft = right;
      processed.marginRight = left;
    }

    // Padding
    if ('paddingLeft' in processed || 'paddingRight' in processed) {
      const left = processed.paddingLeft;
      const right = processed.paddingRight;
      processed.paddingLeft = right;
      processed.paddingRight = left;
    }

    // Positioning
    if ('left' in processed || 'right' in processed) {
      const left = processed.left;
      const right = processed.right;
      processed.left = right;
      processed.right = left;
    }

    // Border radius
    if ('borderTopLeftRadius' in processed || 'borderTopRightRadius' in processed) {
      const topLeft = processed.borderTopLeftRadius;
      const topRight = processed.borderTopRightRadius;
      processed.borderTopLeftRadius = topRight;
      processed.borderTopRightRadius = topLeft;
    }
    if ('borderBottomLeftRadius' in processed || 'borderBottomRightRadius' in processed) {
      const bottomLeft = processed.borderBottomLeftRadius;
      const bottomRight = processed.borderBottomRightRadius;
      processed.borderBottomLeftRadius = bottomRight;
      processed.borderBottomRightRadius = bottomLeft;
    }

    // Text alignment
    if (processed.textAlign === 'left') {
      processed.textAlign = 'right';
    } else if (processed.textAlign === 'right') {
      processed.textAlign = 'left';
    }

    // Flex direction
    if (processed.flexDirection === 'row') {
      processed.flexDirection = 'row-reverse';
    } else if (processed.flexDirection === 'row-reverse') {
      processed.flexDirection = 'row';
    }
  }

  return processed;
};

// Use start/end instead of left/right
export const rtlStyle = {
  marginStart: (value: number) => ({
    marginLeft: isRTL ? undefined : value,
    marginRight: isRTL ? value : undefined,
  }),
  marginEnd: (value: number) => ({
    marginLeft: isRTL ? value : undefined,
    marginRight: isRTL ? undefined : value,
  }),
  paddingStart: (value: number) => ({
    paddingLeft: isRTL ? undefined : value,
    paddingRight: isRTL ? value : undefined,
  }),
  paddingEnd: (value: number) => ({
    paddingLeft: isRTL ? value : undefined,
    paddingRight: isRTL ? undefined : value,
  }),
  textStart: {
    textAlign: isRTL ? 'right' : 'left',
  } as const,
  textEnd: {
    textAlign: isRTL ? 'left' : 'right',
  } as const,
};
```

### RTL-Aware Components

```typescript
// components/RTLIcon.tsx
import React from 'react';
import { View, StyleSheet, ViewStyle } from 'react-native';
import { useRTL } from '../utils/rtl';
import { Icon, IconProps } from './Icon';

interface RTLIconProps extends IconProps {
  shouldMirror?: boolean;
}

export const RTLIcon: React.FC<RTLIconProps> = ({
  shouldMirror = true,
  style,
  ...props
}) => {
  const { isRTL, transform } = useRTL();

  return (
    <Icon
      {...props}
      style={[
        style,
        shouldMirror && isRTL && styles.mirrored,
      ]}
    />
  );
};

const styles = StyleSheet.create({
  mirrored: {
    transform: [{ scaleX: -1 }],
  },
});

// Predefined directional icons
export const BackIcon: React.FC<Omit<RTLIconProps, 'name'>> = (props) => (
  <RTLIcon name="arrow-back" shouldMirror={true} {...props} />
);

export const ForwardIcon: React.FC<Omit<RTLIconProps, 'name'>> = (props) => (
  <RTLIcon name="arrow-forward" shouldMirror={true} {...props} />
);

export const ChevronRightIcon: React.FC<Omit<RTLIconProps, 'name'>> = (props) => (
  <RTLIcon name="chevron-right" shouldMirror={true} {...props} />
);

// Non-mirrored icons
export const PlayIcon: React.FC<Omit<RTLIconProps, 'name'>> = (props) => (
  <RTLIcon name="play" shouldMirror={false} {...props} />
);

export const CheckIcon: React.FC<Omit<RTLIconProps, 'name'>> = (props) => (
  <RTLIcon name="check" shouldMirror={false} {...props} />
);

// components/RTLView.tsx
import React from 'react';
import { View, ViewProps, StyleSheet } from 'react-native';
import { useRTL } from '../utils/rtl';

interface RTLViewProps extends ViewProps {
  row?: boolean;
}

export const RTLView: React.FC<RTLViewProps> = ({
  row = false,
  style,
  children,
  ...props
}) => {
  const { isRTL } = useRTL();

  return (
    <View
      style={[
        row && styles.row,
        row && isRTL && styles.rowReverse,
        style,
      ]}
      {...props}
    >
      {children}
    </View>
  );
};

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
  },
  rowReverse: {
    flexDirection: 'row-reverse',
  },
});
```

## Flutter RTL Support

### RTL Manager

```dart
// rtl_manager.dart
import 'package:flutter/material.dart';

class RTLManager {
  static const List<String> rtlLanguages = ['ar', 'he', 'fa', 'ur'];

  static bool isRTL(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }

  static bool shouldBeRTL(String languageCode) {
    return rtlLanguages.contains(languageCode);
  }

  static TextDirection getTextDirection(String languageCode) {
    return shouldBeRTL(languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }
}

// RTL-aware widget wrapper
class RTLAware extends StatelessWidget {
  final Widget child;
  final bool forceDirection;
  final TextDirection? direction;

  const RTLAware({
    super.key,
    required this.child,
    this.forceDirection = false,
    this.direction,
  });

  @override
  Widget build(BuildContext context) {
    if (forceDirection && direction != null) {
      return Directionality(
        textDirection: direction!,
        child: child,
      );
    }
    return child;
  }
}
```

### RTL-Aware Components

```dart
// rtl_icon.dart
class RTLIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final bool shouldMirror;

  const RTLIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.shouldMirror = true,
  });

  @override
  Widget build(BuildContext context) {
    final isRTL = RTLManager.isRTL(context);

    Widget iconWidget = Icon(
      icon,
      size: size,
      color: color,
    );

    if (shouldMirror && isRTL) {
      return Transform.scale(
        scaleX: -1,
        child: iconWidget,
      );
    }

    return iconWidget;
  }

  // Factory constructors for common directional icons
  static Widget back({double? size, Color? color}) =>
      RTLIcon(Icons.arrow_back, size: size, color: color);

  static Widget forward({double? size, Color? color}) =>
      RTLIcon(Icons.arrow_forward, size: size, color: color);

  static Widget chevronRight({double? size, Color? color}) =>
      RTLIcon(Icons.chevron_right, size: size, color: color);

  // Non-mirrored icons
  static Widget play({double? size, Color? color}) =>
      RTLIcon(Icons.play_arrow, size: size, color: color, shouldMirror: false);

  static Widget check({double? size, Color? color}) =>
      RTLIcon(Icons.check, size: size, color: color, shouldMirror: false);
}

// rtl_padding.dart
class RTLPadding extends StatelessWidget {
  final Widget child;
  final double start;
  final double top;
  final double end;
  final double bottom;

  const RTLPadding({
    super.key,
    required this.child,
    this.start = 0,
    this.top = 0,
    this.end = 0,
    this.bottom = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: start,
        top: top,
        end: end,
        bottom: bottom,
      ),
      child: child,
    );
  }
}

// rtl_row.dart
class RTLRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const RTLRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      textDirection: Directionality.of(context),
      children: children,
    );
  }
}
```

### RTL Text Handling

```dart
// rtl_text.dart
class RTLText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const RTLText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    // Detect text direction from content
    final textDirection = _detectTextDirection(text);

    return Text(
      text,
      style: style,
      textAlign: textAlign ?? _defaultAlignment(context, textDirection),
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextDirection _detectTextDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;

    // Check first strong character
    for (final char in text.runes) {
      if (_isRTLChar(char)) return TextDirection.rtl;
      if (_isLTRChar(char)) return TextDirection.ltr;
    }

    return TextDirection.ltr;
  }

  bool _isRTLChar(int char) {
    // Arabic, Hebrew, etc.
    return (char >= 0x0590 && char <= 0x05FF) || // Hebrew
        (char >= 0x0600 && char <= 0x06FF) || // Arabic
        (char >= 0x0750 && char <= 0x077F) || // Arabic Supplement
        (char >= 0xFB50 && char <= 0xFDFF) || // Arabic Presentation Forms-A
        (char >= 0xFE70 && char <= 0xFEFF); // Arabic Presentation Forms-B
  }

  bool _isLTRChar(int char) {
    return (char >= 0x0041 && char <= 0x005A) || // A-Z
        (char >= 0x0061 && char <= 0x007A); // a-z
  }

  TextAlign _defaultAlignment(BuildContext context, TextDirection textDirection) {
    final layoutDirection = Directionality.of(context);
    if (layoutDirection == textDirection) {
      return TextAlign.start;
    }
    return TextAlign.start;
  }
}
```

## Output Expectations

When implementing RTL support, the subagent should:

1. Enable RTL support in app configuration
2. Use directional layout properties (start/end vs left/right)
3. Create RTL-aware icon components
4. Handle bidirectional text properly
5. Mirror navigation and list layouts
6. Preserve non-directional elements
7. Test with RTL languages (Arabic, Hebrew)
8. Handle mixed LTR/RTL content
9. Support runtime direction switching
10. Document RTL-specific behaviors
