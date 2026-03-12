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
import 'package:fixify/presentation/screens/professional/earnings.dart';
import 'package:fixify/presentation/screens/professional/pro_booking_detail_screen.dart';
import 'package:fixify/presentation/screens/customer/schedule_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:fixify/presentation/screens/auth/login_screen.dart';
import 'package:fixify/presentation/screens/auth/register_screen.dart';
import 'package:fixify/presentation/screens/customer/dashboard_customer.dart';
import 'package:fixify/presentation/screens/customer/profile_customer.dart';
import 'package:fixify/presentation/screens/customer/requestservice_customer.dart';
import 'package:fixify/presentation/screens/customer/bookings_customer.dart';
import 'package:fixify/presentation/screens/customer/professional_profile_screen.dart'
    as customer;
import 'package:fixify/presentation/screens/customer/booking_status_screen.dart';
import 'package:fixify/presentation/screens/customer/review_screen.dart';
import 'package:fixify/presentation/screens/customer/notifications.dart';
import 'package:fixify/presentation/screens/customer/assessment_screen.dart';
import 'package:fixify/presentation/screens/professional/dashboard_professional.dart';
import 'package:fixify/presentation/screens/professional/profile_professional.dart';
import 'package:fixify/presentation/screens/professional/apply_professional.dart';
import 'package:fixify/presentation/screens/professional/verificationstatus_professional.dart';
import 'package:fixify/presentation/screens/professional/booking_requests_professional.dart';
import 'package:fixify/presentation/screens/professional/booking_history_professional.dart';
import 'package:fixify/presentation/screens/professional/reviews_professional.dart';
import 'package:fixify/presentation/screens/professional/notificationhandyman.dart';
import 'package:fixify/presentation/screens/admin/dashboard_admin.dart';
import 'package:fixify/presentation/screens/admin/profile_admin.dart';
import 'package:fixify/presentation/screens/admin/approvals_admin.dart';
import 'package:fixify/presentation/screens/admin/notificationsadmin.dart';
import 'package:fixify/presentation/screens/customer/privacy_policy_screen.dart';

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
      title: 'Fixify',
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

  final _authFlowKey = GlobalKey();
  late final Widget _authFlow;

  @override
  void initState() {
    super.initState();
    _authFlow = AuthFlow(key: _authFlowKey);
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
    return _isLoggedIn ? const MainApp() : _authFlow;
  }
}

// ── AUTH ──────────────────────────────────────────────

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showSplash = true;
  bool _showRegister = false;
  String? _prefillEmail;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return SplashScreen();

    if (_showRegister) {
      return RegisterScreen(
        onNavigateToLogin: () => setState(() {
          _showRegister = false;
          _prefillEmail = null;
        }),
        onSuccess: (email) => setState(() {
          _showRegister = false;
          _prefillEmail = email;
        }),
      );
    }

    return LoginScreen(
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
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  // ── MODEL layer references ────────────────────────────────────────────────
  // These data sources encapsulate all DB/API interactions (Model layer).
  late final SupabaseDataSource _ds;
  late final ApplicationDataSource _appDs;
  late final NotificationDataSource _notifDs;

  // ── Controller state ──────────────────────────────────────────────────────
  DateTime? _lastBackPress;
  String? _preselectedServiceType;
  String? _preselectedProblemTitle;

  // ── Model state (data held by Controller for View consumption) ────────────
  UserModel? _user;
  ProfessionalModel? _pro;
  List<ProfessionalModel> _professionals = [];
  List<BookingModel> _bookings = [];

  // Open (unassigned) booking requests visible to this professional.
  List<BookingModel> _openRequests = [];

  List<ApplicationModel> _applications = [];
  List<ReviewModel> _reviews = [];
  int _navIndex = 0;
  String _screen = 'home';
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
          title: 'Schedule Confirmed!',
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

  /// Professional proposes an initial schedule for a booking.
  /// Validation (past-time guard) is enforced in SupabaseDataSource.proposeSchedule().
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

  /// Customer confirms that the professional has completed the job.
  /// Transitions status: pendingCustomerConfirmation → completed.
  Future<void> _handleCustomerConfirmCompletion() async {
    if (_selectedBooking == null) return;
    try {
      // Model: persist completion confirmation.
      final updated = await _ds.customerConfirmCompletion(_selectedBooking!.id);
      // Model: keep local list consistent.
      _updateBookingInList(updated);
      // View: reflect updated status.
      setState(() {
        _selectedBooking = updated;
        _screen = 'booking_status';
      });
      _notify('Job confirmed as complete! Thank you. ✅');
      // Model: notify the professional.
      final proUserId = updated.professional?.userId;
      if (proUserId != null) {
        await _notifDs.pushToUser(
          targetUserId: proUserId,
          role: 'professional',
          type: NotificationTypeStrings.bookingAccepted,
          title: 'Job Confirmed Complete!',
          message:
              '${_user?.name ?? 'The customer'} has confirmed your job is done. Great work!',
          referenceId: updated.id,
          referenceType: 'booking',
        );
      }
    } catch (e) {
      _notify('Failed to confirm completion: $e');
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
      _user = await _ds.getCurrentUser();
      if (_user != null) {
        _professionals = await _ds.getProfessionals();

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
            );
            _applications = await _appDs.getMyApplications(_pro!.id);
            _reviews = await _ds.getProfessionalReviews(_pro!.id);

            _openRequestsChannel = _ds.subscribeToOpenBookingRequests(
              skills: _pro!.skills,
              onNewRequest: (newRequest) {
                if (!mounted) return;
                if (!_openRequests.any((r) => r.id == newRequest.id)) {
                  setState(
                      () => _openRequests = [newRequest, ..._openRequests]);
                  _notify('New booking request!');
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

            _appDs.subscribeToMyApplications(
              professionalId: _pro!.id,
              onUpdate: (a) {
                setState(() => _applications =
                    _applications.map((x) => x.id == a.id ? a : x).toList());
                if (a.status == 'approved')
                  _notify('Your ${a.serviceType} application was approved!');
                if (a.status == 'rejected')
                  _notify('Your ${a.serviceType} application was reviewed.');
                _ds
                    .getProfessionals()
                    .then((list) => setState(() => _professionals = list));
              },
            );
          }
        } else if (_user!.role == 'admin') {
          _applications = await _appDs.getAllApplications();
        } else {
          // ── Customer ──────────────────────────────────────────────────
          _bookings = await _ds.getCustomerBookings(_user!.id);

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
                final updated = await _ds.getProfessionals();
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

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLLER — refresh helpers (Model re-fetch → View setState)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _refreshBookings() async {
    try {
      if (_user == null) return;
      if (_user!.isProfessional && _pro != null) {
        final assigned = await _ds.getProfessionalBookings(_pro!.id);
        final open = await _ds.getOpenBookingRequests(skills: _pro!.skills);
        if (mounted)
          setState(() {
            _bookings = _deduped(assigned);
            _openRequests = open;
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
      final pros = await _ds.getProfessionals();
      final bookings = await _ds.getCustomerBookings(_user!.id);
      if (mounted)
        setState(() {
          _professionals = pros;
          _bookings = _deduped(bookings);
        });
    } catch (e) {
      debugPrint('Pull-to-refresh (customer) error: $e');
    }
  }

  Future<void> _refreshProfessionalDashboard() async {
    if (_user == null || _pro == null) return;
    try {
      final bookings = await _ds.getProfessionalBookings(_pro!.id);
      final open = await _ds.getOpenBookingRequests(skills: _pro!.skills);
      final reviews = await _ds.getProfessionalReviews(_pro!.id);
      final updatedPro = await _ds.getProfessionalByUserId(_user!.id);
      if (mounted)
        setState(() {
          _bookings = _deduped(bookings);
          _openRequests = open;
          _reviews = reviews;
          if (updatedPro != null) _pro = updatedPro;
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
        onBack: () => setState(() => _navIndex = 0),
        onApprove: (app) async {
          try {
            await _appDs.approveApplication(app);
            _applications = await _appDs.getAllApplications();
            _professionals = await _ds.getProfessionals();
            setState(() {});
            _notify('${app.applicantName} approved for ${app.serviceType}!');
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
            _professionals = await _ds.getProfessionals();
            setState(() {});
            _notify('${app.applicantName} approved for ${app.serviceType}!');
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

    final pending = _applications.where((a) => a.status == 'pending').length;
    return AdminDashboardScreen(
      adminUserId: _user!.id,
      adminName: _user!.name,
      pendingApprovals: pending,
      totalUsers: _professionals.length,
      totalEarnings: _bookings
          .where((b) => b.status == BookingStatus.completed)
          .fold(0.0, (s, b) => s + (b.priceEstimate ?? 0)),
      completedBookings:
          _bookings.where((b) => b.status == BookingStatus.completed).length,
      currentNavIndex: _navIndex,
      onNavTap: (i) => setState(() => _navIndex = i),
      onHandymanApprovals: () => setState(() => _navIndex = 1),
      onAnalytics: () => setState(() => _navIndex = 2),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VIEW — PROFESSIONAL FLOW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _professionalFlow() {
    final u = _user!.toEntity();
    final proEntity = _pro?.toEntity();
    final bookingEntities = _bookings.map((b) => b.toEntity()).toList();
    final openRequestEntities = _openRequests.map((b) => b.toEntity()).toList();

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
        onMarkComplete: () async {
          try {
            final updated = await _ds.markJobDoneByPro(_selectedProBooking!.id);
            _updateBookingInList(updated);
            if (mounted) {
              setState(() => _selectedProBooking = updated.toEntity());
            }
            _notify('Job marked as done! Waiting for customer confirmation. ✅');
          } catch (e) {
            _notify('Error updating status: $e');
            rethrow;
          }
        },
        onProposeSchedule: _handleProposeSchedule,
        onProposeReschedule: _handleProposeReschedule,
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
      final proId = _pro?.id;
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
        onBack: () => setState(() => _screen = 'home'),
        onApplyNew: () => setState(() => _screen = 'apply'),
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
              _notify('Booking accepted! Customer has been notified. ✅');
            }
          } on BookingAlreadyClaimedException catch (e) {
            setState(
                () => _openRequests.removeWhere((r) => r.id == booking.id));
            _notify(e.message);
          } catch (e) {
            _notify('Error: $e');
          }
        },
        onDecline: (booking) async {
          setState(() => _openRequests.removeWhere((r) => r.id == booking.id));
          _notify('Request dismissed.');
        },
      );
    }

    if (_navIndex == 2) {
      return EarningsHandymanScreen(
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
      openRequestCount: _openRequests.length,
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

  Widget _customerFlow() {
    final bookingEntities = _bookings.map((b) => b.toEntity()).toList();

    if (_navIndex == 1 && _screen == 'home') {
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
          initialServiceType: _preselectedServiceType,
          initialProblemTitle: _preselectedProblemTitle,
          targetProfessionalId: _selectedPro?.id,
          onBack: () => setState(() {
            _screen = 'home';
            _preselectedServiceType = null;
            _preselectedProblemTitle = null;
            _selectedPro = null;
          }),
          onSubmit: (result) async {
            try {
              final notesText = [
                result.problemTitle,
                if (result.priceRange != null && result.priceRange!.isNotEmpty)
                  'Price Range: ${result.priceRange}',
                if (result.description.isNotEmpty) result.description,
                if (result.notes != null) result.notes!,
              ].join('\n');

              final lowestPrice = result.matchedPros.isNotEmpty
                  ? result.matchedPros
                      .map((p) => p.priceMin ?? 0.0)
                      .reduce((a, b) => a < b ? a : b)
                  : null;

              final booking = await _ds.createBooking(
                customerId: _user!.id,
                professionalId: null,
                serviceType: result.serviceType,
                scheduledDate: result.preferredDate,
                notes: notesText,
                address: result.address,
                priceEstimate: lowestPrice,
                latitude: result.latitude,
                longitude: result.longitude,
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
                    title: 'New Booking Request',
                    message: 'A customer needs ${result.serviceType} service'
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

              _notify('Request sent! Looking for an available handyman...');
            } catch (e) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Request failed: $e')));
            }
          },
        );

      case 'professional_profile':
        if (_selectedPro == null) return _home();
        return customer.ProfessionalProfileScreen(
          professional: (_selectedProFresh ?? _selectedPro!).toEntity(),
          reviews: _proReviews.map((r) => r.toEntity()).toList(),
          onBack: () => setState(() {
            _screen = 'home';
            _proReviews = [];
            _selectedProFresh = null;
          }),
          onBookNow: () => setState(() => _screen = 'request_service'),
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
          onViewAssessment: _selectedBooking!.status == BookingStatus.assessment
              ? () => setState(() => _screen = 'assessment')
              : null,
          onReviewSchedule: () => setState(() => _screen = 'schedule_review'),
          // Customer confirms job is done (pendingCustomerConfirmation → completed).
          onConfirmCompletion: _selectedBooking!.status ==
                  BookingStatus.pendingCustomerConfirmation
              ? _handleCustomerConfirmCompletion
              : null,
          // Review CTA: shown for completed bookings the customer hasn't reviewed.
          onLeaveReview: _selectedBooking!.status == BookingStatus.completed &&
                  !_reviewedBookingIds.contains(_selectedBooking!.id)
              ? () => setState(() => _screen = 'review')
              : null,
          hasReviewed: _reviewedBookingIds.contains(_selectedBooking!.id),
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
              _notify('Service started! Your handyman is on the way. 🔧');
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
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = i == 2 ? 'profile' : 'home';
        }),
        onRequestService: () => setState(() {
          _preselectedServiceType = null;
          _preselectedProblemTitle = null;
          _selectedPro = null;
          _screen = 'request_service';
        }),
        onRequestServiceWithType: (serviceType, serviceName) => setState(() {
          _preselectedServiceType = serviceType;
          _preselectedProblemTitle = serviceName;
          _selectedPro = null;
          _screen = 'request_service';
        }),
        onViewBookings: () => setState(() {
          _navIndex = 1;
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
        onFilterBySkill: (skill) async {
          try {
            final list = skill == 'All'
                ? await _ds.getProfessionals()
                : await _ds.getProfessionals(skill: skill);
            setState(() => _professionals = list);
          } catch (e) {
            debugPrint('Filter error: $e');
          }
        },
        onProfessionalTap: (entity) {
          final model = _professionals.firstWhere((p) => p.id == entity.id);
          setState(() {
            _selectedPro = model;
            _selectedProFresh = null;
            _proReviews = [];
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
        onProfileTap: () {
          setState(() {
            _navIndex = 3;
            _screen = 'profile';
          });
        },
        onNotificationsViewed: () => setState(() => _unreadNotifCount = 0),
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
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Booking failed: $e')));
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
      _notify('Review submitted! Thank you. ⭐');
      try {
        final updated = await _ds.getProfessionals();
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
