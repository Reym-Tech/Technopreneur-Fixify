// lib/presentation/screens/professional/subscription_screen.dart
//
// Plans & Pricing screen for the Professional role.
//
// ARCHITECTURE — staged rollout:
//   Stage 1 (current): UI looks and feels like a real payment flow.
//   The handyman selects a plan → sees a checkout-style bottom sheet →
//   confirms → sends an upgrade request to admin. Admin activates the
//   plan manually (GCash / bank transfer). No real payment SDK needed yet.
//
//   Stage 2 (future): Replace _submitUpgradeRequest() with a PayMongo
//   payment link call. Everything else (UI, tiers, feature lists) stays.
//
// PROPS:
//   professional      → ProfessionalEntity?   current professional record
//   hasPendingUpgrade → bool                  suppresses CTA if request exists
//   onRequestUpgrade  → Future<void> Function(int targetTier)
//                        called after user confirms in the checkout sheet;
//                        parent saves the upgrade request to Supabase
//   onBack            → VoidCallback?

import 'package:flutter/material.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';

// ── Tier data ─────────────────────────────────────────────────────────────────

class _TierInfo {
  final String name;
  final String price; // display string e.g. "₱199"
  final String period; // e.g. "/month"
  final String tagline;
  final Color color;
  final IconData icon;
  final List<String> features;
  final List<String> notIncluded; // shown as greyed-out in lower tiers
  const _TierInfo({
    required this.name,
    required this.price,
    required this.period,
    required this.tagline,
    required this.color,
    required this.icon,
    required this.features,
    this.notIncluded = const [],
  });
}

const _tiers = [
  _TierInfo(
    name: 'Free',
    price: '₱0',
    period: '/month',
    tagline: 'Get started on AYO',
    color: Color(0xFF8E8E93),
    icon: Icons.person_outline_rounded,
    features: [
      'Listed in customer search',
      'Up to 2 active jobs at a time',
      'Receive ratings & reviews',
      'Basic profile page',
    ],
    notIncluded: [
      'Higher search ranking',
      'Priority job notifications',
      'Featured in customer home',
      'AYO badge on profile',
    ],
  ),
  _TierInfo(
    name: 'AYO Pro',
    price: '₱199',
    period: '/month',
    tagline: 'Grow your client base faster',
    color: Color(0xFF007AFF),
    icon: Icons.workspace_premium_rounded,
    features: [
      'Everything in Free',
      'Higher search ranking',
      'Up to 10 active jobs at a time',
      'Priority job notifications',
      'AYO Pro badge on profile',
      'Monthly performance insights',
    ],
    notIncluded: [
      'Top search placement',
      'Featured in customer home',
      'Unlimited active jobs',
    ],
  ),
  _TierInfo(
    name: 'AYO Elite',
    price: '₱399',
    period: '/month',
    tagline: 'Maximum visibility & income',
    color: Color(0xFFFF9500),
    icon: Icons.star_rounded,
    features: [
      'Everything in Pro',
      'Top placement in search results',
      'Unlimited active jobs',
      'Featured card on customer home',
      'Profile highlighted in listings',
      'AYO Elite badge on profile',
      'Priority customer support',
    ],
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SubscriptionScreen extends StatefulWidget {
  final ProfessionalEntity? professional;
  final bool hasPendingUpgrade;
  final Future<void> Function(int targetTier)? onRequestUpgrade;
  final VoidCallback? onBack;

  const SubscriptionScreen({
    super.key,
    this.professional,
    this.hasPendingUpgrade = false,
    this.onRequestUpgrade,
    this.onBack,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Which tier card is currently expanded / highlighted by the user.
  // Defaults to showing the current tier.
  late int _focusedTier;

  @override
  void initState() {
    super.initState();
    _focusedTier = (widget.professional?.subscriptionTier ?? 0).clamp(0, 2);
  }

  int get _currentTier =>
      (widget.professional?.subscriptionTier ?? 0).clamp(0, 2);

  bool get _hasPending => widget.hasPendingUpgrade;

  // ── Checkout sheet ─────────────────────────────────────────

  void _openCheckout(int targetTier) {
    final tier = _tiers[targetTier];
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),

              // ── Plan summary ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tier.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(tier.icon, color: tier.color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tier.name,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: tier.color)),
                          Text(tier.tagline,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textLight)),
                        ],
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Price row
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tier.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tier.color.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Subscription Total',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textLight)),
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: tier.price,
                                      style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: tier.color),
                                    ),
                                    TextSpan(
                                      text: tier.period,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: tier.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Monthly',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: tier.color)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Payment info note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7F4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Payment is processed via GCash or bank transfer. '
                              'After you confirm, our team will reach out within '
                              '24 hours to complete your upgrade.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMedium,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Buttons ───────────────────────────────
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('Cancel',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMedium)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: submitting
                              ? null
                              : () async {
                                  set(() => submitting = true);
                                  try {
                                    await widget.onRequestUpgrade
                                        ?.call(targetTier);
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text('Upgrade request sent! '
                                            'We\'ll activate ${tier.name} within 24 hours.'),
                                        backgroundColor: AppColors.primary,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ));
                                    }
                                  } catch (e) {
                                    set(() => submitting = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(SnackBar(
                                        content:
                                            Text('Could not send request: $e'),
                                        backgroundColor: AppColors.error,
                                      ));
                                    }
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: submitting
                                  ? tier.color.withOpacity(0.5)
                                  : tier.color,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: submitting
                                  ? []
                                  : [
                                      BoxShadow(
                                          color: tier.color.withOpacity(0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4)),
                                    ],
                            ),
                            child: Center(
                              child: submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                              Colors.white)))
                                  : const Text('Confirm & Request',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'No automatic charges — manual activation only.',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.textLight),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF0F3D2E),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF082218),
                      Color(0xFF0F3D2E),
                      Color(0xFF1A5C43)
                    ],
                  ),
                ),
                child: Stack(children: [
                  Positioned(
                    top: -20,
                    right: -10,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 48, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Plans & Pricing',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('Choose the plan that fits your goals',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Pending banner ───────────────────────────────────
          if (_hasPending)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFF9500).withOpacity(0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFFF9500), size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upgrade Request Pending',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF9500))),
                        SizedBox(height: 2),
                        Text(
                          'Your request is under review. '
                          'You\'ll be notified once activated.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMedium,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),

          // ── Tier cards ───────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _TierCard(
                  tier: _tiers[i],
                  tierIndex: i,
                  currentTier: _currentTier,
                  isFocused: _focusedTier == i,
                  hasPending: _hasPending,
                  onTap: () => setState(() => _focusedTier = i),
                  onUpgrade: i > _currentTier && !_hasPending
                      ? () => _openCheckout(i)
                      : null,
                ),
                childCount: _tiers.length,
              ),
            ),
          ),

          // ── FAQ footer ───────────────────────────────────────
          const SliverToBoxAdapter(child: _FaqSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Tier card ─────────────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final _TierInfo tier;
  final int tierIndex;
  final int currentTier;
  final bool isFocused;
  final bool hasPending;
  final VoidCallback onTap;
  final VoidCallback? onUpgrade;

  const _TierCard({
    required this.tier,
    required this.tierIndex,
    required this.currentTier,
    required this.isFocused,
    required this.hasPending,
    required this.onTap,
    this.onUpgrade,
  });

  bool get _isCurrent => tierIndex == currentTier;
  bool get _isUpgrade => tierIndex > currentTier;
  bool get _isDowngrade => tierIndex < currentTier;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isFocused
                ? tier.color.withOpacity(0.6)
                : tier.color.withOpacity(0.15),
            width: isFocused ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isFocused
                  ? tier.color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isFocused ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Card header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tier.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(tier.icon, color: tier.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(tier.name,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: tier.color)),
                          if (_isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tier.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Current Plan',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: tier.color)),
                            ),
                          ],
                          if (tierIndex == 2) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFF9500).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Most Popular',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFF9500))),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(tier.tagline,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: tier.price,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: tier.color),
                            ),
                          ],
                        ),
                      ),
                      Text(tier.period,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Feature list (shown when focused) ───────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: isFocused
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 16),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Column(
                  children: [
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 12),
                    ...tier.features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Icon(Icons.check_circle_rounded,
                                size: 15, color: tier.color),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(f,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textMedium,
                                        fontWeight: FontWeight.w500))),
                          ]),
                        )),
                    if (tier.notIncluded.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...tier.notIncluded.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              const Icon(Icons.remove_circle_outline_rounded,
                                  size: 15, color: Color(0xFFCCCCCC)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(f,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFFBBBBBB),
                                          fontWeight: FontWeight.w400))),
                            ]),
                          )),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),

            // ── CTA button ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: _buildCta(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta() {
    if (_isCurrent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: tier.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, color: tier.color, size: 16),
              const SizedBox(width: 6),
              Text('Active Plan',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tier.color)),
            ],
          ),
        ),
      );
    }

    if (_isDowngrade) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text('Lower tier',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLight)),
        ),
      );
    }

    // Upgrade
    if (hasPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9500).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
        ),
        child: const Center(
          child: Text('Request Pending',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF9500))),
        ),
      );
    }

    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: tier.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: tier.color.withOpacity(0.30),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Text('Upgrade to ${tier.name}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }
}

// ── FAQ section ───────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _faqs = [
    (
      q: 'How do I pay for my plan?',
      a: 'After you confirm your upgrade request, our team will contact you '
          'via the app or SMS to complete payment through GCash or bank transfer. '
          'Your plan is activated once payment is confirmed.'
    ),
    (
      q: 'When does my subscription renew?',
      a: 'Plans are billed monthly from the date your upgrade is activated. '
          'You\'ll receive a reminder 3 days before renewal.'
    ),
    (
      q: 'Can I downgrade or cancel?',
      a: 'Yes. You can cancel anytime by contacting support. Your current '
          'plan stays active until the end of the billing period.'
    ),
    (
      q: 'What happens when my plan expires?',
      a: 'Your account automatically returns to the Free tier. '
          'All your bookings and history remain intact.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Frequently Asked Questions',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => _FaqTile(q: faq.q, a: faq.a)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(widget.q,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
              ),
              Icon(
                _open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textLight,
                size: 20,
              ),
            ]),
            if (_open) ...[
              const SizedBox(height: 10),
              Text(widget.a,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium, height: 1.55)),
            ],
          ],
        ),
      ),
    );
  }
}
