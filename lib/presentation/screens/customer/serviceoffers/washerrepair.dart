// lib/presentation/screens/customer/serviceoffers/washerrepair.dart
// Auto-generated service detail screen for Washer Repair.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class WasherRepairScreen extends StatelessWidget {
  final Function(String)? onBookNow;
  const WasherRepairScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Washer Repair',
        serviceType: 'Appliances',
        description:
            'Whether your washing machine won\'t spin, leaks, or makes unusual noises, our appliance technicians diagnose the root cause and repair it on the spot — restoring your laundry routine without the cost of a new unit.',
        imagePath: 'assets/images/washerrepair.png',
        accentColor: const Color(0xFF5856D6),
        icon: Icons.kitchen_rounded,
        priceRange: '₱500 – ₱3,500',
        duration: '1–3 hours',
        includes: const [
          'Full diagnostic assessment',
          'Repair of motor, pump, or drum issues',
          'Belt and bearing replacement if needed',
          'Water inlet valve inspection',
          'Test run to confirm fix',
        ],
        tips:
            'Note down the exact symptoms (e.g. error code on display, which cycle it fails at) — this helps the technician arrive prepared with the right parts.',
        onBookNow: onBookNow,
      );
}
