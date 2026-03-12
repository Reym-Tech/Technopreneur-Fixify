// lib/presentation/screens/customer/booking_status_screen.dart
//
// SCHEDULING UPDATE:
//   • Timeline now shows 7 steps:
//       Pending → Accepted → Schedule Proposed → Scheduled →
//       Assessment → In Progress → Completed
//   • When status == scheduleProposed: shows a pulsing "Review Schedule" CTA
//     that routes to ScheduleReviewScreen via onReviewSchedule().
//     The CTA now also shows the customer's original preferred date so they
//     can compare against the handyman's proposed time at a glance.
//   • AssessmentCTA is now only shown for status == assessment (not accepted).
//   • _statusLabel / _statusMessage updated for new statuses.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:intl/intl.dart';

class BookingStatusScreen extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onBack;
  final VoidCallback? onViewAssessment;

  /// Called when the customer taps "Review Schedule".
  /// Parent navigates to ScheduleReviewScreen.
  final VoidCallback? onReviewSchedule;

  const BookingStatusScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onViewAssessment,
    this.onReviewSchedule,
  });

  // ── Step helpers ───────────────────────────────────────────────────────────

  static const List<BookingStatus> _steps = [
    BookingStatus.pending,
    BookingStatus.accepted,
    BookingStatus.scheduleProposed,
    BookingStatus.scheduled,
    BookingStatus.assessment,
    BookingStatus.inProgress,
    BookingStatus.completed,
  ];

  int get _currentStepIndex {
    if (booking.status == BookingStatus.cancelled) return -1;
    return _steps.indexOf(booking.status);
  }

  String _stepLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.scheduleProposed:
        return 'Schedule\nProposed';
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.assessment:
        return 'Assessment';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      default:
        return '';
    }
  }

  // ── Status display helpers ─────────────────────────────────────────────────

  String get _statusLabel {
    switch (booking.status) {
      case BookingStatus.pending:
        return 'Finding Handyman';
      case BookingStatus.accepted:
        return 'Handyman Assigned';
      case BookingStatus.scheduleProposed:
        return 'Schedule Proposed';
      case BookingStatus.scheduled:
        return 'Job Scheduled';
      case BookingStatus.assessment:
        return 'Assessment Ready';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get _statusMessage {
    switch (booking.status) {
      case BookingStatus.pending:
        return 'We\'re matching you with an available handyman. This usually takes just a few minutes.';
      case BookingStatus.accepted:
        return 'A handyman has accepted your request and is setting up a schedule for your job.';
      case BookingStatus.scheduleProposed:
        return 'Your handyman has proposed a start time. Please review and confirm the schedule below.';
      case BookingStatus.scheduled:
        return 'You\'ve confirmed the schedule. Your handyman will arrive at the agreed time.';
      case BookingStatus.assessment:
        return 'Your handyman has assessed the job and set a price. Please review and confirm to get started.';
      case BookingStatus.inProgress:
        return 'Your handyman is currently working on the job.';
      case BookingStatus.completed:
        return 'Your job has been completed. Thank you for using AYO!';
      case BookingStatus.cancelled:
        return 'This booking has been cancelled.';
    }
  }

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.pending:
        return const Color(0xFFFF9500);
      case BookingStatus.accepted:
        return const Color(0xFF007AFF);
      case BookingStatus.scheduleProposed:
        return const Color(0xFFFF9500);
      case BookingStatus.scheduled:
        return const Color(0xFF007AFF);
      case BookingStatus.assessment:
        return const Color(0xFF5856D6);
      case BookingStatus.inProgress:
        return const Color(0xFF34C759);
      case BookingStatus.completed:
        return AppColors.primary;
      case BookingStatus.cancelled:
        return const Color(0xFFFF3B30);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard()
                        .animate()
                        .fadeIn(delay: 80.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 16),

                    _buildTimeline()
                        .animate()
                        .fadeIn(delay: 150.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 16),

                    // ── Schedule Review CTA ──────────────────────────────
                    if (booking.status == BookingStatus.scheduleProposed) ...[
                      _buildScheduleCTA()
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(
                              duration: 2000.ms,
                              color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 16),
                    ],

                    // ── Assessment CTA ───────────────────────────────────
                    if (booking.status == BookingStatus.assessment) ...[
                      AssessmentCTA(
                        booking: booking,
                        onViewAssessment: onViewAssessment,
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: 16),
                    ],

                    _buildBookingInfo()
                        .animate()
                        .fadeIn(delay: 280.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

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
                onTap: onBack,
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
                      const Text('Booking Status',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      Text(booking.serviceType,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );

  // ── Status Card ────────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    if (booking.status == BookingStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B30).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.cancel_rounded,
                color: Color(0xFFFF3B30), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Booking Cancelled',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF3B30))),
              const SizedBox(height: 4),
              Text(_statusMessage,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium)),
            ]),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _statusColor.withOpacity(0.1),
            _statusColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(_statusIcon, color: _statusColor, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_statusLabel,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _statusColor)),
            const SizedBox(height: 4),
            Text(_statusMessage,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  IconData get _statusIcon {
    switch (booking.status) {
      case BookingStatus.pending:
        return Icons.search_rounded;
      case BookingStatus.accepted:
        return Icons.person_rounded;
      case BookingStatus.scheduleProposed:
        return Icons.schedule_rounded;
      case BookingStatus.scheduled:
        return Icons.event_available_rounded;
      case BookingStatus.assessment:
        return Icons.receipt_long_rounded;
      case BookingStatus.inProgress:
        return Icons.handyman_rounded;
      case BookingStatus.completed:
        return Icons.check_circle_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  Widget _buildTimeline() {
    final currentIdx = _currentStepIndex;
    final isCancelled = booking.status == BookingStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Progress',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 20),
        if (isCancelled)
          _cancelledTimeline()
        else
          ..._steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            final isDone = i < currentIdx;
            final isActive = i == currentIdx;
            final isLast = i == _steps.length - 1;

            return _TimelineStep(
              label: _stepLabel(step),
              isDone: isDone,
              isActive: isActive,
              isLast: isLast,
              activeColor: _colorForStep(step),
            );
          }),
      ]),
    );
  }

  Widget _cancelledTimeline() => Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded,
              color: Color(0xFFFF3B30), size: 18),
        ),
        const SizedBox(width: 12),
        const Text('This booking was cancelled.',
            style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
      ]);

  Color _colorForStep(BookingStatus s) {
    switch (s) {
      case BookingStatus.scheduleProposed:
        return const Color(0xFFFF9500);
      case BookingStatus.assessment:
        return const Color(0xFF5856D6);
      case BookingStatus.inProgress:
        return const Color(0xFF34C759);
      case BookingStatus.completed:
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  // ── Schedule CTA ───────────────────────────────────────────────────────────
  // Shows the handyman's proposed time prominently.
  // Also shows the customer's original preferred date so they can compare.

  Widget _buildScheduleCTA() {
    final proposedTime = booking.scheduledTime;
    final proposedStr = proposedTime != null
        ? DateFormat('MMM d · h:mm a').format(proposedTime.toLocal())
        : null;

    // Customer's original preferred date (what they asked for when booking)
    final preferredStr =
        DateFormat('MMM d, yyyy').format(booking.scheduledDate.toLocal());

    return GestureDetector(
      onTap: onReviewSchedule,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9500), Color(0xFFFFB340)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF9500).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Schedule Proposed!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              if (proposedStr != null)
                Text(
                  'Proposed: $proposedStr',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 2),
              Text(
                'Your request: $preferredStr  •  Tap to review',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 11),
              ),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  // ── Booking Info ───────────────────────────────────────────────────────────

  Widget _buildBookingInfo() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
          _infoRow(Icons.build_rounded, 'Service', booking.serviceType),
          if (booking.professional != null) ...[
            const SizedBox(height: 12),
            _infoRow(
                Icons.person_rounded, 'Handyman', booking.professional!.name),
          ],
          const SizedBox(height: 12),
          _infoRow(
            Icons.calendar_today_rounded,
            'Requested Date',
            DateFormat('MMM d, yyyy').format(booking.scheduledDate),
          ),
          if (booking.scheduledTime != null) ...[
            const SizedBox(height: 12),
            _infoRow(
              Icons.schedule_rounded,
              'Confirmed Start',
              DateFormat('MMM d, yyyy · h:mm a')
                  .format(booking.scheduledTime!.toLocal()),
            ),
          ],
          if (booking.address != null && booking.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.location_on_rounded, 'Location', booking.address!),
          ],
          if (booking.assessmentPrice != null) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.payments_rounded, 'Agreed Price',
                '₱${booking.assessmentPrice!.toStringAsFixed(0)}'),
          ],
          if (booking.description != null &&
              booking.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.notes_rounded, 'Notes', booking.description!),
          ],
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
            ]),
          ),
        ],
      );
}

// ── Timeline Step Widget ───────────────────────────────────────────────────────

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final Color activeColor;

  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 24,
        child: Column(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDone
                  ? activeColor
                  : isActive
                      ? activeColor.withOpacity(0.15)
                      : Colors.grey.shade200,
              shape: BoxShape.circle,
              border:
                  isActive ? Border.all(color: activeColor, width: 2) : null,
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : isActive
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: activeColor, shape: BoxShape.circle),
                        ),
                      )
                    : null,
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 36,
              color:
                  isDone ? activeColor.withOpacity(0.4) : Colors.grey.shade200,
            ),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? activeColor
                  : isDone
                      ? AppColors.textDark
                      : AppColors.textLight,
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Assessment CTA ─────────────────────────────────────────────────────────────

class AssessmentCTA extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onViewAssessment;

  const AssessmentCTA({
    super.key,
    required this.booking,
    this.onViewAssessment,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewAssessment,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5856D6), Color(0xFF7B79E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF5856D6).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Assessment Ready',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                booking.assessmentPrice != null
                    ? 'Your handyman set a price of ₱${booking.assessmentPrice!.toStringAsFixed(0)}. Tap to review.'
                    : 'Your handyman has assessed the job. Tap to review.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85), fontSize: 12),
              ),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}
