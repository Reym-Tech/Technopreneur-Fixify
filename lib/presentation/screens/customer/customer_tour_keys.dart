// lib/presentation/screens/customer/customer_tour_keys.dart
//
// First-time user tour — GlobalKeys and tooltip definitions.
// Requires showcaseview ^4.0.0.
//
// Arrow alignment: TourCard receives [targetKey] and computes the accurate
// horizontal arrow offset via RenderBox.localToGlobal after the first frame.
// See _tour_shared.dart for implementation details.

import 'package:fixify/presentation/screens/shared/_tour_shared.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

// ── Singleton key holder ──────────────────────────────────────────────────────

class CustomerTourKeys {
  CustomerTourKeys._();
  static final CustomerTourKeys instance = CustomerTourKeys._();

  final GlobalKey requestServiceKey = GlobalKey();
  final GlobalKey serviceOffersKey = GlobalKey();
  final GlobalKey categoryFilterKey = GlobalKey();
  final GlobalKey topProsKey = GlobalKey();
  final GlobalKey notificationsKey = GlobalKey();
  final GlobalKey bookingsTabKey = GlobalKey();
  final GlobalKey profileTabKey = GlobalKey();
  final GlobalKey recentBookingsKey = GlobalKey();

  List<GlobalKey> orderedKeys({bool hasRecentBookings = false}) => [
        requestServiceKey,
        serviceOffersKey,
        categoryFilterKey,
        topProsKey,
        notificationsKey,
        bookingsTabKey,
        profileTabKey,
        if (hasRecentBookings) recentBookingsKey,
      ];
}

// ── Shared prefs key ──────────────────────────────────────────────────────────

const String kCustomerTourSeenKey = 'customer_has_seen_tour';

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
  'topPros': _TourStep(
    title: 'Top Professionals',
    description: 'These are the highest-rated verified handymen in your area. '
        'Tap a card to view their profile, reviews, and book them directly.',
    arrowDir: TourArrowDir.up,
  ),
  'notifications': _TourStep(
    title: 'Notifications',
    description:
        'Booking updates, schedule proposals, and job completion alerts '
        'will appear here. A red dot indicates unread notifications.',
    arrowDir: TourArrowDir.up,
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
  'recentBookings': _TourStep(
    title: 'Recent Bookings',
    description: 'Your latest jobs are shown here for quick access. '
        'Tap a card to jump directly to its status screen.',
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
  }) {
    final step = _steps[stepName];
    assert(step != null, 'No tour step defined for "$stepName"');

    // innerKey is attached to the child widget directly so TourCard can
    // measure its actual screen position for accurate arrow alignment.
    final innerKey = GlobalKey();
    return Showcase.withWidget(
      key: key,
      overlayOpacity: 0.0,
      overlayColor: Colors.transparent,
      targetShapeBorder: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.transparent, width: 0),
      ),
      targetPadding: const EdgeInsets.all(6),
      height: 0,
      width: kTourCardWidth,
      disableMovingAnimation: true,
      container: TourCard(
        title: step!.title,
        description: step.description,
        isLast: isLast,
        arrowDir: step.arrowDir,
        showcaseContext: showcaseContext,
        innerKey: innerKey,
      ),
      child: KeyedSubtree(key: innerKey, child: child),
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
  }) {
    final step = _steps[stepName];
    assert(step != null, 'No tour step defined for "$stepName"');

    final innerKey = GlobalKey();
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
        innerKey: innerKey,
      ),
      child: KeyedSubtree(key: innerKey, child: child),
    );
  }
}
