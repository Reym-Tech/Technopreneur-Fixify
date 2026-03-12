// lib/presentation/screens/professional/pro_booking_detail_screen.dart
//
// SCHEDULING UPDATE:
//   accepted status:
//     • Shows customer's preferred time prominently.
//     • Default: "Confirm Customer's Time" — one tap, no back-and-forth.
//     • Toggle "Propose a different time" reveals a date/time picker for the
//       handyman to suggest an alternative slot.
//     • Both paths call onProposeSchedule(DateTime).
//
//   scheduleProposed status:
//     • Shows "Waiting for customer to confirm the schedule" banner.
//
//   scheduled status:
//     • Shows the agreed schedule.
//     • Shows price setter (handyman arrived, now setting the assessment price).
//     • Also shows "Propose Reschedule" option (running late / new job).
//
//   assessment status:
//     • Shows "Waiting for Customer Confirmation" banner (unchanged).
//
//   inProgress status:
//     • Shows "Mark as Complete" button (unchanged).

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

  /// Called when the handyman confirms or proposes a start date/time.
  /// parent calls supabase.proposeSchedule()
  final Function(DateTime proposedTime)? onProposeSchedule;

  /// Called when the handyman wants to reschedule.
  /// parent calls supabase.proposeReschedule()
  final Function(DateTime newTime, String? reason)? onProposeReschedule;

  /// Called when the handyman sets an assessment price.
  /// parent calls supabase.updateBookingAssessmentPrice()
  final Function(double price)? onSetAssessmentPrice;

  /// Called when the handyman marks the job complete.
  final VoidCallback? onMarkComplete;

  const ProBookingDetailScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onProposeSchedule,
    this.onProposeReschedule,
    this.onSetAssessmentPrice,
    this.onMarkComplete,
  });

  @override
  State<ProBookingDetailScreen> createState() => _ProBookingDetailScreenState();
}

class _ProBookingDetailScreenState extends State<ProBookingDetailScreen> {
  // ── Schedule state ─────────────────────────────────────────────────────────
  DateTime? _selectedDateTime;
  bool _isSubmittingSchedule = false;

  /// When false (default): the customer's preferred time is confirmed as-is.
  /// When true: the date/time picker is revealed so the handyman can suggest
  /// a different slot.
  bool _proposingAlternative = false;

  // ── Price state ────────────────────────────────────────────────────────────
  final _priceController = TextEditingController();
  bool _isSubmittingPrice = false;

  // ── Reschedule state ───────────────────────────────────────────────────────
  DateTime? _rescheduleDateTime;
  final _rescheduleReasonController = TextEditingController();

  /// The customer's original preferred time.
  DateTime get _customerPreferredTime =>
      widget.booking.scheduledTime ?? widget.booking.scheduledDate;

  @override
  void initState() {
    super.initState();
    // Seed alternative picker with customer's time so handyman only tweaks.
    _selectedDateTime = _customerPreferredTime;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _rescheduleReasonController.dispose();
    super.dispose();
  }

  // ── Date/time picker helpers ───────────────────────────────────────────────

  Future<void> _pickSchedule({bool isReschedule = false}) async {
    final initial = isReschedule
        ? (_rescheduleDateTime ?? DateTime.now())
        : (_selectedDateTime ?? _customerPreferredTime);

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

    final combined =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isReschedule) {
        _rescheduleDateTime = combined;
      } else {
        _selectedDateTime = combined;
      }
    });
  }

  // ── Submit schedule ────────────────────────────────────────────────────────

  Future<void> _submitSchedule() async {
    // Not proposing alternative → confirm the customer's own preferred time.
    final timeToSend =
        _proposingAlternative ? _selectedDateTime! : _customerPreferredTime;

    setState(() => _isSubmittingSchedule = true);
    try {
      await widget.onProposeSchedule?.call(timeToSend);
    } finally {
      if (mounted) setState(() => _isSubmittingSchedule = false);
    }
  }

  // ── Submit reschedule ──────────────────────────────────────────────────────

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

  // ── Submit price ───────────────────────────────────────────────────────────

  Future<void> _submitPrice() async {
    final raw = _priceController.text.trim();
    final price = double.tryParse(raw);
    if (price == null || price <= 0) {
      _showSnack('Please enter a valid price.');
      return;
    }
    setState(() => _isSubmittingPrice = true);
    try {
      await widget.onSetAssessmentPrice?.call(price);
    } finally {
      if (mounted) setState(() => _isSubmittingPrice = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  // ── Booking Info ───────────────────────────────────────────────────────────

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
        const SizedBox(height: 14),
        _infoRow(Icons.build_rounded, 'Service', b.serviceType),
        const SizedBox(height: 10),
        _infoRow(
            Icons.person_rounded, 'Customer', b.customer?.name ?? 'Customer'),
        const SizedBox(height: 10),
        _infoRow(
          Icons.calendar_today_rounded,
          'Customer\'s Preferred Time',
          DateFormat('MMM d, yyyy · h:mm a')
              .format(_customerPreferredTime.toLocal()),
        ),
        // Only show confirmed start when status is past the accepted phase
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
        if (b.description != null && b.description!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _infoRow(Icons.notes_rounded, 'Notes', b.description!),
        ],
        if (b.assessmentPrice != null) ...[
          const SizedBox(height: 10),
          _infoRow(Icons.payments_rounded, 'Assessment Price',
              '₱${b.assessmentPrice!.toStringAsFixed(0)}'),
        ],
      ]),
    );
  }

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

  // ── Status-specific actions ────────────────────────────────────────────────

  Widget _buildActionSection() {
    switch (widget.booking.status) {
      case BookingStatus.accepted:
        return _buildConfirmOrProposeSection();
      case BookingStatus.scheduleProposed:
        return _buildWaitingForScheduleConfirm();
      case BookingStatus.scheduled:
        return _buildScheduledSection();
      case BookingStatus.assessment:
        return _buildWaitingForAssessmentConfirm();
      case BookingStatus.inProgress:
        return _buildMarkCompleteSection();
      case BookingStatus.completed:
        return _buildCompletedSection();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── (1) accepted → confirm customer time OR propose alternative ────────────

  Widget _buildConfirmOrProposeSection() {
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
              Text('Schedule',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              Text('Confirm or propose a different time',
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
        const SizedBox(height: 14),

        // ── "Propose a different time" toggle ──────────────────────────────
        GestureDetector(
          onTap: () => setState(() {
            _proposingAlternative = !_proposingAlternative;
            // Reset to customer's time when toggling on so the picker opens
            // close to the requested slot.
            if (_proposingAlternative) {
              _selectedDateTime = _customerPreferredTime;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _proposingAlternative
                  ? const Color(0xFFFF9500).withOpacity(0.07)
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _proposingAlternative
                    ? const Color(0xFFFF9500).withOpacity(0.4)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(children: [
              Icon(
                _proposingAlternative
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                color: _proposingAlternative
                    ? const Color(0xFFFF9500)
                    : AppColors.textLight,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "I can't make that time — propose a different one",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _proposingAlternative
                              ? const Color(0xFFFF9500)
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Customer will review and accept or decline.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textLight),
                      ),
                    ]),
              ),
            ]),
          ),
        ),

        // ── Alternative picker — only when toggled on ──────────────────────
        if (_proposingAlternative) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickSchedule(),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.schedule_rounded,
                    color: Color(0xFFFF9500), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedDateTime != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy')
                                  .format(_selectedDateTime!),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark),
                            ),
                            Text(
                              DateFormat('h:mm a').format(_selectedDateTime!),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textLight),
                            ),
                          ],
                        )
                      : const Text('Tap to pick a different date & time',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textLight)),
                ),
                const Icon(Icons.edit_calendar_rounded,
                    color: Color(0xFFFF9500), size: 18),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Primary action button ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmittingSchedule ? null : _submitSchedule,
            icon: Icon(
              _proposingAlternative
                  ? Icons.send_rounded
                  : Icons.check_circle_rounded,
              size: 18,
            ),
            label: _isSubmittingSchedule
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _proposingAlternative
                        ? 'Send Alternative Time to Customer'
                        : 'Confirm',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _proposingAlternative
                  ? const Color(0xFFFF9500)
                  : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }

  // ── (2) scheduleProposed → waiting for customer ────────────────────────────

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

  // ── (3) scheduled → handyman sets price OR proposes reschedule ─────────────

  Widget _buildScheduledSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                'Schedule confirmed by customer. '
                'Arrive on time and assess the job, then set the price below.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _buildPriceSetter(),
        const SizedBox(height: 16),
        _buildRescheduleSection(),
      ]);

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
            onTap: () => _pickSchedule(isReschedule: true),
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
              hintText: 'Reason (optional) — e.g. still on another job',
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

  // ── (4) assessment → waiting for customer price confirm ───────────────────

  Widget _buildWaitingForAssessmentConfirm() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF5856D6).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5856D6).withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF5856D6).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFF5856D6), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Waiting for Customer Confirmation',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5856D6))),
              const SizedBox(height: 4),
              Text(
                widget.booking.assessmentPrice != null
                    ? 'You set ₱${widget.booking.assessmentPrice!.toStringAsFixed(0)}. '
                        'The customer is reviewing and will confirm shortly.'
                    : 'The customer is reviewing your assessment. '
                        'You\'ll be notified when they confirm.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ]),
          ),
        ]),
      );

  // ── (5) inProgress → mark complete ────────────────────────────────────────

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

  // ── (6) completed ──────────────────────────────────────────────────────────

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
