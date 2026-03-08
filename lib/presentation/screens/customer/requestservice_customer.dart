// lib/presentation/screens/customer/requestservice_customer.dart
//
// RequestServiceScreen — 4-step service request wizard.
//
// Changes vs previous version:
//   • Added [initialProblemTitle] prop — when provided (e.g. "Pipe Leak Repair"),
//     it pre-fills the Problem Title field in Step 2 so users don't have to
//     retype the service name they already selected from the catalogue.
//
// Step 3 — Location (enhanced):
//   • Asks for location permission on entry (Once / Always / Deny)
//   • Tap-to-pin on Google Maps with red marker
//   • "Use My Location" button (GPS crosshair)
//   • Reverse-geocodes pin → auto-fills address fields
//   • Address fields are editable after autofill
//   • Toggle between Map view and Form-only view (for slow devices)
//   • Additional Notes field (P.S.)
//   • "Use two fingers to move the map" hint on single-finger scroll
//   • Map type toggle: bottom-left thumbnail switches Normal ↔ Satellite

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/models/models.dart';

// ─────────────────────────────────────────────────────────────
// Result data class
// ─────────────────────────────────────────────────────────────

class RequestServiceResult {
  final String serviceType;
  final String problemTitle;
  final String description;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? photoPath;
  final ProfessionalModel matchedPro;

  const RequestServiceResult({
    required this.serviceType,
    required this.problemTitle,
    required this.description,
    required this.address,
    this.latitude,
    this.longitude,
    this.notes,
    this.photoPath,
    required this.matchedPro,
  });
}

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────

class RequestServiceScreen extends StatefulWidget {
  final List<ProfessionalModel> professionals;
  final Function(RequestServiceResult)? onSubmit;
  final VoidCallback? onBack;

  /// Pre-selects the service category and jumps straight to Step 2 (Describe).
  final String? initialServiceType;

  /// Pre-fills the Problem Title field in Step 2.
  final String? initialProblemTitle;

  const RequestServiceScreen({
    super.key,
    this.professionals = const [],
    this.onSubmit,
    this.onBack,
    this.initialServiceType,
    this.initialProblemTitle,
  });

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  int _step = 0;

  // Step 1
  String? _serviceType;

  // Step 2
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _photoPath;
  bool _pickingPhoto = false;

  // Step 3 — map
  GoogleMapController? _mapCtrl;
  LatLng? _pinned;
  bool _locating = false;
  bool _geocoding = false;
  bool _permissionDenied = false;
  bool _permCheckDone = false;

  // ── Map type & gesture control ───────────────────────────
  MapType _mapType = MapType.normal;
  // When true the parent SingleChildScrollView is locked
  bool _lockScroll = false;
  final ScrollController _scrollCtrl = ScrollController();

  // Step 3 — address fields
  final _streetCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Step 4
  bool _submitting = false;

  // ── Catalogue ──────────────────────────────────────────────
  static const _catalogue = [
    {
      'type': 'Electrical',
      'icon': Icons.electrical_services_rounded,
      'color': Color(0xFFFF9500),
      'subtitle': 'Wiring, outlets, fixtures'
    },
    {
      'type': 'Plumbing',
      'icon': Icons.water_drop_rounded,
      'color': Color(0xFF007AFF),
      'subtitle': 'Faucets, pipes, water heater'
    },
    {
      'type': 'Carpentry',
      'icon': Icons.handyman_rounded,
      'color': Color(0xFF8B5E3C),
      'subtitle': 'Furniture repair, installations'
    },
    {
      'type': 'Painting',
      'icon': Icons.format_paint_rounded,
      'color': Color(0xFF34C759),
      'subtitle': 'Interior & exterior painting'
    },
    {
      'type': 'Appliances',
      'icon': Icons.kitchen_rounded,
      'color': Color(0xFF5856D6),
      'subtitle': 'AC maintenance, repairs & service'
    },
    {
      'type': 'Cleaning',
      'icon': Icons.cleaning_services_rounded,
      'color': Color(0xFF00C7BE),
      'subtitle': 'Deep clean, regular housekeeping'
    },
  ];

  Set<String> get _availableTypes => widget.professionals
      .where((p) => p.verified && p.available)
      .expand((p) => p.skills)
      .map((s) => '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}')
      .toSet();

  ProfessionalModel? get _matchedPro {
    if (_serviceType == null) return null;
    final matches = widget.professionals.where((p) =>
        p.verified &&
        p.available &&
        p.skills.any((s) => s.toLowerCase() == _serviceType!.toLowerCase()));
    if (matches.isEmpty) return null;
    return matches.reduce((a, b) => (a.rating ?? 0) >= (b.rating ?? 0) ? a : b);
  }

  String get _fullAddress {
    final parts = [
      _streetCtrl.text.trim(),
      _barangayCtrl.text.trim(),
      _cityCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceType != null) {
      _serviceType = widget.initialServiceType;
      _step = 1;
    }
    if (widget.initialProblemTitle != null &&
        widget.initialProblemTitle!.isNotEmpty) {
      _titleCtrl.text = widget.initialProblemTitle!;
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Pointer tracking: lock page scroll while finger is on map ──

  void _onMapPointerDown(PointerDownEvent e) {
    if (!_lockScroll && mounted) setState(() => _lockScroll = true);
  }

  void _onMapPointerUp(PointerUpEvent e) {
    if (_lockScroll && mounted) setState(() => _lockScroll = false);
  }

  void _onMapPointerCancel(PointerCancelEvent e) {
    if (_lockScroll && mounted) setState(() => _lockScroll = false);
  }

  // ── NEW: map type toggle ───────────────────────────────────

  void _toggleMapType() {
    setState(() {
      _mapType =
          _mapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  // ── Navigation ─────────────────────────────────────────────

  void _next() {
    if (_step == 0 && _serviceType == null) {
      _snack('Please select a service type');
      return;
    }
    if (_step == 1 && _titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a problem title');
      return;
    }
    if (_step == 2) {
      // Location permission is required — block if denied
      if (_permissionDenied) {
        _snack('Location access is required. Please allow it to continue.');
        return;
      }
      // Must have a pinned location
      if (_pinned == null) {
        _snack('Please pin your location on the map first.');
        return;
      }
      if (_streetCtrl.text.trim().isEmpty) {
        _snack('Please enter your street or house number');
        return;
      }
      if (_cityCtrl.text.trim().isEmpty) {
        _snack('Please enter your city or municipality');
        return;
      }
    }
    if (_step == 3) {
      _submit();
      return;
    }
    setState(() => _step++);
    if (_step == 2) _initLocation();
  }

  void _back() {
    if (_step == 0)
      widget.onBack?.call();
    else
      setState(() => _step--);
  }

  // ── Location permission & GPS ──────────────────────────────

  bool _locationPermissionGranted = false;

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _permissionDenied = true;
        _locationPermissionGranted = false;
        _permCheckDone = true;
      });
      return;
    }

    final status = await Geolocator.checkPermission();

    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      setState(() {
        _locationPermissionGranted = true;
        _permissionDenied = false;
        _permCheckDone = true;
      });
      await _getDeviceLocation();
      return;
    }

    if (status == LocationPermission.deniedForever) {
      setState(() {
        _permissionDenied = true;
        _locationPermissionGranted = false;
        _permCheckDone = true;
      });
      return;
    }

    // status == denied → show the mandatory allow dialog (no "Not now" option)
    if (!mounted) return;
    await _showPermissionDialog();

    final newStatus = await Geolocator.requestPermission();
    if (newStatus == LocationPermission.always ||
        newStatus == LocationPermission.whileInUse) {
      setState(() {
        _locationPermissionGranted = true;
        _permissionDenied = false;
        _permCheckDone = true;
      });
      await _getDeviceLocation();
    } else {
      setState(() {
        _permissionDenied = true;
        _locationPermissionGranted = false;
        _permCheckDone = true;
      });
    }
  }

  Future<void> _showPermissionDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Allow Location Access',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 10),
            const Text(
              'Fixify requires your location to accurately pin the service address and match you with the nearest available professional.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location access is required to proceed.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Allow Location',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _getDeviceLocation() async {
    if (!mounted) return;
    setState(() => _locating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      final ll = LatLng(pos.latitude, pos.longitude);
      await _setPin(ll, moveCamera: true);
    } catch (_) {
      if (mounted) _snack('Could not get location — pin manually on the map.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _onMapTap(LatLng ll) => _setPin(ll, moveCamera: false);

  Future<void> _setPin(LatLng ll, {required bool moveCamera}) async {
    setState(() {
      _pinned = ll;
      _geocoding = true;
    });
    if (moveCamera) {
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 17));
    }
    try {
      final marks = await placemarkFromCoordinates(ll.latitude, ll.longitude)
          .timeout(const Duration(seconds: 8));
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;

        setState(() {
          // ── Street / House No. ────────────────────────────────
          // p.street can return a Google Plus Code (e.g. "Q7CX+2PP") when
          // there is no named street. Prefer a real street name from
          // thoroughfare, then name, then street — skip Plus Codes entirely.
          final plusCodePattern = RegExp(r'^[0-9A-Z]{4,}\+[0-9A-Z]{2,}');
          String street = '';
          for (final candidate in [
            p.thoroughfare, // named road (most reliable)
            p.name, // POI / landmark name — often has Purok/Sitio
            p.street, // fallback
          ]) {
            final v = (candidate ?? '').trim();
            if (v.isNotEmpty && !plusCodePattern.hasMatch(v)) {
              street = v;
              break;
            }
          }
          if (street.isNotEmpty) _streetCtrl.text = street;

          // ── Barangay ──────────────────────────────────────────
          // Priority: subLocality (barangay in PH) → subThoroughfare
          // (subdivision/purok) → name if it looks like a barangay.
          // Deliberately skip subAdministrativeArea — that is the province.
          String barangay = '';
          for (final candidate in [
            p.subLocality, // Barangay X in PH when available
            p.subThoroughfare, // house-level detail, sometimes has Purok
          ]) {
            final v = (candidate ?? '').trim();
            if (v.isNotEmpty) {
              barangay = v;
              break;
            }
          }
          // Last resort: if p.name looks like a barangay/purok and street
          // didn't use it already, use it here.
          if (barangay.isEmpty) {
            final nameVal = (p.name ?? '').trim();
            final looksLikeBarangay = RegExp(
              r'(barangay|brgy|purok|sitio|prk)',
              caseSensitive: false,
            ).hasMatch(nameVal);
            if (nameVal.isNotEmpty &&
                looksLikeBarangay &&
                nameVal != _streetCtrl.text) {
              barangay = nameVal;
            }
          }
          if (barangay.isNotEmpty) _barangayCtrl.text = barangay;

          // ── City / Municipality ───────────────────────────────
          // p.locality is the city/municipality (e.g. "Digos City").
          // p.administrativeArea is the region/province — NOT shown here.
          final city = (p.locality ?? '').trim();
          if (city.isNotEmpty) _cityCtrl.text = city;
        });
      }
    } catch (_) {
      // Geocoding failed silently — user can type manually
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  // ── Photo ──────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (img != null && mounted) setState(() => _photoPath = img.path);
    } catch (_) {
      _snack('Could not open gallery');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  // ── Submit ─────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    final pro = _matchedPro;
    if (pro == null) {
      _snack('No available professional found for $_serviceType right now.');
      return;
    }
    setState(() => _submitting = true);
    await widget.onSubmit?.call(RequestServiceResult(
      serviceType: _serviceType!,
      problemTitle: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      address: _fullAddress,
      latitude: _pinned?.latitude,
      longitude: _pinned?.longitude,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      photoPath: _photoPath,
      matchedPro: pro,
    ));
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildTopBar(),
        _buildStepper(),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            // Block the scroll bubbling up when fingers are on the map
            onNotification: (n) => _lockScroll,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              // Disable physics entirely while map is being touched
              physics: _lockScroll
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ][_step],
            ),
          ),
        ),
        _buildFooter(),
      ]),
    );
  }

  // ── TOP BAR ───────────────────────────────────────────────

  Widget _buildTopBar() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E)],
          ),
        ),
        child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                GestureDetector(
                  onTap: _back,
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
                const Text('Request Service',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ]),
            )),
      );

  // ── STEPPER ───────────────────────────────────────────────

  Widget _buildStepper() {
    const labels = ['Service', 'Describe', 'Location', 'Confirm'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
          children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < _step;
          return Expanded(
              child: AnimatedContainer(
            duration: 300.ms,
            height: 2,
            color: done ? AppColors.primary : const Color(0xFFE0E0E0),
          ));
        }
        final idx = i ~/ 2;
        final done = idx < _step;
        final active = idx == _step;
        return Column(children: [
          AnimatedContainer(
            duration: 300.ms,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  done || active ? AppColors.primary : const Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
            child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : Text('${idx + 1}',
                        style: TextStyle(
                            color:
                                active ? Colors.white : const Color(0xFFAAAAAA),
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
          ),
          const SizedBox(height: 4),
          Text(labels[idx],
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.primary : const Color(0xFFAAAAAA),
              )),
        ]);
      })),
    );
  }

  // ── STEP 1: SERVICE ───────────────────────────────────────

  Widget _buildStep1() {
    final available = _availableTypes;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Select Service Type',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3)),
      const SizedBox(height: 4),
      const Text('Choose the type of service you need',
          style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 20),
      ..._catalogue.asMap().entries.map((e) {
        final svc = e.value;
        final type = svc['type'] as String;
        final isAvail = available.contains(type);
        final selected = _serviceType == type;
        final color = svc['color'] as Color;
        return GestureDetector(
          onTap: isAvail ? () => setState(() => _serviceType = type) : null,
          child: AnimatedContainer(
            duration: 200.ms,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.06)
                  : isAvail
                      ? Colors.white
                      : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2),
              boxShadow: isAvail
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                  : [],
            ),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isAvail
                      ? color.withOpacity(0.12)
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(svc['icon'] as IconData,
                    color: isAvail ? color : const Color(0xFFBBBBBB), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(type,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isAvail
                                  ? AppColors.textDark
                                  : const Color(0xFFBBBBBB))),
                      if (!isAvail) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('Unavailable',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFAAAAAA),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(svc['subtitle'] as String,
                        style: TextStyle(
                            fontSize: 12,
                            color: isAvail
                                ? AppColors.textLight
                                : const Color(0xFFCCCCCC))),
                  ])),
              if (!isAvail)
                const Icon(Icons.lock_rounded,
                    color: Color(0xFFCCCCCC), size: 18)
              else if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
            ]),
          ).animate().fadeIn(delay: (e.key * 55).ms),
        );
      }),
      const SizedBox(height: 20),
    ]);
  }

  // ── STEP 2: DESCRIBE ──────────────────────────────────────

  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Describe the Issue',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3)),
          const SizedBox(height: 4),
          const Text('Please describe the issue in detail',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 24),
          _field(
              ctrl: _titleCtrl,
              hint: 'Problem Title',
              icon: Icons.title_rounded),
          const SizedBox(height: 14),
          _field(
              ctrl: _descCtrl,
              hint: 'Problem Description',
              icon: Icons.description_outlined,
              maxLines: 5),
          const SizedBox(height: 24),
          const Text('Upload Photo',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickPhoto,
            child: _pickingPhoto
                ? Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F2),
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: const Color(0xFFDDDDDD), width: 1),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          strokeWidth: 2),
                    ),
                  )
                : _photoPath != null
                    // ── Photo uploaded: show full image, natural height ──
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: AppColors.primary, width: 2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_photoPath!),
                                  width: double.infinity,
                                  // No fixed height — image shows at its
                                  // natural aspect ratio
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                            ),
                          ),
                          // Remove button
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => setState(() => _photoPath = null),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          // Tap-to-replace hint at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16)),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                color: Colors.black.withOpacity(0.35),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 13),
                                    SizedBox(width: 5),
                                    Text('Tap to change photo',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    // ── Placeholder: full-width, fixed height ──
                    : Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFFDDDDDD), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add_photo_alternate_rounded,
                                  color: AppColors.primary.withOpacity(0.6),
                                  size: 28),
                            ),
                            const SizedBox(height: 12),
                            const Text('Tap to upload a photo',
                                style: TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Optional · JPG, PNG',
                                style: TextStyle(
                                    color: AppColors.textLight, fontSize: 11)),
                          ],
                        ),
                      ),
          ),
          const SizedBox(height: 20),
        ],
      ).animate().fadeIn(duration: 200.ms);

  // ── STEP 3: LOCATION ──────────────────────────────────────

  Widget _buildStep3() {
    final initialPos = _pinned ?? const LatLng(7.0707, 125.6087);
    final isSatellite = _mapType == MapType.satellite;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header (no Map/Form toggle) ───────────────────────
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pin Your Location',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3)),
        SizedBox(height: 2),
        Text('Tap the map or use GPS to pin your location',
            style: TextStyle(fontSize: 12, color: AppColors.textLight)),
      ]),
      const SizedBox(height: 16),

      // ── Loading / permission check ────────────────────────
      if (!_permCheckDone)
        Container(
          height: 270,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  strokeWidth: 2),
              SizedBox(height: 12),
              Text('Checking location access…',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            ]),
          ),
        ),

      // ── Permission denied — BLOCKING card ────────────────
      if (_permCheckDone && _permissionDenied) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD6D6), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.red.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_off_rounded,
                  color: Colors.red, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Access Required',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fixify requires location access to accurately pin your service address. Manual address entry is not supported to ensure service quality.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
            const SizedBox(height: 20),
            // Open Settings button (for deniedForever)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  // Re-check after user returns from settings
                  if (mounted) {
                    setState(() {
                      _permCheckDone = false;
                      _permissionDenied = false;
                    });
                    await _initLocation();
                  }
                },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Open App Settings',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Retry button (in case it was just a soft deny)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  setState(() {
                    _permCheckDone = false;
                    _permissionDenied = false;
                  });
                  await _initLocation();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
      ],

      // ── Map widget (only when permission granted) ─────────
      if (_permCheckDone && !_permissionDenied)
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 270,
            child: Listener(
              // Track every finger landing on / leaving the map area
              onPointerDown: _onMapPointerDown,
              onPointerUp: _onMapPointerUp,
              onPointerCancel: _onMapPointerCancel,
              child: Stack(children: [
                // ── Google Map ─────────────────────────
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: initialPos, zoom: 14),
                  mapType: _mapType,
                  onMapCreated: (c) {
                    _mapCtrl = c;
                    if (_pinned != null) {
                      c.animateCamera(CameraUpdate.newLatLngZoom(_pinned!, 17));
                    }
                  },
                  onTap: _onMapTap,
                  markers: _pinned != null
                      ? {
                          Marker(
                            markerId: const MarkerId('pin'),
                            position: _pinned!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed),
                            infoWindow: InfoWindow(
                              title: 'Service Location',
                              snippet:
                                  _fullAddress.isNotEmpty ? _fullAddress : null,
                            ),
                          ),
                        }
                      : {},
                  myLocationEnabled: _locationPermissionGranted,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),

                // ── GPS button (top-right) ──────────────
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: _permissionDenied ? null : _getDeviceLocation,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: _locating
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      AppColors.primary)))
                          : Icon(Icons.my_location_rounded,
                              color: _permissionDenied
                                  ? const Color(0xFFCCCCCC)
                                  : AppColors.primary,
                              size: 22),
                    ),
                  ),
                ),

                // ── Zoom controls (bottom-right) ────────
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Column(children: [
                    _zoomBtn(Icons.add_rounded,
                        () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
                    const SizedBox(height: 4),
                    _zoomBtn(Icons.remove_rounded,
                        () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
                  ]),
                ),

                // ── NEW: Map type toggle thumbnail (bottom-left) ──
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: _toggleMapType,
                    child: AnimatedContainer(
                      duration: 200.ms,
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.5),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail preview of the OTHER map type
                            isSatellite
                                ? Container(
                                    color: const Color(0xFF8DB8D6),
                                    child: CustomPaint(
                                      painter: _RoadMapPainter(),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF3A5E38),
                                    child: CustomPaint(
                                      painter: _SatellitePainter(),
                                    ),
                                  ),
                            // Label at bottom
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                color: Colors.black.withOpacity(0.5),
                                child: Text(
                                  isSatellite ? 'Map' : 'Satellite',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Geocoding indicator ─────────────────
                if (_geocoding)
                  Positioned(
                    bottom: 74,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 8),
                        Text('Getting address…',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),

                // ── "Tap map to pin" hint ───────────────
                if (_pinned == null && !_locating)
                  Center(
                      child: IgnorePointer(
                          child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.touch_app_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Tap map to pin location',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ))),
              ]),
            ),
          ),
        ),
      const SizedBox(height: 14),

      // ── Pinned location card ──────────────────────────────
      AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pinned != null
              ? AppColors.primary.withOpacity(0.06)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _pinned != null
                  ? AppColors.primary.withOpacity(0.25)
                  : const Color(0xFFE0E0E0)),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (_pinned != null
                      ? AppColors.primary
                      : const Color(0xFFBBBBBB))
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.place_rounded,
                color: _pinned != null
                    ? AppColors.primary
                    : const Color(0xFFBBBBBB),
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  _pinned != null
                      ? 'Pinned Location'
                      : 'No location pinned yet',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _pinned != null
                          ? AppColors.primary
                          : const Color(0xFFAAAAAA)),
                ),
                if (_fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_fullAddress,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark)),
                ],
              ])),
          if (_pinned != null)
            GestureDetector(
              onTap: () => setState(() {
                _pinned = null;
                _streetCtrl.clear();
                _barangayCtrl.clear();
                _cityCtrl.clear();
              }),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFFBBBBBB), size: 18),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      const Text('Confirm or Edit Address',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark)),
      const SizedBox(height: 2),
      const Text('Auto-filled from map pin — edit if needed',
          style: TextStyle(fontSize: 11, color: AppColors.textLight)),
      const SizedBox(height: 12),
      _label('Street / House No. *'),
      const SizedBox(height: 6),
      _field(
          ctrl: _streetCtrl,
          hint: 'e.g. 316 Gen. Luna St.',
          icon: Icons.home_rounded,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      _label('Barangay'),
      const SizedBox(height: 6),
      _field(
          ctrl: _barangayCtrl,
          hint: 'e.g. Barangay Matti',
          icon: Icons.map_rounded,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      _label('City / Municipality *'),
      const SizedBox(height: 6),
      _field(
          ctrl: _cityCtrl,
          hint: 'e.g. Digos City, Davao del Sur',
          icon: Icons.location_city_rounded,
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 18),
      const Text('Additional Notes (Optional)',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark)),
      const SizedBox(height: 6),
      _field(
        ctrl: _notesCtrl,
        hint: 'e.g. Gate is on the left side, call before coming…',
        icon: Icons.sticky_note_2_outlined,
        maxLines: 3,
        prefix: 'P.S.',
      ),
      const SizedBox(height: 20),
    ]).animate().fadeIn(duration: 200.ms);
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4)
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.textDark),
        ),
      );

  // ── STEP 4: CONFIRM ───────────────────────────────────────

  Widget _buildStep4() {
    final notesVal = _notesCtrl.text.trim();
    final rows = <Map<String, dynamic>>[
      {
        'icon': Icons.build_rounded,
        'label': 'Service Type',
        'value': _serviceType ?? '—'
      },
      {
        'icon': Icons.article_rounded,
        'label': 'Issue Details',
        'value': _titleCtrl.text.trim().isEmpty
            ? 'No title provided'
            : _titleCtrl.text.trim()
      },
      {
        'icon': Icons.location_on_rounded,
        'label': 'Service Location',
        'value': _fullAddress.isEmpty ? 'No address entered' : _fullAddress
      },
      if (notesVal.isNotEmpty)
        {
          'icon': Icons.sticky_note_2_outlined,
          'label': 'Notes',
          'value': notesVal
        },
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Review Your Request',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3)),
      const SizedBox(height: 4),
      const Text('Please review the details before submitting',
          style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 24),
      ...rows.asMap().entries.map((e) {
        final row = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(row['icon'] as IconData,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(row['label'] as String,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                  const SizedBox(height: 3),
                  Text(row['value'] as String,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                ])),
          ]),
        ).animate().fadeIn(delay: (e.key * 60).ms);
      }),
      if (_photoPath != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uploaded Photo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_photoPath!),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_rounded,
                            size: 40,
                            color: AppColors.textLight.withOpacity(0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image failed to load',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.primary.withOpacity(0.7), size: 18),
          const SizedBox(width: 10),
          const Expanded(
              child: Text(
            'By submitting, you agree to our Terms of Service and Privacy Policy.',
            style: TextStyle(fontSize: 12, color: AppColors.textMedium),
          )),
        ]),
      ),
      const SizedBox(height: 20),
    ]).animate().fadeIn(duration: 200.ms);
  }

  // ── FOOTER ────────────────────────────────────────────────

  Widget _buildFooter() {
    final isFirst = _step == 0;
    final isLast = _step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
          top: false,
          child: Row(children: [
            if (!isFirst) ...[
              Expanded(
                  child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              )),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: ElevatedButton(
              onPressed: _submitting ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(isLast ? 'Submit' : 'Next',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            )),
          ])),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark));

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? prefix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
        prefixIcon: prefix == null
            ? Icon(icon, color: AppColors.textLight, size: 20)
            : null,
        prefix: prefix != null
            ? Text('$prefix  ',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13))
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}

// ── Custom painters for map type thumbnail ─────────────────────

/// Mimics a simple road-map style (used when currently in satellite mode)
class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFD4E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Horizontal road
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), road);
    // Vertical road
    canvas.drawLine(Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height), road);

    // Block fills
    final block = Paint()..color = const Color(0xFFB8D4BC);
    canvas.drawRect(
        Rect.fromLTWH(4, 4, size.width * 0.4, size.height * 0.4), block);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.55, size.width * 0.4,
            size.height * 0.4),
        block);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Mimics a satellite-view style (used when currently in normal map mode)
class _SatellitePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark green base
    final bg = Paint()..color = const Color(0xFF2D4A2A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Lighter patches (vegetation / urban)
    final patch1 = Paint()..color = const Color(0xFF3E6B38);
    canvas.drawOval(
        Rect.fromLTWH(2, 2, size.width * 0.5, size.height * 0.5), patch1);

    final patch2 = Paint()..color = const Color(0xFF557A50);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.4, size.height * 0.3, size.width * 0.55,
            size.height * 0.55),
        patch2);

    // Road-like line
    final road = Paint()
      ..color = const Color(0xFFBBA96A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.6),
        Offset(size.width, size.height * 0.45), road);

    // Water patch
    final water = Paint()..color = const Color(0xFF3B6E8C);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.05, size.height * 0.6, size.width * 0.3,
            size.height * 0.35),
        water);
  }

  @override
  bool shouldRepaint(_) => false;
}
