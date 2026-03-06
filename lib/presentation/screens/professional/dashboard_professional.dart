// lib/presentation/screens/professional/dashboard_professional.dart
//
// ProfessionalDashboardScreen — MVP dashboard for Handyman (Professional) role.
//
// Shows:
//   • Header with name, verified badge, availability toggle
//   • Stats row: earnings, total jobs, completion rate
//   • Quick-action menu cards (Booking Requests, Booking History, Earnings Summary)
//   • Ratings Overview card (avg rating, star breakdown bars, total jobs, completion %)
//
// Key props:
//   user              → UserEntity?                          — logged-in user
//   professional      → ProfessionalEntity?                  — professional profile data
//   bookings          → List<BookingEntity>                  — all bookings for this pro
//   onUpdateStatus    → Function(BookingEntity, BookingStatus)? — accept/decline/complete a booking
//   onViewRequests    → VoidCallback?                        — "Booking Requests" tap
//   onViewHistory     → VoidCallback?                        — "Booking History" tap
//   onViewEarnings    → VoidCallback?                        — "Earnings Summary" tap
//   onToggleAvailability → Function(bool)?                   — availability switch changed
//   onNavTap          → Function(int)?                       — bottom nav (0=Dashboard,1=Requests,2=Earnings,3=Profile)
//   currentNavIndex   → int                                  — active nav tab, default 0

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  final UserEntity? user;
  final ProfessionalEntity? professional;
  final List<BookingEntity> bookings;
  final Function(BookingEntity, BookingStatus)? onUpdateStatus;
  final VoidCallback? onViewRequests;
  final VoidCallback? onViewHistory;
  final VoidCallback? onViewEarnings;
  final Function(bool)? onToggleAvailability;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const ProfessionalDashboardScreen({
    super.key,
    this.user,
    this.professional,
    this.bookings = const [],
    this.onUpdateStatus,
    this.onViewRequests,
    this.onViewHistory,
    this.onViewEarnings,
    this.onToggleAvailability,
    this.onNavTap,
    this.currentNavIndex = 0,
  });

  @override
  State<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends State<ProfessionalDashboardScreen> {
  bool _available = true;

  @override
  void initState() {
    super.initState();
    _available = widget.professional?.available ?? true;
  }

  // ── Derived stats ─────────────────────────────────────────
  int get _pendingCount =>
      widget.bookings.where((b) => b.status == BookingStatus.pending).length;

  int get _completedCount =>
      widget.bookings.where((b) => b.status == BookingStatus.completed).length;

  double get _totalEarnings => widget.bookings
      .where((b) => b.status == BookingStatus.completed)
      .fold(0.0, (sum, b) => sum + (b.priceEstimate ?? 0));

  double get _completionRate {
    final total = widget.bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled)
        .length;
    if (total == 0) return 0;
    return (_completedCount / total) * 100;
  }

  double get _avgRating => widget.professional?.rating ?? 0.0;
  int get _totalJobs => widget.professional?.reviewCount ?? _completedCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildStatsRow(),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
          ),
          if (_pendingCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildPendingBanner(),
              ).animate().fadeIn(delay: 200.ms),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _buildMenuCards(),
            ).animate().fadeIn(delay: 250.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: _buildRatingsCard(),
            ).animate().fadeIn(delay: 320.ms),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = widget.user?.name ?? 'Professional';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    final verified = widget.professional?.verified ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 50,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.construction_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Fixify',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                      ]),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Pro info row
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34C759), Color(0xFF1A5C43)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            initials.isNotEmpty ? initials : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF34C759)
                                            .withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          color: Color(0xFF34C759), size: 11),
                                      SizedBox(width: 3),
                                      Text('Verified',
                                          style: TextStyle(
                                              color: Color(0xFF34C759),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              widget.professional?.skills.isNotEmpty == true
                                  ? widget.professional!.skills
                                      .map((s) =>
                                          s[0].toUpperCase() + s.substring(1))
                                      .join(' · ')
                                  : 'Handyman',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Availability toggle
                      Column(
                        children: [
                          Switch(
                            value: _available,
                            onChanged: (v) {
                              setState(() => _available = v);
                              widget.onToggleAvailability?.call(v);
                            },
                            activeColor: const Color(0xFF34C759),
                            activeTrackColor:
                                const Color(0xFF34C759).withOpacity(0.3),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                          ),
                          Text(
                            _available ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: _available
                                  ? const Color(0xFF34C759)
                                  : Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.04, end: 0);
  }

  // ── STATS ROW ─────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(
          label: 'Earnings',
          value: '₱${_totalEarnings.toStringAsFixed(0)}',
          icon: Icons.payments_rounded,
          color: const Color(0xFF34C759),
        ),
        const SizedBox(width: 12),
        _statCard(
          label: 'Total Jobs',
          value: '$_totalJobs',
          icon: Icons.work_rounded,
          color: const Color(0xFF007AFF),
        ),
        const SizedBox(width: 12),
        _statCard(
          label: 'Completion',
          value: '${_completionRate.toStringAsFixed(0)}%',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF5856D6),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── PENDING BANNER ────────────────────────────────────────

  Widget _buildPendingBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: Color(0xFFFF9500), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$_pendingCount New Request${_pendingCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF9500))),
                    const Text('Respond before they book someone else',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onViewRequests,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('View',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MENU CARDS ────────────────────────────────────────────

  Widget _buildMenuCards() {
    return Column(
      children: [
        _menuCard(
          icon: Icons.calendar_month_rounded,
          title: 'Booking Requests',
          subtitle: 'View and accept new service requests',
          badge: _pendingCount > 0 ? '$_pendingCount' : null,
          badgeColor: const Color(0xFFFF3B30),
          onTap: widget.onViewRequests,
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.history_rounded,
          title: 'Booking History',
          subtitle: 'View your past and ongoing services',
          badge: widget.bookings
                  .where((b) => b.status == BookingStatus.inProgress)
                  .isNotEmpty
              ? 'Ongoing'
              : null,
          badgeColor: const Color(0xFF007AFF),
          onTap: widget.onViewHistory,
        ),
        const SizedBox(height: 12),
        _menuCard(
          icon: Icons.monetization_on_rounded,
          title: 'Earnings Summary',
          subtitle: 'View your earnings and job history',
          onTap: widget.onViewEarnings,
        ),
      ],
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor ?? AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  // ── RATINGS CARD ──────────────────────────────────────────

  Widget _buildRatingsCard() {
    // Mock distribution based on avg (real app would use actual review data)
    final avg = _avgRating.clamp(0.0, 5.0);
    final bars = _mockStarDistribution(avg, _totalJobs);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ratings Overview',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 20),
          Row(
            children: [
              // Big score
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFF9500),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('out of 5',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
              ),
              const SizedBox(width: 20),
              // Star bars
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final star = 5 - i;
                    final pct = bars[star] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('$star ★',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF9500)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: Color(0xFFEEEEEE)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ratingStatItem(avg.toStringAsFixed(1), 'Average Rating',
                  const Color(0xFFFF9500)),
              _ratingStatItem('$_totalJobs', 'Total Jobs', AppColors.primary),
              _ratingStatItem('${_completionRate.toStringAsFixed(0)}%',
                  'Completion', const Color(0xFF34C759)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  /// Generates a plausible star distribution from avg rating
  Map<int, double> _mockStarDistribution(double avg, int total) {
    if (total == 0) return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    final fiveW = (avg - 1) / 4;
    final oneW = 1 - fiveW;
    return {
      5: (fiveW * 0.7).clamp(0, 1),
      4: (fiveW * 0.5).clamp(0, 1),
      3: 0.15,
      2: (oneW * 0.08).clamp(0, 1),
      1: (oneW * 0.05).clamp(0, 1),
    };
  }

  // ── BOTTOM NAV ────────────────────────────────────────────

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
              color: Colors.black.withOpacity(0.08),
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
                        ? AppColors.primary.withOpacity(0.1)
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
