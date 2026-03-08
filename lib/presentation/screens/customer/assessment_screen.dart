// lib/presentation/screens/customer/assessment_screen.dart
//
// AssessmentScreen — shown after a handyman accepts a booking.
//
// Changes:
//  • Confirm & Start is DISABLED (greyed out) when assessmentPrice is null —
//    shows a "Waiting for price" banner so the customer knows to wait.
//  • Map placeholder cleaned up — no more dev-note text.
//  • Map shows customer pin only (red) if pro lat/lng not set — no "both pins
//    required" restriction. Falls back gracefully.
//  • Price card shows "Awaiting handyman's price…" with a pulsing indicator
//    when assessmentPrice is null, instead of "To be discussed".

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapCtrl;
  bool _confirming = false;
  bool _declining = false;
  bool _mapReady = false;

  // ── Coordinates ──────────────────────────────────────────────────────────

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
        markerId: const MarkerId('handyman'),
        position: _proLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: widget.booking.professional?.name ?? 'Handyman',
          snippet: 'Handyman location',
        ),
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
      final sw = LatLng(
        _customerLatLng!.latitude < _proLatLng!.latitude
            ? _customerLatLng!.latitude
            : _proLatLng!.latitude,
        _customerLatLng!.longitude < _proLatLng!.longitude
            ? _customerLatLng!.longitude
            : _proLatLng!.longitude,
      );
      final ne = LatLng(
        _customerLatLng!.latitude > _proLatLng!.latitude
            ? _customerLatLng!.latitude
            : _proLatLng!.latitude,
        _customerLatLng!.longitude > _proLatLng!.longitude
            ? _customerLatLng!.longitude
            : _proLatLng!.longitude,
      );
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 80));
    } else {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(_initialCamera, 15));
    }
  }

  // ── Price ────────────────────────────────────────────────────────────────

  /// True only when the handyman has explicitly set a price.
  bool get _priceSet => widget.booking.assessmentPrice != null;

  double? get _price =>
      widget.booking.assessmentPrice ?? widget.booking.priceEstimate;
  String get _priceDisplay =>
      _price == null ? 'Awaiting price…' : '₱${_price!.toStringAsFixed(2)}';

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _handleConfirm() async {
    // Guard: block if no assessment price set yet
    if (!_priceSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.info_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Please wait for the handyman to set a price before confirming.')),
          ]),
          backgroundColor: const Color(0xFFFF9500),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
    final pro = widget.booking.professional;
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
        title: const Text('Assessment',
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
            child: Column(children: [
              _buildMapSection(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(children: [
                  // Waiting-for-price banner — shown prominently when price not set
                  if (!_priceSet) ...[
                    _buildWaitingBanner(),
                    const SizedBox(height: 16),
                  ],
                  if (pro != null) ...[
                    _buildHandymanCard(pro),
                    const SizedBox(height: 16)
                  ],
                  _buildServiceDetailsCard(),
                  const SizedBox(height: 16),
                  _buildPriceCard(),
                  const SizedBox(height: 20),
                ]),
              ),
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
              'The handyman hasn\'t set a price yet. Once they do, you\'ll be able to confirm or decline the service.',
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

  // ── Map ───────────────────────────────────────────────────────────────────

  Widget _buildMapSection() {
    if (!_hasAnyPin) {
      return Container(
        height: 200,
        color: const Color(0xFFF0F4F2),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined,
                size: 44, color: AppColors.textLight),
            const SizedBox(height: 10),
            const Text('Service location not yet available',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight)),
            const SizedBox(height: 4),
            if (widget.booking.address != null &&
                widget.booking.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  widget.booking.address!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textLight),
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
            Future.delayed(const Duration(milliseconds: 600), _fitBounds);
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

      // Info banner when only one pin is available
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
                      ? 'Service location not pinned — see address below.'
                      : 'Handyman location not yet set on their profile.',
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
              if (_customerLatLng != null)
                _legendDot(const Color(0xFFE53935), 'Service Location'),
              if (_customerLatLng != null && _proLatLng != null)
                const SizedBox(height: 4),
              if (_proLatLng != null)
                _legendDot(const Color(0xFF43A047), 'Handyman Location'),
            ],
          ),
        ),
      ),

      // Fit-bounds button
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

  // ── Handyman card ─────────────────────────────────────────────────────────

  Widget _buildHandymanCard(ProfessionalEntity pro) {
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
          Icon(Icons.person_pin_rounded, size: 15, color: AppColors.primary),
          SizedBox(width: 6),
          Text('Your Handyman',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _ProAvatar(name: pro.name, avatarUrl: pro.avatarUrl, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
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
                    '${pro.rating.toStringAsFixed(1)} (${pro.reviewCount} reviews)',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          if (pro.yearsExperience > 0)
            _pill(Icons.work_history_rounded,
                '${pro.yearsExperience} yr${pro.yearsExperience == 1 ? '' : 's'} exp'),
          if (pro.city != null && pro.city!.isNotEmpty)
            _pill(Icons.location_on_rounded, pro.city!),
          if (pro.skills.isNotEmpty)
            _pill(
                Icons.build_rounded, pro.skills.map((s) => _cap(s)).join(', ')),
        ]),
        if (pro.bio != null && pro.bio!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(pro.bio!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textLight, height: 1.5)),
        ],
      ]),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _pill(IconData icon, String label) => Container(
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

  // ── Service details ───────────────────────────────────────────────────────

  Widget _buildServiceDetailsCard() {
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
        if (widget.booking.address != null &&
            widget.booking.address!.isNotEmpty)
          _detailRow(
              Icons.location_on_rounded, 'Location', widget.booking.address!),
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
                borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              ])),
        ]),
      );

  // ── Price card ────────────────────────────────────────────────────────────

  Widget _buildPriceCard() {
    final hasPriceSet = _priceSet;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasPriceSet
              ? [
                  AppColors.primary.withOpacity(0.06),
                  AppColors.primary.withOpacity(0.12)
                ]
              : [const Color(0xFFF5F5F5), const Color(0xFFEEEEEE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPriceSet
              ? AppColors.primary.withOpacity(0.2)
              : const Color(0xFFDDDDDD),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Icon(
            hasPriceSet
                ? Icons.price_check_rounded
                : Icons.hourglass_empty_rounded,
            size: 16,
            color: hasPriceSet ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Text(
            'Price Assessment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: hasPriceSet ? AppColors.primary : AppColors.textLight,
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
                color: hasPriceSet
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
                color: hasPriceSet ? AppColors.textLight : AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (hasPriceSet) ...[
              Text(
                _priceDisplay,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text('Inclusive of labor',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ] else ...[
              // Pulsing "awaiting" indicator
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
                  'Awaiting handyman\'s price…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight.withOpacity(0.7),
                    letterSpacing: -0.2,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                'The handyman will set a price after assessing your request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ]),
        ),
        if (hasPriceSet) ...[
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
              // Visually disabled + tooltip-like when no price set
              icon: (_confirming)
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
              // Disabled until handyman sets price
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

  String _cap(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}' : s;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable avatar widget — shows photo with graceful initial-letter fallback
// ─────────────────────────────────────────────────────────────────────────────

class _ProAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _ProAvatar(
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
