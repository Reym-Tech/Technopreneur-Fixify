// lib/presentation/screens/customer/requestservice_customer.dart
// See full docstring in file header.

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
  /// Full professionals list from Supabase. Screen filters approved+available ones.
  final List<ProfessionalModel> professionals;
  final Function(RequestServiceResult)? onSubmit;
  final VoidCallback? onBack;

  const RequestServiceScreen({
    super.key,
    this.professionals = const [],
    this.onSubmit,
    this.onBack,
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

  // Step 3
  GoogleMapController? _mapCtrl;
  LatLng? _pinned;
  String _address = '';
  bool _locating = false;
  final _notesCtrl = TextEditingController();

  // Step 4
  bool _submitting = false;

  // Service catalogue
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

  /// Service types with at least one APPROVED + AVAILABLE professional.
  Set<String> get _availableTypes {
    return widget.professionals
        .where((p) => p.verified && p.available)
        .expand((p) => p.skills)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}')
        .toSet();
  }

  /// Best-rated professional matching the selected service.
  ProfessionalModel? get _matchedPro {
    if (_serviceType == null) return null;
    final matches = widget.professionals.where((p) =>
        p.verified &&
        p.available &&
        p.skills.any((s) => s.toLowerCase() == _serviceType!.toLowerCase()));
    if (matches.isEmpty) return null;
    return matches.reduce((a, b) => (a.rating ?? 0) >= (b.rating ?? 0) ? a : b);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // Navigation
  void _next() {
    if (_step == 0 && _serviceType == null) {
      _snack('Please select a service type');
      return;
    }
    if (_step == 1 && _titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a problem title');
      return;
    }
    if (_step == 2 && _address.isEmpty) {
      _snack('Please pin your location on the map');
      return;
    }
    if (_step == 3) {
      _submit();
      return;
    }
    setState(() => _step++);
    if (_step == 2 && _pinned == null) _getCurrentLocation();
  }

  void _back() {
    if (_step == 0)
      widget.onBack?.call();
    else
      setState(() => _step--);
  }

  // Photo
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

  // Location
  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        _snack('Location permission denied. Pin manually on the map.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      await _updatePin(ll);
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 17));
    } catch (_) {
      _snack('Could not get location. Pin manually on the map.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _onMapTap(LatLng ll) => _updatePin(ll);

  Future<void> _updatePin(LatLng ll) async {
    setState(() {
      _pinned = ll;
      _address = '';
    });
    try {
      final marks = await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.postalCode,
          p.country
        ].where((s) => s != null && s!.isNotEmpty).toList();
        setState(() => _address = parts.join(', '));
      }
    } catch (_) {
      if (mounted)
        setState(() => _address =
            '${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}');
    }
  }

  // Submit
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
      address: _address,
      latitude: _pinned?.latitude,
      longitude: _pinned?.longitude,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      photoPath: _photoPath,
      matchedPro: pro,
    ));
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

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
              _buildStep4()
            ][_step],
          ),
        ),
        _buildFooter(),
      ]),
    );
  }

  Widget _buildTopBar() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF082218), Color(0xFF0F3D2E)]),
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
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    )),
                const SizedBox(width: 14),
                const Text('Request Service',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ]),
            )),
      );

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
                  color: done ? AppColors.primary : const Color(0xFFE0E0E0)));
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
                  color: active ? AppColors.primary : const Color(0xFFAAAAAA))),
        ]);
      })),
    );
  }

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
          _inputField(
              controller: _titleCtrl,
              hint: 'Problem Title',
              icon: Icons.title_rounded),
          const SizedBox(height: 14),
          _inputField(
              controller: _descCtrl,
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

  Widget _buildStep3() {
    final initialPos =
        _pinned ?? const LatLng(7.0707, 125.6087); // Default: Davao
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Pin Your Location',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.3)),
      const SizedBox(height: 4),
      const Text('Tap on the map to pin your exact location',
          style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 280,
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: initialPos, zoom: 14),
              onMapCreated: (c) => _mapCtrl = c,
              onTap: _onMapTap,
              markers: _pinned != null
                  ? {
                      Marker(
                          markerId: const MarkerId('pin'),
                          position: _pinned!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed))
                    }
                  : {},
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
            Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _getCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8)
                      ],
                    ),
                    child: _locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary)))
                        : const Icon(Icons.my_location_rounded,
                            color: AppColors.primary, size: 20),
                  ),
                )),
            if (_pinned == null)
              Center(
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Tap map to pin location',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              )),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(16),
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
            width: 38,
            height: 38,
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
                size: 20),
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
                            : const Color(0xFFAAAAAA))),
                if (_address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(_address,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark)),
                ],
              ])),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('Additional Notes (Optional)',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark)),
      const SizedBox(height: 12),
      _inputField(
          controller: _notesCtrl,
          hint: 'e.g. Gate is on the left side, call before coming...',
          icon: Icons.sticky_note_2_outlined,
          maxLines: 3,
          prefix: 'P.S.'),
      const SizedBox(height: 20),
    ]).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildStep4() {
    final rows = [
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
        'value': _address.isEmpty ? 'No location pinned' : _address
      },
      if (_notesCtrl.text.trim().isNotEmpty)
        {
          'icon': Icons.sticky_note_2_outlined,
          'label': 'Additional Notes',
          'value': _notesCtrl.text.trim()
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
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium))),
        ]),
      ),
      const SizedBox(height: 20),
    ]).animate().fadeIn(duration: 200.ms);
  }

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

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}),
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
