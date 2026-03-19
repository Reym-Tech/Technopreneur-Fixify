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

class VerificationStatusScreen extends StatefulWidget {
  final List<ApplicationModel> applications;
  final List<ServiceProposalModel> proposals;
  final VoidCallback? onApplyNew;
  final VoidCallback? onProposeService;
  final VoidCallback? onViewMyServices;
  final VoidCallback? onBack;

  const VerificationStatusScreen({
    super.key,
    this.applications = const [],
    this.proposals = const [],
    this.onApplyNew,
    this.onProposeService,
    this.onViewMyServices,
    this.onBack,
  });

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  // ── VIEW helpers — one-skill FAB state machine ───────────────────────────

  _FabConfig? get _fabConfig {
    if (widget.applications.isEmpty) {
      return const _FabConfig(
        label: 'Apply for Verification',
        icon: Icons.add_rounded,
      );
    }
    switch (widget.applications.first.status) {
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
        return null;
    }
  }

  _FabConfig? get _proposalFabConfig {
    final isVerified = widget.applications.any((a) => a.status == 'approved');
    if (!isVerified) return null;

    if (widget.proposals.isEmpty) {
      return const _FabConfig(
        label: 'Propose a Service',
        icon: Icons.storefront_rounded,
      );
    }
    switch (widget.proposals.first.status) {
      case 'rejected':
        return const _FabConfig(
          label: 'Update Proposal',
          icon: Icons.edit_rounded,
        );
      case 'approved':
      case 'pending':
      default:
        return null;
    }
  }

  // ── Detail sheet helpers ──────────────────────────────────────────────────

  void _showApplicationDetail(ApplicationModel app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplicationDetailSheet(app: app),
    );
  }

  void _showProposalDetail(ServiceProposalModel prop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProposalDetailSheet(
        prop: prop,
        onViewMyServices: widget.onViewMyServices,
      ),
    );
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
              if (widget.applications.isEmpty)
                _buildEmpty(
                  icon: Icons.workspace_premium_outlined,
                  title: 'No application yet',
                  subtitle:
                      'Submit your credentials to get verified and start receiving bookings.',
                )
              else
                ...widget.applications
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
              if (widget.proposals.isEmpty)
                _buildEmpty(
                  icon: Icons.storefront_outlined,
                  title: 'No proposals yet',
                  subtitle: widget.applications
                          .any((a) => a.status == 'approved')
                      ? 'Don\'t see a service you offer? Propose a new one for admin review. Once approved, it will be added to your My Services list automatically.'
                      : 'Get verified first, then you can propose new services. Admin-seeded services are already available to select from My Services.',
                )
              else
                ...widget.proposals
                    .asMap()
                    .entries
                    .map((e) => _buildProposalCard(e.value, e.key)),
            ]),
          ),
        ),
      ]),
      floatingActionButton: (credFab == null && propFab == null)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (propFab != null) ...[
                  FloatingActionButton.extended(
                    heroTag: 'propose_fab',
                    onPressed: widget.onProposeService,
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
                    onPressed: widget.onApplyNew,
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
                    onTap: widget.onBack ?? () => Navigator.maybePop(context),
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
    return GestureDetector(
      onTap: () => _showApplicationDetail(app),
      child: Container(
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
          border: Border.all(
              color: (statusInfo['color'] as Color).withOpacity(0.2)),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _detail(
                        Icons.trending_up_rounded, '${app.yearsExp} yrs exp'),
                    if (app.priceMin != null)
                      _detail(Icons.payments_rounded,
                          '₱${app.priceMin!.toStringAsFixed(0)}/hr'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('View details',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right_rounded,
                    size: 15, color: AppColors.primary),
              ]),
            ],
          ),
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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ),
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
    return GestureDetector(
      onTap: () => _showProposalDetail(prop),
      child: Container(
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
          border: Border.all(
              color: (statusInfo['color'] as Color).withOpacity(0.2)),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (prop.priceRange != null)
                      _detail(Icons.payments_rounded, prop.priceRange!),
                    if (prop.duration != null)
                      _detail(Icons.schedule_rounded, prop.duration!),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('View details',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right_rounded,
                    size: 15, color: AppColors.primary),
              ]),
            ],
          ),
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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ),
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

// ─────────────────────────────────────────────────────────────
// Application Detail Sheet
// ─────────────────────────────────────────────────────────────

class _ApplicationDetailSheet extends StatelessWidget {
  final ApplicationModel app;
  const _ApplicationDetailSheet({required this.app});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusColor(app.status);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.build_circle_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.serviceType,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                      const SizedBox(height: 3),
                      Text('Submitted ${_fmtDate(app.submittedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo['color'].withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: statusInfo['color'].withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusInfo['icon'] as IconData,
                      color: statusInfo['color'] as Color, size: 13),
                  const SizedBox(width: 4),
                  Text(statusInfo['label'] as String,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusInfo['color'] as Color)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // Body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // ── Key info chips ────────────────────────────────────
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _infoPill(Icons.trending_up_rounded,
                      '${app.yearsExp} yrs experience', AppColors.primary),
                  if (app.priceMin != null)
                    _infoPill(
                        Icons.payments_rounded,
                        '₱${app.priceMin!.toStringAsFixed(0)}/hr',
                        const Color(0xFF34C759)),
                  if (app.reviewedAt != null)
                    _infoPill(
                        Icons.rate_review_rounded,
                        'Reviewed ${_fmtDate(app.reviewedAt!)}',
                        const Color(0xFF5856D6)),
                ]),
                // ── Bio ───────────────────────────────────────────────
                if (app.bio != null && app.bio!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('About'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(app.bio!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                            height: 1.55)),
                  ),
                ],
                // ── Uploaded documents ────────────────────────────────
                if (app.credentialUrl != null || app.validIdUrl != null) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Submitted Documents'),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (app.credentialUrl != null) ...[
                      Expanded(
                        child: _DocumentTile(
                          url: app.credentialUrl!,
                          label: 'Credential',
                          icon: Icons.workspace_premium_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    if (app.credentialUrl != null && app.validIdUrl != null)
                      const SizedBox(width: 12),
                    if (app.validIdUrl != null) ...[
                      Expanded(
                        child: _DocumentTile(
                          url: app.validIdUrl!,
                          label: 'Valid ID',
                          icon: Icons.badge_rounded,
                          color: const Color(0xFF5856D6),
                        ),
                      ),
                    ],
                  ]),
                ],
                // ── Admin note ────────────────────────────────────────
                if (app.adminNote != null && app.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Admin Feedback'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: app.status == 'rejected'
                          ? const Color(0xFFFF3B30).withOpacity(0.06)
                          : const Color(0xFF34C759).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: app.status == 'rejected'
                              ? const Color(0xFFFF3B30).withOpacity(0.2)
                              : const Color(0xFF34C759).withOpacity(0.2)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            app.status == 'rejected'
                                ? Icons.info_outline_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 16,
                            color: app.status == 'rejected'
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF34C759),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(app.adminNote!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: app.status == 'rejected'
                                          ? const Color(0xFFFF3B30)
                                          : const Color(0xFF34C759)))),
                        ]),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static Map<String, dynamic> _statusColor(String status) {
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

  static String _fmtDate(DateTime dt) {
    const m = [
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
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 0.4));

  Widget _infoPill(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// Proposal Detail Sheet
// ─────────────────────────────────────────────────────────────

class _ProposalDetailSheet extends StatelessWidget {
  final ServiceProposalModel prop;
  final VoidCallback? onViewMyServices;
  const _ProposalDetailSheet({required this.prop, this.onViewMyServices});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _ApplicationDetailSheet._statusColor(prop.status);
    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              if (prop.imageUrl != null && prop.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(prop.imageUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackIcon()),
                )
              else
                _fallbackIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prop.serviceName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                      const SizedBox(height: 3),
                      Text(
                          '${prop.serviceType}  ·  ${_ApplicationDetailSheet._fmtDate(prop.submittedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusInfo['color'].withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: statusInfo['color'].withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusInfo['icon'] as IconData,
                      color: statusInfo['color'] as Color, size: 13),
                  const SizedBox(width: 4),
                  Text(statusInfo['label'] as String,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusInfo['color'] as Color)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          // Body
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // ── Key info chips ────────────────────────────────────
                Wrap(spacing: 10, runSpacing: 10, children: [
                  if (prop.priceRange != null)
                    _infoPill(Icons.payments_rounded, prop.priceRange!,
                        const Color(0xFF34C759)),
                  if (prop.duration != null)
                    _infoPill(Icons.schedule_rounded, prop.duration!,
                        const Color(0xFF007AFF)),
                  if (prop.warrantyDays > 0)
                    _infoPill(
                        Icons.verified_rounded,
                        '${prop.warrantyDays}d warranty',
                        const Color(0xFF5856D6)),
                  if (prop.reviewedAt != null)
                    _infoPill(
                        Icons.rate_review_rounded,
                        'Reviewed ${_ApplicationDetailSheet._fmtDate(prop.reviewedAt!)}',
                        AppColors.primary),
                ]),
                // ── Description ───────────────────────────────────────
                if (prop.description != null &&
                    prop.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Description'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(prop.description!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                            height: 1.55)),
                  ),
                ],
                // ── What's included ───────────────────────────────────
                if (prop.includes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel("What's Included"),
                  const SizedBox(height: 10),
                  ...prop.includes.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(item,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMedium,
                                          height: 1.4))),
                            ]),
                      )),
                ],
                // ── Tips ─────────────────────────────────────────────
                if (prop.tips != null && prop.tips!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Tips for Customers'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A843).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFD4A843).withOpacity(0.2)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              size: 16, color: Color(0xFFD4A843)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(prop.tips!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMedium,
                                      height: 1.5))),
                        ]),
                  ),
                ],
                // ── Service image ─────────────────────────────────────
                if (prop.imageUrl != null && prop.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Service Image'),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      prop.imageUrl!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_rounded,
                              color: AppColors.textLight, size: 40),
                        ),
                      ),
                    ),
                  ),
                ],
                // ── Admin note ────────────────────────────────────────
                if (prop.adminNote != null && prop.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Admin Feedback'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: prop.status == 'rejected'
                          ? const Color(0xFFFF3B30).withOpacity(0.06)
                          : const Color(0xFF34C759).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: prop.status == 'rejected'
                              ? const Color(0xFFFF3B30).withOpacity(0.2)
                              : const Color(0xFF34C759).withOpacity(0.2)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                              prop.status == 'rejected'
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 16,
                              color: prop.status == 'rejected'
                                  ? const Color(0xFFFF3B30)
                                  : const Color(0xFF34C759)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(prop.adminNote!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: prop.status == 'rejected'
                                          ? const Color(0xFFFF3B30)
                                          : const Color(0xFF34C759)))),
                        ]),
                  ),
                ],
                // ── My Services button (approved only) ────────────────
                if (prop.status == 'approved' && onViewMyServices != null) ...[
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onViewMyServices!();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.checklist_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Go to My Services',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fallbackIcon() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.storefront_rounded,
            color: AppColors.primary, size: 26),
      );

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 0.4));

  Widget _infoPill(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// Shared document tile — tappable full-screen image viewer
// ─────────────────────────────────────────────────────────────

class _DocumentTile extends StatelessWidget {
  final String url;
  final String label;
  final IconData icon;
  final Color color;

  const _DocumentTile({
    required this.url,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          color: color.withOpacity(0.04),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                return Container(
                  color: color.withOpacity(0.06),
                  child: Center(
                      child:
                          Icon(icon, color: color.withOpacity(0.5), size: 32)),
                );
              }),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: Colors.black.withOpacity(0.45),
                  child: Row(children: [
                    Icon(icon, size: 11, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    const Spacer(),
                    const Icon(Icons.open_in_full_rounded,
                        size: 11, color: Colors.white70),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64)),
          ),
        ),
      ),
    ));
  }
}
