// lib/presentation/screens/professional/verificationstatus_professional.dart
//
// VerificationStatusScreen — shows the professional their application history.
//
// Shows a list of all their submitted applications with status chips
// (Pending / Approved / Rejected + admin note).
//
// Key props:
//   applications  → List<ApplicationModel>  — from ApplicationDataSource
//   onApplyNew    → VoidCallback?           — "Apply for New Service" button
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

  @override
  Widget build(BuildContext context) {
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onApplyNew,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Apply for New Service',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
