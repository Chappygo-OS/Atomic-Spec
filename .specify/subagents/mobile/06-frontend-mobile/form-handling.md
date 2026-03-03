---
name: Mobile Form Handling
platform: mobile
description: Form management, input validation, error handling, and submission patterns for mobile applications
model: opus
category: mobile/frontend
---

# Mobile Form Handling

## Purpose

Implement robust form handling systems that provide excellent user experience through real-time validation, clear error messaging, proper keyboard management, and accessible input controls. Forms should support complex validation rules, async validation, and maintain state through app lifecycle changes.

## Form Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Form Structure                              │
├─────────────────────────────────────────────────────────────────┤
│  Form State           │  Validation           │  Submission     │
│  - Field values       │  - Sync validators    │  - Loading      │
│  - Touched/dirty      │  - Async validators   │  - Success      │
│  - Focus state        │  - Cross-field rules  │  - Error        │
│  - Errors             │  - Debouncing         │  - Retry        │
└─────────────────────────────────────────────────────────────────┘
```

## Validation Rules

### Common Validators

```typescript
// validators.ts
export const validators = {
  required: (value: string) => {
    if (!value || !value.trim()) {
      return 'This field is required';
    }
    return null;
  },

  email: (value: string) => {
    if (!value) return null;
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  },

  phone: (value: string) => {
    if (!value) return null;
    const phoneRegex = /^\+?[\d\s-]{10,}$/;
    if (!phoneRegex.test(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  },

  minLength: (min: number) => (value: string) => {
    if (!value) return null;
    if (value.length < min) {
      return `Must be at least ${min} characters`;
    }
    return null;
  },

  maxLength: (max: number) => (value: string) => {
    if (!value) return null;
    if (value.length > max) {
      return `Must be no more than ${max} characters`;
    }
    return null;
  },

  password: (value: string) => {
    if (!value) return null;
    const errors: string[] = [];

    if (value.length < 8) {
      errors.push('at least 8 characters');
    }
    if (!/[A-Z]/.test(value)) {
      errors.push('one uppercase letter');
    }
    if (!/[a-z]/.test(value)) {
      errors.push('one lowercase letter');
    }
    if (!/[0-9]/.test(value)) {
      errors.push('one number');
    }
    if (!/[!@#$%^&*]/.test(value)) {
      errors.push('one special character (!@#$%^&*)');
    }

    if (errors.length > 0) {
      return `Password must contain ${errors.join(', ')}`;
    }
    return null;
  },

  confirmPassword: (password: string) => (confirmValue: string) => {
    if (!confirmValue) return null;
    if (confirmValue !== password) {
      return 'Passwords do not match';
    }
    return null;
  },

  numeric: (value: string) => {
    if (!value) return null;
    if (!/^\d+$/.test(value)) {
      return 'Please enter numbers only';
    }
    return null;
  },

  decimal: (value: string) => {
    if (!value) return null;
    if (!/^\d+(\.\d{1,2})?$/.test(value)) {
      return 'Please enter a valid amount';
    }
    return null;
  },

  url: (value: string) => {
    if (!value) return null;
    try {
      new URL(value);
      return null;
    } catch {
      return 'Please enter a valid URL';
    }
  },

  creditCard: (value: string) => {
    if (!value) return null;
    const cleaned = value.replace(/\s/g, '');
    if (!/^\d{13,19}$/.test(cleaned)) {
      return 'Please enter a valid card number';
    }
    // Luhn algorithm
    let sum = 0;
    let isEven = false;
    for (let i = cleaned.length - 1; i >= 0; i--) {
      let digit = parseInt(cleaned[i], 10);
      if (isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      isEven = !isEven;
    }
    if (sum % 10 !== 0) {
      return 'Please enter a valid card number';
    }
    return null;
  },

  cvv: (value: string) => {
    if (!value) return null;
    if (!/^\d{3,4}$/.test(value)) {
      return 'Please enter a valid CVV';
    }
    return null;
  },

  expiryDate: (value: string) => {
    if (!value) return null;
    const [month, year] = value.split('/');
    const expiry = new Date(2000 + parseInt(year), parseInt(month) - 1);
    if (expiry < new Date()) {
      return 'Card has expired';
    }
    return null;
  },

  compose: (...validators: ((value: string) => string | null)[]) =>
    (value: string) => {
      for (const validator of validators) {
        const error = validator(value);
        if (error) return error;
      }
      return null;
    },
};
```

## iOS Form Handling (SwiftUI)

### Form State Management

```swift
// FormField.swift
import SwiftUI

@Observable
class FormField<T: Equatable> {
    var value: T
    var error: String?
    var isTouched: Bool = false
    var isDirty: Bool = false

    private let initialValue: T
    private let validators: [(T) -> String?]

    init(value: T, validators: [(T) -> String?] = []) {
        self.value = value
        self.initialValue = value
        self.validators = validators
    }

    func setValue(_ newValue: T) {
        value = newValue
        isDirty = value != initialValue
        if isTouched {
            validate()
        }
    }

    func touch() {
        isTouched = true
        validate()
    }

    func validate() -> Bool {
        for validator in validators {
            if let errorMessage = validator(value) {
                error = errorMessage
                return false
            }
        }
        error = nil
        return true
    }

    func reset() {
        value = initialValue
        error = nil
        isTouched = false
        isDirty = false
    }

    var isValid: Bool {
        error == nil && isTouched
    }
}

// FormState.swift
@Observable
class FormState {
    var isSubmitting: Bool = false
    var submitError: String?
    var isSubmitted: Bool = false

    private var fields: [AnyHashable: any AnyFormField] = [:]

    func register<T: Equatable>(_ field: FormField<T>, key: AnyHashable) {
        fields[key] = field
    }

    func validateAll() -> Bool {
        var isValid = true
        for (_, field) in fields {
            field.touchField()
            if !field.validateField() {
                isValid = false
            }
        }
        return isValid
    }

    func resetAll() {
        for (_, field) in fields {
            field.resetField()
        }
        isSubmitting = false
        submitError = nil
        isSubmitted = false
    }

    var isDirty: Bool {
        fields.values.contains { $0.isDirtyField }
    }

    var hasErrors: Bool {
        fields.values.contains { $0.hasError }
    }
}

protocol AnyFormField {
    func touchField()
    func validateField() -> Bool
    func resetField()
    var isDirtyField: Bool { get }
    var hasError: Bool { get }
}

extension FormField: AnyFormField {
    func touchField() { touch() }
    func validateField() -> Bool { validate() }
    func resetField() { reset() }
    var isDirtyField: Bool { isDirty }
    var hasError: Bool { error != nil }
}

// LoginFormViewModel.swift
@Observable
final class LoginFormViewModel {
    let email = FormField<String>(
        value: "",
        validators: [
            Validators.required("Email is required"),
            Validators.email("Please enter a valid email")
        ]
    )

    let password = FormField<String>(
        value: "",
        validators: [
            Validators.required("Password is required"),
            Validators.minLength(8, "Password must be at least 8 characters")
        ]
    )

    let formState = FormState()

    private let authService: AuthService

    init(authService: AuthService = .shared) {
        self.authService = authService
    }

    var isFormValid: Bool {
        email.isValid && password.isValid
    }

    func submit() async {
        guard formState.validateAll() else { return }

        formState.isSubmitting = true
        formState.submitError = nil

        do {
            try await authService.login(
                email: email.value,
                password: password.value
            )
            formState.isSubmitted = true
        } catch {
            formState.submitError = error.localizedDescription
        }

        formState.isSubmitting = false
    }
}

// Validators.swift
enum Validators {
    static func required(_ message: String = "This field is required") -> (String) -> String? {
        return { value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? message : nil
        }
    }

    static func email(_ message: String = "Invalid email") -> (String) -> String? {
        return { value in
            guard !value.isEmpty else { return nil }
            let emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
            return value.wholeMatch(of: emailRegex) != nil ? nil : message
        }
    }

    static func minLength(_ length: Int, _ message: String? = nil) -> (String) -> String? {
        return { value in
            guard !value.isEmpty else { return nil }
            let errorMessage = message ?? "Must be at least \(length) characters"
            return value.count >= length ? nil : errorMessage
        }
    }

    static func maxLength(_ length: Int, _ message: String? = nil) -> (String) -> String? {
        return { value in
            let errorMessage = message ?? "Must be no more than \(length) characters"
            return value.count <= length ? nil : errorMessage
        }
    }

    static func pattern(_ regex: Regex<Substring>, _ message: String) -> (String) -> String? {
        return { value in
            guard !value.isEmpty else { return nil }
            return value.wholeMatch(of: regex) != nil ? nil : message
        }
    }

    static func password(_ message: String = "Invalid password") -> (String) -> String? {
        return { value in
            guard !value.isEmpty else { return nil }
            let hasUppercase = value.contains(where: { $0.isUppercase })
            let hasLowercase = value.contains(where: { $0.isLowercase })
            let hasNumber = value.contains(where: { $0.isNumber })
            let hasMinLength = value.count >= 8

            if !hasUppercase || !hasLowercase || !hasNumber || !hasMinLength {
                return message
            }
            return nil
        }
    }
}
```

### SwiftUI Form View

```swift
// LoginFormView.swift
struct LoginFormView: View {
    @State private var viewModel = LoginFormViewModel()
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo or header
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.accentColor)
                        .padding(.top, 40)

                    Text("Welcome Back")
                        .font(.title.bold())

                    // Form fields
                    VStack(spacing: 16) {
                        FormTextField(
                            field: viewModel.email,
                            label: "Email",
                            placeholder: "Enter your email",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                        FormSecureField(
                            field: viewModel.password,
                            label: "Password",
                            placeholder: "Enter your password"
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await viewModel.submit() } }
                    }
                    .padding(.horizontal)

                    // Error message
                    if let error = viewModel.formState.submitError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // Submit button
                    AppButton(
                        "Sign In",
                        isLoading: viewModel.formState.isSubmitting,
                        isDisabled: !viewModel.isFormValid,
                        isFullWidth: true
                    ) {
                        focusedField = nil
                        Task { await viewModel.submit() }
                    }
                    .padding(.horizontal)

                    // Forgot password link
                    Button("Forgot Password?") {
                        // Navigate to forgot password
                    }
                    .font(.subheadline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }
}

// FormTextField.swift
struct FormTextField: View {
    @Bindable var field: FormField<String>
    let label: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            TextField(placeholder, text: Binding(
                get: { field.value },
                set: { field.setValue($0) }
            ))
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(field.error != nil ? Color.red : Color.clear, lineWidth: 1)
            )
            .onSubmit {
                field.touch()
            }

            if let error = field.error, field.isTouched {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// FormSecureField.swift
struct FormSecureField: View {
    @Bindable var field: FormField<String>
    let label: String
    let placeholder: String
    @State private var isSecure: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            HStack {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: Binding(
                            get: { field.value },
                            set: { field.setValue($0) }
                        ))
                    } else {
                        TextField(placeholder, text: Binding(
                            get: { field.value },
                            set: { field.setValue($0) }
                        ))
                    }
                }
                .textContentType(.password)

                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(field.error != nil ? Color.red : Color.clear, lineWidth: 1)
            )

            if let error = field.error, field.isTouched {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}
```

## Android Form Handling (Compose)

### Form State with ViewModel

```kotlin
// FormField.kt
data class FormField<T>(
    val value: T,
    val error: String? = null,
    val isTouched: Boolean = false,
    val isDirty: Boolean = false
)

// LoginFormState.kt
data class LoginFormState(
    val email: FormField<String> = FormField(""),
    val password: FormField<String> = FormField(""),
    val isSubmitting: Boolean = false,
    val submitError: String? = null
) {
    val isValid: Boolean
        get() = email.error == null && password.error == null &&
                email.value.isNotBlank() && password.value.isNotBlank()
}

// LoginFormViewModel.kt
@HiltViewModel
class LoginFormViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _state = MutableStateFlow(LoginFormState())
    val state: StateFlow<LoginFormState> = _state.asStateFlow()

    private val _events = Channel<LoginFormEvent>(Channel.BUFFERED)
    val events: Flow<LoginFormEvent> = _events.receiveAsFlow()

    fun onEmailChange(value: String) {
        _state.update { state ->
            state.copy(
                email = state.email.copy(
                    value = value,
                    isDirty = true,
                    error = if (state.email.isTouched) validateEmail(value) else null
                )
            )
        }
    }

    fun onEmailBlur() {
        _state.update { state ->
            state.copy(
                email = state.email.copy(
                    isTouched = true,
                    error = validateEmail(state.email.value)
                )
            )
        }
    }

    fun onPasswordChange(value: String) {
        _state.update { state ->
            state.copy(
                password = state.password.copy(
                    value = value,
                    isDirty = true,
                    error = if (state.password.isTouched) validatePassword(value) else null
                )
            )
        }
    }

    fun onPasswordBlur() {
        _state.update { state ->
            state.copy(
                password = state.password.copy(
                    isTouched = true,
                    error = validatePassword(state.password.value)
                )
            )
        }
    }

    fun submit() {
        val currentState = _state.value

        // Validate all fields
        val emailError = validateEmail(currentState.email.value)
        val passwordError = validatePassword(currentState.password.value)

        _state.update { state ->
            state.copy(
                email = state.email.copy(isTouched = true, error = emailError),
                password = state.password.copy(isTouched = true, error = passwordError)
            )
        }

        if (emailError != null || passwordError != null) {
            return
        }

        viewModelScope.launch {
            _state.update { it.copy(isSubmitting = true, submitError = null) }

            val result = authRepository.login(
                email = currentState.email.value,
                password = currentState.password.value
            )

            result.fold(
                onSuccess = {
                    _events.send(LoginFormEvent.NavigateToHome)
                },
                onFailure = { error ->
                    _state.update {
                        it.copy(
                            isSubmitting = false,
                            submitError = error.message ?: "Login failed"
                        )
                    }
                }
            )
        }
    }

    private fun validateEmail(value: String): String? {
        return when {
            value.isBlank() -> "Email is required"
            !Patterns.EMAIL_ADDRESS.matcher(value).matches() -> "Invalid email address"
            else -> null
        }
    }

    private fun validatePassword(value: String): String? {
        return when {
            value.isBlank() -> "Password is required"
            value.length < 8 -> "Password must be at least 8 characters"
            else -> null
        }
    }
}

sealed class LoginFormEvent {
    data object NavigateToHome : LoginFormEvent()
}

// LoginScreen.kt
@Composable
fun LoginScreen(
    viewModel: LoginFormViewModel = hiltViewModel(),
    onNavigateToHome: () -> Unit,
    onNavigateToForgotPassword: () -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val focusManager = LocalFocusManager.current
    val passwordFocusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is LoginFormEvent.NavigateToHome -> onNavigateToHome()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(48.dp))

        // Header
        Icon(
            imageVector = Icons.Default.Person,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Welcome Back",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Email field
        AppTextField(
            value = state.email.value,
            onValueChange = viewModel::onEmailChange,
            label = "Email",
            placeholder = "Enter your email",
            errorMessage = state.email.error,
            leadingIcon = Icons.Default.Email,
            keyboardType = KeyboardType.Email,
            imeAction = ImeAction.Next,
            onImeAction = { passwordFocusRequester.requestFocus() },
            modifier = Modifier
                .fillMaxWidth()
                .onFocusChanged { if (!it.isFocused) viewModel.onEmailBlur() }
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Password field
        AppTextField(
            value = state.password.value,
            onValueChange = viewModel::onPasswordChange,
            label = "Password",
            placeholder = "Enter your password",
            errorMessage = state.password.error,
            leadingIcon = Icons.Default.Lock,
            isPassword = true,
            imeAction = ImeAction.Done,
            onImeAction = {
                focusManager.clearFocus()
                viewModel.submit()
            },
            modifier = Modifier
                .fillMaxWidth()
                .focusRequester(passwordFocusRequester)
                .onFocusChanged { if (!it.isFocused) viewModel.onPasswordBlur() }
        )

        // Submit error
        AnimatedVisibility(visible = state.submitError != null) {
            Text(
                text = state.submitError ?: "",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Submit button
        AppButton(
            text = "Sign In",
            onClick = {
                focusManager.clearFocus()
                viewModel.submit()
            },
            isLoading = state.isSubmitting,
            enabled = state.isValid,
            fullWidth = true
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Forgot password
        TextButton(onClick = onNavigateToForgotPassword) {
            Text("Forgot Password?")
        }
    }
}
```

## React Native Form Handling

### React Hook Form with Zod

```typescript
// schemas/authSchemas.ts
import { z } from 'zod';

export const loginSchema = z.object({
  email: z
    .string()
    .min(1, 'Email is required')
    .email('Please enter a valid email'),
  password: z
    .string()
    .min(1, 'Password is required')
    .min(8, 'Password must be at least 8 characters'),
});

export const registerSchema = z
  .object({
    name: z
      .string()
      .min(1, 'Name is required')
      .min(2, 'Name must be at least 2 characters'),
    email: z
      .string()
      .min(1, 'Email is required')
      .email('Please enter a valid email'),
    password: z
      .string()
      .min(1, 'Password is required')
      .min(8, 'Password must be at least 8 characters')
      .regex(
        /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/,
        'Password must contain uppercase, lowercase, and number'
      ),
    confirmPassword: z.string().min(1, 'Please confirm your password'),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });

export type LoginFormData = z.infer<typeof loginSchema>;
export type RegisterFormData = z.infer<typeof registerSchema>;

// hooks/useLoginForm.ts
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { loginSchema, LoginFormData } from '../schemas/authSchemas';
import { useAuthStore } from '../stores/authStore';

export const useLoginForm = (onSuccess?: () => void) => {
  const { login } = useAuthStore();

  const form = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
    },
    mode: 'onBlur',
  });

  const onSubmit = async (data: LoginFormData) => {
    try {
      await login(data.email, data.password);
      onSuccess?.();
    } catch (error) {
      if (error instanceof Error) {
        form.setError('root', { message: error.message });
      }
    }
  };

  return {
    form,
    onSubmit: form.handleSubmit(onSubmit),
    isSubmitting: form.formState.isSubmitting,
    errors: form.formState.errors,
  };
};

// screens/LoginScreen.tsx
import React, { useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  TextInput as RNTextInput,
  StyleSheet,
} from 'react-native';
import { Controller } from 'react-hook-form';
import { useLoginForm } from '../hooks/useLoginForm';
import { TextInput } from '../components/TextInput';
import { Button } from '../components/Button';
import { tokens } from '../design/theme';

export const LoginScreen: React.FC<{ onSuccess: () => void }> = ({
  onSuccess,
}) => {
  const { form, onSubmit, isSubmitting, errors } = useLoginForm(onSuccess);
  const passwordRef = useRef<RNTextInput>(null);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <Text style={styles.title}>Welcome Back</Text>
          <Text style={styles.subtitle}>Sign in to continue</Text>
        </View>

        <View style={styles.form}>
          <Controller
            control={form.control}
            name="email"
            render={({ field: { onChange, onBlur, value }, fieldState }) => (
              <TextInput
                label="Email"
                placeholder="Enter your email"
                value={value}
                onChangeText={onChange}
                onBlur={onBlur}
                error={fieldState.error?.message}
                keyboardType="email-address"
                autoCapitalize="none"
                autoComplete="email"
                returnKeyType="next"
                onSubmitEditing={() => passwordRef.current?.focus()}
                blurOnSubmit={false}
              />
            )}
          />

          <Controller
            control={form.control}
            name="password"
            render={({ field: { onChange, onBlur, value }, fieldState }) => (
              <TextInput
                ref={passwordRef}
                label="Password"
                placeholder="Enter your password"
                value={value}
                onChangeText={onChange}
                onBlur={onBlur}
                error={fieldState.error?.message}
                isPassword
                autoCapitalize="none"
                autoComplete="password"
                returnKeyType="done"
                onSubmitEditing={onSubmit}
              />
            )}
          />

          {errors.root && (
            <Text style={styles.errorText}>{errors.root.message}</Text>
          )}

          <Button
            title="Sign In"
            onPress={onSubmit}
            isLoading={isSubmitting}
            isDisabled={!form.formState.isValid}
            fullWidth
            style={styles.submitButton}
          />
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: tokens.colors.neutral[0],
  },
  scrollContent: {
    flexGrow: 1,
    padding: 24,
  },
  header: {
    alignItems: 'center',
    marginTop: 48,
    marginBottom: 32,
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    color: tokens.colors.neutral[900],
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: tokens.colors.neutral[500],
  },
  form: {
    gap: 16,
  },
  errorText: {
    color: tokens.colors.semantic.error,
    fontSize: 14,
    textAlign: 'center',
  },
  submitButton: {
    marginTop: 8,
  },
});
```

## Flutter Form Handling

### Form with Reactive Forms

```dart
// forms/login_form.dart
import 'package:reactive_forms/reactive_forms.dart';

class LoginForm {
  static FormGroup build() {
    return FormGroup({
      'email': FormControl<String>(
        value: '',
        validators: [
          Validators.required,
          Validators.email,
        ],
      ),
      'password': FormControl<String>(
        value: '',
        validators: [
          Validators.required,
          Validators.minLength(8),
        ],
      ),
    });
  }
}

// Custom validators
class CustomValidators {
  static Map<String, dynamic>? passwordStrength(AbstractControl control) {
    final value = control.value as String?;
    if (value == null || value.isEmpty) return null;

    final errors = <String>[];

    if (!value.contains(RegExp(r'[A-Z]'))) {
      errors.add('uppercase');
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      errors.add('lowercase');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      errors.add('number');
    }
    if (!value.contains(RegExp(r'[!@#$%^&*]'))) {
      errors.add('special');
    }

    return errors.isEmpty ? null : {'passwordStrength': errors};
  }

  static ValidatorFunction mustMatch(String controlName, String matchingControlName) {
    return (AbstractControl control) {
      final form = control as FormGroup;
      final control1 = form.control(controlName);
      final control2 = form.control(matchingControlName);

      if (control1.value != control2.value) {
        control2.setErrors({'mustMatch': true});
        return {'mustMatch': true};
      }

      control2.removeError('mustMatch');
      return null;
    };
  }
}

// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final FormGroup form;
  final _passwordFocusNode = FocusNode();
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    form = LoginForm.build();
  }

  @override
  void dispose() {
    form.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (form.invalid) {
      form.markAllAsTouched();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.login(
        email: form.control('email').value as String,
        password: form.control('password').value as String,
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _submitError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ReactiveForm(
          formGroup: form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),

                // Header
                const Icon(
                  Icons.person_outline,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email field
                ReactiveTextField<String>(
                  formControlName: 'email',
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Email is required',
                    ValidationMessage.email: (_) => 'Please enter a valid email',
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                ReactiveTextField<String>(
                  formControlName: 'password',
                  focusNode: _passwordFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validationMessages: {
                    ValidationMessage.required: (_) => 'Password is required',
                    ValidationMessage.minLength: (_) =>
                        'Password must be at least 8 characters',
                  },
                ),

                // Submit error
                if (_submitError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submitError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // Submit button
                ReactiveFormConsumer(
                  builder: (context, formGroup, child) {
                    return AppButton(
                      text: 'Sign In',
                      onPressed: formGroup.valid ? _submit : null,
                      isLoading: _isSubmitting,
                      isFullWidth: true,
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Forgot password
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## Async Validation

### Email Availability Check

```typescript
// React Native
const checkEmailAvailability = async (email: string): Promise<boolean> => {
  const response = await apiClient.get<{ available: boolean }>(
    `/auth/check-email?email=${encodeURIComponent(email)}`
  );
  return response.available;
};

// In form schema
export const registerSchema = z.object({
  email: z
    .string()
    .email()
    .refine(async (email) => {
      const available = await checkEmailAvailability(email);
      return available;
    }, 'This email is already registered'),
});
```

```swift
// iOS
func validateEmailAvailability(_ email: String) async -> String? {
    do {
        let isAvailable = try await authService.checkEmailAvailability(email)
        return isAvailable ? nil : "This email is already registered"
    } catch {
        return "Unable to verify email"
    }
}
```

## Output Expectations

When implementing form handling, the subagent should:

1. Create reusable form field components
2. Implement comprehensive validation rules
3. Support real-time and on-blur validation
4. Handle async validation with debouncing
5. Manage keyboard navigation between fields
6. Show clear error messages
7. Handle form submission states
8. Support form state persistence
9. Implement accessible form controls
10. Create cross-field validation rules
