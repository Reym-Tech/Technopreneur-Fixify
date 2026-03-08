// lib/presentation/screens/customer/serviceoffers/dryerrepair.dart
// Auto-generated service detail screen for Dryer Repair.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class DryerRepairScreen extends StatelessWidget {
  final Function(String, String)? onBookNow;
  const DryerRepairScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Dryer Repair',
        serviceType: 'Appliances',
        description:
            'A dryer that doesn\'t heat, tumbles slowly, or trips the breaker wastes energy and damages clothes. Our technicians will identify heating element, thermostat, or motor faults and get your dryer back to peak performance.',
        imagePath: 'assets/images/dryerrepair.png',
        accentColor: const Color(0xFF5856D6),
        icon: Icons.kitchen_rounded,
        priceRange: '₱500 – ₱3,000',
        duration: '1–3 hours',
        includes: const [
          'Heating element and thermostat diagnosis',
          'Belt, drum, and motor inspection',
          'Lint trap and vent duct cleaning',
          'Electrical connection check',
          'Full test cycle after repair',
        ],
        tips:
            'Clean the lint filter before the technician arrives. A clogged lint trap is the #1 cause of dryer fires and poor performance.',
        onBookNow: onBookNow,
      );
}
