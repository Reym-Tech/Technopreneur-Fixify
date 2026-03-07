// lib/presentation/screens/professional/profile_professional.dart
//
// ProfessionalProfileScreen — Full-featured profile for Handyman role.
//
// Features:
//   • Edit Profile    — name, phone, city; saved via onSaveProfile
//   • Change Password — current / new / confirm; saved via onChangePassword
//   • Avatar upload   — gallery or camera; saved via onUploadAvatar
//   • Privacy Policy  — tap handler
//   • Logout          — confirmation dialog
//
// Props:
//   user              → UserEntity?
//   professional      → ProfessionalEntity?
//   onBack            → VoidCallback?
//   onSaveProfile     → Future<void> Function(String name, String? phone, String? city)?
//   onChangePassword  → Future<void> Function(String currentPw, String newPw)?
//   onUploadAvatar    → Future<String?> Function(List<int> bytes, String fileName)?
//   onServicesOffered → VoidCallback?
//   onPayoutSettings  → VoidCallback?
//   onPrivacyPolicy   → VoidCallback?
//   onLogout          → VoidCallback?

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  final UserEntity? user;
  final ProfessionalEntity? professional;
  final VoidCallback? onBack;
  final Future<void> Function(String name, String? phone, String? city)?
      onSaveProfile;
  final Future<void> Function(String currentPassword, String newPassword)?
      onChangePassword;
  final Future<String?> Function(List<int> bytes, String fileName)?
      onUploadAvatar;
  final VoidCallback? onServicesOffered;
  final VoidCallback? onPayoutSettings;
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onLogout;

  const ProfessionalProfileScreen({
    super.key,
    this.user,
    this.professional,
    this.onBack,
    this.onSaveProfile,
    this.onChangePassword,
    this.onUploadAvatar,
    this.onServicesOffered,
    this.onPayoutSettings,
    this.onPrivacyPolicy,
    this.onLogout,
  });

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen> {
  late String _name;
  late String? _phone;
  late String? _city;
  String? _avatarUrl;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _name = widget.user?.name ?? 'Professional';
    _phone = widget.user?.phone;
    _city = widget.professional?.city;
    _avatarUrl = widget.user?.avatarUrl;
  }

  // ── SHARED CHROME HELPERS ─────────────────────────────────

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
    final cityCtrl = TextEditingController(text: _city ?? '');
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
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 20),
                // Header
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
                      const SizedBox(height: 16),
                      _buildField(
                        controller: cityCtrl,
                        label: 'City / Address',
                        icon: Icons.location_on_outlined,
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
                    final newCity = cityCtrl.text.trim().isEmpty
                        ? null
                        : cityCtrl.text.trim();
                    try {
                      await widget.onSaveProfile
                          ?.call(newName, newPhone, newCity);
                      if (mounted)
                        setState(() {
                          _name = newName;
                          _phone = newPhone;
                          _city = newCity;
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
            child: SingleChildScrollView(
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
                          onPressed: () =>
                              set(() => showCurrent = !showCurrent),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your current password'
                            : null,
                      ),
                      const SizedBox(height: 16),
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
                          onPressed: () =>
                              set(() => showConfirm = !showConfirm),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Please confirm your password';
                          if (v != newCtrl.text)
                            return 'Passwords do not match';
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
            const Icon(Icons.chevron_right_rounded,
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

      // Show local preview immediately
      setState(() => _avatarFile = file);

      final newUrl =
          await widget.onUploadAvatar?.call(bytes.toList(), fileName);

      if (mounted) {
        setState(() {
          if (newUrl != null) _avatarUrl = newUrl;
          _avatarFile = null;
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildPersonalCard(),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08, end: 0),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildProfessionalCard(),
            ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08, end: 0),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildActionsCard(),
            ).animate().fadeIn(delay: 290.ms).slideY(begin: 0.08, end: 0),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: _buildLogoutButton(context),
            ).animate().fadeIn(delay: 360.ms),
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
    final verified = widget.professional?.verified ?? false;

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
                  const Text('Handyman Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  // Edit button opens the edit sheet
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
                              initials.isNotEmpty ? initials : 'P',
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Handyman',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: verified
                          ? const Color(0xFF34C759).withOpacity(0.2)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: verified
                            ? const Color(0xFF34C759).withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          verified
                              ? Icons.verified_rounded
                              : Icons.pending_rounded,
                          color: verified
                              ? const Color(0xFF34C759)
                              : Colors.white.withOpacity(0.6),
                          size: 13),
                      const SizedBox(width: 4),
                      Text(
                        verified ? 'Approved' : 'Pending',
                        style: TextStyle(
                            color: verified
                                ? const Color(0xFF34C759)
                                : Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: -0.04, end: 0);
  }

  // ── PERSONAL INFO CARD ────────────────────────────────────

  Widget _buildPersonalCard() {
    return _card(
      title: 'Personal Information',
      children: [
        _infoRow(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            value: _name),
        _divider(),
        _infoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile Number',
            value: _phone ?? '—'),
        _divider(),
        _infoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: widget.user?.email ?? '—'),
        _divider(),
        _infoRow(
            icon: Icons.location_on_outlined,
            label: 'City / Address',
            value: _city ?? 'Not specified'),
      ],
    );
  }

  // ── PROFESSIONAL INFO CARD ────────────────────────────────

  Widget _buildProfessionalCard() {
    final skills = widget.professional?.skills ?? [];
    final specialization = skills.isNotEmpty
        ? skills.map((s) => s[0].toUpperCase() + s.substring(1)).join(', ')
        : '—';

    final price = (widget.professional?.priceMin != null)
        ? '₱${widget.professional!.priceMin!.toStringAsFixed(0)}'
            '${widget.professional!.priceMax != null ? ' – ₱${widget.professional!.priceMax!.toStringAsFixed(0)}' : ''}'
        : '—';

    final verified = widget.professional?.verified ?? false;

    return _card(
      title: 'Professional Information',
      children: [
        _infoRow(
            icon: Icons.work_outline_rounded,
            label: 'Specialization',
            value: specialization),
        _divider(),
        _infoRow(
            icon: Icons.trending_up_rounded,
            label: 'Years of Experience',
            value:
                '${widget.professional?.yearsExperience ?? 0} year${(widget.professional?.yearsExperience ?? 0) != 1 ? 's' : ''}'),
        _divider(),
        _infoRow(
            icon: Icons.attach_money_rounded,
            label: 'Price Range',
            value: price),
        _divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (verified
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF9500))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.verified_user_outlined,
                  color: verified
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF9500),
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verification Status',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: (verified
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF9500))
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (verified
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFFF9500))
                              .withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        verified ? 'APPROVED' : 'PENDING',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: verified
                                ? const Color(0xFF34C759)
                                : const Color(0xFFFF9500),
                            letterSpacing: 0.5),
                      ),
                    ),
                  ]),
            ),
          ]),
        ),
      ],
    );
  }

  // ── ACTIONS CARD ──────────────────────────────────────────

  Widget _buildActionsCard() {
    return _card(
      children: [
        _actionRow(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: _openChangePasswordSheet,
        ),
        _divider(),
        _actionRow(
          icon: Icons.shield_outlined,
          label: 'Privacy Policy',
          onTap: widget.onPrivacyPolicy,
        ),
      ],
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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

  // ── SHARED WIDGET HELPERS ─────────────────────────────────

  Widget _card({String? title, required List<Widget> children}) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                      letterSpacing: 0.3)),
            ),
          ...children,
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

  Widget _actionRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color ?? AppColors.textDark)),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 20),
        ]),
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 72, endIndent: 20, color: Color(0xFFEEEEEE));
}
