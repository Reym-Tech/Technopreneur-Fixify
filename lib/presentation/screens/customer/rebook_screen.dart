// lib/presentation/screens/customer/rebook_screen.dart
//
// RebookScreen — ONE-TAP REBOOK
//
// MVC ROLE: VIEW
//   • Receives the original completed BookingEntity and fires onConfirm.
//   • No direct data-source calls.
//
// Shown when the customer taps "Book Again" on a completed booking.
// All fields are pre-filled from the original booking — the customer only
// needs to pick a preferred date. Everything else is remembered.
//
// Layout (top to bottom):
//   1. Header — "Book Again" with original service title as subtitle
//   2. Original booking summary card — service, handyman, address, last price
//   3. Date picker row — the only field the customer needs to touch
//   4. What to expect info box
//   5. Pinned "Confirm Booking" button
//
// Props:
//   booking   → BookingEntity   — the completed booking being rebooked
//   onConfirm → Function(RebookConfirmData) — fires on confirm tap
//   onBack    → VoidCallback?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

// ── Result data passed to the Controller on confirm ──────────────────────────

class RebookConfirmData {
  final String customerId;
  final String serviceType;
  final String? serviceTitle;
  final String? professionalId;
  final DateTime preferredDate;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? priceEstimate;

  const RebookConfirmData({
    required this.customerId,
    required this.serviceType,
    this.serviceTitle,
    this.professionalId,
    required this.preferredDate,
    this.address,
    this.latitude,
    this.longitude,
    this.priceEstimate,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class RebookScreen extends StatefulWidget {
  final BookingEntity booking;
  final Future<void> Function(RebookConfirmData data)? onConfirm;
  final VoidCallback? onBack;

  const RebookScreen({
    super.key,
    required this.booking,
    this.onConfirm,
    this.onBack,
  });

  @override
  State<RebookScreen> createState() => _RebookScreenState();
}

class _RebookScreenState extends State<RebookScreen> {
  // Default to tomorrow so the date is always in the future on open.
  DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;

  BookingEntity get _b => widget.booking;

  // ── DATE PICKER ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _preferredDate = picked);
    }
  }

  // ── CONFIRM ───────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    if (_b.customerId.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirm?.call(RebookConfirmData(
        customerId: _b.customerId,
        serviceType: _b.serviceType,
        serviceTitle: _b.serviceTitle,
        professionalId: _b.professionalId,
        preferredDate: _preferredDate,
        address: _b.address,
        latitude: _b.latitude,
        longitude: _b.longitude,
        // Use the last agreed price as the estimate so the handyman
        // and customer start from a familiar reference point.
        priceEstimate: _b.assessmentPrice ?? _b.priceEstimate,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not place booking: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Original booking summary ──────────────────────────
                  _buildSummaryCard()
                      .animate()
                      .fadeIn(delay: 80.ms)
                      .slideY(begin: 0.06, end: 0),
                  const SizedBox(height: 20),

                  // ── Date picker ───────────────────────────────────────
                  _sectionLabel('Preferred Date'),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose when you would like the handyman to return.',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 10),
                  _buildDatePicker()
                      .animate()
                      .fadeIn(delay: 130.ms)
                      .slideY(begin: 0.06, end: 0),
                  const SizedBox(height: 24),

                  // ── Info box ──────────────────────────────────────────
                  _buildInfoBox()
                      .animate()
                      .fadeIn(delay: 160.ms)
                      .slideY(begin: 0.06, end: 0),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ]),
        bottomNavigationBar: _buildConfirmButton(),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final serviceTitle =
        _b.serviceTitle?.isNotEmpty == true ? _b.serviceTitle! : _b.serviceType;
    return Container(
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
                  const Text('Book Again',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                  Text(serviceTitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // "Pre-filled" badge — signals to the customer they don't
            // need to re-enter anything.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Text('Pre-filled',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Original booking summary card ─────────────────────────────────────────

  Widget _buildSummaryCard() {
    final serviceTitle =
        _b.serviceTitle?.isNotEmpty == true ? _b.serviceTitle! : _b.serviceType;
    final proName = _b.professional?.name;
    final hasPrice = _b.assessmentPrice != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card label
        Row(children: [
          const Icon(Icons.history_rounded,
              size: 14, color: AppColors.textLight),
          const SizedBox(width: 6),
          const Text('Rebooking from',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                  letterSpacing: 0.1)),
        ]),
        const SizedBox(height: 12),

        // Service name
        Text(serviceTitle,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.2)),

        // Service type chip when title differs
        if (_b.serviceTitle?.isNotEmpty == true &&
            _b.serviceTitle != _b.serviceType) ...[
          const SizedBox(height: 4),
          Text(_b.serviceType,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ],

        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 14),

        // Detail rows — everything that will be pre-filled
        if (proName != null && proName.isNotEmpty)
          _summaryRow(
            Icons.person_outline_rounded,
            'Handyman',
            proName,
            hint: 'Same handyman will be requested',
          ),
        if (proName != null) const SizedBox(height: 10),

        if (_b.address != null && _b.address!.isNotEmpty)
          _summaryRow(
            Icons.location_on_outlined,
            'Address',
            _b.address!,
          ),
        if (_b.address != null) const SizedBox(height: 10),

        if (hasPrice)
          _summaryRow(
            Icons.payments_outlined,
            'Last Price Paid',
            '₱${_b.assessmentPrice!.toStringAsFixed(0)}',
            hint: 'Used as price reference',
          ),

        // Pre-filled indicator — reassures customer nothing is missing
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'All details above are pre-filled from your previous booking. '
                'Just pick a date below and confirm.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.primary, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Summary row helper ────────────────────────────────────────────────────

  Widget _summaryRow(
    IconData icon,
    String label,
    String value, {
    String? hint,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: AppColors.textLight),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(hint,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ),
        ],
      ]);

  // ── Date picker ───────────────────────────────────────────────────────────

  Widget _buildDatePicker() => GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preferred Date',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_preferredDate),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded,
                size: 18, color: AppColors.primary),
          ]),
        ),
      );

  // ── Info box ──────────────────────────────────────────────────────────────

  Widget _buildInfoBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What happens next?',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  SizedBox(height: 4),
                  Text(
                    'Your booking will be sent directly to the same handyman. '
                    'They will confirm the schedule and get in touch. '
                    'You can cancel anytime before the job begins.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMedium, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark));

  // ── Confirm button ────────────────────────────────────────────────────────

  Widget _buildConfirmButton() => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Confirm Booking',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
}
