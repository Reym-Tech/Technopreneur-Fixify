// lib/presentation/screens/customer/privacy_policy_screen.dart
//
// PrivacyPolicyScreen — Full-featured privacy policy screen for Fixify.
//
// Design: matches the existing dark green gradient system used throughout Fixify.
//
// Props:
//   onBack  → VoidCallback?   (defaults to Navigator.maybePop)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PrivacyPolicyScreen({super.key, this.onBack});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  int? _expandedIndex;

  static const _lastUpdated = 'March 9, 2026';

  static const _sections = [
    _PolicySection(
      icon: Icons.info_outline_rounded,
      title: '1. Information We Collect',
      content:
          'We collect information you provide directly to us when you create an account, '
          'request or provide services, or otherwise interact with our platform. This includes:\n\n'
          '• Full name, email address, phone number, and profile photo\n'
          '• Home or service address and location data (with your permission)\n'
          '• Payment information processed securely through our payment providers\n'
          '• Communications between you and service professionals\n'
          '• Ratings and reviews you submit\n\n'
          'We also automatically collect certain technical information when you use the app, '
          'such as device type, operating system, IP address, and usage logs.',
    ),
    _PolicySection(
      icon: Icons.settings_suggest_outlined,
      title: '2. How We Use Your Information',
      content: 'We use the information we collect to:\n\n'
          '• Create and manage your account\n'
          '• Match you with available service professionals\n'
          '• Process bookings and facilitate payments\n'
          '• Send booking confirmations, status updates, and service reminders\n'
          '• Resolve disputes and provide customer support\n'
          '• Improve and personalize your experience on the platform\n'
          '• Comply with legal obligations and enforce our Terms of Service\n\n'
          'We do not sell your personal information to third parties for their marketing purposes.',
    ),
    _PolicySection(
      icon: Icons.share_outlined,
      title: '3. Sharing of Information',
      content: 'We share your information only in limited circumstances:\n\n'
          '• With service professionals to fulfill your booking requests (name, address, contact details)\n'
          '• With payment processors to securely handle transactions\n'
          '• With service providers who assist us in operating the platform (hosting, analytics, support)\n'
          '• If required by law, court order, or government authority\n'
          '• In connection with a merger, acquisition, or sale of assets\n\n'
          'All third-party partners are contractually required to protect your information and use it only for permitted purposes.',
    ),
    _PolicySection(
      icon: Icons.my_location_rounded,
      title: '4. Location Data',
      content: 'Fixify requests access to your device\'s location to:\n\n'
          '• Show nearby available professionals\n'
          '• Enable accurate service address entry\n'
          '• Provide estimated arrival times\n\n'
          'Location access is requested only when you use location-related features. '
          'You can revoke location permissions at any time through your device settings, '
          'though this may limit some functionality. We do not share your precise location '
          'with third parties beyond what is needed to fulfill your service request.',
    ),
    _PolicySection(
      icon: Icons.lock_outline_rounded,
      title: '5. Data Security',
      content:
          'We implement industry-standard security measures to protect your personal information:\n\n'
          '• All data is transmitted over encrypted HTTPS connections\n'
          '• Passwords are hashed and never stored in plain text\n'
          '• Access to user data is restricted to authorized personnel only\n'
          '• We conduct regular security reviews and vulnerability assessments\n\n'
          'While we strive to protect your data, no method of transmission over the internet '
          'is 100% secure. We encourage you to use a strong, unique password for your account.',
    ),
    _PolicySection(
      icon: Icons.child_care_outlined,
      title: '6. Children\'s Privacy',
      content:
          'Fixify is not directed to individuals under the age of 18. We do not knowingly collect '
          'personal information from minors. If you are a parent or guardian and believe your child '
          'has provided us with personal information, please contact us immediately at '
          'privacy@fixify.ph and we will delete such information from our records.',
    ),
    _PolicySection(
      icon: Icons.tune_rounded,
      title: '7. Your Rights & Choices',
      content: 'You have the following rights regarding your personal data:\n\n'
          '• Access — request a copy of the data we hold about you\n'
          '• Correction — update or correct inaccurate information in your profile\n'
          '• Deletion — request deletion of your account and associated data\n'
          '• Portability — receive your data in a machine-readable format\n'
          '• Opt-out — unsubscribe from promotional notifications at any time\n\n'
          'To exercise any of these rights, please contact us at privacy@fixify.ph. '
          'We will respond within 30 days.',
    ),
    _PolicySection(
      icon: Icons.update_rounded,
      title: '8. Changes to This Policy',
      content:
          'We may update this Privacy Policy from time to time to reflect changes in our practices '
          'or for legal, operational, or regulatory reasons. When we make significant changes, '
          'we will notify you via in-app notification or email before the changes take effect.\n\n'
          'Continued use of Fixify after the effective date of any changes constitutes your '
          'acceptance of the revised policy. We encourage you to review this page periodically.',
    ),
    _PolicySection(
      icon: Icons.mail_outline_rounded,
      title: '9. Contact Us',
      content:
          'If you have any questions, concerns, or requests regarding this Privacy Policy or '
          'our data practices, please reach out to us:\n\n'
          '📧  privacy@fixify.ph\n'
          '📞  +63 917 123 4567\n'
          '🏢  Fixify Inc., Davao City, Philippines\n\n'
          'We are committed to resolving privacy-related concerns promptly and transparently.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildIntroCard()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  index == _sections.length - 1 ? 40 : 12,
                ),
                child: _buildSectionCard(index),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 80 * index))
                  .slideY(begin: 0.06, end: 0),
              childCount: _sections.length,
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(children: [
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap:
                        widget.onBack ?? () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const Text('Privacy Policy',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 40), // balance
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 2),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 14),
              const Text('Your Privacy Matters',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Last updated: $_lastUpdated',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: -0.04, end: 0);
  }

  // ── INTRO CARD ────────────────────────────────────────────

  Widget _buildIntroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'This policy explains how Fixify collects, uses, and protects your personal information. '
                'Tap any section below to read more.',
                style: TextStyle(
                    fontSize: 13.5, height: 1.55, color: AppColors.textMedium),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.06, end: 0),
    );
  }

  // ── SECTION CARD ──────────────────────────────────────────

  Widget _buildSectionCard(int index) {
    final section = _sections[index];
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded
                ? AppColors.primary.withOpacity(0.3)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpanded ? 0.08 : 0.05),
              blurRadius: isExpanded ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isExpanded
                      ? AppColors.primary.withOpacity(0.12)
                      : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon,
                    color: isExpanded ? AppColors.primary : AppColors.textLight,
                    size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(section.title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isExpanded
                            ? AppColors.primary
                            : AppColors.textDark)),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? AppColors.primary : AppColors.textLight,
                    size: 22),
              ),
            ]),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(children: [
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Text(
                  section.content,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    color: AppColors.textMedium,
                  ),
                ),
              ),
            ]),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    );
  }
}

// ── DATA MODEL ────────────────────────────────────────────

class _PolicySection {
  final IconData icon;
  final String title;
  final String content;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.content,
  });
}
