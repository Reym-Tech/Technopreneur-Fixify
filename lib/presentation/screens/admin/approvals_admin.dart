// lib/presentation/screens/admin/approvals_admin.dart
//
// ApprovalsScreen — Admin screen to review:
//   1. Handyman verification applications  (ApplicationModel pipeline)
//   2. Service offer proposals             (ServiceProposalModel pipeline)
//   3. Service selection requests          (ServiceSelectionRequestModel pipeline)
//
// Top-level tabs: "Handyman Apps" | "Service Proposals" | "Service Requests"
// Each tab has sub-tabs: Pending / Approved / Rejected
//
// SERVICE SELECTION REQUEST PATCH:
//   A handyman toggling a service on/off in MyServicesScreen now submits a
//   ServiceSelectionRequestModel instead of writing directly to
//   professional_services. The new third tab lets the admin review these
//   requests, cross-check credentials, and approve or reject each one.
//   On approval the Controller (main.dart) writes the actual
//   professional_services record; on rejection it notifies the handyman.
//
// Key props:
//   applications         → List<ApplicationModel>
//   proposals            → List<ServiceProposalModel>
//   serviceRequests      → List<ServiceSelectionRequestModel>
//   onApprove            → Function(ApplicationModel)?
//   onReject             → Function(ApplicationModel, String? note)?
//   onApproveProposal    → Function(ServiceProposalModel)?
//   onRejectProposal     → Function(ServiceProposalModel, String? note)?
//   onApproveServiceRequest → Function(ServiceSelectionRequestModel)?
//   onRejectServiceRequest  → Function(ServiceSelectionRequestModel, String?)?
//   onBack               → VoidCallback?
//   onNavTap             → Function(int)?
//   currentNavIndex      → int

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/application_datasource.dart';
import 'package:fixify/data/datasources/service_selection_request_datasource.dart';

class ApprovalsScreen extends StatefulWidget {
  final List<ApplicationModel> applications;
  final List<ServiceProposalModel> proposals;

  /// Pending / approved / rejected service selection requests from handymen.
  final List<ServiceSelectionRequestModel> serviceRequests;

  final Function(ApplicationModel)? onApprove;
  final Function(ApplicationModel, String?)? onReject;
  final Function(ServiceProposalModel)? onApproveProposal;
  final Function(ServiceProposalModel, String?)? onRejectProposal;

  /// Called when the admin approves a service selection request.
  /// The Controller (main.dart) is responsible for writing the actual
  /// professional_services record after this callback resolves.
  final Function(ServiceSelectionRequestModel)? onApproveServiceRequest;

  /// Called when the admin rejects a service selection request.
  /// Optional admin note is passed as the second argument.
  final Function(ServiceSelectionRequestModel, String?)? onRejectServiceRequest;

  final VoidCallback? onBack;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const ApprovalsScreen({
    super.key,
    this.applications = const [],
    this.proposals = const [],
    this.serviceRequests = const [],
    this.onApprove,
    this.onReject,
    this.onApproveProposal,
    this.onRejectProposal,
    this.onApproveServiceRequest,
    this.onRejectServiceRequest,
    this.onBack,
    this.onNavTap,
    this.currentNavIndex = 1,
  });

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with TickerProviderStateMixin {
  // Top-level: Handyman Apps | Service Proposals | Service Requests
  late TabController _topTabs;
  // Sub-tabs: Pending / Approved / Rejected — one per top-level tab
  late TabController _appSubTabs;
  late TabController _propSubTabs;
  late TabController _sreqSubTabs;

  String? _processingId;

  @override
  void initState() {
    super.initState();
    _topTabs = TabController(length: 3, vsync: this);
    _appSubTabs = TabController(length: 3, vsync: this);
    _propSubTabs = TabController(length: 3, vsync: this);
    _sreqSubTabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _topTabs.dispose();
    _appSubTabs.dispose();
    _propSubTabs.dispose();
    _sreqSubTabs.dispose();
    super.dispose();
  }

  // ── Filtering helpers ──────────────────────────────────────────────────────

  List<ApplicationModel> _filteredApps(String status) =>
      widget.applications.where((a) => a.status == status).toList();

  List<ServiceProposalModel> _filteredProps(String status) =>
      widget.proposals.where((p) => p.status == status).toList();

  List<ServiceSelectionRequestModel> _filteredSreqs(String status) =>
      widget.serviceRequests.where((r) => r.status == status).toList();

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendingApps = _filteredApps('pending');
    final pendingProps = _filteredProps('pending');
    final pendingSreqs = _filteredSreqs('pending');
    final totalPending =
        pendingApps.length + pendingProps.length + pendingSreqs.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(totalPending),
          // ── Top-level tab bar: Handyman Apps | Service Proposals | Service Requests
          Container(
            color: const Color(0xFF0F3D2E),
            child: TabBar(
              controller: _topTabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  text: 'Handyman Apps'
                      '${pendingApps.isNotEmpty ? ' (${pendingApps.length})' : ''}',
                ),
                Tab(
                  text: 'Service Proposals'
                      '${pendingProps.isNotEmpty ? ' (${pendingProps.length})' : ''}',
                ),
                Tab(
                  text: 'Service Requests'
                      '${pendingSreqs.isNotEmpty ? ' (${pendingSreqs.length})' : ''}',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _topTabs,
              children: [
                // ── Pipeline 1: Handyman Applications ──────────────────
                _buildApplicationsPipeline(pendingApps),
                // ── Pipeline 2: Service Proposals ───────────────────────
                _buildProposalsPipeline(pendingProps),
                // ── Pipeline 3: Service Selection Requests ──────────────
                _buildServiceRequestsPipeline(pendingSreqs),
              ],
            ),
          ),
        ]),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Handyman Applications pipeline ────────────────────────────────────────

  Widget _buildApplicationsPipeline(List<ApplicationModel> pending) {
    final approved = _filteredApps('approved');
    final rejected = _filteredApps('rejected');
    return Column(children: [
      Container(
        color: const Color(0xFF082218),
        child: TabBar(
          controller: _appSubTabs,
          indicatorColor: const Color(0xFF34C759),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: [
            Tab(
                text:
                    'Pending${pending.isNotEmpty ? ' (${pending.length})' : ''}'),
            Tab(
                text:
                    'Approved${approved.isNotEmpty ? ' (${approved.length})' : ''}'),
            Tab(
                text:
                    'Rejected${rejected.isNotEmpty ? ' (${rejected.length})' : ''}'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _appSubTabs,
          children: [
            _buildAppList(pending),
            _buildAppList(approved),
            _buildAppList(rejected),
          ],
        ),
      ),
    ]);
  }

  Widget _buildAppList(List<ApplicationModel> apps) {
    if (apps.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: apps.length,
      itemBuilder: (_, i) => _buildAppCard(apps[i], i),
    );
  }

  // ── Service Proposals pipeline ────────────────────────────────────────────

  Widget _buildProposalsPipeline(List<ServiceProposalModel> pending) {
    final approved = _filteredProps('approved');
    final rejected = _filteredProps('rejected');
    return Column(children: [
      Container(
        color: const Color(0xFF082218),
        child: TabBar(
          controller: _propSubTabs,
          indicatorColor: const Color(0xFFD4A843),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: [
            Tab(
                text:
                    'Pending${pending.isNotEmpty ? ' (${pending.length})' : ''}'),
            Tab(
                text:
                    'Approved${approved.isNotEmpty ? ' (${approved.length})' : ''}'),
            Tab(
                text:
                    'Rejected${rejected.isNotEmpty ? ' (${rejected.length})' : ''}'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _propSubTabs,
          children: [
            _buildPropList(pending),
            _buildPropList(approved),
            _buildPropList(rejected),
          ],
        ),
      ),
    ]);
  }

  Widget _buildPropList(List<ServiceProposalModel> props) {
    if (props.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: props.length,
      itemBuilder: (_, i) => _buildProposalCard(props[i], i),
    );
  }

  // ── Service Selection Requests pipeline ──────────────────────────────────

  Widget _buildServiceRequestsPipeline(
      List<ServiceSelectionRequestModel> pending) {
    final approved = _filteredSreqs('approved');
    final rejected = _filteredSreqs('rejected');
    return Column(children: [
      Container(
        color: const Color(0xFF082218),
        child: TabBar(
          controller: _sreqSubTabs,
          indicatorColor: const Color(0xFFFF9500),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: [
            Tab(
                text:
                    'Pending${pending.isNotEmpty ? ' (${pending.length})' : ''}'),
            Tab(
                text:
                    'Approved${approved.isNotEmpty ? ' (${approved.length})' : ''}'),
            Tab(
                text:
                    'Rejected${rejected.isNotEmpty ? ' (${rejected.length})' : ''}'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _sreqSubTabs,
          children: [
            _buildSreqList(pending),
            _buildSreqList(approved),
            _buildSreqList(rejected),
          ],
        ),
      ),
    ]);
  }

  Widget _buildSreqList(List<ServiceSelectionRequestModel> reqs) {
    if (reqs.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      itemCount: reqs.length,
      itemBuilder: (_, i) => _buildServiceRequestCard(reqs[i], i),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 52, color: AppColors.textLight.withOpacity(0.3)),
          const SizedBox(height: 12),
          const Text('Nothing here',
              style: TextStyle(color: AppColors.textLight, fontSize: 15)),
        ]),
      );

  // ── Handyman Application card ─────────────────────────────────────────────

  Widget _buildAppCard(ApplicationModel app, int index) {
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
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _avatar(app.applicantName),
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
                    ]),
              ),
              _statusChip(app.status),
            ]),
            const SizedBox(height: 12),
            _serviceBadge(app.serviceType, Icons.build_rounded),
            const SizedBox(height: 10),
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
            if (app.adminNote != null && app.status == 'rejected') ...[
              const SizedBox(height: 10),
              _adminNoteChip(app.adminNote!),
            ],
          ]),
        ),
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
        if (isPending) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        strokeWidth: 2))
                : _approveRejectRow(
                    onReject: () => _confirmRejectApp(app),
                    onApprove: () => _approveApp(app),
                  ),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.06, end: 0);
  }

  // ── Service Proposal card ─────────────────────────────────────────────────

  Widget _buildProposalCard(ServiceProposalModel prop, int index) {
    final isPending = prop.status == 'pending';
    final isLoading = _processingId == prop.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _avatar(prop.proposerName, color: const Color(0xFFD4A843)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prop.proposerName ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text('Submitted ${_formatDate(prop.submittedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ]),
              ),
              _statusChip(prop.status),
            ]),
            const SizedBox(height: 12),
            // Service name + type badges
            Wrap(spacing: 8, runSpacing: 6, children: [
              _serviceBadge(prop.serviceName, Icons.storefront_rounded),
              _serviceBadge(prop.serviceType, Icons.build_rounded,
                  color: const Color(0xFF5856D6)),
            ]),
            // Quick details
            if (prop.priceRange != null || prop.duration != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (prop.priceRange != null)
                  _info(Icons.payments_rounded, prop.priceRange!),
                if (prop.priceRange != null && prop.duration != null)
                  const SizedBox(width: 16),
                if (prop.duration != null)
                  _info(Icons.schedule_rounded, prop.duration!),
              ]),
            ],
            if (prop.description != null && prop.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(prop.description!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (prop.adminNote != null && prop.status == 'rejected') ...[
              const SizedBox(height: 10),
              _adminNoteChip(prop.adminNote!),
            ],
          ]),
        ),
        // ── Service image preview ──────────────────────────────
        if (prop.imageUrl != null && prop.imageUrl!.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Service Image',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                      letterSpacing: 0.3)),
              const SizedBox(height: 10),
              Row(children: [
                _docTile(
                    'Service Image', prop.imageUrl!, const Color(0xFFD4A843)),
              ]),
            ]),
          ),
        ],
        // ── Includes preview ───────────────────────────────────
        if (prop.includes.isNotEmpty) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('What\'s Included',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium)),
              const SizedBox(height: 8),
              ...prop.includes.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 13, color: Color(0xFF34C759)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(item,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMedium)),
                          ),
                        ]),
                  )),
              if (prop.includes.length > 3)
                Text('+ ${prop.includes.length - 3} more',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
            ]),
          ),
        ],
        if (isPending) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFD4A843)),
                        strokeWidth: 2))
                : _approveRejectRow(
                    onReject: () => _confirmRejectProposal(prop),
                    onApprove: () => _approveProposal(prop),
                    approveColor: const Color(0xFFD4A843),
                  ),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.06, end: 0);
  }

  // ── Service Selection Request card ──────────────────────────────────────────

  Widget _buildServiceRequestCard(ServiceSelectionRequestModel req, int index) {
    final isPending = req.status == 'pending';
    final isLoading = _processingId == req.id;
    final isDeselect = req.action == 'deselect';

    // Amber for select requests, purple for deselect requests — mirrors the
    // action badge colours used in MyServicesScreen.
    const selectColor = Color(0xFFFF9500);
    const deselectColor = Color(0xFF5856D6);
    final actionColor = isDeselect ? deselectColor : selectColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header row: avatar + name + status chip ───────────────
            Row(children: [
              _avatar(req.handymanName, color: actionColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.handymanName ?? 'Unknown Handyman',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text('Submitted ${_formatDate(req.submittedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                    ]),
              ),
              _statusChip(req.status),
            ]),
            const SizedBox(height: 12),
            // ── Service name + action + skill type badges ─────────────
            Wrap(spacing: 8, runSpacing: 6, children: [
              _serviceBadge(req.serviceName ?? 'Unknown Service',
                  Icons.home_repair_service_rounded),
              // Action badge: "Add Service" or "Remove Service"
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isDeselect
                        ? Icons.remove_circle_outline_rounded
                        : Icons.add_circle_outline_rounded,
                    color: actionColor,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isDeselect ? 'Remove Service' : 'Add Service',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: actionColor),
                  ),
                ]),
              ),
              if (req.skillType != null)
                _serviceBadge(req.skillType!, Icons.build_rounded,
                    color: const Color(0xFF5856D6)),
            ]),
            const SizedBox(height: 10),
            // ── Context note for the admin ────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: actionColor.withOpacity(0.2)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isDeselect
                        ? 'This handyman wants to stop offering this service. '
                            'Approve if appropriate; reject to keep it active.'
                        : 'This handyman wants to add this service to their profile. '
                            'Verify their credentials before approving.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMedium, height: 1.4),
                  ),
                ),
              ]),
            ),
            // ── Admin rejection note ──────────────────────────────────
            if (req.adminNote != null && req.status == 'rejected') ...[
              const SizedBox(height: 10),
              _adminNoteChip(req.adminNote!),
            ],
          ]),
        ),
        // ── Approve / Reject row (pending only) ──────────────────────
        if (isPending) ...[
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFF9500)),
                        strokeWidth: 2))
                : _approveRejectRow(
                    onReject: () => _confirmRejectServiceRequest(req),
                    onApprove: () => _approveServiceRequest(req),
                    approveColor: const Color(0xFFFF9500),
                  ),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.06, end: 0);
  }

  // ── Actions — Service Selection Requests ──────────────────────────────────

  Future<void> _approveServiceRequest(ServiceSelectionRequestModel req) async {
    setState(() => _processingId = req.id);
    await widget.onApproveServiceRequest?.call(req);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmRejectServiceRequest(
      ServiceSelectionRequestModel req) async {
    final noteCtrl = TextEditingController();
    final isDeselect = req.action == 'deselect';
    final handymanName = req.handymanName ?? 'this handyman';
    final serviceName = req.serviceName ?? 'this service';
    final confirmed = await _rejectDialog(
      ctx: context,
      title: isDeselect ? 'Reject Removal Request' : 'Reject Service Request',
      message: isDeselect
          ? 'Reject $handymanName\'s request to remove '
              '"$serviceName" from their profile?\n\n'
              'The service will remain active on their profile.'
          : 'Reject $handymanName\'s request to add '
              '"$serviceName" to their profile?\n\n'
              'You can provide feedback so they know what credentials are needed.',
      noteCtrl: noteCtrl,
    );
    if (confirmed == true) {
      setState(() => _processingId = req.id);
      await widget.onRejectServiceRequest?.call(
          req, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Shared widget helpers ─────────────────────────────────────────────────

  Widget _avatar(String? name, {Color color = const Color(0xFF34C759)}) =>
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name?.isNotEmpty == true ? name![0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
      );

  Widget _serviceBadge(String label, IconData icon,
          {Color color = AppColors.primary}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      );

  Widget _adminNoteChip(String note) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFFF3B30), size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Feedback: $note',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF3B30))),
          ),
        ]),
      );

  Widget _approveRejectRow({
    required VoidCallback onReject,
    required VoidCallback onApprove,
    Color approveColor = const Color(0xFF34C759),
  }) =>
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF3B30)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Reject',
                style: TextStyle(
                    color: Color(0xFFFF3B30), fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: approveColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            child: const Text('Approve',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]);

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

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textLight),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500)),
        ],
      );

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
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.85)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 11),
                          const SizedBox(width: 3),
                          Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  String _formatDate(DateTime dt) {
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

  // ── Actions — Applications ─────────────────────────────────────────────────

  Future<void> _approveApp(ApplicationModel app) async {
    setState(() => _processingId = app.id);
    await widget.onApprove?.call(app);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmRejectApp(ApplicationModel app) async {
    final noteCtrl = TextEditingController();
    final confirmed = await _rejectDialog(
      ctx: context,
      title: 'Reject Application',
      message:
          'Reject ${app.applicantName ?? "this applicant"}\'s application for ${app.serviceType}?',
      noteCtrl: noteCtrl,
    );
    if (confirmed == true) {
      setState(() => _processingId = app.id);
      await widget.onReject?.call(
          app, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Actions — Proposals ────────────────────────────────────────────────────

  Future<void> _approveProposal(ServiceProposalModel prop) async {
    setState(() => _processingId = prop.id);
    await widget.onApproveProposal?.call(prop);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmRejectProposal(ServiceProposalModel prop) async {
    final noteCtrl = TextEditingController();
    final confirmed = await _rejectDialog(
      ctx: context,
      title: 'Reject Proposal',
      message:
          'Reject ${prop.proposerName ?? "this handyman"}\'s proposal for "${prop.serviceName}"?\n\n'
          'You can add feedback so they know what to fix.',
      noteCtrl: noteCtrl,
    );
    if (confirmed == true) {
      setState(() => _processingId = prop.id);
      await widget.onRejectProposal?.call(
          prop, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Shared reject dialog ───────────────────────────────────────────────────

  Future<bool?> _rejectDialog({
    required BuildContext ctx,
    required String title,
    required String message,
    required TextEditingController noteCtrl,
  }) =>
      showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, style: const TextStyle(color: AppColors.textMedium)),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Feedback for the handyman (optional)',
                hintStyle: const TextStyle(fontSize: 13),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reject',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  void _showDocDialog(String label, String url) => showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.black87,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ]),
            ),
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
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.broken_image_outlined,
                                color: Colors.white30, size: 48),
                            SizedBox(height: 10),
                            Text('Image could not be loaded.',
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 13),
                                textAlign: TextAlign.center),
                          ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(int totalPending) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(children: [
              GestureDetector(
                onTap: widget.onBack ?? () => widget.onNavTap?.call(0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Approvals',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('Review applications & service proposals',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              if (totalPending > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFFF3B30).withOpacity(0.4)),
                  ),
                  child: Text('$totalPending pending',
                      style: const TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      );

  // ── Bottom nav ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.pending_actions_rounded, 'label': 'Approvals'},
      {'icon': Icons.bar_chart_rounded, 'label': 'Analytics'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == widget.currentNavIndex;
              return GestureDetector(
                onTap: () => widget.onNavTap?.call(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i]['icon'] as IconData,
                        color: active ? AppColors.primary : AppColors.textLight,
                        size: 24),
                    const SizedBox(height: 4),
                    Text(items[i]['label'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                            color: active
                                ? AppColors.primary
                                : AppColors.textLight)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
