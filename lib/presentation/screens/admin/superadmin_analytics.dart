// lib/presentation/screens/admin/super_admin_analytics.dart
//
// SuperAdminAnalytics — platform-wide analytics for the admin.
//
// All stats are derived from real data passed as props:
//   bookings    → List<BookingEntity>  — all platform bookings
//   professionals → List<ProfessionalEntity> — all professionals
//   reviews     → List<ReviewEntity>  — all reviews
//
// Period filter (Today / This Week / This Month / This Year) slices
// _filteredBookings and all derived stats.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class SuperAdminAnalytics extends StatefulWidget {
  final List<BookingEntity> bookings;
  final List<ProfessionalEntity> professionals;
  final List<ReviewEntity> reviews;
  final VoidCallback? onBack;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const SuperAdminAnalytics({
    super.key,
    this.bookings = const [],
    this.professionals = const [],
    this.reviews = const [],
    this.onBack,
    this.onNavTap,
    this.currentNavIndex = 2,
  });

  @override
  State<SuperAdminAnalytics> createState() => _SuperAdminAnalyticsState();
}

class _SuperAdminAnalyticsState extends State<SuperAdminAnalytics>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  String _selectedPeriod = 'This Month';
  static const _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  // Chart mode for the revenue/bookings/handymen switcher
  String _chartMode = 'Revenue';

  // ── Period filtering ────────────────────────────────────────────────────

  List<BookingEntity> get _filteredBookings {
    final now = DateTime.now();
    DateTime start;
    switch (_selectedPeriod) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        break;
      default: // This Month
        start = DateTime(now.year, now.month, 1);
    }
    return widget.bookings
        .where((b) => !b.scheduledDate.isBefore(start))
        .toList();
  }

  List<BookingEntity> get _completedBookings => _filteredBookings
      .where((b) => b.status == BookingStatus.completed)
      .toList();

  List<BookingEntity> get _activeBookings => _filteredBookings
      .where((b) =>
          b.status != BookingStatus.completed &&
          b.status != BookingStatus.cancelled)
      .toList();

  // ── Revenue helpers ─────────────────────────────────────────────────────

  double _effectivePrice(BookingEntity b) {
    final ap = b.assessmentPrice;
    return (ap != null && ap > 0) ? ap : (b.priceEstimate ?? 0.0);
  }

  double get _totalRevenue =>
      _completedBookings.fold(0.0, (s, b) => s + _effectivePrice(b));

  double get _avgOrderValue => _completedBookings.isEmpty
      ? 0
      : _totalRevenue / _completedBookings.length;

  double get _completionRate {
    final relevant = _filteredBookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled)
        .length;
    if (relevant == 0) return 0;
    return (_completedBookings.length / relevant) * 100;
  }

  // ── Monthly aggregation (last 6 months, ignores period filter) ───────────

  List<_MonthData> get _last6Months {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i), 1);
      final inMonth = widget.bookings.where((b) =>
          b.scheduledDate.year == m.year && b.scheduledDate.month == m.month);
      final completed =
          inMonth.where((b) => b.status == BookingStatus.completed);
      final revenue = completed.fold(0.0, (s, b) => s + _effectivePrice(b));
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
      return _MonthData(
        label: months[m.month - 1],
        revenue: revenue,
        bookings: inMonth.length,
        handymen: widget.professionals.length,
      );
    });
  }

  // ── Service breakdown ────────────────────────────────────────────────────

  List<_ServiceData> get _serviceBreakdown {
    final map = <String, _ServiceData>{};
    final palette = [
      const Color(0xFFFF9500),
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFF5856D6),
      const Color(0xFFFF3B30),
      AppColors.primary,
    ];
    int ci = 0;
    for (final b in _completedBookings) {
      final t = b.serviceType;
      final p = _effectivePrice(b);
      final existing = map[t];
      final color = existing?.color ?? palette[ci++ % palette.length];
      map[t] = _ServiceData(
        type: t,
        revenue: (existing?.revenue ?? 0) + p,
        bookings: (existing?.bookings ?? 0) + 1,
        color: color,
      );
    }
    final list = map.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final total = list.fold(0.0, (s, d) => s + d.revenue);
    return list
        .map((d) => _ServiceData(
              type: d.type,
              revenue: d.revenue,
              bookings: d.bookings,
              color: d.color,
              pct: total > 0 ? d.revenue / total : 0,
            ))
        .toList();
  }

  // ── Top professionals ────────────────────────────────────────────────────

  List<_TopProData> get _topPros {
    final map = <String, _TopProData>{};
    for (final b in _completedBookings) {
      final pro = b.professional;
      if (pro == null) continue;
      final p = _effectivePrice(b);
      final existing = map[pro.id];
      map[pro.id] = _TopProData(
        id: pro.id,
        name: pro.name,
        skill: pro.skills.isNotEmpty ? pro.skills.first : '',
        earnings: (existing?.earnings ?? 0) + p,
        bookings: (existing?.bookings ?? 0) + 1,
        rating: pro.rating,
      );
    }
    return (map.values.toList()
          ..sort((a, b) => b.earnings.compareTo(a.earnings)))
        .take(5)
        .toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(double v) {
    if (v >= 1000000) return '₱${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '₱${(v / 1000).toStringAsFixed(1)}k';
    return '₱${v.toStringAsFixed(0)}';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(),
          // White tab bar
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
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Reports'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildOverviewTab(), _buildReportsTab()],
            ),
          ),
        ]),
        bottomNavigationBar: _buildBottomNav(),
      ),
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
                    onTap: widget.onBack ?? () => widget.onNavTap?.call(0),
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
                        Text('Analytics',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Platform insights and statistics',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Period picker pill
                  GestureDetector(
                    onTap: _showPeriodPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_selectedPeriod,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 16),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Stats strip — 2×2
                Column(children: [
                  Row(children: [
                    _headerStat(Icons.payments_rounded, _fmt(_totalRevenue),
                        'Revenue', const Color(0xFF4ADE80)),
                    const SizedBox(width: 10),
                    _headerStat(
                        Icons.check_circle_rounded,
                        '${_completedBookings.length}',
                        'Completed',
                        const Color(0xFF60A5FA)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _headerStat(
                        Icons.autorenew_rounded,
                        '${_activeBookings.length}',
                        'Active',
                        const Color(0xFFA78BFA)),
                    const SizedBox(width: 10),
                    _headerStat(
                        Icons.engineering_rounded,
                        '${widget.professionals.length}',
                        'Professionals',
                        const Color(0xFFFBBF24)),
                  ]),
                ]),
              ],
            ),
          ),
        ),
      );

  Widget _headerStat(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 10)),
                ],
              ),
            ),
          ]),
        ),
      );

  // ── OVERVIEW TAB ─────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final months = _last6Months;
    final breakdown = _serviceBreakdown;
    final topPros = _topPros;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Key metric cards ──────────────────────────────────────
          Column(children: [
            Row(children: [
              Expanded(
                child: _metricCard(
                  title: 'Total Revenue',
                  value: _fmt(_totalRevenue),
                  sub: '${_completedBookings.length} completed jobs',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF34C759),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  title: 'Avg. Job Value',
                  value: _fmt(_avgOrderValue),
                  sub: 'Per completed booking',
                  icon: Icons.receipt_rounded,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _metricCard(
                  title: 'Completion Rate',
                  value: '${_completionRate.toStringAsFixed(0)}%',
                  sub: 'Of all closed bookings',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF5856D6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  title: 'Total Bookings',
                  value: '${_filteredBookings.length}',
                  sub: '${_activeBookings.length} currently active',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFFFF9500),
                ),
              ),
            ]),
          ]).animate().fadeIn(delay: 60.ms),

          const SizedBox(height: 20),

          // ── Monthly chart card ────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _cardTitle('6-Month Trend'),
                    // Chart mode chips
                    Row(children: [
                      _chartChip('Revenue'),
                      const SizedBox(width: 6),
                      _chartChip('Bookings'),
                      const SizedBox(width: 6),
                      _chartChip('Handymen'),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, 180),
                      painter: _BarChartPainter(
                        months: months,
                        mode: _chartMode,
                        color: _chartMode == 'Revenue'
                            ? const Color(0xFF2A7F6E)
                            : _chartMode == 'Bookings'
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF5856D6),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                // Month labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: months
                      .map((m) => Text(m.label,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textLight)))
                      .toList(),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 16),

          // ── Service breakdown ─────────────────────────────────────
          if (breakdown.isNotEmpty)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardTitle('Revenue by Service'),
                  const SizedBox(height: 14),
                  ...breakdown.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: s.color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(s.type,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textDark)),
                              ]),
                              Text(_fmt(s.revenue),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                            ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: s.pct,
                            backgroundColor: const Color(0xFFF0F0F0),
                            valueColor: AlwaysStoppedAnimation<Color>(s.color),
                            minHeight: 7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${s.bookings} bookings',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textLight)),
                              Text('${(s.pct * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: s.color)),
                            ]),
                      ]),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms)
          else
            _emptyCard(
                'No completed bookings yet',
                'Revenue by service will appear once bookings complete.',
                Icons.pie_chart_outline_rounded),

          const SizedBox(height: 16),

          // ── Top professionals ─────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle('Top Professionals'),
                const SizedBox(height: 12),
                if (topPros.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No completed bookings yet',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textLight)),
                    ),
                  )
                else
                  ...topPros.asMap().entries.map((e) {
                    final i = e.key;
                    final pro = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        // Rank
                        SizedBox(
                          width: 24,
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: i == 0
                                      ? const Color(0xFFFFB800)
                                      : AppColors.textLight)),
                        ),
                        // Avatar
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              pro.name.isNotEmpty
                                  ? pro.name[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pro.name,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                  '${pro.skill.isEmpty ? 'Handyman' : pro.skill}  ·  ${pro.bookings} jobs',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_fmt(pro.earnings),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star_rounded,
                                  size: 11, color: Color(0xFFFFB800)),
                              const SizedBox(width: 2),
                              Text(pro.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight)),
                            ]),
                          ],
                        ),
                      ]),
                    );
                  }),
              ],
            ),
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _chartChip(String label) {
    final selected = _chartMode == label;
    return GestureDetector(
      onTap: () => setState(() => _chartMode = label),
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textLight)),
      ),
    );
  }

  // ── REPORTS TAB ───────────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          const Text('Generate Reports',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _reportCard(
                title: 'Revenue Report',
                description: 'Earnings and payout breakdown',
                icon: Icons.payments_rounded,
                color: const Color(0xFF34C759),
              ),
              _reportCard(
                title: 'Handyman Report',
                description: 'Performance metrics per pro',
                icon: Icons.engineering_rounded,
                color: const Color(0xFF007AFF),
              ),
              _reportCard(
                title: 'Customer Report',
                description: 'Customer activity and spend',
                icon: Icons.people_rounded,
                color: const Color(0xFFFF9500),
              ),
              _reportCard(
                title: 'Booking Report',
                description: 'Trends, status distribution',
                icon: Icons.calendar_today_rounded,
                color: const Color(0xFF5856D6),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick stats for the current period
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle('Period Summary  ·  $_selectedPeriod'),
                const SizedBox(height: 14),
                _summaryRow('Total Bookings', '${_filteredBookings.length}'),
                _summaryRow('Completed', '${_completedBookings.length}'),
                _summaryRow('Active', '${_activeBookings.length}'),
                _summaryRow('Cancelled',
                    '${_filteredBookings.where((b) => b.status == BookingStatus.cancelled).length}'),
                _summaryRow('Total Revenue', _fmt(_totalRevenue)),
                _summaryRow('Avg. Job Value', _fmt(_avgOrderValue)),
                _summaryRow('Completion Rate',
                    '${_completionRate.toStringAsFixed(1)}%'),
                _summaryRow('Active Professionals',
                    '${widget.professionals.where((p) => p.available).length}'),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMedium)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ],
        ),
      );

  Widget _reportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) =>
      GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$title — coming soon'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 3),
              Text(description,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textLight),
                  maxLines: 2),
            ],
          ),
        ),
      );

  // ── Shared card widgets ───────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
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
        child: child,
      );

  Widget _cardTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark));

  Widget _metricCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 1),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            Text(sub,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _emptyCard(String title, String sub, IconData icon) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: AppColors.textLight.withOpacity(0.35)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]),
      );

  // ── Period picker sheet ───────────────────────────────────────────────────

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Period',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ),
          ),
          const SizedBox(height: 8),
          ..._periods.map((p) {
            final selected = _selectedPeriod == p;
            return InkWell(
              onTap: () {
                setState(() => _selectedPeriod = p);
                Navigator.pop(context);
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.12)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      p == 'Today'
                          ? Icons.today_rounded
                          : p == 'This Week'
                              ? Icons.date_range_rounded
                              : p == 'This Month'
                                  ? Icons.calendar_month_rounded
                                  : Icons.calendar_today_rounded,
                      size: 18,
                      color: selected ? AppColors.primary : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(p,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textDark)),
                  ),
                  if (selected)
                    const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 18),
                ]),
              ),
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ]),
      ),
    );
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

// ── Data models ───────────────────────────────────────────────────────────────

class _MonthData {
  final String label;
  final double revenue;
  final int bookings;
  final int handymen;
  const _MonthData({
    required this.label,
    required this.revenue,
    required this.bookings,
    required this.handymen,
  });
}

class _ServiceData {
  final String type;
  final double revenue;
  final int bookings;
  final Color color;
  final double pct;
  const _ServiceData({
    required this.type,
    required this.revenue,
    required this.bookings,
    required this.color,
    this.pct = 0,
  });
}

class _TopProData {
  final String id;
  final String name;
  final String skill;
  final double earnings;
  final int bookings;
  final double rating;
  const _TopProData({
    required this.id,
    required this.name,
    required this.skill,
    required this.earnings,
    required this.bookings,
    required this.rating,
  });
}

// ── Bar chart painter ─────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<_MonthData> months;
  final String mode;
  final Color color;

  const _BarChartPainter({
    required this.months,
    required this.mode,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty) return;

    const topPad = 20.0;
    const bottomPad = 4.0;
    final chartH = size.height - topPad - bottomPad;
    final n = months.length;
    final slotW = size.width / n;
    final barW = (slotW * 0.55).clamp(8.0, 32.0);

    double maxVal = 0;
    for (final m in months) {
      double v = mode == 'Revenue'
          ? m.revenue
          : mode == 'Bookings'
              ? m.bookings.toDouble()
              : m.handymen.toDouble();
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 1;

    final gridPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;

    // Grid lines
    for (int i = 0; i <= 3; i++) {
      final y = topPad + chartH * (1 - i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final valuePainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < n; i++) {
      final m = months[i];
      double val = mode == 'Revenue'
          ? m.revenue
          : mode == 'Bookings'
              ? m.bookings.toDouble()
              : m.handymen.toDouble();

      final cx = slotW * i + slotW / 2;
      final barH = (val / maxVal) * chartH;
      final barTop = topPad + chartH - barH;
      final barLeft = cx - barW / 2;

      // Track
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(barLeft, topPad, barW, chartH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = color.withOpacity(0.07),
      );

      // Bar
      if (val > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(barLeft, barTop, barW, barH),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color.withOpacity(0.5), color],
            ).createShader(Rect.fromLTWH(barLeft, barTop, barW, barH)),
        );

        // Value label
        String vLabel;
        if (mode == 'Revenue') {
          vLabel = val >= 1000
              ? '₱${(val / 1000).toStringAsFixed(0)}k'
              : '₱${val.toStringAsFixed(0)}';
        } else {
          vLabel = '${val.toInt()}';
        }
        valuePainter.text = TextSpan(
          text: vLabel,
          style:
              TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color),
        );
        valuePainter.layout();
        final vY = (barTop - valuePainter.height - 2).clamp(0.0, barTop);
        valuePainter.paint(canvas, Offset(cx - valuePainter.width / 2, vY));
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.months != months || old.mode != mode || old.color != color;
}
