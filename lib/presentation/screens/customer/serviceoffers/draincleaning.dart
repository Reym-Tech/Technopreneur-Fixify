// lib/presentation/screens/customer/serviceoffers/draincleaning.dart
// Auto-generated service detail screen for Drain Cleaning.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class DrainCleaningScreen extends StatelessWidget {
  final Function(String, String)? onBookNow;
  const DrainCleaningScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Drain Cleaning',
        serviceType: 'Plumbing',
        description:
            'Clogged drains cause slow water drainage, foul odors, and potential backflow. Our professionals use mechanical snaking and hydro-jetting to clear blockages thoroughly — leaving your pipes flowing freely.',
        imagePath: 'assets/images/draincleaning.png',
        accentColor: const Color(0xFF007AFF),
        icon: Icons.water_drop_rounded,
        priceRange: '₱300 – ₱1,800',
        duration: '30 min – 2 hours',
        includes: const [
          'Visual and physical drain inspection',
          'Mechanical snake or hydro-jet clearing',
          'Removal of hair, grease, and debris',
          'Deodorizing treatment after cleaning',
          'Drain flow verification test',
        ],
        tips:
            'Avoid pouring grease or food scraps down drains between now and your appointment — it could worsen the blockage.',
        onBookNow: onBookNow,
      );
}
