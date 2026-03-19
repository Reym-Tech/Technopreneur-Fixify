// lib/presentation/screens/professional/professional_tour_keys.dart
//
// First-time user tour for the Professional dashboard.
// Requires showcaseview ^4.0.0.
//
// Arrow alignment: TourCard receives [targetKey] and computes the accurate
// horizontal arrow offset via RenderBox.localToGlobal after the first frame.
// See _tour_shared.dart for implementation details.

import 'package:fixify/presentation/screens/shared/_tour_shared.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

// ── Singleton key holder ──────────────────────────────────────────────────────

class ProfessionalTourKeys {
  ProfessionalTourKeys._();
  static final ProfessionalTourKeys instance = ProfessionalTourKeys._();

  final GlobalKey availabilityKey =
      GlobalKey(debugLabel: 'pro_tour_availability');
  final GlobalKey notificationsKey =
      GlobalKey(debugLabel: 'pro_tour_notifications');
  final GlobalKey statsRowKey = GlobalKey(debugLabel: 'pro_tour_statsRow');
  final GlobalKey bookingRequestsKey =
      GlobalKey(debugLabel: 'pro_tour_bookingRequests');
  final GlobalKey bookingHistoryKey =
      GlobalKey(debugLabel: 'pro_tour_bookingHistory');
  final GlobalKey earningsSummaryKey =
      GlobalKey(debugLabel: 'pro_tour_earningsSummary');
  final GlobalKey myCredentialsKey =
      GlobalKey(debugLabel: 'pro_tour_myCredentials');
  final GlobalKey myServicesKey = GlobalKey(debugLabel: 'pro_tour_myServices');
  final GlobalKey myPlanKey = GlobalKey(debugLabel: 'pro_tour_myPlan');
  final GlobalKey requestsNavKey =
      GlobalKey(debugLabel: 'pro_tour_requestsNav');
  final GlobalKey earningsNavKey =
      GlobalKey(debugLabel: 'pro_tour_earningsNav');
  final GlobalKey profileNavKey = GlobalKey(debugLabel: 'pro_tour_profileNav');

  List<GlobalKey> orderedKeys() => [
        availabilityKey,
        notificationsKey,
        statsRowKey,
        bookingRequestsKey,
        bookingHistoryKey,
        earningsSummaryKey,
        myPlanKey,
        myCredentialsKey,
        myServicesKey,
        requestsNavKey,
        earningsNavKey,
        profileNavKey,
      ];
}

// ── Shared prefs key ──────────────────────────────────────────────────────────

const String kProfessionalTourSeenKey = 'professional_has_seen_tour';

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
  'availability': _TourStep(
    title: 'Availability',
    description: 'Toggle your status between Online and Offline. When Online, '
        'customers can find and book you. Switch Offline to pause new bookings.',
    arrowDir: TourArrowDir.up,
  ),
  'notifications': _TourStep(
    title: 'Notifications',
    description: 'Booking requests, schedule updates, and customer messages '
        'will appear here. A red dot indicates unread notifications.',
    arrowDir: TourArrowDir.up,
  ),
  'statsRow': _TourStep(
    title: 'Your Performance',
    description:
        'Track your total earnings, completed jobs, and completion rate '
        'at a glance. These update automatically after each job.',
    arrowDir: TourArrowDir.up,
  ),
  'bookingRequests': _TourStep(
    title: 'Booking Requests',
    description:
        'Open service requests from customers in your area appear here. '
        'Accept a request to claim the job before another handyman does.',
    arrowDir: TourArrowDir.up,
  ),
  'bookingHistory': _TourStep(
    title: 'Booking History',
    description: 'View all your active and past jobs. Tap any entry to see '
        'details, update status, or submit job completion proof.',
    arrowDir: TourArrowDir.up,
  ),
  'earningsSummary': _TourStep(
    title: 'Earnings Summary',
    description: 'See a full breakdown of your income by job. '
        'Track payments and monitor your earnings over time.',
    arrowDir: TourArrowDir.up,
  ),
  'myPlan': _TourStep(
    title: 'My Plan',
    description: 'View your current subscription tier and upgrade to '
        'AYO Pro or Elite for more job slots, priority matching, '
        'and featured placement.',
    arrowDir: TourArrowDir.up,
  ),
  'myCredentials': _TourStep(
    title: 'My Credentials',
    description: 'Submit your valid ID and trade certifications here to get '
        'verified. Verified handymen receive more bookings.',
    arrowDir: TourArrowDir.up,
  ),
  'myServices': _TourStep(
    title: 'My Services',
    description: 'Choose which services you offer to customers. '
        'Only the services you select will appear in your profile.',
    arrowDir: TourArrowDir.up,
  ),
  'requestsNav': _TourStep(
    title: 'Requests Tab',
    description: 'Quickly jump to your open booking requests from anywhere '
        'in the app using this tab.',
    arrowDir: TourArrowDir.down,
  ),
  'earningsNav': _TourStep(
    title: 'Earnings Tab',
    description: 'Access your full earnings history and payment records '
        'from this tab at any time.',
    arrowDir: TourArrowDir.down,
  ),
  'profileNav': _TourStep(
    title: 'Profile Tab',
    description: 'Update your personal information, manage account settings, '
        'and sign out from this section.',
    arrowDir: TourArrowDir.down,
  ),
};

// ── Showcase wrapper helper ───────────────────────────────────────────────────

class ProfessionalTourShowcase {
  ProfessionalTourShowcase._();

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
