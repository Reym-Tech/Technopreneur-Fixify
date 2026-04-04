// lib/presentation/screens/admin/approvals_admin.dart
//
// ApprovalsScreen — Admin reviews four pipelines:
//   1. Handyman verification applications
//   2. Service offer proposals
//   3. Service selection requests
//   4. Subscription upgrade requests
//
// REDESIGN:
//   • Single top TabBar on a white surface — no nested dark sub-tab bars.
//   • Status filter (Pending / Approved / Rejected) as inline segment chips
//     per pipeline — keeps the layout flat and readable.
//   • Cards use a clean white shell with a small status dot; no border accents.
//   • Consistent spacing, typography, and action zone across all four pipelines.
//
// CREDENTIAL VERIFICATION (NEW):
//   • Before approving a handyman application, the admin must fill in
//     credential verification fields that match what the external system expects.
//   • TESDA path  → Last Name, First Name, first 4 digits + last 4 digits of
//                   the Certificate Number.
//   • License path (by Name)       → Profession, First Name, Last Name.
//   • License path (by License No.) → Profession, License No., Birthdate.
//   • The dialog is presented via _verifyAndApproveApp(); all three sub-paths
//     follow the same _cardShell / AlertDialog pattern used by _rejectDialog().

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/application_datasource.dart';
import 'package:fixify/data/datasources/service_selection_request_datasource.dart';
import 'package:fixify/data/models/models.dart' show SubscriptionRequestModel;

class ApprovalsScreen extends StatefulWidget {
  final List<ApplicationModel> applications;
  final List<ServiceProposalModel> proposals;
  final List<ServiceSelectionRequestModel> serviceRequests;
  final List<SubscriptionRequestModel> upgradeRequests;
  final Function(ApplicationModel)? onApprove;
  final Function(ApplicationModel, String?)? onReject;
  final Function(ServiceProposalModel)? onApproveProposal;
  final Function(ServiceProposalModel, String?)? onRejectProposal;
  final Function(ServiceSelectionRequestModel)? onApproveServiceRequest;
  final Function(ServiceSelectionRequestModel, String?)? onRejectServiceRequest;
  final Function(SubscriptionRequestModel)? onApproveUpgrade;
  final Function(SubscriptionRequestModel, String?)? onRejectUpgrade;
  final VoidCallback? onBack;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const ApprovalsScreen({
    super.key,
    this.applications = const [],
    this.proposals = const [],
    this.serviceRequests = const [],
    this.upgradeRequests = const [],
    this.onApprove,
    this.onReject,
    this.onApproveProposal,
    this.onRejectProposal,
    this.onApproveServiceRequest,
    this.onRejectServiceRequest,
    this.onApproveUpgrade,
    this.onRejectUpgrade,
    this.onBack,
    this.onNavTap,
    this.currentNavIndex = 1,
  });

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _topTabs;

  // Per-pipeline status filter — 'pending' | 'approved' | 'rejected'
  String _appFilter = 'pending';
  String _propFilter = 'pending';
  String _sreqFilter = 'pending';
  String _upgradeFilter = 'pending';

  String? _processingId;

  @override
  void initState() {
    super.initState();
    _topTabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _topTabs.dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<ApplicationModel> _filteredApps(String s) =>
      widget.applications.where((a) => a.status == s).toList();

  List<ServiceProposalModel> _filteredProps(String s) =>
      widget.proposals.where((p) => p.status == s).toList();

  List<ServiceSelectionRequestModel> _filteredSreqs(String s) =>
      widget.serviceRequests.where((r) => r.status == s).toList();

  List<SubscriptionRequestModel> _filteredUpgrades(String s) =>
      widget.upgradeRequests.where((r) => r.status == s).toList();

  int _pendingCount(String pipeline) {
    switch (pipeline) {
      case 'apps':
        return _filteredApps('pending').length;
      case 'props':
        return _filteredProps('pending').length;
      case 'sreqs':
        return _filteredSreqs('pending').length;
      case 'upgrades':
        return _filteredUpgrades('pending').length;
    }
    return 0;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalPending = _pendingCount('apps') +
        _pendingCount('props') +
        _pendingCount('sreqs') +
        _pendingCount('upgrades');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(totalPending),
          // ── Top tab bar — white background ────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _topTabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                _tabLabel('Applications', _pendingCount('apps')),
                _tabLabel('Proposals', _pendingCount('props')),
                _tabLabel('Selections', _pendingCount('sreqs')),
                _tabLabel('Plan Upgrades', _pendingCount('upgrades')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _topTabs,
              children: [
                _buildPipeline(
                  filter: _appFilter,
                  onFilterChange: (f) => setState(() => _appFilter = f),
                  counts: {
                    'pending': _filteredApps('pending').length,
                    'approved': _filteredApps('approved').length,
                    'rejected': _filteredApps('rejected').length,
                  },
                  items: _filteredApps(_appFilter),
                  itemBuilder: (item, i) =>
                      _buildAppCard(item as ApplicationModel, i),
                ),
                _buildPipeline(
                  filter: _propFilter,
                  onFilterChange: (f) => setState(() => _propFilter = f),
                  counts: {
                    'pending': _filteredProps('pending').length,
                    'approved': _filteredProps('approved').length,
                    'rejected': _filteredProps('rejected').length,
                  },
                  items: _filteredProps(_propFilter),
                  itemBuilder: (item, i) =>
                      _buildProposalCard(item as ServiceProposalModel, i),
                ),
                _buildPipeline(
                  filter: _sreqFilter,
                  onFilterChange: (f) => setState(() => _sreqFilter = f),
                  counts: {
                    'pending': _filteredSreqs('pending').length,
                    'approved': _filteredSreqs('approved').length,
                    'rejected': _filteredSreqs('rejected').length,
                  },
                  items: _filteredSreqs(_sreqFilter),
                  itemBuilder: (item, i) => _buildServiceRequestCard(
                      item as ServiceSelectionRequestModel, i),
                ),
                _buildPipeline(
                  filter: _upgradeFilter,
                  onFilterChange: (f) => setState(() => _upgradeFilter = f),
                  counts: {
                    'pending': _filteredUpgrades('pending').length,
                    'approved': _filteredUpgrades('approved').length,
                    'rejected': _filteredUpgrades('rejected').length,
                  },
                  items: _filteredUpgrades(_upgradeFilter),
                  itemBuilder: (item, i) =>
                      _buildUpgradeCard(item as SubscriptionRequestModel, i),
                ),
              ],
            ),
          ),
        ]),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Tab label with badge ──────────────────────────────────────────────────

  Tab _tabLabel(String label, int pending) => Tab(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          if (pending > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$pending',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );

  // ── Generic pipeline layout ───────────────────────────────────────────────

  Widget _buildPipeline({
    required String filter,
    required void Function(String) onFilterChange,
    required Map<String, int> counts,
    required List items,
    required Widget Function(dynamic, int) itemBuilder,
  }) {
    return Column(children: [
      // ── Segment filter ─────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          _segmentChip('Pending', filter == 'pending', counts['pending'] ?? 0,
              const Color(0xFFFF9500), () => onFilterChange('pending')),
          const SizedBox(width: 8),
          _segmentChip(
              'Approved',
              filter == 'approved',
              counts['approved'] ?? 0,
              const Color(0xFF34C759),
              () => onFilterChange('approved')),
          const SizedBox(width: 8),
          _segmentChip(
              'Rejected',
              filter == 'rejected',
              counts['rejected'] ?? 0,
              const Color(0xFFFF3B30),
              () => onFilterChange('rejected')),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      // ── List ───────────────────────────────────────────────────
      Expanded(
        child: items.isEmpty
            ? _emptyState(filter)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: items.length,
                itemBuilder: (_, i) => itemBuilder(items[i], i),
              ),
      ),
    ]);
  }

  Widget _segmentChip(String label, bool selected, int count, Color color,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 150.ms,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : const Color(0xFFDDDDDD),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textDark)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withOpacity(0.25)
                    : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : color)),
            ),
          ]),
        ),
      );

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState(String filter) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                shape: BoxShape.circle),
            child: Icon(
              filter == 'pending'
                  ? Icons.inbox_rounded
                  : filter == 'approved'
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
              size: 40,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            filter == 'pending'
                ? 'No pending items'
                : filter == 'approved'
                    ? 'Nothing approved yet'
                    : 'Nothing rejected yet',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            filter == 'pending' ? 'All caught up.' : 'Items will appear here.',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ]),
      );

  // ── Shared card shell ─────────────────────────────────────────────────────

  Widget _cardShell({
    required String status,
    required int index,
    required List<Widget> body,
    Widget? docsSection,
    Widget? includesSection,
    bool isPending = false,
    bool isLoading = false,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    Color approveColor = const Color(0xFF34C759),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: body),
        ),
        if (docsSection != null) ...[
          const Divider(height: 1, color: Color(0xFFF2F2F2)),
          docsSection,
        ],
        if (includesSection != null) ...[
          const Divider(height: 1, color: Color(0xFFF2F2F2)),
          includesSection,
        ],
        if (isPending) ...[
          const Divider(height: 1, color: Color(0xFFF2F2F2)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(approveColor)),
                    ),
                  )
                : _actionRow(
                    onReject: onReject,
                    onApprove: onApprove,
                    approveColor: approveColor,
                  ),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.05, end: 0);
  }

  // ── Application card ──────────────────────────────────────────────────────

  Widget _buildAppCard(ApplicationModel app, int index) => _cardShell(
        status: app.status,
        index: index,
        isPending: app.status == 'pending',
        isLoading: _processingId == app.id,
        onApprove: () => _verifyAndApproveApp(app),
        onReject: () => _confirmRejectApp(app),
        body: [
          _cardHeader(
            name: app.applicantName,
            subtitle: app.applicantEmail ?? '',
            status: app.status,
            avatarColor: AppColors.primary,
            date: null,
          ),
          const SizedBox(height: 12),
          // Credential type badge + service type badge
          Wrap(spacing: 8, runSpacing: 6, children: [
            _badge(app.serviceType, Icons.build_rounded, AppColors.primary),
            if (app.credentialType != null)
              _badge(
                app.isTesda ? 'TESDA' : 'Licensed',
                app.isTesda ? Icons.verified_rounded : Icons.badge_rounded,
                app.isTesda ? const Color(0xFF5856D6) : const Color(0xFF007AFF),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _infoChip(
                Icons.trending_up_rounded, '${app.yearsExp} yrs experience'),
            if (app.priceMin != null)
              _infoChip(Icons.payments_rounded,
                  '₱${app.priceMin!.toStringAsFixed(0)}/hr'),
          ]),
          if (app.bio != null && app.bio!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(app.bio!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (app.adminNote != null && app.status == 'rejected') ...[
            const SizedBox(height: 10),
            _feedbackNote(app.adminNote!),
          ],
        ],
        docsSection: (app.credentialUrl != null || app.validIdUrl != null)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Submitted Documents'),
                      const SizedBox(height: 10),
                      Row(children: [
                        if (app.credentialUrl != null)
                          _docTile('Credential', app.credentialUrl!,
                              const Color(0xFFFF9500)),
                        if (app.credentialUrl != null && app.validIdUrl != null)
                          const SizedBox(width: 10),
                        if (app.validIdUrl != null)
                          _docTile('Valid ID', app.validIdUrl!,
                              const Color(0xFF007AFF)),
                      ]),
                    ]),
              )
            : null,
      );

  // ── Proposal card ─────────────────────────────────────────────────────────

  Widget _buildProposalCard(ServiceProposalModel prop, int index) => _cardShell(
        status: prop.status,
        index: index,
        isPending: prop.status == 'pending',
        isLoading: _processingId == prop.id,
        approveColor: const Color(0xFFD4A843),
        onApprove: () => _approveProposal(prop),
        onReject: () => _confirmRejectProposal(prop),
        body: [
          _cardHeader(
            name: prop.proposerName,
            subtitle: 'Submitted ${_formatDate(prop.submittedAt)}',
            status: prop.status,
            avatarColor: const Color(0xFFD4A843),
            date: null,
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _badge(prop.serviceName, Icons.storefront_rounded,
                const Color(0xFFD4A843)),
            _badge(
                prop.serviceType, Icons.build_rounded, const Color(0xFF5856D6)),
          ]),
          if (prop.priceRange != null || prop.duration != null) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 16, runSpacing: 6, children: [
              if (prop.priceRange != null)
                _infoChip(Icons.payments_rounded, prop.priceRange!),
              if (prop.duration != null)
                _infoChip(Icons.schedule_rounded, prop.duration!),
            ]),
          ],
          if (prop.description != null && prop.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(prop.description!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (prop.adminNote != null && prop.status == 'rejected') ...[
            const SizedBox(height: 10),
            _feedbackNote(prop.adminNote!),
          ],
        ],
        docsSection: (prop.imageUrl != null && prop.imageUrl!.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Service Image'),
                      const SizedBox(height: 10),
                      Row(children: [
                        _docTile('Service Image', prop.imageUrl!,
                            const Color(0xFFD4A843)),
                        const Expanded(child: SizedBox()),
                      ]),
                    ]),
              )
            : null,
        includesSection: prop.includes.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("What's Included"),
                      const SizedBox(height: 8),
                      ...prop.includes.take(3).map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      size: 13, color: Color(0xFF34C759)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(item,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMedium)),
                                  ),
                                ]),
                          )),
                      if (prop.includes.length > 3)
                        Text(
                          '+ ${prop.includes.length - 3} more',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textLight),
                        ),
                    ]),
              )
            : null,
      );

  // ── Service Request card ──────────────────────────────────────────────────

  Widget _buildServiceRequestCard(ServiceSelectionRequestModel req, int index) {
    final isDeselect = req.action == 'deselect';
    final actionColor =
        isDeselect ? const Color(0xFF5856D6) : const Color(0xFFFF9500);
    return _cardShell(
      status: req.status,
      index: index,
      isPending: req.status == 'pending',
      isLoading: _processingId == req.id,
      approveColor: const Color(0xFFFF9500),
      onApprove: () => _approveServiceRequest(req),
      onReject: () => _confirmRejectServiceRequest(req),
      body: [
        _cardHeader(
          name: req.handymanName,
          subtitle: 'Submitted ${_formatDate(req.submittedAt)}',
          status: req.status,
          avatarColor: actionColor,
          date: null,
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _badge(req.serviceName ?? 'Unknown Service',
              Icons.home_repair_service_rounded, AppColors.primary),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    fontWeight: FontWeight.w600,
                    color: actionColor),
              ),
            ]),
          ),
          if (req.skillType != null)
            _badge(
                req.skillType!, Icons.build_rounded, const Color(0xFF5856D6)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded,
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDeselect
                    ? 'This handyman wants to stop offering this service. '
                        'Approve if appropriate; reject to keep it active.'
                    : 'This handyman wants to add this service to their profile. '
                        'Verify their credentials before approving.',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMedium, height: 1.45),
              ),
            ),
          ]),
        ),
        if (req.adminNote != null && req.status == 'rejected') ...[
          const SizedBox(height: 10),
          _feedbackNote(req.adminNote!),
        ],
      ],
    );
  }

  // ── Upgrade card ──────────────────────────────────────────────────────────

  Widget _buildUpgradeCard(SubscriptionRequestModel req, int index) {
    final tierColor = req.requestedTier >= 2
        ? const Color(0xFFFF9500)
        : const Color(0xFF007AFF);
    return _cardShell(
      status: req.status,
      index: index,
      isPending: req.isPending,
      isLoading: _processingId == req.id,
      approveColor: tierColor,
      onApprove: () => _approveUpgrade(req),
      onReject: () => _confirmRejectUpgrade(req),
      body: [
        _cardHeader(
          name: req.handymanName,
          subtitle: 'Submitted ${_formatDate(req.createdAt)}',
          status: req.status,
          avatarColor: tierColor,
          date: null,
        ),
        const SizedBox(height: 12),
        // Tier upgrade arrow
        Row(children: [
          _badge(req.currentTierLabel, Icons.person_outline_rounded,
              const Color(0xFF8E8E93)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded,
                size: 14, color: AppColors.textLight),
          ),
          _badge(req.requestedTierLabel, Icons.workspace_premium_rounded,
              tierColor),
        ]),
        if (req.adminNote != null && req.status == 'rejected') ...[
          const SizedBox(height: 10),
          _feedbackNote(req.adminNote!),
        ],
      ],
    );
  }

  // ── Shared widget helpers ─────────────────────────────────────────────────

  Widget _cardHeader({
    required String? name,
    required String subtitle,
    required String status,
    required Color avatarColor,
    required DateTime? date,
  }) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: avatarColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name?.isNotEmpty == true ? name![0].toUpperCase() : '?',
              style: TextStyle(
                  color: avatarColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 17),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name ?? 'Unknown',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ]),
        ),
        const SizedBox(width: 8),
        _statusChip(status),
      ]);

  Widget _badge(String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _infoChip(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textLight),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500)),
      ]);

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
          letterSpacing: 0.4));

  Widget _feedbackNote(String note) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFFF3B30), size: 13),
          const SizedBox(width: 8),
          Expanded(
            child: Text(note,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFCC2A20), height: 1.4)),
          ),
        ]),
      );

  Widget _statusChip(String status) {
    final Color color;
    final String label;
    switch (status) {
      case 'approved':
        color = const Color(0xFF34C759);
        label = 'Approved';
        break;
      case 'rejected':
        color = const Color(0xFFFF3B30);
        label = 'Rejected';
        break;
      default:
        color = const Color(0xFFFF9500);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _actionRow({
    required VoidCallback onReject,
    required VoidCallback onApprove,
    Color approveColor = const Color(0xFF34C759),
  }) =>
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
              side: const BorderSide(color: Color(0xFFFF3B30), width: 1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: const Text('Reject',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: approveColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: const Text('Verify & Approve',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ]);

  Widget _docTile(String label, String url, Color color) => Expanded(
        child: GestureDetector(
          onTap: () => _showDocDialog(label, url),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.05),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                Image.network(url,
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
                                color: color.withOpacity(0.4), size: 28),
                          ),
                        )),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.black.withOpacity(0.45),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  // ── Actions ────────────────────────────────────────────────────────────────

  // ── Credential verification before approving ──────────────────────────────
  //
  // This replaces the old _approveApp() direct call.  The admin must fill in
  // the verification fields that match the external registry before the
  // approval goes through.  The dialog shape and style follow _rejectDialog().
  //
  // credentialType == 'tesda':
  //   TESDA registry lookup → Last Name + First Name + cert digits (4+4).
  // credentialType == 'license' (or null/unknown, shown as fallback):
  //   PRC license lookup — two sub-modes toggled by the admin:
  //   • By Name        → Profession + First Name + Last Name
  //   • By License No. → Profession + License No. + Birthdate

  Future<void> _verifyAndApproveApp(ApplicationModel app) async {
    // Determine the credential path.
    //
    // • 'tesda'   → TESDA certificate verification dialog.
    // • 'license' → PRC / government license verification dialog.
    // • null      → Legacy row that predates the credential_type column.
    //               Ask the admin to pick a path before proceeding so we
    //               never silently assume the wrong verification method.
    String? resolvedType = app.credentialType;

    if (resolvedType == null) {
      resolvedType = await _pickCredentialTypeDialog(app);
      if (resolvedType == null) return; // admin dismissed the picker — abort.
    }

    final confirmed = resolvedType == 'tesda'
        ? await _tesdaVerifyDialog(app)
        : await _licenseVerifyDialog(app);

    if (confirmed == true) {
      setState(() => _processingId = app.id);
      await widget.onApprove?.call(app);
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Legacy credential-type picker ─────────────────────────────────────────
  //
  // Shown only for rows where credential_type IS NULL (submitted before the
  // column existed).  Returns 'tesda', 'license', or null (cancelled).

  Future<String?> _pickCredentialTypeDialog(ApplicationModel app) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.help_outline_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Select Credential Type',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'This application was submitted before credential types were '
                'recorded. Choose the verification path that matches the '
                'document submitted by ${app.applicantName ?? "this applicant"}.',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w400,
                    height: 1.45),
              ),
            ],
          ),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            // TESDA option
            GestureDetector(
              onTap: () => Navigator.pop(ctx, 'tesda'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF5856D6).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF5856D6).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5856D6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: Color(0xFF5856D6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TESDA',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5856D6))),
                          SizedBox(height: 2),
                          Text('National Certificate verification',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textLight)),
                        ]),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF5856D6), size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            // License option
            GestureDetector(
              onTap: () => Navigator.pop(ctx, 'license'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF007AFF).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.badge_rounded,
                        color: Color(0xFF007AFF), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Licensed',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF007AFF))),
                          SizedBox(height: 2),
                          Text('PRC / government license verification',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textLight)),
                        ]),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF007AFF), size: 18),
                ]),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textLight)),
            ),
          ],
        ),
      );

  // ── TESDA verification dialog ─────────────────────────────────────────────

  Future<bool?> _tesdaVerifyDialog(ApplicationModel app) {
    final lastNameCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final certFirst4Ctrl = TextEditingController();
    final certLast4Ctrl = TextEditingController();

    // Track validation state inside a StatefulBuilder.
    final formKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5856D6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: Color(0xFF5856D6), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('TESDA Verification',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'Enter the details exactly as they appear on the '
                'TESDA certificate to verify ${app.applicantName ?? "this applicant"}.',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w400,
                    height: 1.45),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _verifyField(
                controller: lastNameCtrl,
                label: 'Last Name',
                hint: 'as on certificate',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 10),
              _verifyField(
                controller: firstNameCtrl,
                label: 'First Name',
                hint: 'as on certificate',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _sectionLabel('Certificate Number'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _verifyField(
                    controller: certFirst4Ctrl,
                    label: 'First 4 digits',
                    hint: '0000',
                    icon: Icons.tag_rounded,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('—',
                      style:
                          TextStyle(fontSize: 18, color: AppColors.textLight)),
                ),
                Expanded(
                  child: _verifyField(
                    controller: certLast4Ctrl,
                    label: 'Last 4 digits',
                    hint: '0000',
                    icon: Icons.tag_rounded,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm & Approve',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── License verification dialog ───────────────────────────────────────────
  //
  // Two sub-modes toggled by a segmented control inside the dialog:
  //   • By Name        — Profession, First Name, Last Name
  //   • By License No. — Profession, License No., Birthdate

  Future<bool?> _licenseVerifyDialog(ApplicationModel app) {
    // 0 = By Name, 1 = By License No.
    int mode = 0;

    final professionCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final licenseNoCtrl = TextEditingController();
    final birthdateCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.badge_rounded,
                        color: Color(0xFF007AFF), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('License Verification',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Enter the PRC details for ${app.applicantName ?? "this applicant"} '
                  'to confirm their license is valid.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      fontWeight: FontWeight.w400,
                      height: 1.45),
                ),
                const SizedBox(height: 12),
                // Mode toggle
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(children: [
                    _modeTab('By Name', mode == 0,
                        () => setDlgState(() => mode = 0)),
                    _modeTab('By License No.', mode == 1,
                        () => setDlgState(() => mode = 1)),
                  ]),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Profession — common to both modes
                _verifyField(
                  controller: professionCtrl,
                  label: 'Profession',
                  hint: 'e.g. Electrician',
                  icon: Icons.work_outline_rounded,
                ),
                const SizedBox(height: 10),

                if (mode == 0) ...[
                  // By Name
                  _verifyField(
                    controller: firstNameCtrl,
                    label: 'First Name',
                    hint: 'as on PRC record',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                  _verifyField(
                    controller: lastNameCtrl,
                    label: 'Last Name',
                    hint: 'as on PRC record',
                    icon: Icons.person_outline_rounded,
                  ),
                ] else ...[
                  // By License No.
                  _verifyField(
                    controller: licenseNoCtrl,
                    label: 'License No.',
                    hint: 'e.g. 0123456',
                    icon: Icons.tag_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  // Birthdate picker
                  _birthdateField(
                    ctx: ctx,
                    controller: birthdateCtrl,
                    onPicked: (date) {
                      setDlgState(() {
                        birthdateCtrl.text =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      });
                    },
                  ),
                ],
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textLight)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm & Approve',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Dialog field helpers ───────────────────────────────────────────────────

  /// Standard text field used inside verification dialogs.
  Widget _verifyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int? maxLength,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
          labelStyle:
              const TextStyle(fontSize: 13, color: AppColors.textMedium),
          prefixIcon: Icon(icon, size: 16, color: AppColors.textLight),
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  /// Tappable birthdate field — opens a date picker.
  Widget _birthdateField({
    required BuildContext ctx,
    required TextEditingController controller,
    required void Function(DateTime) onPicked,
  }) =>
      TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontSize: 13),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        onTap: () async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: DateTime(1990),
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null) onPicked(picked);
        },
        decoration: InputDecoration(
          labelText: 'Birthdate',
          hintText: 'YYYY-MM-DD',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
          labelStyle:
              const TextStyle(fontSize: 13, color: AppColors.textMedium),
          prefixIcon: const Icon(Icons.calendar_today_rounded,
              size: 16, color: AppColors.textLight),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppColors.textLight),
          filled: true,
          fillColor: const Color(0xFFF8F8F8),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  /// Segmented toggle tab inside the license dialog.
  Widget _modeTab(String label, bool selected, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: 150.ms,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]
                  : null,
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.textDark : AppColors.textLight)),
          ),
        ),
      );

  // ── Remaining action methods (unchanged) ──────────────────────────────────

  Future<void> _confirmRejectApp(ApplicationModel app) async {
    final noteCtrl = TextEditingController();
    final ok = await _rejectDialog(
      title: 'Reject Application',
      message: 'Reject ${app.applicantName ?? "this applicant"}'
          '\'s application for ${app.serviceType}?',
      noteCtrl: noteCtrl,
    );
    if (ok == true) {
      setState(() => _processingId = app.id);
      await widget.onReject?.call(
          app, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _approveProposal(ServiceProposalModel prop) async {
    setState(() => _processingId = prop.id);
    await widget.onApproveProposal?.call(prop);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmRejectProposal(ServiceProposalModel prop) async {
    final noteCtrl = TextEditingController();
    final ok = await _rejectDialog(
      title: 'Reject Proposal',
      message: 'Reject ${prop.proposerName ?? "this handyman"}'
          '\'s proposal for "${prop.serviceName}"?',
      noteCtrl: noteCtrl,
    );
    if (ok == true) {
      setState(() => _processingId = prop.id);
      await widget.onRejectProposal?.call(
          prop, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _approveServiceRequest(ServiceSelectionRequestModel req) async {
    setState(() => _processingId = req.id);
    await widget.onApproveServiceRequest?.call(req);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmRejectServiceRequest(
      ServiceSelectionRequestModel req) async {
    final noteCtrl = TextEditingController();
    final isDeselect = req.action == 'deselect';
    final ok = await _rejectDialog(
      title: isDeselect ? 'Reject Removal Request' : 'Reject Service Request',
      message: isDeselect
          ? 'Reject ${req.handymanName ?? "this handyman"}'
              '\'s request to remove "${req.serviceName ?? "this service"}"?'
          : 'Reject ${req.handymanName ?? "this handyman"}'
              '\'s request to add "${req.serviceName ?? "this service"}"?',
      noteCtrl: noteCtrl,
    );
    if (ok == true) {
      setState(() => _processingId = req.id);
      await widget.onRejectServiceRequest?.call(
          req, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _approveUpgrade(SubscriptionRequestModel req) async {
    setState(() => _processingId = req.id);
    await widget.onApproveUpgrade?.call(req);
    if (mounted) setState(() => _processingId = null);
  }

  Future<void> _confirmRejectUpgrade(SubscriptionRequestModel req) async {
    final noteCtrl = TextEditingController();
    final ok = await _rejectDialog(
      title: 'Reject Upgrade Request',
      message: 'Reject ${req.handymanName ?? "this handyman"}'
          '\'s request to upgrade to ${req.requestedTierLabel}?',
      noteCtrl: noteCtrl,
    );
    if (ok == true) {
      setState(() => _processingId = req.id);
      await widget.onRejectUpgrade?.call(
          req, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Reject dialog ─────────────────────────────────────────────────────────

  Future<bool?> _rejectDialog({
    required String title,
    required String message,
    required TextEditingController noteCtrl,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMedium, height: 1.5)),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Feedback for the handyman (optional)',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textLight),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textLight)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
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

  // ── Doc viewer ────────────────────────────────────────────────────────────

  void _showDocDialog(String label, String url) => showDialog(
        context: context,
        builder: (ctx) => Dialog(
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
                  onPressed: () => Navigator.of(ctx).pop(),
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
                  child: Image.network(url,
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
                      errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.fromLTRB(24, 8, 24, 28),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      color: Colors.white30, size: 48),
                                  SizedBox(height: 10),
                                  Text('Image could not be loaded.',
                                      style: TextStyle(
                                          color: Colors.white60, fontSize: 13),
                                      textAlign: TextAlign.center),
                                ]),
                          )),
                ),
              ),
            ),
          ]),
        ),
      );

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(int totalPending) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
                      Text('Review applications & proposals',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11)),
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

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  // ── Bottom nav ────────────────────────────────────────────────────────────

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
