// lib/presentation/screens/customer/serviceoffers/cabinetinstallation.dart
// Auto-generated service detail screen for Cabinet Installation.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class CabinetInstallationScreen extends StatelessWidget {
  final Function(String)? onBookNow;
  const CabinetInstallationScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Cabinet Installation',
        serviceType: 'Carpentry',
        description:
            'Transform your kitchen or bathroom with professionally installed cabinets. Our carpenters ensure level, secure mounting, proper alignment, and clean finishes — giving your space both beauty and lasting functionality.',
        imagePath: 'assets/images/cabenitinstallation.png',
        accentColor: const Color(0xFFFF3B30),
        icon: Icons.handyman_rounded,
        priceRange: '₱1,500 – ₱8,000',
        duration: '2–6 hours',
        includes: const [
          'Wall stud location and mounting preparation',
          'Cabinet leveling and alignment',
          'Secure wall-anchor installation',
          'Door hinge and hardware fitting',
          'Touch-up and clean-up after installation',
        ],
        tips:
            'Have your cabinets on-site and fully assembled before booking. Confirm measurements with your carpenter — even 1cm can matter.',
        onBookNow: onBookNow,
      );
}
