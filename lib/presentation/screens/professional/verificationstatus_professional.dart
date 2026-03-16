// lib/presentation/screens/professional/verificationstatus_professional.dart
//
// VerificationStatusScreen — shows the professional their application history
// AND their service proposal history, side by side in two sections.
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
// Service Proposals section shows the handyman's submitted proposals with
// status chips. A "Propose a Service" FAB (second FAB) or action card is
// shown when the handyman is verified (approved application).
//
// The callback wired to the credentials FAB is always onApplyNew — main.dart unchanged.
// The callback wired to the proposal action is onProposeService.
//
// Key props:
//   applications    → List<ApplicationModel>
//   proposals       → List<ServiceProposalModel>  — handyman's own proposals
//   onApplyNew      → VoidCallback?               — credentials FAB
//   onProposeService → VoidCallback?              — propose / resubmit service
//   onBack          → VoidCallback?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/application_datasource.dart';

// Small helpers used by the VerificationStatusScreen.
class _FabConfig {
  final String label;
  final IconData icon;
  const _FabConfig({required this.label, required this.icon});
}

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
  Widget build(BuildContext context) => Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.12)),
          color: color.withOpacity(0.04),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child:
              Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
            return Container(
              color: color.withOpacity(0.06),
              child: Center(
                child: Icon(icon, color: color.withOpacity(0.9)),
              ),
            );
          }),
        ),
      );
}

class VerificationStatusScreen extends StatelessWidget {
  final List<ApplicationModel> applications;
  final List<ServiceProposalModel> proposals;
  final VoidCallback? onApplyNew;
  final VoidCallback? onProposeService;
  final VoidCallback? onBack;

  const VerificationStatusScreen({
    super.key,
    this.applications = const [],
    this.proposals = const [],
    this.onApplyNew,
    this.onProposeService,
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

  // ── Proposal FAB — shown when the handyman is verified ────────────────────
  // Pending proposal  → hidden (under review).
  // Approved proposal → hidden (already in catalogue; use My Services to select).
  // Rejected proposal → shows "Update & Resubmit".
  // No proposals      → shows "Propose a Service".
  _FabConfig? get _proposalFabConfig {
    final isVerified = applications.any((a) => a.status == 'approved');
    if (!isVerified) return null; // must be verified first

    if (proposals.isEmpty) {
      return const _FabConfig(
        label: 'Propose a Service',
        icon: Icons.storefront_rounded,
      );
    }
    // Check the most recent proposal's status
    switch (proposals.first.status) {
      case 'rejected':
        return const _FabConfig(
          label: 'Update Proposal',
          icon: Icons.edit_rounded,
        );
      case 'approved':
      case 'pending':
      default:
        // Under review or already approved — no action here
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final credFab = _fabConfig;
    final propFab = _proposalFabConfig;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Credentials section ───────────────────────────────────
              const Text('Verification Application',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              if (applications.isEmpty)
                _buildEmpty(
                  icon: Icons.workspace_premium_outlined,
                  title: 'No application yet',
                  subtitle:
                      'Submit your credentials to get verified and start receiving bookings.',
                )
              else
                ...applications
                    .asMap()
                    .entries
                    .map((e) => _buildCard(e.value, e.key)),

              // ── Service Proposals section ──────────────────────────────
              const SizedBox(height: 28),
              const Text('Service Proposals',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              if (proposals.isEmpty)
                _buildEmpty(
                  icon: Icons.storefront_outlined,
                  title: 'No proposals yet',
                  subtitle: applications.any((a) => a.status == 'approved')
                      ? 'Don\'t see a service you offer? Propose a new one for admin review. Once approved, it will be added to your My Services list automatically.'
                      : 'Get verified first, then you can propose new services. Admin-seeded services are already available to select from My Services.',
                )
              else
                ...proposals
                    .asMap()
                    .entries
                    .map((e) => _buildProposalCard(e.value, e.key)),
            ]),
          ),
        ),
      ]),
      // Stack both FABs vertically when both are visible
      floatingActionButton: (credFab == null && propFab == null)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (propFab != null) ...[
                  FloatingActionButton.extended(
                    heroTag: 'propose_fab',
                    onPressed: onProposeService,
                    backgroundColor: const Color(0xFFD4A843),
                    icon: Icon(propFab.icon, color: Colors.white),
                    label: Text(propFab.label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (credFab != null)
                  FloatingActionButton.extended(
                    heroTag: 'cred_fab',
                    onPressed: onApplyNew,
                    backgroundColor: AppColors.primary,
                    icon: Icon(credFab.icon, color: Colors.white),
                    label: Text(credFab.label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ],
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

  Widget _buildEmpty({
    IconData icon = Icons.workspace_premium_outlined,
    String title = 'No applications yet',
    String subtitle =
        'Submit your credentials to start\ngetting bookings from customers.',
  }) =>
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight, height: 1.4)),
            ]),
          ),
        ]),
      );

  // ── VIEW — Service Proposal card ─────────────────────────────────────────

  Widget _buildProposalCard(ServiceProposalModel prop, int index) {
    final statusInfo = _statusInfo(prop.status);
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
          // Service image thumbnail
          if (prop.imageUrl != null && prop.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(prop.imageUrl!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.storefront_rounded,
                            color: AppColors.primary, size: 22),
                      )),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.storefront_rounded,
                  color: AppColors.primary, size: 22),
            ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(prop.serviceName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(
                    '${prop.serviceType}  ·  Submitted ${_formatDate(prop.submittedAt)}',
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
                      letterSpacing: 0.3)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 10),
        Row(children: [
          if (prop.priceRange != null)
            _detail(Icons.payments_rounded, prop.priceRange!),
          if (prop.priceRange != null && prop.duration != null)
            const SizedBox(width: 20),
          if (prop.duration != null)
            _detail(Icons.schedule_rounded, prop.duration!),
        ]),
        // Admin feedback on rejection
        if (prop.status == 'rejected' && prop.adminNote != null) ...[
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
                  child: Text('Admin feedback: ${prop.adminNote}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFFF3B30)))),
            ]),
          ),
        ],
        // Approval note — tells the professional the service is live and
        // has been automatically added to their My Services list.
        if (prop.status == 'approved') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF34C759).withOpacity(0.2)),
            ),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF34C759), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Your service is live and visible to customers. '
                    'It has been automatically added to your My Services list.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF34C759)),
                  )),
                ]),
          ),
        ],
        // Submitted documents thumbnails
        if (prop.imageUrl != null) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.image_rounded,
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 5),
            const Text('Service Image',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _CredentialThumbnail(
              url: prop.imageUrl!,
              label: 'Service Image',
              icon: Icons.storefront_rounded,
              color: const Color(0xFFD4A843),
            ),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.06, end: 0);
  }

  // ── VIEW — status info ─────────────────────────────────────────────────────
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

// (helpers moved earlier)
