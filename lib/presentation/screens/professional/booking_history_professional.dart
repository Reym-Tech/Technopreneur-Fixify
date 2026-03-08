// lib/presentation/screens/professional/booking_history_professional.dart
//
// BookingHistoryScreen — Professional's booking history.
//
// Tabs: All / Ongoing / Completed / Cancelled
// Cards are now TAPPABLE → opens ProBookingDetailScreen via onViewDetail.
//
// Props:
//   bookings        → List<BookingEntity>
//   onUpdateStatus  → Function(BookingEntity, BookingStatus)?
//   onViewDetail    → Function(BookingEntity)?   ← NEW: tap card to view detail
//   onBack          → VoidCallback?
//   onNavTap        → Function(int)?
//   currentNavIndex → int
//   onRefresh       → Future<void> Function()?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class BookingHistoryScreen extends StatefulWidget {
  final List<BookingEntity> bookings;
  final Function(BookingEntity, BookingStatus)? onUpdateStatus;
  final Function(BookingEntity)? onViewDetail;
  final VoidCallback? onBack;
  final Function(int)? onNavTap;
  final int currentNavIndex;
  final Future<void> Function()? onRefresh;

  const BookingHistoryScreen({
    super.key,
    this.bookings = const [],
    this.onUpdateStatus,
    this.onViewDetail,
    this.onBack,
    this.onNavTap,
    this.currentNavIndex = 0,
    this.onRefresh,
  });

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen>
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

  // History = everything that is NOT pending
  List<BookingEntity> get _history =>
      widget.bookings.where((b) => b.status != BookingStatus.pending).toList();

  List<BookingEntity> _filter(String f) {
    switch (f) {
      case 'Ongoing':
        return _history
            .where((b) =>
                b.status == BookingStatus.accepted ||
                b.status == BookingStatus.inProgress)
            .toList();
      case 'Completed':
        return _history
            .where((b) => b.status == BookingStatus.completed)
            .toList();
      case 'Cancelled':
        return _history
            .where((b) => b.status == BookingStatus.cancelled)
            .toList();
      default:
        return _history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: ['All', 'Ongoing', 'Completed', 'Cancelled']
                  .map((f) => _buildList(f))
                  .toList(),
            ),
          ),
        ]),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() => Container(
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
            child: Row(children: [
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
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Booking History',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      Text(
                          '${_history.length} total job${_history.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF34C759), size: 14),
                  const SizedBox(width: 4),
                  Text('${_filter('Completed').length} done',
                      style: const TextStyle(
                          color: Color(0xFF34C759),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
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
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled')
          ],
        ),
      );

  Widget _buildList(String filter) {
    final list = _filter(filter);
    if (list.isEmpty) return _empty(filter);
    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _HistoryCard(
          booking: list[i],
          onTap: widget.onViewDetail != null
              ? () => widget.onViewDetail!(list[i])
              : null,
          onMarkComplete: list[i].status == BookingStatus.accepted ||
                  list[i].status == BookingStatus.inProgress
              ? () =>
                  widget.onUpdateStatus?.call(list[i], BookingStatus.completed)
              : null,
          onMarkInProgress: list[i].status == BookingStatus.accepted
              ? () =>
                  widget.onUpdateStatus?.call(list[i], BookingStatus.inProgress)
              : null,
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
              child: Icon(Icons.history_rounded,
                  size: 44, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text('No ${filter == 'All' ? '' : '$filter '}jobs yet',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Accepted bookings will appear here.',
                style: TextStyle(fontSize: 13, color: AppColors.textLight)),
          ]),
        ),
      );

  Widget _buildBottomNav() {
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Requests'},
      {'icon': Icons.monetization_on_rounded, 'label': 'Earnings'},
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
                        color: active ? AppColors.primary : AppColors.textLight,
                        size: 24),
                    const SizedBox(height: 4),
                    Text(items[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w400,
                          color:
                              active ? AppColors.primary : AppColors.textLight,
                        )),
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

// ── History Card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onTap;
  final VoidCallback? onMarkComplete;
  final VoidCallback? onMarkInProgress;

  const _HistoryCard({
    required this.booking,
    this.onTap,
    this.onMarkComplete,
    this.onMarkInProgress,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(booking.status);
    final label = _statusLabel(booking.status);
    final isActionable = onMarkComplete != null || onMarkInProgress != null;

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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_serviceIcon(booking.serviceType),
                    color: color, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceType,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(
                        booking.address ?? 'No address provided',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
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
              // Chevron hint for tappable cards
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400, size: 18),
              ],
            ]),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F8F8),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(children: [
              Row(children: [
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
                if (booking.assessmentPrice != null) ...[
                  const Spacer(),
                  Text('₱${booking.assessmentPrice!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ] else if (booking.priceEstimate != null) ...[
                  const Spacer(),
                  Text('₱${booking.priceEstimate!.toStringAsFixed(0)}/hr',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ],
              ]),
              if (isActionable) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (onMarkInProgress != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onMarkInProgress,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: const Color(0xFF5856D6).withOpacity(0.5)),
                          foregroundColor: const Color(0xFF5856D6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Start Job',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  if (onMarkInProgress != null && onMarkComplete != null)
                    const SizedBox(width: 10),
                  if (onMarkComplete != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onMarkComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text('Mark Complete',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                ]),
              ],
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
