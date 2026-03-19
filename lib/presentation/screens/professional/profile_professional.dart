// lib/presentation/screens/professional/profile_professional.dart
//
// ProfessionalProfileScreen — Full-featured profile for Handyman role.
//
// Features:
//   • Edit Profile    — name, phone, city; saved via onSaveProfile
//   • Change Password — current / new / confirm; saved via onChangePassword
//   • Avatar upload   — gallery or camera; saved via onUploadAvatar
//   • Service Location — permission modal → map pin (Google Maps + GPS)
//                        Auto-reverse-geocodes → updates city/address field
//   • Privacy Policy  — tap handler
//   • Logout          — confirmation dialog
//
// Props:
//   user              → UserEntity?
//   professional      → ProfessionalEntity?
//   onBack            → VoidCallback?
//   onSaveProfile     → Future<void> Function(String name, String? phone, String? city)?
//   onSaveLocation    → Future<void> Function(double lat, double lng)?
//   onChangePassword  → Future<void> Function(String currentPw, String newPw)?
//   onUploadAvatar    → Future<String?> Function(List<int> bytes, String fileName)?
//   onServicesOffered → VoidCallback?
//   onPayoutSettings  → VoidCallback?
//   onPrivacyPolicy   → VoidCallback?
//   onLogout          → VoidCallback?

import 'dart:io';
import 'package:fixify/presentation/screens/professional/professional_tour_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; // Factory, EagerGestureRecognizer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfessionalProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfessionalProfileScreen extends StatefulWidget {
  final UserEntity? user;
  final ProfessionalEntity? professional;
  final VoidCallback? onBack;
  final Future<void> Function(String name, String? phone, String? city)?
      onSaveProfile;
  final Future<void> Function(double latitude, double longitude)?
      onSaveLocation;
  final Future<void> Function(String currentPassword, String newPassword)?
      onChangePassword;
  final Future<String?> Function(List<int> bytes, String fileName)?
      onUploadAvatar;
  final VoidCallback? onServicesOffered;
  final VoidCallback? onPayoutSettings;
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onLogout;

  /// Called after the tour prefs key is cleared so the parent can navigate
  /// back to the dashboard where the tour will auto-start.
  final VoidCallback? onReplayTour;

  const ProfessionalProfileScreen({
    super.key,
    this.user,
    this.professional,
    this.onBack,
    this.onSaveProfile,
    this.onSaveLocation,
    this.onChangePassword,
    this.onUploadAvatar,
    this.onServicesOffered,
    this.onPayoutSettings,
    this.onPrivacyPolicy,
    this.onLogout,
    this.onReplayTour,
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

  // Tracks whether a location has been saved (green = set, orange = not set)
  double? _savedLat;
  double? _savedLng;

  @override
  void initState() {
    super.initState();
    _name = widget.user?.name ?? 'Professional';
    _phone = widget.user?.phone;
    _city = widget.professional?.city;
    _avatarUrl = widget.user?.avatarUrl;
    _savedLat = widget.professional?.latitude;
    _savedLng = widget.professional?.longitude;
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
                      await widget.onSaveProfile
                          ?.call(newName, newPhone, _city);
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

  // ── 4. LOCATION — permission check + modal ────────────────
  //
  // Flow:
  //   a) Check if location service is enabled on device.
  //   b) If permission is deniedForever  → show "Open Settings" dialog.
  //   c) If permission is denied         → show "Allow Location" dialog,
  //                                        then call requestPermission().
  //   d) If permission is granted        → open _LocationPickerSheet.
  //
  // _LocationPickerSheet.onSave persists lat/lng AND syncs the geocoded
  // city back to the City/Address field via onSaveProfile (best-effort).

  Future<void> _openLocationSheet() async {
    // ── a) Device location service ───────────────────────────
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showError(context, 'Location services are disabled on this device.');
      return;
    }

    // ── b/c) Permission ──────────────────────────────────────
    var status = await Geolocator.checkPermission();

    if (status == LocationPermission.deniedForever) {
      if (!mounted) return;
      await _showLocationPermissionModal(deniedForever: true);
      // Re-read after user may have changed settings
      status = await Geolocator.checkPermission();
      if (status != LocationPermission.always &&
          status != LocationPermission.whileInUse) return;
    } else if (status == LocationPermission.denied) {
      if (!mounted) return;
      // Show the explain-why dialog first, then trigger the OS prompt
      await _showLocationPermissionModal(deniedForever: false);
      if (!mounted) return;
      status = await Geolocator.requestPermission();
      if (status != LocationPermission.always &&
          status != LocationPermission.whileInUse) {
        if (mounted)
          _showError(context,
              'Location permission denied. Enable it in app settings.');
        return;
      }
    }

    // ── d) Permission granted → open map sheet ───────────────
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // prevent sheet drag stealing map pan gestures
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        initialLat: _savedLat,
        initialLng: _savedLng,
        onSave: (lat, lng, city) async {
          await widget.onSaveLocation?.call(lat, lng);
          if (mounted) {
            setState(() {
              _savedLat = lat;
              _savedLng = lng;
              if (city != null && city.isNotEmpty) _city = city;
            });
          }
          // Best-effort: sync geocoded city to DB
          if (city != null && city.isNotEmpty) {
            try {
              await widget.onSaveProfile?.call(_name, _phone, city);
            } catch (_) {
              // Non-fatal: location coords already saved
            }
          }
          _showSuccess(
              'Location saved! Customers can now see your route on the map.');
        },
      ),
    );
  }

  // ── Location permission modal ─────────────────────────────
  //
  // Mirrors the RequestServiceScreen permission dialog style:
  //   • Location icon in a tinted circle
  //   • Title + explanation text
  //   • Tinted info-banner
  //   • Primary action button  ("Allow Location" or "Open App Settings")
  //   • Secondary cancel link  (only when deniedForever, so user can skip
  //     going to Settings without triggering the OS prompt again)

  Future<void> _showLocationPermissionModal(
      {required bool deniedForever}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Icon ──────────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────
            const Text(
              'Allow Location Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 10),

            // ── Body ──────────────────────────────────────
            Text(
              deniedForever
                  ? 'Location permission was permanently denied.\n\n'
                      'Please open App Settings and enable location '
                      'access for Fixify so you can pin your service area on the map.'
                  : 'Fixify needs your location to accurately pin your '
                      'service area on the map so customers can find you.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.55),
            ),
            const SizedBox(height: 14),

            // ── Info banner ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deniedForever
                          ? 'You will be taken to App Settings. After enabling location, return to Fixify.'
                          : 'Your location is only used to set your service area. It is never shared without your consent.',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Primary button ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (deniedForever) await Geolocator.openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  deniedForever ? 'Open App Settings' : 'Allow Location',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // ── Cancel (only shown for deniedForever) ─────
            if (deniedForever) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── TOUR REPLAY ───────────────────────────────────────────

  Future<void> _resetAndReplayTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kProfessionalTourSeenKey);
    } catch (e) {
      debugPrint('[Tour] Could not reset tour prefs: $e');
    }
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
    final hasLocation = _savedLat != null && _savedLng != null;

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

        // ── Service Location row ───────────────────────────
        GestureDetector(
          onTap: _openLocationSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hasLocation
                      ? const Color(0xFF34C759).withOpacity(0.1)
                      : const Color(0xFFFF9500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color: hasLocation
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF9500),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Service Location',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                      const SizedBox(height: 3),
                      Text(
                        hasLocation
                            ? (_city != null && _city!.isNotEmpty
                                ? _city!
                                : 'Location set')
                            : 'Not set yet  ·  Tap to pin your location',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasLocation
                              ? const Color(0xFF34C759)
                              : const Color(0xFFFF9500),
                        ),
                      ),
                      if (hasLocation)
                        const Text(
                          'Tap to update',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                    ]),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: hasLocation
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF9500),
                size: 20,
              ),
            ]),
          ),
        ),
        _divider(),
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
        _divider(),
        _actionRow(
          icon: Icons.lightbulb_outline_rounded,
          label: 'App Tour',
          onTap: _resetAndReplayTour,
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

// ─────────────────────────────────────────────────────────────────────────────
// _LocationPickerSheet
//
// Near-full-screen bottom sheet with:
//   • Google Map — tap anywhere to drop a green marker
//   • GPS button (top-right) — jumps to device location
//     (permission already granted by parent before this sheet opens)
//   • Zoom controls (bottom-right)
//   • Map type toggle thumbnail (bottom-left) — Normal ↔ Satellite
//   • Reverse-geocoding — address label + city extraction shown under pin
//   • City badge — "City: X ← will update your profile"
//   • Pin preview card + Save Location / Cancel buttons
//   • "Tap to pin" hint overlay when no pin is set
//   • RawGestureDetector wrapping the map — AllowMultipleGestureRecognizer
//     wins the gesture arena immediately so single-finger panning goes to
//     GoogleMap, not the sheet's drag-to-dismiss handler
//
// onSave(lat, lng, city?) — city passed back for profile City/Address sync.
// ─────────────────────────────────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final Future<void> Function(double lat, double lng, String? city) onSave;

  const _LocationPickerSheet({
    this.initialLat,
    this.initialLng,
    required this.onSave,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  GoogleMapController? _mapCtrl;
  LatLng? _pinned;
  bool _locating = false;
  bool _geocoding = false;
  bool _saving = false;
  String _addressLabel = '';
  String? _geocodedCity;

  MapType _mapType = MapType.normal;

  static const LatLng _defaultCamera = LatLng(7.0707, 125.6087); // Davao City

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      // Already has a saved pin — restore it, don't override with GPS.
      _pinned = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      // No saved pin — auto-fetch GPS so the map lands on the user's
      // exact position immediately without needing to tap the button.
      WidgetsBinding.instance.addPostFrameCallback((_) => _useGps());
    }
  }

  LatLng get _camera => _pinned ?? _defaultCamera;

  // ── Map type toggle ────────────────────────────────────────

  void _toggleMapType() => setState(() {
        _mapType =
            _mapType == MapType.normal ? MapType.satellite : MapType.normal;
      });

  // ── Pin & geocode ──────────────────────────────────────────

  Future<void> _onMapTap(LatLng ll) async {
    setState(() {
      _pinned = ll;
      _geocoding = true;
      _addressLabel = '';
      _geocodedCity = null;
    });
    try {
      final marks = await placemarkFromCoordinates(ll.latitude, ll.longitude)
          .timeout(const Duration(seconds: 8));
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;

        // Full address label
        final parts = [
          p.street,
          p.subLocality ?? p.subAdministrativeArea,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).toList();

        // City — matches requestservice_customer.dart logic
        final city = (p.locality ?? '').trim();

        setState(() {
          _addressLabel = parts.join(', ');
          _geocodedCity = city.isNotEmpty ? city : null;
        });
      }
    } catch (_) {
      // Silent — coordinates are still valid without an address label
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  // ── GPS ────────────────────────────────────────────────────
  // Permission is pre-checked by _openLocationSheet() in the parent,
  // so here we only need to fetch the position.

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      final ll = LatLng(pos.latitude, pos.longitude);
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 17));
      await _onMapTap(ll);
    } catch (_) {
      _snack('Could not get GPS location — try pinning manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────

  Future<void> _save() async {
    if (_pinned == null) {
      _snack('Please pin your location on the map first.');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(_pinned!.latitude, _pinned!.longitude, _geocodedCity);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isSatellite = _mapType == MapType.satellite;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(children: [
        // ── Drag handle ────────────────────────────────────
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),

        // ── Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.my_location_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Your Location',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  SizedBox(height: 2),
                  Text(
                    'Tap the map or use GPS to pin where you operate from',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Map ────────────────────────────────────────────
        // RawGestureDetector + AllowMultipleGestureRecognizer:
        //   wins the gesture arena on first touch so GoogleMap gets all
        //   pan/scale events; the sheet's drag handler never fires.
        Expanded(
          child: Stack(children: [
            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: _camera, zoom: _pinned != null ? 15 : 13),
              mapType: _mapType,
              gestureRecognizers: {
                Factory<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: (c) {
                _mapCtrl = c;
                if (_pinned != null) {
                  Future.delayed(
                    const Duration(milliseconds: 400),
                    () => _mapCtrl?.animateCamera(
                        CameraUpdate.newLatLngZoom(_pinned!, 15)),
                  );
                }
              },
              onTap: _onMapTap,
              markers: _pinned != null
                  ? {
                      Marker(
                        markerId: const MarkerId('pro_pin'),
                        position: _pinned!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                        infoWindow: InfoWindow(
                          title: 'My Location',
                          snippet:
                              _addressLabel.isNotEmpty ? _addressLabel : null,
                        ),
                      ),
                    }
                  : {},
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),

            // GPS button — top-right
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _locating ? null : _useGps,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: _locating
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary)))
                      : const Icon(Icons.my_location_rounded,
                          color: AppColors.primary, size: 22),
                ),
              ),
            ),

            // Zoom controls — bottom-right
            Positioned(
              bottom: 12,
              right: 12,
              child: Column(children: [
                _zoomBtn(Icons.add_rounded,
                    () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
                const SizedBox(height: 4),
                _zoomBtn(Icons.remove_rounded,
                    () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
              ]),
            ),

            // Map type toggle thumbnail — bottom-left
            Positioned(
              bottom: 12,
              left: 12,
              child: GestureDetector(
                onTap: _toggleMapType,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7.5),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail of the OTHER map type
                        isSatellite
                            ? Container(
                                color: const Color(0xFF8DB8D6),
                                child: CustomPaint(painter: _RoadMapPainter()),
                              )
                            : Container(
                                color: const Color(0xFF3A5E38),
                                child:
                                    CustomPaint(painter: _SatellitePainter()),
                              ),
                        // Label
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            color: Colors.black.withOpacity(0.5),
                            child: Text(
                              isSatellite ? 'Map' : 'Satellite',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Geocoding indicator — above map-type thumbnail
            if (_geocoding)
              Positioned(
                bottom: 74,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 8),
                    Text('Getting address…',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),

            // "Tap to pin" hint — centre overlay
            if (_pinned == null && !_locating)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.touch_app_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Tap map to pin your location',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),

        // ── Bottom bar ─────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Pin preview card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _pinned != null
                    ? const Color(0xFF34C759).withOpacity(0.06)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _pinned != null
                        ? const Color(0xFF34C759).withOpacity(0.3)
                        : const Color(0xFFE0E0E0)),
              ),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: (_pinned != null
                            ? const Color(0xFF34C759)
                            : const Color(0xFFBBBBBB))
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.place_rounded,
                      color: _pinned != null
                          ? const Color(0xFF34C759)
                          : const Color(0xFFBBBBBB),
                      size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pinned != null
                              ? 'Pinned Location'
                              : 'No location pinned yet',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _pinned != null
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFAAAAAA)),
                        ),
                        if (_addressLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(_addressLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ] else if (_pinned != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_pinned!.latitude.toStringAsFixed(5)}, '
                            '${_pinned!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                        // City badge
                        if (_geocodedCity != null &&
                            _geocodedCity!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2)),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_city_rounded,
                                        color: AppColors.primary, size: 11),
                                    const SizedBox(width: 4),
                                    Text(
                                      'City: $_geocodedCity',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary),
                                    ),
                                  ]),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '← will update your profile',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textLight),
                            ),
                          ]),
                        ],
                      ]),
                ),
                if (_pinned != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _pinned = null;
                      _addressLabel = '';
                      _geocodedCity = null;
                    }),
                    child: const Icon(Icons.close_rounded,
                        color: Color(0xFFBBBBBB), size: 18),
                  ),
              ]),
            ),
            const SizedBox(height: 14),

            // Cancel / Save buttons
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
                  onTap: _saving ? null : _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _pinned != null
                            ? [const Color(0xFF0F3D2E), const Color(0xFF1A5C43)]
                            : [
                                const Color(0xFFCCCCCC),
                                const Color(0xFFBBBBBB)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _pinned != null
                          ? [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]
                          : [],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  Icon(Icons.save_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Save Location',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ]),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4)
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.textDark),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters for map type thumbnail
// ─────────────────────────────────────────────────────────────────────────────

/// Mimics a simple road-map style (shown when currently in satellite mode)
class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFD4E8F0));

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), road);
    canvas.drawLine(Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height), road);

    final block = Paint()..color = const Color(0xFFB8D4BC);
    canvas.drawRect(
        Rect.fromLTWH(4, 4, size.width * 0.4, size.height * 0.4), block);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.55, size.width * 0.4,
            size.height * 0.4),
        block);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Mimics a satellite-view style (shown when currently in normal map mode)
class _SatellitePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF2D4A2A));

    canvas.drawOval(Rect.fromLTWH(2, 2, size.width * 0.5, size.height * 0.5),
        Paint()..color = const Color(0xFF3E6B38));
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.4, size.height * 0.3, size.width * 0.55,
            size.height * 0.55),
        Paint()..color = const Color(0xFF557A50));

    canvas.drawLine(
        Offset(0, size.height * 0.6),
        Offset(size.width, size.height * 0.45),
        Paint()
          ..color = const Color(0xFFBBA96A)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);

    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.6, size.width * 0.3,
            size.height * 0.35),
        Paint()..color = const Color(0xFF3B6E8C));
  }

  @override
  bool shouldRepaint(_) => false;
}
