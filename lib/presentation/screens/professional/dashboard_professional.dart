// lib/presentation/screens/professional/dashboard_professional.dart
//
// Changes from previous version:
//   1. Added `onRefresh` callback prop (Future<void> Function()?).
//   2. Wrapped CustomScrollView in a RefreshIndicator so pull-to-refresh works
//      with sliver-based layouts.
//   3. _fetchUnreadCount is also called on every pull-to-refresh cycle.
//   4. [FIX] Added `openRequestCount` prop. The pending banner and the
//      "Booking Requests" menu card badge now use this value instead of
//      _pendingCount (which counts pending items in assigned _bookings —
//      always 0 after a booking is claimed). This was causing stale
//      "2 New Requests" banners to persist even after all requests were handled.
//
// FIRST-TIME USER TOUR (new):
//   5. ShowCaseWidget wraps the entire Scaffold.
//   6. SharedPreferences key 'professional_has_seen_tour' guards one-time launch.
//   7. Tour scheduled inside ShowCaseWidget builder using builder context.
//   8. ProfessionalTourShowcase.wrap() used for visible targets;
//      wrapAnchor() used for bottom nav steps (TooltipPosition.top).

import 'dart:ui';
import 'package:fixify/data/datasources/notification_datasource.dart';
import 'package:fixify/presentation/screens/professional/notificationhandyman.dart';
import 'package:fixify/presentation/screens/professional/professional_tour_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfessionalDashboardScreen extends StatefulWidget {
  final UserEntity? user;
  final ProfessionalEntity? professional;
  final List<BookingEntity> bookings;

  /// Number of open (unassigned) booking requests visible to this professional.
  /// Sourced from _openRequests.length in main.dart — kept separate from
  /// [bookings] which only holds assigned/claimed jobs. Used for the pending
  /// banner and the "Booking Requests" menu card badge.
  final int openRequestCount;

  final int pendingApplications;
  final Function(BookingEntity, BookingStatus)? onUpdateStatus;
  final VoidCallback? onViewRequests;
  final VoidCallback? onViewHistory;
  final VoidCallback? onViewEarnings;
  final VoidCallback? onApplyCredentials;
  final VoidCallback? onViewVerification;
  final VoidCallback? onViewReviews;
  final VoidCallback? onManageServices;

  /// Called when the handyman taps "Share Profile".
  /// The controller builds the share link and triggers the share sheet.
  final VoidCallback? onShareProfile;

  /// Called when the handyman taps an upgrade CTA on the subscription card.
  /// In Stage 1 (manual flow) the controller shows a contact/request sheet.
  /// In Stage 2 (PayMongo) this triggers the payment link flow.
  final VoidCallback? onRequestUpgrade;

  /// True when the handyman already has a pending upgrade request awaiting
  /// admin review. Suppresses the upgrade button to prevent duplicate requests.
  final bool hasPendingUpgrade;
  final List<ReviewEntity> reviews;
  final Function(bool)? onToggleAvailability;
  final Function(int)? onNavTap;
  final int currentNavIndex;

  /// Called when the user pulls to refresh. Should re-fetch bookings, reviews,
  /// and professional record in the parent (_MainAppState) and call setState.
  final Future<void> Function()? onRefresh;

  const ProfessionalDashboardScreen({
    super.key,
    this.user,
    this.professional,
    this.bookings = const [],
    this.openRequestCount = 0,
    this.pendingApplications = 0,
    this.onUpdateStatus,
    this.onViewRequests,
    this.onViewHistory,
    this.onViewEarnings,
    this.onApplyCredentials,
    this.onViewVerification,
    this.onViewReviews,
    this.onManageServices,
    this.onShareProfile,
    this.onRequestUpgrade,
    this.hasPendingUpgrade = false,
    this.reviews = const [],
    this.onToggleAvailability,
    this.onNavTap,
    this.currentNavIndex = 0,
    this.onRefresh,
  });

  @override
  State<ProfessionalDashboardScreen> createState() =>
      _ProfessionalDashboardScreenState();
}

class _ProfessionalDashboardScreenState
    extends State<ProfessionalDashboardScreen> {
  bool _available = true;

  // ── Notification bell state ───────────────────────────────
  int _unreadNotifCount = 0;
  late final NotificationDataSource _notifDs;
  RealtimeChannel? _notifChannel;

  // ── Tour ──────────────────────────────────────────────────
  final _keys = ProfessionalTourKeys.instance;
  bool _tourScheduled = false;

  @override
  void initState() {
    super.initState();
    _available = widget.professional?.available ?? true;
    _notifDs = NotificationDataSource(Supabase.instance.client);
    _fetchUnreadCount();
    _subscribeToNotifications();
    // Tour is scheduled inside ShowCaseWidget's builder context — see build().
  }

  @override
  void dispose() {
    if (_notifChannel != null) _notifDs.unsubscribe(_notifChannel!);
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    final userId = widget.user?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      final count = await _notifDs.getUnreadCount(userId);
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (e) {
      debugPrint('[ProDashboard] Could not fetch unread count: $e');
    }
  }

  void _subscribeToNotifications() {
    final userId = widget.user?.id;
    if (userId == null || userId.isEmpty) return;
    _notifChannel = _notifDs.subscribeToNotifications(
      userId: userId,
      onNew: (_) => _fetchUnreadCount(),
    );
  }

  /// Triggered by the RefreshIndicator. Calls parent refresh then re-fetches
  /// the unread notification count so the bell badge stays in sync.
  Future<void> _handleRefresh() async {
    await widget.onRefresh?.call();
    await _fetchUnreadCount();
  }

  // ── Tour ──────────────────────────────────────────────────

  void _startTour(BuildContext showcaseContext) {
    ShowCaseWidget.of(showcaseContext).startShowCase(_keys.orderedKeys());
  }

  Future<void> _markTourSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kProfessionalTourSeenKey, true);
    } catch (e) {
      debugPrint('[ProTour] Could not write prefs: $e');
    }
  }

  // ── Derived stats ─────────────────────────────────────────

  int get _completedCount =>
      widget.bookings.where((b) => b.status == BookingStatus.completed).length;

  /// Returns the price that was actually agreed on for a booking.
  /// Prefers assessmentPrice (set by the professional during the job) and
  /// falls back to the customer's initial priceEstimate.
  /// Mirrors the identical helper in EarningsHandymanScreen.
  double _effectivePrice(BookingEntity b) {
    final ap = b.assessmentPrice;
    if (ap != null && ap > 0) return ap;
    return b.priceEstimate ?? 0.0;
  }

  double get _totalEarnings => widget.bookings
      .where((b) => b.status == BookingStatus.completed)
      .fold(0.0, (sum, b) => sum + _effectivePrice(b));

  double get _completionRate {
    final total = widget.bookings
        .where((b) =>
            b.status == BookingStatus.completed ||
            b.status == BookingStatus.cancelled)
        .length;
    if (total == 0) return 0;
    return (_completedCount / total) * 100;
  }

  double get _avgRating {
    if (widget.reviews.isNotEmpty) {
      final total = widget.reviews.fold<int>(0, (sum, r) => sum + r.rating);
      return total / widget.reviews.length;
    }
    return widget.professional?.rating ?? 0.0;
  }

  // Total jobs = completed bookings, regardless of how many have reviews.
  // Reviews are a subset of completed jobs — conflating the two causes the
  // stat chip to under-count whenever not every job has received a review.
  int get _totalJobs => _completedCount;

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: _markTourSeen,
      onComplete: (_, __) {},
      enableAutoScroll: true,
      builder: (showcaseContext) {
        if (!_tourScheduled) {
          _tourScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            try {
              final prefs = await SharedPreferences.getInstance();
              final seen = prefs.getBool(kProfessionalTourSeenKey) ?? false;
              if (!seen && mounted) {
                // Mark seen immediately so navigating away mid-tour never
                // causes the tour to replay when the user returns.
                await prefs.setBool(kProfessionalTourSeenKey, true);
                _startTour(showcaseContext);
              }
            } catch (e) {
              debugPrint('[ProTour] Could not read prefs: $e');
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          // ── Pull-to-refresh wraps the entire CustomScrollView ──────────
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.primary,
            backgroundColor: Colors.white,
            displacement: 60,
            child: CustomScrollView(
              // AlwaysScrollableScrollPhysics ensures RefreshIndicator fires even
              // when content is shorter than the viewport.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(showcaseContext)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    // TOUR STEP 3 — stats row
                    child: ProfessionalTourShowcase.wrap(
                      key: _keys.statsRowKey,
                      stepName: 'statsRow',
                      showcaseContext: showcaseContext,
                      child: _buildStatsRow(),
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
                ),
                // ── Subscription status card ──────────────────────────────────
                // Always visible — shows current tier and upgrade CTA for
                // Tier 0 and Tier 1 handymen, and plan details for Tier 2.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildSubscriptionCard(),
                  ).animate().fadeIn(delay: 170.ms),
                ),
                if (!(widget.professional?.verified ?? false))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildVerificationBanner(),
                    ).animate().fadeIn(delay: 180.ms),
                  ),
                // FIX: Use openRequestCount — this reflects actual open/unassigned
                // requests, not pending items in already-assigned bookings.
                if (widget.openRequestCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _buildPendingBanner(),
                    ).animate().fadeIn(delay: 200.ms),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildMenuCards(showcaseContext),
                  ).animate().fadeIn(delay: 250.ms),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: _buildRatingsCard(),
                  ).animate().fadeIn(delay: 320.ms),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(showcaseContext),
        );
      },
    );
  }

  // ── HEADER ────────────────────────────────────────────────

  Widget _buildHeader(BuildContext showcaseContext) {
    final name = widget.user?.name ?? 'Professional';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    final verified = widget.professional?.verified ?? false;

    final avatarUrl = widget.user?.avatarUrl;
    final ImageProvider? avatarImage =
        (avatarUrl != null && avatarUrl.isNotEmpty)
            ? NetworkImage(avatarUrl)
            : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 50,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3), width: 3),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.handyman_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('AYO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            )),
                      ]),
                      // Share + Bell row — TOUR STEP 2 wraps the bell only
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: widget.onShareProfile,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.share_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bell with dynamic red dot — TOUR STEP 2
                        ProfessionalTourShowcase.wrap(
                          key: _keys.notificationsKey,
                          stepName: 'notifications',
                          showcaseContext: showcaseContext,
                          child: IconButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HandymanNotificationsScreen(
                                    userId: widget.user?.id ?? '',
                                  ),
                                ),
                              );
                              _fetchUnreadCount();
                            },
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                if (_unreadNotifCount > 0)
                                  const Positioned(
                                    top: 7,
                                    right: 7,
                                    child: CircleAvatar(
                                      radius: 3.5,
                                      backgroundColor: Color(0xFFFF3B30),
                                    ),
                                  ),
                              ],
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ]), // end share + bell Row
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Pro info row
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34C759), Color(0xFF1A5C43)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: avatarImage != null
                            ? ClipOval(
                                child: Image(
                                  image: avatarImage,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      initials.isNotEmpty ? initials : 'P',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initials.isNotEmpty ? initials : 'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF34C759)
                                            .withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          color: Color(0xFF34C759), size: 11),
                                      SizedBox(width: 3),
                                      Text('Verified',
                                          style: TextStyle(
                                              color: Color(0xFF34C759),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              widget.professional?.skills.isNotEmpty == true
                                  ? widget.professional!.skills
                                      .map((s) =>
                                          s[0].toUpperCase() + s.substring(1))
                                      .join(' · ')
                                  : 'Handyman',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Availability toggle — TOUR STEP 1
                      ProfessionalTourShowcase.wrap(
                        key: _keys.availabilityKey,
                        stepName: 'availability',
                        showcaseContext: showcaseContext,
                        child: Column(
                          children: [
                            Switch(
                              value: _available,
                              onChanged: (v) {
                                setState(() => _available = v);
                                widget.onToggleAvailability?.call(v);
                              },
                              activeColor: AppColors.success,
                              activeTrackColor:
                                  AppColors.success.withOpacity(0.3),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.white.withOpacity(0.2),
                            ),
                            Text(
                              _available ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: _available
                                    ? AppColors.success
                                    : Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.04, end: 0);
  }

  // ── SUBSCRIPTION CARD ─────────────────────────────────────────────────────
  // Shows the handyman's current plan with included features and an upgrade CTA.
  // Tier 0 → upgrade to Pro. Tier 1 → upgrade to Elite. Tier 2 → shows badge.

  Widget _buildSubscriptionCard() {
    final pro = widget.professional;
    final tier = pro?.subscriptionTier ?? 0;
    final effectiveTier = (pro?.tierExpiresAt == null ||
            DateTime.now().isBefore(pro!.tierExpiresAt!))
        ? tier
        : 0;

    // Colors and labels per tier
    const tierColors = [
      Color(0xFF8E8E93), // Free — grey
      Color(0xFF007AFF), // Pro — blue
      Color(0xFFFF9500), // Elite — amber
    ];
    const tierLabels = ['Free', 'AYO Pro', 'AYO Elite'];
    const tierIcons = [
      Icons.person_outline_rounded,
      Icons.workspace_premium_rounded,
      Icons.star_rounded,
    ];

    final color = tierColors[effectiveTier.clamp(0, 2)];
    final label = tierLabels[effectiveTier.clamp(0, 2)];
    final icon = tierIcons[effectiveTier.clamp(0, 2)];

    // Feature lists per tier
    const tierFeatures = [
      ['Listed in search', 'Up to 2 active jobs', 'Receive ratings'],
      [
        'Higher search ranking',
        'Up to 10 active jobs',
        'Priority job notifications',
        'AYO Pro badge',
      ],
      [
        'Top search placement',
        'Unlimited active jobs',
        'Featured in customer home',
        'Profile highlighted',
        'AYO Elite badge',
      ],
    ];

    final features = tierFeatures[effectiveTier.clamp(0, 2)];
    final hasUpgrade = effectiveTier < 2;
    final nextLabel = effectiveTier == 0 ? 'AYO Pro' : 'AYO Elite';

    // Expiry notice
    String? expiryNote;
    if (effectiveTier > 0 && pro?.tierExpiresAt != null) {
      final days = pro!.tierExpiresAt!.difference(DateTime.now()).inDays;
      if (days <= 7) {
        expiryNote = days <= 0
            ? 'Your plan expired. Tap below to renew.'
            : 'Plan expires in $days day${days == 1 ? '' : 's'}.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Plan',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight)),
                  const SizedBox(height: 1),
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color)),
                ],
              ),
            ),
            // Active badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(effectiveTier == 0 ? 'Active' : 'Active',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),

          // ── Features list ────────────────────────────────────────────────
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                  const SizedBox(width: 8),
                  Text(f,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          fontWeight: FontWeight.w500)),
                ]),
              )),

          // ── Expiry warning ───────────────────────────────────────────────
          if (expiryNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFF3B30).withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: Color(0xFFFF3B30)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(expiryNote,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF3B30),
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ],

          // ── Upgrade CTA / Pending state ──────────────────────────────────
          if (hasUpgrade) ...[
            const SizedBox(height: 14),
            if (widget.hasPendingUpgrade)
              // Pending banner — request already submitted, awaiting admin
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFF9500).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 16, color: Color(0xFFFF9500)),
                  const SizedBox(width: 10),
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
                          'You will be notified when it is approved.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMedium,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ]),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onRequestUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Upgrade to $nextLabel',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Submit a request — admin will activate within 24 hours.',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(
          label: 'Earnings',
          value: '₱${_totalEarnings.toStringAsFixed(0)}',
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        const SizedBox(width: 12),
        _statCard(
          label: 'Total Jobs',
          value: '$_totalJobs',
          icon: Icons.work_rounded,
          color: AppColors.statusAccepted,
        ),
        const SizedBox(width: 12),
        _statCard(
          label: 'Completion',
          value: '${_completionRate.toStringAsFixed(0)}%',
          icon: Icons.check_circle_rounded,
          color: AppColors.statusInProgress,
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── VERIFICATION BANNER ───────────────────────────────────

  Widget _buildVerificationBanner() {
    final hasPending = widget.pendingApplications > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasPending
              ? [
                  const Color(0xFFFF9500).withOpacity(0.12),
                  const Color(0xFFFFCC00).withOpacity(0.08)
                ]
              : [
                  const Color(0xFF5856D6).withOpacity(0.10),
                  const Color(0xFF007AFF).withOpacity(0.06)
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPending
              ? const Color(0xFFFF9500).withOpacity(0.35)
              : const Color(0xFF5856D6).withOpacity(0.3),
        ),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color:
                (hasPending ? const Color(0xFFFF9500) : const Color(0xFF5856D6))
                    .withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            hasPending
                ? Icons.hourglass_top_rounded
                : Icons.workspace_premium_rounded,
            color:
                hasPending ? const Color(0xFFFF9500) : const Color(0xFF5856D6),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasPending
                    ? 'Application Under Review'
                    : 'Get Verified to Receive Bookings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hasPending
                      ? const Color(0xFFFF9500)
                      : const Color(0xFF5856D6),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hasPending
                    ? 'Your credentials are being reviewed by the admin (24–48 hrs).'
                    : 'Submit your credentials and valid ID to get approved.',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMedium),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: hasPending
              ? widget.onViewVerification
              : widget.onApplyCredentials,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: hasPending
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF5856D6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              hasPending ? 'Track' : 'Apply',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ]),
    );
  }

  // ── PENDING BANNER ────────────────────────────────────────
  // FIX: Uses widget.openRequestCount instead of the old _pendingCount.
  // _pendingCount counted BookingStatus.pending inside _bookings (assigned
  // jobs), which is always 0 after a booking is claimed. openRequestCount
  // reflects the actual number of unassigned open requests from _openRequests.

  Widget _buildPendingBanner() {
    final count = widget.openRequestCount;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFFF9500), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count New Request${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF9500))),
                  const Text('Respond before they book someone else',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onViewRequests,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('View',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ));
  }

  // ── MENU CARDS ────────────────────────────────────────────
  // FIX: "Booking Requests" badge now uses openRequestCount, not _pendingCount.

  Widget _buildMenuCards(BuildContext showcaseContext) {
    final openCount = widget.openRequestCount;
    return Column(
      children: [
        // TOUR STEP 4
        ProfessionalTourShowcase.wrap(
          key: _keys.bookingRequestsKey,
          stepName: 'bookingRequests',
          showcaseContext: showcaseContext,
          child: _menuCard(
            icon: Icons.calendar_month_rounded,
            iconColor: AppColors.statusAccepted,
            title: 'Booking Requests',
            subtitle: 'View and accept new service requests',
            badge: openCount > 0 ? '$openCount' : null,
            badgeColor: AppColors.error,
            onTap: widget.onViewRequests,
          ),
        ),
        const SizedBox(height: 12),
        // TOUR STEP 5
        ProfessionalTourShowcase.wrap(
          key: _keys.bookingHistoryKey,
          stepName: 'bookingHistory',
          showcaseContext: showcaseContext,
          child: _menuCard(
            icon: Icons.history_rounded,
            iconColor: AppColors.success,
            title: 'Booking History',
            subtitle: 'View your past and ongoing services',
            badge: widget.bookings
                    .where((b) => b.status == BookingStatus.inProgress)
                    .isNotEmpty
                ? 'Ongoing'
                : null,
            badgeColor: AppColors.statusAccepted,
            onTap: widget.onViewHistory,
          ),
        ),
        const SizedBox(height: 12),
        // TOUR STEP 6
        ProfessionalTourShowcase.wrap(
          key: _keys.earningsSummaryKey,
          stepName: 'earningsSummary',
          showcaseContext: showcaseContext,
          child: _menuCard(
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF00B8A9), // teal
            title: 'Earnings Summary',
            subtitle: 'Track what you have earned through AYO',
            onTap: widget.onViewEarnings,
          ),
        ),
        const SizedBox(height: 12),
        // TOUR STEP 7
        ProfessionalTourShowcase.wrap(
          key: _keys.myCredentialsKey,
          stepName: 'myCredentials',
          showcaseContext: showcaseContext,
          child: _menuCard(
            icon: Icons.workspace_premium_rounded,
            iconColor: AppColors.warning,
            title: 'My Credentials',
            subtitle: 'Submit credentials & track verification',
            badge: widget.pendingApplications > 0 ? 'Pending' : null,
            badgeColor: AppColors.warning,
            onTap: widget.onViewVerification,
          ),
        ),
        const SizedBox(height: 12),
        // TOUR STEP 8
        ProfessionalTourShowcase.wrap(
          key: _keys.myServicesKey,
          stepName: 'myServices',
          showcaseContext: showcaseContext,
          child: _menuCard(
            icon: Icons.home_repair_service_rounded,
            iconColor: AppColors.primary,
            title: 'My Services',
            subtitle: 'Select the services you offer to customers',
            onTap: widget.onManageServices,
          ),
        ),
      ],
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    String? badge,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    final iColor = iconColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor ?? AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  // ── RATINGS CARD ──────────────────────────────────────────

  Widget _buildRatingsCard() {
    final avg = _avgRating.clamp(0.0, 5.0);
    final total = widget.reviews.length;

    Map<int, double> realDistribution() {
      if (total == 0) return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (final r in widget.reviews) {
        final star = r.rating.clamp(1, 5);
        counts[star] = (counts[star] ?? 0) + 1;
      }
      return counts.map((star, count) => MapEntry(star, count / total));
    }

    final bars = realDistribution();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Reputation',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark),
              ),
              Row(children: [
                if (widget.onShareProfile != null)
                  GestureDetector(
                    onTap: widget.onShareProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share_rounded,
                              size: 12, color: AppColors.primary),
                          SizedBox(width: 5),
                          Text('Share',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                if (widget.onShareProfile != null &&
                    widget.onViewReviews != null)
                  const SizedBox(width: 8),
                if (widget.onViewReviews != null)
                  GestureDetector(
                    onTap: widget.onViewReviews,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
          const SizedBox(height: 20),
          if (total == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.star_outline_rounded,
                        size: 40, color: AppColors.textLight.withOpacity(0.4)),
                    const SizedBox(height: 10),
                    const Text('No reviews yet',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight)),
                    const SizedBox(height: 4),
                    const Text(
                      'Complete jobs through AYO to\nbuild your reputation.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF9500),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('out of 5',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: List.generate(5, (i) {
                      final star = 5 - i;
                      final pct = bars[star] ?? 0.0;
                      final count =
                          widget.reviews.where((r) => r.rating == star).length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('$star ★',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  backgroundColor: const Color(0xFFEEEEEE),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFF9500)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 18,
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textLight),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, color: Color(0xFFEEEEEE)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ratingStatItem(avg.toStringAsFixed(1), 'Avg Rating',
                    const Color(0xFFFF9500)),
                _ratingStatItem('$total', 'Reviews', AppColors.primary),
                _ratingStatItem('${_completionRate.toStringAsFixed(0)}%',
                    'Completion', const Color(0xFF34C759)),
              ],
            ),
            if (widget.reviews.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.format_quote_rounded,
                    color: AppColors.textLight, size: 16),
                const SizedBox(width: 6),
                const Text('Latest review',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight)),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < widget.reviews.first.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFFF9500),
                            size: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.reviews.first.customerName ?? 'Customer',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                    ]),
                    if (widget.reviews.first.comment?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${widget.reviews.first.comment}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _ratingStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  // ── BOTTOM NAV ────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext showcaseContext) {
    const items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Requests'},
      {'icon': Icons.monetization_on_rounded, 'label': 'Earnings'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = i == widget.currentNavIndex;
              final navItem = GestureDetector(
                onTap: () => widget.onNavTap?.call(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i]['icon'] as IconData,
                          color:
                              active ? AppColors.primary : AppColors.textLight,
                          size: 24),
                      const SizedBox(height: 4),
                      Text(items[i]['label'] as String,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w400,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textLight)),
                    ],
                  ),
                ),
              );
              // Wrap tour-relevant nav items directly on the actual widget
              // so the package measures real screen position and renders
              // the tooltip above the nav bar correctly.
              if (i == 1) {
                return ProfessionalTourShowcase.wrapAnchor(
                  key: _keys.requestsNavKey,
                  stepName: 'requestsNav',
                  showcaseContext: showcaseContext,
                  child: navItem,
                );
              }
              if (i == 2) {
                return ProfessionalTourShowcase.wrapAnchor(
                  key: _keys.earningsNavKey,
                  stepName: 'earningsNav',
                  showcaseContext: showcaseContext,
                  child: navItem,
                );
              }
              if (i == 3) {
                return ProfessionalTourShowcase.wrapAnchor(
                  key: _keys.profileNavKey,
                  stepName: 'profileNav',
                  showcaseContext: showcaseContext,
                  isLast: true,
                  child: navItem,
                );
              }
              return navItem;
            }),
          ),
        ),
      ),
    );
  }
}
