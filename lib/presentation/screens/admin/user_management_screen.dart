// lib/presentation/screens/admin/user_management_screen.dart
//
// AdminUserManagementScreen — admin view of all professionals and customers.
//
// Props:
//   professionals      → List<ProfessionalEntity> — all platform professionals
//   bookings           → List<BookingEntity>       — all platform bookings
//                        (used to derive per-user stats and find customer names)
//   onBack             → VoidCallback?
//   onRefresh          → Future<void> Function()?
//
// Design rules:
//   • No border-left accents, no emojis, no gradients on avatars
//   • Consistent header style with rounded gradient bottom
//   • Wrap-safe chips, clean cards

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class AdminUserManagementScreen extends StatefulWidget {
  final List<ProfessionalEntity> professionals;
  final List<BookingEntity> bookings;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;

  const AdminUserManagementScreen({
    super.key,
    this.professionals = const [],
    this.bookings = const [],
    this.onBack,
    this.onRefresh,
  });

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String _proSearch = '';
  String _custSearch = '';
  String _proFilter = 'All'; // All | Available | Unavailable

  // ── Derived data ──────────────────────────────────────────────────────────

  // Professionals list
  List<ProfessionalEntity> get _filteredPros {
    var list = widget.professionals;
    if (_proFilter == 'Available')
      list = list.where((p) => p.available).toList();
    if (_proFilter == 'Unavailable')
      list = list.where((p) => !p.available).toList();
    final q = _proSearch.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.skills.any((s) => s.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  // Derive unique customers from bookings
  List<_CustomerSummary> get _allCustomers {
    final map = <String, _CustomerSummary>{};
    for (final b in widget.bookings) {
      final c = b.customer;
      if (c == null) continue;
      final existing = map[c.id];
      map[c.id] = _CustomerSummary(
        id: c.id,
        name: c.name,
        email: c.email,
        totalBookings: (existing?.totalBookings ?? 0) + 1,
        completedBookings: (existing?.completedBookings ?? 0) +
            (b.status == BookingStatus.completed ? 1 : 0),
        totalSpent: (existing?.totalSpent ?? 0) +
            (b.status == BookingStatus.completed
                ? (b.assessmentPrice != null && b.assessmentPrice! > 0
                    ? b.assessmentPrice!
                    : (b.priceEstimate ?? 0))
                : 0),
      );
    }
    return map.values.toList()
      ..sort((a, b) => b.totalBookings.compareTo(a.totalBookings));
  }

  List<_CustomerSummary> get _filteredCustomers {
    final q = _custSearch.trim().toLowerCase();
    if (q.isEmpty) return _allCustomers;
    return _allCustomers
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(double v) {
    if (v >= 1000) return '₱${(v / 1000).toStringAsFixed(1)}k';
    return '₱${v.toStringAsFixed(0)}';
  }

  int _proBookingCount(String proId) =>
      widget.bookings.where((b) => b.professional?.id == proId).length;

  double _proEarnings(String proId) => widget.bookings
          .where((b) =>
              b.professional?.id == proId &&
              b.status == BookingStatus.completed)
          .fold(0.0, (s, b) {
        final ap = b.assessmentPrice;
        return s + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      });

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
        _buildHeader(),
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
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Professionals'),
                  const SizedBox(width: 6),
                  _tabBadge(widget.professionals.length, AppColors.primary),
                ]),
              ),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Customers'),
                  const SizedBox(width: 6),
                  _tabBadge(_allCustomers.length, const Color(0xFF007AFF)),
                ]),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildProfessionalsTab(),
              _buildCustomersTab(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
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
                        Text('User Management',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Manage professionals and customers',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Stats strip
                Row(children: [
                  _headerStat(
                      Icons.engineering_rounded,
                      '${widget.professionals.length}',
                      'Professionals',
                      const Color(0xFF4ADE80)),
                  const SizedBox(width: 10),
                  _headerStat(Icons.person_rounded, '${_allCustomers.length}',
                      'Customers', const Color(0xFF60A5FA)),
                  const SizedBox(width: 10),
                  _headerStat(
                      Icons.check_circle_rounded,
                      '${widget.professionals.where((p) => p.available).length}',
                      'Active Pros',
                      const Color(0xFFFBBF24)),
                ]),
              ],
            ),
          ),
        ),
      );

  Widget _headerStat(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 9)),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _tabBadge(int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  // ── PROFESSIONALS TAB ────────────────────────────────────────────────────

  Widget _buildProfessionalsTab() {
    final pros = _filteredPros;
    return Column(children: [
      // Search + filter
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          _searchBar(
            hint: 'Search by name or skill…',
            value: _proSearch,
            onChanged: (v) => setState(() => _proSearch = v),
            onClear: () => setState(() => _proSearch = ''),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _filterChip('All', _proFilter == 'All', AppColors.primary,
                () => setState(() => _proFilter = 'All')),
            const SizedBox(width: 8),
            _filterChip(
                'Available',
                _proFilter == 'Available',
                const Color(0xFF34C759),
                () => setState(() => _proFilter = 'Available')),
            const SizedBox(width: 8),
            _filterChip(
                'Unavailable',
                _proFilter == 'Unavailable',
                const Color(0xFFFF3B30),
                () => setState(() => _proFilter = 'Unavailable')),
          ]),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      // Count
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${pros.length} professional${pros.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ),
      ),
      Expanded(
        child: pros.isEmpty
            ? _emptyState(
                'No professionals found',
                'Try adjusting the search or filter.',
                Icons.engineering_rounded)
            : RefreshIndicator(
                onRefresh: widget.onRefresh ?? () async {},
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: pros.length,
                  itemBuilder: (_, i) => _ProCard(
                    pro: pros[i],
                    bookingCount: _proBookingCount(pros[i].id),
                    earnings: _proEarnings(pros[i].id),
                    fmt: _fmt,
                    onTap: () => _showProDetail(pros[i]),
                  )
                      .animate()
                      .fadeIn(delay: (i * 30).ms)
                      .slideX(begin: 0.03, end: 0),
                ),
              ),
      ),
    ]);
  }

  // ── CUSTOMERS TAB ────────────────────────────────────────────────────────

  Widget _buildCustomersTab() {
    final customers = _filteredCustomers;
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _searchBar(
          hint: 'Search by name or email…',
          value: _custSearch,
          onChanged: (v) => setState(() => _custSearch = v),
          onClear: () => setState(() => _custSearch = ''),
        ),
      ),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${customers.length} customer${customers.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ),
      ),
      Expanded(
        child: customers.isEmpty
            ? _emptyState(
                'No customers found',
                'Customers who have made bookings will appear here.',
                Icons.person_rounded)
            : RefreshIndicator(
                onRefresh: widget.onRefresh ?? () async {},
                color: AppColors.primary,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: customers.length,
                  itemBuilder: (_, i) => _CustomerCard(
                    customer: customers[i],
                    fmt: _fmt,
                    onTap: () => _showCustomerDetail(customers[i]),
                  )
                      .animate()
                      .fadeIn(delay: (i * 30).ms)
                      .slideX(begin: 0.03, end: 0),
                ),
              ),
      ),
    ]);
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _searchBar({
    required String hint,
    required String value,
    required void Function(String) onChanged,
    required VoidCallback onClear,
  }) =>
      Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textLight),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textLight),
            suffixIcon: value.isNotEmpty
                ? GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textLight),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          ),
        ),
      );

  Widget _filterChip(
          String label, bool selected, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 150.ms,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? color : const Color(0xFFDDDDDD)),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textDark)),
        ),
      );

  Widget _emptyState(String title, String sub, IconData icon) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  size: 40, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textLight, height: 1.5)),
          ]),
        ),
      );

  // ── Detail sheets ─────────────────────────────────────────────────────────

  void _showProDetail(ProfessionalEntity pro) {
    final bookings =
        widget.bookings.where((b) => b.professional?.id == pro.id).toList();
    final completed =
        bookings.where((b) => b.status == BookingStatus.completed).length;
    final earnings = _proEarnings(pro.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        title: pro.name,
        subtitle: pro.skills.isNotEmpty ? pro.skills.join(', ') : 'Handyman',
        avatarColor: AppColors.primary,
        rows: [
          _DetailRow(Icons.star_rounded, 'Rating',
              '${pro.rating.toStringAsFixed(1)} / 5.0'),
          _DetailRow(Icons.check_circle_outline_rounded, 'Completed Jobs',
              '$completed'),
          _DetailRow(Icons.calendar_today_rounded, 'Total Bookings',
              '${bookings.length}'),
          _DetailRow(Icons.payments_rounded, 'Total Earnings', _fmt(earnings)),
          _DetailRow(Icons.workspace_premium_rounded, 'Subscription',
              _tierLabel(pro.subscriptionTier)),
          _DetailRow(Icons.circle, 'Status',
              pro.available ? 'Available' : 'Unavailable',
              valueColor: pro.available
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30)),
          if (pro.city != null && pro.city!.isNotEmpty)
            _DetailRow(Icons.location_on_rounded, 'Location', pro.city!),
        ],
      ),
    );
  }

  void _showCustomerDetail(_CustomerSummary customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        title: customer.name,
        subtitle: customer.email.isNotEmpty ? customer.email : 'Customer',
        avatarColor: const Color(0xFF007AFF),
        rows: [
          _DetailRow(Icons.calendar_today_rounded, 'Total Bookings',
              '${customer.totalBookings}'),
          _DetailRow(Icons.check_circle_outline_rounded, 'Completed',
              '${customer.completedBookings}'),
          _DetailRow(
              Icons.payments_rounded, 'Total Spent', _fmt(customer.totalSpent)),
        ],
      ),
    );
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 1:
        return 'Pro';
      case 2:
        return 'Elite';
      default:
        return 'Free';
    }
  }
}

// ── Professional card ─────────────────────────────────────────────────────────

class _ProCard extends StatelessWidget {
  final ProfessionalEntity pro;
  final int bookingCount;
  final double earnings;
  final String Function(double) fmt;
  final VoidCallback onTap;

  const _ProCard({
    required this.pro,
    required this.bookingCount,
    required this.earnings,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = pro.subscriptionTier >= 2
        ? const Color(0xFFFF9500)
        : pro.subscriptionTier == 1
            ? const Color(0xFF007AFF)
            : AppColors.textLight;
    final tierLabel = pro.subscriptionTier >= 2
        ? 'Elite'
        : pro.subscriptionTier == 1
            ? 'Pro'
            : 'Free';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                pro.name.isNotEmpty ? pro.name[0].toUpperCase() : 'P',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(pro.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  // Tier badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tierLabel,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: tierColor)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  pro.skills.isNotEmpty
                      ? pro.skills.take(2).join(', ')
                      : 'Handyman',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Wrap(spacing: 12, runSpacing: 4, children: [
                  _stat(Icons.calendar_today_rounded, '$bookingCount jobs'),
                  _stat(Icons.payments_rounded, fmt(earnings)),
                  _stat(Icons.star_rounded, pro.rating.toStringAsFixed(1)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Availability dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: pro.available
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stat(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.textLight),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
      ]);
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final _CustomerSummary customer;
  final String Function(double) fmt;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                style: const TextStyle(
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w800,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (customer.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(customer.email,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 5),
                Wrap(spacing: 12, runSpacing: 4, children: [
                  _stat(Icons.calendar_today_rounded,
                      '${customer.totalBookings} bookings'),
                  _stat(Icons.check_circle_outline_rounded,
                      '${customer.completedBookings} done'),
                  _stat(Icons.payments_rounded, fmt(customer.totalSpent)),
                ]),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 18),
        ]),
      ),
    );
  }

  Widget _stat(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.textLight),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
      ]);
}

// ── Detail sheet ──────────────────────────────────────────────────────────────

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(this.icon, this.label, this.value, {this.valueColor});
}

class _DetailSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color avatarColor;
  final List<_DetailRow> rows;

  const _DetailSheet({
    required this.title,
    required this.subtitle,
    required this.avatarColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(children: [
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                  style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ]),
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
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: rows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  return Column(children: [
                    if (i > 0)
                      const Divider(height: 1, color: Color(0xFFF2F2F2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Icon(r.icon, size: 15, color: AppColors.textLight),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Text(r.label,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textLight)),
                        ),
                        Expanded(
                          child: Text(r.value,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: r.valueColor ?? AppColors.textDark)),
                        ),
                      ]),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Customer summary model ────────────────────────────────────────────────────

class _CustomerSummary {
  final String id;
  final String name;
  final String email;
  final int totalBookings;
  final int completedBookings;
  final double totalSpent;

  const _CustomerSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.totalBookings,
    required this.completedBookings,
    required this.totalSpent,
  });
}
