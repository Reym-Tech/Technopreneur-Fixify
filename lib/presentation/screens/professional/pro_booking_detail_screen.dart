// lib/presentation/screens/professional/pro_booking_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

class ProBookingDetailScreen extends StatefulWidget {
  final BookingEntity booking;
  final Future<void> Function(double price)? onSetPrice;
  final Future<void> Function(BookingStatus)? onUpdateStatus;
  final VoidCallback? onBack;

  const ProBookingDetailScreen({
    super.key,
    required this.booking,
    this.onSetPrice,
    this.onUpdateStatus,
    this.onBack,
  });

  @override
  State<ProBookingDetailScreen> createState() => _ProBookingDetailScreenState();
}

class _ProBookingDetailScreenState extends State<ProBookingDetailScreen> {
  // ── Google Maps deep link ─────────────────────────────────────────────────
  //
  // Uses the professional's saved lat/lng as origin (if set) so Maps opens
  // with turn-by-turn directions straight to the customer's location.
  // Falls back gracefully: coords → address search → nothing.

  Future<void> _openInGoogleMaps() async {
    final custLat = widget.booking.latitude;
    final custLng = widget.booking.longitude;
    final address = widget.booking.address ?? '';
    final proLat = widget.booking.professional?.latitude;
    final proLng = widget.booking.professional?.longitude;

    Uri uri;

    if (custLat != null && custLng != null) {
      // Best case: exact coordinates
      if (proLat != null && proLng != null) {
        // Directions: pro location → customer location
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&origin=$proLat,$proLng'
          '&destination=$custLat,$custLng'
          '&travelmode=driving',
        );
      } else {
        // Just show the destination pin
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=$custLat,$custLng',
        );
      }
    } else if (address.isNotEmpty) {
      // Fallback: address string (old bookings without lat/lng)
      final encoded = Uri.encodeComponent(address);
      if (proLat != null && proLng != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&origin=$proLat,$proLng'
          '&destination=$encoded'
          '&travelmode=driving',
        );
      } else {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encoded',
        );
      }
    } else {
      _snack('No location available for this booking.');
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open Google Maps.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Price setter ──────────────────────────────────────────────────────────

  final _priceCtrl = TextEditingController();
  bool _settingPrice = false;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final existing =
        widget.booking.assessmentPrice ?? widget.booking.priceEstimate;
    if (existing != null) _priceCtrl.text = existing.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSetPrice() async {
    final raw = _priceCtrl.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      setState(() => _priceError = 'Enter a valid price greater than 0');
      return;
    }
    setState(() {
      _settingPrice = true;
      _priceError = null;
    });
    try {
      await widget.onSetPrice?.call(parsed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Assessment price saved!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted)
        setState(() => _priceError = 'Failed to save price. Try again.');
    } finally {
      if (mounted) setState(() => _settingPrice = false);
    }
  }

  // ── Status actions ────────────────────────────────────────────────────────

  bool _updatingStatus = false;

  Future<void> _handleStatusUpdate(
      BookingStatus newStatus, String label) async {
    final confirmed = await _showConfirmDialog(label);
    if (!confirmed) return;
    setState(() => _updatingStatus = true);
    try {
      await widget.onUpdateStatus?.call(newStatus);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<bool> _showConfirmDialog(String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Confirm: $action',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            content: Text('Are you sure you want to $action this booking?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.booking.status;
    final isEditable =
        s == BookingStatus.accepted || s == BookingStatus.inProgress;

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
        title: const Text('Booking Detail',
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
              color: _statusColor(s).withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_statusLabel(s),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(s))),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              // Location card — always shown at top
              _buildLocationCard(),
              const SizedBox(height: 16),

              // Customer card
              _buildCustomerCard(),
              const SizedBox(height: 16),

              // Service details
              _buildServiceCard(),
              const SizedBox(height: 16),

              // Price setter (accepted / in-progress only)
              if (isEditable) ...[
                _buildPriceSetter(),
                const SizedBox(height: 16),
              ],

              // Price read-only (completed / cancelled)
              if (!isEditable && widget.booking.assessmentPrice != null) ...[
                _buildPriceReadOnly(),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 12),
            ]),
          ),
        ),
        _buildActionBar(),
      ]),
    );
  }

  // ── Location card ─────────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    final hasCoords =
        widget.booking.latitude != null && widget.booking.longitude != null;
    final hasAddress =
        widget.booking.address != null && widget.booking.address!.isNotEmpty;
    final hasAnyLocation = hasCoords || hasAddress;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(children: [
            Icon(Icons.location_on_rounded, size: 15, color: AppColors.primary),
            SizedBox(width: 6),
            Text('Service Location',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 14),

          if (hasAnyLocation) ...[
            // Address text
            if (hasAddress)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8F5),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.12)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_rounded,
                          size: 16, color: AppColors.primary.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.booking.address!,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                              height: 1.4),
                        ),
                      ),
                    ]),
              ),

            // Coordinates chip (shows if available)
            if (hasCoords) ...[
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF34C759).withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.my_location_rounded,
                        size: 12, color: Color(0xFF34C759)),
                    const SizedBox(width: 5),
                    const Text('Exact GPS location available',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF34C759))),
                  ]),
                ),
              ]),
            ],

            const SizedBox(height: 14),

            // Get Directions button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Get Directions in Google Maps'),
                onPressed: _openInGoogleMaps,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            // No location at all
            Row(children: [
              const Icon(Icons.location_off_rounded,
                  size: 18, color: AppColors.textLight),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No location provided. Ask the customer for their address.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textLight, height: 1.4),
                ),
              ),
            ]),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── Customer card ─────────────────────────────────────────────────────────

  Widget _buildCustomerCard() {
    final customer = widget.booking.customer;
    final name = customer?.name ?? 'Customer';
    final phone = customer?.phone;
    final avatarUrl = customer?.avatarUrl;

    return Container(
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
        const Row(children: [
          Icon(Icons.person_rounded, size: 15, color: AppColors.primary),
          SizedBox(width: 6),
          Text('Customer',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _CustomerAvatar(name: name, avatarUrl: avatarUrl, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.phone_rounded,
                      size: 13, color: AppColors.textLight),
                  const SizedBox(width: 5),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMedium)),
                ]),
              ],
            ]),
          ),
          if (phone != null && phone.isNotEmpty)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded,
                  size: 18, color: AppColors.primary),
            ),
        ]),
      ]),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  // ── Service details ───────────────────────────────────────────────────────

  Widget _buildServiceCard() {
    return Container(
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
        const Row(children: [
          Icon(Icons.receipt_long_rounded, size: 15, color: AppColors.primary),
          SizedBox(width: 6),
          Text('Service Details',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        _detailRow(
            Icons.build_circle_rounded, 'Service', widget.booking.serviceType),
        _detailRow(Icons.calendar_today_rounded, 'Scheduled',
            _formatDate(widget.booking.scheduledDate)),
        if (widget.booking.address != null &&
            widget.booking.address!.isNotEmpty)
          _detailRow(
              Icons.location_on_rounded, 'Address', widget.booking.address!),
        if (widget.booking.notes != null && widget.booking.notes!.isNotEmpty)
          _detailRow(Icons.notes_rounded, 'Notes', widget.booking.notes!),
      ]),
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
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

  // ── Price setter ──────────────────────────────────────────────────────────

  Widget _buildPriceSetter() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.primary.withOpacity(0.11),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.price_check_rounded, size: 16, color: AppColors.primary),
          SizedBox(width: 6),
          Text('Set Assessment Price',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Set your price for this job. The customer will see it on their Assessment screen and can confirm or decline.',
          style:
              TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Center(
              child: Text('₱',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle:
                    const TextStyle(color: AppColors.textLight, fontSize: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: const OutlineInputBorder(
                  borderRadius:
                      BorderRadius.horizontal(right: Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(14)),
                  borderSide: BorderSide(
                      color: _priceError != null
                          ? const Color(0xFFFF3B30)
                          : AppColors.primary.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(14)),
                  borderSide: BorderSide(
                      color: _priceError != null
                          ? const Color(0xFFFF3B30)
                          : AppColors.primary,
                      width: 1.5),
                ),
                errorText: _priceError,
              ),
              onChanged: (_) {
                if (_priceError != null) setState(() => _priceError = null);
              },
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _settingPrice
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_settingPrice ? 'Saving…' : 'Set Price for Customer'),
            onPressed: _settingPrice ? null : _handleSetPrice,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  // ── Price read-only ───────────────────────────────────────────────────────

  Widget _buildPriceReadOnly() {
    final price = widget.booking.assessmentPrice;
    return Container(
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
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.monetization_on_rounded,
              color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Agreed Price',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            price != null ? '₱${price.toStringAsFixed(2)}' : 'Not set',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
        ]),
      ]),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    final s = widget.booking.status;
    return Container(
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
      child: _buildActionContent(s),
    );
  }

  Widget _buildActionContent(BookingStatus s) {
    if (s == BookingStatus.completed) {
      return _statusBadge(
          const Color(0xFF34C759), Icons.check_circle_rounded, 'Job Completed');
    }
    if (s == BookingStatus.cancelled) {
      return _statusBadge(
          const Color(0xFFFF3B30), Icons.cancel_rounded, 'Booking Cancelled');
    }
    if (s == BookingStatus.inProgress) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: _updatingStatus
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text('Mark as Complete'),
          onPressed: _updatingStatus
              ? null
              : () =>
                  _handleStatusUpdate(BookingStatus.completed, 'Mark Complete'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF34C759),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            elevation: 0,
          ),
        ),
      );
    }
    // Accepted → Start Job
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: _updatingStatus
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: const Text('Start Job'),
        onPressed: _updatingStatus
            ? null
            : () => _handleStatusUpdate(BookingStatus.inProgress, 'Start Job'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5856D6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _statusBadge(Color color, IconData icon, String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _statusColor(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return const Color(0xFF007AFF);
      case BookingStatus.inProgress:
        return const Color(0xFF5856D6);
      case BookingStatus.completed:
        return const Color(0xFF34C759);
      case BookingStatus.cancelled:
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFFFF9500);
    }
  }

  String _statusLabel(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
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
    return '${months[d.month]} ${d.day}, ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _CustomerAvatar(
      {required this.name, required this.avatarUrl, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
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
          color: const Color(0xFF007AFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        child: Center(
          child: Text(letter,
              style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF))),
        ),
      );
}
