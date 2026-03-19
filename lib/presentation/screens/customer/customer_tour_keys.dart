// lib/presentation/screens/customer/customer_tour_keys.dart
//
// First-time user tour — GlobalKeys and tooltip definitions.
// Requires showcaseview ^4.0.0.
//
// Arrow alignment: TourCard receives [targetKey] and computes the accurate
// horizontal arrow offset via RenderBox.localToGlobal after the first frame.
// See _tour_shared.dart for implementation details.
//
// TOUR STRUCTURE:
//   • Dashboard tour  — runs once on first launch (kCustomerTourSeenKey).
//   • Explore tour    — runs once the first time the customer opens the
//                       Explore tab (kExploreTourSeenKey). Separate key so
//                       the two tours don't interfere and each can be
//                       replayed independently from the profile App Tour item.

import 'package:fixify/presentation/screens/shared/_tour_shared.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

// ── Singleton key holder ──────────────────────────────────────────────────────

class CustomerTourKeys {
  CustomerTourKeys._();
  static final CustomerTourKeys instance = CustomerTourKeys._();

  // ── Dashboard tour keys ───────────────────────────────────────────────────
  final GlobalKey requestServiceKey = GlobalKey();
  final GlobalKey serviceOffersKey = GlobalKey();
  final GlobalKey categoryFilterKey = GlobalKey();
  final GlobalKey exploreTabKey = GlobalKey();
  final GlobalKey notificationsKey = GlobalKey();
  final GlobalKey bookingsTabKey = GlobalKey();
  final GlobalKey profileTabKey = GlobalKey();
  final GlobalKey recentBookingsKey = GlobalKey();

  // ── Explore tour keys ─────────────────────────────────────────────────────
  final GlobalKey exploreSearchKey =
      GlobalKey(debugLabel: 'customer_tour_exploreSearch');
  final GlobalKey exploreSkillFilterKey =
      GlobalKey(debugLabel: 'customer_tour_exploreSkillFilter');

  List<GlobalKey> orderedKeys({bool hasRecentBookings = false}) => [
        requestServiceKey,
        serviceOffersKey,
        categoryFilterKey,
        exploreTabKey,
        notificationsKey,
        bookingsTabKey,
        profileTabKey,
        if (hasRecentBookings) recentBookingsKey,
      ];

  List<GlobalKey> exploreOrderedKeys() => [
        exploreSearchKey,
        exploreSkillFilterKey,
      ];
}

// ── Shared prefs keys ─────────────────────────────────────────────────────────

const String kCustomerTourSeenKey = 'customer_has_seen_tour';

/// Separate key for the Explore tab tour so it can be tracked and replayed
/// independently of the main dashboard tour.
const String kExploreTourSeenKey = 'customer_has_seen_explore_tour';

// ── Tour step content ─────────────────────────────────────────────────────────

class _TourStep {
  final String title;
  final String description;
  final TourArrowDir arrowDir;
  const _TourStep({
    required this.title,
    required this.description,
    required this.arrowDir,
  });
}

const _steps = <String, _TourStep>{
  // ── Dashboard steps ───────────────────────────────────────────────────────
  'requestService': _TourStep(
    title: 'Book a Service',
    description:
        'Tap here to request a verified handyman. Describe your problem '
        'and an available professional will be matched to your job.',
    arrowDir: TourArrowDir.up,
  ),
  'serviceOffers': _TourStep(
    title: 'Available Services',
    description: 'Browse services offered by professionals on the platform. '
        'Tap any card to view pricing, inclusions, and book directly.',
    arrowDir: TourArrowDir.up,
  ),
  'categoryFilter': _TourStep(
    title: 'Filter by Skills',
    description:
        'Narrow down services by skill — Plumber, Electrician, Carpenter, '
        'and more. Categories with no available professionals are marked.',
    arrowDir: TourArrowDir.up,
  ),
  'recentBookings': _TourStep(
    title: 'Recent Bookings',
    description: 'Your latest jobs are shown here for quick access. '
        'Tap a card to jump directly to its status screen.',
    arrowDir: TourArrowDir.up,
  ),
  'notifications': _TourStep(
    title: 'Notifications',
    description:
        'Booking updates, schedule proposals, and job completion alerts '
        'will appear here. A red dot indicates unread notifications.',
    arrowDir: TourArrowDir.up,
  ),
  'exploreTab': _TourStep(
    title: 'Explore Professionals',
    description: 'Browse and search all verified professionals in your area. '
        'Filter by skill, view profiles, reviews, and book directly.',
    arrowDir: TourArrowDir.down,
  ),
  'bookingsTab': _TourStep(
    title: 'My Bookings',
    description: 'View all your active and past bookings. Tap any entry to see '
        'the current status, scheduled time, and assigned professional.',
    arrowDir: TourArrowDir.down,
  ),
  'profileTab': _TourStep(
    title: 'Your Profile',
    description: 'Update your personal information, manage account settings, '
        'and sign out from this section.',
    arrowDir: TourArrowDir.down,
  ),

  // ── Explore tab steps ─────────────────────────────────────────────────────
  'exploreSearch': _TourStep(
    title: 'Search Professionals',
    description:
        'Search by name, skill, or city to find the right professional '
        'for your job. Results update as you type.',
    arrowDir: TourArrowDir.up,
  ),
  'exploreSkillFilter': _TourStep(
    title: 'Filter by Skill',
    description:
        'Tap a skill chip to narrow the list to professionals who offer '
        'that trade. Tap All to reset and see everyone.',
    arrowDir: TourArrowDir.up,
  ),
};

// ── Showcase wrapper helper ───────────────────────────────────────────────────

class CustomerTourShowcase {
  CustomerTourShowcase._();

  /// Wraps a visible target widget. [key] is passed to TourCard so the
  /// arrow can be aligned to the target's actual screen position.
  static Widget wrap({
    required GlobalKey key,
    required String stepName,
    required Widget child,
    required BuildContext showcaseContext,
    bool isLast = false,
    GlobalKey? innerKey,
  }) {
    final step = _steps[stepName];
    assert(step != null, 'No tour step defined for "$stepName"');

    // innerKey must be stable across builds — callers that rebuild frequently
    // (e.g. inside a StatefulWidget.build) should pass a pre-created key stored
    // in their State. If omitted a new key is created (fine for one-shot builds).
    final effectiveInnerKey = innerKey ?? GlobalKey();
    return Showcase.withWidget(
      key: key,
      overlayOpacity: 0.0,
      overlayColor: Colors.transparent,
      targetShapeBorder: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.transparent, width: 0),
      ),
      targetPadding: EdgeInsets.zero,
      height: 0,
      width: kTourCardWidth,
      disableMovingAnimation: true,
      container: TourCard(
        title: step!.title,
        description: step.description,
        isLast: isLast,
        arrowDir: step.arrowDir,
        showcaseContext: showcaseContext,
        innerKey: effectiveInnerKey,
      ),
      child: KeyedSubtree(key: effectiveInnerKey, child: child),
    );
  }

  /// Wraps a nav bar item directly so the package measures its real position
  /// and renders the tooltip above it.
  static Widget wrapAnchor({
    required GlobalKey key,
    required String stepName,
    required BuildContext showcaseContext,
    required Widget child,
    bool isLast = false,
    GlobalKey? innerKey,
  }) {
    final step = _steps[stepName];
    assert(step != null, 'No tour step defined for "$stepName"');

    final effectiveInnerKey = innerKey ?? GlobalKey();
    return Showcase.withWidget(
      key: key,
      overlayOpacity: 0.0,
      overlayColor: Colors.transparent,
      targetShapeBorder: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.transparent, width: 0),
      ),
      targetPadding: EdgeInsets.zero,
      height: 0,
      width: kTourCardWidth,
      disableMovingAnimation: true,
      container: TourCard(
        title: step!.title,
        description: step.description,
        isLast: isLast,
        arrowDir: step.arrowDir,
        showcaseContext: showcaseContext,
        innerKey: effectiveInnerKey,
      ),
      child: KeyedSubtree(key: effectiveInnerKey, child: child),
    );
  }
}
