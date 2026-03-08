// lib/presentation/screens/customer/all_professionals_screen.dart
//
// AllProfessionalsScreen
// ─────────────────────────────────────────────────────────────
// Shows ALL verified professionals sorted by (rating × reviewCount) desc.
// Loads 10 at a time with a "Load More" button at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/widgets/shared_widgets.dart';

class AllProfessionalsScreen extends StatefulWidget {
  /// Full list of professionals passed in from the parent.
  /// This screen handles its own filtering + sorting + pagination.
  final List<ProfessionalEntity> professionals;
  final Function(ProfessionalEntity)? onProfessionalTap;
  final VoidCallback? onBack;

  const AllProfessionalsScreen({
    super.key,
    required this.professionals,
    this.onProfessionalTap,
    this.onBack,
  });

  @override
  State<AllProfessionalsScreen> createState() => _AllProfessionalsScreenState();
}

class _AllProfessionalsScreenState extends State<AllProfessionalsScreen> {
  static const int _pageSize = 10;

  int _loadedCount = _pageSize;

  // ── Sort: verified only, highest (rating * reviewCount) first ──────────
  late final List<ProfessionalEntity> _sorted = () {
    final verified = widget.professionals.where((p) => p.verified).toList();
    verified.sort((a, b) {
      final scoreA = a.rating * a.reviewCount;
      final scoreB = b.rating * b.reviewCount;
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);
      // Tiebreak: higher raw rating first
      return b.rating.compareTo(a.rating);
    });
    return verified;
  }();

  List<ProfessionalEntity> get _visible => _sorted.take(_loadedCount).toList();

  bool get _hasMore => _loadedCount < _sorted.length;

  void _loadMore() => setState(() => _loadedCount += _pageSize);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _sorted.isEmpty
                ? _buildEmpty()
                : CustomScrollView(
                    slivers: [
                      // ── Stats strip ─────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: _buildStatsStrip(),
                        ).animate().fadeIn(delay: 80.ms),
                      ),

                      // ── Professional list ────────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final pro = _visible[i];
                              return _RankedProfessionalCard(
                                rank: i + 1,
                                professional: pro,
                                onTap: () {
                                  widget.onProfessionalTap?.call(pro);
                                },
                              )
                                  .animate()
                                  .fadeIn(delay: (i * 50).ms)
                                  .slideX(begin: 0.04, end: 0);
                            },
                            childCount: _visible.length,
                          ),
                        ),
                      ),

                      // ── Load more / end indicator ────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          child: _hasMore
                              ? _buildLoadMoreButton()
                              : _buildEndIndicator(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────

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
                onTap: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
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
                    Text('Top Professionals',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text('Verified · Ranked by rating & reviews',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );

  // ── STATS STRIP ────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    final avgRating = _sorted.isEmpty
        ? 0.0
        : _sorted.map((p) => p.rating).reduce((a, b) => a + b) / _sorted.length;
    final totalReviews = _sorted.fold<int>(0, (s, p) => s + p.reviewCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.engineering_rounded, '${_sorted.length}',
              'Verified Pros', AppColors.primary),
          _divider(),
          _statItem(Icons.star_rounded, avgRating.toStringAsFixed(1),
              'Avg Rating', const Color(0xFFFFB800)),
          _divider(),
          _statItem(Icons.rate_review_rounded, '$totalReviews', 'Total Reviews',
              const Color(0xFF5856D6)),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) =>
      Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500)),
      ]);

  Widget _divider() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));

  // ── LOAD MORE ──────────────────────────────────────────────────────────

  Widget _buildLoadMoreButton() => GestureDetector(
        onTap: _loadMore,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.expand_more_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Load More  ·  Showing $_loadedCount of ${_sorted.length}',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _buildEndIndicator() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 40, height: 1, color: const Color(0xFFDDDDDD)),
          const SizedBox(width: 10),
          Text(
            'All ${_sorted.length} professionals shown',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 10),
          Container(width: 40, height: 1, color: const Color(0xFFDDDDDD)),
        ],
      );

  // ── EMPTY STATE ────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.engineering_rounded,
                    size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('No verified professionals yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text(
                'Check back soon — we\'re always adding verified handymen.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textLight, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── RANKED PROFESSIONAL CARD ──────────────────────────────────────────────────
// Extends ProfessionalCard visually with a rank badge.

class _RankedProfessionalCard extends StatelessWidget {
  final int rank;
  final ProfessionalEntity professional;
  final VoidCallback onTap;

  const _RankedProfessionalCard({
    required this.rank,
    required this.professional,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Top-3 get gold / silver / bronze tint
    final Color? rankColor = rank == 1
        ? const Color(0xFFFFB800)
        : rank == 2
            ? const Color(0xFF9E9E9E)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The base ProfessionalCard
        ProfessionalCard(
          professional: professional,
          onTap: onTap,
        ),

        // Rank badge — top-left corner
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: rankColor ?? AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: rankColor != null
                      ? rankColor.withOpacity(0.4)
                      : AppColors.primary.withOpacity(0.2),
                  width: 1.5),
              boxShadow: rankColor != null
                  ? [
                      BoxShadow(
                          color: rankColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(
                      Icons.emoji_events_rounded,
                      size: 14,
                      color:
                          rankColor != null ? Colors.white : AppColors.primary,
                    )
                  : Text(
                      '$rank',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary.withOpacity(0.8)),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
