// lib/presentation/screens/professional/propose_service_screen.dart
//
// ProposeServiceScreen — form for a verified Handyman to propose a new
// service offer. Submitted proposals go to the Admin for review.
//
// Lifecycle:
//   pending  → Admin reviewing
//   approved → Visible in Customer Service Offers
//   rejected → Admin note shown; handyman can edit & resubmit
//
// Props:
//   professionalId → String
//   userId         → String
//   existingProposal → ServiceProposalModel? — pre-fills form for resubmission
//   onSubmit       → Function(ProposeServiceFormData)?
//   onBack         → VoidCallback?

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/application_datasource.dart';

class ProposeServiceScreen extends StatefulWidget {
  final String professionalId;
  final String userId;

  /// If non-null, the form pre-fills with the existing proposal's data.
  /// Used when the handyman is resubmitting after a rejection.
  final ServiceProposalModel? existingProposal;

  final Function(ProposeServiceFormData data)? onSubmit;
  final VoidCallback? onBack;

  const ProposeServiceScreen({
    super.key,
    required this.professionalId,
    required this.userId,
    this.existingProposal,
    this.onSubmit,
    this.onBack,
  });

  @override
  State<ProposeServiceScreen> createState() => _ProposeServiceScreenState();
}

class _ProposeServiceScreenState extends State<ProposeServiceScreen> {
  static const _serviceTypes = [
    'Plumber',
    'Electrician',
    'Technician',
    'Carpenter',
    'Masonry',
  ];

  // ── Controllers ───────────────────────────────────────────────────────────
  late String? _serviceType;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _tipsCtrl;

  // Includes — each item editable, add/remove rows
  late List<TextEditingController> _includeControllers;

  File? _imageFile;
  bool _submitting = false;
  bool _pickingImage = false;

  // For resubmission: remember the existing image URL so we only re-upload
  // if the handyman swaps the image.
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProposal;
    _serviceType = p?.serviceType;
    _nameCtrl = TextEditingController(text: p?.serviceName ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: p?.priceRange ?? '');
    _durationCtrl = TextEditingController(text: p?.duration ?? '');
    _tipsCtrl = TextEditingController(text: p?.tips ?? '');
    _includeControllers = p != null && p.includes.isNotEmpty
        ? p.includes.map((s) => TextEditingController(text: s)).toList()
        : [TextEditingController()];
    _existingImageUrl = p?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _tipsCtrl.dispose();
    for (final c in _includeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (img != null && mounted) {
        setState(() {
          _imageFile = File(img.path);
          _existingImageUrl = null; // new image selected — discard old URL
        });
      }
    } catch (_) {
      _snack('Could not open gallery');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_serviceType == null) {
      _snack('Please select a service type');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Please enter a service name');
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _snack('Please add a description');
      return;
    }
    if (_imageFile == null && _existingImageUrl == null) {
      _snack('Please upload a service image');
      return;
    }
    if (_priceCtrl.text.trim().isEmpty) {
      _snack('Please add an estimated price range');
      return;
    }
    if (_durationCtrl.text.trim().isEmpty) {
      _snack('Please add an estimated duration');
      return;
    }
    final includes = _includeControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (includes.isEmpty) {
      _snack('Add at least one item to "What\'s Included"');
      return;
    }
    // If resubmitting without a new image, create a stub File so the
    // form data type is consistent — the datasource will use existingImageUrl.
    final imageFile = _imageFile ?? File('');

    // Normalize before sending so DB stores a consistent, peso-prefixed value.
    final normalizedPrice = _normalizePriceRange(_priceCtrl.text.trim());

    setState(() => _submitting = true);
    await widget.onSubmit?.call(ProposeServiceFormData(
      serviceType: _serviceType!,
      serviceName: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      imageFile: imageFile,
      includes: includes,
      priceRange: normalizedPrice,
      duration: _durationCtrl.text.trim(),
      tips: _tipsCtrl.text.trim().isEmpty ? null : _tipsCtrl.text.trim(),
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

  // Normalize the textual price range so we always store a consistent
  // currency-formatted string in the DB (e.g. "₱500 – ₱1,800").
  String _normalizePriceRange(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;

    // Extract numeric parts (allow commas and decimal points).
    final parts =
        RegExp(r"(\d[\d.,]*)").allMatches(s).map((m) => m.group(1)!).toList();
    if (parts.isEmpty) {
      return s.startsWith('₱') ? s : '₱$s';
    }
    if (parts.length == 1) return '₱${parts[0]}';

    // Use en-dash with spaces between amounts for consistency.
    return '₱${parts[0]} – ₱${parts[1]}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isResubmit = widget.existingProposal != null;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildHeader(isResubmit),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Rejection note banner (resubmission only) ──────────────
              if (isResubmit && widget.existingProposal!.adminNote != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFF3B30).withOpacity(0.2)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Color(0xFFFF3B30), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Admin Feedback',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFFF3B30))),
                                const SizedBox(height: 3),
                                Text(widget.existingProposal!.adminNote!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFFF3B30))),
                              ]),
                        ),
                      ]),
                ).animate().fadeIn(delay: 60.ms),
                const SizedBox(height: 20),
              ],

              // ── Info banner ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Your proposal will be reviewed by the admin. '
                          'Once approved, it will appear in the Customer Service Offers.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMedium),
                        ),
                      ),
                    ]),
              ).animate().fadeIn(delay: 80.ms),
              const SizedBox(height: 24),

              // ── Service type ───────────────────────────────────────────
              _sectionLabel('Service Type *'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _serviceTypes.map((s) {
                  final sel = _serviceType == s;
                  return GestureDetector(
                    onTap: () => setState(() => _serviceType = s),
                    child: AnimatedContainer(
                      duration: 180.ms,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : const Color(0xFFDDDDDD)),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))
                              ]
                            : [],
                      ),
                      child: Text(s,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textMedium,
                          )),
                    ),
                  );
                }).toList(),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 22),

              // ── Service name ───────────────────────────────────────────
              _sectionLabel('Service Name *'),
              const Text('e.g. "Pipe Leak Repair" or "Circuit Breaker Fix"',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 8),
              _textField(
                controller: _nameCtrl,
                hint: 'Enter a specific service name',
                icon: Icons.home_repair_service_rounded,
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 20),

              // ── Image ──────────────────────────────────────────────────
              _sectionLabel('Service Image *'),
              const Text('Upload a clear photo that represents this service.',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 8),
              _buildImagePicker().animate().fadeIn(delay: 140.ms),
              const SizedBox(height: 20),

              // ── Description ────────────────────────────────────────────
              _sectionLabel('About This Service *'),
              const SizedBox(height: 8),
              _textField(
                controller: _descCtrl,
                hint:
                    'Describe what this service covers and why customers need it...',
                icon: Icons.article_outlined,
                maxLines: 4,
              ).animate().fadeIn(delay: 160.ms),
              const SizedBox(height: 20),

              // ── What's included ────────────────────────────────────────
              _sectionLabel('What\'s Included *'),
              const Text('Each item appears as a bullet point.',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 8),
              ..._includeControllers.asMap().entries.map((entry) {
                final i = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: _textField(
                        controller: entry.value,
                        hint: 'e.g. Visual inspection and diagnosis',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    if (_includeControllers.length > 1) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _includeControllers[i].dispose();
                          _includeControllers.removeAt(i);
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_rounded,
                              color: Color(0xFFFF3B30), size: 18),
                        ),
                      ),
                    ],
                  ]),
                );
              }),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(
                    () => _includeControllers.add(TextEditingController())),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Text('Add Item',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // ── Price range ────────────────────────────────────────────
              _sectionLabel('Estimated Price Range *'),
              const Text('e.g. ₱300 – ₱1,500',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 8),
              _textField(
                controller: _priceCtrl,
                hint: '₱500 – ₱2,000',
                icon: Icons.payments_rounded,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 20),

              // ── Duration ───────────────────────────────────────────────
              _sectionLabel('Estimated Duration *'),
              const Text('e.g. 1–3 hours',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 8),
              _textField(
                controller: _durationCtrl,
                hint: '1–2 hours',
                icon: Icons.schedule_rounded,
              ).animate().fadeIn(delay: 220.ms),
              const SizedBox(height: 20),

              // ── Pro tip (optional) ─────────────────────────────────────
              _sectionLabel('Pro Tip — optional'),
              const Text('A useful note shown to customers before booking.',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 8),
              _textField(
                controller: _tipsCtrl,
                hint: 'e.g. Clear the area around the pipes before I arrive.',
                icon: Icons.lightbulb_outline_rounded,
                maxLines: 3,
              ).animate().fadeIn(delay: 240.ms),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
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
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          isResubmit ? 'Resubmit Proposal' : 'Submit Proposal',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 260.ms),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Processing usually takes 24–48 hours.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight.withOpacity(0.7)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isResubmit) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF082218),
              Color(0xFF0F3D2E),
              Color(0xFF1A5C43),
            ],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(children: [
              Row(children: [
                GestureDetector(
                  onTap: widget.onBack ?? () => Navigator.maybePop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isResubmit ? 'Update Proposal' : 'Propose a Service',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD4A843).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.storefront_rounded,
                        color: Color(0xFFD4A843), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Service Proposal',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Submit your service for admin approval',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                        ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );

  // ── Image picker tile ─────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    final hasImage = _imageFile != null || _existingImageUrl != null;
    return GestureDetector(
      onTap: hasImage ? null : _pickImage,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: hasImage ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? AppColors.primary.withOpacity(0.35)
                : const Color(0xFFDDDDDD),
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: _pickingImage
            ? const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary)))
            : hasImage
                ? Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _imageFile != null
                          ? Image.file(_imageFile!, fit: BoxFit.cover)
                          : Image.network(_existingImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.primary.withOpacity(0.08),
                                    child: const Icon(
                                        Icons.broken_image_rounded,
                                        color: AppColors.primary,
                                        size: 32),
                                  )),
                    ),
                    // Change / remove overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(15)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.55),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        child: Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 13),
                                    SizedBox(width: 4),
                                    Text('Change',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _imageFile = null;
                              _existingImageUrl = null;
                            }),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      color: Colors.white70, size: 13),
                                  SizedBox(width: 4),
                                  Text('Remove',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                                ]),
                          ),
                        ]),
                      ),
                    ),
                  ])
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.add_photo_alternate_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(height: 10),
                      const Text('Tap to upload a service image',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      const SizedBox(height: 3),
                      const Text('Clear, well-lit photos work best',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textLight)),
                    ],
                  ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: maxLines == 1
              ? Icon(icon, color: AppColors.textLight, size: 20)
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      );
}
