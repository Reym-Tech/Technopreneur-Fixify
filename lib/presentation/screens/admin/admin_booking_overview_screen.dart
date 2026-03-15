// lib/presentation/screens/admin/admin_booking_overview_screen.dart
//
// AdminBookingOverviewScreen
// ─────────────────────────────────────────────────────────────────────────────
// Shows ALL platform bookings with status filtering and a detail bottom sheet
// that includes completion proof photos for admin transaction tracking.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:intl/intl.dart';

class AdminBookingOverviewScreen extends StatefulWidget {
  final List<BookingEntity> bookings;

  /// Called to load completion proof photos for a specific booking.
  final Future<List<String>> Function(String bookingId) onLoadCompletionPhotos;

  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;

  const AdminBookingOverviewScreen({
    super.key,
    required this.bookings,
    required this.onLoadCompletionPhotos,
    this.onBack,
    this.onRefresh,
  });

  @override
  State<AdminBookingOverviewScreen> createState() =>
      _AdminBookingOverviewScreenState();
}

class _AdminBookingOverviewScreenState
    extends State<AdminBookingOverviewScreen> {
  // ── Filter state ──────────────────────────────────────────────────────────
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const List<_FilterDef> _filters = [
    _FilterDef('All', Icons.list_alt_rounded, AppColors.primary),
    _FilterDef('Pending', Icons.hourglass_empty_rounded, Color(0xFFFF9500)),
    _FilterDef('In Progress', Icons.handyman_rounded, Color(0xFF5856D6)),
    _FilterDef('Completed', Icons.check_circle_rounded, Color(0xFF34C759)),
    _FilterDef('Cancelled', Icons.cancel_rounded, Color(0xFFFF3B30)),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────
  List<BookingEntity> get _filtered {
    var list = widget.bookings;

    // Status filter
    if (_selectedFilter != 'All') {
      list = list.where((b) {
        switch (_selectedFilter) {
          case 'Pending':
            return b.status == BookingStatus.pending ||
                b.status == BookingStatus.accepted ||
                b.status == BookingStatus.scheduleProposed ||
                b.status == BookingStatus.scheduled;
          case 'In Progress':
            return b.status == BookingStatus.pendingArrivalConfirmation ||
                b.status == BookingStatus.assessment ||
                b.status == BookingStatus.inProgress ||
                b.status == BookingStatus.pendingCustomerConfirmation;
          case 'Completed':
            return b.status == BookingStatus.completed;
          case 'Cancelled':
            return b.status == BookingStatus.cancelled;
          default:
            return true;
        }
      }).toList();
    }

    // Search filter
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((b) {
        final customerName = (b.customer?.name ?? '').toLowerCase();
        final proName = (b.professional?.name ?? '').toLowerCase();
        final service = b.serviceType.toLowerCase();
        final address = (b.address ?? '').toLowerCase();
        return customerName.contains(q) ||
            proName.contains(q) ||
            service.contains(q) ||
            address.contains(q);
      }).toList();
    }

    return list;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  int get _completedCount =>
      widget.bookings.where((b) => b.status == BookingStatus.completed).length;

  int get _activeCount => widget.bookings
      .where((b) =>
          b.status != BookingStatus.completed &&
          b.status != BookingStatus.cancelled)
      .length;

  double get _totalRevenue => widget.bookings
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (s, b) {
        final ap = b.assessmentPrice;
        return s + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      });

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildTopBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async {},
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                // ── Stats strip ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: _buildStatsStrip(),
                  ).animate().fadeIn(delay: 80.ms),
                ),

                // ── Search bar ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _buildSearchBar(),
                  ).animate().fadeIn(delay: 100.ms),
                ),

                // ── Filter chips ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 0, 8),
                    child: _buildFilterChips(),
                  ).animate().fadeIn(delay: 120.ms),
                ),

                // ── Count label ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Text(
                      '${filtered.length} booking${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                // ── Booking list ────────────────────────────────────────
                filtered.isEmpty
                    ? SliverFillRemaining(
                        child: _buildEmpty(),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _BookingRow(
                              booking: filtered[i],
                              onTap: () => _showDetail(filtered[i]),
                            )
                                .animate()
                                .fadeIn(delay: (i * 30).ms)
                                .slideX(begin: 0.03, end: 0),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────────────────────

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
                    Text('Booking Overview',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text('All platform bookings',
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

  // ── STATS STRIP ───────────────────────────────────────────────────────────

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
            _statItem(Icons.list_alt_rounded, '${widget.bookings.length}',
                'Total', AppColors.primary),
            _vDivider(),
            _statItem(Icons.autorenew_rounded, '$_activeCount', 'Active',
                const Color(0xFF5856D6)),
            _vDivider(),
            _statItem(Icons.check_circle_rounded, '$_completedCount',
                'Completed', const Color(0xFF34C759)),
            _vDivider(),
            _statItem(
                Icons.payments_rounded,
                '₱${_totalRevenue.toStringAsFixed(0)}',
                'Revenue',
                const Color(0xFFFF9500)),
          ],
        ),
      );

  Widget _statItem(IconData icon, String value, String label, Color color) =>
      Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500)),
      ]);

  Widget _vDivider() =>
      Container(width: 1, height: 36, color: const Color(0xFFEEEEEE));

  // ── SEARCH BAR ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() => Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Search by customer, handyman, service…',
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textLight),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 18, color: AppColors.textLight),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() {
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textLight),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          ),
        ),
      );

  // ── FILTER CHIPS ──────────────────────────────────────────────────────────

  Widget _buildFilterChips() => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          padding: const EdgeInsets.only(right: 20),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _filters[i];
            final selected = _selectedFilter == f.label;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f.label),
              child: AnimatedContainer(
                duration: 150.ms,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? f.color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : const Color(0xFFDDDDDD)),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color: f.color.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.icon,
                      size: 13, color: selected ? Colors.white : f.color),
                  const SizedBox(width: 6),
                  Text(f.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textDark)),
                ]),
              ),
            );
          },
        ),
      );

  // ── EMPTY STATE ───────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  shape: BoxShape.circle),
              child: const Icon(Icons.assignment_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No bookings found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Try adjusting the filter or search.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textLight, height: 1.5),
                textAlign: TextAlign.center),
          ]),
        ),
      );

  // ── DETAIL SHEET ──────────────────────────────────────────────────────────

  void _showDetail(BookingEntity booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(
        booking: booking,
        onLoadCompletionPhotos: widget.onLoadCompletionPhotos,
      ),
    );
  }
}

// ── Filter definition ─────────────────────────────────────────────────────────

class _FilterDef {
  final String label;
  final IconData icon;
  final Color color;
  const _FilterDef(this.label, this.icon, this.color);
}

// ── Booking Row ───────────────────────────────────────────────────────────────

class _BookingRow extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onTap;

  const _BookingRow({required this.booking, required this.onTap});

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.pending:
        return const Color(0xFFFF9500);
      case BookingStatus.accepted:
      case BookingStatus.scheduleProposed:
      case BookingStatus.scheduled:
        return const Color(0xFF007AFF);
      case BookingStatus.pendingArrivalConfirmation:
      case BookingStatus.assessment:
      case BookingStatus.inProgress:
      case BookingStatus.pendingCustomerConfirmation:
        return const Color(0xFF5856D6);
      case BookingStatus.completed:
        return const Color(0xFF34C759);
      case BookingStatus.cancelled:
        return const Color(0xFFFF3B30);
    }
  }

  String get _statusLabel {
    switch (booking.status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.scheduleProposed:
        return 'Reschedule';
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.pendingArrivalConfirmation:
        return 'Arriving';
      case BookingStatus.assessment:
        return 'Assessment';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.pendingCustomerConfirmation:
        return 'Confirming';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = booking.professional;
    final customer = booking.customer;
    final price =
        booking.assessmentPrice != null && booking.assessmentPrice! > 0
            ? '₱${booking.assessmentPrice!.toStringAsFixed(0)}'
            : booking.priceEstimate != null
                ? '₱${booking.priceEstimate!.toStringAsFixed(0)}'
                : '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 12),
            decoration:
                BoxDecoration(color: _statusColor, shape: BoxShape.circle),
          ),
          // Main info
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(booking.serviceType,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _statusColor)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${customer?.name ?? 'Customer'} → ${pro?.name ?? 'Unassigned'}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 10, color: AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy')
                      .format(booking.scheduledDate.toLocal()),
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
                const Spacer(),
                Text(price,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight, size: 18),
        ]),
      ),
    );
  }
}

// ── Booking Detail Sheet ──────────────────────────────────────────────────────

class _BookingDetailSheet extends StatefulWidget {
  final BookingEntity booking;
  final Future<List<String>> Function(String bookingId) onLoadCompletionPhotos;

  const _BookingDetailSheet({
    required this.booking,
    required this.onLoadCompletionPhotos,
  });

  @override
  State<_BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<_BookingDetailSheet> {
  Future<List<String>>? _photosFuture;

  @override
  void initState() {
    super.initState();
    // Only load photos for completed/confirming bookings
    if (widget.booking.status == BookingStatus.completed ||
        widget.booking.status == BookingStatus.pendingCustomerConfirmation) {
      _photosFuture = widget.onLoadCompletionPhotos(widget.booking.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final pro = b.professional;
    final customer = b.customer;
    final price = b.assessmentPrice != null && b.assessmentPrice! > 0
        ? '₱${b.assessmentPrice!.toStringAsFixed(0)}'
        : b.priceEstimate != null
            ? '₱${b.priceEstimate!.toStringAsFixed(0)} (estimate)'
            : 'Not set';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(children: [
        // Drag handle
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: Text(b.serviceType,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.2)),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textDark),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Booking ID: ${b.id.substring(0, 8).toUpperCase()}…',
              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Info grid ──────────────────────────────────────────
              _infoCard([
                _infoRow(
                    Icons.person_rounded, 'Customer', customer?.name ?? '—'),
                _infoRow(Icons.engineering_rounded, 'Handyman',
                    pro?.name ?? 'Unassigned'),
                _infoRow(Icons.payments_rounded, 'Price', price),
                _infoRow(
                    Icons.calendar_today_rounded,
                    'Scheduled',
                    DateFormat('MMM d, yyyy · h:mm a')
                        .format(b.scheduledDate.toLocal())),
                if (b.address != null && b.address!.isNotEmpty)
                  _infoRow(Icons.location_on_rounded, 'Address', b.address!),
                if (b.description != null && b.description!.isNotEmpty)
                  _infoRow(Icons.description_rounded, 'Issue', b.description!),
                if (b.notes != null && b.notes!.isNotEmpty)
                  _infoRow(Icons.notes_rounded, 'Notes', b.notes!),
              ]),
              const SizedBox(height: 16),

              // ── Issue photo (customer's upload) ─────────────────────
              if (b.photoUrl != null && b.photoUrl!.isNotEmpty) ...[
                const Text('Issue Photo',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(b.photoUrl!,
                      width: double.infinity, height: 180, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
              ],

              // ── Completion proof photos ─────────────────────────────
              if (_photosFuture != null) ...[
                const Text('Completion Proof',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 10),
                FutureBuilder<List<String>>(
                  future: _photosFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary)),
                        ),
                      );
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No proof photos uploaded for this booking.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textLight),
                        ),
                      );
                    }
                    final urls = snap.data!;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: urls.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => _showFullscreen(context, urls, i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(urls[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFF0F4F2),
                                    child: const Icon(
                                        Icons.broken_image_rounded,
                                        color: AppColors.textLight),
                                  )),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _infoCard(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: rows),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 14, color: AppColors.textLight),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textLight)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
        ]),
      );

  void _showFullscreen(BuildContext context, List<String> urls, int initial) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Image.network(urls[i], fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
