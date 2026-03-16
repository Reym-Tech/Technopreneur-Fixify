// lib/presentation/screens/admin/admin_catalogue_screen.dart
//
// AdminCatalogueScreen — admin creates, edits, and deletes platform service
// offers. All services created here are immediately 'approved' and visible
// to professionals for selection and to customers on the dashboard.
// Also shows pending professional proposals for review.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/models/models.dart';
import 'package:fixify/data/datasources/application_datasource.dart';

class AdminCatalogueScreen extends StatefulWidget {
  /// All approved service offers (admin-seeded + approved proposals).
  final List<ServiceOfferModel> services;

  /// Pending professional proposals awaiting admin review.
  final List<ServiceProposalModel> pendingProposals;

  /// Called to create a new admin-seeded service.
  final Future<void> Function(ServiceFormData data) onCreateService;

  /// Called to delete a service offer by id.
  final Future<void> Function(String id) onDeleteService;

  /// Called to approve a professional's proposal.
  final Future<void> Function(ServiceProposalModel proposal) onApproveProposal;

  /// Called to reject a professional's proposal with an optional note.
  final Future<void> Function(ServiceProposalModel proposal, String? note)
      onRejectProposal;

  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;

  const AdminCatalogueScreen({
    super.key,
    required this.services,
    required this.pendingProposals,
    required this.onCreateService,
    required this.onDeleteService,
    required this.onApproveProposal,
    required this.onRejectProposal,
    this.onBack,
    this.onRefresh,
  });

  @override
  State<AdminCatalogueScreen> createState() => _AdminCatalogueScreenState();
}

class _AdminCatalogueScreenState extends State<AdminCatalogueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _serviceTypes = [
    'Plumber',
    'Electrician',
    'Technician',
    'Carpenter',
    'Masonry',
  ];

  String _selectedType = 'All';

  List<ServiceOfferModel> get _filtered {
    if (_selectedType == 'All') return widget.services;
    return widget.services
        .where((s) => s.serviceType == _selectedType)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildTopBar(),
        // Tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textLight,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'Service Catalogue'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Proposals'),
                    if (widget.pendingProposals.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.pendingProposals.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildCatalogueTab(),
              _buildProposalsTab(),
            ],
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Service',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              GestureDetector(
                onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Service Catalogue',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text('Manage platform service offers',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w400)),
                    ]),
              ),
            ]),
          ),
        ),
      );

  // ── CATALOGUE TAB ─────────────────────────────────────────────────────────

  Widget _buildCatalogueTab() {
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Type filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                children: ['All', ..._serviceTypes].map((t) {
                  final sel = _selectedType == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t),
                    child: AnimatedContainer(
                      duration: 150.ms,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel
                                ? Colors.transparent
                                : const Color(0xFFDDDDDD)),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppColors.textDark)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Text(
                '${filtered.length} service${filtered.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ),
          ),
          // List
          filtered.isEmpty
              ? SliverFillRemaining(child: _buildCatalogueEmpty())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _CatalogueRow(
                        service: filtered[i],
                        onDelete: () => _confirmDelete(context, filtered[i]),
                      )
                          .animate()
                          .fadeIn(delay: (i * 30).ms)
                          .slideX(begin: 0.03, end: 0),
                      childCount: filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCatalogueEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  shape: BoxShape.circle),
              child: const Icon(Icons.home_repair_service_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No Services Yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text(
              'Tap "Add Service" to seed the first service offer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
          ]),
        ),
      );

  // ── PROPOSALS TAB ─────────────────────────────────────────────────────────

  Widget _buildProposalsTab() {
    final pending = widget.pendingProposals;
    if (pending.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.07),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 40, color: Color(0xFF34C759)),
            ),
            const SizedBox(height: 16),
            const Text('All caught up!',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text(
              'No pending service proposals from professionals.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
          ]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _ProposalReviewCard(
        proposal: pending[i],
        onApprove: () => widget.onApproveProposal(pending[i]),
        onReject: (note) => widget.onRejectProposal(pending[i], note),
      ).animate().fadeIn(delay: (i * 40).ms),
    );
  }

  // ── CREATE SHEET ──────────────────────────────────────────────────────────

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateServiceSheet(
        onSubmit: (data) async {
          await widget.onCreateService(data);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── DELETE CONFIRM ────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, ServiceOfferModel service) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Service',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Delete "${service.serviceName}"? This will also remove it '
          'from all professionals\' service lists.',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await widget.onDeleteService(service.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Catalogue row ─────────────────────────────────────────────────────────────

class _CatalogueRow extends StatelessWidget {
  final ServiceOfferModel service;
  final VoidCallback onDelete;

  const _CatalogueRow({required this.service, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // Thumbnail
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: service.imageUrl != null
              ? Image.network(service.imageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder())
              : _placeholder(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.serviceName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(service.serviceType,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
              if (service.priceRange != null) ...[
                const SizedBox(width: 8),
                Text(service.priceRange!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ],
            ]),
          ]),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFFF3B30), size: 20),
          tooltip: 'Delete',
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        color: const Color(0xFFF0F4F2),
        child: const Icon(Icons.home_repair_service_rounded,
            color: AppColors.textLight, size: 24),
      );
}

// ── Proposal review card ──────────────────────────────────────────────────────

class _ProposalReviewCard extends StatelessWidget {
  final ServiceProposalModel proposal;
  final VoidCallback onApprove;
  final void Function(String? note) onReject;

  const _ProposalReviewCard({
    required this.proposal,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Pending Review',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9500))),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(proposal.serviceType,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(proposal.serviceName,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        if (proposal.description != null) ...[
          const SizedBox(height: 6),
          Text(proposal.description!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMedium, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
        if (proposal.priceRange != null) ...[
          const SizedBox(height: 6),
          Text('Price: ${proposal.priceRange}',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showRejectDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side:
                    BorderSide(color: const Color(0xFFFF3B30).withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Reject',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: onApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Approve',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Proposal',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rejecting "${proposal.serviceName}".',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textMedium)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason for rejection (optional)',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textLight),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReject(ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reject',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Create service bottom sheet ───────────────────────────────────────────────

class ServiceFormData {
  final String serviceName;
  final String serviceType;
  final String description;
  final List<String> includes;
  final String priceRange;
  final String duration;
  final String? tips;
  final String? imageUrl;

  const ServiceFormData({
    required this.serviceName,
    required this.serviceType,
    required this.description,
    required this.includes,
    required this.priceRange,
    required this.duration,
    this.tips,
    this.imageUrl,
  });
}

class _CreateServiceSheet extends StatefulWidget {
  final Future<void> Function(ServiceFormData data) onSubmit;

  const _CreateServiceSheet({required this.onSubmit});

  @override
  State<_CreateServiceSheet> createState() => _CreateServiceSheetState();
}

class _CreateServiceSheetState extends State<_CreateServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _includesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _tipsCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  String? _serviceType;
  bool _submitting = false;

  static const _serviceTypes = [
    'Plumber',
    'Electrician',
    'Technician',
    'Carpenter',
    'Masonry',
  ];

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _descCtrl,
      _includesCtrl,
      _priceCtrl,
      _durationCtrl,
      _tipsCtrl,
      _imageCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_serviceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a service type')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final includes = _includesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.onSubmit(ServiceFormData(
        serviceName: _nameCtrl.text.trim(),
        serviceType: _serviceType!,
        description: _descCtrl.text.trim(),
        includes: includes,
        priceRange: _priceCtrl.text.trim(),
        duration: _durationCtrl.text.trim(),
        tips: _tipsCtrl.text.trim().isEmpty ? null : _tipsCtrl.text.trim(),
        imageUrl:
            _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
      ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to create: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      child: Column(children: [
        const SizedBox(height: 12),
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            const Expanded(
              child: Text('Add New Service',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textDark),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Service Type'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _serviceTypes.map((t) {
                        final sel = _serviceType == t;
                        return GestureDetector(
                          onTap: () => setState(() => _serviceType = t),
                          child: AnimatedContainer(
                            duration: 150.ms,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? Colors.transparent
                                      : const Color(0xFFDDDDDD)),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textDark)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _label('Service Name *'),
                    const SizedBox(height: 8),
                    _field(_nameCtrl,
                        hint: 'e.g. Faucet/Bidet Install',
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null),
                    const SizedBox(height: 14),
                    _label('Description *'),
                    const SizedBox(height: 8),
                    _field(_descCtrl,
                        hint:
                            'e.g. Replacement of bathroom or kitchen fixtures.',
                        maxLines: 3,
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null),
                    const SizedBox(height: 14),
                    _label("What's Included"),
                    const SizedBox(height: 4),
                    const Text('Separate items with commas',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 6),
                    _field(_includesCtrl,
                        hint: 'Removal of old unit, Teflon tape, Leak testing'),
                    const SizedBox(height: 14),
                    _label('Price Range (Labor) *'),
                    const SizedBox(height: 8),
                    _field(_priceCtrl,
                        hint: 'e.g. ₱350 – ₱600',
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null),
                    const SizedBox(height: 14),
                    _label('Estimated Time *'),
                    const SizedBox(height: 8),
                    _field(_durationCtrl,
                        hint: 'e.g. 30 minutes – 1 hour',
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required' : null),
                    const SizedBox(height: 14),
                    _label('Pro Tip (optional)'),
                    const SizedBox(height: 8),
                    _field(_tipsCtrl,
                        hint:
                            'e.g. Buy heavy-duty stainless; plastic cracks easily.',
                        maxLines: 2),
                    const SizedBox(height: 14),
                    _label('Image URL (optional)'),
                    const SizedBox(height: 8),
                    _field(_imageCtrl, hint: 'https://…supabase.co/storage/…'),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Create Service',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark));

  Widget _field(
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF3B30))),
        ),
      );
}
