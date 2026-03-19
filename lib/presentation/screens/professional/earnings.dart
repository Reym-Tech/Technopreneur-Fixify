// lib/presentation/screens/professional/earnings_handyman.dart
//
// EarningsHandymanScreen — Real data version.
//
// FIXES from previous version:
//  1. _effectivePrice() helper — always uses assessmentPrice (the price the
//     pro actually agreed on) when available, falling back to priceEstimate.
//  2. All earnings aggregations go through _effectivePrice.
//  3. Monthly bar chart and service breakdown also use _effectivePrice.
//  4. Transaction tiles show the effective price instead of the raw estimate.
//  5. Empty-state cards explain WHY there's no data.
//  6. Pending amount counts bookings in accepted/inProgress/pending states.
//  7. _transactionBookings includes 'accepted' and 'inProgress'.
//  8. BookingStatus.scheduleProposed added to all exhaustive switches.
//  9. withOpacity replaced with withValues throughout.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class EarningsHandymanScreen extends StatefulWidget {
  final String? professionalId;
  final ProfessionalEntity? professional;
  final List<BookingEntity> bookings;
  final List<ReviewEntity> reviews;
  final VoidCallback? onBack;
  final Function(DateTimeRange)? onDateRangeSelected;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const EarningsHandymanScreen({
    super.key,
    this.professionalId,
    this.professional,
    this.bookings = const [],
    this.reviews = const [],
    this.onBack,
    this.onDateRangeSelected,
    this.onNavTap,
    this.currentNavIndex = 2,
  });

  @override
  State<EarningsHandymanScreen> createState() => _EarningsHandymanScreenState();
}

class _EarningsHandymanScreenState extends State<EarningsHandymanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTimeRange? _selectedDateRange;
  BookingStatus? _selectedStatusFilter;
  String? _searchQuery;
  String? _expandedId;

  // ── Tier helpers ─────────────────────────────────────────
  int get _tier => (widget.professional?.subscriptionTier ?? 0).clamp(0, 2);
  bool get _isElite => _tier >= 2;
  bool get _isPro => _tier >= 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isPro ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── KEY FIX: Effective price helper ─────────────────────
  double _effectivePrice(BookingEntity b) {
    final ap = b.assessmentPrice;
    if (ap != null && ap > 0) return ap;
    return b.priceEstimate ?? 0.0;
  }

  // ── Derived Stats ────────────────────────────────────────

  List<BookingEntity> get _completed => widget.bookings
      .where((b) => b.status == BookingStatus.completed)
      .toList();

  /// Completed bookings filtered by [_selectedDateRange] when active.
  /// All Overview stats that depend on the date filter use this getter.
  List<BookingEntity> get _filteredCompleted {
    if (_selectedDateRange == null) return _completed;
    return _completed.where((b) {
      return !b.scheduledDate.isBefore(_selectedDateRange!.start) &&
          !b.scheduledDate.isAfter(_selectedDateRange!.end);
    }).toList();
  }

  List<BookingEntity> get _unpaid => widget.bookings
      .where((b) =>
          b.status == BookingStatus.pending ||
          b.status == BookingStatus.accepted ||
          b.status == BookingStatus.inProgress)
      .toList();

  double get _totalEarnings =>
      _filteredCompleted.fold(0.0, (s, b) => s + _effectivePrice(b));

  double get _thisMonthEarnings {
    final now = DateTime.now();
    return _completed
        .where((b) =>
            b.scheduledDate.year == now.year &&
            b.scheduledDate.month == now.month)
        .fold(0.0, (s, b) => s + _effectivePrice(b));
  }

  double get _lastMonthEarnings {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    return _completed
        .where((b) =>
            b.scheduledDate.year == lastMonth.year &&
            b.scheduledDate.month == lastMonth.month)
        .fold(0.0, (s, b) => s + _effectivePrice(b));
  }

  double get _todayEarnings {
    final now = DateTime.now();
    return _completed
        .where((b) =>
            b.scheduledDate.year == now.year &&
            b.scheduledDate.month == now.month &&
            b.scheduledDate.day == now.day)
        .fold(0.0, (s, b) => s + _effectivePrice(b));
  }

  double get _pendingAmount =>
      _unpaid.fold(0.0, (s, b) => s + _effectivePrice(b));

  double get _completionRate {
    final bookings = _selectedDateRange == null
        ? widget.bookings
        : widget.bookings.where((b) {
            return !b.scheduledDate.isBefore(_selectedDateRange!.start) &&
                !b.scheduledDate.isAfter(_selectedDateRange!.end);
          });
    final relevant = bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled)
        .length;
    if (relevant == 0) return 0;
    return (_filteredCompleted.length / relevant) * 100;
  }

  double get _avgRating {
    if (widget.reviews.isNotEmpty) {
      return widget.reviews.fold<int>(0, (s, r) => s + r.rating) /
          widget.reviews.length;
    }
    return 0.0;
  }

  // ── Monthly aggregation ──────────────────────────────────

  List<_MonthlyData> get _monthlyEarnings {
    final map = <String, _MonthlyData>{};
    for (final b in _filteredCompleted) {
      final key =
          '${b.scheduledDate.year}-${b.scheduledDate.month.toString().padLeft(2, '0')}';
      final label = _monthLabel(b.scheduledDate.month);
      final price = _effectivePrice(b);
      final existing = map[key];
      if (existing == null) {
        map[key] = _MonthlyData(
            label: label,
            month: b.scheduledDate.month,
            year: b.scheduledDate.year,
            amount: price,
            jobs: 1);
      } else {
        map[key] = _MonthlyData(
            label: label,
            month: existing.month,
            year: existing.year,
            amount: existing.amount + price,
            jobs: existing.jobs + 1);
      }
    }
    final sorted = map.values.toList()
      ..sort((a, b) {
        if (a.year != b.year) return a.year.compareTo(b.year);
        return a.month.compareTo(b.month);
      });
    return sorted;
  }

  String _monthLabel(int month) {
    const labels = [
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
    return labels[month - 1];
  }

  // ── Service breakdown ────────────────────────────────────

  List<_ServiceData> get _serviceBreakdown {
    final map = <String, _ServiceData>{};
    final colors = [
      Colors.amber,
      Colors.blue,
      Colors.brown,
      Colors.teal,
      Colors.purple,
      Colors.pink,
    ];
    int colorIndex = 0;
    for (final b in _filteredCompleted) {
      final type = b.serviceType;
      final price = _effectivePrice(b);
      final existing = map[type];
      final color = existing?.color ?? colors[colorIndex++ % colors.length];
      if (existing == null) {
        map[type] = _ServiceData(
            serviceType: type, count: 1, amount: price, color: color);
      } else {
        map[type] = _ServiceData(
            serviceType: type,
            count: existing.count + 1,
            amount: existing.amount + price,
            color: color);
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  // ── Transactions from bookings ───────────────────────────

  List<BookingEntity> get _transactionBookings {
    var list = widget.bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.pending ||
            b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress)
        .toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    if (_selectedDateRange != null) {
      list = list.where((b) {
        return !b.scheduledDate.isBefore(_selectedDateRange!.start) &&
            !b.scheduledDate.isAfter(_selectedDateRange!.end);
      }).toList();
    }
    if (_selectedStatusFilter != null) {
      list = list.where((b) => b.status == _selectedStatusFilter).toList();
    }
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final q = _searchQuery!.toLowerCase();
      list = list.where((b) {
        return (b.customer?.name ?? '').toLowerCase().contains(q) ||
            b.serviceType.toLowerCase().contains(q) ||
            b.id.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  // ── Helpers ──────────────────────────────────────────────

  String _fmt(double amount) => '₱${amount.toStringAsFixed(2)}';

  String _fmtDateTime(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.month}/${d.day}/${d.year} $h:$m $ap';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).abs();
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _rangeLabelShort(DateTimeRange r) {
    String fmt(DateTime d) => '${d.month}/${d.day}';
    return '${fmt(r.start)} – ${fmt(r.end)}';
  }

  // FIX: BookingStatus.scheduleProposed added to make switch exhaustive.
  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.accepted:
        return Colors.blue;
      case BookingStatus.assessment:
        return const Color(0xFFFF9500);
      case BookingStatus.inProgress:
        return const Color(0xFF5856D6);
      case BookingStatus.scheduleProposed:
        return const Color(0xFF9C27B0); // purple — schedule pending review
      case BookingStatus.scheduled:
        return const Color(0xFF007AFF); // blue — confirmed schedule
      case BookingStatus.pendingCustomerConfirmation:
        return Colors.amber; // amber — awaiting customer confirmation
      case BookingStatus.pendingArrivalConfirmation:
        return Colors
            .teal; // teal — handyman arrived, awaiting customer confirmation
    }
  }

  // FIX: scheduleProposed + scheduled + pendingCustomerConfirmation added to make switch exhaustive.
  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.assessment:
        return 'Awaiting Confirm';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.scheduleProposed:
        return 'Schedule Proposed';
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.pendingCustomerConfirmation:
        return 'Awaiting Customer';
      case BookingStatus.pendingArrivalConfirmation:
        return 'Awaiting Customer';
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  if (_isElite) _buildAnalyticsTab(),
                  if (_isPro && !_isElite) _buildProAnalyticsTab(),
                  _buildTransactionsTab(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onNavTap?.call(0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Earnings',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    Text('Everything you have earned through AYO',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13)),
                  ],
                ),
              ),
              if (_selectedDateRange != null) ...[
                GestureDetector(
                  onTap: () => setState(() => _selectedDateRange = null),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _rangeLabelShort(_selectedDateRange!),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.close_rounded,
                          color: Colors.white, size: 13),
                    ]),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: Icon(
                  Icons.calendar_today,
                  color: _selectedDateRange != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
                onPressed: _showDateRangePicker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textLight,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
        tabs: [
          const Tab(text: 'Overview'),
          if (_isPro)
            Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Analytics'),
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isElite
                        ? const Color(0xFFFF9500).withValues(alpha: 0.15)
                        : const Color(0xFF1E88E5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isElite ? 'Elite' : 'Pro',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _isElite
                            ? const Color(0xFFFF9500)
                            : const Color(0xFF1E88E5)),
                  ),
                ),
              ]),
            ),
          const Tab(text: 'Transactions'),
        ],
      ),
    );
  }

  // ── Overview Tab ─────────────────────────────────────────

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalEarningsCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildMonthlyChart(),
          const SizedBox(height: 16),
          _buildServiceBreakdownCard(),
          const SizedBox(height: 16),
          _buildRecentTransactionsCard(),
          const SizedBox(height: 16),
          if (!_isPro) _buildAnalyticsNudge(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTotalEarningsCard() {
    final growthPct = _lastMonthEarnings > 0
        ? ((_thisMonthEarnings / _lastMonthEarnings - 1) * 100)
        : (_thisMonthEarnings > 0 ? 100.0 : 0.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A7F6E), Color(0xFF1E5F4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2A7F6E).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earned through AYO',
              style: TextStyle(
                  color: Colors.white, fontSize: 14, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          Text(_fmt(_totalEarnings),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${_filteredCompleted.length} job${_filteredCompleted.length == 1 ? '' : 's'} completed on AYO',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('This Month',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_fmt(_thisMonthEarnings),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
              if (_lastMonthEarnings > 0 || _thisMonthEarnings > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Icon(
                        growthPct >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: Colors.white,
                        size: 16),
                    const SizedBox(width: 4),
                    Text(
                        '${growthPct >= 0 ? '+' : ''}${growthPct.toStringAsFixed(0)}%',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2×2 Stats Grid ───────────────────────────────────────
  // Today | Unpaid
  // Jobs  | Avg Rating
  // Replaces the old _buildStatsRow (which duplicated This Month)
  // and the _summaryItem row at the bottom of the monthly chart.

  Widget _buildStatsGrid() {
    final items = [
      _GridStatItem(
        label: 'Today',
        value: _fmt(_todayEarnings),
        icon: Icons.today_rounded,
        color: Colors.blue,
      ),
      _GridStatItem(
        label: 'Unpaid',
        value: _fmt(_pendingAmount),
        icon: Icons.pending_actions_rounded,
        color: Colors.orange,
        badge: _unpaid.isNotEmpty ? '${_unpaid.length}' : null,
      ),
      _GridStatItem(
        label: 'Jobs Done',
        value: '${_filteredCompleted.length}',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF2A7F6E),
      ),
      _GridStatItem(
        label: 'Avg Rating',
        value: _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—',
        icon: Icons.star_rounded,
        color: const Color(0xFFFF9500),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: items.map((item) => _buildGridStatCard(item)).toList(),
    );
  }

  Widget _buildGridStatCard(_GridStatItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Text(
                  item.value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: item.color),
                ),
                if (item.badge != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(item.badge!,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: item.color)),
                  ),
                ],
              ]),
              Text(item.label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Monthly Bar Chart ────────────────────────────────────

  Widget _buildMonthlyChart() {
    final months = _monthlyEarnings;

    if (months.isEmpty) {
      return _emptyCard(
        'No earnings yet',
        _filteredCompleted.isEmpty && _completed.isEmpty
            ? 'Complete your first job to see monthly earnings here.'
            : 'No data available for this period.',
        Icons.bar_chart_rounded,
      );
    }

    final recent =
        months.length > 6 ? months.sublist(months.length - 6) : months;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Monthly Earnings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5F4B))),
            TextButton(
                onPressed: _showDetailedChart, child: const Text('View All')),
          ]),
          const SizedBox(height: 16),
          // Responsive chart via LayoutBuilder
          LayoutBuilder(
            builder: (context, constraints) {
              return _MonthlyBarChart(
                months: recent,
                width: constraints.maxWidth,
                color: const Color(0xFF2A7F6E),
                fmt: _fmt,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Service Breakdown ────────────────────────────────────

  Widget _buildServiceBreakdownCard() {
    final breakdown = _serviceBreakdown;
    if (breakdown.isEmpty) {
      return _emptyCard(
        'No service data yet',
        'Earnings by service type will appear once you complete jobs.',
        Icons.pie_chart_outline_rounded,
      );
    }

    final totalAmt = breakdown.fold<double>(0, (s, b) => s + b.amount);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earnings by Service',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B))),
          const SizedBox(height: 16),
          ...breakdown.map((s) {
            final pct = totalAmt > 0 ? s.amount / totalAmt : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(children: [
                Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: Text(s.serviceType,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500))),
                  Expanded(
                      flex: 1,
                      child: Text('${s.count} job${s.count == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]))),
                  Expanded(
                      flex: 1,
                      child: Text(_fmt(s.amount),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E5F4B)))),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(s.color),
                    minHeight: 6,
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Recent Transactions ──────────────────────────────────

  Widget _buildRecentTransactionsCard() {
    final txns = _transactionBookings.take(3).toList();
    if (txns.isEmpty) {
      return _emptyCard(
        'No transactions yet',
        'Your bookings will appear here once you start accepting jobs.',
        Icons.receipt_long_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Transactions',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5F4B))),
            TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('View All')),
          ]),
          const SizedBox(height: 8),
          ...txns.map((b) => _buildTxnTile(b)),
        ],
      ),
    );
  }

  Widget _buildTxnTile(BookingEntity b) {
    final price = _effectivePrice(b);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFF2A7F6E).withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.handyman_rounded,
              color: Color(0xFF2A7F6E), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.customer?.name ?? 'Customer',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E5F4B))),
            Text(
              '${b.serviceType} • ${_timeAgo(b.scheduledDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmt(price),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor(b.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusLabel(b.status),
                style: TextStyle(
                    fontSize: 9,
                    color: _statusColor(b.status),
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }

  // ── Analytics Tab (Elite only) ───────────────────────────

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _analyticsSection(
            icon: Icons.trending_up_rounded,
            title: 'Earnings Trend',
            subtitle: 'Last 6 months',
            color: const Color(0xFF2A7F6E),
            child: _EarningsBarChart(
              months: _earningsLast6Months(),
              color: const Color(0xFF2A7F6E),
              fmt: _fmt,
            ),
          ),
          const SizedBox(height: 20),
          _analyticsSection(
            icon: Icons.star_rounded,
            title: 'Rating History',
            subtitle: 'Last 10 reviews',
            color: const Color(0xFFFF9500),
            child: _RatingLineChart(
              entries: _ratingHistory(),
              color: const Color(0xFFFF9500),
            ),
          ),
          const SizedBox(height: 20),
          _analyticsSection(
            icon: Icons.check_circle_rounded,
            title: 'Completion Rate Trend',
            subtitle: 'Last 6 months',
            color: Colors.blue,
            child: _CompletionBarChart(
              months: _completionLast6Months(),
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _analyticsSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E5F4B))),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ]),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }

  // ── Analytics data derivation ────────────────────────────

  List<_MonthlyData> _earningsLast6Months() {
    final now = DateTime.now();
    final result = <_MonthlyData>[];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final jobs = _completed.where((b) =>
          b.scheduledDate.year == m.year && b.scheduledDate.month == m.month);
      result.add(_MonthlyData(
        label: _monthLabel(m.month),
        month: m.month,
        year: m.year,
        amount: jobs.fold(0.0, (s, b) => s + _effectivePrice(b)),
        jobs: jobs.length,
      ));
    }
    return result;
  }

  List<_RatingEntry> _ratingHistory() {
    final sorted = List<ReviewEntity>.from(widget.reviews)
      ..sort((a, b) => a.createdAt == null || b.createdAt == null
          ? 0
          : a.createdAt!.compareTo(b.createdAt!));
    final slice =
        sorted.length > 10 ? sorted.sublist(sorted.length - 10) : sorted;
    return slice.asMap().entries.map((e) {
      final d = e.value.createdAt;
      return _RatingEntry(
        label: d != null ? _monthLabel(d.month) : '#${e.key + 1}',
        rating: e.value.rating.toDouble(),
      );
    }).toList();
  }

  List<_CompletionEntry> _completionLast6Months() {
    final now = DateTime.now();
    final result = <_CompletionEntry>[];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final inMonth = widget.bookings.where((b) =>
          b.scheduledDate.year == m.year && b.scheduledDate.month == m.month);
      final done =
          inMonth.where((b) => b.status == BookingStatus.completed).length;
      final cancelled =
          inMonth.where((b) => b.status == BookingStatus.cancelled).length;
      final total = done + cancelled;
      result.add(_CompletionEntry(
        label: _monthLabel(m.month),
        rate: total > 0 ? (done / total) * 100 : 0,
      ));
    }
    return result;
  }

  // ── Pro Analytics Tab (Tier 1) ───────────────────────────
  // Shows basic jobs completed count and earnings trend.
  // Rating history and completion rate trend are Elite-only.

  Widget _buildProAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _analyticsSection(
            icon: Icons.work_rounded,
            title: 'Jobs Completed',
            subtitle: 'Last 6 months',
            color: const Color(0xFF1E88E5),
            child: _JobsBarChart(
              months: _earningsLast6Months(),
              color: const Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(height: 20),
          // Elite upgrade nudge at bottom of Pro analytics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFFFF9500).withValues(alpha: 0.08),
                const Color(0xFFFF9500).withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star_rounded,
                    color: Color(0xFFFF9500), size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unlock Full Analytics',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF9500))),
                      SizedBox(height: 3),
                      Text(
                        'Upgrade to AYO Elite for earnings trends, '
                        'rating history, and completion rate insights.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMedium,
                            height: 1.4),
                      ),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Pro upgrade nudge ────────────────────────────────────

  Widget _buildAnalyticsNudge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF9500).withValues(alpha: 0.08),
          const Color(0xFFFF9500).withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.star_rounded,
              color: Color(0xFFFF9500), size: 20),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Unlock Full Analytics',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9500))),
            SizedBox(height: 3),
            Text(
              'Upgrade to AYO Elite to unlock earnings trends, '
              'rating history, and monthly completion insights.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMedium, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Transactions Tab ─────────────────────────────────────

  Widget _buildTransactionsTab() {
    final txns = _transactionBookings;
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${txns.length} Transaction${txns.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700])),
            Row(children: [
              _filterChip('Filter', Icons.filter_list, _showFilterDialog),
              const SizedBox(width: 8),
              _filterChip('Search', Icons.search, _showSearchDialog),
            ]),
          ],
        ),
      ),
      Expanded(
        child: txns.isEmpty
            ? _emptyCenterWidget(
                'No transactions found',
                widget.bookings.isEmpty
                    ? 'You have no bookings yet.'
                    : 'No jobs match the current filter.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: txns.length,
                itemBuilder: (context, i) {
                  final b = txns[i];
                  return _ExpandableTxnCard(
                    booking: b,
                    expanded: _expandedId == b.id,
                    onTap: () => setState(
                        () => _expandedId = _expandedId == b.id ? null : b.id),
                    statusColor: _statusColor(b.status),
                    statusLabel: _statusLabel(b.status),
                    effectivePrice: _effectivePrice(b),
                    fmt: _fmt,
                    fmtDateTime: _fmtDateTime,
                    timeAgo: _timeAgo,
                  )
                      .animate()
                      .fadeIn(delay: (i * 50).ms)
                      .slideY(begin: 0.06, end: 0);
                },
              ),
      ),
    ]);
  }

  Widget _filterChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ]),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────

  void _showDateRangePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _DateRangeSheet(
        onSelect: (range) {
          setState(() => _selectedDateRange = range);
          widget.onDateRangeSelected?.call(range);
        },
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Filter by Status',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5F4B))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              BookingStatus.completed,
              BookingStatus.pending,
              BookingStatus.accepted,
              BookingStatus.inProgress,
              BookingStatus.scheduleProposed,
            ].map((s) {
              return FilterChip(
                label: Text(_statusLabel(s)),
                selected: _selectedStatusFilter == s,
                onSelected: (sel) {
                  setState(() => _selectedStatusFilter = sel ? s : null);
                  Navigator.pop(context);
                },
                selectedColor: _statusColor(s).withValues(alpha: 0.2),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  void _showSearchDialog() {
    final ctrl = TextEditingController(text: _searchQuery);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Transactions'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Customer name, service, booking ID...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                setState(() => _searchQuery = null);
                Navigator.pop(context);
              },
              child: const Text('Clear')),
          ElevatedButton(
            onPressed: () {
              setState(
                  () => _searchQuery = ctrl.text.isEmpty ? null : ctrl.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A7F6E),
                foregroundColor: Colors.white),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showDetailedChart() {
    final months = _monthlyEarnings;
    final maxAmt = months.isEmpty
        ? 1.0
        : months.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Monthly Earnings Details',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5F4B))),
            const SizedBox(height: 20),
            Expanded(
              child: months.isEmpty
                  ? const Center(child: Text('No data yet.'))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: months.length,
                      itemBuilder: (context, i) {
                        final m = months[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A7F6E)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(m.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2A7F6E),
                                        fontSize: 11)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${m.jobs} job${m.jobs == 1 ? '' : 's'} completed',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: maxAmt > 0 ? m.amount / maxAmt : 0,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation(
                                          Color(0xFF2A7F6E)),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(_fmt(m.amount),
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E5F4B))),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────

  Widget _emptyCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 40, color: AppColors.textLight.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        ]),
      ),
    );
  }

  Widget _emptyCenterWidget(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long,
                size: 44, color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5)),
        ]),
      ),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Requests'},
      {'icon': Icons.monetization_on_rounded, 'label': 'Earnings'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
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
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i]['icon'] as IconData,
                          color:
                              active ? AppColors.primary : AppColors.textLight,
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
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Monthly bar chart — Overview tab (CustomPainter, responsive)
// ─────────────────────────────────────────────────────────────

class _MonthlyBarChart extends StatelessWidget {
  final List<_MonthlyData> months;
  final double width;
  final Color color;
  final String Function(double) fmt;

  const _MonthlyBarChart({
    required this.months,
    required this.width,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Chart area height: bar area + label row
    const chartH = 160.0;
    const labelH = 20.0;
    return SizedBox(
      width: width,
      height: chartH + labelH,
      child: CustomPaint(
        size: Size(width, chartH + labelH),
        painter: _MonthlyBarPainter(
          months: months,
          color: color,
          fmt: fmt,
        ),
      ),
    );
  }
}

class _MonthlyBarPainter extends CustomPainter {
  final List<_MonthlyData> months;
  final Color color;
  final String Function(double) fmt;

  const _MonthlyBarPainter({
    required this.months,
    required this.color,
    required this.fmt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    // Layout constants
    const labelH = 20.0; // bottom label row
    const topPad = 28.0; // room for value labels above bars
    const yAxisW = 52.0; // left Y-axis labels
    const gridLines = 4;

    final chartW = size.width - yAxisW;
    final chartH = size.height - labelH - topPad;
    final chartTop = topPad;
    final chartBottom = topPad + chartH;

    final maxAmt =
        months.map((m) => m.amount).fold(0.0, (a, b) => a > b ? a : b);
    // Round max up to a nice number
    final niceMax = maxAmt <= 0 ? 1000.0 : _niceMax(maxAmt);

    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    final axisLabelPainter = TextPainter(textDirection: TextDirection.ltr);

    // ── Y-axis grid lines + labels ──────────────────────────
    for (int i = 0; i <= gridLines; i++) {
      final y = chartTop + chartH * (1 - i / gridLines);
      // Grid line
      canvas.drawLine(
        Offset(yAxisW, y),
        Offset(size.width, y),
        gridPaint,
      );
      // Y label
      final val = niceMax * i / gridLines;
      final label = val >= 1000
          ? '₱${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}k'
          : '₱${val.toStringAsFixed(0)}';
      axisLabelPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
            fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
      );
      axisLabelPainter.layout();
      axisLabelPainter.paint(
        canvas,
        Offset(yAxisW - axisLabelPainter.width - 4,
            y - axisLabelPainter.height / 2),
      );
    }

    // ── Bars ────────────────────────────────────────────────
    final n = months.length;
    final slotW = chartW / n;
    final barW = (slotW * 0.55).clamp(8.0, 36.0);
    final valuePainter = TextPainter(textDirection: TextDirection.ltr);
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final maxMonth = months.reduce((a, b) => a.amount > b.amount ? a : b);

    for (int i = 0; i < n; i++) {
      final m = months[i];
      final cx = yAxisW + slotW * i + slotW / 2;
      final isPeak = m.amount == maxMonth.amount && m.month == maxMonth.month;

      // Bar height
      final barH = niceMax > 0 ? (m.amount / niceMax) * chartH : 0.0;
      final barTop = chartBottom - barH;
      final barLeft = cx - barW / 2;

      // Background track
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(barLeft, chartTop, barW, chartH),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()..color = color.withValues(alpha: 0.07),
      );

      // Filled bar
      if (m.amount > 0) {
        final gradient = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: isPeak
              ? [color.withValues(alpha: 0.75), color]
              : [color.withValues(alpha: 0.35), color.withValues(alpha: 0.6)],
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(barLeft, barTop, barW, barH),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          Paint()
            ..shader = gradient
                .createShader(Rect.fromLTWH(barLeft, barTop, barW, barH)),
        );

        // Value label above bar
        final vLabel = m.amount >= 1000
            ? '₱${(m.amount / 1000).toStringAsFixed(1)}k'
            : '₱${m.amount.toStringAsFixed(0)}';
        valuePainter.text = TextSpan(
          text: vLabel,
          style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: isPeak ? color : const Color(0xFF999999)),
        );
        valuePainter.layout();
        final labelY = (barTop - valuePainter.height - 3).clamp(0.0, barTop);
        valuePainter.paint(canvas, Offset(cx - valuePainter.width / 2, labelY));
      }

      // Month label below chart
      labelPainter.text = TextSpan(
        text: m.label,
        style: TextStyle(
            fontSize: 10,
            color: isPeak ? color : const Color(0xFF999999),
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w400),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(cx - labelPainter.width / 2, chartBottom + 6),
      );
    }
  }

  // Round up to a nice axis ceiling (e.g. 1250 → 1500, 3400 → 4000)
  double _niceMax(double value) {
    if (value <= 0) return 1000;
    final magnitude = (value).abs();
    final pow10 = (magnitude == 0)
        ? 1.0
        : (10.0.toInt().toDouble() *
            (magnitude < 1
                ? 0.1
                : magnitude < 10
                    ? 1
                    : magnitude < 100
                        ? 10
                        : magnitude < 1000
                            ? 100
                            : magnitude < 10000
                                ? 1000
                                : 10000));
    return ((magnitude / pow10).ceil() * pow10).toDouble();
  }

  @override
  bool shouldRepaint(_MonthlyBarPainter old) =>
      old.months != months || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Analytics data classes
// ─────────────────────────────────────────────────────────────

class _RatingEntry {
  final String label;
  final double rating;
  const _RatingEntry({required this.label, required this.rating});
}

class _CompletionEntry {
  final String label;
  final double rate;
  const _CompletionEntry({required this.label, required this.rate});
}

// ─────────────────────────────────────────────────────────────
// Jobs bar chart — Pro Analytics (jobs count per month)
// ─────────────────────────────────────────────────────────────

class _JobsBarChart extends StatelessWidget {
  final List<_MonthlyData> months;
  final Color color;

  const _JobsBarChart({required this.months, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasData = months.any((m) => m.jobs > 0);
    if (!hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No completed jobs yet',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        ),
      );
    }
    final total = months.fold(0, (s, m) => s + m.jobs);
    final best = months.reduce((a, b) => a.jobs > b.jobs ? a : b);
    final avg = total / months.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: 160,
          child: CustomPaint(
            size: Size(constraints.maxWidth, 160),
            painter: _JobsBarPainter(months: months, color: color),
          ),
        );
      }),
      const SizedBox(height: 14),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _stat('Total Jobs', '$total', color),
        _stat('Monthly Avg', avg.toStringAsFixed(1), color),
        _stat('Best Month', '${best.jobs} jobs', color),
      ]),
    ]);
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _JobsBarPainter extends CustomPainter {
  final List<_MonthlyData> months;
  final Color color;
  const _JobsBarPainter({required this.months, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;
    const labelH = 20.0;
    const topPad = 24.0;
    final chartH = size.height - labelH - topPad;
    final chartTop = topPad;
    final chartBottom = topPad + chartH;
    final n = months.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.55).clamp(8.0, 36.0);
    final maxJobs = months.map((m) => m.jobs).fold(0, (a, b) => a > b ? a : b);

    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartTop + chartH * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final valuePainter = TextPainter(textDirection: TextDirection.ltr);
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < n; i++) {
      final m = months[i];
      final cx = slotW * i + slotW / 2;
      final isPeak = m.jobs == maxJobs && m.jobs > 0;
      final barH = maxJobs > 0 ? (m.jobs / maxJobs) * chartH : 0.0;
      final barTop = chartBottom - barH;
      final barLeft = cx - barW / 2;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(barLeft, chartTop, barW, chartH),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()..color = color.withValues(alpha: 0.07),
      );

      if (m.jobs > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(barLeft, barTop, barW, barH),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: isPeak
                  ? [color.withValues(alpha: 0.6), color]
                  : [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.6)
                    ],
            ).createShader(Rect.fromLTWH(barLeft, barTop, barW, barH)),
        );

        valuePainter.text = TextSpan(
          text: '${m.jobs}',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isPeak ? color : const Color(0xFF999999)),
        );
        valuePainter.layout();
        final vY = (barTop - valuePainter.height - 3).clamp(0.0, barTop);
        valuePainter.paint(canvas, Offset(cx - valuePainter.width / 2, vY));
      }

      labelPainter.text = TextSpan(
        text: m.label,
        style: TextStyle(
            fontSize: 10,
            color: isPeak ? color : const Color(0xFF999999),
            fontWeight: isPeak ? FontWeight.w700 : FontWeight.w400),
      );
      labelPainter.layout();
      labelPainter.paint(
          canvas, Offset(cx - labelPainter.width / 2, chartBottom + 6));
    }
  }

  @override
  bool shouldRepaint(_JobsBarPainter old) =>
      old.months != months || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Earnings bar chart — Elite Analytics (reuses _MonthlyBarChart)
// ─────────────────────────────────────────────────────────────

class _EarningsBarChart extends StatelessWidget {
  final List<_MonthlyData> months;
  final Color color;
  final String Function(double) fmt;

  const _EarningsBarChart({
    required this.months,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = months.any((m) => m.amount > 0);
    if (!hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No completed jobs yet',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        ),
      );
    }
    final peak = months.reduce((a, b) => a.amount > b.amount ? a : b);
    final avg = months.fold(0.0, (s, m) => s + m.amount) / months.length;
    final total = months.fold(0.0, (s, m) => s + m.amount);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        return _MonthlyBarChart(
          months: months,
          width: constraints.maxWidth,
          color: color,
          fmt: fmt,
        );
      }),
      const SizedBox(height: 14),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _stat('Peak', fmt(peak.amount), color),
        _stat('Average', fmt(avg), color),
        _stat('6-Month Total', fmt(total), color),
      ]),
    ]);
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────
// Rating line chart — Elite Analytics (responsive, no overflow)
// ─────────────────────────────────────────────────────────────

class _RatingLineChart extends StatelessWidget {
  final List<_RatingEntry> entries;
  final Color color;

  const _RatingLineChart({required this.entries, required this.color});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No reviews yet',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        ),
      );
    }
    final avg = entries.fold(0.0, (s, e) => s + e.rating) / entries.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        const topPad = 26.0;
        const bottomPad = 8.0;
        const chartH = 130.0;
        return SizedBox(
          width: constraints.maxWidth,
          height: chartH,
          child: CustomPaint(
            size: Size(constraints.maxWidth, chartH),
            painter: _RatingLinePainter(
              entries: entries,
              color: color,
              topPad: topPad,
              bottomPad: bottomPad,
            ),
          ),
        );
      }),
      const SizedBox(height: 6),
      Row(
        children: entries
            .map((e) => Expanded(
                  child: Text(e.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textLight)),
                ))
            .toList(),
      ),
      const SizedBox(height: 12),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _stat('Reviews', '${entries.length}', color),
        _stat('Average', avg.toStringAsFixed(2), color),
        _stat('Latest', entries.last.rating.toStringAsFixed(1), color),
      ]),
    ]);
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _RatingLinePainter extends CustomPainter {
  final List<_RatingEntry> entries;
  final Color color;
  final double topPad;
  final double bottomPad;

  const _RatingLinePainter({
    required this.entries,
    required this.color,
    required this.topPad,
    required this.bottomPad,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    const maxRating = 5.0;
    final chartH = size.height - topPad - bottomPad;
    final spacing = size.width / (entries.length - 1);

    final points = entries
        .asMap()
        .entries
        .map((e) => Offset(
              e.key * spacing,
              topPad + chartH * (1 - e.value.rating / maxRating),
            ))
        .toList();

    // Fill
    final fill = Path()..moveTo(points.first.dx, size.height - bottomPad);
    for (final p in points) fill.lineTo(p.dx, p.dy);
    fill
      ..lineTo(points.last.dx, size.height - bottomPad)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..color = color.withValues(alpha: 0.10)
          ..style = PaintingStyle.fill);

    // Line
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cp = (points[i - 1].dx + points[i].dx) / 2;
      line.cubicTo(
          cp, points[i - 1].dy, cp, points[i].dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    // Dots + labels
    final dotFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotBg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5.5, dotBg);
      canvas.drawCircle(points[i], 4, dotFill);

      tp.text = TextSpan(
        text: entries[i].rating.toStringAsFixed(1),
        style:
            TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      );
      tp.layout();
      final labelY =
          (points[i].dy - tp.height - 7).clamp(0.0, size.height - tp.height);
      final labelX =
          (points[i].dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(labelX - 2, labelY - 1, tp.width + 4, tp.height + 2),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white,
      );
      tp.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(_RatingLinePainter old) =>
      old.entries != entries || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// Completion rate bar chart — Elite Analytics (responsive)
// ─────────────────────────────────────────────────────────────

class _CompletionBarChart extends StatelessWidget {
  final List<_CompletionEntry> months;
  final Color color;
  const _CompletionBarChart({required this.months, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasData = months.any((m) => m.rate > 0);
    if (!hasData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Not enough data yet',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        ),
      );
    }
    final avg = months.fold(0.0, (s, m) => s + m.rate) / months.length;
    final best = months.map((m) => m.rate).reduce((a, b) => a > b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: 160,
          child: CustomPaint(
            size: Size(constraints.maxWidth, 160),
            painter: _CompletionBarPainter(months: months, color: color),
          ),
        );
      }),
      const SizedBox(height: 12),
      const Divider(height: 1, color: Color(0xFFF0F0F0)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _stat('6-Month Avg', '${avg.toStringAsFixed(0)}%', color),
        _stat('This Month', '${months.last.rate.toStringAsFixed(0)}%', color),
        _stat('Best Month', '${best.toStringAsFixed(0)}%', color),
      ]),
    ]);
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _CompletionBarPainter extends CustomPainter {
  final List<_CompletionEntry> months;
  final Color color;
  const _CompletionBarPainter({required this.months, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    const labelH = 20.0;
    const topPad = 24.0;
    final chartH = size.height - labelH - topPad;
    final chartTop = topPad;
    final chartBottom = topPad + chartH;
    final n = months.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.55).clamp(8.0, 36.0);

    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartTop + chartH * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final valuePainter = TextPainter(textDirection: TextDirection.ltr);
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final bestRate = months.map((m) => m.rate).reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < n; i++) {
      final m = months[i];
      final cx = slotW * i + slotW / 2;
      final isBest = m.rate == bestRate && m.rate > 0;
      final barH = (m.rate / 100) * chartH;
      final barTop = chartBottom - barH;
      final barLeft = cx - barW / 2;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(barLeft, chartTop, barW, chartH),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        Paint()..color = color.withValues(alpha: 0.07),
      );

      if (m.rate > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(barLeft, barTop, barW, barH),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: isBest
                  ? [color.withValues(alpha: 0.6), color]
                  : [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.6)
                    ],
            ).createShader(Rect.fromLTWH(barLeft, barTop, barW, barH)),
        );

        valuePainter.text = TextSpan(
          text: '${m.rate.toStringAsFixed(0)}%',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isBest ? color : const Color(0xFF999999)),
        );
        valuePainter.layout();
        final vY = (barTop - valuePainter.height - 3).clamp(0.0, barTop);
        valuePainter.paint(canvas, Offset(cx - valuePainter.width / 2, vY));
      }

      labelPainter.text = TextSpan(
        text: m.label,
        style: TextStyle(
            fontSize: 10,
            color: isBest ? color : const Color(0xFF999999),
            fontWeight: isBest ? FontWeight.w700 : FontWeight.w400),
      );
      labelPainter.layout();
      labelPainter.paint(
          canvas, Offset(cx - labelPainter.width / 2, chartBottom + 6));
    }
  }

  @override
  bool shouldRepaint(_CompletionBarPainter old) =>
      old.months != months || old.color != color;
}

class _GridStatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;
  const _GridStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
  });
}

class _MonthlyData {
  final String label;
  final int month;
  final int year;
  final double amount;
  final int jobs;
  const _MonthlyData({
    required this.label,
    required this.month,
    required this.year,
    required this.amount,
    required this.jobs,
  });
}

class _ServiceData {
  final String serviceType;
  final int count;
  final double amount;
  final Color color;
  const _ServiceData({
    required this.serviceType,
    required this.count,
    required this.amount,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────
// Expandable transaction card
// ─────────────────────────────────────────────────────────────

class _ExpandableTxnCard extends StatelessWidget {
  final BookingEntity booking;
  final bool expanded;
  final VoidCallback onTap;
  final Color statusColor;
  final String statusLabel;
  final double effectivePrice;
  final String Function(double) fmt;
  final String Function(DateTime) fmtDateTime;
  final String Function(DateTime) timeAgo;

  const _ExpandableTxnCard({
    required this.booking,
    required this.expanded,
    required this.onTap,
    required this.statusColor,
    required this.statusLabel,
    required this.effectivePrice,
    required this.fmt,
    required this.fmtDateTime,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expanded
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: expanded
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: expanded ? 16 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A7F6E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.handyman_rounded,
                      color: Color(0xFF2A7F6E), size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.customer?.name ?? 'Customer',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.serviceType} • ${timeAgo(booking.scheduledDate)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt(effectivePrice),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5F4B))),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 9,
                            color: statusColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ]),
            ),
            if (expanded) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(children: [
                  _detailRow(Icons.calendar_today_outlined, 'Date & Time',
                      fmtDateTime(booking.scheduledDate)),
                  _detailRow(Icons.location_on_outlined, 'Address',
                      booking.address ?? 'N/A'),
                  if (booking.assessmentPrice != null &&
                      booking.assessmentPrice! > 0 &&
                      booking.priceEstimate != null &&
                      booking.assessmentPrice != booking.priceEstimate)
                    _detailRow(
                        Icons.price_change_outlined,
                        'Price (assessment)',
                        '${fmt(booking.assessmentPrice!)} (estimate was ${fmt(booking.priceEstimate!)})'),
                  _detailRow(
                      Icons.receipt_long_outlined, 'Booking ID', booking.id),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: AppColors.textLight),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark)),
            ),
          ]),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// Date range picker sheet
// ─────────────────────────────────────────────────────────────

class _DateRangeSheet extends StatelessWidget {
  final void Function(DateTimeRange) onSelect;
  const _DateRangeSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Select Date Range',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E5F4B))),
        const SizedBox(height: 16),
        _tile(
            context,
            Icons.today,
            'Today',
            DateTimeRange(
              start: DateTime(now.year, now.month, now.day),
              end: DateTime(now.year, now.month, now.day, 23, 59, 59),
            )),
        _tile(
            context,
            Icons.date_range,
            'This Week',
            DateTimeRange(
              start: now.subtract(Duration(days: now.weekday - 1)),
              end: DateTime(now.year, now.month, now.day, 23, 59, 59),
            )),
        _tile(
            context,
            Icons.calendar_month,
            'This Month',
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
            )),
      ]),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, DateTimeRange range) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2A7F6E)),
      title: Text(label),
      onTap: () {
        onSelect(range);
        Navigator.pop(context);
      },
    );
  }
}
