// lib/core/utils/auth_error_handler.dart
//
// Centralised auth error → user-friendly message mapper.
// Used by LoginScreen, RegisterScreen, and main.dart's _AuthFlowState.

class AuthErrorHandler {
  AuthErrorHandler._();

  /// Returns a short, human-readable message for any Supabase / network error
  /// that comes out of sign-in, sign-up, or password-update calls.
  static AuthErrorResult parse(Object error) {
    final raw = error.toString().toLowerCase();

    // ── Supabase GoTrue error codes ────────────────────────────────────────

    // Wrong password
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid password') ||
        raw.contains('wrong password') ||
        raw.contains('email or password') ||
        (raw.contains('400') && raw.contains('credentials'))) {
      return const AuthErrorResult(
        message: 'Incorrect email or password. Please try again.',
        field: AuthErrorField.password,
      );
    }

    // Email not found
    if (raw.contains('user not found') ||
        raw.contains('no user found') ||
        raw.contains('email not found')) {
      return const AuthErrorResult(
        message: 'No account found with that email address.',
        field: AuthErrorField.email,
      );
    }

    // Email not confirmed / unverified
    if (raw.contains('email not confirmed') ||
        raw.contains('email_not_confirmed') ||
        raw.contains('confirm your email') ||
        raw.contains('not confirmed')) {
      return const AuthErrorResult(
        message:
            'Please verify your email before signing in. Check your inbox for a confirmation link.',
        field: AuthErrorField.general,
        actionLabel: 'Resend Email',
        action: AuthErrorAction.resendConfirmation,
      );
    }

    // Account already exists
    if (raw.contains('user already registered') ||
        raw.contains('already registered') ||
        raw.contains('email already in use') ||
        raw.contains('already exists')) {
      return const AuthErrorResult(
        message: 'An account with this email already exists. Try signing in.',
        field: AuthErrorField.email,
      );
    }

    // Weak password
    if (raw.contains('password should be at least') ||
        raw.contains('weak password') ||
        raw.contains('password is too short')) {
      return const AuthErrorResult(
        message: 'Password must be at least 6 characters.',
        field: AuthErrorField.password,
      );
    }

    // Invalid email format
    if (raw.contains('invalid email') ||
        raw.contains('email address is invalid') ||
        raw.contains('malformed')) {
      return const AuthErrorResult(
        message: 'Please enter a valid email address.',
        field: AuthErrorField.email,
      );
    }

    // Rate limited / too many attempts
    if (raw.contains('too many requests') ||
        raw.contains('rate limit') ||
        raw.contains('429')) {
      return const AuthErrorResult(
        message: 'Too many attempts. Please wait a moment and try again.',
        field: AuthErrorField.general,
      );
    }

    // Token expired (e.g. magic link / password reset)
    if (raw.contains('token expired') ||
        raw.contains('otp expired') ||
        raw.contains('link has expired')) {
      return const AuthErrorResult(
        message: 'This link has expired. Please request a new one.',
        field: AuthErrorField.general,
      );
    }

    // Network / connectivity
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection refused') ||
        raw.contains('no internet') ||
        raw.contains('clientexception')) {
      return const AuthErrorResult(
        message: 'No internet connection. Please check your network and retry.',
        field: AuthErrorField.general,
      );
    }

    // Server error
    if (raw.contains('500') ||
        raw.contains('503') ||
        raw.contains('internal server error') ||
        raw.contains('service unavailable')) {
      return const AuthErrorResult(
        message: 'Our servers are having trouble. Please try again shortly.',
        field: AuthErrorField.general,
      );
    }

    // ── Fallback ───────────────────────────────────────────────────────────
    return const AuthErrorResult(
      message: 'Something went wrong. Please try again.',
      field: AuthErrorField.general,
    );
  }
}

/// Which field the error relates to (used to set inline validation text).
enum AuthErrorField { email, password, general }

/// Optional recoverable action the UI can offer alongside the error.
enum AuthErrorAction { resendConfirmation }

class AuthErrorResult {
  final String message;
  final AuthErrorField field;
  final String? actionLabel;
  final AuthErrorAction? action;

  const AuthErrorResult({
    required this.message,
    required this.field,
    this.actionLabel,
    this.action,
  });
}
