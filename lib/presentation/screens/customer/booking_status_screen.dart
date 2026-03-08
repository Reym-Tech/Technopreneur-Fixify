// lib/presentation/screens/customer/booking_status_screen.dart
//
// BookingStatusScreen — 4-step status timeline for a customer booking.
//
// Changes from previous version:
//  • Assessment CTA is visible for both Accepted AND InProgress statuses
//    so customer can re-view the assessment details any time.
//  • Assessment CTA shows dynamic price status:
//      - "Awaiting price…" (orange) when assessmentPrice is null
//      - "₱XXX — Tap to review" (green) when price is set
//  • Professional card uses actual avatar photo (_ProAvatar widget)
//    instead of just the first-letter initial.
//  • Bottom sheet also uses _ProAvatar.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class BookingStatusScreen extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onBack;
  final VoidCallback? onWriteReview;
  final VoidCallback? onCancelBooking;

  /// Called when customer taps "Assessment Ready" → navigates to AssessmentScreen.
  final VoidCallback? onViewAssessment;

  const BookingStatusScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onWriteReview,
    this.onCancelBooking,
    this.onViewAssessment,
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
  bool get _isAccepted => booking.status == BookingStatus.accepted;
  bool get _isInProgress => booking.status == BookingStatus.inProgress;

  bool get _showProfessional =>
      booking.professional != null &&
      booking.status != BookingStatus.pending &&
      !_isCancelled;

  /// Show the Assessment CTA for both Accepted and InProgress so the
  /// customer can always get back to the assessment / price details.
  bool get _showAssessmentCTA =>
      (_isAccepted || _isInProgress) && onViewAssessment != null;

  bool get _priceSet => booking.assessmentPrice != null;

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
            _buildStatusCard(),
            const SizedBox(height: 20),
            if (booking.status == BookingStatus.pending) ...[
              _buildPendingNotice(),
              const SizedBox(height: 20),
            ],
            if (_showAssessmentCTA) ...[
              _buildAssessmentCTA(context),
              const SizedBox(height: 20),
            ],
            _buildDetailsCard(),
            const SizedBox(height: 20),
            if (_showProfessional) ...[
              _buildProfessionalCard(context),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── Assessment CTA ────────────────────────────────────────────────────────

  Widget _buildAssessmentCTA(BuildContext context) {
    final bool priceReady = _priceSet;
    final String priceLabel = priceReady
        ? '₱${booking.assessmentPrice!.toStringAsFixed(2)} — Tap to review'
        : 'Awaiting handyman\'s price…';
    final Color statusColor =
        priceReady ? const Color(0xFF34C759) : const Color(0xFFFF9500);

    return GestureDetector(
      onTap: onViewAssessment,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3D2E), Color(0xFF1A5C43)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              priceReady
                  ? Icons.price_check_rounded
                  : Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                priceReady ? 'Assessment Ready' : 'Awaiting Assessment',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    priceLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white70, size: 22),
        ]),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: -0.05);
  }

  // ── Pending Notice ─────────────────────────────────────────────────────────

  Widget _buildPendingNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child:
                Icon(Icons.search_rounded, color: Color(0xFFFF9500), size: 20),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Looking for a handyman…',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9500),
                      fontSize: 13),
                ),
                SizedBox(height: 3),
                Text(
                  'Your request is being reviewed by available professionals. '
                  'A handyman will be assigned once someone accepts.',
                  style: TextStyle(
                      color: AppColors.textLight, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }

  // ── Status Timeline Card ───────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final steps = [
      _StepInfo(
          label: 'Pending',
          sub: 'Waiting for professional to accept',
          icon: Icons.schedule_rounded),
      _StepInfo(
          label: 'Accepted',
          sub: 'Professional accepted the booking',
          icon: Icons.thumb_up_rounded),
      _StepInfo(
          label: 'In Progress',
          sub: 'Service is underway',
          icon: Icons.build_rounded),
      _StepInfo(
          label: 'Completed',
          sub: 'Service finished',
          icon: Icons.check_circle_rounded),
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
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  steps.length, (i) => _buildStep(steps[i], i, steps.length))),
      ]),
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
      child: const Row(children: [
        Icon(Icons.cancel_rounded, color: Color(0xFFFF3B30), size: 22),
        SizedBox(width: 10),
        Expanded(
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
        SizedBox(
          width: 32,
          child: Column(children: [
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
                            spreadRadius: 2)
                      ]
                    : null,
              ),
              child: Icon(step.icon,
                  size: 16,
                  color: isActive ? Colors.white : Colors.grey.shade500),
            ),
            if (!isLast)
              Container(
                  width: 2,
                  height: 40,
                  color: index < _statusStep ? activeColor : inactiveColor),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          isActive ? AppColors.textDark : AppColors.textLight)),
              const SizedBox(height: 2),
              Text(step.sub,
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          isCurrent ? AppColors.primary : AppColors.textLight,
                      fontWeight:
                          isCurrent ? FontWeight.w500 : FontWeight.w400)),
            ]),
          ),
        ),
        if (isCurrent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: activeColor))
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
    final dateStr = _formatDate(booking.scheduledDate);
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
        ),
      ]),
    );
  }

  // ── Professional Card (tappable → profile sheet) ──────────────────────────

  Widget _buildProfessionalCard(BuildContext context) {
    final pro = booking.professional!;

    return GestureDetector(
      onTap: () => _showHandymanSheet(context, pro),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          Row(children: [
            const Icon(Icons.person_pin_rounded,
                size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('Your Handyman',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const Spacer(),
            if (_isAccepted || _isInProgress)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline_rounded,
                      size: 11, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('View Profile',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            // ── Use actual avatar photo ──────────────────────────────────
            _ProAvatar(name: pro.name, avatarUrl: pro.avatarUrl, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(pro.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (pro.verified) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 11, color: Color(0xFF34C759)),
                                SizedBox(width: 3),
                                Text('Verified',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF34C759))),
                              ]),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      ...List.generate(
                          5,
                          (i) => Icon(
                                i < pro.rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 14,
                                color: const Color(0xFFFF9F0A),
                              )),
                      const SizedBox(width: 5),
                      Text(pro.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ]),
            ),
            if (_isAccepted || _isInProgress)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textLight, size: 20),
          ]),
        ]),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  void _showHandymanSheet(BuildContext context, ProfessionalEntity pro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandymanProfileSheet(
        pro: pro,
        onViewAssessment: onViewAssessment,
        isAccepted: _isAccepted || _isInProgress,
        priceSet: _priceSet,
        assessmentPrice: booking.assessmentPrice,
      ),
    );
  }

  // ── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget? _buildBottomBar(BuildContext context) {
    if (onCancelBooking == null && onWriteReview == null) return null;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
      ]),
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
              child: const Text('Keep')),
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

// ── Handyman Profile Bottom Sheet ─────────────────────────────────────────────

class _HandymanProfileSheet extends StatelessWidget {
  final ProfessionalEntity pro;
  final VoidCallback? onViewAssessment;
  final bool isAccepted;
  final bool priceSet;
  final double? assessmentPrice;

  const _HandymanProfileSheet({
    required this.pro,
    this.onViewAssessment,
    required this.isAccepted,
    required this.priceSet,
    this.assessmentPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Header ──────────────────────────────────────────────────
              Row(children: [
                _ProAvatar(name: pro.name, avatarUrl: pro.avatarUrl, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(pro.name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (pro.verified) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF34C759).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(7)),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        size: 12, color: Color(0xFF34C759)),
                                    SizedBox(width: 3),
                                    Text('Verified',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF34C759))),
                                  ]),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          ...List.generate(
                              5,
                              (i) => Icon(
                                    i < pro.rating.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: const Color(0xFFFF9F0A),
                                  )),
                          const SizedBox(width: 6),
                          Text(
                              '${pro.rating.toStringAsFixed(1)} · ${pro.reviewCount} reviews',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMedium,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ]),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Info pills ───────────────────────────────────────────────
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (pro.yearsExperience > 0)
                  _pill(Icons.work_history_rounded,
                      '${pro.yearsExperience} yr${pro.yearsExperience == 1 ? '' : 's'} exp'),
                if (pro.city != null && pro.city!.isNotEmpty)
                  _pill(Icons.location_on_rounded, pro.city!),
                if (pro.priceMin != null)
                  _pill(Icons.payments_rounded,
                      'From ₱${pro.priceMin!.toStringAsFixed(0)}'),
                if (pro.skills.isNotEmpty)
                  ...pro.skills.map((s) => _pill(Icons.build_rounded,
                      '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}')),
              ]),

              // ── Bio ──────────────────────────────────────────────────────
              if (pro.bio != null && pro.bio!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('About',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 6),
                Text(pro.bio!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textLight, height: 1.5)),
              ],

              const SizedBox(height: 24),
            ]),
          ),
        ),

        // ── CTA ─────────────────────────────────────────────────────────────
        if (isAccepted && onViewAssessment != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                  priceSet
                      ? Icons.price_check_rounded
                      : Icons.hourglass_top_rounded,
                  size: 18,
                ),
                label: Text(priceSet
                    ? 'Review Price  ·  ₱${assessmentPrice!.toStringAsFixed(2)}'
                    : 'View Assessment (Price Pending)'),
                onPressed: () {
                  Navigator.pop(context);
                  onViewAssessment?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      priceSet ? AppColors.primary : const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                  elevation: 0,
                ),
              ),
            ),
          )
        else
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ]),
    );
  }

  Widget _pill(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ]),
      );
}

// ── Reusable avatar ───────────────────────────────────────────────────────────

class _ProAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _ProAvatar(
      {required this.name, required this.avatarUrl, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.27),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, prog) =>
              prog == null ? child : _placeholder(initial),
          errorBuilder: (_, __, ___) => _placeholder(initial),
        ),
      );
    }
    return _placeholder(initial);
  }

  Widget _placeholder(String letter) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        child: Center(
          child: Text(letter,
              style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      );
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _StepInfo {
  final String label, sub;
  final IconData icon;
  const _StepInfo({required this.label, required this.sub, required this.icon});
}
