// lib/presentation/screens/professional/reviews_professional.dart
//
// ProfessionalReviewsScreen — All reviews received by the handyman.
//
// Shows:
//   • Header with avg rating summary + total reviews
//   • Filter tabs: All / 5★ / 4★ / 3★ / ≤2★
//   • Each card: customer initials, star rating, comment, service type, date
//
// Props:
//   reviews         → List<ReviewEntity>
//   professional    → ProfessionalEntity?
//   onBack          → VoidCallback?
//   onNavTap        → Function(int)?
//   currentNavIndex → int

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class ProfessionalReviewsScreen extends StatefulWidget {
  final List<ReviewEntity> reviews;
  final ProfessionalEntity? professional;
  final VoidCallback? onBack;
  final Function(int)? onNavTap;
  final int currentNavIndex;
  final Future<void> Function()? onRefresh;

  const ProfessionalReviewsScreen({
    super.key,
    this.reviews = const [],
    this.professional,
    this.onBack,
    this.onNavTap,
    this.currentNavIndex = 0,
    this.onRefresh,
  });

  @override
  State<ProfessionalReviewsScreen> createState() =>
      _ProfessionalReviewsScreenState();
}

class _ProfessionalReviewsScreenState extends State<ProfessionalReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Derived stats ─────────────────────────────────────────

  double get _avgRating {
    if (widget.reviews.isEmpty) return 0.0;
    final total = widget.reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / widget.reviews.length;
  }

  /// Real star distribution — fraction (0.0–1.0) for each star level.
  Map<int, double> get _starDistribution {
    if (widget.reviews.isEmpty) {
      return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    }
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in widget.reviews) {
      counts[r.rating.clamp(1, 5)] = (counts[r.rating.clamp(1, 5)] ?? 0) + 1;
    }
    final total = widget.reviews.length;
    return counts.map((star, count) => MapEntry(star, count / total));
  }

  List<ReviewEntity> _filtered(int? star) {
    if (star == null) return widget.reviews;
    if (star == 2) {
      // "≤2★" tab
      return widget.reviews.where((r) => r.rating <= 2).toList();
    }
    return widget.reviews.where((r) => r.rating == star).toList();
  }

  int _countFor(int? star) => _filtered(star).length;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildList(null), // All
                  _buildList(5), // 5★
                  _buildList(4), // 4★
                  _buildList(3), // 3★
                  _buildList(2), // ≤2★
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() {
    final avg = _avgRating;
    final dist = _starDistribution;
    final total = widget.reviews.length;

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
          child: Column(
            children: [
              // Top row — back + title
              Row(children: [
                GestureDetector(
                  onTap: widget.onBack,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Reviews',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '$total review${total == 1 ? '' : 's'} received',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Avg rating badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFF9500), size: 15),
                    const SizedBox(width: 4),
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Color(0xFFFF9500),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ]),
                ),
              ]),

              if (total > 0) ...[
                const SizedBox(height: 20),
                // Rating summary card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(children: [
                    // Big avg number
                    Column(children: [
                      Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) {
                          final filled = i < avg.round();
                          return Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFFF9500),
                            size: 14,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$total total',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11),
                      ),
                    ]),
                    const SizedBox(width: 20),
                    // Star bars — REAL data
                    Expanded(
                      child: Column(
                        children: List.generate(5, (i) {
                          final star = 5 - i;
                          final pct = dist[star] ?? 0.0;
                          final count = _countFor(star == 2 ? null : star);
                          final barCount =
                              star <= 2 ? _countFor(2) : _countFor(star);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              Text('$star',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.6),
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 4),
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFF9500), size: 10),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: star <= 2
                                        ? (dist[1]! + dist[2]!).clamp(0.0, 1.0)
                                        : pct,
                                    minHeight: 6,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.15),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Color(0xFFFF9500)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${star <= 2 ? _countFor(2) : barCount}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.6)),
                              ),
                            ]),
                          );
                        }),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────

  Widget _buildTabBar() => Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
          tabs: [
            Tab(text: 'All (${widget.reviews.length})'),
            Tab(text: '5★ (${_countFor(5)})'),
            Tab(text: '4★ (${_countFor(4)})'),
            Tab(text: '3★ (${_countFor(3)})'),
            Tab(text: '≤2★ (${_countFor(2)})'),
          ],
        ),
      );

  // ── LIST ──────────────────────────────────────────────────

  Widget _buildList(int? starFilter) {
    final list = _filtered(starFilter);
    if (list.isEmpty) return _empty(starFilter);
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _ReviewCard(review: list[i])
            .animate()
            .fadeIn(delay: (i * 50).ms)
            .slideY(begin: 0.06, end: 0),
      ),
    );
  }

  Widget _empty(int? starFilter) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_outline_rounded,
                  size: 44, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              starFilter == null
                  ? 'No reviews yet'
                  : 'No ${starFilter <= 2 ? '≤2' : '$starFilter'}★ reviews',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Reviews from completed bookings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ]),
        ),
      );

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
                  duration: 200.ms,
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

// ── Review Card ────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewEntity review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name = review.customerName ?? 'Customer';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row — avatar + name + stars + date
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryLight,
                      AppColors.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Stars
                    Row(
                      children: List.generate(
                          5,
                          (i) => Icon(
                                i < review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: const Color(0xFFFF9500),
                                size: 15,
                              )),
                    ),
                  ],
                ),
              ),
              // Date
              Text(
                _formatDate(review.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ]),

            // Comment
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '"${review.comment}"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'No comment left.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight.withOpacity(0.7),
                    fontStyle: FontStyle.italic),
              ),
            ],

            // Rating label chip
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _ratingColor(review.rating).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ratingLabel(review.rating),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ratingColor(review.rating),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  String _ratingLabel(int r) {
    switch (r) {
      case 5:
        return 'Excellent 🌟';
      case 4:
        return 'Good 😊';
      case 3:
        return 'Average 🙂';
      case 2:
        return 'Poor 😐';
      default:
        return 'Very Poor 😞';
    }
  }

  Color _ratingColor(int r) {
    if (r >= 4) return AppColors.success;
    if (r == 3) return AppColors.warning;
    return AppColors.error;
  }
}
