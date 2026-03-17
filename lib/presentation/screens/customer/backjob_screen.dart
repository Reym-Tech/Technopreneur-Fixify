// lib/presentation/screens/customer/backjob_screen.dart
//
// BackjobScreen — WARRANTY CLAIM SUBMISSION
//
// MVC ROLE: VIEW
//   • Receives the original completed BookingEntity and fires onSubmit callback.
//   • No direct data-source calls.
//
// Shown when the customer taps "Backjob" on a completed booking that is
// still within its warranty period.
//
// The screen shows:
//   1. A summary card of the original booking (service, date, pro name).
//   2. A warranty status banner with expiry date.
//   3. An issue description text field.
//   4. A preferred date picker.
//   5. A "Submit Backjob Request" button.
//
// Props:
//   booking         → BookingEntity    — the completed booking being claimed
//   onSubmit        → Function(BackjobSubmitData) — fires on tap of submit btn
//   onBack          → VoidCallback?

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

// ── Result data passed to the Controller on submit ───────────────────────────

class BackjobSubmitData {
  final String originalBookingId;
  final String serviceType;
  final String serviceTitle;
  final String description;
  final DateTime preferredDate;

  const BackjobSubmitData({
    required this.originalBookingId,
    required this.serviceType,
    required this.serviceTitle,
    required this.description,
    required this.preferredDate,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class BackjobScreen extends StatefulWidget {
  final BookingEntity booking;
  final Future<void> Function(BackjobSubmitData data)? onSubmit;
  final VoidCallback? onBack;

  const BackjobScreen({
    super.key,
    required this.booking,
    this.onSubmit,
    this.onBack,
  });

  @override
  State<BackjobScreen> createState() => _BackjobScreenState();
}

class _BackjobScreenState extends State<BackjobScreen> {
  final _descCtrl = TextEditingController();
  DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;

  BookingEntity get _b => widget.booking;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── WARRANTY LABEL ────────────────────────────────────────────────────────

  /// Returns a human-readable remaining-warranty string.
  /// Safe when warrantyExpiresAt is null — returns a generic active label.
  String _warrantyLabel() {
    final exp = _b.warrantyExpiresAt;
    if (exp == null) return 'Warranty active';
    final diff = exp.difference(DateTime.now());
    final days = diff.inDays;
    if (days <= 0) return 'Expires today';
    if (days == 1) return '1 day remaining';
    if (days < 30) return '$days days remaining';
    final months = (days / 30).floor();
    return '$months month${months > 1 ? 's' : ''} remaining';
  }

  /// Formats the warranty expiry date for display.
  /// Returns 'Unknown' safely when warrantyExpiresAt is null, which happens
  /// on old completed bookings that pre-date the warranty system.
  String _warrantyExpiry() {
    final exp = _b.warrantyExpiresAt;
    if (exp == null) return 'Unknown';
    return DateFormat('MMMM d, yyyy').format(exp.toLocal());
  }

  // ── DATE PICKER ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
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

  // ── SUBMIT ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _snack('Please describe the issue you are experiencing.');
      return;
    }

    final serviceTitle = _b.serviceTitle ?? _b.serviceType;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit?.call(BackjobSubmitData(
        originalBookingId: _b.id,
        serviceType: _b.serviceType,
        serviceTitle: serviceTitle,
        description: desc,
        preferredDate: _preferredDate,
      ));
    } catch (e) {
      if (mounted) _snack('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
                    // ── Warranty status banner ──────────────────────────────
                    _buildWarrantyBanner()
                        .animate()
                        .fadeIn(delay: 80.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 16),

                    // ── Original booking summary ────────────────────────────
                    _buildOriginalBookingCard()
                        .animate()
                        .fadeIn(delay: 130.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 24),

                    // ── Issue description ───────────────────────────────────
                    _sectionLabel('Describe the Issue *'),
                    const SizedBox(height: 4),
                    const Text(
                      'Explain what problem has reoccurred since the original service.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. The drain is clogged again after 2 weeks...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AppColors.textLight),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFFDDDDDD)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ).animate().fadeIn(delay: 180.ms),
                    const SizedBox(height: 24),

                    // ── Preferred date ──────────────────────────────────────
                    _sectionLabel('Preferred Service Date *'),
                    const SizedBox(height: 10),
                    _buildDatePicker()
                        .animate()
                        .fadeIn(delay: 220.ms)
                        .slideY(begin: 0.06, end: 0),
                    const SizedBox(height: 32),

                    // ── What happens next info box ──────────────────────────
                    _buildInfoBox()
                        .animate()
                        .fadeIn(delay: 260.ms)
                        .slideY(begin: 0.06, end: 0),

                    const SizedBox(height: 40),
                  ]),
            ),
          ),
        ]),
        bottomNavigationBar: _buildSubmitButton(),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A2E3F), Color(0xFF1D8A9E), Color(0xFF30B0C7)],
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
                    color: Colors.white.withOpacity(0.15),
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
                      Text('Backjob Request',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      Text('Warranty claim',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 13)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  const Text('Under Warranty',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      );

  // ── Warranty status banner ─────────────────────────────────────────────────

  Widget _buildWarrantyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF30B0C7).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF30B0C7).withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF30B0C7).withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.verified_user_rounded,
              color: Color(0xFF30B0C7), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Warranty Active',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D8A9E))),
            const SizedBox(height: 2),
            Text(
              '${_warrantyLabel()}  •  Expires ${_warrantyExpiry()}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMedium, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Original booking summary card ─────────────────────────────────────────

  Widget _buildOriginalBookingCard() {
    final proName = _b.professional?.name ?? 'Your Handyman';
    final serviceTitle = _b.serviceTitle ?? _b.serviceType;
    final completedDate =
        DateFormat('MMMM d, yyyy').format(_b.scheduledDate.toLocal());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section label
        Row(children: [
          const Icon(Icons.history_rounded,
              size: 15, color: AppColors.textLight),
          const SizedBox(width: 6),
          const Text('Original Booking',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                  letterSpacing: 0.2)),
        ]),
        const SizedBox(height: 12),
        // Service name
        Text(serviceTitle,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.2)),
        const SizedBox(height: 8),
        // Type chip + completed badge
        Row(children: [
          _miniChip(_b.serviceType, AppColors.primary),
          const SizedBox(width: 8),
          _miniChip('Completed', const Color(0xFF34C759)),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 12),
        // Details row — person + date always side by side
        Row(children: [
          _detailPill(Icons.person_rounded, proName),
          const SizedBox(width: 12),
          _detailPill(Icons.calendar_today_rounded, completedDate),
        ]),
        // Address — full width row beneath when present
        if (_b.address != null && _b.address!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            _detailPill(Icons.location_on_rounded, _b.address!),
          ]),
        ],
      ]),
    );
  }

  Widget _miniChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  // _detailPill uses Flexible which requires a Row parent.
  // Always call this inside a Row — never as a bare Column child.
  Widget _detailPill(IconData icon, String text) => Flexible(
        child: Row(children: [
          Icon(icon, size: 13, color: AppColors.textLight),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  // ── Date picker widget ────────────────────────────────────────────────────

  Widget _buildDatePicker() => GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
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
                  ]),
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ℹ️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('What happens next?',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              SizedBox(height: 4),
              Text(
                'Your backjob request will be sent to the original handyman as a new booking. '
                'They will review your issue and confirm the schedule. '
                'This service is covered under your warranty at no extra charge.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.5),
              ),
            ]),
          ),
        ]),
      );

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark));

  // ── Submit button ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() => Container(
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
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF30B0C7),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF30B0C7).withOpacity(0.5),
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Submit Backjob Request',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ),
      );
}
