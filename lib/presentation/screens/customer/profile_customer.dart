// lib/presentation/screens/customer/profile_customer.dart
//
// CustomerProfileScreen — Full-featured profile screen for Homeowner role.
//
// Features:
//   • Edit Profile    — name + phone, saved to Supabase via onSaveProfile
//   • Change Password — current / new / confirm, saved via onChangePassword
//   • Avatar upload   — pick from gallery or camera, saved via onUploadAvatar
//   • Privacy Policy  — tap handler
//   • Logout          — confirmation dialog
//
// Props:
//   user              → UserEntity?
//   onBack            → VoidCallback?
//   onSaveProfile     → Future<void> Function(String name, String? phone)?
//   onChangePassword  → Future<void> Function(String currentPw, String newPw)?
//   onUploadAvatar    → Future<String?> Function(List<int> bytes, String fileName)?
//                        returns the new public URL (or null on skip)
//   onPrivacyPolicy   → VoidCallback?
//   onLogout          → VoidCallback?

import 'dart:io';
import 'package:fixify/presentation/screens/customer/customer_tour_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerProfileScreen extends StatefulWidget {
  final UserEntity? user;
  final VoidCallback? onBack;
  final Future<void> Function(String name, String? phone)? onSaveProfile;
  final Future<void> Function(String currentPassword, String newPassword)?
      onChangePassword;
  final Future<String?> Function(List<int> bytes, String fileName)?
      onUploadAvatar;
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onLogout;

  /// Called after the tour prefs key is cleared so the parent can navigate
  /// back to the dashboard where the tour will auto-start.
  final VoidCallback? onReplayTour;

  const CustomerProfileScreen({
    super.key,
    this.user,
    this.onBack,
    this.onSaveProfile,
    this.onChangePassword,
    this.onUploadAvatar,
    this.onPrivacyPolicy,
    this.onLogout,
    this.onReplayTour,
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late String _name;
  late String? _phone;
  String? _avatarUrl; // remote URL
  File? _avatarFile; // local picked file (preview while uploading)

  @override
  void initState() {
    super.initState();
    _name = widget.user?.name ?? 'Customer';
    _phone = widget.user?.phone;
    _avatarUrl = widget.user?.avatarUrl;
  }

  // ── SHARED CHROME HELPERS ─────────────────────────────────

  /// Standard bottom-sheet chrome wrapper
  Widget _sheet({required Widget child}) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2)),
          ),
          child,
        ]),
      );

  /// Reusable text field for all bottom sheets
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      obscureText: obscure,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  /// Cancel + primary action button row
  Widget _sheetButtons({
    required BuildContext ctx,
    required String actionLabel,
    required bool saving,
    required VoidCallback? onAction,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16)),
                child: const Center(
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: saving ? null : onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F3D2E), Color(0xFF1A5C43)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : Text(actionLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      );

  void _showError(BuildContext ctx, String msg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── 1. EDIT PROFILE SHEET ─────────────────────────────────

  void _openEditSheet() {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _sheet(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.edit_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Edit Profile',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ]),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: formKey,
                  child: Column(children: [
                    _buildField(
                      controller: nameCtrl,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name cannot be empty'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: phoneCtrl,
                      label: 'Mobile Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (v) {
                        if (v != null && v.isNotEmpty && v.length < 10)
                          return 'Enter a valid phone number';
                        return null;
                      },
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              _sheetButtons(
                ctx: ctx,
                actionLabel: 'Save Changes',
                saving: saving,
                onAction: () async {
                  if (!formKey.currentState!.validate()) return;
                  set(() => saving = true);
                  final newName = nameCtrl.text.trim();
                  final newPhone = phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim();
                  try {
                    await widget.onSaveProfile?.call(newName, newPhone);
                    if (mounted)
                      setState(() {
                        _name = newName;
                        _phone = newPhone;
                      });
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _showSuccess('Profile updated successfully!');
                  } catch (e) {
                    set(() => saving = false);
                    if (ctx.mounted) _showError(ctx, 'Failed to save: $e');
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 2. CHANGE PASSWORD SHEET ──────────────────────────────

  void _openChangePasswordSheet() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _sheet(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Change Password',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ]),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: formKey,
                  child: Column(children: [
                    // Current password
                    _buildField(
                      controller: currentCtrl,
                      label: 'Current Password',
                      icon: Icons.lock_outline_rounded,
                      obscure: !showCurrent,
                      suffixIcon: IconButton(
                        icon: Icon(
                            showCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                            size: 20),
                        onPressed: () => set(() => showCurrent = !showCurrent),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your current password'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // New password
                    _buildField(
                      controller: newCtrl,
                      label: 'New Password',
                      icon: Icons.lock_reset_rounded,
                      obscure: !showNew,
                      suffixIcon: IconButton(
                        icon: Icon(
                            showNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                            size: 20),
                        onPressed: () => set(() => showNew = !showNew),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Enter a new password';
                        if (v.length < 6)
                          return 'Password must be at least 6 characters';
                        if (v == currentCtrl.text)
                          return 'New password must differ from current';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Confirm password
                    _buildField(
                      controller: confirmCtrl,
                      label: 'Confirm New Password',
                      icon: Icons.check_circle_outline_rounded,
                      obscure: !showConfirm,
                      suffixIcon: IconButton(
                        icon: Icon(
                            showConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textLight,
                            size: 20),
                        onPressed: () => set(() => showConfirm = !showConfirm),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Please confirm your password';
                        if (v != newCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              _sheetButtons(
                ctx: ctx,
                actionLabel: 'Update Password',
                saving: saving,
                onAction: () async {
                  if (!formKey.currentState!.validate()) return;
                  set(() => saving = true);
                  try {
                    await widget.onChangePassword
                        ?.call(currentCtrl.text, newCtrl.text);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    _showSuccess('Password updated successfully!');
                  } catch (e) {
                    set(() => saving = false);
                    if (ctx.mounted)
                      _showError(ctx, 'Failed to update password: $e');
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── 3. AVATAR PICKER ──────────────────────────────────────

  void _openAvatarSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheet(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Profile Picture',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ]),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose how to update your profile photo',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight)),
            ),
          ),
          const SizedBox(height: 16),
          _avatarOption(
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
            sub: 'Pick a photo from your device',
            onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.gallery);
            },
          ),
          const Divider(
              height: 1, indent: 24, endIndent: 24, color: Color(0xFFEEEEEE)),
          _avatarOption(
            icon: Icons.camera_alt_outlined,
            label: 'Take a Photo',
            sub: 'Use your camera',
            onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.camera);
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16)),
                child: const Center(
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMedium)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _avatarOption({
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ]),
        ),
      );

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source, imageQuality: 80, maxWidth: 512);
      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Show local preview immediately while uploading
      setState(() => _avatarFile = file);

      final newUrl =
          await widget.onUploadAvatar?.call(bytes.toList(), fileName);

      if (mounted) {
        setState(() {
          if (newUrl != null) _avatarUrl = newUrl;
          _avatarFile = null; // clear temp once URL is ready
        });
        _showSuccess('Profile picture updated!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _avatarFile = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  // ── TOUR REPLAY ───────────────────────────────────────────

  Future<void> _resetAndReplayTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kCustomerTourSeenKey);
    } catch (e) {
      debugPrint('[Tour] Could not reset tour prefs: $e');
    }
    // Navigate back to the dashboard — the tour auto-starts on next build.
    widget.onReplayTour?.call();
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildAccountCard(),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08, end: 0),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildActionsCard(),
            ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08, end: 0),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: _buildLogoutButton(context),
            ).animate().fadeIn(delay: 300.ms),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final initials = _name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    // Priority: local file preview > remote URL > initials
    ImageProvider? avatarImage;
    if (_avatarFile != null) {
      avatarImage = FileImage(_avatarFile!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_avatarUrl!);
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(children: [
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(children: [
              // Top bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Text('Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: _openEditSheet,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Avatar — tappable to change photo
              GestureDetector(
                onTap: _openAvatarSheet,
                child: Stack(children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34C759), Color(0xFF1A5C43)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35), width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: avatarImage != null
                        ? ClipOval(
                            child: Image(
                                image: avatarImage,
                                fit: BoxFit.cover,
                                width: 88,
                                height: 88))
                        : Center(
                            child: Text(
                              initials.isNotEmpty ? initials : 'C',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0F3D2E), width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Color(0xFF0F3D2E), size: 13),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text(_name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Homeowner',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: -0.04, end: 0);
  }

  // ── ACCOUNT INFO CARD ─────────────────────────────────────

  Widget _buildAccountCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Account Information',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMedium,
                    letterSpacing: 0.3)),
          ),
          _infoRow(
              icon: Icons.person_outline_rounded,
              label: 'Full Name',
              value: _name),
          _divider(),
          _infoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: widget.user?.email ?? '—'),
          _divider(),
          _infoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile Number',
              value: _phone ?? '—'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ]),
        ),
      ]),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 72, endIndent: 20, color: Color(0xFFEEEEEE));

  // ── ACTIONS CARD ──────────────────────────────────────────

  Widget _buildActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        _actionRow(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: _openChangePasswordSheet,
        ),
        const Divider(
            height: 1, indent: 20, endIndent: 20, color: Color(0xFFEEEEEE)),
        _actionRow(
          icon: Icons.shield_outlined,
          label: 'Privacy Policy',
          onTap: widget.onPrivacyPolicy,
        ),
        const Divider(
            height: 1, indent: 20, endIndent: 20, color: Color(0xFFEEEEEE)),
        _actionRow(
          icon: Icons.lightbulb_outline_rounded,
          label: 'App Tour',
          onTap: _resetAndReplayTour,
        ),
      ]),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.textDark;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color ?? AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: c)),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 20),
        ]),
      ),
    );
  }

  // ── LOGOUT ────────────────────────────────────────────────

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFFF3B30), size: 22),
            SizedBox(width: 10),
            Text('Logout',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF3B30))),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onLogout?.call();
            },
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
