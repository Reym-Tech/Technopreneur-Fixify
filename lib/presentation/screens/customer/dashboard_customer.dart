// lib/presentation/screens/customer/dashboard_customer.dart

import 'dart:ui';
import 'package:fixify/data/datasources/notification_datasource.dart';
import 'package:fixify/presentation/screens/customer/all_professionals_screen.dart';
import 'package:fixify/presentation/screens/customer/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/widgets/shared_widgets.dart';
import 'package:fixify/presentation/screens/customer/serviceoffers/service_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerDashboardScreen extends StatefulWidget {
  final UserEntity? user;
  final List<ProfessionalEntity> professionals;
  final List<BookingEntity> recentBookings;
  final VoidCallback? onRequestService;
  final Function(String serviceType, String serviceName)?
      onRequestServiceWithType;
  final VoidCallback? onViewBookings;
  final Function(String skill)? onFilterBySkill;
  final Function(ProfessionalEntity)? onProfessionalTap;
  final Function(int)? onNavTap;
  final Function(BookingEntity)? onBookingTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int currentNavIndex;
  final VoidCallback? onNotificationsViewed;

  const CustomerDashboardScreen({
    super.key,
    this.user,
    this.professionals = const [],
    this.recentBookings = const [],
    this.onRequestService,
    this.onRequestServiceWithType,
    this.onViewBookings,
    this.onFilterBySkill,
    this.onProfessionalTap,
    this.onNavTap,
    this.currentNavIndex = 0,
    this.onBookingTap,
    this.onNotificationTap,
    this.onProfileTap,
    this.onNotificationsViewed,
  });

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

// ── Service catalogue ─────────────────────────────────────────────────────────

class _ServiceDef {
  final String id, name, description, image, category;
  const _ServiceDef({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.category,
  });
}

const _allServices = [
  _ServiceDef(
      id: 'p1',
      name: 'Pipe Leak Repair',
      description: 'Fix leaking pipes and faucets',
      image: 'assets/images/pipeleakrepair.png',
      category: 'Plumbing'),
  _ServiceDef(
      id: 'p2',
      name: 'Drain Cleaning',
      description: 'Unclog slow and blocked drains',
      image: 'assets/images/draincleaning.png',
      category: 'Plumbing'),
  _ServiceDef(
      id: 'e1',
      name: 'Wiring Repair',
      description: 'Fix electrical wiring issues safely',
      image: 'assets/images/wirerepair.png',
      category: 'Electrical'),
  _ServiceDef(
      id: 'e2',
      name: 'Outlet Installation',
      description: 'Install new grounded power outlets',
      image: 'assets/images/outletinstallation.png',
      category: 'Electrical'),
  _ServiceDef(
      id: 'a1',
      name: 'Washer Repair',
      description: 'Fix washing machine problems',
      image: 'assets/images/washerrepair.png',
      category: 'Appliances'),
  _ServiceDef(
      id: 'a2',
      name: 'Dryer Repair',
      description: 'Fix dryer not heating or spinning',
      image: 'assets/images/dryerrepair.png',
      category: 'Appliances'),
  _ServiceDef(
      id: 'c1',
      name: 'Cabinet Installation',
      description: 'Install kitchen & bathroom cabinets',
      image: 'assets/images/cabenitinstallation.png',
      category: 'Carpentry'),
  _ServiceDef(
      id: 'c2',
      name: 'Door Repair',
      description: 'Fix squeaky or misaligned doors',
      image: 'assets/images/doorrepair.png',
      category: 'Carpentry'),
  _ServiceDef(
      id: 'pa1',
      name: 'Wall Painting',
      description: 'Interior wall painting service',
      image: 'assets/images/wallpainting.png',
      category: 'Painting'),
  _ServiceDef(
      id: 'pa2',
      name: 'Ceiling Painting',
      description: 'Paint ceilings and trim cleanly',
      image: 'assets/images/ceillingpainting.png',
      category: 'Painting'),
];

// ── Category meta ─────────────────────────────────────────────────────────────

class _CatMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _CatMeta(
      {required this.label, required this.icon, required this.color});
}

const _categories = [
  _CatMeta(
      label: 'All', icon: Icons.grid_view_rounded, color: Color(0xFF0F3D2E)),
  _CatMeta(
      label: 'Plumbing',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF007AFF)),
  _CatMeta(
      label: 'Electrical',
      icon: Icons.electrical_services_rounded,
      color: Color(0xFFFF9500)),
  _CatMeta(
      label: 'Appliances',
      icon: Icons.kitchen_rounded,
      color: Color(0xFF5856D6)),
  _CatMeta(
      label: 'Carpentry',
      icon: Icons.handyman_rounded,
      color: Color(0xFFFF3B30)),
  _CatMeta(
      label: 'Painting',
      icon: Icons.format_paint_rounded,
      color: Color(0xFF34C759)),
];

// ── Service detail data ───────────────────────────────────────────────────────

final Map<String, Map<String, dynamic>> _serviceDetails = {
  'p1': {
    'color': const Color(0xFF007AFF),
    'icon': Icons.water_drop_rounded,
    'price': '₱500 – ₱2,500',
    'duration': '1–3 hours',
    'includes': [
      'Inspection of visible and hidden pipes',
      'Sealing or replacement of the leaking section',
      'Pressure test after repair',
      'Clean-up of the work area',
      '30-day workmanship warranty'
    ],
    'tip':
        'Turn off your main water valve before the handyman arrives to prevent further damage.',
    'fullDesc':
        'A leaking pipe can waste hundreds of liters of water per day and cause serious structural damage. Our verified plumbers locate the source, replace or seal the affected section, and test the repair for a permanent fix.',
  },
  'p2': {
    'color': const Color(0xFF007AFF),
    'icon': Icons.water_drop_rounded,
    'price': '₱300 – ₱1,800',
    'duration': '30 min – 2 hours',
    'includes': [
      'Visual and physical drain inspection',
      'Mechanical snake or hydro-jet clearing',
      'Removal of hair, grease, and debris',
      'Deodorizing treatment after cleaning',
      'Drain flow verification test'
    ],
    'tip':
        'Avoid pouring grease or food scraps down drains before your appointment — it could worsen the blockage.',
    'fullDesc':
        'Clogged drains cause slow water drainage, foul odors, and potential backflow. Our professionals use mechanical snaking and hydro-jetting to clear blockages thoroughly.',
  },
  'e1': {
    'color': const Color(0xFFFF9500),
    'icon': Icons.electrical_services_rounded,
    'price': '₱600 – ₱3,000',
    'duration': '1–4 hours',
    'includes': [
      'Electrical fault diagnosis',
      'Repair or replacement of damaged wiring',
      'Circuit breaker inspection',
      'Safety continuity test after repair',
      'PEC-compliant installation'
    ],
    'tip':
        'Switch off the circuit breaker for the affected area before the technician arrives.',
    'fullDesc':
        'Faulty wiring is a leading cause of house fires. Our licensed electricians diagnose short circuits, damaged insulation, and overloaded circuits to restore safe, reliable power.',
  },
  'e2': {
    'color': const Color(0xFFFF9500),
    'icon': Icons.electrical_services_rounded,
    'price': '₱400 – ₱1,500 per outlet',
    'duration': '30 min – 2 hours',
    'includes': [
      'Wall assessment and outlet placement advice',
      'Wiring from nearest junction or panel',
      'Grounded outlet installation',
      'Load capacity verification',
      'Safety inspection and testing'
    ],
    'tip':
        'Decide the exact location(s) for new outlets beforehand. Consider USB-C combo outlets for modern convenience.',
    'fullDesc':
        'Need more power points in your kitchen, home office, or living room? Our electricians install grounded outlets safely, ensuring proper load distribution and code compliance.',
  },
  'a1': {
    'color': const Color(0xFF5856D6),
    'icon': Icons.kitchen_rounded,
    'price': '₱500 – ₱3,500',
    'duration': '1–3 hours',
    'includes': [
      'Full diagnostic assessment',
      'Repair of motor, pump, or drum issues',
      'Belt and bearing replacement if needed',
      'Water inlet valve inspection',
      'Test run to confirm fix'
    ],
    'tip':
        'Note down the exact symptoms (error code, which cycle it fails at) — this helps the technician arrive with the right parts.',
    'fullDesc':
        'Whether your washing machine won\'t spin, leaks, or makes unusual noises, our appliance technicians diagnose and repair it on the spot.',
  },
  'a2': {
    'color': const Color(0xFF5856D6),
    'icon': Icons.kitchen_rounded,
    'price': '₱500 – ₱3,000',
    'duration': '1–3 hours',
    'includes': [
      'Heating element and thermostat diagnosis',
      'Belt, drum, and motor inspection',
      'Lint trap and vent duct cleaning',
      'Electrical connection check',
      'Full test cycle after repair'
    ],
    'tip':
        'Clean the lint filter before the technician arrives. A clogged lint trap is the #1 cause of poor dryer performance.',
    'fullDesc':
        'A dryer that doesn\'t heat, tumbles slowly, or trips the breaker wastes energy and damages clothes. Our technicians get it back to peak performance.',
  },
  'c1': {
    'color': const Color(0xFFFF3B30),
    'icon': Icons.handyman_rounded,
    'price': '₱1,500 – ₱8,000',
    'duration': '2–6 hours',
    'includes': [
      'Wall stud location and mounting preparation',
      'Cabinet leveling and alignment',
      'Secure wall-anchor installation',
      'Door hinge and hardware fitting',
      'Touch-up and clean-up after installation'
    ],
    'tip':
        'Have your cabinets on-site and fully assembled before booking. Confirm measurements — even 1cm can matter.',
    'fullDesc':
        'Transform your kitchen or bathroom with professionally installed cabinets. Our carpenters ensure level, secure mounting, proper alignment, and a clean finish.',
  },
  'c2': {
    'color': const Color(0xFFFF3B30),
    'icon': Icons.handyman_rounded,
    'price': '₱300 – ₱2,000',
    'duration': '1–3 hours',
    'includes': [
      'Door frame and hinge inspection',
      'Planing or adjustment for a perfect fit',
      'Hinge tightening or replacement',
      'Lock and latch mechanism check',
      'Weather stripping replacement if needed'
    ],
    'tip':
        'If the door started sticking after a rainy season, it may have swollen — our carpenter will account for this.',
    'fullDesc':
        'Squeaky, sticking, or misaligned doors are more than annoying — they can be a security risk. Our carpenters restore smooth, secure operation.',
  },
  'pa1': {
    'color': const Color(0xFF34C759),
    'icon': Icons.format_paint_rounded,
    'price': '₱1,000 – ₱6,000 per room',
    'duration': '4–8 hours',
    'includes': [
      'Surface preparation and crack filling',
      'Primer application where needed',
      '2 coats of interior paint',
      'Edge masking for clean lines',
      'Furniture protection and clean-up'
    ],
    'tip':
        'Choose your paint color and finish before booking. Flat/matte hides imperfections; semi-gloss is easier to clean.',
    'fullDesc':
        'A fresh coat of paint transforms a room instantly. Our painters prepare surfaces properly, apply even coats, and deliver clean edges and consistent coverage.',
  },
  'pa2': {
    'color': const Color(0xFF34C759),
    'icon': Icons.format_paint_rounded,
    'price': '₱800 – ₱4,000 per room',
    'duration': '3–6 hours',
    'includes': [
      'Water stain treatment and sealing',
      'Surface sanding and priming',
      '2 coats of ceiling-grade white paint',
      'Wall/trim masking for clean borders',
      'Drop cloth protection for flooring'
    ],
    'tip':
        'Fix any active leaks before painting — our Plumbing service can help. Painting over an active leak is only a temporary fix.',
    'fullDesc':
        'Yellowed, water-stained, or peeling ceiling paint brings down the whole room. Our painters treat stains and apply ceiling-grade paint for a clean, bright finish.',
  },
};

// ── Screen state ──────────────────────────────────────────────────────────────

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  String _selectedSkill = 'All';

  // ── Unread count — owned entirely by this state, fetched from Supabase ──
  int _unreadNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final userId = widget.user?.id;
      if (userId == null || userId.isEmpty) return;
      final ds = NotificationDataSource(Supabase.instance.client);
      final count = await ds.getUnreadCount(userId);
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (_) {}
  }

  // ── Top Professionals helpers ─────────────────────────────────────────

  /// All verified professionals sorted by (rating * reviewCount) descending.
  /// Tiebreak: higher raw rating wins.
  List<ProfessionalEntity> get _verifiedSorted {
    // Only show pros that are BOTH verified AND currently online (available).
    // getProfessionals() already filters available=true from Supabase, but
    // this guard ensures the local list stays consistent if state is stale.
    final list =
        widget.professionals.where((p) => p.verified && p.available).toList();
    list.sort((a, b) {
      final scoreA = a.rating * a.reviewCount;
      final scoreB = b.rating * b.reviewCount;
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);
      return b.rating.compareTo(a.rating);
    });
    return list;
  }

  /// Only the top 3 for the dashboard preview.
  List<ProfessionalEntity> get _topThree => _verifiedSorted.take(3).toList();

  // ─────────────────────────────────────────────────────────────────────────

  Set<String> get _availableCategories {
    final cats = <String>{};
    for (final p in widget.professionals) {
      if (p.verified && p.available) {
        for (final s in p.skills) {
          cats.add('${s[0].toUpperCase()}${s.substring(1).toLowerCase()}');
        }
      }
    }
    return cats;
  }

  bool _hasProForCategory(String category) {
    if (category == 'All') return _availableCategories.isNotEmpty;
    return _availableCategories.contains(category);
  }

  List<_ServiceDef> get _filteredServices {
    if (_selectedSkill == 'All') return _allServices.toList();
    return _allServices.where((s) => s.category == _selectedSkill).toList();
  }

  void _openServiceDetail(_ServiceDef service) async {
    final d = _serviceDetails[service.id];
    if (d == null) return;

    final result = await Navigator.of(context).push<(String, String)>(
      MaterialPageRoute(
        builder: (_) => ServiceDetailScreen(
          serviceName: service.name,
          serviceType: service.category,
          description: d['fullDesc'] as String,
          imagePath: service.image,
          accentColor: d['color'] as Color,
          icon: d['icon'] as IconData,
          priceRange: d['price'] as String,
          duration: d['duration'] as String,
          includes: List<String>.from(d['includes'] as List),
          tips: d['tip'] as String?,
          onBookNow: (type, name) => Navigator.of(context).pop((type, name)),
        ),
      ),
    );

    if (result != null && mounted) {
      final (serviceType, serviceName) = result;
      widget.onRequestServiceWithType?.call(serviceType, serviceName);
    }
  }

  /// Opens the full paginated professionals list.
  void _openAllProfessionals() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllProfessionalsScreen(
          professionals: widget.professionals,
          onProfessionalTap: widget.onProfessionalTap,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  // ── Avatar chip ───────────────────────────────────────────────────────────
  Widget _buildAvatarChip(String name) {
    final avatarUrl = widget.user?.avatarUrl;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: (avatarUrl == null || avatarUrl.isEmpty)
            ? const LinearGradient(
                colors: [Color(0xFF34C759), Color(0xFF2E7D5E)],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? Image.network(
                avatarUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackInitial(name),
              )
            : _fallbackInitial(name),
      ),
    );
  }

  Widget _fallbackInitial(String name) => Container(
        color: const Color(0xFF2E7D5E),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final topThree = _topThree;
    final verifiedCount = _verifiedSorted.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _buildRequestCTA(),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
          ),
          SliverToBoxAdapter(
            child: _buildServiceOffers().animate().fadeIn(delay: 220.ms),
          ),
          if (widget.recentBookings.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SectionHeader(
                  title: 'Recent Bookings',
                  actionLabel: 'See All',
                  onAction: widget.onViewBookings,
                ),
              ).animate().fadeIn(delay: 280.ms),
            ),
            SliverToBoxAdapter(
              child: _buildRecentBookings().animate().fadeIn(delay: 320.ms),
            ),
          ],

          // ── Top Professionals header ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: SectionHeader(
                title: 'Top Professionals',
                // Show "See All" only when there are verified pros
                actionLabel: verifiedCount > 0 ? 'See All' : null,
                onAction: verifiedCount > 0 ? _openAllProfessionals : null,
              ),
            ).animate().fadeIn(delay: 360.ms),
          ),

          // ── Top 3 verified pros (or empty state) ────────────────────
          topThree.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyPros())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final pro = topThree[i];
                        return ProfessionalCard(
                          professional: pro,
                          onTap: () => widget.onProfessionalTap?.call(pro),
                        )
                            .animate()
                            .fadeIn(delay: (400 + i * 70).ms)
                            .slideX(begin: 0.04, end: 0);
                      },
                      childCount: topThree.length,
                    ),
                  ),
                ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = widget.user?.name ?? 'Customer';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    // Show verified-only count in the header badge
    final proCount = _verifiedSorted.length;

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
          Positioned(top: -30, right: -20, child: _circle(180, 0.04)),
          Positioned(top: 70, right: 40, child: _circle(90, 0.06)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 3),
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.handyman_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'AYO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      // Action buttons
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationsScreen(
                                    userId: widget.user?.id ?? '',
                                  ),
                                ),
                              );
                              if (mounted) {
                                await _fetchUnreadCount();
                                widget.onNotificationsViewed?.call();
                              }
                            },
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                if (_unreadNotifCount > 0)
                                  Positioned(
                                    top: 7,
                                    right: 7,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onProfileTap,
                            icon: _buildAvatarChip(name),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting 👋',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'What repair do you need today?',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.18)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$proCount+',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Experts',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0);
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );

  // ── CTA ──────────────────────────────────────────────────────────────────

  Widget _buildRequestCTA() => GestureDetector(
        onTap: widget.onRequestService,
        child: Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3D2E), Color(0xFF1A5C43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('⚡ Instant Booking',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 10),
                  const Text('Request Service',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text('Book a verified handyman now',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ])),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 24),
            ),
          ]),
        ),
      );

  // ── SERVICE OFFERS ────────────────────────────────────────────────────────

  Widget _buildServiceOffers() {
    final services = _filteredServices;
    final catHasPro = _hasProForCategory(_selectedSkill);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(right: 20),
          child: SectionHeader(title: 'Service Offers'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _categories[i];
              final selected = _selectedSkill == cat.label;
              final hasAvail = _hasProForCategory(cat.label);
              return FilterChip(
                label: Text(cat.label),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) {
                  setState(() => _selectedSkill = cat.label);
                  widget.onFilterBySkill?.call(cat.label);
                },
                backgroundColor: Colors.white,
                selectedColor: cat.color,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textDark,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                avatar: Stack(clipBehavior: Clip.none, children: [
                  Icon(cat.icon,
                      size: 16, color: selected ? Colors.white : cat.color),
                  if (!hasAvail && cat.label != 'All')
                    Positioned(
                      top: -3,
                      right: -4,
                      child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFF3B30),
                              shape: BoxShape.circle)),
                    ),
                ]),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color:
                          selected ? Colors.transparent : Colors.grey.shade300),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (!catHasPro && _selectedSkill != 'All')
          _buildNoProsForCategory(_selectedSkill)
        else if (services.isEmpty)
          _buildNoProsForCategory(_selectedSkill)
        else
          SizedBox(
            height: 232,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: services.length,
              padding: const EdgeInsets.only(right: 20),
              itemBuilder: (context, i) {
                final s = services[i];
                final available = _hasProForCategory(s.category);
                return _ServiceCard(
                  service: s,
                  available: available,
                  accentColor: _colorForCategory(s.category),
                  onTap: available ? () => _openServiceDetail(s) : null,
                ).animate().fadeIn(delay: (i * 60).ms);
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildNoProsForCategory(String category) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 20, 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _colorForCategory(category).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconForCategory(category),
                  size: 36,
                  color: _colorForCategory(category).withOpacity(0.5)),
            ),
            const SizedBox(height: 14),
            Text(
              category == 'All'
                  ? 'No professionals available right now'
                  : 'No $category professionals available',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Check back soon — we\'re always adding verified handymen to the platform.',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );

  Color _colorForCategory(String cat) {
    switch (cat) {
      case 'Plumbing':
        return const Color(0xFF007AFF);
      case 'Electrical':
        return const Color(0xFFFF9500);
      case 'Appliances':
        return const Color(0xFF5856D6);
      case 'Carpentry':
        return const Color(0xFFFF3B30);
      case 'Painting':
        return const Color(0xFF34C759);
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Plumbing':
        return Icons.water_drop_rounded;
      case 'Electrical':
        return Icons.electrical_services_rounded;
      case 'Appliances':
        return Icons.kitchen_rounded;
      case 'Carpentry':
        return Icons.handyman_rounded;
      case 'Painting':
        return Icons.format_paint_rounded;
      default:
        return Icons.engineering_rounded;
    }
  }

  // ── RECENT BOOKINGS ───────────────────────────────────────────────────────

  Widget _buildRecentBookings() => SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: widget.recentBookings.length.clamp(0, 5),
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final b = widget.recentBookings[i];
            return GestureDetector(
              onTap: () => widget.onBookingTap?.call(b),
              child: _BookingMiniCard(booking: b),
            );
          },
        ),
      );

  // ── EMPTY PROS ────────────────────────────────────────────────────────────

  Widget _buildEmptyPros() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(children: [
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text('Check back soon — we\'re always growing our network.',
              style: TextStyle(color: AppColors.textLight),
              textAlign: TextAlign.center),
        ]),
      );

  // ── BOTTOM NAV ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
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
                    ]),
                  ),
                );
              }),
            ),
          )),
    );
  }
}

// ── SERVICE CARD ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final _ServiceDef service;
  final bool available;
  final Color accentColor;
  final VoidCallback? onTap;

  const _ServiceCard({
    required this.service,
    required this.available,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 162,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        service.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accentColor.withOpacity(0.1),
                          child: Icon(_iconForCat(service.category),
                              size: 40, color: accentColor),
                        ),
                      ),
                      if (!available)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Unavailable',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          service.description,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textLight),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForCat(String cat) {
    switch (cat) {
      case 'Plumbing':
        return Icons.water_drop_rounded;
      case 'Electrical':
        return Icons.electrical_services_rounded;
      case 'Appliances':
        return Icons.kitchen_rounded;
      case 'Carpentry':
        return Icons.handyman_rounded;
      case 'Painting':
        return Icons.format_paint_rounded;
      default:
        return Icons.build_rounded;
    }
  }
}

// ── BOOKING MINI CARD ─────────────────────────────────────────────────────────

class _BookingMiniCard extends StatelessWidget {
  final BookingEntity booking;
  const _BookingMiniCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(booking.status);
    final statusLabel = _statusLabel(booking.status);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(booking.serviceType,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(booking.professional?.name ?? 'Finding professional...',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const Spacer(),
        Text(
          '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}',
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMedium,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return AppColors.statusAccepted;
      case BookingStatus.inProgress:
        return AppColors.statusInProgress;
      case BookingStatus.completed:
        return AppColors.statusCompleted;
      case BookingStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.statusPending;
    }
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}
