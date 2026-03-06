// lib/presentation/screens/admin/profile_admin.dart
//
// AdminProfileScreen — MVP profile for the Admin role.
//
// Shows:
//   • Header — gradient, initials avatar, name, "Super Administrator" role banner
//   • Personal Information card — Full Name, Email, Mobile Number
//   • System Access card — Access Level, Last Login timestamp, Two-Factor Auth status
//   • Admin Actions card — Activity Logs, Security Settings
//   • Logout button with confirmation dialog
//
// Key props:
//   adminName        → String          — admin display name, default 'Admin'
//   adminEmail       → String          — admin email address
//   adminPhone       → String?         — optional phone number
//   accessLevel      → String          — e.g. 'SUPERADMIN', default 'ADMIN'
//   lastLogin        → DateTime?       — last login timestamp; shows 'Never' if null
//   twoFactorEnabled → bool            — whether 2FA is active, default false
//   onBack           → VoidCallback?   — back navigation
//   onEditProfile    → VoidCallback?   — pencil/edit tap
//   onActivityLogs   → VoidCallback?   — Activity Logs tap
//   onSecuritySettings → VoidCallback? — Security Settings tap
//   onLogout         → VoidCallback?   — called after logout confirmation

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

class AdminProfileScreen extends StatelessWidget {
  final String adminName;
  final String adminEmail;
  final String? adminPhone;
  final String accessLevel;
  final DateTime? lastLogin;
  final bool twoFactorEnabled;
  final VoidCallback? onBack;
  final VoidCallback? onEditProfile;
  final VoidCallback? onActivityLogs;
  final VoidCallback? onSecuritySettings;
  final VoidCallback? onLogout;

  const AdminProfileScreen({
    super.key,
    this.adminName = 'Admin',
    this.adminEmail = '',
    this.adminPhone,
    this.accessLevel = 'ADMIN',
    this.lastLogin,
    this.twoFactorEnabled = false,
    this.onBack,
    this.onEditProfile,
    this.onActivityLogs,
    this.onSecuritySettings,
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
              child: _buildSystemAccessCard(),
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
    final initials = adminName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

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
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
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
                  const Text('Admin Profile',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
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
              // Avatar — gold for admin
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4A843), Color(0xFF9B7B2A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A843).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'A',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(adminName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              // Role banner
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded,
                            color: Color(0xFFD4A843), size: 16),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Super Administrator',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text('Full System Access',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11)),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    const Color(0xFF34C759).withOpacity(0.4)),
                          ),
                          child: const Text('ACTIVE',
                              style: TextStyle(
                                  color: Color(0xFF34C759),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
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
          value: adminName,
        ),
        _divider(),
        _infoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: adminEmail.isNotEmpty ? adminEmail : '—',
        ),
        _divider(),
        _infoRow(
          icon: Icons.phone_outlined,
          label: 'Mobile Number',
          value: adminPhone ?? '—',
        ),
      ],
    );
  }

  // ── SYSTEM ACCESS CARD ────────────────────────────────────

  Widget _buildSystemAccessCard() {
    final lastLoginStr = lastLogin != null
        ? '${lastLogin!.month}/${lastLogin!.day}/${lastLogin!.year} at '
            '${_formatTime(lastLogin!)}'
        : 'Never';

    return _card(
      title: 'System Access',
      titleIcon: Icons.security_rounded,
      children: [
        _infoRow(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Access Level',
          value: accessLevel,
          valueColor: AppColors.primary,
          valueBold: true,
        ),
        _divider(),
        _infoRow(
          icon: Icons.access_time_rounded,
          label: 'Last Login',
          value: lastLoginStr,
        ),
        _divider(),
        // 2FA row with colored status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (twoFactorEnabled
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF9500))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock_rounded,
                  color: twoFactorEnabled
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF9500),
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Two-Factor Auth',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textLight)),
                  const SizedBox(height: 2),
                  Text(
                    twoFactorEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: twoFactorEnabled
                          ? const Color(0xFF34C759)
                          : const Color(0xFFFF9500),
                    ),
                  ),
                ],
              ),
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
          icon: Icons.receipt_long_rounded,
          label: 'Activity Logs',
          onTap: onActivityLogs,
        ),
        _divider(),
        _actionRow(
          icon: Icons.security_rounded,
          label: 'Security Settings',
          onTap: onSecuritySettings,
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

  Widget _card({
    String? title,
    IconData? titleIcon,
    required List<Widget> children,
  }) {
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
              child: Row(children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                      letterSpacing: 0.3,
                    )),
              ]),
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
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
                    color: valueColor ?? AppColors.textDark,
                    letterSpacing: valueBold ? 0.5 : 0,
                  )),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
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
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 20),
        ]),
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        indent: 72,
        endIndent: 20,
        color: Color(0xFFEEEEEE),
      );

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }
}
