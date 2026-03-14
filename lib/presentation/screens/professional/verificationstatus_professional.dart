// lib/presentation/screens/professional/verificationstatus_professional.dart
//
// VerificationStatusScreen — shows the professional their application history.
//
// Shows a list of all their submitted applications with status chips
// (Pending / Approved / Rejected + admin note).
//
// ONE-SKILL MODEL: each handyman has exactly one skill, so there will be at
// most one application at any point. The FAB is driven by that single
// application's status:
//
//   no applications → "Apply for Verification"   (add icon)
//   pending         → FAB hidden (review in progress; no action available)
//   rejected        → "Re-apply"                 (refresh icon)
//   approved        → "Update Credentials"        (edit icon)
//
// The callback wired to the FAB is always onApplyNew — main.dart unchanged.
//
// Key props:
//   applications  → List<ApplicationModel>  — from ApplicationDataSource
//   onApplyNew    → VoidCallback?           — FAB action (apply / re-apply / update)
//   onBack        → VoidCallback?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/application_datasource.dart';

class VerificationStatusScreen extends StatelessWidget {
  final List<ApplicationModel> applications;
  final VoidCallback? onApplyNew;
  final VoidCallback? onBack;

  const VerificationStatusScreen({
    super.key,
    this.applications = const [],
    this.onApplyNew,
    this.onBack,
  });

  // ── VIEW helpers — one-skill FAB state machine ───────────────────────────
  //
  // Derives FAB label/icon from the single application's status.
  // Returns null when the FAB should be hidden (pending review).

  _FabConfig? get _fabConfig {
    if (applications.isEmpty) {
      return const _FabConfig(
        label: 'Apply for Verification',
        icon: Icons.add_rounded,
      );
    }
    // Use the most recent application (list is ordered newest-first).
    switch (applications.first.status) {
      case 'approved':
        return const _FabConfig(
          label: 'Update Credentials',
          icon: Icons.edit_rounded,
        );
      case 'rejected':
        return const _FabConfig(
          label: 'Re-apply',
          icon: Icons.refresh_rounded,
        );
      case 'pending':
      default:
        // Application is under review — no action available.
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fab = _fabConfig;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: applications.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  itemCount: applications.length,
                  itemBuilder: (_, i) => _buildCard(applications[i], i),
                ),
        ),
      ]),
      floatingActionButton: fab == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onApplyNew,
              backgroundColor: AppColors.primary,
              icon: Icon(fab.icon, color: Colors.white),
              label: Text(fab.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF082218),
                Color(0xFF0F3D2E),
                Color(0xFF1A5C43)
              ]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(children: [
                GestureDetector(
                    onTap: onBack ?? () => Navigator.maybePop(context),
                    child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18))),
                const SizedBox(width: 14),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Verification Status',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Track your application progress',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
              ]),
            )),
      );

  Widget _buildCard(ApplicationModel app, int index) {
    final statusInfo = _statusInfo(app.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
        border:
            Border.all(color: (statusInfo['color'] as Color).withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.build_circle_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(app.serviceType,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('Submitted ${_formatDate(app.submittedAt)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: (statusInfo['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: (statusInfo['color'] as Color).withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusInfo['icon'] as IconData,
                  color: statusInfo['color'] as Color, size: 13),
              const SizedBox(width: 4),
              Text(statusInfo['label'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusInfo['color'] as Color,
                    letterSpacing: 0.3,
                  )),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 12),
        Row(children: [
          _detail(Icons.trending_up_rounded, '${app.yearsExp} yrs exp'),
          if (app.priceMin != null) ...[
            const SizedBox(width: 20),
            _detail(Icons.payments_rounded,
                '₱${app.priceMin!.toStringAsFixed(0)}/hr'),
          ],
        ]),
        // Rejection note
        if (app.status == 'rejected' && app.adminNote != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFFFF3B30), size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Admin note: ${app.adminNote}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFFF3B30)))),
            ]),
          ),
        ],
        // Approval confirmation
        if (app.status == 'approved') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF34C759).withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF34C759), size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'You are now visible to customers for this service.',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF34C759)))),
            ]),
          ),
        ],
        // ── Submitted documents ──────────────────────────────────────────────
        // Shown whenever at least one URL is present. Each thumbnail is
        // tappable and opens a full-screen InteractiveViewer dialog.
        if (app.credentialUrl != null || app.validIdUrl != null) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.folder_copy_rounded,
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 5),
            const Text('Submitted Documents',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (app.credentialUrl != null)
              Expanded(
                child: _CredentialThumbnail(
                  url: app.credentialUrl!,
                  label: 'Credential',
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFFFF9500),
                ),
              ),
            if (app.credentialUrl != null && app.validIdUrl != null)
              const SizedBox(width: 10),
            if (app.validIdUrl != null)
              Expanded(
                child: _CredentialThumbnail(
                  url: app.validIdUrl!,
                  label: 'Valid ID',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF007AFF),
                ),
              ),
          ]),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.06, end: 0);
  }

  Widget _detail(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500)),
      ]);

  Widget _buildEmpty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.workspace_premium_outlined,
              color: AppColors.primary, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('No applications yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 8),
        const Text(
            'Submit your credentials to start\ngetting bookings from customers.',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
            textAlign: TextAlign.center),
      ]));

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case 'approved':
        return {
          'label': 'APPROVED',
          'icon': Icons.check_circle_rounded,
          'color': const Color(0xFF34C759)
        };
      case 'rejected':
        return {
          'label': 'REJECTED',
          'icon': Icons.cancel_rounded,
          'color': const Color(0xFFFF3B30)
        };
      default:
        return {
          'label': 'PENDING',
          'icon': Icons.hourglass_top_rounded,
          'color': const Color(0xFFFF9500)
        };
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ── FAB config ────────────────────────────────────────────────────────────────
// Immutable value object that drives the FAB label and icon.
// Returned as null by _fabConfig when the FAB should be hidden (pending state).

class _FabConfig {
  final String label;
  final IconData icon;
  const _FabConfig({required this.label, required this.icon});
}

// ── Credential thumbnail ──────────────────────────────────────────────────────
// Tappable image tile used in the "Submitted Documents" section.
// Opens a full-screen InteractiveViewer dialog on tap — pinch-to-zoom supported.
// Shows a placeholder tile while loading and a broken-image state on error.

class _CredentialThumbnail extends StatelessWidget {
  final String url;
  final String label;
  final IconData icon;
  final Color color;

  const _CredentialThumbnail({
    required this.url,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImagePreview(context),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(fit: StackFit.expand, children: [
            // Network image
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _placeholder(spinning: true),
              errorBuilder: (_, __, ___) => _placeholder(error: true),
            ),
            // Label overlay at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
                child: Row(children: [
                  Icon(icon, size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const Spacer(),
                  const Icon(Icons.zoom_in_rounded,
                      size: 12, color: Colors.white70),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder({bool spinning = false, bool error = false}) => Container(
        color: Colors.grey.shade100,
        child: Center(
          child: spinning
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color)),
                )
              : Icon(
                  error ? Icons.broken_image_rounded : icon,
                  size: 28,
                  color: color.withOpacity(0.4),
                ),
        ),
      );

  void _showImagePreview(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(alignment: Alignment.center, children: [
          // Pinch-to-zoom image viewer
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 5.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54),
                      ),
                    ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_rounded,
                    size: 64, color: Colors.white38),
              ),
            ),
          ),
          // Label chip at the top
          Positioned(
            top: MediaQuery.of(ctx).padding.top + 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(ctx).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
