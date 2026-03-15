// lib/presentation/screens/auth/login_screen.dart
//
// Changes from previous version:
//  1. Added `initialEmail` parameter — when coming from RegisterScreen the
//     email field is pre-filled so the user doesn't retype it.
//  2. _handleLogin now explicitly clears _isLoading on success path (not
//     just in the finally block) so the spinner dismisses immediately when
//     the auth stream is slow to fire and the widget is still mounted.
//  3. All other logic (AuthErrorHandler, inline errors, banner) unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_error_handler.dart';
import '../../widgets/shared_widgets.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onNavigateToRegister;
  final Function(String email, String password)? onLogin;
  final VoidCallback? onContinueAsGuest;

  /// When set, pre-fills the email field. Passed from AuthFlow after a
  /// successful registration so the user doesn't have to retype their email.
  final String? initialEmail;

  const LoginScreen({
    super.key,
    this.onNavigateToRegister,
    this.onLogin,
    this.onContinueAsGuest,
    this.initialEmail, // <-- NEW
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;
  String? _generalError;
  AuthErrorAction? _generalAction;

  @override
  void initState() {
    super.initState();
    // FIX: Pre-fill email when coming from registration
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    _emailController.addListener(_clearErrors);
    _passwordController.addListener(_clearErrors);
  }

  void _clearErrors() {
    if (_emailError != null ||
        _passwordError != null ||
        _generalError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
        _generalError = null;
        _generalAction = null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _applyError(AuthErrorResult result) {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
      _generalAction = null;

      switch (result.field) {
        case AuthErrorField.email:
          _emailError = result.message;
          break;
        case AuthErrorField.password:
          _passwordError = result.message;
          break;
        case AuthErrorField.general:
          _generalError = result.message;
          _generalAction = result.action;
          break;
      }
    });
  }

  void _showNetworkSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onLogin?.call(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // FIX: Login succeeded. The parent (AppNavigator via auth stream) will
      // replace this widget. However if the stream fires before this finally
      // block, the widget may already be unmounted — that is fine. If the
      // widget is still mounted we clear the loading state so the UI doesn't
      // freeze on the spinner while waiting for the stream.
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      final result = AuthErrorHandler.parse(e);

      if (result.field == AuthErrorField.general &&
          result.message.toLowerCase().contains('internet')) {
        _showNetworkSnackbar(result.message);
      } else {
        _applyError(result);
      }
    } finally {
      // Guards against the case where the widget was disposed mid-await.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
          () => _emailError = 'Enter your email so we can resend the link.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Confirmation email sent! Check your inbox.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _generalError = null;
          _generalAction = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showNetworkSnackbar('Could not send email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F2EE), Color(0xFFF5F5F3)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Container(
                    height: 260,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF082218),
                          Color(0xFF0F3D2E),
                          Color(0xFF1A5C43),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -40,
                          right: -40,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 20,
                          left: -30,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/logo.jpg',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Welcome back!',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Sign in to continue booking services',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Form card ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // General error banner
                            if (_generalError != null) ...[
                              _GeneralErrorBanner(
                                message: _generalError!,
                                actionLabel: _generalAction != null
                                    ? _getActionLabel(_generalAction!)
                                    : null,
                                onAction: _generalAction != null
                                    ? () =>
                                        _handleGeneralAction(_generalAction!)
                                    : null,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email field
                            _FieldWithError(
                              errorText: _emailError,
                              child: FixifyTextField(
                                controller: _emailController,
                                hint: 'Enter your email',
                                label: 'Email Address',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Email is required';
                                  if (!v.contains('@'))
                                    return 'Enter a valid email';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            _FieldWithError(
                              errorText: _passwordError,
                              child: FixifyTextField(
                                controller: _passwordController,
                                hint: 'Enter your password',
                                label: 'Password',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textLight,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return 'Password is required';
                                  if (v.length < 6)
                                    return 'At least 6 characters';
                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(double.infinity, 56),
                              ),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildDivider(),
                            const SizedBox(height: 24),
                            _buildSocialLogin(),
                            const SizedBox(height: 12),
                            _buildGuestButton(),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.1, end: 0),
                  ),

                  // ── Register link ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: AppColors.textMedium),
                        ),
                        GestureDetector(
                          onTap: widget.onNavigateToRegister,
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getActionLabel(AuthErrorAction action) {
    switch (action) {
      case AuthErrorAction.resendConfirmation:
        return 'Resend Email';
    }
  }

  void _handleGeneralAction(AuthErrorAction action) {
    switch (action) {
      case AuthErrorAction.resendConfirmation:
        _resendConfirmation();
        break;
    }
  }

  Widget _buildGuestButton() {
    if (widget.onContinueAsGuest == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: widget.onContinueAsGuest,
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              BorderSide(color: AppColors.textLight.withOpacity(0.3), width: 1),
        ),
      ),
      child: const Text(
        'Browse as Guest',
        style: TextStyle(
          color: AppColors.textLight,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.textLight.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ),
        Expanded(child: Divider(color: AppColors.textLight.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Image.asset('assets/images/googlelogo.png', width: 24, height: 24),
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textDark,
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ── Field + server-side inline error wrapper ─────────────────────────────────

class _FieldWithError extends StatelessWidget {
  final Widget child;
  final String? errorText;

  const _FieldWithError({required this.child, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 13, color: Color(0xFFD32F2F)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD32F2F),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Inline general-error banner ──────────────────────────────────────────────

class _GeneralErrorBanner extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _GeneralErrorBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDC6B), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF856404), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF664D03),
                    height: 1.4,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F3D2E),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
