// lib/presentation/screens/customer/requestservice_customer.dart
//
// RequestServiceScreen — 4-step service request wizard.
//
// Step 3 — Location:
//   • Asks for location permission on entry (Once / Always / Deny)
//   • Tap-to-pin on Google Maps with red marker
//   • "Use My Location" button (GPS crosshair)
//   • Reverse-geocodes pin → auto-fills address fields
//   • Address fields are editable after autofill
//   • Toggle between Map view and Form-only view (for slow devices)
//   • Additional Notes field (P.S.)

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
  final String? initialServiceType; // pre-selects service + skips to step 1

  const RequestServiceScreen({
    super.key,
    this.professionals = const [],
    this.onSubmit,
    this.onBack,
    this.initialServiceType,
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
  bool _showMap = true; // toggle between map and form-only
  bool _locating = false;
  bool _geocoding = false;
  bool _permissionDenied = false;
  bool _permCheckDone = false; // true once permission flow has completed

  // Step 3 — address fields (auto-filled by geocoding, also manually editable)
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
      _step = 1; // skip service selection, jump straight to problem description
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
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
    // On entering step 3, ask for permission & try to get location
    if (_step == 2) _initLocation();
  }

  void _back() {
    if (_step == 0)
      widget.onBack?.call();
    else
      setState(() => _step--);
  }

  // ── Location permission & GPS ──────────────────────────────

  // ── Location permission & GPS ──────────────────────────────
  //
  // Flow:
  //   1. Check if location service is on
  //   2. If already granted → get location immediately, no dialogs
  //   3. If denied (not forever) → show OUR explanation dialog first
  //      → user taps "Allow" → THEN call Geolocator.requestPermission()
  //        which shows the ONE system dialog
  //   4. If deniedForever → show manual-entry banner
  //
  // myLocationEnabled on GoogleMap is set ONLY after permission is granted
  // to prevent the map SDK from triggering its own extra permission request.

  bool _locationPermissionGranted = false; // drives myLocationEnabled

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

    // status == denied — show our explanation dialog first
    if (!mounted) return;
    final choice = await _showPermissionDialog();
    if (choice == _LocationChoice.deny) {
      setState(() {
        _permissionDenied = true;
        _locationPermissionGranted = false;
        _permCheckDone = true;
      });
      return;
    }

    // User chose Allow → system dialog fires ONCE here
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

  Future<_LocationChoice?> _showPermissionDialog() {
    return showDialog<_LocationChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
              'Fixify uses your location to pin the service address on the map and find the nearest available professional.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
            const SizedBox(height: 24),
            // Allow — triggers system dialog
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, _LocationChoice.once),
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
            const SizedBox(height: 10),
            // Not now
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, _LocationChoice.deny),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Not now — I\'ll type my address',
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
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
          if ((p.street ?? '').isNotEmpty) _streetCtrl.text = p.street!;
          if ((p.subLocality ?? '').isNotEmpty)
            _barangayCtrl.text = p.subLocality!;
          else if ((p.subAdministrativeArea ?? '').isNotEmpty)
            _barangayCtrl.text = p.subAdministrativeArea!;
          final cityParts = [p.locality, p.administrativeArea]
              .where((s) => s != null && s.isNotEmpty)
              .toList();
          if (cityParts.isNotEmpty) _cityCtrl.text = cityParts.join(', ');
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
              _buildStep4(),
            ][_step],
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
            child: AnimatedContainer(
              duration: 200.ms,
              height: 140,
              decoration: BoxDecoration(
                color: _photoPath != null
                    ? Colors.transparent
                    : const Color(0xFFF0F4F2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _photoPath != null
                        ? AppColors.primary
                        : const Color(0xFFDDDDDD),
                    width: _photoPath != null ? 2 : 1),
              ),
              child: _pickingPhoto
                  ? const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          strokeWidth: 2))
                  : _photoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(fit: StackFit.expand, children: [
                            Image.file(File(_photoPath!), fit: BoxFit.cover),
                            Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _photoPath = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                )),
                          ]),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.cloud_upload_outlined,
                                  color: AppColors.textLight.withOpacity(0.5),
                                  size: 36),
                              const SizedBox(height: 8),
                              const Text('Tap to upload a photo',
                                  style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              const Text('Optional',
                                  style: TextStyle(
                                      color: Color(0xFFBBBBBB), fontSize: 11)),
                            ]),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ).animate().fadeIn(duration: 200.ms);

  // ── STEP 3: LOCATION ──────────────────────────────────────

  Widget _buildStep3() {
    // Default camera position: Davao City
    final initialPos = _pinned ?? const LatLng(7.0707, 125.6087);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Title + map/form toggle
      Row(children: [
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ),
        // Map / Form toggle pill
        GestureDetector(
          onTap: () => setState(() => _showMap = !_showMap),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _showMap
                  ? AppColors.primary.withOpacity(0.1)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _showMap
                      ? AppColors.primary.withOpacity(0.3)
                      : const Color(0xFFDDDDDD)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _showMap ? Icons.map_rounded : Icons.list_alt_rounded,
                size: 15,
                color: _showMap ? AppColors.primary : AppColors.textLight,
              ),
              const SizedBox(width: 5),
              Text(
                _showMap ? 'Map' : 'Form',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _showMap ? AppColors.primary : AppColors.textLight,
                ),
              ),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 16),

      // ── MAP VIEW ────────────────────────────────────────
      if (_showMap) ...[
        // Show a loading indicator while permission check is running
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

        // Permission denied banner (only shown after check completes)
        if (_permCheckDone && _permissionDenied)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.location_off_rounded,
                  color: Color(0xFFFF9500), size: 18),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text(
                'Location access denied. Tap the map to pin manually or fill in the address below.',
                style: TextStyle(fontSize: 12, color: Color(0xFFAA6600)),
              )),
              GestureDetector(
                onTap: _initLocation,
                child: const Text('Retry',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF9500))),
              ),
            ]),
          ),

        // Google Map — only rendered AFTER permission check is done
        if (_permCheckDone)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 270,
              child: Stack(children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: initialPos, zoom: 14),
                  onMapCreated: (c) {
                    _mapCtrl = c;
                    // If we already have a pin from GPS, don't re-center
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

                // GPS button (top-right)
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

                // Zoom buttons (bottom-right)
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

                // Geocoding spinner overlay
                if (_geocoding)
                  Positioned(
                    bottom: 12,
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

                // "Tap to pin" hint when no pin yet
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
        const SizedBox(height: 14),
      ],

      // ── Pinned address preview card ──────────────────────
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

      // ── Editable address fields ───────────────────────────
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
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(File(_photoPath!),
              height: 150, width: double.infinity, fit: BoxFit.cover),
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

// ── Internal enum ──────────────────────────────────────────────
enum _LocationChoice { once, always, deny }
