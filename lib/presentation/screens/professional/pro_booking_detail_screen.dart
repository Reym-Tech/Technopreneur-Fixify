// lib/presentation/screens/professional/pro_booking_detail_screen.dart
//
// ProBookingDetailScreen — shown when a professional taps an accepted/ongoing booking.
//
// Features:
//  • Customer info card (name, address, service type, notes)
//  • Google Map showing handyman's location → customer's service location
//  • Assessment Price setter: text field + "Set Price" button → calls onSetPrice
//  • Status action bar:
//    - Accepted    → "Start Job" (→ inProgress)
//    - In Progress → "Mark Complete" (→ completed)
//    - Completed   → review badge (read-only)
//    - Cancelled   → cancelled badge (read-only)
//
// Props:
//   booking        → BookingEntity (required)
//   onSetPrice     → Future<void> Function(double price)?  — saves assessment_price to Supabase
//   onUpdateStatus → Future<void> Function(BookingStatus)? — updates booking status
//   onBack         → VoidCallback?

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  // ── Map ───────────────────────────────────────────────────────────────────

  GoogleMapController? _mapCtrl;
  bool _mapReady = false;

  LatLng? get _customerLatLng {
    final lat = widget.booking.latitude;
    final lng = widget.booking.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _proLatLng {
    final lat = widget.booking.professional?.latitude;
    final lng = widget.booking.professional?.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  bool get _hasAnyPin => _customerLatLng != null || _proLatLng != null;
  bool get _hasBothPins => _customerLatLng != null && _proLatLng != null;

  LatLng get _initialCamera {
    if (_hasBothPins) {
      return LatLng(
        (_customerLatLng!.latitude + _proLatLng!.latitude) / 2,
        (_customerLatLng!.longitude + _proLatLng!.longitude) / 2,
      );
    }
    return _customerLatLng ?? _proLatLng ?? const LatLng(7.0707, 125.6087);
  }

  Set<Marker> get _markers {
    final m = <Marker>{};
    if (_customerLatLng != null) {
      m.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Service Location',
          snippet: widget.booking.address ?? '',
        ),
      ));
    }
    if (_proLatLng != null) {
      m.add(Marker(
        markerId: const MarkerId('pro'),
        position: _proLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }
    return m;
  }

  Set<Polyline> get _polylines {
    if (!_hasBothPins) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_proLatLng!, _customerLatLng!],
        color: AppColors.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  void _fitBounds() {
    if (_mapCtrl == null) return;
    if (_hasBothPins) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            _customerLatLng!.latitude < _proLatLng!.latitude
                ? _customerLatLng!.latitude
                : _proLatLng!.latitude,
            _customerLatLng!.longitude < _proLatLng!.longitude
                ? _customerLatLng!.longitude
                : _proLatLng!.longitude,
          ),
          northeast: LatLng(
            _customerLatLng!.latitude > _proLatLng!.latitude
                ? _customerLatLng!.latitude
                : _proLatLng!.latitude,
            _customerLatLng!.longitude > _proLatLng!.longitude
                ? _customerLatLng!.longitude
                : _proLatLng!.longitude,
          ),
        ),
        80,
      ));
    } else {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(_initialCamera, 14));
    }
  }

  // ── Price setter ──────────────────────────────────────────────────────────

  final _priceCtrl = TextEditingController();
  bool _settingPrice = false;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing assessment price if already set
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assessment price saved!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
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
            child: Column(children: [
              // Map
              _buildMapSection(),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(children: [
                  // Customer card
                  _buildCustomerCard(),
                  const SizedBox(height: 16),

                  // Service details
                  _buildServiceCard(),
                  const SizedBox(height: 16),

                  // Price setter — only for accepted/in-progress
                  if (isEditable) ...[
                    _buildPriceSetter(),
                    const SizedBox(height: 16),
                  ],

                  // Read-only price display for completed/cancelled
                  if (!isEditable &&
                      widget.booking.assessmentPrice != null) ...[
                    _buildPriceReadOnly(),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 12),
                ]),
              ),
            ]),
          ),
        ),
        _buildActionBar(),
      ]),
    );
  }

  // ── Map section ───────────────────────────────────────────────────────────

  Widget _buildMapSection() {
    if (!_hasAnyPin) {
      return Container(
        height: 200,
        color: const Color(0xFFF0F4F2),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined,
                size: 44, color: AppColors.textLight),
            const SizedBox(height: 8),
            const Text('Service location not pinned yet',
                style: TextStyle(fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                widget.booking.address ?? 'No address provided',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      );
    }

    return Stack(children: [
      SizedBox(
        height: 240,
        child: GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _initialCamera, zoom: 13),
          onMapCreated: (c) {
            _mapCtrl = c;
            setState(() => _mapReady = true);
            Future.delayed(const Duration(milliseconds: 500), _fitBounds);
          },
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
        ),
      ),

      // Banner when partial data
      if (!_hasBothPins)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: const Color(0xFFFF9500).withOpacity(0.88),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _customerLatLng == null
                      ? 'Customer location not pinned yet.'
                      : 'Your location not set on profile.',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),

      // Legend
      Positioned(
        bottom: 12,
        left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.93),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_proLatLng != null)
                _legendDot(const Color(0xFF1565C0), 'Your Location'),
              if (_proLatLng != null && _customerLatLng != null)
                const SizedBox(height: 4),
              if (_customerLatLng != null)
                _legendDot(const Color(0xFFE53935), 'Service Location'),
            ],
          ),
        ),
      ),

      // Fit bounds button
      if (_mapReady)
        Positioned(
          top: _hasBothPins ? 12 : 44,
          right: 12,
          child: GestureDetector(
            onTap: _fitBounds,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.fit_screen_rounded,
                  size: 20, color: AppColors.primary),
            ),
          ),
        ),
    ]);
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
        ],
      );

  // ── Customer card ─────────────────────────────────────────────────────────

  Widget _buildCustomerCard() {
    final customer = widget.booking.customer;
    final name = customer?.name ?? 'Customer';
    final phone = customer?.phone;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
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
          // Avatar
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

          // Call / message button placeholder
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

  // ── Service details card ──────────────────────────────────────────────────

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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
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
  }

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
            AppColors.primary.withOpacity(0.11)
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
          // Currency prefix
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

          // Text field
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

  // ── Price read-only display ───────────────────────────────────────────────

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
    // Completed
    if (s == BookingStatus.completed) {
      return _statusBadge(
          const Color(0xFF34C759), Icons.check_circle_rounded, 'Job Completed');
    }

    // Cancelled
    if (s == BookingStatus.cancelled) {
      return _statusBadge(
          const Color(0xFFFF3B30), Icons.cancel_rounded, 'Booking Cancelled');
    }

    // In Progress → Mark Complete
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

  Widget _statusBadge(Color color, IconData icon, String label) {
    return Container(
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
  }

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
    return '${months[d.month]} ${d.day}, ${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Avatar widget — shows photo if available, else coloured initial
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
