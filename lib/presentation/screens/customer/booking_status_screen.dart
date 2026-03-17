// lib/presentation/screens/customer/booking_status_screen.dart
//
// MVC ROLE: VIEW
//   • Receives all data and callbacks from the Controller (main.dart).
//   • Owns only presentation logic — formatting, step colors, icon mapping.
//   • No direct data-source calls; every action fires a callback.
//
// SCHEDULE SIMPLIFICATION (applied):
//   • scheduleProposed step REMOVED from the progress timeline.
//     Customers set their preferred date/time at booking creation.
//     Handymen who accept simply confirm that time — no back-and-forth.
//   • "Review Schedule" CTA (_buildScheduleCTA) REMOVED.
//   • onReviewSchedule callback retained for API compatibility but no
//     longer wired to any UI element.
//
// ARRIVAL CONFIRMATION (applied):
//   • New status: pendingArrivalConfirmation
//     Handyman taps "I've Arrived" → customer sees _ConfirmArrivalCTA.
//     Customer confirms → status = assessment → handyman sets price.
//   • onConfirmArrival callback added (nullable, backward-compat).
//   • Timeline steps are now 8:
//       Pending → Accepted → Scheduled → Handyman Arrived →
//       Assessment → In Progress → Confirm Completion → Completed
//
// COMPLETION UPDATE (retained):
//   • pendingCustomerConfirmation → shows _ConfirmCompletionCTA.
//
// REVIEW FIX (retained):
//   • onLeaveReview shown for completed, unreviewed bookings.
//
// BACKJOB / WARRANTY UPDATE:
//   • Added onBackjob callback — shown for completed bookings where
//     booking.isUnderWarranty == true.
//   • _BackjobCTA widget added — teal shield-icon card, rendered between
//     Book Again and the booking info section for completed in-warranty jobs.
//   • The Backjob CTA is intentionally shown even when onBookAgain is also
//     visible — customers may want to rebook (new service) OR file a warranty
//     claim (same issue). Both are distinct actions.
//
// PROPS (all optional for backward compat):
//   onReviewSchedule    — VoidCallback? — kept in signature, no longer shown
//   onConfirmArrival    — VoidCallback? — customer confirms handyman arrived
//   onConfirmCompletion — VoidCallback?
//   onLeaveReview       — VoidCallback?
//   hasReviewed         — bool (default false)
//   onBackjob           — VoidCallback? — customer files a warranty backjob claim

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:intl/intl.dart';

class BookingStatusScreen extends StatefulWidget {
  final BookingEntity booking;
  final VoidCallback? onBack;
  final VoidCallback? onViewAssessment;

  /// Retained for API compatibility. No longer shown in UI — schedule
  /// confirmation is no longer part of the customer flow.
  final VoidCallback? onReviewSchedule;

  /// Called when the customer confirms the handyman has arrived on-site.
  /// Transitions status: pendingArrivalConfirmation → assessment.
  final VoidCallback? onConfirmArrival;

  /// Called when the customer confirms the job is complete.
  final VoidCallback? onConfirmCompletion;

  /// Called to load completion proof photos for this booking.
  /// Returns a list of public image URLs uploaded by the handyman.
  /// Shown to the customer in the pendingCustomerConfirmation state.
  final Future<List<String>> Function(String bookingId)? onLoadCompletionPhotos;

  /// Called when the customer taps "Leave a Review" on a completed booking.
  final VoidCallback? onLeaveReview;

  /// Called when the customer accepts a proposed reschedule (scheduleProposed).
  /// Reuses onReviewSchedule routing — navigates to ScheduleReviewScreen.
  // (onReviewSchedule already declared above)

  /// Called when the customer declines a proposed reschedule directly
  /// from the booking status card without going to ScheduleReviewScreen.
  final VoidCallback? onDeclineSchedule;

  /// Called when the customer taps "Book Again" on a completed booking.
  /// The controller should navigate to RequestServiceScreen pre-targeting
  /// the same professional (direct booking behaviour).
  final Function(String serviceType)? onBookAgain;

  /// Called when the customer taps "Backjob" on a completed booking that
  /// is still within its warranty period.
  /// The controller navigates to BackjobScreen.
  final VoidCallback? onBackjob;

  /// Called when the customer taps "Cancel Booking".
  final VoidCallback? onCancel;

  /// Whether the customer has already submitted a review for this booking.
  final bool hasReviewed;

  const BookingStatusScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onViewAssessment,
    this.onReviewSchedule, // retained — not wired to UI
    this.onConfirmArrival,
    this.onConfirmCompletion,
    this.onLoadCompletionPhotos,
    this.onLeaveReview,
    this.onBookAgain,
    this.onBackjob,
    this.onDeclineSchedule,
    this.onCancel,
    this.hasReviewed = false,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen> {
  // ── VIEW convenience accessors ────────────────────────────────────────────
  BookingEntity get booking => widget.booking;
  VoidCallback? get onBack => widget.onBack;
  VoidCallback? get onViewAssessment => widget.onViewAssessment;
  // onReviewSchedule is surfaced for the scheduleProposed reschedule flow.
  VoidCallback? get onReviewSchedule => widget.onReviewSchedule;
  VoidCallback? get onConfirmArrival => widget.onConfirmArrival;
  VoidCallback? get onConfirmCompletion => widget.onConfirmCompletion;
  Future<List<String>> Function(String bookingId)? get onLoadCompletionPhotos =>
      widget.onLoadCompletionPhotos;
  VoidCallback? get onLeaveReview => widget.onLeaveReview;
  VoidCallback? get onDeclineSchedule => widget.onDeclineSchedule;
  Function(String serviceType)? get onBookAgain => widget.onBookAgain;
  VoidCallback? get onBackjob => widget.onBackjob;
  VoidCallback? get onCancel => widget.onCancel;
  bool get hasReviewed => widget.hasReviewed;

  // ── VIEW helpers — handyman card visibility ───────────────────────────────
  // Show the handyman card from 'accepted' through 'completed' (not on
  // pending or cancelled — no professional assigned yet / anymore).
  bool get _showHandymanCard {
    const visibleStatuses = {
      BookingStatus.accepted,
      BookingStatus.scheduleProposed,
      BookingStatus.scheduled,
      BookingStatus.pendingArrivalConfirmation,
      BookingStatus.assessment,
      BookingStatus.inProgress,
      BookingStatus.pendingCustomerConfirmation,
      BookingStatus.completed,
    };
    return visibleStatuses.contains(booking.status);
  }

  // ── MODEL (View-local) — timeline step definitions ────────────────────────
  // scheduleProposed intentionally removed — customers set their own time;
  // handymen confirm it directly, so this intermediate status no longer
  // represents a customer-visible phase.
  // pendingArrivalConfirmation is the new step between scheduled and assessment:
  // handyman arrives → customer confirms → price-setting unlocked.
  static const List<BookingStatus> _steps = [
    BookingStatus.pending,
    BookingStatus.accepted,
    BookingStatus.scheduled,
    BookingStatus.pendingArrivalConfirmation,
    BookingStatus.assessment,
    BookingStatus.inProgress,
    BookingStatus.pendingCustomerConfirmation,
    BookingStatus.completed,
  ];

  // ── VIEW helpers — step index & labels ───────────────────────────────────

  int get _currentStepIndex {
    if (booking.status == BookingStatus.cancelled) return -1;
    // scheduleProposed maps to "accepted" visually — treat as step 1 so the
    // timeline still renders correctly if the status is encountered.
    if (booking.status == BookingStatus.scheduleProposed) {
      return _steps.indexOf(BookingStatus.accepted);
    }
    return _steps.indexOf(booking.status);
  }

  String _stepLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.pendingArrivalConfirmation:
        return 'Handyman\nArrived';
      case BookingStatus.assessment:
        return 'Assessment';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.pendingCustomerConfirmation:
        return 'Confirm\nCompletion';
      case BookingStatus.completed:
        return 'Completed';
      default:
        return '';
    }
  }

  // ── VIEW helpers — status display ─────────────────────────────────────────

  String get _statusLabel {
    // Backjob pending shows a distinct label so the customer knows it is
    // directed at their original handyman, not a broadcast search.
    if (booking.isBackjob && booking.status == BookingStatus.pending) {
      return 'Warranty Claim Sent';
    }
    switch (booking.status) {
      case BookingStatus.pending:
        return 'Finding Handyman';
      case BookingStatus.accepted:
        return 'Handyman Assigned';
      case BookingStatus.scheduleProposed:
        return 'Handyman Assigned';
      case BookingStatus.scheduled:
        return 'Job Scheduled';
      case BookingStatus.pendingArrivalConfirmation:
        return 'Handyman Arrived';
      case BookingStatus.assessment:
        return 'Assessment In Progress';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.pendingCustomerConfirmation:
        return 'Confirm Completion';
      case BookingStatus.completed:
        return booking.warrantyExpiresAt != null &&
                DateTime.now().isBefore(booking.warrantyExpiresAt!)
            ? 'Completed — Covered'
            : 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get _statusMessage {
    // ── Backjob / warranty override for pending state ─────────────────────
    // When a warranty claim is pending the booking is already assigned to
    // the original handyman — it is NOT an open broadcast. Show a specific
    // message so the customer knows their claim was received and directed
    // to the right person rather than the generic "finding a handyman" copy.
    if (booking.isBackjob && booking.status == BookingStatus.pending) {
      return 'Your warranty claim has been sent directly to your original '
          'handyman. They will review it and confirm the schedule — '
          'usually within 24 hours.';
    }

    // ── Completed state — warranty-aware loyalty message ─────────────────
    // When the job is done and the service carried a warranty, tell the
    // customer their work is covered and how to claim it. This is the
    // key retention moment: before they leave the app, they should know
    // there is still value here if the issue returns.
    if (booking.status == BookingStatus.completed) {
      if (booking.warrantyExpiresAt != null &&
          DateTime.now().isBefore(booking.warrantyExpiresAt!)) {
        final days =
            booking.warrantyExpiresAt!.difference(DateTime.now()).inDays;
        final periodLabel = days >= 30
            ? '${(days / 30).floor()} month${(days / 30).floor() == 1 ? '' : 's'}'
            : '$days day${days == 1 ? '' : 's'}';
        return 'Your service is complete and covered by AYO\'s guarantee '
            'for another $periodLabel. If the same issue returns, tap '
            '"File a Backjob" below — your handyman will come back at '
            'no extra charge.';
      }
      return 'Your service is complete. Book through AYO again anytime '
          'to keep a full record of your home services and stay covered '
          'by our guarantee.';
    }

    switch (booking.status) {
      case BookingStatus.pending:
        return 'We\'re matching you with an available handyman. '
            'This usually takes just a few minutes.';
      case BookingStatus.accepted:
        return 'A handyman has accepted your request and confirmed '
            'your preferred schedule.';
      case BookingStatus.scheduleProposed:
        return 'Your handyman has requested a reschedule. Please '
            'review the new proposed time below.';
      case BookingStatus.scheduled:
        return 'Your handyman is on the way. '
            'You\'ll be notified when they arrive.';
      case BookingStatus.pendingArrivalConfirmation:
        return 'Your handyman has arrived. Please confirm their arrival '
            'below so they can begin the assessment.';
      case BookingStatus.assessment:
        return 'Your handyman is assessing the job and will send '
            'you a price shortly.';
      case BookingStatus.inProgress:
        return 'Your handyman is currently working on the job.';
      case BookingStatus.pendingCustomerConfirmation:
        return 'Your handyman has marked the job as done. Please '
            'confirm below once you\'re satisfied with the work.';
      case BookingStatus.completed:
        // Handled by the early-return block above. This case is
        // unreachable but required for exhaustive switch coverage.
        return 'Your service is complete.';
      case BookingStatus.cancelled:
        return 'This booking has been cancelled.';
    }
  }

  Color get _statusColor {
    switch (booking.status) {
      case BookingStatus.pending:
        return const Color(0xFFFF9500);
      case BookingStatus.accepted:
      case BookingStatus.scheduleProposed:
        return const Color(0xFF007AFF);
      case BookingStatus.scheduled:
        return const Color(0xFF007AFF);
      case BookingStatus.pendingArrivalConfirmation:
        return const Color(0xFF34C759);
      case BookingStatus.assessment:
        return const Color(0xFF5856D6);
      case BookingStatus.inProgress:
        return const Color(0xFF34C759);
      case BookingStatus.pendingCustomerConfirmation:
        return const Color(0xFF30B0C7);
      case BookingStatus.completed:
        return AppColors.primary;
      case BookingStatus.cancelled:
        return const Color(0xFFFF3B30);
    }
  }

  // ── VIEW — build ───────────────────────────────────────────────────────────

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
                    // ── For completed bookings use a service record card
                    // instead of the status card + timeline combination.
                    // The timeline is a progress tracker — irrelevant once
                    // the job is done. The record card reads like a document.
                    if (booking.status == BookingStatus.completed) ...[
                      _buildServiceRecordCard()
                          .animate()
                          .fadeIn(delay: 80.ms)
                          .slideY(begin: 0.06, end: 0),
                      const SizedBox(height: 16),
                    ] else ...[
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
                    ],

                    // ── Handyman Info Card ───────────────────────────────
                    // Shown from 'accepted' onwards whenever a professional
                    // has been assigned. Tapping opens a detail bottom sheet.
                    if (_showHandymanCard && booking.professional != null) ...[
                      _HandymanInfoCard(
                        professional: booking.professional!,
                      )
                          .animate()
                          .fadeIn(delay: 210.ms)
                          .slideY(begin: 0.06, end: 0),
                      const SizedBox(height: 16),
                    ],

                    // ── Confirm Arrival CTA ──────────────────────────────
                    if (booking.status ==
                        BookingStatus.pendingArrivalConfirmation) ...[
                      _ConfirmArrivalCTA(
                        onConfirmArrival: onConfirmArrival,
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Reschedule Review Card (scheduleProposed) ─────────
                    // Shown when the handyman has proposed a new date.
                    // Customer can Accept or Decline.
                    if (booking.status == BookingStatus.scheduleProposed) ...[
                      _RescheduleReviewCard(
                        booking: booking,
                        onAccept: onReviewSchedule != null
                            ? () => onReviewSchedule!()
                            : null,
                        onDecline: onDeclineSchedule,
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Running Late ETA Banner (scheduled) ───────────────
                    // Shown when the handyman updated their ETA without
                    // changing the date (status stays 'scheduled').
                    if (booking.status == BookingStatus.scheduled &&
                        booking.scheduledTime != null &&
                        booking.rescheduleReason != null) ...[
                      _RunningLateBanner(booking: booking)
                          .animate()
                          .fadeIn(delay: 220.ms),
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

                    // ── Confirm Completion CTA ───────────────────────────
                    if (booking.status ==
                        BookingStatus.pendingCustomerConfirmation) ...[
                      // Proof photos — shown above the confirm button so the
                      // customer reviews the handyman's evidence first.
                      if (onLoadCompletionPhotos != null) ...[
                        _CompletionProofCard(
                          bookingId: booking.id,
                          onLoad: onLoadCompletionPhotos!,
                        ).animate().fadeIn(delay: 215.ms),
                        const SizedBox(height: 12),
                      ],
                      _ConfirmCompletionCTA(
                        booking: booking,
                        onConfirmCompletion: onConfirmCompletion,
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Leave a Review CTA (completed, not yet reviewed) ──
                    if (booking.status == BookingStatus.completed &&
                        !hasReviewed &&
                        onLeaveReview != null) ...[
                      _ReviewCTA(
                        onLeaveReview: onLeaveReview!,
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Book Again CTA (completed) ────────────────────────
                    if (booking.status == BookingStatus.completed &&
                        onBookAgain != null) ...[
                      _BookAgainCTA(
                        onBookAgain: () => onBookAgain!(booking.serviceType),
                      ).animate().fadeIn(delay: 260.ms),
                      const SizedBox(height: 16),
                    ],

                    // ── Backjob / Warranty CTA ────────────────────────────
                    // Shown for completed bookings that are still within their
                    // warranty period (booking.isUnderWarranty == true).
                    // Distinct from Book Again — this files a warranty claim,
                    // not a new paid booking.
                    if (booking.status == BookingStatus.completed &&
                        booking.isUnderWarranty &&
                        onBackjob != null) ...[
                      _BackjobCTA(
                        booking: booking,
                        onBackjob: onBackjob!,
                      ).animate().fadeIn(delay: 290.ms),
                      const SizedBox(height: 16),
                    ],

                    _buildBookingInfo(context)
                        .animate()
                        .fadeIn(delay: 280.ms)
                        .slideY(begin: 0.06, end: 0),

                    // ── Issue Photo card ────────────────────────────────
                    if (booking.photoUrl != null &&
                        booking.photoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPhotoCard()
                          .animate()
                          .fadeIn(delay: 330.ms)
                          .slideY(begin: 0.06, end: 0),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: (onCancel != null &&
                (booking.status == BookingStatus.pending ||
                    booking.status == BookingStatus.accepted ||
                    booking.status == BookingStatus.scheduleProposed ||
                    booking.status == BookingStatus.scheduled))
            ? Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundLight.withOpacity(0),
                      AppColors.backgroundLight,
                    ],
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3B30).withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmCancelDialog(context),
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text('Cancel Booking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 6,
                          shadowColor: const Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                  ),
                ]),
              )
            : null,
      ),
    );
  }

  // ── VIEW — Header ──────────────────────────────────────────────────────────

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
                      // Completed bookings are surfaced as service records,
                      // not status trackers — the title reflects that shift.
                      Text(
                          booking.status == BookingStatus.completed
                              ? 'Service Record'
                              : 'Booking Status',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      Text(
                          booking.serviceTitle?.isNotEmpty == true
                              ? booking.serviceTitle!
                              : booking.serviceType,
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

  // ── VIEW — Service Record Card (completed bookings only) ─────────────────
  // Replaces the status card + timeline for completed bookings.
  // Reads like a document header: what was done, when, by whom, at what cost,
  // and whether the AYO Guarantee is still active.

  Widget _buildServiceRecordCard() {
    final serviceTitle = booking.serviceTitle?.isNotEmpty == true
        ? booking.serviceTitle!
        : booking.serviceType;
    final proName = booking.professional?.name;
    final hasPrice = booking.assessmentPrice != null;
    final isWarrantied = booking.warrantyExpiresAt != null;
    final isCovered = booking.isUnderWarranty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCovered
              ? const Color(0xFF30B0C7).withOpacity(0.25)
              : const Color(0xFF34C759).withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Record header ──────────────────────────────────────────────
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF34C759), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(serviceTitle,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.2)),
              const SizedBox(height: 2),
              if (booking.serviceTitle?.isNotEmpty == true &&
                  booking.serviceTitle != booking.serviceType)
                Text(booking.serviceType,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary)),
            ]),
          ),
          // Guarantee pill — prominent only when still active
          if (isWarrantied)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isCovered
                    ? const Color(0xFF30B0C7).withOpacity(0.10)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCovered
                      ? const Color(0xFF30B0C7).withOpacity(0.35)
                      : const Color(0xFFDDDDDD),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_user_rounded,
                    size: 11,
                    color: isCovered
                        ? const Color(0xFF1D8A9E)
                        : AppColors.textLight),
                const SizedBox(width: 4),
                Text(
                  isCovered ? 'Covered' : 'Expired',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCovered
                          ? const Color(0xFF1D8A9E)
                          : AppColors.textLight),
                ),
              ]),
            ),
        ]),

        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 16),

        // ── Record data rows ───────────────────────────────────────────
        if (proName != null && proName.isNotEmpty)
          _recordRow(Icons.person_outline_rounded, 'Handyman', proName),
        const SizedBox(height: 12),
        _recordRow(
          Icons.calendar_today_outlined,
          'Completed on',
          _formatRecordDate(booking.scheduledDate),
        ),
        if (hasPrice) ...[
          const SizedBox(height: 12),
          _recordRow(
            Icons.payments_outlined,
            'Amount Paid',
            '₱${booking.assessmentPrice!.toStringAsFixed(0)}',
            valueStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ],
        if (booking.address != null && booking.address!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _recordRow(Icons.location_on_outlined, 'Location', booking.address!),
        ],

        // ── Guarantee row — key loyalty data point ─────────────────────
        if (isWarrantied) ...[
          const SizedBox(height: 12),
          _recordRow(
            Icons.verified_user_outlined,
            'AYO Guarantee',
            isCovered
                ? 'Active until ${_formatRecordDate(booking.warrantyExpiresAt!)}'
                : 'Expired ${_formatRecordDate(booking.warrantyExpiresAt!)}',
            valueStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    isCovered ? const Color(0xFF1D8A9E) : AppColors.textLight),
          ),
        ],
      ]),
    );
  }

  // ── Record row helper — icon · label · value (right-aligned) ─────────────
  Widget _recordRow(
    IconData icon,
    String label,
    String value, {
    TextStyle? valueStyle,
  }) =>
      Row(children: [
        Icon(icon, size: 15, color: AppColors.textLight),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: valueStyle ??
                  const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]);

  // Formats a DateTime as "Sep 14, 2025"
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

  // ── VIEW — Status Card ─────────────────────────────────────────────────────

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
            // ── Warranty badge — shown on backjob bookings ──────────────
            // Appears below the status message to remind the customer
            // this is a warranty-covered job at no extra charge.
            if (booking.isBackjob) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF30B0C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF30B0C7).withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_user_rounded,
                      size: 12, color: Color(0xFF1D8A9E)),
                  const SizedBox(width: 5),
                  const Text('AYO Guarantee — No Extra Charge',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D8A9E))),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  IconData get _statusIcon {
    // Backjob pending uses a shield icon instead of the search icon to
    // reinforce that this is a warranty claim, not a new search.
    if (booking.isBackjob && booking.status == BookingStatus.pending) {
      return Icons.verified_user_rounded;
    }
    switch (booking.status) {
      case BookingStatus.pending:
        return Icons.search_rounded;
      case BookingStatus.accepted:
      case BookingStatus.scheduleProposed:
        return Icons.person_rounded;
      case BookingStatus.scheduled:
        return Icons.event_available_rounded;
      case BookingStatus.pendingArrivalConfirmation:
        return Icons.directions_walk_rounded;
      case BookingStatus.assessment:
        return Icons.receipt_long_rounded;
      case BookingStatus.inProgress:
        return Icons.handyman_rounded;
      case BookingStatus.pendingCustomerConfirmation:
        return Icons.task_alt_rounded;
      case BookingStatus.completed:
        return Icons.check_circle_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  // ── VIEW — Timeline ────────────────────────────────────────────────────────

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
      case BookingStatus.pendingArrivalConfirmation:
        return const Color(0xFF34C759);
      case BookingStatus.assessment:
        return const Color(0xFF5856D6);
      case BookingStatus.inProgress:
        return const Color(0xFF34C759);
      case BookingStatus.pendingCustomerConfirmation:
        return const Color(0xFF30B0C7);
      case BookingStatus.completed:
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  // ── VIEW — Booking Info ────────────────────────────────────────────────────

  Widget _buildBookingInfo(BuildContext context) => Container(
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
          Text(
              booking.status == BookingStatus.completed
                  ? 'Additional Notes'
                  : 'Booking Details',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 16),
          _infoRow(Icons.build_rounded, 'Service', booking.serviceType),
          // Handyman name row intentionally removed — handyman details are
          // shown in the dedicated _HandymanInfoCard above this section.
          if (booking.customer != null &&
              booking.customer!.phone != null &&
              booking.customer!.phone!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.phone_rounded, 'Phone', booking.customer!.phone!),
          ],
          const SizedBox(height: 12),
          _infoRow(
            Icons.calendar_today_rounded,
            'Preferred Date',
            DateFormat('MMM d, yyyy').format(booking.scheduledDate.toLocal()),
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.access_time_rounded,
            'Preferred Time',
            DateFormat('h:mm a').format(booking.scheduledDate.toLocal()),
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
          if (_extractPriceRange(booking.notes) != null) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.payments_rounded, 'Estimated Range',
                _extractPriceRange(booking.notes)!),
          ],
          if (booking.assessmentPrice != null) ...[
            const SizedBox(height: 12),
            _infoRow(Icons.payments_rounded, 'Agreed Price',
                '₱${booking.assessmentPrice!.toStringAsFixed(0)}'),
          ],
          if (booking.notes != null) ...[
            () {
              final pruned = _pruneNotes(booking.notes!);
              if (pruned.isNotEmpty) {
                return Column(children: [
                  const SizedBox(height: 12),
                  _infoRow(Icons.notes_rounded, 'Notes', pruned),
                ]);
              }
              return const SizedBox.shrink();
            }(),
          ],
        ]),
      );

  // ── VIEW — Issue Photo Card ────────────────────────────────────────────────

  Widget _buildPhotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Issue Photo',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    SizedBox(height: 1),
                    Text('Uploaded by customer',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded,
                        size: 13, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Tap to expand',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
          ),
          Container(
            height: 1,
            color: const Color(0xFFF0F0F0),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          GestureDetector(
            onTap: () => _showPhotoPreview(context),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Image.network(
                booking.photoUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF0F4F2),
                          const Color(0xFFE4EDE8),
                          const Color(0xFFF0F4F2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.primary.withOpacity(0.6)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Loading photo…',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary.withOpacity(0.5))),
                        ],
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded,
                          size: 40, color: Color(0xFFBBBBBB)),
                      const SizedBox(height: 8),
                      Text('Could not load photo',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight.withOpacity(0.7))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── VIEW — full-screen photo preview ──────────────────────────────────────

  void _showPhotoPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.network(
                booking.photoUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      size: 64, color: Colors.white38),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 28,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.pinch_rounded, color: Colors.white70, size: 14),
                  SizedBox(width: 6),
                  Text('Pinch to zoom',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── VIEW — Cancel dialog ───────────────────────────────────────────────────

  void _confirmCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style:
              TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Booking',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onCancel?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Yes, Cancel',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── VIEW — row helpers ─────────────────────────────────────────────────────

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

  // ── MODEL (View-local) — notes parsing helpers ─────────────────────────────

  /// Extracts a "Price Range: …" line from notes, if present.
  String? _extractPriceRange(String? notes) {
    if (notes == null) return null;
    final m =
        RegExp(r'Price Range:\s*(.+)', caseSensitive: false).firstMatch(notes);
    if (m != null) return m.group(1)?.trim();
    return null;
  }

  /// Returns notes with the "Price Range:" line removed.
  String _pruneNotes(String notes) {
    return notes
        .split('\n')
        .where((line) =>
            !RegExp(r'Price Range:', caseSensitive: false).hasMatch(line))
        .join('\n')
        .trim();
  }
}

// ── VIEW — Timeline Step widget ────────────────────────────────────────────

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
    final dotColor = isDone
        ? AppColors.primary
        : isActive
            ? activeColor
            : const Color(0xFFE0E0E0);

    final lineColor = isDone ? AppColors.primary : const Color(0xFFE0E0E0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone || isActive
                  ? dotColor.withOpacity(0.15)
                  : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
              border: Border.all(
                color: dotColor,
                width: isActive ? 2.5 : 1.5,
              ),
            ),
            child: isDone
                ? Icon(Icons.check_rounded, color: dotColor, size: 14)
                : isActive
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: dotColor, shape: BoxShape.circle),
                        ),
                      )
                    : null,
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 32,
              color: lineColor,
              margin: const EdgeInsets.symmetric(vertical: 3),
            ),
        ]),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? activeColor
                  : isDone
                      ? AppColors.textDark
                      : AppColors.textLight,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ── VIEW — Assessment CTA ──────────────────────────────────────────────────

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

// ── VIEW — Confirm Arrival CTA ─────────────────────────────────────────────
//
// Shown when status = pendingArrivalConfirmation.
// Customer confirms the handyman has physically arrived on-site.
// Tapping fires onConfirmArrival() → Controller → confirmHandymanArrival()
// → status = assessment → price-setting unlocks for the handyman.

class _ConfirmArrivalCTA extends StatelessWidget {
  final VoidCallback? onConfirmArrival;

  const _ConfirmArrivalCTA({this.onConfirmArrival});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmDialog(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34C759), Color(0xFF30D158)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF34C759).withOpacity(0.35),
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
            child: const Icon(Icons.where_to_vote_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Handyman Has Arrived!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                'Is your handyman at your location? Tap to confirm.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  void _confirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Arrival',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Please confirm that your handyman has arrived at your location. '
          'This will allow them to begin the assessment.',
          style:
              TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not Yet',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirmArrival?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Yes, They\'re Here',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── VIEW — Confirm Completion CTA ──────────────────────────────────────────

class _ConfirmCompletionCTA extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onConfirmCompletion;

  const _ConfirmCompletionCTA({
    required this.booking,
    this.onConfirmCompletion,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmDialog(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF30B0C7), Color(0xFF4ECDE0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF30B0C7).withOpacity(0.35),
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
            child: const Icon(Icons.task_alt_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Job Completed by Handyman',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                'Satisfied with the work? Tap here to confirm completion.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white, size: 16),
        ]),
      ),
    );
  }

  void _confirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Job Completion',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Please only confirm if you are satisfied with the completed work. '
          'This action cannot be undone.',
          style:
              TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not Yet',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirmCompletion?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF30B0C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Yes, Job is Done',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── VIEW — Handyman Info Card (shown from 'accepted' onwards) ─────────────
// Tapping the card opens _HandymanDetailSheet — a bottom sheet with full
// professional details (city, bio, skills, ratings, Maps deep-link).

class _HandymanInfoCard extends StatelessWidget {
  final ProfessionalEntity professional;

  const _HandymanInfoCard({required this.professional});

  @override
  Widget build(BuildContext context) {
    final pro = professional;
    return GestureDetector(
      onTap: () => _HandymanDetailSheet.show(context, pro),
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
          // ── Section header ─────────────────────────────────────────
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.18)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View Details',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: AppColors.primary),
              ]),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Avatar + name row ──────────────────────────────────────
          Row(children: [
            _HICAvatar(name: pro.name, avatarUrl: pro.avatarUrl, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(pro.name,
                            style: const TextStyle(
                                fontSize: 15,
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
                    // Star rating row
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
                      Text(
                          '${pro.rating.toStringAsFixed(1)} (${pro.reviewCount})',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ]),
            ),
          ]),

          // ── Pills row ──────────────────────────────────────────────
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (pro.yearsExperience > 0)
              _HICPill(Icons.work_history_rounded,
                  '${pro.yearsExperience} yr${pro.yearsExperience == 1 ? '' : 's'} exp'),
            if (pro.city != null && pro.city!.isNotEmpty)
              _HICPill(Icons.location_on_rounded, pro.city!),
            if (pro.skills.isNotEmpty)
              _HICPill(
                  Icons.build_rounded,
                  pro.skills.map(_cap).take(2).join(', ') +
                      (pro.skills.length > 2 ? '…' : '')),
          ]),
        ]),
      ),
    );
  }

  static String _cap(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : s;
}

// ── VIEW — Handyman Detail Bottom Sheet ──────────────────────────────────────

class _HandymanDetailSheet extends StatelessWidget {
  final ProfessionalEntity professional;

  const _HandymanDetailSheet({required this.professional});

  static void show(BuildContext context, ProfessionalEntity pro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandymanDetailSheet(professional: pro),
    );
  }

  // ── Google Maps deep-link — open professional's city location ────────────
  Future<void> _openMaps(BuildContext context) async {
    final pro = professional;
    Uri uri;

    if (pro.latitude != null && pro.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${pro.latitude},${pro.longitude}',
      );
    } else if (pro.city != null && pro.city!.isNotEmpty) {
      final encoded = Uri.encodeComponent(pro.city!);
      uri =
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No location available for this handyman.'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open Google Maps.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  // ── Phone deep-link — open the dialler with the handyman's number ─────────
  Future<void> _callHandyman(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open the dialler.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = professional;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Drag handle ───────────────────────────────────────────────
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Header ───────────────────────────────────────────────────
        Row(children: [
          _HICAvatar(name: pro.name, avatarUrl: pro.avatarUrl, size: 60),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFF34C759).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified_rounded,
                            size: 12, color: Color(0xFF34C759)),
                        SizedBox(width: 4),
                        Text('Verified',
                            style: TextStyle(
                                fontSize: 11,
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
                            size: 15,
                            color: const Color(0xFFFF9F0A),
                          )),
                  const SizedBox(width: 6),
                  Text(
                      '${pro.rating.toStringAsFixed(1)} · ${pro.reviewCount} reviews',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          fontWeight: FontWeight.w500)),
                ]),
              ])),
        ]),

        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 16),

        // ── Detail rows ───────────────────────────────────────────────
        _DetailRow(
          icon: Icons.work_history_rounded,
          label: 'Experience',
          value: pro.yearsExperience > 0
              ? '${pro.yearsExperience} year${pro.yearsExperience == 1 ? '' : 's'}'
              : 'Not specified',
        ),
        if (pro.city != null && pro.city!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.location_city_rounded,
            label: 'City',
            value: pro.city!,
          ),
        ],
        // Phone — sourced from the professional's users row (ProfessionalEntity.phone).
        // Collected at registration and editable in the Professional Profile screen.
        if (pro.phone != null && pro.phone!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: pro.phone!,
          ),
        ],
        if (pro.skills.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.build_rounded,
            label: 'Skills',
            value: pro.skills
                .map((s) => s.isNotEmpty
                    ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}'
                    : s)
                .join(', '),
          ),
        ],
        if (pro.bio != null && pro.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.info_outline_rounded,
            label: 'About',
            value: pro.bio!,
          ),
        ],

        // ── Action buttons ────────────────────────────────────────────
        // Show Call and/or Maps buttons when relevant data is available.
        if ((pro.phone != null && pro.phone!.isNotEmpty) ||
            pro.latitude != null ||
            (pro.city != null && pro.city!.isNotEmpty)) ...[
          const SizedBox(height: 20),
          Row(children: [
            // Call button — only shown when phone is available
            if (pro.phone != null && pro.phone!.isNotEmpty) ...[
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                  onPressed: () => _callHandyman(context, pro.phone!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    elevation: 0,
                  ),
                ),
              ),
            ],
            // Spacer between buttons when both are visible
            if ((pro.phone != null && pro.phone!.isNotEmpty) &&
                (pro.latitude != null ||
                    (pro.city != null && pro.city!.isNotEmpty)))
              const SizedBox(width: 10),
            // Maps button — only shown when location is available
            if (pro.latitude != null ||
                (pro.city != null && pro.city!.isNotEmpty))
              Expanded(
                flex: (pro.phone != null && pro.phone!.isNotEmpty) ? 2 : 1,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('View on Maps'),
                  onPressed: () => _openMaps(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    elevation: 0,
                  ),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

// ── VIEW — Detail Row helper (used inside _HandymanDetailSheet) ─────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 17, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
        ]),
      ),
    ]);
  }
}

// ── VIEW — Reusable avatar widget for handyman info card ─────────────────────

class _HICAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _HICAvatar(
      {required this.name, required this.avatarUrl, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
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
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Center(
          child: Text(letter,
              style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
      );
}

// ── VIEW — Pill chip helper (used inside _HandymanInfoCard) ──────────────────

class _HICPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HICPill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
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
}

// ── VIEW — Book Again CTA ──────────────────────────────────────────────────

class _BookAgainCTA extends StatelessWidget {
  final VoidCallback onBookAgain;
  const _BookAgainCTA({required this.onBookAgain});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBookAgain,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F3D2E), Color(0xFF1A5C43)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.30),
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
            child:
                const Icon(Icons.replay_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Book Again',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                'Request the same handyman for a new job.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
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

// ── VIEW — Backjob CTA ─────────────────────────────────────────────────────
// Shown for completed bookings where booking.isUnderWarranty == true.
// Uses a teal gradient so it is visually distinct from Book Again (green)
// and Review (amber).

class _BackjobCTA extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback onBackjob;

  const _BackjobCTA({required this.booking, required this.onBackjob});

  String _expiryLabel() {
    final exp = booking.warrantyExpiresAt;
    if (exp == null) return 'Warranty active';
    final days = exp.difference(DateTime.now()).inDays;
    if (days <= 0) return 'Expires today';
    if (days == 1) return '1 day left';
    if (days < 30) return '$days days left';
    final months = (days / 30).floor();
    return '$months month${months > 1 ? 's' : ''} left';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBackjob,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2E3F), Color(0xFF1D8A9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF30B0C7).withOpacity(0.30),
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
            child: const Icon(Icons.verified_user_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Request a Backjob',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                'Same issue? Your AYO guarantee covers it. ${_expiryLabel()}.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('FREE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
        ]),
      ),
    );
  }
}

// ── VIEW — Review CTA ──────────────────────────────────────────────────────

class _ReviewCTA extends StatelessWidget {
  final VoidCallback onLeaveReview;
  const _ReviewCTA({required this.onLeaveReview});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLeaveReview,
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
                color: const Color(0xFFFF9500).withOpacity(0.30),
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
            child:
                const Icon(Icons.star_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Leave a Review',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text(
                'How was your experience? Your review helps others find trusted handymen.',
                style: TextStyle(color: Colors.white, fontSize: 12),
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

// ── VIEW — Reschedule Review Card ─────────────────────────────────────────────
// Shown when the handyman proposes a new date (status = scheduleProposed).
// Displays the new proposed time, the reason, and Accept / Decline buttons.

class _RescheduleReviewCard extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _RescheduleReviewCard({
    required this.booking,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final newTime = booking.scheduledTime;
    final reason = booking.rescheduleReason;
    final proName = booking.professional?.name ?? 'Your handyman';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5856D6).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF5856D6).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF5856D6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_repeat_rounded,
                color: Color(0xFF5856D6), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reschedule Requested',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5856D6))),
              Text('$proName has proposed a new time.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Proposed time ────────────────────────────────────────────────
        if (newTime != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF5856D6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFF5856D6).withOpacity(0.15)),
            ),
            child: Row(children: [
              const Icon(Icons.schedule_rounded,
                  color: Color(0xFF5856D6), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Proposed new time',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5856D6),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy')
                            .format(newTime.toLocal()),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                      Text(
                        DateFormat('h:mm a').format(newTime.toLocal()),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ]),
              ),
            ]),
          ),

        // ── Reason (if provided) ─────────────────────────────────────────
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.textLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reason,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.4)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),

        // ── Accept / Decline buttons ─────────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side: const BorderSide(color: Color(0xFFFF3B30)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Decline',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5856D6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text('Accept',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── VIEW — Running Late ETA Banner ────────────────────────────────────────────
// Shown on the customer's booking status screen when the handyman updated
// their ETA (status stays 'scheduled'; rescheduleReason is set).

class _RunningLateBanner extends StatelessWidget {
  final BookingEntity booking;
  const _RunningLateBanner({required this.booking});

  @override
  Widget build(BuildContext context) {
    final eta = booking.scheduledTime!;
    final reason = booking.rescheduleReason;
    final proName = booking.professional?.name ?? 'Your handyman';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.access_time_rounded,
              color: Color(0xFFFF9500), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Handyman Running Late',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCC7700))),
            const SizedBox(height: 4),
            Text(
              '$proName has updated their arrival time to '
              '${DateFormat('h:mm a').format(eta.toLocal())}.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium, height: 1.4),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Reason: $reason',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                      fontStyle: FontStyle.italic)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── VIEW — Completion Proof Photo Card ───────────────────────────────────────
// Shown in pendingCustomerConfirmation status above the confirm button.
// Loads photos lazily via onLoad and displays them in a scrollable grid.

class _CompletionProofCard extends StatefulWidget {
  final String bookingId;
  final Future<List<String>> Function(String bookingId) onLoad;

  const _CompletionProofCard({
    required this.bookingId,
    required this.onLoad,
  });

  @override
  State<_CompletionProofCard> createState() => _CompletionProofCardState();
}

class _CompletionProofCardState extends State<_CompletionProofCard> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.onLoad(widget.bookingId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34C759).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.photo_library_rounded,
                color: Color(0xFF34C759), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Completion Proof',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              Text('Photos uploaded by your handyman.',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Photos ────────────────────────────────────────────────────────
        FutureBuilder<List<String>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF34C759))),
                ),
              );
            }
            if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No proof photos were uploaded for this job.',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              );
            }
            final urls = snap.data!;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            color: const Color(0xFFF0F4F2),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Color(0xFF34C759))),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF0F4F2),
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppColors.textLight, size: 28),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }

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
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${initial + 1} / ${urls.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
