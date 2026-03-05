// lib/presentation/screens/professional/professional_dashboard.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/shared_widgets.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  final UserEntity? user;
  final ProfessionalEntity? professional;
  final List<BookingEntity> bookings;
  final Function(BookingEntity, BookingStatus)? onUpdateStatus;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  const ProfessionalDashboardScreen({
    super.key,
    this.user,
    this.professional,
    this.bookings = const [],
    this.onUpdateStatus,
    this.onNavTap,
    this.currentNavIndex = 0,
  });

  @override
  State<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends State<ProfessionalDashboardScreen> {
  String _selectedFilter = 'All';

  List<BookingEntity> get _filteredBookings {
    if (_selectedFilter == 'All') return widget.bookings;
    final statusMap = {
      'Pending': BookingStatus.pending,
      'Accepted': BookingStatus.accepted,
      'In Progress': BookingStatus.inProgress,
      'Completed': BookingStatus.completed,
    };
    final status = statusMap[_selectedFilter];
    if (status == null) return widget.bookings;
    return widget.bookings.where((b) => b.status == status).toList();
  }

  int get _pendingCount =>
      widget.bookings.where((b) => b.status == BookingStatus.pending).length;

  double get _totalEarnings => widget.bookings
      .where((b) => b.status == BookingStatus.completed)
      .fold(0, (sum, b) => sum + (b.priceEstimate ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _buildStatsRow(),
            ).animate().fadeIn(delay: 200.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 0, 20),
              child: _buildFilterChips(),
            ).animate().fadeIn(delay: 300.ms),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SectionHeader(
                title: 'Booking Requests',
              ),
            ),
          ),
          _filteredBookings.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassCard(
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.work_outline_rounded,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No bookings found',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'New booking requests will appear here',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textLight,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildBookingCard(_filteredBookings[index])
                            .animate()
                            .fadeIn(delay: (400 + index * 80).ms)
                            .slideX(begin: 0.05, end: 0);
                      },
                      childCount: _filteredBookings.length,
                    ),
                  ),
                ),
        ],
      ),
      bottomNavigationBar: FixifyBottomNav(
        currentIndex: widget.currentNavIndex,
        onTap: widget.onNavTap ?? (_) {},
        isProfessional: true,
      ),
    );
  }

  Widget _buildHeader() {
    final name = widget.user?.name ?? 'Professional';
    final pro = widget.professional;

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
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34C759), Color(0xFF2E7D5E)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                                if (pro?.verified == true) ...[
                                  const SizedBox(width: 8),
                                  const VerifiedBadge(isVerified: true),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFFFB800), size: 14),
                                Text(
                                  ' ${pro?.rating.toStringAsFixed(1) ?? '0.0'} • ${pro?.reviewCount ?? 0} reviews',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Availability toggle
                      Column(
                        children: [
                          Text(
                            pro?.available == true ? 'Available' : 'Offline',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Switch(
                            value: pro?.available ?? true,
                            onChanged: (_) {},
                            activeColor: const Color(0xFF34C759),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Pending notification banner
                  if (_pendingCount > 0)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFF9500).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded,
                                  color: Color(0xFFFF9500), size: 18),
                              const SizedBox(width: 10),
                              Text(
                                'You have $_pendingCount pending booking request${_pendingCount > 1 ? 's' : ''}!',
                                style: const TextStyle(
                                  color: Color(0xFFFF9500),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildStatsRow() {
    final completedCount = widget.bookings
        .where((b) => b.status == BookingStatus.completed)
        .length;

    return Row(
      children: [
        _buildStatCard('💰', '\$${_totalEarnings.toStringAsFixed(0)}',
            'Earnings', AppColors.success,
            flex: 2),
        const SizedBox(width: 12),
        _buildStatCard(
            '✅', '$completedCount', 'Completed', AppColors.statusAccepted,
            flex: 1),
        const SizedBox(width: 12),
        _buildStatCard(
            '⏳', '$_pendingCount', 'Pending', AppColors.statusPending,
            flex: 1),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String value, String label, Color color,
      {required int flex}) {
    return Expanded(
      flex: flex,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Pending', 'Accepted', 'In Progress', 'Completed'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? AppColors.primary.withOpacity(0.25)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingEntity booking) {
    final customer = booking.customer;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    customer?.name.isNotEmpty == true
                        ? customer!.name[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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
                      customer?.name ?? 'Customer',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _capitalizeSkill(booking.serviceType),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildBookingInfoItem(
                    Icons.calendar_today_rounded,
                    _formatDate(booking.scheduledDate),
                  ),
                ),
                if (booking.priceEstimate != null) ...[
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFE0E0E0),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  _buildBookingInfoItem(
                    Icons.payments_rounded,
                    '\$${booking.priceEstimate!.toStringAsFixed(0)}',
                  ),
                ],
              ],
            ),
          ),

          // Accept/Decline buttons for pending
          if (booking.status == BookingStatus.pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onUpdateStatus
                        ?.call(booking, BookingStatus.cancelled),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                          color: AppColors.error.withOpacity(0.5), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onUpdateStatus
                        ?.call(booking, BookingStatus.accepted),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size.zero,
                      elevation: 0,
                    ),
                    child: const Text('Accept',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],

          // Update status for accepted/in-progress
          if (booking.status == BookingStatus.accepted ||
              booking.status == BookingStatus.inProgress) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => widget.onUpdateStatus?.call(
                booking,
                booking.status == BookingStatus.accepted
                    ? BookingStatus.inProgress
                    : BookingStatus.completed,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: booking.status == BookingStatus.accepted
                    ? AppColors.statusInProgress
                    : AppColors.statusCompleted,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                booking.status == BookingStatus.accepted
                    ? 'Start Job'
                    : 'Mark as Completed',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingInfoItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }

  String _capitalizeSkill(String skill) {
    if (skill.isEmpty) return skill;
    return skill[0].toUpperCase() + skill.substring(1);
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
