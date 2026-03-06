// lib/presentation/screens/customer/dashboard_customer.dart
//
// CustomerDashboardScreen — MVP home screen for Homeowner role.
// Shows: greeting, request service CTA, service categories,
// bookings summary, promo banner, bottom nav.
//
// Key props:
//   user            → UserEntity?       — logged-in user data
//   professionals   → List<ProfessionalEntity> — available pros (for browse)
//   recentBookings  → List<BookingEntity>       — customer's recent bookings
//   onRequestService → VoidCallback?    — taps "Request Service" CTA
//   onViewBookings   → VoidCallback?    — taps "My Bookings"
//   onFilterBySkill  → Function(String) — category chip tap
//   onProfessionalTap → Function(ProfessionalEntity) — pro card tap
//   onNavTap         → Function(int)    — bottom nav tap (0=home,1=bookings,2=support,3=profile)
//   currentNavIndex  → int              — active nav index

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/widgets/shared_widgets.dart';

class CustomerDashboardScreen extends StatefulWidget {
  final UserEntity? user;
  final List<ProfessionalEntity> professionals;
  final List<BookingEntity> recentBookings;
  final VoidCallback? onRequestService;
  final VoidCallback? onViewBookings;
  final Function(String skill)? onFilterBySkill;
  final Function(ProfessionalEntity)? onProfessionalTap;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const CustomerDashboardScreen({
    super.key,
    this.user,
    this.professionals = const [],
    this.recentBookings = const [],
    this.onRequestService,
    this.onViewBookings,
    this.onFilterBySkill,
    this.onProfessionalTap,
    this.onNavTap,
    this.currentNavIndex = 0,
  });

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  String _selectedSkill = 'All';

  static const _categories = [
    {
      'label': 'All',
      'icon': Icons.grid_view_rounded,
      'color': Color(0xFF0F3D2E)
    },
    {
      'label': 'Plumbing',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF007AFF)
    },
    {
      'label': 'Electrical',
      'icon': Icons.electrical_services_rounded,
      'color': Color(0xFFFF9500)
    },
    {
      'label': 'Appliances',
      'icon': Icons.kitchen_rounded,
      'color': Color(0xFF5856D6)
    },
    {
      'label': 'Carpentry',
      'icon': Icons.handyman_rounded,
      'color': Color(0xFFFF3B30)
    },
    {
      'label': 'Painting',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFF34C759)
    },
  ];

  @override
  Widget build(BuildContext context) {
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
            child: _buildCategoryRow().animate().fadeIn(delay: 220.ms),
          ),
          if (widget.recentBookings.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SectionHeader(
                title: 'Top Professionals',
                actionLabel: widget.professionals.isNotEmpty ? 'See All' : null,
              ),
            ).animate().fadeIn(delay: 360.ms),
          ),
          widget.professionals.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyPros())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final pro = widget.professionals[i];
                        return ProfessionalCard(
                          professional: pro,
                          onTap: () => widget.onProfessionalTap?.call(pro),
                        )
                            .animate()
                            .fadeIn(delay: (400 + i * 70).ms)
                            .slideX(begin: 0.04, end: 0);
                      },
                      childCount: widget.professionals.length,
                    ),
                  ),
                ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = widget.user?.name ?? 'Customer';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

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
            child: _circle(180, 0.04),
          ),
          Positioned(
            top: 70,
            right: 40,
            child: _circle(90, 0.06),
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
                      Row(children: [
                        _headerIconBtn(Icons.notifications_outlined),
                        const SizedBox(width: 8),
                        _avatarChip(name),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Greeting row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$greeting 👋',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4)),
                            const SizedBox(height: 6),
                            Text('What repair do you need today?',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      // Stats chip
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
                            child: Column(children: [
                              const Text('500+',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                              Text('Experts',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 11)),
                            ]),
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
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  Widget _headerIconBtn(IconData icon) => Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
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
      );

  Widget _avatarChip(String name) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF34C759), Color(0xFF2E7D5E)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'C',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      );

  // ── REQUEST SERVICE CTA ───────────────────────────────────

  Widget _buildRequestCTA() {
    return GestureDetector(
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
            ),
          ],
        ),
        child: Row(
          children: [
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
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  // ── CATEGORIES ────────────────────────────────────────────

  Widget _buildCategoryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: SectionHeader(title: 'Services'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final label = cat['label'] as String;
                final selected = _selectedSkill == label;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSkill = label);
                    widget.onFilterBySkill?.call(label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    decoration: BoxDecoration(
                      color: selected ? (cat['color'] as Color) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: selected
                              ? (cat['color'] as Color).withOpacity(0.3)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: selected ? 12 : 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          color:
                              selected ? Colors.white : (cat['color'] as Color),
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  )
                      .animate(target: selected ? 1 : 0)
                      .scaleXY(begin: 1, end: 1.05, duration: 200.ms),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── RECENT BOOKINGS ───────────────────────────────────────

  Widget _buildRecentBookings() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.recentBookings.length.clamp(0, 5),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = widget.recentBookings[i];
          return _BookingMiniCard(booking: b);
        },
      ),
    );
  }

  // ── EMPTY STATE ───────────────────────────────────────────

  Widget _buildEmptyPros() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.engineering_rounded,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No professionals found',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text('Try a different category',
              style: TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }

  // ── BOTTOM NAV ────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.calendar_today_rounded, 'label': 'Bookings'},
      {'icon': Icons.headset_mic_rounded, 'label': 'Support'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
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
                      Icon(
                        items[i]['icon'] as IconData,
                        color: active ? AppColors.primary : AppColors.textLight,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                          color:
                              active ? AppColors.primary : AppColors.textLight,
                        ),
                      ),
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

// ── BOOKING MINI CARD (horizontal list) ──────────────────────

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.serviceType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
            ],
          ),
          const SizedBox(height: 8),
          Text(
            booking.professional?.name ?? 'Finding professional...',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}',
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMedium,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
