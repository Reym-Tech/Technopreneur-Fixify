// lib/presentation/screens/customer/serviceoffers/service_detail_screen.dart
//
// ServiceDetailScreen — rich detail page for a specific service offer.
// Shows: hero image, service name, description, what's included list,
// estimated price range, typical duration, and a "Book Now" CTA.
//
// Props:
//   serviceName     → String
//   serviceType     → String   — matches RequestServiceScreen serviceType (e.g. 'Plumbing')
//   description     → String
//   imagePath       → String
//   accentColor     → Color
//   icon            → IconData
//   includes        → List<String>  — what the service covers
//   priceRange      → String        — e.g. '₱500 – ₱1,500'
//   duration        → String        — e.g. '1–3 hours'
//   tips            → String?       — optional tip/note for the customer
//   onBookNow       → Function(String serviceType, String serviceName)
//                     ↑ now passes BOTH so the request wizard can pre-fill
//                       the Problem Title field with the specific service name.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

class ServiceDetailScreen extends StatelessWidget {
  final String serviceName;
  final String serviceType;
  final String description;
  final String imagePath;
  final Color accentColor;
  final IconData icon;
  final List<String> includes;
  final String priceRange;
  final String duration;
  final String? tips;

  /// Called when the user taps "Book Now".
  /// Receives [serviceType] (category, e.g. 'Plumbing') AND
  /// [serviceName] (specific service, e.g. 'Pipe Leak Repair') so the
  /// RequestServiceScreen wizard can pre-populate the Problem Title field.
  final Function(String serviceType, String serviceName)? onBookNow;

  const ServiceDetailScreen({
    super.key,
    required this.serviceName,
    required this.serviceType,
    required this.description,
    required this.imagePath,
    required this.accentColor,
    required this.icon,
    required this.includes,
    required this.priceRange,
    required this.duration,
    this.tips,
    this.onBookNow,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(serviceName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 8)])),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: accentColor.withOpacity(0.2),
                      child: Icon(icon, size: 80, color: accentColor),
                    ),
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          accentColor.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick stats row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _statChip(
                          Icons.payments_rounded, priceRange, accentColor),
                      const SizedBox(width: 12),
                      _statChip(
                          Icons.schedule_rounded, duration, AppColors.primary),
                    ]),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                  const SizedBox(height: 20),

                  // Description
                  _sectionTitle('About This Service'),
                  const SizedBox(height: 8),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textMedium,
                          height: 1.6)),

                  const SizedBox(height: 24),

                  // What's Included
                  _sectionTitle('What\'s Included'),
                  const SizedBox(height: 12),
                  ...includes
                      .asMap()
                      .entries
                      .map((e) => _includeItem(e.value, accentColor, e.key)),

                  // Tips (optional)
                  if (tips != null) ...[
                    const SizedBox(height: 24),
                    _tipBox(tips!, accentColor),
                  ],

                  const SizedBox(height: 100), // space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBookButton(context),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          letterSpacing: -0.2));

  Widget _includeItem(String text, Color color, int index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 13, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textMedium, height: 1.45)),
          ),
        ]).animate().fadeIn(delay: (150 + index * 50).ms).slideX(begin: 0.05),
      );

  Widget _tipBox(String tip, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9500).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pro Tip',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFCC7700))),
              const SizedBox(height: 4),
              Text(tip,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium, height: 1.5)),
            ]),
          ),
        ]),
      );

  Widget _buildBookButton(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                if (onBookNow != null) {
                  // Pass BOTH serviceType (category) and serviceName (specific)
                  onBookNow!(serviceType, serviceName);
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.calendar_month_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Book Now',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}
