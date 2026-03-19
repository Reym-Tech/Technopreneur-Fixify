// lib/presentation/screens/customer/all_professionals_screen.dart
//
// AllProfessionalsScreen
// ─────────────────────────────────────────────────────────────
// Shows ALL verified professionals sorted by (rating × reviewCount) desc.
// Fetches 10 at a time directly from Supabase (server-side pagination) so
// the full professionals table is never loaded into memory at once.
//
// Pagination strategy:
//   • On open  → fetch page 0.
//   • Search / skill change → reset to page 0, re-fetch.
//   • "Load More" tapped → fetch next page, append to _items.
//   • _hasMore becomes false when the last page returned < _pageSize rows.
//
// Tour:
//   • Runs once on first open (kExploreTourSeenKey not set).
//   • Can be replayed via Profile → App Tour (clears kExploreTourSeenKey).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/supabase_datasource.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/widgets/shared_widgets.dart';
import 'package:fixify/presentation/screens/customer/customer_tour_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class AllProfessionalsScreen extends StatefulWidget {
  /// Data source injected by the Controller (main.dart).
  /// The screen owns its own fetch lifecycle — no pre-loaded list needed.
  final SupabaseDataSource ds;
  final Function(ProfessionalEntity)? onProfessionalTap;
  final VoidCallback? onBack;
  final int currentNavIndex;
  final Function(int)? onNavTap;

  const AllProfessionalsScreen({
    super.key,
    required this.ds,
    this.onProfessionalTap,
    this.onBack,
    this.currentNavIndex = 1,
    this.onNavTap,
  });

  @override
  State<AllProfessionalsScreen> createState() => _AllProfessionalsScreenState();
}

class _AllProfessionalsScreenState extends State<AllProfessionalsScreen> {
  static const int _pageSize = 10;

  // ── Pagination state ────────────────────────────────────────────────────
  final List<ProfessionalEntity> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // ── Filter / search state ───────────────────────────────────────────────
  String _search = '';
  String _selectedSkill = 'All';
  final _searchCtrl = TextEditingController();

  // ── Stats ───────────────────────────────────────────────────────────────
  int _totalCount = 0;

  // ── Tour ────────────────────────────────────────────────────────────────
  final _keys = CustomerTourKeys.instance;
  bool _tourScheduled = false;
  late BuildContext _showcaseContext;
  // Stable inner keys for targets that rebuild frequently.
  final _searchInnerKey = GlobalKey(debugLabel: 'explore_search_inner');
  final _skillFilterInnerKey =
      GlobalKey(debugLabel: 'explore_skill_filter_inner');

  static const _skillFilters = [
    {'label': 'All', 'icon': Icons.grid_view_rounded},
    {'label': 'Plumber', 'icon': Icons.water_drop_rounded},
    {'label': 'Electrician', 'icon': Icons.electrical_services_rounded},
    {'label': 'Technician', 'icon': Icons.kitchen_rounded},
    {'label': 'Carpenter', 'icon': Icons.handyman_rounded},
    {'label': 'Masonry', 'icon': Icons.format_paint_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPage(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Fetch helpers ───────────────────────────────────────────────────────

  Future<void> _fetchPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _items.clear();
        _page = 0;
        _hasMore = true;
        _totalCount = 0;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final skill = _selectedSkill == 'All' ? null : _selectedSkill;
      final search = _search.trim().isEmpty ? null : _search.trim();

      // Fetch the page and the total count in parallel on reset.
      final futures = <Future>[
        widget.ds.getProfessionalsPaged(
          page: reset ? 0 : _page,
          pageSize: _pageSize,
          skill: skill,
          search: search,
        ),
        if (reset) widget.ds.getProfessionalsCount(skill: skill),
      ];

      final results = await Future.wait(futures);
      if (!mounted) return;

      final page = results[0] as List;
      final newItems = page
          .map((m) => (m as dynamic).toEntity() as ProfessionalEntity)
          .toList();

      setState(() {
        if (reset) {
          _totalCount = results.length > 1 ? results[1] as int : 0;
          _page = 1;
        } else {
          _page += 1;
        }
        _items.addAll(newItems);
        _hasMore = newItems.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      debugPrint('[AllProfessionalsScreen] fetch error: $e');
    }
  }

  void _onSearchChanged(String v) {
    _search = v;
    _fetchPage(reset: true);
  }

  void _onSkillSelected(String skill) {
    if (_selectedSkill == skill) return;
    _selectedSkill = skill;
    _fetchPage(reset: true);
  }

  // ── Derived stats from fetched items ────────────────────────────────────
  int get _availableCount => _items.where((p) => p.available).length;
  int get _totalReviews => _items.fold(0, (s, p) => s + p.reviewCount);

  // ── Tour helpers ─────────────────────────────────────────────────────────

  void _startTour(BuildContext showcaseContext) {
    ShowCaseWidget.of(showcaseContext)
        .startShowCase(_keys.exploreOrderedKeys());
  }

  Future<void> _markTourSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kExploreTourSeenKey, true);
    } catch (e) {
      debugPrint('[ExploreTour] Could not write prefs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: _markTourSeen,
      onComplete: (_, __) {},
      enableAutoScroll: true,
      builder: (showcaseContext) {
        _showcaseContext = showcaseContext;
        if (!_tourScheduled) {
          _tourScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            try {
              final prefs = await SharedPreferences.getInstance();
              final seen = prefs.getBool(kExploreTourSeenKey) ?? false;
              if (!seen && mounted) _startTour(showcaseContext);
            } catch (e) {
              debugPrint('[ExploreTour] Could not read prefs: $e');
            }
          });
        }
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          bottomNavigationBar: _buildBottomNav(),
          body: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _isLoading
                    ? _buildInitialLoader()
                    : _items.isEmpty && !_hasMore
                        ? _buildEmpty()
                        : CustomScrollView(
                            slivers: [
                              // ── Stats strip ──────────────────────────────
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 20, 20, 8),
                                  child: _buildStatsStrip(),
                                ).animate().fadeIn(delay: 60.ms),
                              ),

                              // ── Empty filtered state ─────────────────────
                              if (_items.isEmpty)
                                SliverFillRemaining(
                                  child: _buildFilteredEmpty(),
                                ),

                              // ── Professional list ────────────────────────
                              if (_items.isNotEmpty)
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 8, 20, 8),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        final pro = _items[i];
                                        return _RankedProfessionalCard(
                                          rank: i + 1,
                                          professional: pro,
                                          onTap: () => widget.onProfessionalTap
                                              ?.call(pro),
                                        )
                                            .animate()
                                            .fadeIn(delay: (i * 50).ms)
                                            .slideX(begin: 0.04, end: 0);
                                      },
                                      childCount: _items.length,
                                    ),
                                  ),
                                ),

                              // ── Load more / end indicator ────────────────
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
        ); // end Scaffold
      }, // end ShowCaseWidget builder
    ); // end ShowCaseWidget
  }

  // ── TOP BAR ────────────────────────────────────────────────────────────

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _buildTopBar() => Container(
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
            Positioned(top: -30, right: -20, child: _circle(180, 0.04)),
            Positioned(top: 70, right: 40, child: _circle(90, 0.06)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title row ─────────────────────────────────────
                    Row(children: [
                      if (widget.onBack != null) ...[
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
                      ],
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Explore',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3)),
                            Text('Find & book verified professionals',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 18),

                    // ── Search bar ─────────────────────────────────────
                    CustomerTourShowcase.wrap(
                      key: _keys.exploreSearchKey,
                      stepName: 'exploreSearch',
                      showcaseContext: _showcaseContext,
                      innerKey: _searchInnerKey,
                      child: _buildSearchBar(),
                    ),

                    const SizedBox(height: 12),

                    // ── Skill filter chips ─────────────────────────────
                    CustomerTourShowcase.wrap(
                      key: _keys.exploreSkillFilterKey,
                      stepName: 'exploreSkillFilter',
                      showcaseContext: _showcaseContext,
                      isLast: true,
                      innerKey: _skillFilterInnerKey,
                      child: _buildSkillFilter(),
                    ),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── STATS STRIP ────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    final hasText = _search.isNotEmpty;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style:
            TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.8)),
        decoration: InputDecoration(
          hintText: 'Search by name, skill or city…',
          hintStyle: TextStyle(
              fontSize: 13, color: AppColors.primary.withOpacity(0.8)),
          prefixIcon: Icon(Icons.search_rounded,
              size: 18, color: AppColors.primary.withOpacity(0.8)),
          suffixIcon: hasText
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Colors.white.withOpacity(0.6)),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSkillFilter() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _skillFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _skillFilters[i];
          final label = f['label'] as String;
          final selected = _selectedSkill == label;
          return GestureDetector(
            onTap: () => _onSkillSelected(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.22)),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(f['icon'] as IconData,
                    size: 13,
                    color: selected
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.8)),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : Colors.white.withOpacity(0.8))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No professionals found',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text(
              'Try a different skill or search term.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );

  Widget _buildStatsStrip() => Container(
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
            _statItem(Icons.engineering_rounded, '$_totalCount',
                'Professionals', AppColors.primary),
            _divider(),
            _statItem(Icons.circle_rounded, '$_availableCount', 'Available Now',
                AppColors.success),
            _divider(),
            _statItem(Icons.rate_review_rounded, '$_totalReviews',
                'Total Reviews', const Color(0xFF5856D6)),
          ],
        ),
      );

  Widget _statItem(IconData icon, String value, String label, Color color) =>
      Column(children: [
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

  Widget _divider() =>
      Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));

  // ── LOAD MORE ──────────────────────────────────────────────────────────

  Widget _buildLoadMoreButton() => GestureDetector(
        onTap: _isLoadingMore ? null : () => _fetchPage(),
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
          child: _isLoadingMore
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.expand_more_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Load More  ·  Showing ${_items.length} of $_totalCount',
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
            'All ${_items.length} shown',
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 10),
          Container(width: 40, height: 1, color: const Color(0xFFDDDDDD)),
        ],
      );

  // ── INITIAL LOADER ─────────────────────────────────────────────────────

  Widget _buildInitialLoader() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Finding professionals…',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight.withOpacity(0.8),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.explore_rounded, 'label': 'Explore'},
      {'icon': Icons.calendar_today_rounded, 'label': 'Bookings'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
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
