// lib/presentation/screens/professional/booking_requests_professional.dart
//
// BookingRequestsScreen — Professional's incoming booking requests (navIndex=1).
//
// Shows PENDING bookings only with Accept / Decline actions.
// Tap card → expands to show full details.
// When the pro is offline an overlay banner blocks new accepts and explains why.
//
// Props:
//   bookings        → List<BookingEntity>   — all pro bookings (filtered internally to pending)
//   isAvailable     → bool                  — mirrors the toggle state from main.dart
//   onAccept        → Function(BookingEntity)
//   onDecline       → Function(BookingEntity)
//   onNavTap        → Function(int)
//   currentNavIndex → int
//   onRefresh       → Future<void> Function()?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class BookingRequestsScreen extends StatefulWidget {
  final List<BookingEntity> bookings;
  final bool isAvailable;
  final Function(BookingEntity)? onAccept;
  final Function(BookingEntity)? onDecline;
  final Function(int)? onNavTap;
  final int currentNavIndex;
  final Future<void> Function()? onRefresh;

  const BookingRequestsScreen({
    super.key,
    this.bookings = const [],
    this.isAvailable = true,
    this.onAccept,
    this.onDecline,
    this.onNavTap,
    this.currentNavIndex = 1,
    this.onRefresh,
  });

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  String? _expandedId;

  List<BookingEntity> get _pending =>
      widget.bookings.where((b) => b.status == BookingStatus.pending).toList();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onNavTap?.call(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(),
          // ── Offline banner ─────────────────────────────────────────
          if (!widget.isAvailable) _buildOfflineBanner(),
          Expanded(child: _pending.isEmpty ? _empty() : _buildList()),
        ]),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── OFFLINE BANNER ────────────────────────────────────────

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.wifi_off_rounded,
              color: Color(0xFFFF3B30), size: 22),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'re currently Offline',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF3B30),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Customers cannot find or book you. '
                'Toggle Online from your Dashboard to receive new requests.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  // ── HEADER ────────────────────────────────────────────────

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
                onTap: () => widget.onNavTap?.call(0),
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
                    const Text('Booking Requests',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    Text(
                      '${_pending.length} pending request${_pending.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Status pill next to count badge
              Row(children: [
                // Online / Offline pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: widget.isAvailable
                        ? const Color(0xFF34C759).withOpacity(0.18)
                        : const Color(0xFFFF3B30).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isAvailable
                          ? const Color(0xFF34C759).withOpacity(0.4)
                          : const Color(0xFFFF3B30).withOpacity(0.4),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.isAvailable
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.isAvailable ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: widget.isAvailable
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF9090),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ),
                if (_pending.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.4)),
                    ),
                    child: Text('${_pending.length} New',
                        style: const TextStyle(
                            color: Color(0xFFFF9090),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      );

  Widget _buildList() => RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: _pending.length,
          itemBuilder: (ctx, i) {
            final b = _pending[i];
            final expanded = _expandedId == b.id;
            return _RequestCard(
              booking: b,
              expanded: expanded,
              // Disable accept/decline when offline — pro must go online first
              isAvailable: widget.isAvailable,
              onTap: () => setState(() => _expandedId = expanded ? null : b.id),
              onAccept:
                  widget.isAvailable ? () => widget.onAccept?.call(b) : null,
              onDecline: () => widget.onDecline?.call(b),
            ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.06, end: 0);
          },
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_rounded,
                  size: 52, color: AppColors.primary.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            const Text('No pending requests',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(
              widget.isAvailable
                  ? 'New booking requests from customers will appear here.'
                  : 'You\'re offline. Go online from your Dashboard to start receiving requests.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
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
}

// ── Request Card (expandable) ──────────────────────────────────

class _RequestCard extends StatelessWidget {
  final BookingEntity booking;
  final bool expanded;
  final bool isAvailable;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _RequestCard({
    required this.booking,
    required this.expanded,
    required this.isAvailable,
    this.onTap,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expanded
                ? AppColors.primary.withOpacity(0.3)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: expanded
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.06),
              blurRadius: expanded ? 16 : 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Summary row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.assignment_rounded,
                    color: Color(0xFFFF9500), size: 22),
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
                      'Requested ${_timeAgo(booking.scheduledDate)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textLight,
                size: 20,
              ),
            ]),
          ),

          // Expanded details
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (booking.address != null && booking.address!.isNotEmpty)
                    _detailRow(Icons.location_on_outlined, 'Location',
                        booking.address!),
                  if (booking.notes != null && booking.notes!.isNotEmpty)
                    _detailRow(Icons.notes_rounded, 'Notes', booking.notes!),
                  _detailRow(Icons.calendar_today_outlined, 'Scheduled',
                      '${booking.scheduledDate.day}/${booking.scheduledDate.month}/${booking.scheduledDate.year}'),
                  if (booking.priceEstimate != null)
                    _detailRow(Icons.payments_outlined, 'Estimated Rate',
                        '₱${booking.priceEstimate!.toStringAsFixed(0)}/hr'),
                ],
              ),
            ),
          ],

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(children: [
              // Offline warning on the card itself
              if (!isAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFF3B30).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.wifi_off_rounded,
                            size: 13, color: Color(0xFFFF3B30)),
                        SizedBox(width: 6),
                        Text(
                          'Go Online to accept requests',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF3B30)),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF3B30)),
                      foregroundColor: const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // null disables the button when offline
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable
                          ? AppColors.primary
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: AppColors.textLight),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark)),
            ),
          ]),
        ]),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt).abs();
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
