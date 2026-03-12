// lib/presentation/screens/customer/schedule_review_screen.dart
//
// Shown to the customer when the handyman has proposed a start date/time
// (booking status = scheduleProposed).
//
// The customer can:
//   • Accept           → onAccept()           → respondToSchedule(accepted:true)
//   • Propose counter  → onProposeAlternative(DateTime) → proposeReschedule()
//   • Decline & Cancel → onDecline()          → respondToSchedule(accepted:false)
//
// Props:
//   booking              — BookingEntity with status == scheduleProposed
//   onAccept             — VoidCallback
//   onDecline            — VoidCallback
//   onProposeAlternative — Function(DateTime) — customer counter-proposes a time
//   onBack               — VoidCallback

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:intl/intl.dart';

class ScheduleReviewScreen extends StatefulWidget {
  final BookingEntity booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Called when the customer picks a counter-proposal time.
  /// Parent calls supabase.proposeReschedule() with the new time.
  final Function(DateTime)? onProposeAlternative;

  final VoidCallback? onBack;

  const ScheduleReviewScreen({
    super.key,
    required this.booking,
    required this.onAccept,
    required this.onDecline,
    this.onProposeAlternative,
    this.onBack,
  });

  @override
  State<ScheduleReviewScreen> createState() => _ScheduleReviewScreenState();
}

class _ScheduleReviewScreenState extends State<ScheduleReviewScreen> {
  /// Whether the customer has opened the "propose different time" panel.
  bool _proposingAlternative = false;
  DateTime? _alternativeDateTime;
  bool _isSubmitting = false;

  String get _proName => widget.booking.professional?.name ?? 'Your handyman';

  String get _formattedDate {
    final t = widget.booking.scheduledTime;
    if (t == null) return 'Not specified';
    return DateFormat('EEEE, MMMM d, yyyy').format(t.toLocal());
  }

  String get _formattedTime {
    final t = widget.booking.scheduledTime;
    if (t == null) return '';
    return DateFormat('h:mm a').format(t.toLocal());
  }

  bool get _isReschedule =>
      widget.booking.rescheduleReason != null &&
      widget.booking.rescheduleReason!.isNotEmpty;

  // ── Date/time picker ───────────────────────────────────────────────────────

  Future<void> _pickAlternativeTime() async {
    final now = DateTime.now();
    final initial = _alternativeDateTime ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _alternativeDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submitAlternative() async {
    if (_alternativeDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time first.')),
      );
      return;
    }
    _confirmProposeAlternative(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner().animate().fadeIn(delay: 80.ms),
                    const SizedBox(height: 20),
                    _buildScheduleCard()
                        .animate()
                        .fadeIn(delay: 150.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 16),
                    _buildBookingInfoCard()
                        .animate()
                        .fadeIn(delay: 220.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 16),
                    if (_isReschedule) ...[
                      _buildRescheduleReasonCard()
                          .animate()
                          .fadeIn(delay: 290.ms)
                          .slideY(begin: 0.06, end: 0),
                      const SizedBox(height: 16),
                    ],
                    _buildNotice()
                        .animate()
                        .fadeIn(delay: _isReschedule ? 360.ms : 290.ms),
                    const SizedBox(height: 32),
                    _buildActions(context)
                        .animate()
                        .fadeIn(delay: _isReschedule ? 430.ms : 360.ms)
                        .slideY(begin: 0.08, end: 0),
                    const SizedBox(height: 32),
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

  Widget _buildHeader(BuildContext context) => Container(
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
                onTap: widget.onBack,
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
                      Text(
                        _isReschedule
                            ? 'Reschedule Request'
                            : 'Schedule Proposal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3),
                      ),
                      Text(
                        'Review and respond',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_rounded,
                      color: Color(0xFFFF9500), size: 14),
                  SizedBox(width: 4),
                  Text('Awaiting',
                      style: TextStyle(
                          color: Color(0xFFFF9500),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      );

  // ── Banner ─────────────────────────────────────────────────────────────────

  Widget _buildBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isReschedule
              ? const Color(0xFFFF9500).withOpacity(0.1)
              : const Color(0xFF007AFF).withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isReschedule
                ? const Color(0xFFFF9500).withOpacity(0.3)
                : const Color(0xFF007AFF).withOpacity(0.2),
          ),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (_isReschedule
                      ? const Color(0xFFFF9500)
                      : const Color(0xFF007AFF))
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isReschedule
                  ? Icons.update_rounded
                  : Icons.event_available_rounded,
              color: _isReschedule
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF007AFF),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _isReschedule
                    ? '$_proName wants to reschedule'
                    : '$_proName has proposed a schedule',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isReschedule
                        ? const Color(0xFFFF9500)
                        : const Color(0xFF007AFF)),
              ),
              const SizedBox(height: 3),
              Text(
                _isReschedule
                    ? 'Review the new proposed time below.'
                    : 'Please confirm, suggest a different time, or decline.',
                style:
                    const TextStyle(fontSize: 12, color: AppColors.textMedium),
              ),
            ]),
          ),
        ]),
      );

  // ── Schedule Card ──────────────────────────────────────────────────────────

  Widget _buildScheduleCard() => Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text('Proposed Schedule',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F3D2E), Color(0xFF1A5C43)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text(_formattedDate,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(_formattedTime,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 28,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Proposed start time',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55), fontSize: 12),
                  textAlign: TextAlign.center),
            ]),
          ),
        ]),
      );

  // ── Booking Info ───────────────────────────────────────────────────────────

  Widget _buildBookingInfoCard() => Container(
        padding: const EdgeInsets.all(18),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Booking Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          _infoRow(Icons.build_rounded, 'Service', widget.booking.serviceType),
          const SizedBox(height: 10),
          _infoRow(Icons.person_rounded, 'Handyman', _proName),
          if (widget.booking.address != null &&
              widget.booking.address!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoRow(
                Icons.location_on_rounded, 'Location', widget.booking.address!),
          ],
          if (widget.booking.description != null &&
              widget.booking.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoRow(Icons.description_rounded, 'Notes',
                widget.booking.description!),
          ],
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
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

  // ── Reschedule Reason ──────────────────────────────────────────────────────

  Widget _buildRescheduleReasonCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9500).withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFFF9500), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reason for reschedule',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9500))),
              const SizedBox(height: 4),
              Text(widget.booking.rescheduleReason ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textDark, height: 1.5)),
            ]),
          ),
        ]),
      );

  // ── Notice ─────────────────────────────────────────────────────────────────

  Widget _buildNotice() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: AppColors.textLight),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Declining cancels the booking. '
              'You can suggest a different time instead of declining.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textLight, height: 1.5),
            ),
          ),
        ],
      );

  // ── Action Buttons ─────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context) => Column(children: [
        // ── Accept ────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmAccept(context),
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: const Text('Accept Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Propose a different time (toggle + picker) ─────────────────────
        if (widget.onProposeAlternative != null) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: _proposingAlternative
                  ? const Color(0xFF007AFF).withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _proposingAlternative
                    ? const Color(0xFF007AFF).withOpacity(0.35)
                    : Colors.grey.shade200,
              ),
            ),
            child: Column(children: [
              // Toggle row
              GestureDetector(
                onTap: () => setState(
                    () => _proposingAlternative = !_proposingAlternative),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded,
                          color: Color(0xFF007AFF), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Suggest a Different Time',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF007AFF))),
                            Text(
                              'Propose your preferred time to the handyman.',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textLight),
                            ),
                          ]),
                    ),
                    Icon(
                      _proposingAlternative
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF007AFF),
                      size: 20,
                    ),
                  ]),
                ),
              ),

              // Expanded picker + send button
              if (_proposingAlternative) ...[
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(children: [
                    // Date/time picker tap target
                    GestureDetector(
                      onTap: _pickAlternativeTime,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.schedule_rounded,
                              color: Color(0xFF007AFF), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _alternativeDateTime != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('EEEE, MMMM d, yyyy')
                                            .format(_alternativeDateTime!),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textDark),
                                      ),
                                      Text(
                                        DateFormat('h:mm a')
                                            .format(_alternativeDateTime!),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textLight),
                                      ),
                                    ],
                                  )
                                : const Text('Tap to pick your preferred time',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textLight)),
                          ),
                          const Icon(Icons.edit_rounded,
                              color: Color(0xFF007AFF), size: 16),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Send counter-proposal button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitAlternative,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send to Handyman',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Decline & Cancel ───────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmDecline(context),
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: const Text('Decline & Cancel',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B30),
              side: const BorderSide(color: Color(0xFFFF3B30)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ]);

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _confirmAccept(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Schedule',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'You are confirming $_formattedDate at $_formattedTime. '
          'Your handyman will arrive at this time.',
          style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onAccept();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Confirm',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDecline(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Declining the schedule will cancel this booking. '
          'You can always submit a new request at any time.',
          style: TextStyle(fontSize: 13, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onDecline();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Cancel Booking',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmProposeAlternative(BuildContext context) {
    final dt = _alternativeDateTime!;
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(dt);
    final timeStr = DateFormat('h:mm a').format(dt);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Suggest This Time?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'You\'re suggesting $dateStr at $timeStr to your handyman. '
          'They\'ll be notified to review your proposed time.',
          style: const TextStyle(
              fontSize: 13, color: AppColors.textMedium, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isSubmitting = true);
              try {
                await widget.onProposeAlternative?.call(dt);
              } finally {
                if (mounted) setState(() => _isSubmitting = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Send Suggestion',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
