// lib/main.dart
//
// OPEN-BOOKING MODEL:
//   Customer creates ONE booking with no professional assigned.
//   All matching pros see it as an open request.
//   First pro to accept claims it via claimBooking().
//   Customer's booking list always shows exactly one entry per request.
//
// KEY CHANGES from broadcast model:
//   • _init() professional branch: loads open requests via getOpenBookingRequests()
//     in addition to assigned bookings via getProfessionalBookings().
//     Subscribes to open requests realtime channel.
//   • onSubmit in RequestServiceScreen: creates exactly ONE booking (no loop).
//   • onAccept in BookingRequestsScreen: calls claimBooking() instead of
//     updateBookingStatus(). Handles BookingAlreadyClaimedException gracefully.
//   • _openRequests state list added for pros (separate from _bookings which
//     holds assigned/active bookings).
//   • Customer side: no sibling-cancellation logic needed — there is only
//     ever one booking per request now.
//   • _subscribeToBooking() retained for customer-side realtime status updates.
//   • _deduped() retained as a safety net.
//
// SCHEDULING UPDATE PATCH (applied):
//   • ScheduleReviewScreen imported.
//   • BookingStatusScreen gets onReviewSchedule callback.
//   • New 'schedule_review' case in _customerFlow().
//   • ProBookingDetailScreen gets onProposeSchedule and onProposeReschedule.
//   • _updateBookingInList() helper added.
//
// COMPLETION UPDATE PATCH (applied):
//   • Pro's onMarkComplete now calls markJobDoneByPro() (→ pending_customer_confirmation)
//     instead of directly setting status = completed.
//   • BookingStatusScreen receives onConfirmCompletion (customer confirms job done),
//     onLeaveReview (navigates to review screen), and hasReviewed.
//   • _handleCustomerConfirmCompletion() Controller helper added.
//
// REVIEW FIX:
//   • BookingStatusScreen now drives review navigation via onLeaveReview callback.
//   • hasReviewed is computed per-booking from _reviewedBookingIds.
//
// SCHEDULE UI SIMPLIFICATION:
//   • onProposeAlternative no longer passed to ScheduleReviewScreen (removed from UI).
//   • Parameter retained in ScheduleReviewScreen for API compat but unused.
//
// SUBSCRIPTION SCREEN (applied):
//   • SubscriptionScreen imported.
//   • _screen == 'my_plan' case added to _professionalFlow().
//   • ProfessionalDashboardScreen now receives onViewPlan instead of
//     onRequestUpgrade / hasPendingUpgrade. The old _handleRequestUpgrade()
//     bottom sheet in main.dart is replaced by the checkout sheet inside
//     SubscriptionScreen, keeping the controller lean.
//   • onRequestUpgrade on SubscriptionScreen calls _ds.submitUpgradeRequest()
//     directly with the targetTier chosen by the user in the pricing page.

// ── MVC SEPARATION NOTES ──────────────────────────────────────────────────
// MODEL  : BookingModel, UserModel, ProfessionalModel, etc. live in
//          data/models/ and domain/entities/. Data source calls (_ds, _appDs,
//          _notifDs) are the Model layer — they own DB interactions.
// VIEW   : All Screen widgets under presentation/screens/ are the View layer.
//          They receive data via constructor params and fire callbacks.
// CONTROLLER: _MainAppState is the Controller. It:
//             • Handles navigation (_screen, _navIndex) — request routing.
//             • Validates pre-conditions (null guards before routing).
//             • Orchestrates Model calls (_ds.*, _appDs.*, _notifDs.*).
//             • Updates View state via setState().
//             • Thin helper methods (_handleAcceptSchedule,
//               _handleDeclineSchedule, _handleProposeSchedule,
//               _handleProposeReschedule, _handleCustomerConfirmCompletion)
//               keep each callback focused.

import 'package:fixify/presentation/screens/admin/superadmin_analytics.dart';
import 'dart:math';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:fixify/presentation/screens/professional/earnings.dart';
import 'package:fixify/presentation/screens/professional/pro_booking_detail_screen.dart';
import 'package:fixify/presentation/screens/customer/schedule_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixify/core/constants/app_config.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/supabase_datasource.dart';
import 'package:fixify/data/datasources/application_datasource.dart';
import 'package:fixify/data/datasources/notification_datasource.dart';
import 'package:fixify/data/models/models.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/screens/shared/splash_screen.dart';
import 'package:fixify/presentation/screens/shared/onboarding_screen.dart';
import 'package:fixify/presentation/screens/auth/login_screen.dart';
import 'package:fixify/presentation/screens/auth/register_screen.dart';
import 'package:fixify/presentation/screens/customer/dashboard_customer.dart';
import 'package:fixify/presentation/screens/customer/profile_customer.dart';
import 'package:fixify/presentation/screens/customer/requestservice_customer.dart';
import 'package:fixify/presentation/screens/customer/bookings_customer.dart';
import 'package:fixify/presentation/screens/customer/professional_profile_screen.dart'
    as customer;
import 'package:fixify/presentation/screens/customer/all_professionals_screen.dart';
import 'package:fixify/presentation/screens/customer/booking_status_screen.dart';
import 'package:fixify/presentation/screens/customer/review_screen.dart';
import 'package:fixify/presentation/screens/customer/backjob_screen.dart';
import 'package:fixify/presentation/screens/customer/rebook_screen.dart';
import 'package:fixify/presentation/screens/customer/notifications.dart';
import 'package:fixify/presentation/screens/customer/assessment_screen.dart';
import 'package:fixify/presentation/screens/professional/dashboard_professional.dart';
import 'package:fixify/presentation/screens/professional/profile_professional.dart';
import 'package:fixify/presentation/screens/professional/apply_professional.dart';
import 'package:fixify/presentation/screens/professional/verificationstatus_professional.dart';
import 'package:fixify/presentation/screens/professional/booking_requests_professional.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixify/presentation/screens/professional/booking_history_professional.dart';
import 'package:fixify/presentation/screens/professional/reviews_professional.dart';
import 'package:fixify/presentation/screens/professional/notificationhandyman.dart';
import 'package:fixify/presentation/screens/admin/dashboard_admin.dart';
import 'package:fixify/presentation/screens/admin/profile_admin.dart';
import 'package:fixify/presentation/screens/admin/approvals_admin.dart';
import 'package:fixify/presentation/screens/admin/notificationsadmin.dart';
import 'package:fixify/presentation/screens/admin/admin_booking_overview_screen.dart';
import 'package:fixify/presentation/screens/admin/admin_catalogue_screen.dart';
import 'package:fixify/presentation/screens/professional/my_services_screen.dart';
import 'package:fixify/data/datasources/service_selection_request_datasource.dart';
import 'package:fixify/presentation/screens/professional/propose_service_screen.dart';
import 'package:fixify/presentation/screens/customer/privacy_policy_screen.dart';
import 'package:fixify/presentation/screens/professional/subscription_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
      url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const FixifyApp());
}

class FixifyApp extends StatelessWidget {
  const FixifyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'AYO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppNavigator());
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});
  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  bool _isLoggedIn = false;
  bool _initialCheckDone = false;

  /// Set to true when the guest taps "Sign Up" so AuthFlow opens on
  /// RegisterScreen instead of LoginScreen. Reset after use.
  bool _showRegisterFirst = false;

  /// Stable key so AuthFlow's internal state (_showRegister, _prefillEmail)
  /// survives AppNavigator rebuilds triggered by auth state changes.
  final _authFlowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final session = Supabase.instance.client.auth.currentSession;
    _isLoggedIn = session != null;
    _initialCheckDone = true;

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final loggedIn = data.session != null;
      if (_isLoggedIn != loggedIn) {
        setState(() => _isLoggedIn = loggedIn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
      );
    }
    if (_isLoggedIn)
      return MainApp(
        onSignUpFromGuest: () {
          setState(() => _showRegisterFirst = true);
        },
        onLoginFromGuest: () {
          setState(() => _showRegisterFirst = false);
        },
      );
    // Pass the flag to AuthFlow then immediately clear it so a subsequent
    // guest → "Log In" (or a new guest session) doesn't re-open RegisterScreen.
    final showRegister = _showRegisterFirst;
    if (_showRegisterFirst) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => setState(() => _showRegisterFirst = false));
    }
    return AuthFlow(
      key: _authFlowKey,
      showRegisterFirst: showRegister,
    );
  }
}

// ── AUTH ──────────────────────────────────────────────

class AuthFlow extends StatefulWidget {
  /// When true, opens RegisterScreen immediately instead of LoginScreen.
  /// Used when the guest taps "Sign Up" from the booking prompt.
  final bool showRegisterFirst;

  const AuthFlow({super.key, this.showRegisterFirst = false});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showSplash = true;
  late bool _showRegister;
  String? _prefillEmail;

  // null = not yet loaded from prefs; true/false = loaded
  bool? _hasSeenOnboarding;

  static const _onboardingKey = 'has_seen_onboarding';

  @override
  void initState() {
    super.initState();
    _showRegister = widget.showRegisterFirst;
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      // Load the onboarding flag while the splash is still showing
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_onboardingKey) ?? false;
      if (mounted) {
        setState(() {
          _hasSeenOnboarding = seen;
          _showSplash = false;
        });
      }
    });
  }

  Future<void> _markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (mounted) setState(() => _hasSeenOnboarding = true);
  }

  /// Called externally (via GlobalKey) when the guest taps "Sign Up".
  void _goToRegister() {
    if (mounted) setState(() => _showRegister = true);
  }

  @override
  Widget build(BuildContext context) {
    // Show splash until both the delay AND the prefs read are done
    if (_showSplash || _hasSeenOnboarding == null) return SplashScreen();

    // First-time user — show onboarding slides
    if (!_hasSeenOnboarding!) {
      return OnboardingScreen(
        onDone: () async {
          await _markOnboardingDone();
          // onboarding → login (state update above triggers rebuild)
        },
      );
    }

    // Show login/register flow
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showRegister) {
          setState(() {
            _showRegister = false;
            _prefillEmail = null;
          });
        }
        // On LoginScreen: swallow the back press — nowhere to go back to
      },
      child: _showRegister
          ? RegisterScreen(
              onNavigateToLogin: () => setState(() {
                _showRegister = false;
                _prefillEmail = null;
              }),
              onSuccess: (email) => setState(() {
                _showRegister = false;
                _prefillEmail = email;
              }),
            )
          : LoginScreen(
              onNavigateToRegister: () => setState(() {
                _showRegister = true;
                _prefillEmail = null;
              }),
              initialEmail: _prefillEmail,
              onLogin: (email, password) async {
                debugPrint('🔐 Attempting login for: $email');
                await Supabase.instance.client.auth
                    .signInWithPassword(email: email, password: password);
                debugPrint('✅ Login successful');
              },
              onContinueAsGuest: () async {
                debugPrint('👤 Signing in anonymously as guest');
                try {
                  await Supabase.instance.client.auth.signInAnonymously();
                  debugPrint('✅ Anonymous sign-in successful');
                } catch (e) {
                  debugPrint('❌ Anonymous sign-in failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                            'Guest browsing is currently unavailable. Please sign in.'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                }
              },
            ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  final String message;
  const _LoadingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.4),
      child: Center(
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark)),
        ]),
      )),
    );
  }
}

// ── MAIN APP ──────────────────────────────────────────────

class MainApp extends StatefulWidget {
  /// Called when the guest taps "Sign Up" from the booking prompt.
  /// Tells AppNavigator to open RegisterScreen when the anonymous session ends.
  final VoidCallback? onSignUpFromGuest;

  /// Called when the guest taps "Log In" from the booking prompt.
  /// Ensures AppNavigator opens LoginScreen (not RegisterScreen).
  final VoidCallback? onLoginFromGuest;
  const MainApp({super.key, this.onSignUpFromGuest, this.onLoginFromGuest});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // ── MODEL layer references ────────────────────────────────────────────────
  // These data sources encapsulate all DB/API interactions (Model layer).
  late final SupabaseDataSource _ds;
  late final ApplicationDataSource _appDs;
  late final NotificationDataSource _notifDs;
  late final ServiceProposalDatasource _proposalDs;
  late final ServiceSelectionRequestDatasource _selectionDs;

  // ── Controller state ──────────────────────────────────────────────────────
  DateTime? _lastBackPress;
  String? _preselectedServiceType;
  String? _preselectedProblemTitle;
  String? _preselectedDescription;

  /// Professional IDs who have selected the currently preselected service.
  /// Empty = no filter (show all matching professionals).
  /// Populated before navigating to request_service so matchedPros is exact.
  Set<String> _qualifiedProfessionalIds = {};

  /// Services offered by a specific professional for direct booking.
  /// Empty = not a direct booking (show all services for the skill type).
  List<ServiceOfferModel> _directBookingOffers = [];

  /// True when the current Supabase session is anonymous (guest browsing).
  /// Guests see the customer dashboard but cannot book — restricted actions
  /// show a sign-up prompt instead.
  bool _isGuest = false;

  // ── Model state (data held by Controller for View consumption) ────────────
  UserModel? _user;
  ProfessionalModel? _pro;
  List<ProfessionalModel> _professionals = [];
  List<BookingModel> _bookings = [];

  // Open (unassigned) booking requests visible to this professional.
  List<BookingModel> _openRequests = [];

  /// All platform bookings — loaded for the admin flow only.
  List<BookingModel> _adminBookings = [];

  /// IDs of service_proposals this professional has selected to offer.
  Set<String> _myServiceIds = {};

  /// All service selection requests — populated for admin (all requests)
  /// and for professionals (their own pending requests only).
  List<ServiceSelectionRequestModel> _serviceSelectionRequests = [];

  /// For the professional flow: maps serviceOfferId → action ('select'|'deselect')
  /// for requests currently pending admin approval.
  /// Drives the pending-state indicators in MyServicesScreen.
  Map<String, String> _pendingServiceRequestMap = {};

  // MODEL — per-professional skip persistence key.
  // Scoped to the professional's ID so that different handymen on the same
  // device maintain completely separate skip lists.
  // The key is initialised lazily in _loadSkippedRequests() once _pro is known.
  String get _prefsSkippedKey => 'skipped_bookings_${_pro?.id ?? 'unknown'}';
  Set<String> _skippedRequestIds = {};

  List<ApplicationModel> _applications = [];
  List<ServiceProposalModel> _proposals =
      []; // admin: all proposals; pro: own proposals
  List<SubscriptionRequestModel> _upgradeRequests = [];
  List<ServiceOfferModel> _serviceOffers =
      []; // customer: approved proposals as offers
  List<ReviewModel> _reviews = [];
  int _navIndex = 0;
  String _screen = 'home';
  // Tracks which screen navigated to 'professional_profile' so the back
  // button returns to the correct destination ('home' or 'explore').
  String _profileReturnScreen = 'home';
  ProfessionalModel? _selectedPro;
  List<ReviewModel> _proReviews = [];
  int _unreadNotifCount = 0;
  ProfessionalModel? _selectedProFresh;

  final Set<String> _reviewedBookingIds = {};
  BookingModel? _selectedBooking;
  BookingEntity? _selectedProBooking;

  bool _loading = true;

  RealtimeChannel? _professionalsChannel;
  RealtimeChannel? _openRequestsChannel;
  RealtimeChannel? _selectedProBookingChannel;
  RealtimeChannel? _proActiveBookingChannel;
  String? _selectedProBookingId;

  // ══════════════════════════════════════════════════════════════════════════
  // MODEL HELPERS — deduplication & realtime subscriptions
  // ══════════════════════════════════════════════════════════════════════════

  // Deduplication helper — safety net for list integrity (Model concern).
  List<BookingModel> _deduped(List<BookingModel> list) {
    final seen = <String>{};
    final result = <BookingModel>[];
    for (final b in list.reversed) {
      if (seen.add(b.id)) result.add(b);
    }
    return result.reversed.toList();
  }

  // Replaces a booking in _bookings by id (Model state mutation).
  void _updateBookingInList(BookingModel updated) {
    final idx = _bookings.indexWhere((b) => b.id == updated.id);
    if (idx != -1) {
      final list = List<BookingModel>.from(_bookings);
      list[idx] = updated;
      _bookings = list;
    }
  }

  // Customer-side realtime subscription for a single booking.
  void _subscribeToBooking(BookingModel booking) {
    _ds.subscribeToBookingUpdates(
      bookingId: booking.id,
      onUpdate: (updated) {
        if (!mounted) return;
        setState(() {
          if (_selectedBooking?.id == updated.id) {
            _selectedBooking = updated;
          }
          _bookings = _deduped(
              _bookings.map((b) => b.id == updated.id ? updated : b).toList());
        });
      },
    );
  }

  // Professional-side realtime subscription for a single booking (detail view).
  void _subscribeToProBooking(BookingEntity booking) {
    if (_selectedProBookingId == booking.id &&
        _selectedProBookingChannel != null) {
      return;
    }
    if (_selectedProBookingChannel != null) {
      _ds.unsubscribeChannel(_selectedProBookingChannel!);
    }
    _selectedProBookingId = booking.id;
    _selectedProBookingChannel = _ds.subscribeToBookingUpdates(
      bookingId: booking.id,
      onUpdate: (updated) {
        if (!mounted) return;
        setState(() {
          final hasBooking = _bookings.any((b) => b.id == updated.id);
          final updatedList = hasBooking
              ? _bookings.map((b) => b.id == updated.id ? updated : b).toList()
              : [updated, ..._bookings];
          _bookings = _deduped(updatedList);
          if (_selectedProBooking?.id == updated.id) {
            _selectedProBooking = updated.toEntity();
          }
        });
      },
    );
  }

  void _subscribeToProActiveBooking(String bookingId) {
    if (_proActiveBookingChannel != null) {
      _ds.unsubscribeChannel(_proActiveBookingChannel!);
      _proActiveBookingChannel = null;
    }
    _proActiveBookingChannel = _ds.subscribeToProfessionalActiveBooking(
      bookingId: bookingId,
      onUpdate: (updated) {
        if (mounted) {
          setState(() {
            _selectedProBooking = updated.toEntity();
            _updateBookingInList(updated);
          });
        }
      },
    );
  }

  void _unsubscribeFromProActiveBooking() {
    if (_proActiveBookingChannel != null) {
      _ds.unsubscribeChannel(_proActiveBookingChannel!);
      _proActiveBookingChannel = null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLLER — schedule action handlers
  // Each method: validates → calls Model (_ds) → updates View (setState).
  // ══════════════════════════════════════════════════════════════════════════

  /// Customer accepts the professional's proposed schedule.
  Future<void> _handleAcceptSchedule() async {
    if (_selectedBooking == null) return;
    try {
      final updated = await _ds.respondToSchedule(
        bookingId: _selectedBooking!.id,
        accepted: true,
      );
      _updateBookingInList(updated);
      setState(() {
        _selectedBooking = updated;
        _screen = 'booking_status';
      });
      final proUserId = updated.professional?.userId;
      if (proUserId != null) {
        await _notifDs.pushToUser(
          targetUserId: proUserId,
          role: 'professional',
          type: NotificationTypeStrings.bookingAccepted,
          title: 'Schedule Confirmed',
          message:
              '${_user?.name ?? 'The customer'} has confirmed your proposed schedule.',
          referenceId: updated.id,
          referenceType: 'booking',
        );
      }
    } catch (e) {
      _notify('Failed to confirm schedule: $e');
    }
  }

  /// Customer declines the professional's proposed schedule.
  Future<void> _handleDeclineSchedule() async {
    if (_selectedBooking == null) return;
    try {
      final updated = await _ds.respondToSchedule(
        bookingId: _selectedBooking!.id,
        accepted: false,
      );
      _updateBookingInList(updated);
      setState(() {
        _selectedBooking = updated;
        _screen = 'booking_status';
      });
      final proUserId = updated.professional?.userId;
      if (proUserId != null) {
        await _notifDs.pushToUser(
          targetUserId: proUserId,
          role: 'professional',
          type: NotificationTypeStrings.bookingCancelled,
          title: 'Schedule Declined',
          message:
              '${_user?.name ?? 'The customer'} has declined your proposed schedule.',
          referenceId: updated.id,
          referenceType: 'booking',
        );
      }
    } catch (e) {
      _notify('Failed to decline schedule: $e');
    }
  }

  /// Handyman confirms the customer's own preferred time.
  /// Calls _ds.confirmSchedule() → status = scheduled directly.
  Future<void> _handleConfirmSchedule(DateTime confirmedTime) async {
    if (_selectedProBooking == null) return;
    try {
      final updated = await _ds.confirmSchedule(
        bookingId: _selectedProBooking!.id,
        confirmedTime: confirmedTime,
      );
      _updateBookingInList(updated);
      setState(() => _selectedProBooking = updated.toEntity());
      await _notifDs.pushToUser(
        targetUserId: updated.customerId,
        role: 'customer',
        type: NotificationTypeStrings.bookingAccepted,
        title: 'Booking Confirmed',
        message:
            '${_pro?.name ?? 'Your handyman'} has confirmed your ${updated.serviceType} booking for your preferred time.',
        referenceId: updated.id,
        referenceType: 'booking',
      );
    } catch (e) {
      _notify('Failed to confirm schedule: $e');
    }
  }

  /// Handyman taps "I've Arrived" on-site.
  /// Transitions status: scheduled → pendingArrivalConfirmation.
  /// Customer is notified and must confirm arrival before price-setting unlocks.
  Future<void> _handleStartAssessment() async {
    if (_selectedProBooking == null) return;
    try {
      final updated = await _ds.markHandymanArrived(_selectedProBooking!.id);
      _updateBookingInList(updated);
      setState(() => _selectedProBooking = updated.toEntity());
      await _notifDs.pushToUser(
        targetUserId: updated.customerId,
        role: 'customer',
        type: NotificationTypeStrings.bookingAccepted,
        title: 'Your Handyman Has Arrived',
        message:
            '${_pro?.name ?? 'Your handyman'} is at your location. Please confirm their arrival in the app.',
        referenceId: updated.id,
        referenceType: 'booking',
      );
    } catch (e) {
      _notify('Failed to mark arrival: $e');
    }
  }

  /// Customer confirms the handyman has arrived.
  /// Transitions status: pendingArrivalConfirmation → assessment.
  /// Price-setting tools unlock for the handyman.
  Future<void> _handleConfirmArrival() async {
    if (_selectedBooking == null) return;
    try {
      final updated = await _ds.confirmHandymanArrival(_selectedBooking!.id);
      _updateBookingInList(updated);
      setState(() {
        _selectedBooking = updated;
        _screen = 'booking_status';
      });
      _notify('Arrival confirmed. Your handyman will now assess the job.');
      final proUserId = updated.professional?.userId;
      if (proUserId != null) {
        await _notifDs.pushToUser(
          targetUserId: proUserId,
          role: 'professional',
          type: NotificationTypeStrings.bookingAccepted,
          title: 'Arrival Confirmed',
          message:
              '${_user?.name ?? 'The customer'} confirmed your arrival. You can now set the assessment price.',
          referenceId: updated.id,
          referenceType: 'booking',
        );
      }
    } catch (e) {
      _notify('Failed to confirm arrival: $e');
    }
  }

  /// Professional proposes an initial schedule for a booking.
  /// Retained for compat — no longer the primary path (use _handleConfirmSchedule).
  Future<void> _handleProposeSchedule(DateTime proposedTime) async {
    if (_selectedProBooking == null) return;
    try {
      final updated = await _ds.proposeSchedule(
        bookingId: _selectedProBooking!.id,
        proposedTime: proposedTime,
      );
      _updateBookingInList(updated);
      setState(() => _selectedProBooking = updated.toEntity());
      await _notifDs.pushToUser(
        targetUserId: updated.customerId,
        role: 'customer',
        type: NotificationTypeStrings.bookingRequest,
        title: 'Schedule Proposed',
        message:
            '${_pro?.name ?? 'Your handyman'} has proposed a start time for your ${updated.serviceType} booking.',
        referenceId: updated.id,
        referenceType: 'booking',
      );
    } catch (e) {
      _notify('Failed to propose schedule: $e');
    }
  }

  /// Professional proposes a reschedule with an optional reason.
  /// Validation (past-time guard) is enforced in SupabaseDataSource.proposeReschedule().
  Future<void> _handleProposeReschedule(
      DateTime newTime, String? reason) async {
    if (_selectedProBooking == null) return;
    try {
      final updated = await _ds.proposeReschedule(
        bookingId: _selectedProBooking!.id,
        newProposedTime: newTime,
        reason: reason,
      );
      _updateBookingInList(updated);
      setState(() => _selectedProBooking = updated.toEntity());
      await _notifDs.pushToUser(
        targetUserId: updated.customerId,
        role: 'customer',
        type: NotificationTypeStrings.bookingRequest,
        title: 'Reschedule Request',
        message:
            '${_pro?.name ?? 'Your handyman'} has requested a new time for your booking.',
        referenceId: updated.id,
        referenceType: 'booking',
      );
    } catch (e) {
      _notify('Failed to propose reschedule: $e');
    }
  }

  /// Professional is running late — updates ETA without changing booking status.
  /// Customer is notified; no accept/decline required.
  Future<void> _handleNotifyRunningLate(DateTime newEta, String? reason) async {
    if (_selectedProBooking == null) return;
    try {
      final updated = await _ds.notifyRunningLate(
        bookingId: _selectedProBooking!.id,
        newEta: newEta,
        reason: reason,
      );
      _updateBookingInList(updated);
      setState(() => _selectedProBooking = updated.toEntity());
      await _notifDs.pushToUser(
        targetUserId: updated.customerId,
        role: 'customer',
        type: NotificationTypeStrings.bookingRequest,
        title: 'Handyman Running Late',
        message:
            '${_pro?.name ?? 'Your handyman'} is running late and will arrive at '
            '${updated.scheduledTime != null ? _fmtTime(updated.scheduledTime!) : 'a new time'}.'
            '${reason != null && reason.isNotEmpty ? ' Reason: $reason' : ''}',
        referenceId: updated.id,
        referenceType: 'booking',
      );
      _notify('Customer has been notified of your new ETA.');
    } catch (e) {
      _notify('Failed to update ETA: $e');
    }
  }

  /// Customer confirms that the professional has completed the job.
  /// Transitions status: pendingCustomerConfirmation → completed.
  /// Also writes warranty_expires_at when the service has warrantyDays > 0.
  Future<void> _handleCustomerConfirmCompletion() async {
    if (_selectedBooking == null) return;
    try {
      // Look up warrantyDays from the matching service offer so we can
      // write warranty_expires_at to the bookings row on completion.
      int warrantyDays = 0;
      try {
        final serviceTitle = _selectedBooking!.serviceTitle;
        final serviceType = _selectedBooking!.serviceType;
        if (serviceTitle != null && serviceTitle.isNotEmpty) {
          final match = _serviceOffers.firstWhereOrNull((o) =>
              o.serviceName.toLowerCase() == serviceTitle.toLowerCase() &&
              o.serviceType.toLowerCase() == serviceType.toLowerCase());
          warrantyDays = match?.warrantyDays ?? 0;
        }
      } catch (e) {
        debugPrint('[Backjob] Could not look up warrantyDays: $e');
      }

      // Model: persist completion confirmation + warranty expiry.
      final updated = await _ds.customerConfirmCompletion(
        _selectedBooking!.id,
        warrantyDays: warrantyDays,
      );
      // Model: keep local list consistent.
      _updateBookingInList(updated);
      // View: reflect updated status.
      setState(() {
        _selectedBooking = updated;
        _screen = 'booking_status';
      });
      _notify('Job confirmed as complete. Thank you for using AYO.');
      // Model: notify the professional.
      final proUserId = updated.professional?.userId;
      if (proUserId != null) {
        await _notifDs.pushToUser(
          targetUserId: proUserId,
          role: 'professional',
          type: NotificationTypeStrings.bookingAccepted,
          title: 'Job Confirmed Complete',
          message:
              '${_user?.name ?? 'The customer'} has confirmed your job is done.',
          referenceId: updated.id,
          referenceType: 'booking',
        );
      }
    } catch (e) {
      _notify('Failed to confirm completion: $e');
    }
  }

  // ── REBOOK ────────────────────────────────────────────────────────────────

  /// Navigates to RebookScreen with the completed booking pre-filled.
  /// Called from BookingStatusScreen.onBookAgain.
  void _navigateToRebook(BookingEntity booking) {
    final model = _bookings.firstWhereOrNull((b) => b.id == booking.id);
    if (model == null) return;
    setState(() {
      _selectedBooking = model;
      _screen = 'rebook';
    });
  }

  /// Controller: creates a new booking from RebookConfirmData (pre-filled
  /// from the original completed booking), notifies the same professional,
  /// and navigates to the new booking's status screen.
  Future<void> _handleRebookConfirm(RebookConfirmData data) async {
    if (_user == null) return;
    try {
      final booking = await _ds.createBooking(
        customerId: data.customerId,
        professionalId: data.professionalId,
        serviceType: data.serviceType,
        serviceTitle: data.serviceTitle,
        scheduledDate: data.preferredDate,
        address: data.address,
        priceEstimate: data.priceEstimate,
        latitude: data.latitude,
        longitude: data.longitude,
      );

      _subscribeToBooking(booking);
      await _refreshBookings();

      // Notify the same professional — direct booking so they see it
      // immediately as an assigned request, not an open broadcast.
      if (data.professionalId != null) {
        try {
          final pro = _professionals
              .firstWhereOrNull((p) => p.id == data.professionalId);
          if (pro != null) {
            await _notifDs.pushToUser(
              targetUserId: pro.userId,
              role: 'professional',
              type: NotificationTypeStrings.bookingRequest,
              title: 'Repeat Booking Request',
              message: '${_user?.name ?? 'A customer'} has booked you again '
                  'for "${data.serviceTitle ?? data.serviceType}". '
                  'Please confirm the schedule.',
              referenceId: booking.id,
              referenceType: 'booking',
            );
          }
        } catch (e) {
          debugPrint('[Rebook] Could not notify professional: $e');
        }
      }

      final created =
          _bookings.firstWhereOrNull((b) => b.id == booking.id) ?? booking;
      if (mounted) {
        setState(() {
          _selectedBooking = created;
          _screen = 'booking_status';
        });
      }
      _notify('Booking confirmed. Your handyman has been notified.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── BACKJOB / WARRANTY ────────────────────────────────────────────────────

  /// Navigates to BackjobScreen for the currently selected completed booking.
  /// Called from BookingStatusScreen.onBackjob and
  /// CustomerBookingsScreen.onBackjob.
  void _navigateToBackjob(BookingEntity booking) {
    final model = _bookings.firstWhereOrNull((b) => b.id == booking.id);
    if (model == null) return;
    setState(() {
      _selectedBooking = model;
      _screen = 'backjob';
    });
  }

  /// Controller: submits a warranty backjob booking via the datasource,
  /// notifies the professional with a 24-hour confirmation request,
  /// and navigates to the new booking's status screen.
  Future<void> _handleBackjobSubmit(BackjobSubmitData data) async {
    if (_user == null) return;
    try {
      final booking = await _ds.createBackjobBooking(
        customerId: _user!.id,
        originalBookingId: data.originalBookingId,
        serviceType: data.serviceType,
        serviceTitle: data.serviceTitle,
        preferredDate: data.preferredDate,
        address: _selectedBooking?.address ?? '',
        description: data.description,
        latitude: _selectedBooking?.latitude,
        longitude: _selectedBooking?.longitude,
      );

      _subscribeToBooking(booking);
      await _refreshBookings();

      // Notify the professional with a priority warranty message.
      // The message explicitly asks them to confirm within 24 hours so
      // the customer has a clear expectation on response time (Option C).
      final proUserId = booking.professional?.userId;
      if (proUserId != null) {
        try {
          await _notifDs.pushToUser(
            targetUserId: proUserId,
            role: 'professional',
            type: NotificationTypeStrings.bookingRequest,
            title: 'Warranty Claim — Action Required',
            message:
                '${_user?.name ?? 'A customer'} has filed a warranty claim '
                'for "${data.serviceTitle}". This is covered under your '
                'previous job warranty. Please confirm within 24 hours.',
            referenceId: booking.id,
            referenceType: 'booking',
          );
        } catch (e) {
          debugPrint('[Backjob] Could not notify professional: $e');
        }
      }

      final created =
          _bookings.firstWhereOrNull((b) => b.id == booking.id) ?? booking;
      if (mounted) {
        setState(() {
          _selectedBooking = created;
          _screen = 'booking_status';
        });
      }
      // Snackbar gives the customer a clear expectation: handyman will
      // confirm within 24 hours — matches the notification message above.
      _notify(
          'Warranty claim submitted. Your handyman will confirm within 24 hours.');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _ds = SupabaseDataSource(Supabase.instance.client);
    _appDs = ApplicationDataSource(Supabase.instance.client);
    _notifDs = NotificationDataSource(Supabase.instance.client);
    _proposalDs = ServiceProposalDatasource(Supabase.instance.client);
    _selectionDs = ServiceSelectionRequestDatasource(Supabase.instance.client);
    _init();
  }

  @override
  void dispose() {
    if (_professionalsChannel != null) {
      _ds.unsubscribeChannel(_professionalsChannel!);
    }
    if (_openRequestsChannel != null) {
      _ds.unsubscribeChannel(_openRequestsChannel!);
    }
    if (_selectedProBookingChannel != null) {
      _ds.unsubscribeChannel(_selectedProBookingChannel!);
    }
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLLER — initialisation (orchestrates Model fetches on startup)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _init() async {
    try {
      // ── Guest detection ──────────────────────────────────────────────────
      // Supabase anonymous sign-in creates a real session but no row in the
      // users table. If currentUser exists but has isAnonymous == true we
      // treat this as a guest session — load professionals for browsing only.
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser != null && authUser.isAnonymous) {
        // Fetch only the first 20 for the dashboard teaser.
        // AllProfessionalsScreen fetches its own pages independently.
        _professionals = await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
        _serviceOffers = await _ds.getServiceOffers();
        if (mounted)
          setState(() {
            _isGuest = true;
            _loading = false;
          });
        return;
      }

      _user = await _ds.getCurrentUser();
      if (_user != null) {
        // Fetch only the first 20 for the dashboard teaser.
        // AllProfessionalsScreen fetches its own pages independently.
        _professionals = await _ds.getProfessionalsPaged(page: 0, pageSize: 20);

        if (_user!.isProfessional) {
          _pro = await _ds.getProfessionalByUserId(_user!.id);

          if (_pro == null) {
            try {
              debugPrint('⚠️ No professional record found — auto-creating...');
              await Supabase.instance.client.from('professionals').insert({
                'user_id': _user!.id,
                'skills': [],
                'verified': false,
                'rating': 0.0,
                'review_count': 0,
                'available': true,
                'years_experience': 0,
              });
              _pro = await _ds.getProfessionalByUserId(_user!.id);
            } catch (e) {
              debugPrint('❌ Could not auto-create professional record: $e');
            }
          }

          if (_pro != null) {
            _bookings = await _ds.getProfessionalBookings(_pro!.id);
            _openRequests = await _ds.getOpenBookingRequests(
              skills: _pro!.skills,
              professionalId: _pro!.id,
            );
            // Load persisted skips and filter open requests
            await _loadSkippedRequests();
            if (_skippedRequestIds.isNotEmpty) {
              _openRequests
                  .removeWhere((r) => _skippedRequestIds.contains(r.id));
            }
            _applications = await _appDs.getMyApplications(_pro!.id);
            _proposals = await _proposalDs.getMyProposals(_pro!.id);
            _reviews = await _ds.getProfessionalReviews(_pro!.id);
            _myServiceIds = await _ds.getMyProfessionalServices(_pro!.id);
            // Load this handyman's upgrade requests so hasPendingUpgrade is
            // accurate on the subscription card without a manual refresh.
            try {
              _upgradeRequests = await _ds.getUpgradeRequests();
            } catch (e) {
              debugPrint('[Pro] Could not load upgrade requests: $e');
            }

            // Load pending service selection requests for this professional
            // so MyServicesScreen can show the pending-state badge on init.
            try {
              final pending =
                  await _selectionDs.getPendingForProfessional(_pro!.id);
              _pendingServiceRequestMap = {
                for (final r in pending) r.serviceOfferId: r.action
              };
            } catch (e) {
              debugPrint('[MyServices] Could not load pending requests: $e');
            }

            _openRequestsChannel = _ds.subscribeToOpenBookingRequests(
              skills: _pro!.skills,
              professionalId: _pro!.id,
              onNewRequest: (newRequest) {
                if (!mounted) return;
                if (!_openRequests.any((r) => r.id == newRequest.id) &&
                    !_skippedRequestIds.contains(newRequest.id)) {
                  setState(
                      () => _openRequests = [newRequest, ..._openRequests]);
                  _notify('New booking request.');
                }
              },
            );

            _ds.subscribeToProfessionalBookings(
              professionalId: _pro!.id,
              onNewBooking: (claimed) {
                if (!mounted) return;
                setState(() {
                  _openRequests.removeWhere((r) => r.id == claimed.id);
                  _bookings = _deduped([claimed, ..._bookings]);
                });
              },
            );

            // Ensure skipped requests stay filtered when professional bookings update
            if (_skippedRequestIds.isNotEmpty) {
              _openRequests
                  .removeWhere((r) => _skippedRequestIds.contains(r.id));
            }

            _appDs.subscribeToMyApplications(
              professionalId: _pro!.id,
              onUpdate: (a) {
                setState(() => _applications =
                    _applications.map((x) => x.id == a.id ? a : x).toList());
                if (a.status == 'approved')
                  _notify('Your ${a.serviceType} application was approved.');
                if (a.status == 'rejected')
                  _notify('Your ${a.serviceType} application was reviewed.');
                _ds
                    .getProfessionals()
                    .then((list) => setState(() => _professionals = list));
              },
            );

            // Subscribe to proposal status updates (approved / rejected).
            _proposalDs.subscribeToMyProposals(
              professionalId: _pro!.id,
              onUpdate: (p) {
                setState(() => _proposals =
                    _proposals.map((x) => x.id == p.id ? p : x).toList());
                if (p.status == 'approved')
                  _notify(
                      '"${p.serviceName}" proposal was approved and is now live.');
                if (p.status == 'rejected')
                  _notify('"${p.serviceName}" proposal was reviewed.');
              },
            );

            // Subscribe to status changes on this professional's service
            // selection requests so the UI updates in real-time when the
            // admin approves or rejects without requiring a full reload.
            _selectionDs.subscribeToMyRequests(
              professionalId: _pro!.id,
              onUpdate: (r) async {
                if (!mounted) return;
                if (r.status == 'approved') {
                  // Apply the approved change to professional_services and
                  // refresh local state so the checkbox reflects reality.
                  try {
                    await _ds.toggleProfessionalService(
                      professionalId: _pro!.id,
                      serviceOfferId: r.serviceOfferId,
                      selected: r.action == 'select',
                    );
                    final updated =
                        await _ds.getMyProfessionalServices(_pro!.id);
                    if (mounted) {
                      setState(() {
                        _myServiceIds = updated;
                        _pendingServiceRequestMap.remove(r.serviceOfferId);
                      });
                    }
                  } catch (e) {
                    debugPrint(
                        '[MyServices] Could not apply approved change: $e');
                  }
                  _notify(r.action == 'select'
                      ? '"${r.serviceName ?? 'Service'}" has been added to your profile.'
                      : '"${r.serviceName ?? 'Service'}" has been removed from your profile.');
                } else if (r.status == 'rejected') {
                  if (mounted) {
                    setState(() =>
                        _pendingServiceRequestMap.remove(r.serviceOfferId));
                  }
                  final note = r.adminNote != null && r.adminNote!.isNotEmpty
                      ? ' Feedback: ${r.adminNote}'
                      : '';
                  _notify(
                      '"${r.serviceName ?? 'Service'}" request was not approved.$note');
                }
              },
            );
          }
        } else if (_user!.role == 'admin') {
          try {
            _applications = await _appDs.getAllApplications();
          } catch (e) {
            debugPrint('[Admin] Could not load applications: $e');
          }
          try {
            _proposals = await _proposalDs.getAllProposals();
          } catch (e) {
            debugPrint('[Admin] Could not load proposals: $e');
          }
          try {
            _serviceSelectionRequests = await _selectionDs.getAllRequests();
          } catch (e) {
            debugPrint('[Admin] Could not load service selection requests: $e');
          }
          try {
            _upgradeRequests = await _ds.getUpgradeRequests();
          } catch (e) {
            debugPrint('[Admin] Could not load upgrade requests: $e');
          }
          try {
            _adminBookings = await _ds.getAllBookings();
          } catch (e) {
            debugPrint('[Admin] Could not load all bookings: $e');
          }
        } else {
          // ── Customer ──────────────────────────────────────────────────
          _bookings = await _ds.getCustomerBookings(_user!.id);
          // Load approved service proposals as the customer's service offers.
          try {
            _serviceOffers = await _ds.getServiceOffers();
          } catch (e) {
            debugPrint('Could not load service offers: $e');
          }

          for (final b in _bookings) {
            if (b.status == BookingStatus.completed) {
              final reviewed = await _ds.hasReviewedBooking(
                bookingId: b.id,
                customerId: _user!.id,
              );
              if (reviewed) _reviewedBookingIds.add(b.id);
            }
          }

          for (final existingBooking in _bookings) {
            final isActive = existingBooking.status == BookingStatus.pending ||
                existingBooking.status == BookingStatus.accepted ||
                existingBooking.status == BookingStatus.assessment ||
                existingBooking.status ==
                    BookingStatus.pendingArrivalConfirmation ||
                existingBooking.status == BookingStatus.inProgress ||
                existingBooking.status ==
                    BookingStatus.pendingCustomerConfirmation;
            if (isActive) {
              _subscribeToBooking(existingBooking);
            }
          }

          _notifDs.getNotifications(userId: _user!.id).then((list) {
            if (mounted)
              setState(() =>
                  _unreadNotifCount = list.where((n) => !n.isRead).length);
          });
          try {
            final notifs = await _notifDs.getNotifications(userId: _user!.id);
            _unreadNotifCount = notifs.where((n) => !n.isRead).length;
          } catch (e) {
            debugPrint('Could not load notif count: $e');
          }

          _professionalsChannel = _ds.subscribeToReviewsInserts(
            onInsert: (_) async {
              try {
                final updated =
                    await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
                if (mounted) setState(() => _professionals = updated);
              } catch (e) {
                debugPrint(
                    '[Realtime] professionals refresh (via review) error: $e');
              }
            },
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSkippedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsSkippedKey) ?? <String>[];
      setState(() => _skippedRequestIds = list.toSet());
    } catch (e) {
      debugPrint('Could not load skipped requests: $e');
    }
  }

  Future<void> _saveSkippedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsSkippedKey, _skippedRequestIds.toList());
    } catch (e) {
      debugPrint('Could not save skipped requests: $e');
    }
  }

  void _skipOpenRequestById(String id) {
    if (id.isEmpty) return;
    setState(() {
      _skippedRequestIds.add(id);
      _openRequests.removeWhere((r) => r.id == id);
    });
    _saveSkippedRequests();
    _notify('Request dismissed.');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLLER — service request navigation helper
  // ══════════════════════════════════════════════════════════════════════════

  /// Navigates to RequestServiceScreen pre-filled with [serviceType] and
  /// [serviceName]. Fetches qualifiedProfessionalIds first so only
  /// professionals who have selected that exact service are matched.
  Future<void> _navigateToRequestServiceWithOffer({
    required String serviceType,
    required String serviceName,
    String? description,
  }) async {
    // Fetch before navigating so the screen has the right pros from the start
    try {
      final ids = await _ds.getProfessionalsOfferingService(
        serviceType: serviceType,
        serviceName: serviceName,
      );
      if (mounted) {
        setState(() {
          _preselectedServiceType = serviceType;
          _preselectedProblemTitle = serviceName;
          _preselectedDescription = description;
          _selectedPro = null;
          _qualifiedProfessionalIds = ids;
          _screen = 'request_service';
        });
      }
    } catch (e) {
      debugPrint('[navigateToRequestService] error: $e');
      // Navigate anyway with empty filter as fallback
      setState(() {
        _preselectedServiceType = serviceType;
        _preselectedProblemTitle = serviceName;
        _preselectedDescription = description;
        _selectedPro = null;
        _qualifiedProfessionalIds = {};
        _screen = 'request_service';
      });
    }
  }

  /// Navigates to ProfessionalProfileScreen given only a [ProfessionalEntity].
  /// Used by AllProfessionalsScreen callbacks, where the tapped professional
  /// may not be present in the in-memory [_professionals] list (which is now
  /// limited to 20 rows for the dashboard teaser).
  ///
  /// Strategy:
  ///   1. Try an O(1) lookup in [_professionals] — covers the case where the
  ///      tapped card is one of the top-20 dashboard pros.
  ///   2. If not found, fetch the full model from the DB via [getProfessionalById]
  ///      before routing, so [_selectedPro] is never null when we set _screen.
  Future<void> _navigateToProProfile(
    ProfessionalEntity entity, {
    String returnScreen = 'explore',
  }) async {
    // Fast path — already in memory.
    final cached = _professionals.where((p) => p.id == entity.id).firstOrNull;
    if (cached != null) {
      setState(() {
        _selectedPro = cached;
        _selectedProFresh = null;
        _proReviews = [];
        _profileReturnScreen = returnScreen;
        _screen = 'professional_profile';
      });
      // Still kick off a fresh fetch to get the latest data.
      _ds.getProfessionalById(entity.id).then((fresh) {
        if (!mounted || fresh == null) return;
        setState(() => _selectedProFresh = fresh);
      }).catchError((e) => debugPrint('Could not refresh pro: $e'));
    } else {
      // Slow path — not in the dashboard cache; fetch before routing.
      try {
        final model = await _ds.getProfessionalById(entity.id);
        if (!mounted || model == null) return;
        setState(() {
          _selectedPro = model;
          _selectedProFresh = null;
          _proReviews = [];
          _profileReturnScreen = returnScreen;
          _screen = 'professional_profile';
        });
      } catch (e) {
        debugPrint('[_navigateToProProfile] error: $e');
        return;
      }
    }
    // Fetch reviews in parallel (works for both paths).
    _ds.getProfessionalReviewsById(entity.id).then((reviews) {
      if (!mounted) return;
      setState(() => _proReviews = reviews);
    }).catchError((e) => debugPrint('Could not load reviews: $e'));
  }

  /// Navigates to RequestServiceScreen for a DIRECT booking against a
  /// specific professional. Fetches only the services that professional
  /// has selected so the customer can only choose from what they actually offer.
  Future<void> _navigateToDirectBooking(ProfessionalModel pro) async {
    final skillType = pro.skills.isNotEmpty
        ? '${pro.skills.first[0].toUpperCase()}'
            '${pro.skills.first.substring(1).toLowerCase()}'
        : '';
    try {
      final offers = await _ds.getMyProfessionalServiceOffers(pro.id);
      if (mounted) {
        setState(() {
          _selectedPro = pro;
          _preselectedServiceType = skillType;
          _preselectedProblemTitle = null;
          _preselectedDescription = null;
          // Direct booking: qualified set = just this professional
          _qualifiedProfessionalIds = {pro.id};
          _directBookingOffers = offers;
          _screen = 'request_service';
        });
      }
    } catch (e) {
      debugPrint('[navigateToDirectBooking] error: $e');
      // Navigate anyway — offers list will be empty, falls back to full catalogue
      setState(() {
        _selectedPro = pro;
        _preselectedServiceType = skillType;
        _preselectedProblemTitle = null;
        _preselectedDescription = null;
        _qualifiedProfessionalIds = {pro.id};
        _directBookingOffers = [];
        _screen = 'request_service';
      });
    }
  }

  Future<void> _refreshBookings() async {
    try {
      if (_user == null) return;
      if (_user!.isProfessional && _pro != null) {
        final assigned = await _ds.getProfessionalBookings(_pro!.id);
        final open = await _ds.getOpenBookingRequests(
            skills: _pro!.skills, professionalId: _pro!.id);
        if (mounted)
          setState(() {
            _bookings = _deduped(assigned);
            _openRequests =
                open.where((r) => !_skippedRequestIds.contains(r.id)).toList();
          });
      } else if (_user!.role == 'customer') {
        final list = await _ds.getCustomerBookings(_user!.id);
        if (mounted) setState(() => _bookings = _deduped(list));
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  Future<void> _refreshReviews() async {
    if (_pro == null) return;
    try {
      final list = await _ds.getProfessionalReviews(_pro!.id);
      if (mounted) setState(() => _reviews = list);
    } catch (e) {
      debugPrint('_refreshReviews error: $e');
    }
  }

  Future<void> _refreshUser() async {
    try {
      final updated = await _ds.getCurrentUser();
      if (mounted && updated != null) setState(() => _user = updated);
    } catch (e) {
      debugPrint('_refreshUser error: $e');
    }
  }

  Future<void> _refreshCustomerDashboard() async {
    if (_user == null) return;
    try {
      final pros = await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
      final bookings = await _ds.getCustomerBookings(_user!.id);
      final offers = await _ds.getServiceOffers();
      if (mounted)
        setState(() {
          _professionals = pros;
          _bookings = _deduped(bookings);
          _serviceOffers = offers;
        });
    } catch (e) {
      debugPrint('Pull-to-refresh (customer) error: $e');
    }
  }

  // ── SHARE PROFILE ─────────────────────────────────────────────────────────

  /// Builds the handyman's AYO profile link and shows a bottom sheet
  /// with options to copy or share it. Uses Clipboard (no extra package
  /// needed — flutter/services.dart is always available).
  ///
  /// The profile link format is:
  ///   https://ayoapp.ph/pro/{professionalId}
  ///
  /// Even before the deep link is live this trains the share habit and the
  /// URL is ready to activate when the web profile page launches.
  void _shareProProfile() {
    if (_pro == null || !mounted) return;
    final link = 'https://ayoapp.ph/pro/${_pro!.id}';
    final proName = _user?.name ?? 'My';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share Your AYO Profile',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E)),
            ),
            const SizedBox(height: 6),
            Text(
              'Send this link to customers so they can book $proName directly through AYO.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF8E8E93), height: 1.4),
            ),
            const SizedBox(height: 20),
            // Link preview box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.link_rounded,
                    size: 16, color: Color(0xFF8E8E93)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(link,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1C1C1E),
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    Navigator.pop(context);
                    _notify('Profile link copied.');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    // url_launcher is already a dependency — use it to
                    // open the native share sheet via a data: URI.
                    // Fallback: copy to clipboard if share is unavailable.
                    final encoded =
                        Uri.encodeComponent('Book me through AYO: $link');
                    final whatsapp = Uri.parse('https://wa.me/?text=$encoded');
                    if (await canLaunchUrl(whatsapp)) {
                      await launchUrl(whatsapp,
                          mode: LaunchMode.externalApplication);
                    } else {
                      Clipboard.setData(ClipboardData(text: link));
                      _notify('Profile link copied.');
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshProfessionalDashboard() async {
    if (_user == null || _pro == null) return;
    try {
      final bookings = await _ds.getProfessionalBookings(_pro!.id);
      final open = await _ds.getOpenBookingRequests(
          skills: _pro!.skills, professionalId: _pro!.id);
      final reviews = await _ds.getProfessionalReviews(_pro!.id);
      // Always re-fetch _pro so subscription_tier is never stale.
      final updatedPro = await _ds.getProfessionalByUserId(_user!.id);
      // Re-fetch upgrade requests so hasPendingUpgrade reflects current state.
      List<SubscriptionRequestModel> updatedUpgrades = _upgradeRequests;
      try {
        updatedUpgrades = await _ds.getUpgradeRequests();
      } catch (e) {
        debugPrint('[Pro refresh] Could not reload upgrade requests: $e');
      }
      if (mounted)
        setState(() {
          _bookings = _deduped(bookings);
          _openRequests =
              open.where((r) => !_skippedRequestIds.contains(r.id)).toList();
          _reviews = reviews;
          if (updatedPro != null) _pro = updatedPro;
          _upgradeRequests = updatedUpgrades;
        });
    } catch (e) {
      debugPrint('Pull-to-refresh (professional) error: $e');
    }
  }

  // ── VIEW helper — snackbar notification ──────────────────────────────────
  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.notifications_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmtTime(DateTime dt) => DateFormat('h:mm a').format(dt.toLocal());

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLLER — build / routing
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary))));

    // Guest session — anonymous Supabase auth, no users table row
    if (_isGuest) return _guestFlow();

    if (_user == null) return const AuthFlow();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
          return;
        }
        if (_screen != 'home') {
          if (_screen == 'pro_booking_detail') {
            setState(() => _screen = 'booking_history');
            return;
          }
          setState(() => _screen = 'home');
          return;
        }
        if (_navIndex != 0) {
          setState(() {
            _navIndex = 0;
            _screen = 'home';
          });
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
        } else {
          // ignore: deprecated_member_use
          SystemNavigator.pop();
        }
      },
      child: _buildContent(),
    );
  }

  // Route to the correct role-based flow (Controller routing decision).
  Widget _buildContent() {
    if (_user!.role == 'admin') return _adminFlow();
    if (_user!.isProfessional) return _professionalFlow();
    return _customerFlow();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW — ADMIN FLOW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _adminFlow() {
    final u = _user!.toEntity();

    if (_navIndex == 1) {
      return ApprovalsScreen(
        applications: _applications,
        proposals: _proposals,
        serviceRequests: _serviceSelectionRequests,
        upgradeRequests: _upgradeRequests,
        onBack: () => setState(() => _navIndex = 0),
        onApprove: (app) async {
          try {
            await _appDs.approveApplication(app);
            _applications = await _appDs.getAllApplications();
            _professionals =
                await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
            setState(() {});
            _notify('${app.applicantName} approved for ${app.serviceType}.');
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onReject: (app, note) async {
          try {
            await _appDs.rejectApplication(app, note: note);
            _applications = await _appDs.getAllApplications();
            setState(() {});
            _notify('Application rejected.');
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onApproveProposal: (prop) async {
          try {
            await _proposalDs.approveProposal(prop);
            // Auto-select the approved service for the professional who proposed it
            final proId = await _ds.getProfessionalIdFromProposal(prop.id);
            if (proId != null) {
              await _ds.autoSelectServiceForProfessional(
                professionalId: proId,
                serviceOfferId: prop.id,
              );
            }
            _proposals = await _proposalDs.getAllProposals();
            setState(() {});
            _notify('"${prop.serviceName}" is now live in Service Offers.');
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onRejectProposal: (prop, note) async {
          try {
            await _proposalDs.rejectProposal(prop, note: note);
            _proposals = await _proposalDs.getAllProposals();
            setState(() {});
            _notify('Proposal rejected.');
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onApproveServiceRequest: (req) async {
          try {
            await _selectionDs.approveRequest(req.id);
            // Apply the actual professional_services change.
            await _ds.toggleProfessionalService(
              professionalId: req.professionalId,
              serviceOfferId: req.serviceOfferId,
              selected: req.action == 'select',
            );
            // Notify the handyman.
            final proUserId =
                await _ds.getUserIdFromProfessionalId(req.professionalId);
            if (proUserId != null) {
              await _notifDs.pushToUser(
                targetUserId: proUserId,
                role: 'professional',
                type: NotificationTypeStrings.bookingAccepted,
                title: req.action == 'select'
                    ? 'Service Request Approved'
                    : 'Service Removal Approved',
                message: req.action == 'select'
                    ? '"${req.serviceName ?? 'Service'}" has been added to your profile.'
                    : '"${req.serviceName ?? 'Service'}" has been removed from your profile.',
                referenceId: req.id,
                referenceType: 'service_selection_request',
              );
            }
            _serviceSelectionRequests = await _selectionDs.getAllRequests();
            setState(() {});
            _notify(req.action == 'select'
                ? '"${req.serviceName ?? 'Service'}" approved and added to handyman profile.'
                : '"${req.serviceName ?? 'Service'}" removal approved.');
          } catch (e) {
            _notify('Error approving service request: $e');
          }
        },
        onRejectServiceRequest: (req, note) async {
          try {
            await _selectionDs.rejectRequest(req.id, adminNote: note);
            // Notify the handyman.
            final proUserId =
                await _ds.getUserIdFromProfessionalId(req.professionalId);
            if (proUserId != null) {
              await _notifDs.pushToUser(
                targetUserId: proUserId,
                role: 'professional',
                type: NotificationTypeStrings.bookingCancelled,
                title: 'Service Request Not Approved',
                message: note != null && note.isNotEmpty
                    ? '"${req.serviceName ?? 'Service'}" request was not approved. Feedback: $note'
                    : '"${req.serviceName ?? 'Service'}" request was not approved.',
                referenceId: req.id,
                referenceType: 'service_selection_request',
              );
            }
            _serviceSelectionRequests = await _selectionDs.getAllRequests();
            setState(() {});
            _notify('Service request rejected.');
          } catch (e) {
            _notify('Error rejecting service request: $e');
          }
        },
        onApproveUpgrade: (req) async {
          try {
            await _ds.approveUpgradeRequest(
              requestId: req.id,
              professionalId: req.professionalId,
              tier: req.requestedTier,
            );
            // Refresh professionals so the new tier is reflected everywhere.
            _professionals =
                await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
            _upgradeRequests = await _ds.getUpgradeRequests();
            setState(() {});
            // Notify the handyman.
            final proUserId =
                await _ds.getUserIdFromProfessionalId(req.professionalId);
            if (proUserId != null) {
              await _notifDs.pushToUser(
                targetUserId: proUserId,
                role: 'professional',
                type: NotificationTypeStrings.bookingAccepted,
                title: 'Plan Upgrade Approved',
                message: 'Your upgrade to ${req.requestedTierLabel} has been '
                    'approved. Your new plan is now active.',
                referenceId: req.id,
                referenceType: 'subscription_request',
              );
            }
            _notify('${req.requestedTierLabel} plan activated for '
                '${req.handymanName ?? 'handyman'}.');
          } catch (e) {
            _notify('Error approving upgrade: $e');
          }
        },
        onRejectUpgrade: (req, note) async {
          try {
            await _ds.rejectUpgradeRequest(
              requestId: req.id,
              adminNote: note,
            );
            _upgradeRequests = await _ds.getUpgradeRequests();
            setState(() {});
            // Notify the handyman.
            final proUserId =
                await _ds.getUserIdFromProfessionalId(req.professionalId);
            if (proUserId != null) {
              await _notifDs.pushToUser(
                targetUserId: proUserId,
                role: 'professional',
                type: NotificationTypeStrings.bookingCancelled,
                title: 'Plan Upgrade Not Approved',
                message: note != null && note.isNotEmpty
                    ? 'Your upgrade request was not approved. Feedback: $note'
                    : 'Your upgrade request was not approved at this time.',
                referenceId: req.id,
                referenceType: 'subscription_request',
              );
            }
            _notify('Upgrade request rejected.');
          } catch (e) {
            _notify('Error rejecting upgrade: $e');
          }
        },
        onNavTap: (i) => setState(() => _navIndex = i),
        currentNavIndex: _navIndex,
      );
    }

    if (_navIndex == 2) {
      return SuperAdminAnalytics(
        onBack: () => setState(() => _navIndex = 0),
        onNavTap: (i) => setState(() => _navIndex = i),
        currentNavIndex: _navIndex,
      );
    }

    if (_navIndex == 3) {
      return AdminProfileScreen(
        adminName: u.name,
        adminEmail: u.email,
        adminPhone: u.phone,
        accessLevel: 'SUPERADMIN',
        lastLogin: DateTime.now(),
        onBack: () => setState(() => _navIndex = 0),
        onLogout: () async => Supabase.instance.client.auth.signOut(),
      );
    }

    if (_navIndex == 4) {
      if (_user == null || _user!.id.isEmpty) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        );
      }
      return AdminNotificationsScreen(
        userId: _user!.id,
        notificationDataSource: _notifDs,
        onBack: () => setState(() => _navIndex = 0),
        onApprove: (applicationId) async {
          try {
            final app = _applications.firstWhere((a) => a.id == applicationId);
            await _appDs.approveApplication(app);
            _applications = await _appDs.getAllApplications();
            _professionals =
                await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
            setState(() {});
            _notify('${app.applicantName} approved for ${app.serviceType}.');
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onReject: (applicationId) async {
          try {
            final app = _applications.firstWhere((a) => a.id == applicationId);
            await _appDs.rejectApplication(app);
            _applications = await _appDs.getAllApplications();
            setState(() {});
            _notify('Application rejected.');
          } catch (e) {
            _notify('Error: $e');
          }
        },
      );
    }

    // ── Booking Overview screen ─────────────────────────────────────────────
    if (_screen == 'booking_overview') {
      return AdminBookingOverviewScreen(
        bookings: _adminBookings.map((b) => b.toEntity()).toList(),
        onLoadCompletionPhotos: (bookingId) =>
            _ds.getCompletionPhotos(bookingId),
        onBack: () async {
          try {
            final fresh = await _ds.getAllBookings();
            if (mounted)
              setState(() {
                _adminBookings = fresh;
                _screen = 'home';
              });
          } catch (_) {
            setState(() => _screen = 'home');
          }
        },
        onRefresh: () async {
          try {
            final fresh = await _ds.getAllBookings();
            if (mounted) setState(() => _adminBookings = fresh);
          } catch (e) {
            debugPrint('[Admin] Refresh bookings error: $e');
          }
        },
      );
    }

    if (_screen == 'admin_catalogue') {
      // Explicit cast ensures callbacks receive ServiceProposalModel not Object?
      final pending = _proposals
          .where((p) => p.status == 'pending')
          .cast<ServiceProposalModel>()
          .toList();
      return AdminCatalogueScreen(
        services: _serviceOffers,
        pendingProposals: pending,
        onBack: () async {
          // Refresh both service offers and proposals on return
          try {
            final offers = await _ds.getServiceOffers();
            final proposals = await _proposalDs.getAllProposals();
            if (mounted)
              setState(() {
                _serviceOffers = offers;
                _proposals = proposals;
                _screen = 'home';
              });
          } catch (_) {
            setState(() => _screen = 'home');
          }
        },
        onRefresh: () async {
          try {
            final offers = await _ds.getServiceOffers();
            final proposals = await _proposalDs.getAllProposals();
            if (mounted)
              setState(() {
                _serviceOffers = offers;
                _proposals = proposals;
              });
          } catch (e) {
            debugPrint('[Admin] Catalogue refresh error: $e');
          }
        },
        onCreateService: (data) async {
          try {
            final result = await _ds.adminSeedService(
              serviceName: data.serviceName,
              serviceType: data.serviceType,
              description: data.description,
              includes: data.includes,
              priceRange: data.priceRange,
              duration: data.duration,
              tips: data.tips,
              imageUrl: data.imageUrl,
              warrantyDays: data.warrantyDays,
            );
            final updated = await _ds.getServiceOffers();
            if (mounted) {
              setState(() => _serviceOffers = updated);
              _notify('"${result.serviceName}" added to the catalogue.');
            }
          } catch (e) {
            debugPrint('[Admin] createService error: $e');
            _notify('Failed to create service: $e');
          }
        },
        onDeleteService: (id) async {
          await _ds.adminDeleteService(id);
          final updated = await _ds.getServiceOffers();
          if (mounted) {
            setState(() => _serviceOffers = updated);
            _notify('Service deleted.');
          }
        },
        onApproveProposal: (ServiceProposalModel prop) async {
          await _proposalDs.approveProposal(prop);
          // Auto-select the approved service for the professional who proposed it
          final proId = await _ds.getProfessionalIdFromProposal(prop.id);
          if (proId != null) {
            await _ds.autoSelectServiceForProfessional(
              professionalId: proId,
              serviceOfferId: prop.id,
            );
          }
          final offers = await _ds.getServiceOffers();
          final proposals = await _proposalDs.getAllProposals();
          if (mounted) {
            setState(() {
              _serviceOffers = offers;
              _proposals = proposals;
            });
            _notify('"${prop.serviceName}" approved and now live.');
          }
        },
        onRejectProposal: (ServiceProposalModel prop, String? note) async {
          await _proposalDs.rejectProposal(prop, note: note);
          final proposals = await _proposalDs.getAllProposals();
          if (mounted) {
            setState(() => _proposals = proposals);
            _notify('Proposal rejected.');
          }
        },
      );
    }

    final pending = _applications.where((a) => a.status == 'pending').length +
        _proposals.where((p) => p.status == 'pending').length +
        _serviceSelectionRequests.where((r) => r.status == 'pending').length +
        _upgradeRequests.where((r) => r.status == 'pending').length;
    // Use _adminBookings for accurate stats; fall back to _bookings if empty.
    final statsSource = _adminBookings.isNotEmpty ? _adminBookings : _bookings;
    return AdminDashboardScreen(
      adminUserId: _user!.id,
      adminName: _user!.name,
      pendingApprovals: pending,
      totalUsers: _professionals.length,
      totalEarnings: statsSource
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (s, b) {
        final ap = b.assessmentPrice;
        return s + (ap != null && ap > 0 ? ap : (b.priceEstimate ?? 0));
      }),
      completedBookings:
          statsSource.where((b) => b.status == BookingStatus.completed).length,
      currentNavIndex: _navIndex,
      onNavTap: (i) => setState(() => _navIndex = i),
      onHandymanApprovals: () => setState(() => _navIndex = 1),
      onAnalytics: () => setState(() => _navIndex = 2),
      onBookingOverview: () async {
        try {
          final fresh = await _ds.getAllBookings();
          if (mounted)
            setState(() {
              _adminBookings = fresh;
              _screen = 'booking_overview';
            });
        } catch (e) {
          _notify('Could not load bookings: $e');
        }
      },
      onManageCatalogue: () async {
        try {
          final fresh = await _ds.getServiceOffers();
          if (mounted)
            setState(() {
              _serviceOffers = fresh;
              _screen = 'admin_catalogue';
            });
        } catch (e) {
          _notify('Could not load catalogue: $e');
        }
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW — PROFESSIONAL FLOW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _professionalFlow() {
    final u = _user!.toEntity();
    final proEntity = _pro?.toEntity();
    // proId is defined here so all screen cases (apply, my_services,
    // propose_service, verification_status) can reference it without
    // redeclaring inside each if block.
    final proId = _pro?.id;
    final bookingEntities = _bookings.map((b) => b.toEntity()).toList();
    final openRequestEntities = _openRequests
        .where((r) => !_skippedRequestIds.contains(r.id))
        .map((b) => b.toEntity())
        .toList();

    if (_screen == 'pro_booking_detail' && _selectedProBooking != null) {
      return ProBookingDetailScreen(
        booking: _selectedProBooking!,
        onBack: () => setState(() => _screen = 'booking_history'),
        onSetAssessmentPrice: (price) async {
          try {
            await _ds.updateBookingAssessmentPrice(
              bookingId: _selectedProBooking!.id,
              price: price,
            );
            await _refreshBookings();
            final updated = _bookings
                .firstWhereOrNull((b) => b.id == _selectedProBooking!.id);
            if (mounted && updated != null) {
              setState(() => _selectedProBooking = updated.toEntity());
            }
          } catch (e) {
            _notify('Failed to save price: $e');
            rethrow;
          }
        },
        // Controller: pro marks job done → pendingCustomerConfirmation.
        // Customer must then confirm via BookingStatusScreen before status
        // reaches 'completed'.
        // onMarkComplete retained for API compat — onMarkCompleteWithProof
        // is the primary path and requires ≥3 proof photos.
        onMarkComplete: () async {
          try {
            final updated = await _ds.markJobDoneByPro(_selectedProBooking!.id);
            _updateBookingInList(updated);
            if (mounted) {
              setState(() => _selectedProBooking = updated.toEntity());
            }
            _notify('Job marked as done. Waiting for customer confirmation.');
          } catch (e) {
            _notify('Error updating status: $e');
            rethrow;
          }
        },
        onMarkCompleteWithProof: (photoPaths) async {
          if (_pro == null || _selectedProBooking == null) return;
          try {
            // Upload each photo and collect public URLs
            final photoUrls = <String>[];
            for (int i = 0; i < photoPaths.length; i++) {
              final bytes = await File(photoPaths[i]).readAsBytes();
              final url = await _ds.uploadCompletionPhoto(
                uploaderUid: _pro!.userId,
                bookingId: _selectedProBooking!.id,
                fileBytes: bytes,
                index: i,
              );
              photoUrls.add(url);
            }
            // Save URLs + advance status in one call
            final updated = await _ds.submitJobDoneWithProof(
              bookingId: _selectedProBooking!.id,
              uploaderUid: _pro!.userId,
              photoUrls: photoUrls,
            );
            _updateBookingInList(updated);
            if (mounted) {
              setState(() => _selectedProBooking = updated.toEntity());
            }
            _notify('Proof uploaded. Waiting for customer confirmation.');
          } catch (e) {
            _notify('Failed to upload proof: $e');
            rethrow;
          }
        },
        onProposeSchedule: _handleConfirmSchedule,
        onProposeReschedule: _handleProposeReschedule,
        onNotifyRunningLate: _handleNotifyRunningLate,
        onStartAssessment: _handleStartAssessment,
      );
    }

    if (_screen == 'booking_history') {
      return BookingHistoryScreen(
        bookings: bookingEntities,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = 'home';
        }),
        onBack: () => setState(() => _screen = 'home'),
        onRefresh: _refreshBookings,
        onUpdateStatus: (booking, status) async {
          try {
            await _ds.updateBookingStatus(booking.id, status);
            await _refreshBookings();
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onViewDetail: (booking) {
          setState(() {
            _selectedProBooking = booking;
            _screen = 'pro_booking_detail';
          });
          _subscribeToProBooking(booking);
        },
      );
    }

    if (_screen == 'reviews') {
      return ProfessionalReviewsScreen(
        reviews: _reviews.map((r) => r.toEntity()).toList(),
        professional: _pro?.toEntity(),
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = 'home';
        }),
        onBack: () => setState(() => _screen = 'home'),
        onRefresh: () async {
          await _refreshReviews();
        },
      );
    }

    if (_screen == 'apply') {
      if (proId == null) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F3D2E),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => setState(() => _screen = 'home'),
            ),
            title: const Text('Apply for Service',
                style: TextStyle(color: Colors.white)),
            elevation: 0,
          ),
          body: Center(
              child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: Color(0xFFFF9500)),
              const SizedBox(height: 16),
              const Text(
                  'Professional profile not found.\nPlease log out and log back in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF666666))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Log Out & Try Again'),
              ),
            ]),
          )),
        );
      }
      return ApplyScreen(
        professionalId: proId,
        userId: _user!.id,
        onBack: () => setState(() => _screen = 'home'),
        onSubmit: (data) async {
          try {
            final app = await _appDs.submitApplication(
              professionalId: proId,
              userId: _user!.id,
              serviceType: data.serviceType,
              credentialFile: data.credentialFile,
              validIdFile: data.validIdFile,
              yearsExp: data.yearsExp,
              priceMin: data.priceMin,
              bio: data.bio,
            );
            setState(() {
              _applications = [app, ..._applications];
              _screen = 'verification_status';
            });
            _notify(
                "Application submitted! We'll review it within 24–48 hours.");
          } catch (e) {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Submission failed: $e')));
          }
        },
      );
    }

    if (_screen == 'verification_status') {
      return VerificationStatusScreen(
        applications: _applications,
        proposals: _proposals,
        onBack: () => setState(() => _screen = 'home'),
        onApplyNew: () => setState(() => _screen = 'apply'),
        onProposeService: () => setState(() => _screen = 'propose_service'),
      );
    }

    if (_screen == 'my_services') {
      if (proId == null) return _home();
      // Normalize to title case so 'plumber' → 'Plumber' matches DB values.
      final rawSkill =
          _pro?.skills.isNotEmpty == true ? _pro!.skills.first : 'Professional';
      final skillType = rawSkill.isEmpty
          ? 'Professional'
          : rawSkill[0].toUpperCase() + rawSkill.substring(1).toLowerCase();
      debugPrint(
          '[MyServices] pro skills: ${_pro?.skills}, using skillType: "$skillType"');
      return FutureBuilder<List<ServiceOfferModel>>(
        future: _ds.getServiceOffersByType(skillType),
        builder: (context, snap) {
          final available = snap.data ?? [];
          return MyServicesScreen(
            availableServices: available,
            selectedIds: _myServiceIds,
            skillType: skillType,
            myProfessionalId: _pro?.id,
            pendingRequests: _pendingServiceRequestMap,
            onBack: () => setState(() => _screen = 'home'),
            onToggleService: (serviceOfferId, selected) async {
              // Look up the service name for the admin card display.
              final offer = available.firstWhere(
                (o) => o.id == serviceOfferId,
                orElse: () => available.first,
              );
              final action = selected ? 'select' : 'deselect';
              // Submit the request for admin review — do NOT write to
              // professional_services directly. The pending badge in the UI
              // and the actual professional_services write both happen only
              // after admin approval (via realtime subscription above).
              await _selectionDs.submitRequest(
                professionalId: proId,
                serviceOfferId: serviceOfferId,
                action: action,
                handymanName: _user?.name,
                serviceName: offer.serviceName,
                skillType: skillType,
              );
              // Notify the admin that a new request is pending review.
              try {
                final adminUsers = await _ds.getAdminUserIds();
                for (final adminId in adminUsers) {
                  await _notifDs.pushToUser(
                    targetUserId: adminId,
                    role: 'admin',
                    type: NotificationTypeStrings.bookingAccepted,
                    title: 'New Service Request',
                    message: '${_user?.name ?? 'A handyman'} has requested to '
                        '${selected ? 'add' : 'remove'} '
                        '"${offer.serviceName}" from their profile.',
                    referenceId: serviceOfferId,
                    referenceType: 'service_selection_request',
                  );
                }
              } catch (e) {
                debugPrint('[MyServices] Could not notify admin: $e');
              }
              // Update the local pending map so the badge appears immediately.
              if (mounted) {
                setState(
                    () => _pendingServiceRequestMap[serviceOfferId] = action);
              }
            },
            onProposeNew: () => setState(() => _screen = 'propose_service'),
          );
        },
      );
    }

    if (_screen == 'propose_service') {
      if (proId == null) return _home();
      // Find existing proposal if this is a resubmission.
      final existing =
          _proposals.isNotEmpty && _proposals.first.status == 'rejected'
              ? _proposals.first
              : null;
      return ProposeServiceScreen(
        professionalId: proId,
        userId: _user!.id,
        existingProposal: existing,
        onBack: () => setState(() => _screen = 'home'),
        onSubmit: (data) async {
          try {
            final ServiceProposalModel result;
            if (existing != null) {
              result = await _proposalDs.resubmitProposal(
                proposalId: existing.id,
                userId: _user!.id,
                data: data,
                existingImageUrl:
                    data.imageFile.path.isEmpty ? existing.imageUrl : null,
              );
              setState(() {
                _proposals = _proposals
                    .map((p) => p.id == result.id ? result : p)
                    .toList();
                _screen = 'home';
              });
            } else {
              result = await _proposalDs.submitProposal(
                professionalId: proId,
                userId: _user!.id,
                data: data,
              );
              setState(() {
                _proposals = [result, ..._proposals];
                _screen = 'home';
              });
            }
            _notify(
                'Proposal submitted. We will review it within 24–48 hours.');
          } catch (e) {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Submission failed: $e')));
          }
        },
      );
    }

    if (_screen == 'my_plan') {
      final hasPending = _upgradeRequests
          .any((r) => r.professionalId == _pro?.id && r.status == 'pending');
      return SubscriptionScreen(
        professional: proEntity,
        hasPendingUpgrade: hasPending,
        onRequestUpgrade: (targetTier) async {
          if (_pro == null) return;
          await _ds.submitUpgradeRequest(
            professionalId: _pro!.id,
            currentTier: _pro!.subscriptionTier,
            requestedTier: targetTier,
          );
          // Refresh upgrade requests so hasPendingUpgrade badge updates.
          try {
            final updated = await _ds.getUpgradeRequests();
            if (mounted) setState(() => _upgradeRequests = updated);
          } catch (e) {
            debugPrint(
                '[SubscriptionScreen] Could not refresh upgrade requests: $e');
          }
          // Notify admins.
          try {
            const tierNames = ['Free', 'AYO Pro', 'AYO Elite'];
            final adminUsers = await _ds.getAdminUserIds();
            for (final adminId in adminUsers) {
              await _notifDs.pushToUser(
                targetUserId: adminId,
                role: 'admin',
                type: NotificationTypeStrings.bookingAccepted,
                title: 'Plan Upgrade Request',
                message:
                    '${_user?.name ?? 'A handyman'} has requested an upgrade '
                    'to ${tierNames[targetTier.clamp(0, 2)]}. Please review in Approvals.',
                referenceId: _pro!.id,
                referenceType: 'subscription_request',
              );
            }
          } catch (e) {
            debugPrint('[SubscriptionScreen] Could not notify admin: $e');
          }
        },
        onBack: () => setState(() => _screen = 'home'),
      );
    }

    // ── NAV INDEX CHECKS ──────────────────────────────────────────────────

    if (_navIndex == 1) {
      return BookingRequestsScreen(
        bookings: openRequestEntities,
        isAvailable: _pro?.available ?? true,
        currentNavIndex: _navIndex,
        onNavTap: (i) async {
          setState(() {
            _navIndex = i;
            _screen = 'home';
          });
          if (i == 1) await _refreshBookings();
        },
        onRefresh: _refreshBookings,
        onAccept: (booking) async {
          if (_pro == null) return;
          try {
            final claimed = await _ds.claimBooking(
              bookingId: booking.id,
              professionalId: _pro!.id,
            );
            setState(() {
              _openRequests.removeWhere((r) => r.id == claimed.id);
              _bookings = _deduped([claimed, ..._bookings]);
              _selectedProBooking = claimed.toEntity();
              _screen = 'pro_booking_detail';
            });
            _subscribeToProBooking(_selectedProBooking!);
            // Compute a simple ETA for the customer if locations exist
            try {
              final custLat = claimed.latitude;
              final custLng = claimed.longitude;
              // pro location may be on _pro or inside claimed.professional
              final proLat = claimed.professional?.latitude ?? _pro?.latitude;
              final proLng = claimed.professional?.longitude ?? _pro?.longitude;
              if (custLat != null &&
                  custLng != null &&
                  proLat != null &&
                  proLng != null) {
                double _deg2rad(double deg) => deg * (3.141592653589793 / 180);
                double haversine(
                    double lat1, double lon1, double lat2, double lon2) {
                  const R = 6371.0; // km
                  final dLat = _deg2rad(lat2 - lat1);
                  final dLon = _deg2rad(lon2 - lon1);
                  final a = (sin(dLat / 2) * sin(dLat / 2)) +
                      cos(_deg2rad(lat1)) *
                          cos(_deg2rad(lat2)) *
                          (sin(dLon / 2) * sin(dLon / 2));
                  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
                  return R * c;
                }

                // Import math functions locally via dart:math
                // Estimate travel time at an average speed (40 km/h)
                final distanceKm = haversine(proLat, proLng, custLat, custLng);
                final avgSpeedKmh = 40.0;
                final etaMinutes = (distanceKm / avgSpeedKmh) * 60.0;
                final etaRounded = etaMinutes < 1 ? 1 : etaMinutes.round();
                await _notifDs.pushToUser(
                  targetUserId: claimed.customerId,
                  role: 'customer',
                  type: NotificationTypeStrings.bookingAccepted,
                  title: 'Handyman is on the way',
                  message:
                      'Your handyman accepted the booking. Estimated arrival: ${etaRounded} min.',
                  referenceId: claimed.id,
                  referenceType: 'booking',
                );
              } else {
                // Fallback notification without ETA
                await _notifDs.pushToUser(
                  targetUserId: claimed.customerId,
                  role: 'customer',
                  type: NotificationTypeStrings.bookingAccepted,
                  title: 'Handyman accepted your request',
                  message:
                      'A handyman accepted your booking. Please check Booking Details for more.',
                  referenceId: claimed.id,
                  referenceType: 'booking',
                );
              }
            } catch (e) {
              debugPrint('Could not compute/send ETA: $e');
              _notify('Booking accepted. Customer has been notified.');
            }
          } on BookingAlreadyClaimedException catch (e) {
            setState(
                () => _openRequests.removeWhere((r) => r.id == booking.id));
            _notify(e.message);
          } on BookingSlotLimitException catch (e) {
            // Handyman is at their tier's slot limit — show the message
            // and keep the request visible so they can try later.
            _notify(e.message);
          } catch (e) {
            _notify(e.toString().replaceFirst('Exception: ', ''));
          }
        },
        onDecline: (booking) async {
          _skipOpenRequestById(booking.id);
        },
      );
    }

    if (_navIndex == 2) {
      return EarningsHandymanScreen(
        professional: proEntity,
        professionalId: _pro?.id,
        bookings: bookingEntities,
        reviews: _reviews.map((r) => r.toEntity()).toList(),
        currentNavIndex: _navIndex,
        onNavTap: (i) {
          setState(() {
            _navIndex = i;
            _screen = 'home';
          });
        },
        onBack: () => setState(() {
          _navIndex = 0;
          _screen = 'home';
        }),
      );
    }

    if (_navIndex == 3) {
      return ProfessionalProfileScreen(
        user: u,
        professional: proEntity,
        onBack: () => setState(() => _navIndex = 0),
        onSaveProfile: (name, phone, city) async {
          await _ds.updateUserProfile(
            userId: _user!.id,
            name: name,
            phone: phone ?? '',
          );
          if (_pro != null) {
            await Supabase.instance.client
                .from('professionals')
                .update({'city': city}).eq('id', _pro!.id);
          }
          await _refreshUser();
          final updatedPro = await _ds.getProfessionalByUserId(_user!.id);
          if (mounted && updatedPro != null) {
            setState(() => _pro = updatedPro);
          }
        },
        onChangePassword: (currentPassword, newPassword) async {
          await Supabase.instance.client.auth.signInWithPassword(
            email: _user!.email,
            password: currentPassword,
          );
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
        },
        onUploadAvatar: (bytes, fileName) async {
          final publicUrl = await _ds.uploadAvatar(
            _user!.id,
            bytes,
            fileName,
          );
          await _ds.updateUserProfile(
            userId: _user!.id,
            avatarUrl: publicUrl,
          );
          await _refreshUser();
          return publicUrl;
        },
        onSaveLocation: (lat, lng) async {
          if (_pro != null) {
            await _ds.updateProfessionalLocation(
              professionalId: _pro!.id,
              latitude: lat,
              longitude: lng,
            );
            final updatedPro = await _ds.getProfessionalByUserId(_user!.id);
            if (mounted && updatedPro != null) {
              setState(() => _pro = updatedPro);
            }
          }
        },
        onPrivacyPolicy: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PrivacyPolicyScreen(
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        onLogout: () async => Supabase.instance.client.auth.signOut(),
        onReplayTour: () => setState(() {
          _navIndex = 0;
          _screen = 'home';
        }),
      );
    }

    if (_navIndex == 4) {
      return HandymanNotificationsScreen(
        userId: _user!.id,
        notificationDataSource: _notifDs,
        onBack: () => setState(() => _navIndex = 0),
        onNotificationTap: (notification) {
          if (notification.type == NotificationTypeStrings.bookingRequest) {
            setState(() => _navIndex = 1);
          }
        },
      );
    }

    return ProfessionalDashboardScreen(
      user: u,
      professional: proEntity,
      bookings: bookingEntities,
      openRequestCount:
          _openRequests.where((r) => !_skippedRequestIds.contains(r.id)).length,
      reviews: _reviews.map((r) => r.toEntity()).toList(),
      pendingApplications:
          _applications.where((a) => a.status == 'pending').length,
      currentNavIndex: _navIndex,
      onRefresh: _refreshProfessionalDashboard,
      onNavTap: (i) async {
        setState(() {
          _navIndex = i;
          _screen = 'home';
        });
        if (i == 1) await _refreshBookings();
      },
      onUpdateStatus: (booking, status) async {
        try {
          await _ds.updateBookingStatus(booking.id, status);
          await _refreshBookings();
        } catch (e) {
          _notify('Error: $e');
        }
      },
      onViewRequests: () async {
        setState(() => _navIndex = 1);
        await _refreshBookings();
      },
      onViewEarnings: () => setState(() => _navIndex = 2),
      onViewHistory: () => setState(() => _screen = 'booking_history'),
      onViewReviews: () => setState(() => _screen = 'reviews'),
      onApplyCredentials: () => setState(() => _screen = 'apply'),
      onViewVerification: () => setState(() => _screen = 'verification_status'),
      onManageServices: () => setState(() => _screen = 'my_services'),
      onShareProfile: () => _shareProProfile(),
      onViewPlan: () => setState(() => _screen = 'my_plan'),
      onToggleAvailability: (isAvailable) async {
        if (_pro == null) return;
        try {
          await _ds.updateProfessionalAvailability(
            professionalId: _pro!.id,
            available: isAvailable,
          );
          final updated = await _ds.getProfessionalByUserId(_user!.id);
          if (mounted && updated != null) setState(() => _pro = updated);
          _notify(isAvailable
              ? 'You are now Online — customers can find and book you.'
              : 'You are now Offline — you will not receive new bookings.');
        } catch (e) {
          _notify('Failed to update availability: $e');
        }
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW — CUSTOMER FLOW
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW — GUEST FLOW
  // ══════════════════════════════════════════════════════════════════════════
  // Guests can browse the customer dashboard, view professionals and their
  // profiles, and use the All Professionals screen. Every action that requires
  // an account (booking, profile, bookings tab) shows _showGuestPrompt().

  void _showGuestPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create a Free Account',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign up to book a service, track your jobs,\nand manage your profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textMedium, height: 1.5),
          ),
          const SizedBox(height: 24),
          // Sign Up — primary
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Tell AppNavigator to open RegisterScreen after sign-out
                widget.onSignUpFromGuest?.call();
                await Supabase.instance.client.auth.signOut();
                if (mounted) setState(() => _isGuest = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Sign Up — It\'s Free',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          // Log In — secondary
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Explicitly tell AppNavigator to open LoginScreen.
                widget.onLoginFromGuest?.call();
                await Supabase.instance.client.auth.signOut();
                if (mounted) setState(() => _isGuest = false);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Already have an account? Log In',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _guestFlow() {
    // Guest _screen state — only 'home', 'professional_profile',
    // and 'explore' are reachable.
    if (_screen == 'explore') {
      return AllProfessionalsScreen(
        ds: _ds,
        onBack: () => setState(() => _screen = 'home'),
        onProfessionalTap: (entity) => _navigateToProProfile(entity),
      );
    }

    if (_screen == 'professional_profile' && _selectedPro != null) {
      return customer.ProfessionalProfileScreen(
        professional: (_selectedProFresh ?? _selectedPro!).toEntity(),
        reviews: _proReviews.map((r) => r.toEntity()).toList(),
        onBack: () => setState(() {
          _screen = _profileReturnScreen;
          _proReviews = [];
          _selectedProFresh = null;
        }),
        // Booking is restricted for guests — show sign-up prompt
        onBookNow: (_) => _showGuestPrompt(context),
      );
    }

    // Default: guest customer dashboard
    return CustomerDashboardScreen(
      user: null, // guest has no user record
      professionals: _professionals.map((p) => p.toEntity()).toList(),
      recentBookings: const [],
      serviceOffers: _serviceOffers,
      currentNavIndex: 0,
      onNavTap: (i) {
        if (i == 1 || i == 2) {
          // Bookings and Profile tabs require an account
          _showGuestPrompt(context);
        }
        // Index 0 (Home) is always allowed
      },
      onRequestService: () => _showGuestPrompt(context),
      onRequestServiceWithType: (_, __, ___) => _showGuestPrompt(context),
      onViewBookings: () => _showGuestPrompt(context),
      onBookingTap: (_) => _showGuestPrompt(context),
      // onFilterBySkill: filtering is handled entirely by local state inside
      // CustomerDashboardScreen (_selectedSkill). No network call needed —
      // calling getProfessionals(skill:) here would overwrite _professionals
      // and trigger a parent rebuild that resets the child's filter state.
      onFilterBySkill: (_) {},
      onProfessionalTap: (entity) {
        final model = _professionals.firstWhere((p) => p.id == entity.id);
        setState(() {
          _selectedPro = model;
          _selectedProFresh = null;
          _proReviews = [];
          _profileReturnScreen = 'home';
          _screen = 'professional_profile';
        });
        _ds.getProfessionalById(entity.id).then((freshPro) {
          if (!mounted) return;
          if (freshPro != null) setState(() => _selectedProFresh = freshPro);
        }).catchError((e) {
          debugPrint('Could not load fresh professional: $e');
        });
        _ds.getProfessionalReviewsById(entity.id).then((reviews) {
          if (!mounted) return;
          setState(() => _proReviews = reviews);
        }).catchError((e) {
          debugPrint('Could not load pro reviews: $e');
        });
      },
      onViewAllProfessionals: () => setState(() => _screen = 'explore'),
      onProfileTap: () => _showGuestPrompt(context),
      onRefresh: () async {
        try {
          final pros = await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
          final offers = await _ds.getServiceOffers();
          if (mounted)
            setState(() {
              _professionals = pros;
              _serviceOffers = offers;
            });
        } catch (e) {
          debugPrint('Guest refresh error: $e');
        }
      },
      featuredProfessionals: _professionals
          .where((p) => p.subscriptionTier >= 2)
          .map((p) => p.toEntity())
          .toList(),
    );
  }

  Widget _customerFlow() {
    final bookingEntities = _bookings.map((b) => b.toEntity()).toList();
    // _navIndex==1 → Explore tab (AllProfessionalsScreen)
    if (_navIndex == 1) {
      return AllProfessionalsScreen(
        ds: _ds,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = i == 3 ? 'profile' : 'home';
        }),
        // onBack is null — this is a tab, not a pushed screen
        onProfessionalTap: (entity) => _navigateToProProfile(entity),
      );
    }

    if (_navIndex == 2 && _screen == 'home') {
      return CustomerBookingsScreen(
        bookings: bookingEntities,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = i == 3 ? 'profile' : 'home';
        }),
        onRefresh: _refreshBookings,
        onBookingTap: (booking) {
          final model = _bookings.firstWhere((b) => b.id == booking.id,
              orElse: () => _bookings.first);
          setState(() {
            _selectedBooking = model;
            _screen = 'booking_status';
          });
          _subscribeToBooking(model);
        },
        onBackjob: (booking) => _navigateToBackjob(booking),
      );
    }

    if (_navIndex == 2 && _screen == 'notifications') {
      return NotificationsScreen(
        userId: _user!.id,
        notificationDataSource: _notifDs,
        onBack: () => setState(() {
          _screen = 'home';
          _navIndex = 0;
          _unreadNotifCount = 0;
        }),
        onNotificationTap: (notification) {
          if (notification.referenceType == 'booking' &&
              notification.referenceId != null) {
            final booking = _bookings
                .firstWhereOrNull((b) => b.id == notification.referenceId);
            if (booking != null) {
              setState(() {
                _selectedBooking = booking;
                _screen = 'booking_status';
              });
            }
          }
        },
      );
    }

    switch (_screen) {
      case 'request_service':
        return RequestServiceScreen(
          professionals: _professionals,
          serviceOffers: _serviceOffers,
          initialServiceType: _preselectedServiceType,
          initialProblemTitle: _preselectedProblemTitle,
          initialDescription: _preselectedDescription,
          targetProfessionalId: _selectedPro?.id,
          qualifiedProfessionalIds: _qualifiedProfessionalIds,
          directBookingOffers: _directBookingOffers,
          onBack: () => setState(() {
            _screen = 'home';
            _preselectedServiceType = null;
            _preselectedProblemTitle = null;
            _preselectedDescription = null;
            _selectedPro = null;
            _qualifiedProfessionalIds = {};
            _directBookingOffers = [];
          }),
          onSubmit: (result) async {
            try {
              // ── description: issue title + detail (shown as "Issue Details"
              //    in the handyman's booking detail view).
              final issueDescription = [
                if (result.problemTitle.isNotEmpty) result.problemTitle,
                if (result.description.isNotEmpty) result.description,
              ].join('\n').trim();

              // ── notes: the customer's optional P.S. field only — no price
              //    range or problem title mixed in here any more.
              final customerNotes = (result.notes?.trim().isEmpty ?? true)
                  ? null
                  : result.notes!.trim();

              final lowestPrice = result.matchedPros.isNotEmpty
                  ? result.matchedPros
                      .map((p) => p.priceMin ?? 0.0)
                      .reduce((a, b) => a < b ? a : b)
                  : null;

              // If we don't have a numeric lowestPrice from matched pros,
              // try to parse the minimum value from the textual priceRange
              // selected by the customer (e.g. "₱300 – ₱1,800").
              double? parsedMinFromRange;
              if ((lowestPrice == null || lowestPrice == 0.0) &&
                  result.priceRange != null &&
                  result.priceRange!.isNotEmpty) {
                try {
                  final m =
                      RegExp(r"(\d+[\d,]*)").firstMatch(result.priceRange!);
                  if (m != null) {
                    parsedMinFromRange =
                        double.parse(m.group(1)!.replaceAll(',', ''));
                  }
                } catch (_) {}
              }

              // When coming from a professional's profile, _selectedPro is set
              // and result.matchedPros contains only that one professional.
              // Pass their ID directly so the booking is assigned to them alone
              // instead of being broadcast as an open request.
              final isDirectBooking = _selectedPro != null &&
                  result.matchedPros.length == 1 &&
                  result.matchedPros.first.id == _selectedPro!.id;

              final booking = await _ds.createBooking(
                customerId: _user!.id,
                professionalId: isDirectBooking ? _selectedPro!.id : null,
                serviceType: result.serviceType,
                serviceTitle: result.serviceName,
                scheduledDate: result.preferredDate,
                description: issueDescription.isEmpty ? null : issueDescription,
                notes: customerNotes,
                address: result.address,
                priceEstimate: lowestPrice ?? parsedMinFromRange,
                latitude: result.latitude,
                longitude: result.longitude,
                photoPath: result.photoPath,
              );

              _subscribeToBooking(booking);
              await _refreshBookings();

              final priceSnippet =
                  (result.priceRange != null && result.priceRange!.isNotEmpty)
                      ? ' Estimated range: ${result.priceRange}.'
                      : '';

              for (final pro in result.matchedPros) {
                try {
                  await _notifDs.pushToUser(
                    targetUserId: pro.userId,
                    role: 'professional',
                    type: NotificationTypeStrings.bookingRequest,
                    title: isDirectBooking
                        ? 'New Direct Booking Request'
                        : 'New Booking Request',
                    message: isDirectBooking
                        ? 'A customer has requested you directly for '
                            '${result.serviceType} service near '
                            '${result.address.split(',').first}.$priceSnippet'
                        : 'A customer needs ${result.serviceType} service'
                            ' near ${result.address.split(',').first}.$priceSnippet',
                    referenceId: booking.id,
                    referenceType: 'booking',
                  );
                } catch (e) {
                  debugPrint('[Notify] Could not notify pro ${pro.id}: $e');
                }
              }

              final created =
                  _bookings.firstWhereOrNull((b) => b.id == booking.id) ??
                      booking;

              if (mounted) {
                setState(() {
                  _selectedBooking = created;
                  _screen = 'booking_status';
                });
              }

              _notify(isDirectBooking
                  ? 'Request sent directly to your chosen handyman.'
                  : 'Request sent. Looking for an available handyman.');
            } on BookingSlotLimitException catch (e) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.message),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
            } catch (e) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(e.toString().replaceFirst('Exception: ', '')),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
            }
          },
        );

      case 'professional_profile':
        if (_selectedPro == null) return _home();
        return customer.ProfessionalProfileScreen(
          professional: (_selectedProFresh ?? _selectedPro!).toEntity(),
          reviews: _proReviews.map((r) => r.toEntity()).toList(),
          onBack: () => setState(() {
            _screen = _profileReturnScreen;
            _proReviews = [];
            _selectedProFresh = null;
          }),
          onBookNow: (serviceType) {
            final pro = _selectedProFresh ?? _selectedPro;
            if (pro != null) _navigateToDirectBooking(pro);
          },
        );

      case 'booking':
        if (_selectedPro == null) return _home();
        return customer.BookingScreen(
          professional: (_selectedProFresh ?? _selectedPro!).toEntity(),
          onBack: () => setState(() => _screen = 'professional_profile'),
          onConfirmBooking: _createBooking,
        );

      // booking_status — exposes onConfirmCompletion, onLeaveReview, hasReviewed.
      // Review navigation is driven by the onLeaveReview callback here so the
      // review button is always reachable for completed, unreviewed bookings.
      case 'booking_status':
        if (_selectedBooking == null) return _home();
        return BookingStatusScreen(
          booking: _selectedBooking!.toEntity(),
          onBack: () => setState(() => _screen = 'home'),
          // onViewAssessment routes to AssessmentScreen where customer
          // reviews the price and confirms → inProgress.
          onViewAssessment: _selectedBooking!.status == BookingStatus.assessment
              ? () => setState(() => _screen = 'assessment')
              : null,
          // onReviewSchedule routes to ScheduleReviewScreen — only shown when
          // the handyman has proposed a reschedule (scheduleProposed status).
          // The customer taps Accept on the _RescheduleReviewCard which calls
          // this, navigating to the full ScheduleReviewScreen for confirmation.
          onReviewSchedule:
              _selectedBooking!.status == BookingStatus.scheduleProposed
                  ? () => setState(() => _screen = 'schedule_review')
                  : null,
          // Customer declines a reschedule directly from the booking status card.
          onDeclineSchedule:
              _selectedBooking!.status == BookingStatus.scheduleProposed
                  ? _handleDeclineSchedule
                  : null,
          // Customer confirms the handyman has arrived on-site.
          // pendingArrivalConfirmation → assessment.
          onConfirmArrival: _selectedBooking!.status ==
                  BookingStatus.pendingArrivalConfirmation
              ? _handleConfirmArrival
              : null,
          // Customer confirms job is done (pendingCustomerConfirmation → completed).
          onConfirmCompletion: _selectedBooking!.status ==
                  BookingStatus.pendingCustomerConfirmation
              ? _handleCustomerConfirmCompletion
              : null,
          // Load completion proof photos for the customer to review before
          // confirming. Only fetched when status is pendingCustomerConfirmation.
          onLoadCompletionPhotos: _selectedBooking!.status ==
                  BookingStatus.pendingCustomerConfirmation
              ? (bookingId) => _ds.getCompletionPhotos(bookingId)
              : null,
          // Review CTA: shown for completed bookings the customer hasn't reviewed.
          onLeaveReview: _selectedBooking!.status == BookingStatus.completed &&
                  !_reviewedBookingIds.contains(_selectedBooking!.id)
              ? () => setState(() => _screen = 'review')
              : null,
          hasReviewed: _reviewedBookingIds.contains(_selectedBooking!.id),
          // Book Again CTA: shown for completed bookings that had an assigned
          // professional. Routes to RebookScreen (one-tap confirmation flow)
          // instead of the full RequestServiceScreen wizard.
          onBookAgain: _selectedBooking!.status == BookingStatus.completed &&
                  _selectedBooking!.professionalId != null
              ? (booking) => _navigateToRebook(booking)
              : null,
          // Backjob CTA: shown for completed bookings still within their
          // warranty window. booking.isUnderWarranty is computed from
          // warrantyExpiresAt written when customerConfirmCompletion fires.
          onBackjob: _selectedBooking!.status == BookingStatus.completed &&
                  _selectedBooking!.toEntity().isUnderWarranty
              ? () => _navigateToBackjob(_selectedBooking!.toEntity())
              : null,
          onCancel: (_selectedBooking!.status == BookingStatus.pending ||
                  _selectedBooking!.status == BookingStatus.accepted ||
                  _selectedBooking!.status == BookingStatus.scheduleProposed ||
                  _selectedBooking!.status == BookingStatus.scheduled)
              ? () async {
                  try {
                    await _ds.updateBookingStatus(
                        _selectedBooking!.id, BookingStatus.cancelled);
                    await _refreshBookings();
                    final updated = _bookings.firstWhere(
                        (b) => b.id == _selectedBooking!.id,
                        orElse: () => _selectedBooking!);
                    if (mounted)
                      setState(() {
                        _selectedBooking = updated;
                        _screen = 'booking_status';
                      });
                    _notify('Booking cancelled.');
                  } catch (e) {
                    _notify('Error: $e');
                  }
                }
              : null,
        );

      // ── Backjob / Warranty claim screen ────────────────────────────────
      case 'backjob':
        if (_selectedBooking == null) return _home();
        return BackjobScreen(
          booking: _selectedBooking!.toEntity(),
          onBack: () => setState(() => _screen = 'booking_status'),
          onSubmit: (data) => _handleBackjobSubmit(data),
        );

      // ── One-tap rebook confirmation screen ─────────────────────────────
      // Pre-fills everything from the original completed booking.
      // Customer only picks a date then taps Confirm — no wizard.
      case 'rebook':
        if (_selectedBooking == null) return _home();
        return RebookScreen(
          booking: _selectedBooking!.toEntity(),
          onBack: () => setState(() => _screen = 'booking_status'),
          onConfirm: (data) => _handleRebookConfirm(data),
        );

      case 'schedule_review':
        if (_selectedBooking == null) return _home();
        return ScheduleReviewScreen(
          booking: _selectedBooking!.toEntity(),
          onBack: () => setState(() => _screen = 'booking_status'),
          onAccept: _handleAcceptSchedule,
          onDecline: _handleDeclineSchedule,
          // onProposeAlternative retained for signature compat but not shown in UI.
        );

      case 'assessment':
        if (_selectedBooking == null) return _home();
        return AssessmentScreen(
          booking: _selectedBooking!.toEntity(),
          onBack: () => setState(() => _screen = 'booking_status'),
          onConfirm: () async {
            try {
              await _ds.confirmAssessment(_selectedBooking!.id);
              await _refreshBookings();
              final updated = _bookings.firstWhere(
                  (b) => b.id == _selectedBooking!.id,
                  orElse: () => _selectedBooking!);
              setState(() {
                _selectedBooking = updated;
                _screen = 'booking_status';
              });
              _notify('Service started. Your handyman is on the way.');
            } catch (e) {
              _notify('Error: $e');
            }
          },
          onDecline: () async {
            try {
              await _ds.updateBookingStatus(
                  _selectedBooking!.id, BookingStatus.cancelled);
              await _refreshBookings();
              final updated = _bookings.firstWhere(
                  (b) => b.id == _selectedBooking!.id,
                  orElse: () => _selectedBooking!);
              setState(() {
                _selectedBooking = updated;
                _screen = 'booking_status';
              });
              _notify('Booking cancelled.');
            } catch (e) {
              _notify('Error: $e');
            }
          },
        );

      case 'review':
        if (_selectedBooking == null) return _home();
        return ReviewScreen(
          booking: _selectedBooking!.toEntity(),
          onBack: () => setState(() => _screen = 'booking_status'),
          onSubmitReview: _submitReview,
        );

      case 'profile':
        return CustomerProfileScreen(
          user: _user?.toEntity(),
          onBack: () => setState(() {
            _screen = 'home';
            _navIndex = 0;
          }),
          onSaveProfile: (name, phone) async {
            await _ds.updateUserProfile(
              userId: _user!.id,
              name: name,
              phone: phone ?? '',
            );
            await _refreshUser();
          },
          onChangePassword: (currentPassword, newPassword) async {
            await Supabase.instance.client.auth.signInWithPassword(
              email: _user!.email,
              password: currentPassword,
            );
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(password: newPassword),
            );
          },
          onUploadAvatar: (bytes, fileName) async {
            final publicUrl = await _ds.uploadAvatar(
              _user!.id,
              bytes,
              fileName,
            );
            await _ds.updateUserProfile(
              userId: _user!.id,
              avatarUrl: publicUrl,
            );
            await _refreshUser();
            return publicUrl;
          },
          onPrivacyPolicy: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PrivacyPolicyScreen(
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          onLogout: () async => Supabase.instance.client.auth.signOut(),
          onReplayTour: () => setState(() {
            _navIndex = 0;
            _screen = 'home';
          }),
        );

      // 'explore' → navigate to Explore tab (navIndex 1)
      case 'explore':
        return AllProfessionalsScreen(
          ds: _ds,
          currentNavIndex: 1,
          onNavTap: (i) => setState(() {
            _navIndex = i;
            _screen = i == 3 ? 'profile' : 'home';
          }),
          onProfessionalTap: (entity) => _navigateToProProfile(entity),
        );

      default:
        return _home();
    }
  }

  // ── VIEW — customer dashboard (default screen) ────────────────────────────
  Widget _home() => CustomerDashboardScreen(
        user: _user?.toEntity(),
        professionals: _professionals.map((p) => p.toEntity()).toList(),
        recentBookings: _bookings.map((b) => b.toEntity()).toList(),
        // CONTROLLER → VIEW: pass approved DB offers so the dashboard renders
        // live data instead of the hardcoded _allServices fallback list.
        serviceOffers: _serviceOffers,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = i == 3 ? 'profile' : 'home';
        }),
        onRequestService: () => setState(() {
          _preselectedServiceType = null;
          _preselectedProblemTitle = null;
          _preselectedDescription = null;
          _selectedPro = null;
          _qualifiedProfessionalIds = {};
          _directBookingOffers = [];
          _screen = 'request_service';
        }),
        onRequestServiceWithType: (serviceType, serviceName, description) =>
            _navigateToRequestServiceWithOffer(
          serviceType: serviceType,
          serviceName: serviceName,
          description: description.isNotEmpty ? description : null,
        ),
        onViewBookings: () => setState(() {
          _navIndex = 2;
          _screen = 'home';
        }),
        onBookingTap: (booking) {
          final model = _bookings.firstWhere((b) => b.id == booking.id,
              orElse: () => _bookings.first);
          setState(() {
            _selectedBooking = model;
            _screen = 'booking_status';
          });
          _subscribeToBooking(model);
        },
        // onFilterBySkill: filtering is handled entirely by local state inside
        // CustomerDashboardScreen (_selectedSkill). No network call needed —
        // calling getProfessionals(skill:) here would overwrite _professionals
        // and trigger a parent rebuild that resets the child's filter state.
        onFilterBySkill: (_) {},
        onProfessionalTap: (entity) {
          final model = _professionals.firstWhere((p) => p.id == entity.id);
          setState(() {
            _selectedPro = model;
            _selectedProFresh = null;
            _proReviews = [];
            _profileReturnScreen = 'home';
            _screen = 'professional_profile';
          });
          _ds.getProfessionalById(entity.id).then((freshPro) {
            if (!mounted) return;
            if (freshPro != null) setState(() => _selectedProFresh = freshPro);
          }).catchError((e) {
            debugPrint('Could not load fresh professional: $e');
          });

          _ds.getProfessionalReviewsById(entity.id).then((reviews) {
            if (!mounted) return;
            setState(() => _proReviews = reviews);
          }).catchError((e) {
            debugPrint('Could not load pro reviews: $e');
          });
        },
        onViewAllProfessionals: () => setState(() => _navIndex = 1),
        onProfileTap: () {
          setState(() {
            _navIndex = 3;
            _screen = 'profile';
          });
        },
        onNotificationsViewed: () => setState(() => _unreadNotifCount = 0),
        // Elite handymen (Tier 2) shown in the Featured row above the catalogue.
        featuredProfessionals: _professionals
            .where((p) => p.subscriptionTier >= 2)
            .map((p) => p.toEntity())
            .toList(),
        // CONTROLLER: pull-to-refresh reloads professionals, bookings,
        // AND service offers so the customer always sees live data.
        onRefresh: _refreshCustomerDashboard,
      );

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLLER — booking creation & review submission
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _createBooking(
      DateTime date, String serviceType, String? notes, String? address,
      {double? latitude, double? longitude}) async {
    if (_user == null || _selectedPro == null) return;
    try {
      final booking = await _ds.createBooking(
        customerId: _user!.id,
        professionalId: _selectedPro!.id,
        serviceType: serviceType,
        scheduledDate: date,
        notes: notes,
        address: address,
        priceEstimate: _selectedPro!.priceMin,
        latitude: latitude,
        longitude: longitude,
      );
      await _refreshBookings();
      final refreshed =
          _bookings.firstWhereOrNull((b) => b.id == booking.id) ?? booking;
      setState(() {
        _selectedBooking = refreshed;
        _screen = 'booking_status';
      });
      _subscribeToBooking(booking);
    } on BookingSlotLimitException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _submitReview(int rating, String? comment) async {
    if (_user == null || _selectedBooking == null) return;
    try {
      await _ds.createReview(
        bookingId: _selectedBooking!.id,
        customerId: _user!.id,
        professionalId: _selectedBooking!.professionalId,
        rating: rating,
        comment: comment,
      );
      setState(() {
        _reviewedBookingIds.add(_selectedBooking!.id);
        _screen = 'booking_status';
      });
      _notify('Review submitted. Thank you.');
      try {
        final updated = await _ds.getProfessionalsPaged(page: 0, pageSize: 20);
        if (mounted) setState(() => _professionals = updated);
      } catch (e) {
        debugPrint('Could not refresh professionals after review: $e');
      }
    } catch (e) {
      debugPrint('Review error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('already submitted')
                  ? 'You\'ve already reviewed this booking.'
                  : 'Failed to submit review. Please try again.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
