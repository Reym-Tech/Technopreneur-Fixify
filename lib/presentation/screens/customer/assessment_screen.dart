// lib/presentation/screens/customer/assessment_screen.dart
//
// AssessmentScreen — focused price-review screen during the assessment phase.
//
// Shown when the customer taps AssessmentCTA on BookingStatusScreen.
// Sole purpose: display the handyman's quoted price and let the customer
// confirm (→ inProgress) or decline (→ cancelled).
//
// Redundant content removed (Option A refactor):
//   • Location card       — now shown in BookingStatusScreen Booking Details
//   • Handyman card       — now shown in BookingStatusScreen _HandymanInfoCard
//   • Service details card — now shown in BookingStatusScreen Booking Details
//
// Remaining content:
//   • Waiting banner  — pulsing indicator while handyman hasn't set price yet
//   • Price card      — displays the quoted amount (or awaiting state)
//   • Action bar      — Decline | Confirm & Start

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class AssessmentScreen extends StatefulWidget {
  final BookingEntity booking;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onDecline;
  final VoidCallback? onBack;

  const AssessmentScreen({
    super.key,
    required this.booking,
    this.onConfirm,
    this.onDecline,
    this.onBack,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  bool _confirming = false;
  bool _declining = false;

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _priceSet => widget.booking.assessmentPrice != null;
  double? get _price =>
      widget.booking.assessmentPrice ?? widget.booking.priceEstimate;
  String get _priceDisplay =>
      _price == null ? 'Awaiting price…' : '₱${_price!.toStringAsFixed(2)}';

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleConfirm() async {
    if (!_priceSet) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.info_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Please wait for the handyman to set a price before confirming.')),
        ]),
        backgroundColor: const Color(0xFFFF9500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    if (!await _confirmDialog()) return;
    setState(() => _confirming = true);
    try {
      await widget.onConfirm?.call();
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _handleDecline() async {
    if (!await _declineDialog()) return;
    setState(() => _declining = true);
    try {
      await widget.onDecline?.call();
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

  Future<bool> _confirmDialog() async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Price',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'By confirming, you agree to the price set by the handyman. The service will begin immediately.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14)),
              child: Text(_priceDisplay,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Review Again')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Yes, Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _declineDialog() async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Decline & Cancel Booking',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: const Text(
              'Declining the price will cancel this booking entirely. You can make a new request anytime.\n\nAre you sure?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30)),
              child: const Text('Yes, Cancel'),
            ),
          ],
        ),
      ) ??
      false;

  // ── Build ─────────────────────────────────────────────────────────────────

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
          onPressed: widget.onBack,
        ),
        title: const Text('Price Assessment',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.thumb_up_rounded, size: 12, color: Color(0xFF34C759)),
              SizedBox(width: 4),
              Text('Accepted',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34C759))),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              // Waiting banner — pulsing while price not yet set
              if (!_priceSet) ...[
                _buildWaitingBanner(),
                const SizedBox(height: 16),
              ],

              // Price card — the sole focus of this screen
              _buildPriceCard(),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        _buildActionBar(),
      ]),
    );
  }

  // ── Waiting banner ────────────────────────────────────────────────────────

  Widget _buildWaitingBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFF9500).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.hourglass_top_rounded,
              color: Color(0xFFFF9500), size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Waiting for Price',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFCC7700)),
            ),
            SizedBox(height: 4),
            Text(
              "The handyman hasn't set a price yet. Once they do, you'll be able to confirm or decline the service.",
              style: TextStyle(
                  fontSize: 12, color: Color(0xFFAA6600), height: 1.4),
            ),
          ]),
        ),
      ]),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 600.ms)
        .then()
        .custom(
          duration: 1800.ms,
          builder: (_, value, child) =>
              Opacity(opacity: 0.7 + (0.3 * value), child: child),
        );
  }

  // ── Price card ────────────────────────────────────────────────────────────

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _priceSet
              ? [
                  AppColors.primary.withOpacity(0.06),
                  AppColors.primary.withOpacity(0.12)
                ]
              : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _priceSet
              ? AppColors.primary.withOpacity(0.2)
              : const Color(0xFFDDDDDD),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Icon(
            _priceSet
                ? Icons.price_check_rounded
                : Icons.hourglass_empty_rounded,
            size: 16,
            color: _priceSet ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            'Price Assessment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _priceSet ? AppColors.primary : AppColors.textLight,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _priceSet
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: [
            Text(
              "Handyman's Price",
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (_priceSet) ...[
              Text(
                _priceDisplay,
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text('Inclusive of labor',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ] else ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        AppColors.textLight.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Awaiting handyman's price…",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight.withOpacity(0.7),
                      letterSpacing: -0.2),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'The handyman will set a price after assessing your request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight.withOpacity(0.6),
                    height: 1.4),
              ),
            ],
          ]),
        ),
        if (_priceSet) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFF9500).withOpacity(0.25)),
            ),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: Color(0xFFFF9500)),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Review the price carefully. Confirming starts the service immediately. Declining cancels this booking.',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFFAA6600), height: 1.4),
                  )),
                ]),
          ),
        ],
      ]),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _buildActionBar() => Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: _declining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF3B30)))
                  : const Icon(Icons.close_rounded, size: 18),
              label: const Text('Decline'),
              onPressed: (_confirming || _declining) ? null : _handleDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                side: const BorderSide(color: Color(0xFFFF3B30)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              icon: _confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _priceSet
                          ? Icons.check_circle_rounded
                          : Icons.lock_rounded,
                      size: 18,
                    ),
              label: Text(_priceSet ? 'Confirm & Start' : 'Awaiting Price'),
              onPressed: (_confirming || _declining || !_priceSet)
                  ? null
                  : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _priceSet ? AppColors.primary : const Color(0xFFCCCCCC),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFDDDDDD),
                disabledForegroundColor: const Color(0xFF999999),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                elevation: 0,
              ),
            ),
          ),
        ]),
      );
}
