// lib/presentation/screens/customer/serviceoffers/pipeleak.dart
// Auto-generated service detail screen for Pipe Leak Repair.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../data/datasources/supabase_datasource.dart';
import '../../../../data/models/models.dart';
import 'service_detail_screen.dart';

/// DB-backed loader for the Pipe Leak Repair service.
/// Falls back to the previous hardcoded values if the DB lookup fails.
class PipeLeakRepairScreen extends StatefulWidget {
  final Function(String, String)? onBookNow;
  const PipeLeakRepairScreen({super.key, this.onBookNow});

  @override
  State<PipeLeakRepairScreen> createState() => _PipeLeakRepairScreenState();
}

class _PipeLeakRepairScreenState extends State<PipeLeakRepairScreen> {
  ServiceOfferModel? _offer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    try {
      final ds = SupabaseDataSource(Supabase.instance.client);
      final fetched = await ds.getServiceOfferBySlug('pipe-leak-repair');
      if (mounted) setState(() => _offer = fetched);
    } catch (e) {
      debugPrint('Failed to fetch service offer: $e');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_offer == null) {
      // Fallback: render the previous hardcoded screen if DB missing
      return ServiceDetailScreen(
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
        onBookNow: widget.onBookNow,
      );
    }

    final accent = const Color(0xFF007AFF);
    final icon = Icons.water_drop_rounded;

    return ServiceDetailScreen(
      serviceName: _offer!.serviceName,
      serviceType: _offer!.serviceType,
      description: _offer!.description ?? '',
      imagePath: _offer!.imageUrl ?? 'assets/images/pipeleakrepair.png',
      accentColor: accent,
      icon: icon,
      priceRange: _offer!.priceRange ?? '',
      duration: _offer!.duration ?? '',
      includes: _offer!.includes,
      tips: _offer!.tips,
      onBookNow: widget.onBookNow,
    );
  }
}
