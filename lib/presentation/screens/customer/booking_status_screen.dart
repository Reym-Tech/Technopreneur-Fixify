// lib/presentation/screens/customer/booking_status_screen.dart
//
// BookingStatusScreen — shows the 4-step status timeline for a customer booking.
//
// Fixed issues:
//  • Professional card "Verified" badge no longer overflows off-screen (RIGHT_OVERFLOW)
//  • Professional card now uses proper layout constraints with Flexible/Expanded
//  • Notes section wraps correctly for multi-line text

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class BookingStatusScreen extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onBack;
  final VoidCallback? onWriteReview;
  final VoidCallback? onCancelBooking;

  const BookingStatusScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onWriteReview,
    this.onCancelBooking,
  });

  // ── Status helpers ─────────────────────────────────────────────────────────

  int get _statusStep {
    switch (booking.status) {
      case BookingStatus.pending:
        return 0;
      case BookingStatus.accepted:
        return 1;
      case BookingStatus.inProgress:
        return 2;
      case BookingStatus.completed:
        return 3;
      default:
        return 0;
    }
  }

  bool get _isCancelled => booking.status == BookingStatus.cancelled;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3D2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: onBack,
        ),
        title: const Text('Booking Status',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status timeline ──────────────────────────────────────────────
            _buildStatusCard(),
            const SizedBox(height: 20),

            // ── Booking details ──────────────────────────────────────────────
            _buildDetailsCard(),
            const SizedBox(height: 20),

            // ── Professional card ────────────────────────────────────────────
            if (booking.professional != null) ...[
              _buildProfessionalCard(),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),

      // ── Bottom action buttons ──────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── Status Timeline Card ───────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final steps = [
      _StepInfo(
        label: 'Pending',
        sub: 'Waiting for professional to accept',
        icon: Icons.schedule_rounded,
      ),
      _StepInfo(
        label: 'Accepted',
        sub: 'Professional accepted the booking',
        icon: Icons.thumb_up_rounded,
      ),
      _StepInfo(
        label: 'In Progress',
        sub: 'Service is underway',
        icon: Icons.build_rounded,
      ),
      _StepInfo(
        label: 'Completed',
        sub: 'Service finished',
        icon: Icons.check_circle_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.track_changes_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              _isCancelled ? 'Booking Cancelled' : 'Booking Progress',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
          ]),
          const SizedBox(height: 20),
          if (_isCancelled)
            _cancelledBanner()
          else
            Column(
              children: List.generate(
                  steps.length, (i) => _buildStep(steps[i], i, steps.length)),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _cancelledBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.cancel_rounded, color: Color(0xFFFF3B30), size: 22),
        const SizedBox(width: 10),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Booking Cancelled',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF3B30),
                    fontSize: 14)),
            SizedBox(height: 2),
            Text('This booking has been cancelled.',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStep(_StepInfo step, int index, int total) {
    final isActive = index <= _statusStep;
    final isCurrent = index == _statusStep;
    final isLast = index == total - 1;

    final activeColor = AppColors.primary;
    final inactiveColor = Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: circle + line ──
        SizedBox(
          width: 32,
          child: Column(children: [
            // Step circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? activeColor : inactiveColor,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(step.icon,
                  size: 16,
                  color: isActive ? Colors.white : Colors.grey.shade500),
            ),
            // Connector line
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: index < _statusStep ? activeColor : inactiveColor,
              ),
          ]),
        ),
        const SizedBox(width: 14),

        // ── Right: label + sub ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.textDark : AppColors.textLight,
                  )),
              const SizedBox(height: 2),
              Text(step.sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCurrent ? AppColors.primary : AppColors.textLight,
                    fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
                  )),
            ]),
          ),
        ),

        // ── Active dot ──
        if (isCurrent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.6, 1.6),
                    duration: 700.ms,
                    curve: Curves.easeInOut)
                .then()
                .scale(
                    begin: const Offset(1.6, 1.6),
                    end: const Offset(1, 1),
                    duration: 700.ms,
                    curve: Curves.easeInOut),
          ),
      ],
    );
  }

  // ── Booking Details Card ───────────────────────────────────────────────────

  Widget _buildDetailsCard() {
    final date = booking.scheduledDate;
    final dateStr = _formatDate(date);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Booking Details',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 16),
        _detailRow(Icons.build_circle_rounded, 'Service', booking.serviceType),
        _detailRow(Icons.calendar_month_rounded, 'Scheduled', dateStr),
        if (booking.address != null && booking.address!.isNotEmpty)
          _detailRow(Icons.location_on_rounded, 'Address', booking.address!),
        if (booking.notes != null && booking.notes!.isNotEmpty)
          _detailRow(Icons.notes_rounded, 'Notes', booking.notes!),
      ]),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Professional Card ──────────────────────────────────────────────────────
  // FIX: Uses Flexible/Expanded properly so "Verified" badge never overflows.

  Widget _buildProfessionalCard() {
    final pro = booking.professional!;
    final verified = pro.verified;
    final rating = pro.rating;
    final initial = pro.name.isNotEmpty ? pro.name[0].toUpperCase() : 'P';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 12),

          // Name + rating — constrained so badge can't push it off screen
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row — "Verified" badge is INSIDE the Row with Flexible
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        pro.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.verified_rounded,
                                size: 11, color: Color(0xFF34C759)),
                            SizedBox(width: 3),
                            Text('Verified',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF34C759))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),

                // Stars + rating
                Row(children: [
                  ...List.generate(
                      5,
                      (i) => Icon(
                            i < rating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: const Color(0xFFFF9F0A),
                          )),
                  const SizedBox(width: 5),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget? _buildBottomBar(BuildContext context) {
    if (onCancelBooking == null && onWriteReview == null) return null;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onWriteReview != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.rate_review_rounded, size: 18),
                label: const Text('Write a Review'),
                onPressed: onWriteReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          if (onWriteReview != null && onCancelBooking != null)
            const SizedBox(height: 10),
          if (onCancelBooking != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Booking'),
                onPressed: () => _confirmCancel(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  side: const BorderSide(color: Color(0xFFFF3B30)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Booking',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
            'Are you sure you want to cancel this booking? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancelBooking?.call();
            },
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    const months = [
      '',
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
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month]} ${d.day}, ${d.year} at $h:$m';
  }
}

// ── Internal helpers ─────────────────────────────────────────────────────────

class _StepInfo {
  final String label;
  final String sub;
  final IconData icon;
  const _StepInfo({required this.label, required this.sub, required this.icon});
}
