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
//   1. A warranty status banner with expiry date.
//   2. A summary card of the original booking (service, date, pro name).
//   3. An issue description text field.
//   4. A preferred date picker.
//   5. A "Submit Backjob Request" button.
//
// Props:
//   booking         → BookingEntity    — the completed booking being claimed
//   onSubmit        → Function(BackjobSubmitData) — fires on tap of submit btn
//   onBack          → VoidCallback?
//
// DESIGN: Minimalist — dark green gradient header matches BookingStatusScreen
// and CustomerBookingsScreen. White cards on #F2F2F7 background. Teal accent
// used only for warranty-specific elements so it reads as a semantic signal,
// not a full-screen theme. Consistent with the rest of the AYO customer flow.

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

  // Teal used exclusively for warranty-related accents throughout the screen.
  static const _teal = Color(0xFF30B0C7);
  static const _tealDark = Color(0xFF1D8A9E);
  static const _tealBg = Color(0xFFE8F8FB);

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── WARRANTY HELPERS ──────────────────────────────────────────────────────

  /// Human-readable remaining warranty time. Null-safe.
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

  /// Formatted expiry date. Returns 'Unknown' safely when null.
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
          colorScheme: const ColorScheme.light(
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
        backgroundColor: const Color(0xFFF2F2F7),
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Warranty status banner ──────────────────────────────
                  _buildWarrantyBanner()
                      .animate()
                      .fadeIn(delay: 60.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),

                  // ── Original booking card ───────────────────────────────
                  _buildOriginalBookingCard()
                      .animate()
                      .fadeIn(delay: 110.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),

                  // ── Issue description card ──────────────────────────────
                  _buildDescriptionCard()
                      .animate()
                      .fadeIn(delay: 160.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),

                  // ── Preferred date card ─────────────────────────────────
                  _buildDateCard()
                      .animate()
                      .fadeIn(delay: 210.ms)
                      .slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),

                  // ── What happens next ───────────────────────────────────
                  _buildInfoBox().animate().fadeIn(delay: 250.ms),

                  // Space for the pinned submit button
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ]),
        bottomNavigationBar: _buildSubmitButton(),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  // Same dark green gradient as BookingStatusScreen and CustomerBookingsScreen
  // so navigating into this screen feels continuous, not jarring.

  Widget _buildHeader() => Container(
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request a Backjob',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    Text('AYO Guarantee claim',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              // Teal badge — signals warranty context without overusing the colour
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _teal.withOpacity(0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_user_rounded, color: _teal, size: 13),
                  const SizedBox(width: 5),
                  Text('Under Warranty',
                      style: TextStyle(
                          color: _teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ),
      );

  // ── WARRANTY BANNER ───────────────────────────────────────────────────────
  // The only teal-tinted card — its colour immediately signals warranty
  // status without competing with the white booking/form cards below.

  Widget _buildWarrantyBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _tealBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _teal.withOpacity(0.3), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child:
                Icon(Icons.verified_user_rounded, color: _tealDark, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Warranty Active',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _tealDark)),
                const SizedBox(height: 2),
                Text(
                  '${_warrantyLabel()}  •  Expires ${_warrantyExpiry()}',
                  style: TextStyle(
                      fontSize: 12,
                      color: _tealDark.withOpacity(0.75),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ]),
      );

  // ── ORIGINAL BOOKING CARD ─────────────────────────────────────────────────

  Widget _buildOriginalBookingCard() {
    final proName = _b.professional?.name ?? 'Your Handyman';
    final serviceTitle = _b.serviceTitle ?? _b.serviceType;
    final scheduledStr =
        DateFormat('MMMM d, yyyy').format(_b.scheduledDate.toLocal());

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
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(children: [
            const Icon(Icons.history_rounded,
                size: 13, color: AppColors.textLight),
            const SizedBox(width: 6),
            const Text('ORIGINAL BOOKING',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 12),

          // Service title
          Text(serviceTitle,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.2)),
          const SizedBox(height: 10),

          // Type + status chips
          Row(children: [
            _chip(_b.serviceType, AppColors.primary,
                AppColors.primary.withOpacity(0.09)),
            const SizedBox(width: 8),
            _chip('Completed', const Color(0xFF1A7A35),
                const Color(0xFF34C759).withOpacity(0.10)),
          ]),
          const SizedBox(height: 14),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),

          // Detail rows — each wrapped in Row so Flexible is always valid
          _detailRow(Icons.person_rounded, proName),
          const SizedBox(height: 8),
          _detailRow(Icons.calendar_today_rounded, scheduledStr),
          if (_b.address != null && _b.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _detailRow(Icons.location_on_rounded, _b.address!),
          ],
        ],
      ),
    );
  }

  // ── DESCRIPTION CARD ──────────────────────────────────────────────────────

  Widget _buildDescriptionCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Text('Describe the Issue',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              SizedBox(width: 4),
              Text('*',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF3B30))),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Explain what problem has reoccurred since the original service.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: 'e.g. The drain is clogged again after 2 weeks...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textLight),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );

  // ── DATE CARD ─────────────────────────────────────────────────────────────

  Widget _buildDateCard() => GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primary, size: 22),
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
                size: 18, color: AppColors.textLight),
          ]),
        ),
      );

  // ── INFO BOX ──────────────────────────────────────────────────────────────

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
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
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
                  SizedBox(height: 5),
                  Text(
                    'Your request will be sent directly to your original handyman. '
                    'They will confirm the schedule within 24 hours. '
                    'This is covered by your AYO Guarantee at no extra charge.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── SUBMIT BUTTON ─────────────────────────────────────────────────────────

  Widget _buildSubmitButton() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
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
                        Text('Submit Backjob',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
          ),
        ),
      );

  // ── SHARED HELPERS ────────────────────────────────────────────────────────

  /// Pill chip for service type / status labels.
  Widget _chip(String label, Color textColor, Color bgColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
      );

  /// Detail row — always wrapped in a Row so Flexible is always valid.
  /// Never call this as a bare Column child.
  Widget _detailRow(IconData icon, String text) => Row(children: [
        Icon(icon, size: 13, color: AppColors.textLight),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]);
}
