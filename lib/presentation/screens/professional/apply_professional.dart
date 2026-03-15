// lib/presentation/screens/professional/apply_professional.dart
//
// ApplyScreen — Credential submission form for Professional (Handyman).
//
// The handyman fills this once per service type they want to offer.
// Submitting creates a row in professional_applications with status='pending'.
// Admin then reviews and approves/rejects.
//
// Key props:
//   professionalId → String          — the pro's professionals.id
//   userId         → String          — auth user id
//   onSubmit       → Function(ApplyFormData)? — called on submit
//   onBack         → VoidCallback?

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fixify/core/theme/app_theme.dart';

class ApplyFormData {
  final String serviceType;
  final File credentialFile;
  final File validIdFile;
  final int yearsExp;
  final double? priceMin;
  final String? bio;

  const ApplyFormData({
    required this.serviceType,
    required this.credentialFile,
    required this.validIdFile,
    required this.yearsExp,
    this.priceMin,
    this.bio,
  });
}

class ApplyScreen extends StatefulWidget {
  final String professionalId;
  final String userId;
  final Function(ApplyFormData)? onSubmit;
  final VoidCallback? onBack;

  const ApplyScreen({
    super.key,
    required this.professionalId,
    required this.userId,
    this.onSubmit,
    this.onBack,
  });

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  String? _serviceType;
  File? _credentialFile;
  File? _validIdFile;
  final _yearsCtrl = TextEditingController(text: '0');
  final _bioCtrl = TextEditingController();
  bool _submitting = false;
  bool _pickingCred = false;
  bool _pickingId = false;

  static const _serviceTypes = [
    'Plumber',
    'Electrician',
    'Technician',
    'Carpenter',
    'Masonry',
  ];

  @override
  void dispose() {
    _yearsCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isCred) async {
    if (isCred)
      setState(() => _pickingCred = true);
    else
      setState(() => _pickingId = true);
    try {
      final img = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (img != null && mounted) {
        setState(() {
          if (isCred)
            _credentialFile = File(img.path);
          else
            _validIdFile = File(img.path);
        });
      }
    } catch (_) {
      _snack('Could not open gallery');
    } finally {
      if (mounted)
        setState(() {
          if (isCred)
            _pickingCred = false;
          else
            _pickingId = false;
        });
    }
  }

  Future<void> _submit() async {
    if (_serviceType == null) {
      _snack('Select a service type');
      return;
    }
    if (_credentialFile == null) {
      _snack('Upload your credential (TESDA cert, diploma, etc.)');
      return;
    }
    if (_validIdFile == null) {
      _snack('Upload a valid government ID');
      return;
    }
    final years = int.tryParse(_yearsCtrl.text.trim()) ?? 0;
    setState(() => _submitting = true);
    await widget.onSubmit?.call(ApplyFormData(
      serviceType: _serviceType!,
      credentialFile: _credentialFile!,
      validIdFile: _validIdFile!,
      yearsExp: years,
      priceMin: null,
      bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
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
        _buildHeader(),
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text(
                  'Submit your credentials for each service type you offer. '
                  'The admin will review and approve your application before customers can book you.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                )),
              ]),
            ).animate().fadeIn(delay: 80.ms),
            const SizedBox(height: 24),

            // Service type
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
            ).animate().fadeIn(delay: 120.ms),
            const SizedBox(height: 24),

            // Credential upload
            _sectionLabel('Credential Document *'),
            const Text('TESDA certificate, diploma, or training certificate',
                style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 10),
            _uploadTile(
              label: 'Upload Credential',
              hint: 'TESDA cert, diploma, training cert...',
              file: _credentialFile,
              loading: _pickingCred,
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFFF9500),
              onTap: () => _pickFile(true),
              onRemove: () => setState(() => _credentialFile = null),
            ).animate().fadeIn(delay: 160.ms),
            const SizedBox(height: 20),

            // Valid ID upload
            _sectionLabel('Valid Government ID *'),
            const Text(
                'Passport, driver\'s license, SSS, PhilHealth, UMID, etc.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 10),
            _uploadTile(
              label: 'Upload Valid ID',
              hint: 'Passport, Driver\'s License, UMID...',
              file: _validIdFile,
              loading: _pickingId,
              icon: Icons.badge_rounded,
              color: const Color(0xFF007AFF),
              onTap: () => _pickFile(false),
              onRemove: () => setState(() => _validIdFile = null),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),

            // Years of experience
            _sectionLabel('Years of Experience'),
            const SizedBox(height: 10),
            _textField(
              controller: _yearsCtrl,
              hint: 'e.g. 3',
              icon: Icons.trending_up_rounded,
              keyboardType: TextInputType.number,
            ).animate().fadeIn(delay: 240.ms),
            const SizedBox(height: 20),

            // Bio
            _sectionLabel('Short Bio  — optional'),
            const SizedBox(height: 10),
            _textField(
              controller: _bioCtrl,
              hint: 'Tell customers about your experience and skills...',
              icon: Icons.person_outline_rounded,
              maxLines: 4,
            ).animate().fadeIn(delay: 280.ms),
            const SizedBox(height: 32),

            // Submit button
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
                    : const Text('Submit Application',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ).animate().fadeIn(delay: 360.ms),
            const SizedBox(height: 12),
            Center(
                child: Text('Processing usually takes 24–48 hours.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight.withOpacity(0.7)))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF082218),
                Color(0xFF0F3D2E),
                Color(0xFF1A5C43)
              ]),
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
                      )),
                  const SizedBox(width: 14),
                  const Text('Apply as Handyman',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD4A843).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: Color(0xFFD4A843), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Professional Verification',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 3),
                          Text('Submit your credentials to get approved',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ])),
                  ]),
                ),
              ]),
            )),
      );

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark));

  Widget _uploadTile({
    required String label,
    required String hint,
    required File? file,
    required bool loading,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: file == null ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: file != null ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                file != null ? color.withOpacity(0.4) : const Color(0xFFDDDDDD),
            width: file != null ? 1.5 : 1,
          ),
        ),
        child: loading
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary))))
            : file != null
                ? Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.file(file, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('File selected',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                          const SizedBox(height: 2),
                          Text(file.path.split('/').last,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLight),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ])),
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30).withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFFFF3B30), size: 16),
                      ),
                    ),
                  ])
                : Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(label,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          Text(hint,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLight)),
                        ])),
                    Icon(Icons.upload_rounded,
                        color: color.withOpacity(0.6), size: 20),
                  ]),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? prefix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
