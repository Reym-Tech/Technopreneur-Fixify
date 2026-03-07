// lib/presentation/screens/customer/serviceoffers/ceilingpainting.dart
// Auto-generated service detail screen for Ceiling Painting.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class CeilingPaintingScreen extends StatelessWidget {
  final Function(String)? onBookNow;
  const CeilingPaintingScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Ceiling Painting',
        serviceType: 'Painting',
        description:
            'Yellowed, water-stained, or peeling ceiling paint brings down the whole room. Our painters work efficiently at height, treating stains and applying ceiling-grade paint for a clean, bright finish overhead.',
        imagePath: 'assets/images/ceillingpainting.png',
        accentColor: const Color(0xFF34C759),
        icon: Icons.format_paint_rounded,
        priceRange: '₱800 – ₱4,000 per room',
        duration: '3–6 hours',
        includes: const [
          'Water stain treatment and sealing',
          'Surface sanding and priming',
          '2 coats of ceiling-grade white paint',
          'Wall/trim masking for clean borders',
          'Drop cloth protection for flooring',
        ],
        tips:
            'If there\'s an active leak causing the stains, fix it first — our Plumbing service can help. Painting over an active leak will only be a temporary fix.',
        onBookNow: onBookNow,
      );
}
