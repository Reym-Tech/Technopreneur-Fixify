// lib/presentation/screens/professional/my_services_screen.dart
//
// MyServicesScreen — lets a verified professional select which admin-seeded
// services they offer. Only shows services matching their approved skill type.
// They can also tap "Propose New Service" to submit a service that doesn't
// exist yet in the catalogue.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/models/models.dart';

class MyServicesScreen extends StatefulWidget {
  /// All approved service offers for this professional's skill type.
  final List<ServiceOfferModel> availableServices;

  /// IDs of services the professional has already selected.
  final Set<String> selectedIds;

  /// Called when the professional toggles a service on or off.
  final Future<void> Function(String serviceOfferId, bool selected)
      onToggleService;

  /// Called when the professional taps "Propose New Service".
  final VoidCallback? onProposeNew;

  final VoidCallback? onBack;

  /// The professional's skill type label (e.g. 'Plumber') — shown in header.
  final String skillType;

  /// The professional's own user ID — used to identify which services
  /// they proposed themselves (shown with a "Your Proposal" badge).
  final String? myProfessionalId;

  const MyServicesScreen({
    super.key,
    required this.availableServices,
    required this.selectedIds,
    required this.onToggleService,
    this.onProposeNew,
    this.onBack,
    required this.skillType,
    this.myProfessionalId,
  });

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  late Set<String> _selectedIds;
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedIds);
  }

  Future<void> _toggle(ServiceOfferModel offer) async {
    if (_loading.contains(offer.id)) return;

    // Proposed services are permanently selected — cannot be deselected
    final isOwnProposal = widget.myProfessionalId != null &&
        offer.professionalId == widget.myProfessionalId;
    if (isOwnProposal && _selectedIds.contains(offer.id)) return;
    final nowSelected = !_selectedIds.contains(offer.id);
    setState(() {
      _loading.add(offer.id);
      if (nowSelected) {
        _selectedIds.add(offer.id);
      } else {
        _selectedIds.remove(offer.id);
      }
    });
    try {
      await widget.onToggleService(offer.id, nowSelected);
    } catch (e) {
      // Revert on error
      setState(() {
        if (nowSelected) {
          _selectedIds.remove(offer.id);
        } else {
          _selectedIds.add(offer.id);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading.remove(offer.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(children: [
        _buildTopBar(),
        Expanded(
          child: widget.availableServices.isEmpty
              ? _buildEmpty()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(
                          'Select the services you offer as a ${widget.skillType}. '
                          'Customers booking these exact services will be matched to you.',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                              height: 1.5),
                        ),
                      ).animate().fadeIn(delay: 80.ms),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final offer = widget.availableServices[i];
                            final isOwnProposal = widget.myProfessionalId !=
                                    null &&
                                offer.professionalId == widget.myProfessionalId;
                            return _ServiceTile(
                              offer: offer,
                              selected: _selectedIds.contains(offer.id),
                              loading: _loading.contains(offer.id),
                              isOwnProposal: isOwnProposal,
                              onTap: () => _toggle(offer),
                            )
                                .animate()
                                .fadeIn(delay: (i * 40).ms)
                                .slideX(begin: 0.03, end: 0);
                          },
                          childCount: widget.availableServices.length,
                        ),
                      ),
                    ),
                    // Propose new service button
                    if (widget.onProposeNew != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          child: OutlinedButton.icon(
                            onPressed: widget.onProposeNew,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Propose a New Service',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                  color: AppColors.primary.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _buildTopBar() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF082218), Color(0xFF0F3D2E)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              GestureDetector(
                onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Services',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(widget.skillType,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w400)),
                    ]),
              ),
              // Selected count badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedIds.length} selected',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.07),
                  shape: BoxShape.circle),
              child: const Icon(Icons.home_repair_service_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No Services Available Yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text(
              'The admin hasn\'t seeded any services for your skill type yet. '
              'You can propose a new service below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
            if (widget.onProposeNew != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onProposeNew,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Propose a New Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ]),
        ),
      );
}

// ── Service tile ──────────────────────────────────────────────────────────────

class _ServiceTile extends StatelessWidget {
  final ServiceOfferModel offer;
  final bool selected;
  final bool loading;
  final bool isOwnProposal;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.offer,
    required this.selected,
    required this.loading,
    required this.onTap,
    this.isOwnProposal = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : const Color(0xFFEEEEEE),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: offer.imageUrl != null
                ? Image.network(
                    offer.imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(offer.serviceName,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textDark)),
                ),
                // "Your Proposal" badge
                if (isOwnProposal) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A843).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFD4A843).withOpacity(0.4)),
                    ),
                    child: const Text('Your Proposal',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD4A843))),
                  ),
                ],
              ]),
              if (offer.priceRange != null) ...[
                const SizedBox(height: 3),
                Text(offer.priceRange!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight)),
              ],
              if (offer.duration != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 11, color: AppColors.textLight),
                  const SizedBox(width: 3),
                  Text(offer.duration!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                ]),
              ],
              // Lock hint for own proposals
              if (isOwnProposal) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 11, color: AppColors.textLight.withOpacity(0.7)),
                  const SizedBox(width: 3),
                  Text('Cannot be deselected',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight.withOpacity(0.7))),
                ]),
              ],
            ]),
          ),
          // Checkbox / loader
          if (loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary)),
            )
          else
            AnimatedContainer(
              duration: 200.ms,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        selected ? AppColors.primary : const Color(0xFFCCCCCC),
                    width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 52,
        height: 52,
        color: const Color(0xFFF0F4F2),
        child: const Icon(Icons.home_repair_service_rounded,
            color: AppColors.textLight, size: 24),
      );
}
