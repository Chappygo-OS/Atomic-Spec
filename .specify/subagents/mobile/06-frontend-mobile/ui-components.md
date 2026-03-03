---
name: Mobile UI Components Library
platform: mobile
description: Reusable, accessible, and customizable UI component library patterns for mobile applications
model: opus
category: mobile/frontend
---

# Mobile UI Components Library

## Purpose

Build consistent, reusable UI component libraries that enforce design system compliance, support theming, ensure accessibility, and provide excellent developer experience across iOS, Android, and cross-platform frameworks.

## Component Architecture Principles

### Component Categories

1. **Primitives** - Basic building blocks (Box, Text, Icon)
2. **Atoms** - Simple components (Button, Input, Badge)
3. **Molecules** - Compound components (SearchBar, Card, ListItem)
4. **Organisms** - Complex components (Form, DataTable, Carousel)
5. **Templates** - Page layouts (AuthLayout, DashboardLayout)

### Design Tokens Integration

```typescript
// tokens.ts
export const tokens = {
  colors: {
    primary: {
      50: '#E3F2FD',
      100: '#BBDEFB',
      500: '#2196F3',
      600: '#1E88E5',
      700: '#1976D2',
    },
    neutral: {
      0: '#FFFFFF',
      50: '#FAFAFA',
      100: '#F5F5F5',
      200: '#EEEEEE',
      500: '#9E9E9E',
      800: '#424242',
      900: '#212121',
    },
    semantic: {
      success: '#4CAF50',
      warning: '#FF9800',
      error: '#F44336',
      info: '#2196F3',
    },
  },
  spacing: {
    xxs: 2,
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  },
  radii: {
    none: 0,
    sm: 4,
    md: 8,
    lg: 16,
    full: 9999,
  },
  typography: {
    fontFamily: {
      primary: 'Inter',
      mono: 'JetBrains Mono',
    },
    fontSize: {
      xs: 12,
      sm: 14,
      md: 16,
      lg: 18,
      xl: 20,
      '2xl': 24,
      '3xl': 30,
    },
    fontWeight: {
      regular: '400',
      medium: '500',
      semibold: '600',
      bold: '700',
    },
    lineHeight: {
      tight: 1.25,
      normal: 1.5,
      relaxed: 1.75,
    },
  },
  shadows: {
    sm: '0 1px 2px rgba(0, 0, 0, 0.05)',
    md: '0 4px 6px rgba(0, 0, 0, 0.1)',
    lg: '0 10px 15px rgba(0, 0, 0, 0.1)',
    xl: '0 20px 25px rgba(0, 0, 0, 0.15)',
  },
} as const;
```

## iOS Components (SwiftUI)

### Button Component

```swift
// Button.swift
import SwiftUI

struct AppButton: View {
    enum Variant {
        case primary
        case secondary
        case outline
        case ghost
        case destructive
    }

    enum Size {
        case small
        case medium
        case large

        var height: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }
    }

    let title: String
    let variant: Variant
    let size: Size
    let icon: Image?
    let iconPosition: IconPosition
    let isLoading: Bool
    let isDisabled: Bool
    let isFullWidth: Bool
    let action: () -> Void

    enum IconPosition {
        case leading, trailing
    }

    init(
        _ title: String,
        variant: Variant = .primary,
        size: Size = .medium,
        icon: Image? = nil,
        iconPosition: IconPosition = .leading,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        isFullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.icon = icon
        self.iconPosition = iconPosition
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.isFullWidth = isFullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else {
                    if let icon, iconPosition == .leading {
                        icon
                            .font(.system(size: size.fontSize))
                    }

                    Text(title)
                        .font(.system(size: size.fontSize, weight: .semibold))

                    if let icon, iconPosition == .trailing {
                        icon
                            .font(.system(size: size.fontSize))
                    }
                }
            }
            .frame(height: size.height)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: variant == .outline ? 1.5 : 0)
            )
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: return .accentColor
        case .secondary: return Color(.systemGray5)
        case .outline, .ghost: return .clear
        case .destructive: return .red
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive: return .white
        case .secondary: return .primary
        case .outline: return .accentColor
        case .ghost: return .accentColor
        }
    }

    private var borderColor: Color {
        switch variant {
        case .outline: return .accentColor
        default: return .clear
        }
    }
}

// Usage
AppButton("Add to Cart", variant: .primary, icon: Image(systemName: "cart.badge.plus")) {
    viewModel.addToCart()
}

AppButton("Delete", variant: .destructive, isLoading: viewModel.isDeleting) {
    viewModel.delete()
}
```

### Text Input Component

```swift
// TextInput.swift
import SwiftUI

struct AppTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let helperText: String?
    let errorMessage: String?
    let isSecure: Bool
    let isDisabled: Bool
    let leadingIcon: Image?
    let trailingIcon: Image?
    let onTrailingIconTap: (() -> Void)?
    let keyboardType: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization

    @FocusState private var isFocused: Bool
    @State private var isSecureTextVisible: Bool = false

    init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        helperText: String? = nil,
        errorMessage: String? = nil,
        isSecure: Bool = false,
        isDisabled: Bool = false,
        leadingIcon: Image? = nil,
        trailingIcon: Image? = nil,
        onTrailingIconTap: (() -> Void)? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.helperText = helperText
        self.errorMessage = errorMessage
        self.isSecure = isSecure
        self.isDisabled = isDisabled
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.onTrailingIconTap = onTrailingIconTap
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            // Input field
            HStack(spacing: 12) {
                if let leadingIcon {
                    leadingIcon
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }

                Group {
                    if isSecure && !isSecureTextVisible {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .focused($isFocused)
                .disabled(isDisabled)

                if isSecure {
                    Button {
                        isSecureTextVisible.toggle()
                    } label: {
                        Image(systemName: isSecureTextVisible ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                } else if let trailingIcon {
                    Button {
                        onTrailingIconTap?()
                    } label: {
                        trailingIcon
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )

            // Helper/Error text
            if let errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(.system(size: 12))
                }
                .foregroundColor(.red)
            } else if let helperText {
                Text(helperText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var borderColor: Color {
        if errorMessage != nil {
            return .red
        }
        if isFocused {
            return .accentColor
        }
        return Color(.systemGray4)
    }
}
```

### Card Component

```swift
// Card.swift
struct AppCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let isInteractive: Bool
    let action: (() -> Void)?

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 4,
        isInteractive: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.isInteractive = isInteractive
        self.action = action
        self.content = content()
    }

    var body: some View {
        Group {
            if isInteractive, let action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(CardButtonStyle())
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

## Android Components (Jetpack Compose)

### Button Component

```kotlin
// Button.kt
@Composable
fun AppButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: ButtonVariant = ButtonVariant.Primary,
    size: ButtonSize = ButtonSize.Medium,
    leadingIcon: ImageVector? = null,
    trailingIcon: ImageVector? = null,
    isLoading: Boolean = false,
    enabled: Boolean = true,
    fullWidth: Boolean = false
) {
    val buttonColors = when (variant) {
        ButtonVariant.Primary -> ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.primary,
            contentColor = MaterialTheme.colorScheme.onPrimary
        )
        ButtonVariant.Secondary -> ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.secondaryContainer,
            contentColor = MaterialTheme.colorScheme.onSecondaryContainer
        )
        ButtonVariant.Outline -> ButtonDefaults.outlinedButtonColors(
            contentColor = MaterialTheme.colorScheme.primary
        )
        ButtonVariant.Ghost -> ButtonDefaults.textButtonColors(
            contentColor = MaterialTheme.colorScheme.primary
        )
        ButtonVariant.Destructive -> ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.error,
            contentColor = MaterialTheme.colorScheme.onError
        )
    }

    val buttonModifier = modifier
        .then(if (fullWidth) Modifier.fillMaxWidth() else Modifier)
        .height(size.height)

    when (variant) {
        ButtonVariant.Outline -> OutlinedButton(
            onClick = onClick,
            modifier = buttonModifier,
            enabled = enabled && !isLoading,
            colors = buttonColors,
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(horizontal = size.horizontalPadding)
        ) {
            ButtonContent(text, leadingIcon, trailingIcon, isLoading, size)
        }
        ButtonVariant.Ghost -> TextButton(
            onClick = onClick,
            modifier = buttonModifier,
            enabled = enabled && !isLoading,
            colors = buttonColors,
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(horizontal = size.horizontalPadding)
        ) {
            ButtonContent(text, leadingIcon, trailingIcon, isLoading, size)
        }
        else -> Button(
            onClick = onClick,
            modifier = buttonModifier,
            enabled = enabled && !isLoading,
            colors = buttonColors,
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(horizontal = size.horizontalPadding)
        ) {
            ButtonContent(text, leadingIcon, trailingIcon, isLoading, size)
        }
    }
}

@Composable
private fun RowScope.ButtonContent(
    text: String,
    leadingIcon: ImageVector?,
    trailingIcon: ImageVector?,
    isLoading: Boolean,
    size: ButtonSize
) {
    if (isLoading) {
        CircularProgressIndicator(
            modifier = Modifier.size(size.iconSize),
            strokeWidth = 2.dp,
            color = LocalContentColor.current
        )
    } else {
        leadingIcon?.let {
            Icon(
                imageVector = it,
                contentDescription = null,
                modifier = Modifier.size(size.iconSize)
            )
            Spacer(Modifier.width(8.dp))
        }

        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge.copy(
                fontSize = size.fontSize
            )
        )

        trailingIcon?.let {
            Spacer(Modifier.width(8.dp))
            Icon(
                imageVector = it,
                contentDescription = null,
                modifier = Modifier.size(size.iconSize)
            )
        }
    }
}

enum class ButtonVariant {
    Primary, Secondary, Outline, Ghost, Destructive
}

enum class ButtonSize(
    val height: Dp,
    val horizontalPadding: Dp,
    val fontSize: TextUnit,
    val iconSize: Dp
) {
    Small(32.dp, 12.dp, 14.sp, 16.dp),
    Medium(44.dp, 16.dp, 16.sp, 20.dp),
    Large(56.dp, 24.dp, 18.sp, 24.dp)
}
```

### Text Input Component

```kotlin
// TextField.kt
@Composable
fun AppTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    helperText: String? = null,
    errorMessage: String? = null,
    leadingIcon: ImageVector? = null,
    trailingIcon: ImageVector? = null,
    onTrailingIconClick: (() -> Unit)? = null,
    isPassword: Boolean = false,
    enabled: Boolean = true,
    readOnly: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Default,
    onImeAction: (() -> Unit)? = null,
    singleLine: Boolean = true,
    maxLines: Int = if (singleLine) 1 else Int.MAX_VALUE
) {
    var passwordVisible by remember { mutableStateOf(false) }
    val isError = errorMessage != null

    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = if (isError) MaterialTheme.colorScheme.error
                    else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 6.dp)
        )

        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            enabled = enabled,
            readOnly = readOnly,
            placeholder = {
                Text(placeholder, color = MaterialTheme.colorScheme.onSurfaceVariant)
            },
            leadingIcon = leadingIcon?.let {
                {
                    Icon(
                        imageVector = it,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            },
            trailingIcon = {
                when {
                    isPassword -> {
                        IconButton(onClick = { passwordVisible = !passwordVisible }) {
                            Icon(
                                imageVector = if (passwordVisible)
                                    Icons.Default.VisibilityOff
                                else
                                    Icons.Default.Visibility,
                                contentDescription = if (passwordVisible)
                                    "Hide password"
                                else
                                    "Show password"
                            )
                        }
                    }
                    trailingIcon != null -> {
                        IconButton(
                            onClick = { onTrailingIconClick?.invoke() },
                            enabled = onTrailingIconClick != null
                        ) {
                            Icon(
                                imageVector = trailingIcon,
                                contentDescription = null
                            )
                        }
                    }
                }
            },
            visualTransformation = if (isPassword && !passwordVisible)
                PasswordVisualTransformation()
            else
                VisualTransformation.None,
            keyboardOptions = KeyboardOptions(
                keyboardType = if (isPassword) KeyboardType.Password else keyboardType,
                imeAction = imeAction
            ),
            keyboardActions = KeyboardActions(
                onDone = { onImeAction?.invoke() },
                onGo = { onImeAction?.invoke() },
                onSearch = { onImeAction?.invoke() },
                onSend = { onImeAction?.invoke() }
            ),
            singleLine = singleLine,
            maxLines = maxLines,
            isError = isError,
            shape = RoundedCornerShape(8.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                errorBorderColor = MaterialTheme.colorScheme.error
            )
        )

        AnimatedVisibility(visible = errorMessage != null || helperText != null) {
            Row(
                modifier = Modifier.padding(top = 4.dp, start = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (isError) {
                    Icon(
                        imageVector = Icons.Default.Error,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = MaterialTheme.colorScheme.error
                    )
                    Spacer(Modifier.width(4.dp))
                }
                Text(
                    text = errorMessage ?: helperText ?: "",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (isError)
                        MaterialTheme.colorScheme.error
                    else
                        MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
```

### Card Component

```kotlin
// Card.kt
@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    elevation: Dp = 2.dp,
    cornerRadius: Dp = 12.dp,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable ColumnScope.() -> Unit
) {
    val cardModifier = modifier.fillMaxWidth()

    if (onClick != null) {
        Card(
            onClick = onClick,
            modifier = cardModifier,
            shape = RoundedCornerShape(cornerRadius),
            elevation = CardDefaults.cardElevation(defaultElevation = elevation),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            )
        ) {
            Column(
                modifier = Modifier.padding(contentPadding),
                content = content
            )
        }
    } else {
        Card(
            modifier = cardModifier,
            shape = RoundedCornerShape(cornerRadius),
            elevation = CardDefaults.cardElevation(defaultElevation = elevation),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            )
        ) {
            Column(
                modifier = Modifier.padding(contentPadding),
                content = content
            )
        }
    }
}
```

## React Native Components

### Button Component

```typescript
// Button.tsx
import React from 'react';
import {
  TouchableOpacity,
  Text,
  ActivityIndicator,
  StyleSheet,
  ViewStyle,
  TextStyle,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { tokens } from '../../design/theme';

type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'destructive';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps {
  title: string;
  onPress: () => void;
  variant?: ButtonVariant;
  size?: ButtonSize;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  isLoading?: boolean;
  isDisabled?: boolean;
  fullWidth?: boolean;
  style?: ViewStyle;
}

const AnimatedTouchable = Animated.createAnimatedComponent(TouchableOpacity);

export const Button: React.FC<ButtonProps> = ({
  title,
  onPress,
  variant = 'primary',
  size = 'md',
  leftIcon,
  rightIcon,
  isLoading = false,
  isDisabled = false,
  fullWidth = false,
  style,
}) => {
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = () => {
    scale.value = withSpring(0.97, { damping: 15 });
  };

  const handlePressOut = () => {
    scale.value = withSpring(1, { damping: 15 });
  };

  const sizeStyles = getSizeStyles(size);
  const variantStyles = getVariantStyles(variant);

  return (
    <AnimatedTouchable
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      disabled={isDisabled || isLoading}
      activeOpacity={0.8}
      style={[
        styles.base,
        sizeStyles.container,
        variantStyles.container,
        fullWidth && styles.fullWidth,
        isDisabled && styles.disabled,
        animatedStyle,
        style,
      ]}
    >
      {isLoading ? (
        <ActivityIndicator
          size="small"
          color={variantStyles.textColor}
        />
      ) : (
        <>
          {leftIcon}
          <Text
            style={[
              styles.text,
              sizeStyles.text,
              { color: variantStyles.textColor },
              leftIcon && styles.textWithLeftIcon,
              rightIcon && styles.textWithRightIcon,
            ]}
          >
            {title}
          </Text>
          {rightIcon}
        </>
      )}
    </AnimatedTouchable>
  );
};

const getSizeStyles = (size: ButtonSize) => {
  const sizes = {
    sm: {
      container: { height: 32, paddingHorizontal: 12 } as ViewStyle,
      text: { fontSize: 14 } as TextStyle,
    },
    md: {
      container: { height: 44, paddingHorizontal: 16 } as ViewStyle,
      text: { fontSize: 16 } as TextStyle,
    },
    lg: {
      container: { height: 56, paddingHorizontal: 24 } as ViewStyle,
      text: { fontSize: 18 } as TextStyle,
    },
  };
  return sizes[size];
};

const getVariantStyles = (variant: ButtonVariant) => {
  const variants = {
    primary: {
      container: { backgroundColor: tokens.colors.primary[500] } as ViewStyle,
      textColor: '#FFFFFF',
    },
    secondary: {
      container: { backgroundColor: tokens.colors.neutral[200] } as ViewStyle,
      textColor: tokens.colors.neutral[900],
    },
    outline: {
      container: {
        backgroundColor: 'transparent',
        borderWidth: 1.5,
        borderColor: tokens.colors.primary[500],
      } as ViewStyle,
      textColor: tokens.colors.primary[500],
    },
    ghost: {
      container: { backgroundColor: 'transparent' } as ViewStyle,
      textColor: tokens.colors.primary[500],
    },
    destructive: {
      container: { backgroundColor: tokens.colors.semantic.error } as ViewStyle,
      textColor: '#FFFFFF',
    },
  };
  return variants[variant];
};

const styles = StyleSheet.create({
  base: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
  },
  fullWidth: {
    width: '100%',
  },
  disabled: {
    opacity: 0.5,
  },
  text: {
    fontWeight: '600',
  },
  textWithLeftIcon: {
    marginLeft: 8,
  },
  textWithRightIcon: {
    marginRight: 8,
  },
});
```

### Text Input Component

```typescript
// TextInput.tsx
import React, { useState, forwardRef } from 'react';
import {
  View,
  TextInput as RNTextInput,
  Text,
  TouchableOpacity,
  StyleSheet,
  TextInputProps as RNTextInputProps,
} from 'react-native';
import Animated, {
  useAnimatedStyle,
  withTiming,
  interpolateColor,
} from 'react-native-reanimated';
import { tokens } from '../../design/theme';
import { Icon } from './Icon';

interface TextInputProps extends Omit<RNTextInputProps, 'style'> {
  label: string;
  error?: string;
  helperText?: string;
  leftIcon?: string;
  rightIcon?: string;
  onRightIconPress?: () => void;
  isPassword?: boolean;
  containerStyle?: object;
}

export const TextInput = forwardRef<RNTextInput, TextInputProps>(
  (
    {
      label,
      error,
      helperText,
      leftIcon,
      rightIcon,
      onRightIconPress,
      isPassword = false,
      containerStyle,
      editable = true,
      ...props
    },
    ref
  ) => {
    const [isFocused, setIsFocused] = useState(false);
    const [isPasswordVisible, setIsPasswordVisible] = useState(false);

    const borderColor = error
      ? tokens.colors.semantic.error
      : isFocused
      ? tokens.colors.primary[500]
      : tokens.colors.neutral[200];

    const animatedBorderStyle = useAnimatedStyle(() => ({
      borderColor: withTiming(borderColor, { duration: 150 }),
    }));

    return (
      <View style={[styles.container, containerStyle]}>
        <Text
          style={[
            styles.label,
            error && styles.labelError,
            !editable && styles.labelDisabled,
          ]}
        >
          {label}
        </Text>

        <Animated.View
          style={[
            styles.inputContainer,
            animatedBorderStyle,
            !editable && styles.inputDisabled,
          ]}
        >
          {leftIcon && (
            <Icon
              name={leftIcon}
              size={20}
              color={tokens.colors.neutral[500]}
              style={styles.leftIcon}
            />
          )}

          <RNTextInput
            ref={ref}
            style={[
              styles.input,
              leftIcon && styles.inputWithLeftIcon,
              (rightIcon || isPassword) && styles.inputWithRightIcon,
            ]}
            placeholderTextColor={tokens.colors.neutral[500]}
            editable={editable}
            secureTextEntry={isPassword && !isPasswordVisible}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            {...props}
          />

          {isPassword && (
            <TouchableOpacity
              onPress={() => setIsPasswordVisible(!isPasswordVisible)}
              style={styles.rightIconButton}
            >
              <Icon
                name={isPasswordVisible ? 'eye-off' : 'eye'}
                size={20}
                color={tokens.colors.neutral[500]}
              />
            </TouchableOpacity>
          )}

          {rightIcon && !isPassword && (
            <TouchableOpacity
              onPress={onRightIconPress}
              disabled={!onRightIconPress}
              style={styles.rightIconButton}
            >
              <Icon
                name={rightIcon}
                size={20}
                color={tokens.colors.neutral[500]}
              />
            </TouchableOpacity>
          )}
        </Animated.View>

        {(error || helperText) && (
          <View style={styles.messageContainer}>
            {error && (
              <Icon
                name="alert-circle"
                size={14}
                color={tokens.colors.semantic.error}
                style={styles.errorIcon}
              />
            )}
            <Text style={[styles.helperText, error && styles.errorText]}>
              {error || helperText}
            </Text>
          </View>
        )}
      </View>
    );
  }
);

const styles = StyleSheet.create({
  container: {
    marginBottom: 16,
  },
  label: {
    fontSize: 14,
    fontWeight: '500',
    color: tokens.colors.neutral[800],
    marginBottom: 6,
  },
  labelError: {
    color: tokens.colors.semantic.error,
  },
  labelDisabled: {
    color: tokens.colors.neutral[500],
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 48,
    borderWidth: 1,
    borderRadius: 8,
    backgroundColor: tokens.colors.neutral[50],
    paddingHorizontal: 16,
  },
  inputDisabled: {
    backgroundColor: tokens.colors.neutral[100],
    opacity: 0.7,
  },
  input: {
    flex: 1,
    fontSize: 16,
    color: tokens.colors.neutral[900],
    padding: 0,
  },
  inputWithLeftIcon: {
    marginLeft: 8,
  },
  inputWithRightIcon: {
    marginRight: 8,
  },
  leftIcon: {
    marginRight: 4,
  },
  rightIconButton: {
    padding: 4,
  },
  messageContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
    paddingHorizontal: 4,
  },
  errorIcon: {
    marginRight: 4,
  },
  helperText: {
    fontSize: 12,
    color: tokens.colors.neutral[500],
  },
  errorText: {
    color: tokens.colors.semantic.error,
  },
});
```

## Flutter Components

### Button Component

```dart
// app_button.dart
import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, outline, ghost, destructive }
enum ButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeConfig = _getSizeConfig();
    final variantConfig = _getVariantConfig(theme);

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: sizeConfig.iconSize,
            height: sizeConfig.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(variantConfig.foregroundColor),
            ),
          )
        else ...[
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: sizeConfig.iconSize),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: sizeConfig.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(trailingIcon, size: sizeConfig.iconSize),
          ],
        ],
      ],
    );

    final buttonStyle = ButtonStyle(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return variantConfig.backgroundColor.withOpacity(0.5);
        }
        return variantConfig.backgroundColor;
      }),
      foregroundColor: MaterialStateProperty.all(variantConfig.foregroundColor),
      padding: MaterialStateProperty.all(
        EdgeInsets.symmetric(horizontal: sizeConfig.horizontalPadding),
      ),
      minimumSize: MaterialStateProperty.all(
        Size(isFullWidth ? double.infinity : 0, sizeConfig.height),
      ),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: variantConfig.borderSide,
        ),
      ),
      elevation: MaterialStateProperty.all(0),
    );

    switch (variant) {
      case ButtonVariant.outline:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
      case ButtonVariant.ghost:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
      default:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: buttonStyle,
          child: child,
        );
    }
  }

  _ButtonSizeConfig _getSizeConfig() {
    switch (size) {
      case ButtonSize.small:
        return _ButtonSizeConfig(
          height: 32,
          horizontalPadding: 12,
          fontSize: 14,
          iconSize: 16,
        );
      case ButtonSize.medium:
        return _ButtonSizeConfig(
          height: 44,
          horizontalPadding: 16,
          fontSize: 16,
          iconSize: 20,
        );
      case ButtonSize.large:
        return _ButtonSizeConfig(
          height: 56,
          horizontalPadding: 24,
          fontSize: 18,
          iconSize: 24,
        );
    }
  }

  _ButtonVariantConfig _getVariantConfig(ThemeData theme) {
    switch (variant) {
      case ButtonVariant.primary:
        return _ButtonVariantConfig(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          borderSide: BorderSide.none,
        );
      case ButtonVariant.secondary:
        return _ButtonVariantConfig(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          borderSide: BorderSide.none,
        );
      case ButtonVariant.outline:
        return _ButtonVariantConfig(
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.primary,
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        );
      case ButtonVariant.ghost:
        return _ButtonVariantConfig(
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.primary,
          borderSide: BorderSide.none,
        );
      case ButtonVariant.destructive:
        return _ButtonVariantConfig(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
          borderSide: BorderSide.none,
        );
    }
  }
}

class _ButtonSizeConfig {
  final double height;
  final double horizontalPadding;
  final double fontSize;
  final double iconSize;

  _ButtonSizeConfig({
    required this.height,
    required this.horizontalPadding,
    required this.fontSize,
    required this.iconSize,
  });
}

class _ButtonVariantConfig {
  final Color backgroundColor;
  final Color foregroundColor;
  final BorderSide borderSide;

  _ButtonVariantConfig({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderSide,
  });
}
```

## Accessibility Checklist

For all components:

1. **Touch targets**: Minimum 44x44pt (iOS) / 48x48dp (Android)
2. **Color contrast**: WCAG AA minimum (4.5:1 for text, 3:1 for UI)
3. **Screen reader labels**: All interactive elements have labels
4. **Focus indicators**: Visible focus states for keyboard navigation
5. **Motion**: Respect reduced motion preferences
6. **Text scaling**: Support dynamic type / font scaling
7. **Semantic roles**: Use proper semantic elements/roles

## Output Expectations

When building components, the subagent should:

1. Create type-safe, well-documented component APIs
2. Implement all standard variants (primary, secondary, etc.)
3. Support multiple sizes with consistent scaling
4. Include loading, disabled, and error states
5. Ensure full accessibility compliance
6. Support theming and design tokens
7. Add smooth animations and transitions
8. Write unit tests for component logic
9. Create visual regression test snapshots
10. Document props with examples
