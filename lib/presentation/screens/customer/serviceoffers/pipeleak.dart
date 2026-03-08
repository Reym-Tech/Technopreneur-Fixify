// lib/presentation/screens/customer/serviceoffers/pipeleak.dart
// Auto-generated service detail screen for Pipe Leak Repair.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class PipeLeakRepairScreen extends StatelessWidget {
  final Function(String, String)? onBookNow;
  const PipeLeakRepairScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Pipe Leak Repair',
        serviceType: 'Plumbing',
        description:
            'A leaking pipe can waste hundreds of liters of water per day and cause serious structural damage to your home. Our verified plumbers will quickly locate the source, replace or seal the affected section, and test the repair to ensure a permanent fix.',
        imagePath: 'assets/images/pipeleakrepair.png',
        accentColor: const Color(0xFF007AFF),
        icon: Icons.water_drop_rounded,
        priceRange: '₱500 – ₱2,500',
        duration: '1–3 hours',
        includes: const [
          'Inspection of visible and hidden pipes',
          'Sealing or replacement of the leaking section',
          'Pressure test after repair',
          'Clean-up of the work area',
          '30-day workmanship warranty',
        ],
        tips:
            'Turn off your main water valve before the handyman arrives to prevent further damage. Take photos of the leak area for the professional\'s reference.',
        onBookNow: onBookNow,
      );
}
