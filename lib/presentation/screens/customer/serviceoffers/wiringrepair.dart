// lib/presentation/screens/customer/serviceoffers/wiringrepair.dart
// Auto-generated service detail screen for Wiring Repair.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class WiringRepairScreen extends StatelessWidget {
  final Function(String, String)? onBookNow;
  const WiringRepairScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Wiring Repair',
        serviceType: 'Electrical',
        description:
            'Faulty wiring is a leading cause of house fires. Our licensed electricians diagnose short circuits, damaged insulation, and overloaded circuits to restore safe, reliable power throughout your home.',
        imagePath: 'assets/images/wirerepair.png',
        accentColor: const Color(0xFFFF9500),
        icon: Icons.electrical_services_rounded,
        priceRange: '₱600 – ₱3,000',
        duration: '1–4 hours',
        includes: const [
          'Electrical fault diagnosis',
          'Repair or replacement of damaged wiring',
          'Circuit breaker inspection',
          'Safety continuity test after repair',
          'PEC-compliant installation',
        ],
        tips:
            'Switch off the circuit breaker for the affected area before the technician arrives. Note where and when the issue occurs (e.g. specific appliance, time of day).',
        onBookNow: onBookNow,
      );
}
