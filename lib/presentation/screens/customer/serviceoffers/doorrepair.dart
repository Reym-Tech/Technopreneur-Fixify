// lib/presentation/screens/customer/serviceoffers/doorrepair.dart
// Auto-generated service detail screen for Door Repair.

import 'package:flutter/material.dart';
import 'service_detail_screen.dart';

class DoorRepairScreen extends StatelessWidget {
  final Function(String)? onBookNow;
  const DoorRepairScreen({super.key, this.onBookNow});

  @override
  Widget build(BuildContext context) => ServiceDetailScreen(
        serviceName: 'Door Repair',
        serviceType: 'Carpentry',
        description:
            'Squeaky, sticking, or misaligned doors are more than annoying — they can be a security risk. Our carpenters re-hang, plane, or replace door components to restore smooth, secure operation.',
        imagePath: 'assets/images/doorrepair.png',
        accentColor: const Color(0xFFFF3B30),
        icon: Icons.handyman_rounded,
        priceRange: '₱300 – ₱2,000',
        duration: '1–3 hours',
        includes: const [
          'Door frame and hinge inspection',
          'Planing or adjustment for a perfect fit',
          'Hinge tightening or replacement',
          'Lock and latch mechanism check',
          'Weather stripping replacement if needed',
        ],
        tips:
            'If the door started sticking after a rainy season, it may have swollen — our carpenter will account for this and size it correctly.',
        onBookNow: onBookNow,
      );
}
