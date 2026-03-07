// lib/presentation/screens/admin/approvals_admin.dart
//
// ApprovalsScreen — Admin screen to review handyman applications.
//
// Shows pending applications with credential + valid ID preview,
// approve button, and reject button (with optional note).
//
// Key props:
//   applications → List<ApplicationModel>                     — from ApplicationDataSource
//   onApprove    → Function(ApplicationModel)?                — approve tap
//   onReject     → Function(ApplicationModel, String? note)?  — reject tap
//   onBack       → VoidCallback?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/application_datasource.dart';

class ApprovalsScreen extends StatefulWidget {
  final List<ApplicationModel> applications;
  final Function(ApplicationModel)? onApprove;
  final Function(ApplicationModel, String?)? onReject;
  final VoidCallback? onBack;

  const ApprovalsScreen({
    super.key,
    this.applications = const [],
    this.onApprove,
    this.onReject,
    this.onBack,
  });

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _processingId; // which card is loading

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<ApplicationModel> _filtered(String status) =>
      widget.applications.where((a) => a.status == status).toList();

  @override
  Widget build(BuildContext context) {
    final pending = _filtered('pending');
    final approved = _filtered('approved');
    final rejected = _filtered('rejected');

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildHeader(pending.length),
        _buildTabs(pending.length, approved.length, rejected.length),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _buildList(pending),
            _buildList(approved),
            _buildList(rejected),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHeader(int pendingCount) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF082218),
                Color(0xFF0F3D2E),
                Color(0xFF1A5C43)
              ]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
        ),
        child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Handyman Approvals',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Review and verify applicants',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12)),
                    ])),
                if (pendingCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.4)),
                    ),
                    child: Text('$pendingCount pending',
                        style: const TextStyle(
                            color: Color(0xFFFF3B30),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
              ]),
            )),
      );

  Widget _buildTabs(int p, int a, int r) => Container(
        color: const Color(0xFF0F3D2E),
        child: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Pending${p > 0 ? ' ($p)' : ''}'),
            Tab(text: 'Approved${a > 0 ? ' ($a)' : ''}'),
            Tab(text: 'Rejected${r > 0 ? ' ($r)' : ''}'),
          ],
        ),
      );

  Widget _buildList(List<ApplicationModel> apps) {
    if (apps.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 52, color: AppColors.textLight.withOpacity(0.3)),
        const SizedBox(height: 12),
        const Text('Nothing here',
            style: TextStyle(color: AppColors.textLight, fontSize: 15)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: apps.length,
      itemBuilder: (_, i) => _buildCard(apps[i], i),
    );
  }

  Widget _buildCard(ApplicationModel app, int index) {
    final isPending = app.status == 'pending';
    final isLoading = _processingId == app.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // ── Applicant info ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF34C759), Color(0xFF1A5C43)]),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(
                  (app.applicantName?.isNotEmpty == true)
                      ? app.applicantName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(app.applicantName ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    Text(app.applicantEmail ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ])),
              _statusChip(app.status),
            ]),
            const SizedBox(height: 14),
            // Service badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.build_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Text('Applying for: ${app.serviceType}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 12),
            // Details row
            Row(children: [
              _info(
                  Icons.trending_up_rounded, '${app.yearsExp} yrs experience'),
              if (app.priceMin != null) ...[
                const SizedBox(width: 16),
                _info(Icons.payments_rounded,
                    '₱${app.priceMin!.toStringAsFixed(0)}/hr'),
              ],
            ]),
            if (app.bio != null && app.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(app.bio!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        // ── Documents preview ──────────────────────────────
        if (app.credentialUrl != null || app.validIdUrl != null) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Submitted Documents',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                      letterSpacing: 0.3)),
              const SizedBox(height: 10),
              Row(children: [
                if (app.credentialUrl != null)
                  _docTile('Credential', app.credentialUrl!,
                      const Color(0xFFFF9500)),
                if (app.credentialUrl != null && app.validIdUrl != null)
                  const SizedBox(width: 10),
                if (app.validIdUrl != null)
                  _docTile(
                      'Valid ID', app.validIdUrl!, const Color(0xFF007AFF)),
              ]),
            ]),
          ),
        ],
        // ── Action buttons (pending only) ──────────────────
        if (isPending) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        strokeWidth: 2))
                : Row(children: [
                    Expanded(
                        child: OutlinedButton(
                      onPressed: () => _confirmReject(app),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF3B30)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(
                              color: Color(0xFFFF3B30),
                              fontWeight: FontWeight.w700)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                      onPressed: () => _approve(app),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34C759),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Approve',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    )),
                  ]),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.06, end: 0);
  }

  Widget _docTile(String label, String url, Color color) => Expanded(
          child: GestureDetector(
        onTap: () => _showDocDialog(label, url),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            color: color.withOpacity(0.05),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(children: [
              // Network image preview with loading indicator
              Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: color.withOpacity(0.05),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color.withOpacity(0.6)),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: color.withOpacity(0.08),
                  child: Center(
                    child: Icon(Icons.image_outlined,
                        color: color.withOpacity(0.5), size: 28),
                  ),
                ),
              ),
              // Label bar at bottom
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.85),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 11),
                          const SizedBox(width: 3),
                          Text(label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                  )),
            ]),
          ),
        ),
      ));

  Widget _statusChip(String status) {
    final info = <String, dynamic>{
          'pending': {'label': 'Pending', 'color': const Color(0xFFFF9500)},
          'approved': {'label': 'Approved', 'color': const Color(0xFF34C759)},
          'rejected': {'label': 'Rejected', 'color': const Color(0xFFFF3B30)},
        }[status] ??
        {'label': status, 'color': AppColors.textLight};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (info['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (info['color'] as Color).withOpacity(0.35)),
      ),
      child: Text(info['label'] as String,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: info['color'] as Color)),
    );
  }

  Widget _info(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500)),
      ]);

  void _showDocDialog(String label, String url) => showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.black87,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(children: [
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ]),
            ),
            // Zoomable image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            const Text('Loading…',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ]),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.broken_image_outlined,
                            color: Colors.white30, size: 48),
                        const SizedBox(height: 10),
                        const Text(
                          'Image could not be loaded.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Make sure the Supabase storage bucket is set to Public in your Supabase dashboard.',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

  Future<void> _approve(ApplicationModel app) async {
    setState(() => _processingId = app.id);
    await widget.onApprove?.call(app);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmReject(ApplicationModel app) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Application',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'Reject ${app.applicantName ?? "this applicant"}\'s application for ${app.serviceType}?',
              style: const TextStyle(color: AppColors.textMedium)),
          const SizedBox(height: 16),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason (optional — shown to applicant)',
              hintStyle: const TextStyle(fontSize: 13),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Reject',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _processingId = app.id);
      await widget.onReject?.call(
          app, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }
}
