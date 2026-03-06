// lib/presentation/screens/customer/bookings_customer.dart
//
// CustomerBookingsScreen — Full bookings list for the Customer (navIndex=1).
//
// Shows 4 tabs: All / Active / Pending / Completed
// Tap any booking card → onBookingTap(booking)
// Pull-to-refresh → onRefresh()
//
// Props:
//   bookings       → List<BookingEntity>
//   onBookingTap   → Function(BookingEntity)
//   onNavTap       → Function(int)
//   currentNavIndex → int
//   onRefresh      → Future<void> Function()?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class CustomerBookingsScreen extends StatefulWidget {
  final List<BookingEntity> bookings;
  final Function(BookingEntity)? onBookingTap;
  final Function(int)? onNavTap;
  final int currentNavIndex;
  final Future<void> Function()? onRefresh;

  const CustomerBookingsScreen({
    super.key,
    this.bookings = const [],
    this.onBookingTap,
    this.onNavTap,
    this.currentNavIndex = 1,
    this.onRefresh,
  });

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<BookingEntity> _filtered(String filter) {
    switch (filter) {
      case 'Active':
        return widget.bookings
            .where((b) =>
                b.status == BookingStatus.accepted ||
                b.status == BookingStatus.inProgress)
            .toList();
      case 'Pending':
        return widget.bookings
            .where((b) => b.status == BookingStatus.pending)
            .toList();
      case 'Completed':
        return widget.bookings
            .where((b) =>
                b.status == BookingStatus.completed ||
                b.status == BookingStatus.cancelled)
            .toList();
      default:
        return widget.bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onNavTap?.call(0); // back → Home
        },
        child: Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Column(children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: ['All', 'Active', 'Pending', 'Completed']
                    .map((f) => _buildList(f))
                    .toList(),
              ),
            ),
          ]),
          bottomNavigationBar: _buildBottomNav(),
        ));
  }

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Bookings',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    Text(
                        '${widget.bookings.length} total booking${widget.bookings.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13)),
                    const SizedBox(height: 16),
                    // Summary chips
                    Row(children: [
                      _statChip(
                          Icons.pending_rounded,
                          '${_filtered('Pending').length}',
                          'Pending',
                          const Color(0xFFFF9500)),
                      const SizedBox(width: 10),
                      _statChip(
                          Icons.construction_rounded,
                          '${_filtered('Active').length}',
                          'Active',
                          const Color(0xFF007AFF)),
                      const SizedBox(width: 10),
                      _statChip(
                          Icons.check_circle_rounded,
                          '${widget.bookings.where((b) => b.status == BookingStatus.completed).length}',
                          'Done',
                          const Color(0xFF34C759)),
                    ]),
                  ]),
            )),
      );

  Widget _statChip(IconData icon, String count, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text('$count $label',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _buildTabBar() => Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      );

  Widget _buildList(String filter) {
    final list = _filtered(filter);
    if (list.isEmpty) return _empty(filter);
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _BookingCard(
          booking: list[i],
          onTap: () => widget.onBookingTap?.call(list[i]),
        ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: 0.06, end: 0),
      ),
    );
  }

  Widget _empty(String filter) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded,
                  size: 44, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text('No ${filter == 'All' ? '' : '$filter '}bookings yet',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text(
                'Your bookings will appear here once you request a service.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textLight)),
          ]),
        ),
      );

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
                    duration: 200.ms,
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

// ── Booking card ───────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onTap;
  const _BookingCard({required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(booking.status);
    final label = _statusLabel(booking.status);
    final icon = _serviceIcon(booking.serviceType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          // Top section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              // Service icon
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
                    Text(booking.serviceType,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 3),
                    Text(booking.professional?.name ?? 'Assigned professional',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ])),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ]),
          ),
          // Divider + footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppColors.textLight),
              const SizedBox(width: 5),
              Text(
                '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500),
              ),
              if (booking.address != null && booking.address!.isNotEmpty) ...[
                const SizedBox(width: 14),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textLight),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(booking.address!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMedium),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ],
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textLight),
            ]),
          ),
        ]),
      ),
    );
  }

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return const Color(0xFF007AFF);
      case BookingStatus.inProgress:
        return const Color(0xFF5856D6);
      case BookingStatus.completed:
        return const Color(0xFF34C759);
      case BookingStatus.cancelled:
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFFF9500);
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

  IconData _serviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'plumbing':
        return Icons.water_drop_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'carpentry':
        return Icons.handyman_rounded;
      case 'painting':
        return Icons.format_paint_rounded;
      case 'appliances':
        return Icons.kitchen_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.build_rounded;
    }
  }
}
