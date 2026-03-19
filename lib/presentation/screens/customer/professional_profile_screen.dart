// lib/presentation/screens/customer/professional_profile_screen.dart
//
// Redesigned — consistent with app design rules:
//   • No emojis in info cards
//   • No border-left accents
//   • Clean white card sections
//   • Verified badge shown on header for all tiers
//   • Tier badge shown alongside verified badge for Pro/Elite

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/shared_widgets.dart';

class ProfessionalProfileScreen extends StatefulWidget {
  final ProfessionalEntity professional;
  final List<ReviewEntity> reviews;
  final Function(String serviceType)? onBookNow;
  final VoidCallback? onBack;

  const ProfessionalProfileScreen({
    super.key,
    required this.professional,
    this.reviews = const [],
    this.onBookNow,
    this.onBack,
  });

  @override
  State<ProfessionalProfileScreen> createState() =>
      _ProfessionalProfileScreenState();
}

class _ProfessionalProfileScreenState extends State<ProfessionalProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ProfessionalEntity _pro;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pro = widget.professional;
  }

  @override
  void didUpdateWidget(ProfessionalProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.professional != oldWidget.professional) {
      setState(() => _pro = widget.professional);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _callPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $phone'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = _pro;
    final tier = pro.effectiveTier;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(pro, tier),
              ),

              // ── Stat row ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildStatRow(pro),
                ).animate().fadeIn(delay: 150.ms),
              ),

              // ── Skills ────────────────────────────────────────────────────
              if (pro.skills.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _sectionCard(
                      title: 'Skills',
                      icon: Icons.build_rounded,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: pro.skills.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _cap(skill),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ),

              // ── About / Bio ───────────────────────────────────────────────
              if (pro.bio != null && pro.bio!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _sectionCard(
                      title: 'About',
                      icon: Icons.person_outline_rounded,
                      child: Text(
                        pro.bio!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                ),

              // ── Price range ───────────────────────────────────────────────
              if (pro.priceRange != null && pro.priceRange!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _sectionCard(
                      title: 'Rate',
                      icon: Icons.payments_rounded,
                      child: Text(
                        pro.priceRange!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 280.ms),
                ),

              // ── Reviews header ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: Color(0xFFFFB800)),
                    const SizedBox(width: 7),
                    Text(
                      'Reviews (${widget.reviews.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ]),
                ).animate().fadeIn(delay: 300.ms),
              ),

              // ── Reviews list ──────────────────────────────────────────────
              widget.reviews.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.rate_review_outlined,
                                size: 36,
                                color: AppColors.textLight.withOpacity(0.4)),
                            const SizedBox(height: 10),
                            const Text('No reviews yet',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.textLight)),
                          ]),
                        ),
                      ).animate().fadeIn(delay: 320.ms),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _buildReviewCard(widget.reviews[i])
                              .animate()
                              .fadeIn(delay: (320 + i * 40).ms),
                          childCount: widget.reviews.length,
                        ),
                      ),
                    ),
            ],
          ),

          // ── Floating action bar ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundLight.withOpacity(0),
                    AppColors.backgroundLight,
                  ],
                ),
              ),
              child: Row(children: [
                if (pro.phone != null && pro.phone!.trim().isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _callPhone(pro.phone!),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF34C759).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pro.skills.isEmpty
                        ? null
                        : () => widget.onBookNow?.call(pro.skills.first),
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: const Text('Book This Professional'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ProfessionalEntity pro, int tier) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // Back + share row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
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
              const Spacer(),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share_rounded,
                    color: Colors.white, size: 18),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.25), width: 2.5),
                ),
                child: pro.avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(pro.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarInitial(pro.name)),
                      )
                    : _avatarInitial(pro.name),
              ),
              // Availability dot
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: pro.available
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Name
          Text(
            pro.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),

          // Badges row — Verified + Tier
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (pro.verified) ...[
              VerifiedBadge(isVerified: true, small: true),
            ],
            if (tier >= 1) ...[
              const SizedBox(width: 6),
              _TierPill(tier: tier),
            ],
          ]),

          const SizedBox(height: 10),

          // City
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.location_on_rounded,
                size: 13,
                color: Colors.white.withOpacity(pro.city != null ? 0.6 : 0.35)),
            const SizedBox(width: 4),
            Text(
              pro.city ?? 'Location not set',
              style: TextStyle(
                color: Colors.white.withOpacity(pro.city != null ? 0.6 : 0.35),
                fontSize: 12,
                fontStyle:
                    pro.city != null ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Rating stars
          RatingStars(rating: pro.rating, size: 17),

          // Phone pill
          if (pro.phone != null && pro.phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _callPhone(pro.phone!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF34C759).withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.phone_rounded,
                      color: Color(0xFF34C759), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    pro.phone!,
                    style: const TextStyle(
                        color: Color(0xFF34C759),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ]),
      ),
    ).animate().fadeIn().slideY(begin: -0.03, end: 0);
  }

  Widget _avatarInitial(String name) => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: const TextStyle(
              color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
        ),
      );

  // ── STAT ROW ──────────────────────────────────────────────────────────────

  Widget _buildStatRow(ProfessionalEntity pro) => Container(
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
            _statItem(Icons.star_rounded, '${pro.rating.toStringAsFixed(1)}',
                'Rating', const Color(0xFFFFB800)),
            _vDivider(),
            _statItem(Icons.rate_review_rounded, '${pro.reviewCount}',
                'Reviews', const Color(0xFF5856D6)),
            _vDivider(),
            _statItem(Icons.workspace_premium_rounded,
                '${pro.yearsExperience}yr', 'Experience', AppColors.primary),
          ],
        ),
      );

  Widget _statItem(IconData icon, String value, String label, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500)),
      ]);

  Widget _vDivider() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));

  // ── SECTION CARD ──────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  // ── REVIEW CARD ───────────────────────────────────────────────────────────

  Widget _buildReviewCard(ReviewEntity review) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.customerName?.isNotEmpty == true
                        ? review.customerName![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName ?? 'Anonymous',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    RatingStars(rating: review.rating.toDouble(), size: 12),
                  ],
                ),
              ),
              Text(
                _formatDate(review.createdAt),
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ]),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.comment!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMedium, height: 1.5),
              ),
            ],
          ],
        ),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── Tier pill (used in profile header) ───────────────────────────────────────

class _TierPill extends StatelessWidget {
  final int tier;
  const _TierPill({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isElite = tier >= 2;
    final color = isElite ? const Color(0xFFFF9500) : const Color(0xFF007AFF);
    final label = isElite ? 'Elite' : 'Pro';
    final icon = isElite ? Icons.star_rounded : Icons.workspace_premium_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ============================================================
// BOOKING SCREEN — unchanged from original
// ============================================================

class BookingScreen extends StatefulWidget {
  final ProfessionalEntity professional;
  final Function(
          DateTime date, String serviceType, String? notes, String? address)?
      onConfirmBooking;
  final VoidCallback? onBack;

  const BookingScreen({
    super.key,
    required this.professional,
    this.onConfirmBooking,
    this.onBack,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _selectedService = 'plumbing';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final pro = widget.professional;
    final estimatedPrice = _getEstimatedPrice();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF082218), Color(0xFF0F3D2E)],
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      children: [
                        Row(children: [
                          GestureDetector(
                            onTap: widget.onBack,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Book Service',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      pro.name.isNotEmpty ? pro.name[0] : 'P',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(pro.name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.star_rounded,
                                            color: Color(0xFFFFB800), size: 13),
                                        Text(' ${pro.rating}',
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                                fontSize: 12)),
                                      ]),
                                    ],
                                  ),
                                ),
                                if (pro.verified)
                                  const VerifiedBadge(isVerified: true),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text('Service Type',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: pro.skills.map((skill) {
                      final selected = _selectedService == skill;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedService = skill),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFE0E0E0),
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          AppColors.primary.withOpacity(0.25),
                                      blurRadius: 10,
                                    )
                                  ]
                                : [],
                          ),
                          child: Text(
                            _cap(skill),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textMedium,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Schedule Date & Time',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_rounded,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textLight)),
                                    Text(
                                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ]),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.access_time_rounded,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 10),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Time',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textLight)),
                                    Text(
                                      _selectedTime.format(context),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ]),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  FixifyTextField(
                    controller: _addressController,
                    hint: 'Enter your address',
                    label: 'Service Address',
                    prefixIcon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 20),
                  FixifyTextField(
                    controller: _notesController,
                    hint: 'Describe the issue or any details...',
                    label: 'Notes (Optional)',
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF082218), Color(0xFF1A5C43)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service Fee',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 13)),
                            Text(estimatedPrice,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white.withOpacity(0.2)),
                      ),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Estimate',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            Text(_getTotalPrice(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20)),
                          ]),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _handleBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Confirm Booking',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time =
        await showTimePicker(context: context, initialTime: _selectedTime);
    if (time != null) setState(() => _selectedTime = time);
  }

  String _getEstimatedPrice() {
    final pro = widget.professional;
    if (pro.priceMin != null && pro.priceMax != null) {
      return '₱${pro.priceMin!.toInt()} – ₱${pro.priceMax!.toInt()}';
    }
    return 'TBD';
  }

  String _getTotalPrice() {
    final pro = widget.professional;
    if (pro.priceMin != null) return '₱${pro.priceMin!.toInt()}+';
    return 'TBD';
  }

  void _handleBooking() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isLoading = false);
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    widget.onConfirmBooking?.call(
      scheduledDateTime,
      _selectedService,
      _notesController.text.isEmpty ? null : _notesController.text,
      _addressController.text.isEmpty ? null : _addressController.text,
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
