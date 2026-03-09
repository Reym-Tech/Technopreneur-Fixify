// lib/presentation/screens/auth/register_screen.dart
//
// KEY CHANGE: This screen now owns all Supabase signup logic directly instead
// of delegating to main.dart. This fixes the post-register splash-loop bug.
//
// ROOT CAUSE OF BUG: The old flow called auth.signOut() inside _AuthFlowState
// after signUp. That fired onAuthStateChange → AppNavigator rebuilt → replaced
// AuthFlow with a brand-new const instance → _showSplash reset to true and
// _prefillEmail was lost.
//
// FIX: All Supabase calls (signUp, DB inserts, signOut) now happen here.
// When done, we call onSuccess(email) — a plain Dart callback into
// _AuthFlowState.setState — which switches to LoginScreen with the email
// pre-filled. AppNavigator's stream listener receives the signedOut event but
// _isLoggedIn was already false, so it's a no-op and AuthFlow is NOT recreated.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/auth_error_handler.dart';
import '../../widgets/shared_widgets.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLogin;

  /// Called with the registered email after a successful signup.
  /// AuthFlow uses this to switch to LoginScreen with the email pre-filled.
  final void Function(String email)? onSuccess;

  const RegisterScreen({
    super.key,
    this.onNavigateToLogin,
    this.onSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedRole = 'customer';
  bool _obscurePassword = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;
  String? _generalError;

  @override
  void initState() {
    super.initState();
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
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _applyError(AuthErrorResult result) {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;

      switch (result.field) {
        case AuthErrorField.email:
          _emailError = result.message;
          break;
        case AuthErrorField.password:
          _passwordError = result.message;
          break;
        case AuthErrorField.general:
          _generalError = result.message;
          break;
      }
    });
  }

  Future<void> _handleRegister() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final phone =
        _phoneController.text.isEmpty ? null : _phoneController.text.trim();
    final role = _selectedRole;

    setState(() => _isLoading = true);

    try {
      debugPrint('👤 Starting registration for: $email (role: $role)');

      // 1. Create auth account
      final res = await Supabase.instance.client.auth
          .signUp(email: email, password: password);

      if (res.user == null) {
        throw Exception('Unable to create account. Please try again.');
      }
      debugPrint('✅ Auth account created: ${res.user!.id}');

      // 2. Insert user row
      await Supabase.instance.client.from('users').insert({
        'id': res.user!.id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Insert professional row if needed
      if (role == 'professional') {
        try {
          await Supabase.instance.client.from('professionals').insert({
            'user_id': res.user!.id,
            'skills': [],
            'verified': false,
            'rating': 0.0,
            'review_count': 0,
            'available': true,
            'years_experience': 0,
          });
        } catch (proErr) {
          debugPrint('⚠️ Professional record warning: $proErr');
          // Non-fatal — pro row can be auto-created on first login.
        }
      }

      // 4. Sign out the implicit session Supabase created on signUp.
      //    Done BEFORE calling onSuccess so AppNavigator's stream listener
      //    gets the signedOut event while _isLoggedIn is already false —
      //    making it a no-op that does NOT recreate AuthFlow.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Ignore — we just need to clear the session token.
      }

      if (!mounted) return;

      // 5. Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Account created! Check your email to verify, then sign in.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 6. Brief pause so the snackbar is readable before screen switches
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      // 7. Hand off to AuthFlow via plain Dart callback — no Navigator push,
      //    no stream event, AuthFlow instance stays alive with _showSplash=false
      widget.onSuccess?.call(email);
    } catch (e) {
      if (!mounted) return;
      final result = AuthErrorHandler.parse(e);

      if (result.field == AuthErrorField.general &&
          result.message.toLowerCase().contains('internet')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(result.message)),
            ]),
            backgroundColor: const Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        _applyError(result);
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: widget.onNavigateToLogin,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join Fixify and get expert help at home',
                    style: TextStyle(fontSize: 15, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 28),

                  // Role selector
                  GlassCard(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        _buildRoleTab(
                            'customer', 'Homeowner', Icons.home_rounded),
                        _buildRoleTab('professional', 'Professional',
                            Icons.engineering_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // General error banner
                          if (_generalError != null) ...[
                            _RegisterErrorBanner(message: _generalError!),
                            const SizedBox(height: 16),
                          ],

                          FixifyTextField(
                            controller: _nameController,
                            hint: 'Full name',
                            label: 'Full Name',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 18),

                          _FieldWithError(
                            errorText: _emailError,
                            child: FixifyTextField(
                              controller: _emailController,
                              hint: 'Email address',
                              label: 'Email',
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
                          const SizedBox(height: 18),

                          FixifyTextField(
                            controller: _phoneController,
                            hint: 'Phone number (optional)',
                            label: 'Phone',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),

                          _FieldWithError(
                            errorText: _passwordError,
                            child: FixifyTextField(
                              controller: _passwordController,
                              hint: 'Create a password',
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
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
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
                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              minimumSize: const Size(double.infinity, 56),
                            ),
                            child: Text(
                              _selectedRole == 'customer'
                                  ? 'Create Homeowner Account'
                                  : 'Create Professional Account',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Center(
                    child: Text(
                      'By creating an account, you agree to our\nTerms of Service and Privacy Policy',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AppColors.textMedium),
                      ),
                      GestureDetector(
                        onTap: widget.onNavigateToLogin,
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String role, String label, IconData icon) {
    final selected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textMedium),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field + inline error wrapper ─────────────────────────────────────────────

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

// ── Register error banner ────────────────────────────────────────────────────

class _RegisterErrorBanner extends StatelessWidget {
  final String message;
  const _RegisterErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C6C6), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFD32F2F), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7F1D1D),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
