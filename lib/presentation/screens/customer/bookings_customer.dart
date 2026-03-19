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
//   onBackjob      → Function(BookingEntity)? — called when the customer taps
//                    "Backjob" on a completed, in-warranty booking card.
//
// FIX: Added `assessment` to:
//   - _filtered('Active') so Assessment bookings appear in the Active tab
//   - _statusColor() / _statusLabel() so the badge shows correctly
//
// BACKJOB / WARRANTY UPDATE:
//   • Added onBackjob callback to CustomerBookingsScreen and _BookingCard.
//   • Completed cards that are still under warranty show a teal "Backjob"
//     action button row beneath the date/address footer.
//   • The Backjob button is only shown when booking.isUnderWarranty == true
//     AND onBackjob != null — no changes visible for non-warranty bookings.

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

  /// Called when the customer taps "Backjob" on a completed, in-warranty
  /// booking card in the list. The controller navigates to BackjobScreen.
  final Function(BookingEntity)? onBackjob;

  const CustomerBookingsScreen({
    super.key,
    this.bookings = const [],
    this.onBookingTap,
    this.onNavTap,
    this.currentNavIndex = 2,
    this.onRefresh,
    this.onBackjob,
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
        // FIX: include `assessment` so price-negotiation bookings show here
        return widget.bookings
            .where((b) =>
                b.status == BookingStatus.accepted ||
                b.status == BookingStatus.assessment ||
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
                          'Records',
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
          onBackjob: widget.onBackjob != null
              ? () => widget.onBackjob!.call(list[i])
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

  /// Called when the customer taps "Backjob" on this card.
  /// Only wired when the booking is completed AND under warranty.
  final VoidCallback? onBackjob;

  const _BookingCard({required this.booking, this.onTap, this.onBackjob});

  @override
  Widget build(BuildContext context) {
    final isCompleted = booking.status == BookingStatus.completed;

    // Completed cards use a richer service-record layout.
    // All other statuses keep the original compact card layout.
    return isCompleted ? _buildCompletedCard() : _buildActiveCard();
  }

  // ── Completed booking — service record card ───────────────────────────────
  // Shows the specific service performed, handyman, date, final price, and
  // warranty status. Reads like a document entry, not a status tracker.
  Widget _buildCompletedCard() {
    final showBackjob = booking.isUnderWarranty && onBackjob != null;
    final icon = _serviceIcon(booking.serviceType);
    final serviceTitle = booking.serviceTitle?.isNotEmpty == true
        ? booking.serviceTitle!
        : booking.serviceType;
    final hasPrice = booking.assessmentPrice != null;
    final proName = booking.professional?.name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: showBackjob
              ? Border.all(
                  color: const Color(0xFF30B0C7).withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(children: [
          // ── Record header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service icon — uses a soft green tint for completed jobs
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withOpacity(0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF34C759), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Specific service title — the key record identifier
                      Text(serviceTitle,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      // Service category below when title differs from type
                      if (booking.serviceTitle?.isNotEmpty == true &&
                          booking.serviceTitle != booking.serviceType) ...[
                        const SizedBox(height: 2),
                        Text(booking.serviceType,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary)),
                      ],
                    ],
                  ),
                ),
                // Completed badge + warranty indicator stacked vertically
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Completed',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF34C759))),
                    ),
                    if (showBackjob) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF30B0C7).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF30B0C7).withOpacity(0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 9, color: Color(0xFF30B0C7)),
                          const SizedBox(width: 3),
                          const Text('Covered',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF30B0C7))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Record detail rows ────────────────────────────────────────
          // Minimal divider then compact key-value rows. Each row shows
          // one data point the customer would reference as a service record.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              const Divider(height: 1, color: Color(0xFFF2F2F2)),
              const SizedBox(height: 12),
              // Handyman row
              if (proName != null && proName.isNotEmpty)
                _recordRow(
                  Icons.person_outline_rounded,
                  'Handyman',
                  proName,
                ),
              // Date row — formatted as a record date, not "scheduled date"
              _recordRow(
                Icons.calendar_today_outlined,
                'Date',
                _formatRecordDate(booking.scheduledDate),
                topPad: proName != null ? 8 : 0,
              ),
              // Final price — most important data point for a record
              if (hasPrice)
                _recordRow(
                  Icons.payments_outlined,
                  'Amount Paid',
                  '₱${booking.assessmentPrice!.toStringAsFixed(0)}',
                  topPad: 8,
                  valueStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              // Warranty expiry — surfaces the coverage end date at a glance
              if (booking.warrantyExpiresAt != null) ...[
                const SizedBox(height: 8),
                _recordRow(
                  Icons.verified_user_outlined,
                  'Guarantee',
                  booking.isUnderWarranty
                      ? 'Active until ${_formatRecordDate(booking.warrantyExpiresAt!)}'
                      : 'Expired ${_formatRecordDate(booking.warrantyExpiresAt!)}',
                  valueStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: booking.isUnderWarranty
                          ? const Color(0xFF1D8A9E)
                          : AppColors.textLight),
                ),
              ],
            ]),
          ),

          // ── Tap hint footer ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.vertical(
                bottom: showBackjob ? Radius.zero : const Radius.circular(20),
              ),
            ),
            child: Row(children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 12, color: AppColors.textLight),
              const SizedBox(width: 6),
              const Text('View full record',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (booking.address != null && booking.address!.isNotEmpty) ...[
                const Icon(Icons.location_on_outlined,
                    size: 12, color: AppColors.textLight),
                const SizedBox(width: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(booking.address!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
          ),

          // ── AYO Guarantee action row ───────────────────────────────────
          if (showBackjob)
            GestureDetector(
              onTap: onBackjob,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A2E3F), Color(0xFF1D8A9E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Request a Backjob',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('FREE',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 11, color: Colors.white70),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Compact record detail row helper ─────────────────────────────────────
  Widget _recordRow(
    IconData icon,
    String label,
    String value, {
    double topPad = 0,
    TextStyle? valueStyle,
  }) =>
      Padding(
        padding: EdgeInsets.only(top: topPad),
        child: Row(children: [
          Icon(icon, size: 13, color: AppColors.textLight),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: valueStyle ??
                    const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  // Formats a DateTime as a clean record date string, e.g. "Sep 14, 2025"
  String _formatRecordDate(DateTime dt) {
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
    final l = dt.toLocal();
    return '${months[l.month - 1]} ${l.day}, ${l.year}';
  }

  // ── Active booking — original compact card layout (unchanged) ─────────────
  Widget _buildActiveCard() {
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
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F8F8),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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

  // FIX: Added `assessment` case — was missing, so assessment bookings
  // showed as orange 'Pending' badge instead of their own amber colour.
  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return const Color(0xFF007AFF);
      case BookingStatus.assessment:
        return const Color(0xFFFF9500);
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

  // FIX: Added `assessment` case — was missing, so assessment bookings
  // showed label 'Pending' instead of 'Price Ready'.
  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.assessment:
        return 'Price Ready';
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
