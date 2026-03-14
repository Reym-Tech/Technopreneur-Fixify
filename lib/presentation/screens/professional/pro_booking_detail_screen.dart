// lib/presentation/screens/professional/pro_booking_detail_screen.dart
//
// MVC ROLE: VIEW
//   • Receives all data and callbacks from the Controller (main.dart).
//   • Owns only presentation logic and local UI state.
//   • No direct data-source calls; every action fires a callback.
//
// SCHEDULE SIMPLIFICATION (applied):
//   • "Propose a different time" toggle REMOVED from the accepted status.
//     The customer sets their preferred date/time; handymen simply confirm
//     they can make it, or skip the booking.
//   • accepted status now shows ONE action: "Confirm Customer's Schedule".
//     Pressing it calls onProposeSchedule(customerPreferredTime).
//   • onProposeSchedule / onProposeReschedule callbacks retained.
//
// ARRIVAL CONFIRMATION FLOW (applied):
//   • scheduled status shows "Start Assessment — I've Arrived" button.
//     Pressing it calls onStartAssessment() →
//     status = pendingArrivalConfirmation (waiting for customer to confirm).
//   • pendingArrivalConfirmation status shows a "Waiting for Customer
//     to Confirm Arrival" banner. No action available to the handyman.
//   • assessment status (customer confirmed arrival) now shows the PRICE
//     SETTER — the handyman sets the price based on the on-site assessment.
//     After sending the price, the handyman waits for the customer to
//     confirm via the AssessmentScreen (→ inProgress).
//
// EXISTING STATUSES (unchanged behaviour):
//   scheduleProposed — "Waiting for Customer" banner (reschedule edge-case).
//   inProgress       — "Mark Job as Complete" button.
//   completed        — Completed banner.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

class ProBookingDetailScreen extends StatefulWidget {
  final BookingEntity booking;
  final VoidCallback? onBack;

  /// Called when the handyman confirms the customer's preferred date/time.
  /// Parent calls supabase.proposeSchedule().
  final Function(DateTime proposedTime)? onProposeSchedule;

  /// Called when the handyman wants to reschedule.
  /// Parent calls supabase.proposeReschedule().
  final Function(DateTime newTime, String? reason)? onProposeReschedule;

  /// Called when the handyman sets an assessment price.
  /// Parent calls supabase.updateBookingAssessmentPrice().
  final Function(double price)? onSetAssessmentPrice;

  /// Called when the handyman marks the job complete.
  final VoidCallback? onMarkComplete;

  /// Called when the handyman taps "Start Assessment" (scheduled → assessment).
  /// Parent calls supabase.updateBookingStatus(id, BookingStatus.assessment).
  final VoidCallback? onStartAssessment;

  const ProBookingDetailScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onProposeSchedule,
    this.onProposeReschedule,
    this.onSetAssessmentPrice,
    this.onMarkComplete,
    this.onStartAssessment,
  });

  @override
  State<ProBookingDetailScreen> createState() => _ProBookingDetailScreenState();
}

class _ProBookingDetailScreenState extends State<ProBookingDetailScreen> {
  // ── VIEW — local state ────────────────────────────────────────────────────

  bool _isSubmittingSchedule = false;

  // ── Reschedule state ───────────────────────────────────────────────────────
  DateTime? _rescheduleDateTime;
  final _rescheduleReasonController = TextEditingController();

  // ── Price state ────────────────────────────────────────────────────────────
  final _priceController = TextEditingController();
  bool _isSubmittingPrice = false;

  // ── MODEL (View-local) — the customer's original preferred time ────────────
  DateTime get _customerPreferredTime =>
      widget.booking.scheduledTime ?? widget.booking.scheduledDate;

  @override
  void dispose() {
    _priceController.dispose();
    _rescheduleReasonController.dispose();
    super.dispose();
  }

  // ── CONTROLLER (View-local) — date/time picker helpers ────────────────────

  Future<void> _pickReschedule() async {
    final initial = _rescheduleDateTime ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
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
      _rescheduleDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ── CONTROLLER (View-local) — submit helpers ───────────────────────────────

  /// Confirms the customer's own preferred time — no alternative proposed.
  Future<void> _confirmCustomerSchedule() async {
    setState(() => _isSubmittingSchedule = true);
    try {
      await widget.onProposeSchedule?.call(_customerPreferredTime);
    } finally {
      if (mounted) setState(() => _isSubmittingSchedule = false);
    }
  }

  Future<void> _submitReschedule() async {
    if (_rescheduleDateTime == null) {
      _showSnack('Please pick a new date and time first.');
      return;
    }
    setState(() => _isSubmittingSchedule = true);
    try {
      final reason = _rescheduleReasonController.text.trim();
      await widget.onProposeReschedule
          ?.call(_rescheduleDateTime!, reason.isEmpty ? null : reason);
    } finally {
      if (mounted) setState(() => _isSubmittingSchedule = false);
    }
  }

  Future<void> _submitPrice() async {
    final raw = _priceController.text.trim();
    final price = double.tryParse(raw);
    if (price == null || price <= 0) {
      _showSnack('Please enter a valid price.',
          color: const Color(0xFFFF3B30), icon: Icons.error_outline_rounded);
      return;
    }
    setState(() => _isSubmittingPrice = true);
    try {
      await widget.onSetAssessmentPrice?.call(price);
      // Success feedback — fires at the moment the card swaps out so the
      // handyman gets an immediate confirmation at eye level.
      if (mounted) {
        _showSnack(
          '₱${price.toStringAsFixed(0)} sent to customer. Waiting for their confirmation.',
          color: const Color(0xFF5856D6),
          icon: Icons.check_circle_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingPrice = false);
    }
  }

  void _showSnack(String msg, {Color? color, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color ?? AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── VIEW — build ───────────────────────────────────────────────────────────

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
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBookingInfoCard()
                        .animate()
                        .fadeIn(delay: 80.ms)
                        .slideY(begin: 0.05, end: 0),
                    if (widget.booking.photoUrl != null &&
                        widget.booking.photoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPhotoCard()
                          .animate()
                          .fadeIn(delay: 120.ms)
                          .slideY(begin: 0.05, end: 0),
                    ],
                    const SizedBox(height: 16),
                    _buildActionSection()
                        .animate()
                        .fadeIn(delay: 150.ms)
                        .slideY(begin: 0.05, end: 0),
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
                      const Text('Booking Detail',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      Text(widget.booking.serviceType,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13)),
                    ]),
              ),
              _statusChip(),
            ]),
          ),
        ),
      );

  Widget _statusChip() {
    final s = widget.booking.status;
    Color color;
    String label;
    switch (s) {
      case BookingStatus.accepted:
        color = const Color(0xFF007AFF);
        label = 'Accepted';
        break;
      case BookingStatus.scheduleProposed:
        color = const Color(0xFFFF9500);
        label = 'Sched. Sent';
        break;
      case BookingStatus.scheduled:
        color = const Color(0xFF007AFF);
        label = 'Scheduled';
        break;
      case BookingStatus.pendingArrivalConfirmation:
        color = const Color(0xFF34C759);
        label = 'Arrived';
        break;
      case BookingStatus.assessment:
        color = const Color(0xFF5856D6);
        label = 'Assessment';
        break;
      case BookingStatus.inProgress:
        color = const Color(0xFF34C759);
        label = 'In Progress';
        break;
      case BookingStatus.completed:
        color = AppColors.primary;
        label = 'Completed';
        break;
      default:
        color = const Color(0xFFFF9500);
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ── VIEW — Booking Info Card ───────────────────────────────────────────────

  Widget _buildBookingInfoCard() {
    final b = widget.booking;

    return Container(
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
        const Text('Job Details',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        const SizedBox(height: 16),

        _infoRow(Icons.build_rounded, 'Service', b.serviceType),

        if (b.description != null && b.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _infoRow(Icons.article_rounded, 'Issue Details', b.description!),
        ],

        if (b.notes != null && b.notes!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _infoRow(Icons.sticky_note_2_outlined, 'Customer Notes', b.notes!),
        ],

        if (b.priceEstimate != null && b.priceEstimate! > 0) ...[
          const SizedBox(height: 10),
          _estimatedRateRow(b.priceEstimate!),
        ],

        const SizedBox(height: 10),
        _infoRow(
            Icons.person_rounded, 'Customer', b.customer?.name ?? 'Customer'),

        if (b.customer?.phone != null && b.customer!.phone!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _phoneRow(b.customer!.phone!),
        ],

        // ── Customer's preferred time (always shown) ───────────────────────
        const SizedBox(height: 10),
        _infoRow(
          Icons.calendar_today_rounded,
          'Customer\'s Preferred Time',
          DateFormat('MMM d, yyyy · h:mm a')
              .format(_customerPreferredTime.toLocal()),
        ),

        // Confirmed start only shown once schedule is set and status advanced.
        if (b.scheduledTime != null && b.status != BookingStatus.accepted) ...[
          const SizedBox(height: 10),
          _infoRow(
            Icons.schedule_rounded,
            'Confirmed Start',
            DateFormat('MMM d, yyyy · h:mm a')
                .format(b.scheduledTime!.toLocal()),
          ),
        ],

        if (b.address != null && b.address!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _locationRow(b),
        ],

        if (b.assessmentPrice != null) ...[
          const SizedBox(height: 10),
          _infoRow(Icons.payments_rounded, 'Assessment Price',
              '₱${b.assessmentPrice!.toStringAsFixed(0)}'),
        ],
      ]),
    );
  }

  // ── VIEW — row helpers ─────────────────────────────────────────────────────

  Widget _estimatedRateRow(double priceEstimate) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.price_check_rounded,
                size: 16, color: Color(0xFFCC7700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Estimated Rate',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(
                  'From ₱${priceEstimate.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('estimate',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCC7700))),
                ),
              ]),
            ]),
          ),
        ],
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

  Widget _phoneRow(String phone) => GestureDetector(
        onTap: () async {
          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            _showSnack('Could not open the dialer.');
          }
        },
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_rounded,
                size: 16, color: Color(0xFF34C759)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Phone',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(phone,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF34C759))),
            ]),
          ),
        ]),
      );

  Widget _locationRow(BookingEntity b) {
    final address = b.address ?? '';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _infoRow(Icons.location_on_rounded, 'Location', address)),
      if ((b.latitude != null && b.longitude != null) || address.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.map_rounded, color: AppColors.primary),
          onPressed: () => _openMaps(b),
        ),
    ]);
  }

  Future<void> _openMaps(BookingEntity b) async {
    try {
      if (b.latitude != null && b.longitude != null) {
        final uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${b.latitude},${b.longitude}');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _showSnack('Could not open maps.');
        }
        return;
      }
      final address = b.address ?? '';
      if (address.isNotEmpty) {
        final encoded = Uri.encodeComponent(address);
        final uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encoded');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _showSnack('Could not open maps.');
        }
        return;
      }
      _showSnack('Location not available.');
    } catch (e) {
      _showSnack('Failed to open maps: $e');
    }
  }

  // ── VIEW — Issue Photo Card ────────────────────────────────────────────────

  Widget _buildPhotoCard() {
    final photoUrl = widget.booking.photoUrl!;
    return GestureDetector(
      onTap: () => _showPhotoPreview(context, photoUrl),
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF9500), Color(0xFFFFB340)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_camera_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Issue Photo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2)),
                      Text('Uploaded by customer · Tap to expand',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ]),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.zoom_out_map_rounded,
                    color: Colors.white, size: 16),
              ),
            ]),
          ),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: Image.network(
              photoUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFFFFF3E0),
                  child: const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Color(0xFFFF9500))),
                      SizedBox(height: 8),
                      Text('Loading photo…',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFCC7700))),
                    ]),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFFFF3E0),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.broken_image_rounded,
                        size: 40, color: Color(0xFFCC7700)),
                    SizedBox(height: 8),
                    Text('Could not load photo',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFFCC7700))),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _showPhotoPreview(BuildContext context, String photoUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(alignment: Alignment.center, children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 5.0,
            child: Image.network(
              photoUrl,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 200,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ]),
      ),
    );
  }

  // ── VIEW — Status-specific action sections ─────────────────────────────────

  Widget _buildActionSection() {
    switch (widget.booking.status) {
      case BookingStatus.accepted:
        // SIMPLIFIED: handyman confirms the customer's time directly.
        return _buildConfirmCustomerScheduleSection();
      case BookingStatus.scheduleProposed:
        // Reschedule edge-case: handyman already proposed a new time and is
        // waiting for the customer to accept or decline.
        return _buildWaitingForScheduleConfirm();
      case BookingStatus.scheduled:
        // Handyman confirmed schedule; heading to customer's location.
        // Shows "Start Assessment — I've Arrived" as the primary CTA.
        return _buildScheduledSection();
      case BookingStatus.pendingArrivalConfirmation:
        // Handyman tapped "I've Arrived". Waiting for the customer to confirm
        // via their BookingStatusScreen before price-setting unlocks.
        return _buildWaitingForArrivalConfirm();
      case BookingStatus.assessment:
        // Customer confirmed arrival. Handyman now sets the assessment price.
        return _buildAssessmentPriceSection();
      case BookingStatus.inProgress:
        return _buildMarkCompleteSection();
      case BookingStatus.completed:
        return _buildCompletedSection();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── VIEW — (1) accepted → confirm customer's time ─────────────────────────
  //
  // Schedule negotiation removed. Handyman sees the customer's preferred
  // time and confirms it with one tap. If they cannot make it, they should
  // decline/skip the booking from the requests list instead.

  Widget _buildConfirmCustomerScheduleSection() {
    final preferredDate = DateFormat('EEEE, MMMM d, yyyy')
        .format(_customerPreferredTime.toLocal());
    final preferredTime =
        DateFormat('h:mm a').format(_customerPreferredTime.toLocal());

    return Container(
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
        // ── Section header ─────────────────────────────────────────────────
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Color(0xFF007AFF), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Confirm Schedule',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              Text('Accept the customer\'s preferred time',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),

        // ── Customer's preferred time display ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.person_rounded,
                color: Color(0xFF007AFF), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer\'s preferred time',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(preferredDate,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    Text(preferredTime,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Confirm button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmittingSchedule ? null : _confirmCustomerSchedule,
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: _isSubmittingSchedule
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Confirm — I\'ll be there',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Notice ─────────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Icon(Icons.info_outline_rounded,
              size: 14, color: AppColors.textLight),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Can\'t make this time? Skip this booking from the Requests list '
              'and let another handyman accept it.',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textLight, height: 1.4),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── VIEW — (2) scheduleProposed → waiting for customer ────────────────────

  Widget _buildWaitingForScheduleConfirm() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9500).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFFFF9500), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waiting for Customer',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF9500))),
              SizedBox(height: 4),
              Text(
                'The customer is reviewing your proposed schedule. '
                'You\'ll be notified once they confirm.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ]),
          ),
        ]),
      );

  // ── VIEW — (3) scheduled → head to location, tap "I've Arrived" ───────────
  //
  // Price setter removed from this section — it only unlocks after the
  // customer confirms the handyman has arrived (assessment status).

  Widget _buildScheduledSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Confirmed schedule banner ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: const Color(0xFF34C759).withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.event_available_rounded,
                color: Color(0xFF34C759), size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Schedule confirmed. Head to the customer\'s location and '
                'tap "Start Assessment" when you arrive.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── PRIMARY CTA: I've Arrived ────────────────────────────────────────
        _buildStartAssessmentButton(),
        const SizedBox(height: 16),

        // ── Reschedule (running late) ────────────────────────────────────────
        _buildRescheduleSection(),
      ]);

  /// "Start Assessment" — primary CTA for the scheduled status.
  /// Handyman taps when they have physically arrived on-site.
  /// Fires onStartAssessment() → status = pendingArrivalConfirmation.
  /// Price-setting unlocks only after the customer confirms arrival.
  Widget _buildStartAssessmentButton() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF30B0C7).withOpacity(0.32),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: widget.onStartAssessment != null
              ? () => _confirmStartAssessment(context)
              : null,
          icon: const Icon(Icons.directions_walk_rounded, size: 20),
          label: const Text(
            'Start Assessment — I\'ve Arrived',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF30B0C7),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );

  void _confirmStartAssessment(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Start Assessment?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text(
          'Confirm that you have arrived at the customer\'s location and are '
          'ready to assess the job. The customer will be notified.',
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
              widget.onStartAssessment?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF30B0C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Yes, I\'ve Arrived',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── VIEW — Price setter ────────────────────────────────────────────────────

  Widget _buildPriceSetter() => Container(
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
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF5856D6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments_rounded,
                  color: Color(0xFF5856D6), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set Assessment Price',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    Text('After assessing the job at the site',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: InputDecoration(
              hintText: 'Enter price (₱)',
              prefixIcon:
                  const Icon(Icons.payments_outlined, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingPrice ? null : _submitPrice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5856D6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
              ),
              child: _isSubmittingPrice
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Price to Customer',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );

  // ── VIEW — Reschedule section ──────────────────────────────────────────────

  Widget _buildRescheduleSection() => Container(
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
          const Row(children: [
            Icon(Icons.update_rounded, color: Color(0xFFFF9500), size: 18),
            SizedBox(width: 8),
            Text('Running late?',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Propose a new time and let the customer know.',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _pickReschedule,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded,
                    color: Color(0xFFFF9500), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: _rescheduleDateTime != null
                      ? Text(
                          DateFormat('MMM d, yyyy · h:mm a')
                              .format(_rescheduleDateTime!),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark),
                        )
                      : const Text('Pick new date & time',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textLight)),
                ),
                const Icon(Icons.edit_rounded,
                    color: Color(0xFFFF9500), size: 16),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _rescheduleReasonController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Reason (optional) — e.g. traffic, bad weather, etc.',
              filled: true,
              fillColor: AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSubmittingSchedule ? null : _submitReschedule,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Request Reschedule',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF9500),
                side: const BorderSide(color: Color(0xFFFF9500)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      );

  // ── VIEW — (4) pendingArrivalConfirmation → waiting for customer ──────────
  //
  // Handyman tapped "I've Arrived". Now waiting for the customer to confirm
  // via their BookingStatusScreen. No action available to the handyman here.

  Widget _buildWaitingForArrivalConfirm() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF34C759).withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.where_to_vote_rounded,
                color: Color(0xFF34C759), size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waiting for Customer to Confirm Arrival',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34C759))),
              SizedBox(height: 4),
              Text(
                'The customer has been notified that you\'ve arrived. '
                'You\'ll be able to set the price once they confirm.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ]),
          ),
        ]),
      );

  // ── VIEW — (5) assessment → set price ─────────────────────────────────────
  //
  // Customer confirmed arrival. Handyman assesses the job and sets a price.
  // After sending the price, the customer reviews and confirms via
  // AssessmentScreen → status = inProgress.

  Widget _buildAssessmentPriceSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Arrival confirmed banner ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: const Color(0xFF34C759).withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF34C759), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Customer confirmed your arrival. Assess the job and '
                'set the price below.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Inline swap: price setter → waiting banner ───────────────────────
        // Once the price is sent (assessmentPrice != null), the input card is
        // replaced in-place by the waiting banner. The snackbar fired from
        // _submitPrice() provides the immediate at-button-level confirmation.
        if (widget.booking.assessmentPrice == null)
          _buildPriceSetter()
        else
          _buildWaitingForPriceConfirm(),
      ]);

  // ── VIEW — Waiting for customer to confirm the price ──────────────────────

  Widget _buildWaitingForPriceConfirm() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF5856D6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF5856D6).withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF5856D6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFF5856D6), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Price Sent — Awaiting Customer',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5856D6))),
              const SizedBox(height: 4),
              Text(
                'You set ₱${widget.booking.assessmentPrice!.toStringAsFixed(0)}. '
                'The customer is reviewing and will confirm shortly.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ]),
          ),
        ]),
      );

  // ── VIEW — (6) inProgress → mark complete ─────────────────────────────────

  Widget _buildMarkCompleteSection() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onMarkComplete,
          icon: const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text('Mark Job as Complete',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
        ),
      );

  // ── VIEW — (6) completed ───────────────────────────────────────────────────

  Widget _buildCompletedSection() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Job Completed',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              SizedBox(height: 4),
              Text('Great work! This job is done.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
            ]),
          ),
        ]),
      );
}
