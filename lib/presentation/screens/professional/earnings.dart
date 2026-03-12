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
  final List<BookingEntity> bookings;
  final List<ReviewEntity> reviews;
  final VoidCallback? onBack;
  final Function(DateTimeRange)? onDateRangeSelected;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const EarningsHandymanScreen({
    super.key,
    this.professionalId,
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  List<BookingEntity> get _unpaid => widget.bookings
      .where((b) =>
          b.status == BookingStatus.pending ||
          b.status == BookingStatus.accepted ||
          b.status == BookingStatus.inProgress)
      .toList();

  double get _totalEarnings =>
      _completed.fold(0.0, (s, b) => s + _effectivePrice(b));

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
    final relevant = widget.bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled)
        .length;
    if (relevant == 0) return 0;
    return (_completed.length / relevant) * 100;
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
    for (final b in _completed) {
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
    for (final b in _completed) {
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
    }
  }

  // FIX: scheduleProposed + scheduled added to make switch exhaustive.
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
                    Text('Track your income and transactions',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
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
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
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
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildSummaryBalanceCard(),
          const SizedBox(height: 20),
          _buildMonthlyChart(),
          const SizedBox(height: 20),
          _buildServiceBreakdownCard(),
          const SizedBox(height: 20),
          _buildRecentTransactionsCard(),
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
          const Text('Total Earnings',
              style: TextStyle(
                  color: Colors.white, fontSize: 14, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(_fmt(_totalEarnings),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'From ${_completed.length} completed job${_completed.length == 1 ? '' : 's'}',
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

  Widget _buildStatsRow() {
    return Row(children: [
      Expanded(
          child: _statCard(
              'Today', _fmt(_todayEarnings), Icons.today, Colors.blue)),
      const SizedBox(width: 12),
      Expanded(
          child: _statCard('This Month', _fmt(_thisMonthEarnings),
              Icons.calendar_month, const Color(0xFF2A7F6E))),
      const SizedBox(width: 12),
      Expanded(
          child: _statCard('Unpaid', _fmt(_pendingAmount),
              Icons.pending_actions, Colors.orange)),
    ]);
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E5F4B))),
        Text(title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildSummaryBalanceCard() {
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
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Earnings',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(_fmt(_totalEarnings),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5F4B))),
              const SizedBox(height: 6),
              if (_unpaid.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_unpaid.length} active job${_unpaid.length == 1 ? '' : 's'} • ${_fmt(_pendingAmount)} unpaid',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF2A7F6E).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet,
                color: Color(0xFF2A7F6E), size: 30),
          ),
        ],
      ),
    );
  }

  // ── Monthly Bar Chart ────────────────────────────────────

  Widget _buildMonthlyChart() {
    final months = _monthlyEarnings;

    if (months.isEmpty) {
      return _emptyCard(
        'No earnings yet',
        _completed.isEmpty
            ? 'Complete your first job to see monthly earnings here.'
            : 'No data available for this period.',
        Icons.bar_chart_rounded,
      );
    }

    final recent =
        months.length > 6 ? months.sublist(months.length - 6) : months;
    final maxAmt = recent.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

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
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recent.map((m) {
                final barH = maxAmt > 0 ? (m.amount / maxAmt) * 120 : 0.0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: _fmt(m.amount),
                        child: Container(
                          height: barH,
                          width: 20,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2A7F6E), Color(0xFF1E5F4B)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(m.label,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(Icons.work, '${_completed.length}', 'Total Jobs'),
              _summaryItem(
                  Icons.star,
                  _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '—',
                  'Avg Rating'),
              _summaryItem(Icons.check_circle,
                  '${_completionRate.toStringAsFixed(0)}%', 'Completion'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, size: 20, color: const Color(0xFF2A7F6E)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E5F4B))),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
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
                size: 52, color: AppColors.primary.withValues(alpha: 0.4)),
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
      {'icon': Icons.payments_rounded, 'label': 'Earnings'},
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
// Private data classes
// ─────────────────────────────────────────────────────────────

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
