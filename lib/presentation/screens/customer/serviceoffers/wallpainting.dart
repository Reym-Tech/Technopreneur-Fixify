// lib/presentation/screens/customer/serviceoffers/wallpainting.dart
// Auto-generated service detail screen for Wall Painting.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class WallPaintingScreen extends StatelessWidget {
  final Function(String)? onBookNow;
  const WallPaintingScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Wall Painting',
        serviceType: 'Painting',
        description:
            'A fresh coat of paint is the fastest way to transform a room. Our professional painters prepare surfaces properly, apply even coats, and deliver clean edges and consistent coverage — with minimal disruption to your home.',
        imagePath: 'assets/images/wallpainting.png',
        accentColor: const Color(0xFF34C759),
        icon: Icons.format_paint_rounded,
        priceRange: '₱1,000 – ₱6,000 per room',
        duration: '4–8 hours',
        includes: const [
          'Surface preparation and crack filling',
          'Primer application where needed',
          '2 coats of interior paint',
          'Edge masking for clean lines',
          'Furniture protection and clean-up',
        ],
        tips:
            'Choose your paint color and finish before booking. Flat/matte finishes hide imperfections; semi-gloss is easier to clean for kitchens and bathrooms.',
        onBookNow: onBookNow,
      );
}
