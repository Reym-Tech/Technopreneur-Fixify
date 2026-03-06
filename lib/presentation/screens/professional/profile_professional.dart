// lib/presentation/screens/professional/profile_professional.dart
//
// ProfessionalProfileScreen — MVP profile for Handyman (Professional) role.
//
// Shows:
//   • Header — gradient, avatar initials, name, "Handyman" badge, verified status, back + edit
//   • Personal Information card — Full Name, Mobile Number, Email, City/Address
//   • Professional Information card — Specialization (skills), Years Experience,
//                                     Price Range, Verification Status
//   • Actions card — Change Password, Services Offered, Payout Settings, Privacy Policy
//   • Logout button with confirmation dialog
//
// Key props:
//   user                → UserEntity?          — logged-in user data
//   professional        → ProfessionalEntity?  — professional profile data
//   onBack              → VoidCallback?        — back navigation
//   onEditProfile       → VoidCallback?        — edit/pencil tap
//   onChangePassword    → VoidCallback?        — Change Password tap
//   onServicesOffered   → VoidCallback?        — Services Offered tap
//   onPayoutSettings    → VoidCallback?        — Payout Settings tap
//   onPrivacyPolicy     → VoidCallback?        — Privacy Policy tap
//   onLogout            → VoidCallback?        — called after logout confirmation

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class ProfessionalProfileScreen extends StatelessWidget {
  final UserEntity? user;
  final ProfessionalEntity? professional;
  final VoidCallback? onBack;
  final VoidCallback? onEditProfile;
  final VoidCallback? onChangePassword;
  final VoidCallback? onServicesOffered;
  final VoidCallback? onPayoutSettings;
  final VoidCallback? onPrivacyPolicy;
  final VoidCallback? onLogout;

  const ProfessionalProfileScreen({
    super.key,
    this.user,
    this.professional,
    this.onBack,
    this.onEditProfile,
    this.onChangePassword,
    this.onServicesOffered,
    this.onPayoutSettings,
    this.onPrivacyPolicy,
    this.onLogout,
  });

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
    final name = user?.name ?? 'Professional';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    final verified = professional?.verified ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Text('Handyman Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          )),
                      GestureDetector(
                        onTap: onEditProfile,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Avatar
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
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Handyman',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              verified
                                  ? Icons.verified_rounded
                                  : Icons.pending_rounded,
                              color: verified
                                  ? const Color(0xFF34C759)
                                  : Colors.white.withOpacity(0.6),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              verified ? 'Approved' : 'Pending',
                              style: TextStyle(
                                color: verified
                                    ? const Color(0xFF34C759)
                                    : Colors.white.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          value: user?.name ?? '—',
        ),
        _divider(),
        _infoRow(
          icon: Icons.phone_outlined,
          label: 'Mobile Number',
          value: user?.phone ?? '—',
        ),
        _divider(),
        _infoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user?.email ?? '—',
        ),
        _divider(),
        _infoRow(
          icon: Icons.location_on_outlined,
          label: 'City / Address',
          value: professional?.city ?? 'Not specified',
        ),
      ],
    );
  }

  // ── PROFESSIONAL INFO CARD ────────────────────────────────

  Widget _buildProfessionalCard() {
    final skills = professional?.skills ?? [];
    final specialization = skills.isNotEmpty
        ? skills.map((s) => s[0].toUpperCase() + s.substring(1)).join(', ')
        : '—';

    final price = (professional?.priceMin != null)
        ? '₱${professional!.priceMin!.toStringAsFixed(0)}'
            '${professional!.priceMax != null ? ' – ₱${professional!.priceMax!.toStringAsFixed(0)}' : ''}'
        : '—';

    final verified = professional?.verified ?? false;

    return _card(
      title: 'Professional Information',
      children: [
        _infoRow(
          icon: Icons.work_outline_rounded,
          label: 'Specialization',
          value: specialization,
        ),
        _divider(),
        _infoRow(
          icon: Icons.trending_up_rounded,
          label: 'Years of Experience',
          value:
              '${professional?.yearsExperience ?? 0} year${(professional?.yearsExperience ?? 0) != 1 ? 's' : ''}',
        ),
        _divider(),
        _infoRow(
          icon: Icons.attach_money_rounded,
          label: 'Price Range',
          value: price,
        ),
        _divider(),
        // Verification status with colored chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
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
                child: Icon(
                  Icons.verified_user_outlined,
                  color: verified
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
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          onTap: onChangePassword,
        ),
        _divider(),
        _actionRow(
          icon: Icons.list_alt_rounded,
          label: 'Services Offered',
          onTap: onServicesOffered,
        ),
        _divider(),
        _actionRow(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Payout Settings',
          onTap: onPayoutSettings,
        ),
        _divider(),
        _actionRow(
          icon: Icons.shield_outlined,
          label: 'Privacy Policy',
          onTap: onPrivacyPolicy,
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
              offset: const Offset(0, 4),
            ),
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
              onLogout?.call();
            },
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── SHARED HELPERS ────────────────────────────────────────

  Widget _card({String? title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
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
                    letterSpacing: 0.3,
                  )),
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
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
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
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
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
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        indent: 72,
        endIndent: 20,
        color: Color(0xFFEEEEEE),
      );
}
