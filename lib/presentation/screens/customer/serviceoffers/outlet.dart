// lib/presentation/screens/customer/serviceoffers/outlet.dart
// Auto-generated service detail screen for Outlet Installation.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class OutletInstallationScreen extends StatelessWidget {
  final Function(String, String)? onBookNow;
  const OutletInstallationScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Outlet Installation',
        serviceType: 'Electrical',
        description:
            'Need more power points in your kitchen, home office, or living room? Our electricians install grounded outlets safely, ensuring proper load distribution and compliance with local electrical codes.',
        imagePath: 'assets/images/outletinstallation.png',
        accentColor: const Color(0xFFFF9500),
        icon: Icons.electrical_services_rounded,
        priceRange: '₱400 – ₱1,500 per outlet',
        duration: '30 min – 2 hours',
        includes: const [
          'Wall assessment and outlet placement advice',
          'Wiring from nearest junction or panel',
          'Grounded outlet installation',
          'Load capacity verification',
          'Safety inspection and testing',
        ],
        tips:
            'Decide the exact location(s) for new outlets beforehand. Consider USB-C combo outlets for modern convenience.',
        onBookNow: onBookNow,
      );
}
