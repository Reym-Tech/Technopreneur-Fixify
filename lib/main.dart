// lib/main.dart

import 'package:fixify/presentation/screens/admin/superadmin_analytics.dart';
import 'package:fixify/presentation/screens/professional/earnings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixify/core/constants/app_config.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/supabase_datasource.dart';
import 'package:fixify/data/datasources/application_datasource.dart';
import 'package:fixify/data/models/models.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/screens/shared/splash_screen.dart';
import 'package:fixify/presentation/screens/auth/login_screen.dart';
import 'package:fixify/presentation/screens/customer/dashboard_customer.dart';
import 'package:fixify/presentation/screens/customer/profile_customer.dart';
import 'package:fixify/presentation/screens/customer/requestservice_customer.dart';
import 'package:fixify/presentation/screens/customer/bookings_customer.dart';
import 'package:fixify/presentation/screens/customer/professional_profile_screen.dart'
    as customer;
import 'package:fixify/presentation/screens/customer/booking_status_screen.dart';
import 'package:fixify/presentation/screens/customer/review_screen.dart';
import 'package:fixify/presentation/screens/professional/dashboard_professional.dart';
import 'package:fixify/presentation/screens/professional/profile_professional.dart';
import 'package:fixify/presentation/screens/professional/apply_professional.dart';
import 'package:fixify/presentation/screens/professional/verificationstatus_professional.dart';
import 'package:fixify/presentation/screens/professional/booking_requests_professional.dart';
import 'package:fixify/presentation/screens/professional/booking_history_professional.dart';
import 'package:fixify/presentation/screens/admin/dashboard_admin.dart';
import 'package:fixify/presentation/screens/admin/profile_admin.dart';
import 'package:fixify/presentation/screens/admin/approvals_admin.dart';

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

// FIX: StatefulWidget so we react to auth changes properly
class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});
  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  bool _isLoggedIn = false;
  bool _initialCheckDone = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSession();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() => _isLoggedIn = data.session != null);
    });
  }

  Future<void> _checkInitialSession() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _isLoggedIn = session != null;
      _initialCheckDone = true;
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
    return _isLoggedIn ? const MainApp() : const AuthFlow();
  }
}

// ── AUTH ──────────────────────────────────────────────────────

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showSplash = true, _showRegister = false;

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
    if (_showRegister)
      return RegisterScreen(
          onNavigateToLogin: () => setState(() => _showRegister = false),
          onRegister: _handleRegister);
    return LoginScreen(
        onNavigateToRegister: () => setState(() => _showRegister = true),
        onLogin: _handleLogin);
  }

  Future<void> _handleLogin(String email, String password) async {
    try {
      debugPrint('🔐 Attempting login for: $email');
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      debugPrint('✅ Login successful');
    } catch (e) {
      debugPrint('❌ Login error: $e');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: AppColors.error));
    }
  }

  Future<void> _handleRegister(String name, String email, String password,
      String role, String? phone) async {
    OverlayEntry? loadingOverlay;
    loadingOverlay = OverlayEntry(
      builder: (_) =>
          const _LoadingOverlay(message: 'Creating your account...'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Overlay.of(context).insert(loadingOverlay!);
    });

    void dismissOverlay() {
      try {
        loadingOverlay?.remove();
      } catch (_) {}
      loadingOverlay = null;
    }

    try {
      debugPrint('👤 Starting registration for: $email (role: $role)');
      debugPrint('🔐 Step 1: Creating auth account...');
      final res = await Supabase.instance.client.auth
          .signUp(email: email, password: password);
      debugPrint('✅ Auth account created: ${res.user?.id}');

      if (res.user != null) {
        debugPrint('📝 Step 2: Creating user record...');
        await Supabase.instance.client.from('users').insert({
          'id': res.user!.id,
          'name': name,
          'email': email,
          'role': role,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ User record created');

        if (role == 'professional') {
          try {
            debugPrint('🏢 Step 3: Creating professional record...');
            await Supabase.instance.client.from('professionals').insert({
              'user_id': res.user!.id,
              'skills': [],
              'verified': false,
              'rating': 0.0,
              'review_count': 0,
              'available': true,
              'years_experience': 0,
            });
            debugPrint('✅ Professional record created');
          } catch (proErr) {
            debugPrint('⚠️ Professional record warning: $proErr');
          }
        }

        dismissOverlay();
        debugPrint('✅ Registration complete!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Registration successful! Check your email to verify your account.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showRegister = false);
          });
        }
      } else {
        dismissOverlay();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Registration failed: Unable to create account'),
              backgroundColor: AppColors.error));
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      dismissOverlay();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4)));
    }
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

// ── MAIN APP ──────────────────────────────────────────────────

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final SupabaseDataSource _ds;
  late final ApplicationDataSource _appDs;

  DateTime? _lastBackPress; // for double-tap-to-exit

  String?
      _preselectedServiceType; // set when tapping "Book Now" on a service detail
  UserModel? _user;
  ProfessionalModel? _pro;
  List<ProfessionalModel> _professionals = [];
  List<BookingModel> _bookings = [];
  List<ApplicationModel> _applications = [];
  int _navIndex = 0;
  String _screen = 'home';
  ProfessionalModel? _selectedPro;
  BookingModel? _selectedBooking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ds = SupabaseDataSource(Supabase.instance.client);
    _appDs = ApplicationDataSource(Supabase.instance.client);
    _init();
  }

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
              debugPrint('✅ Professional record auto-created');
            } catch (e) {
              debugPrint('❌ Could not auto-create professional record: $e');
            }
          }

          if (_pro != null) {
            _bookings = await _ds.getProfessionalBookings(_pro!.id);
            _applications = await _appDs.getMyApplications(_pro!.id);
            _ds.subscribeToProfessionalBookings(
              professionalId: _pro!.id,
              onNewBooking: (b) {
                setState(() => _bookings = [b, ..._bookings]);
                _notify('New booking request!');
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
          _bookings = await _ds.getCustomerBookings(_user!.id);
        }
      }
    } catch (e) {
      debugPrint('❌ Init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshBookings() async {
    try {
      if (_user == null) return;
      if (_user!.isProfessional && _pro != null) {
        final list = await _ds.getProfessionalBookings(_pro!.id);
        if (mounted) setState(() => _bookings = list);
      } else if (_user!.role == 'customer') {
        final list = await _ds.getCustomerBookings(_user!.id);
        if (mounted) setState(() => _bookings = list);
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

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
        // If a Navigator route (e.g. ServiceDetailScreen) is on top of the
        // stack, let Flutter handle the pop normally — don't intercept it.
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
          return;
        }
        // If on a sub-screen, go back within the app
        if (_screen != 'home') {
          setState(() {
            _screen = 'home';
          });
          return;
        }
        if (_navIndex != 0) {
          setState(() {
            _navIndex = 0;
            _screen = 'home';
          });
          return;
        }
        // At root home: double-tap to exit
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
          // Actually exit
          // ignore: deprecated_member_use
          SystemNavigator.pop();
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_user!.role == 'admin') {
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

      final pending = _applications.where((a) => a.status == 'pending').length;
      return AdminDashboardScreen(
        adminName: u.name,
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

    // ── PROFESSIONAL ──────────────────────────────────────
    if (_user!.isProfessional) {
      final u = _user!.toEntity();
      final proEntity = _pro?.toEntity();
      final bookingEntities = _bookings.map((b) => b.toEntity()).toList();

      // ── Profile tab
      if (_navIndex == 3) {
        return ProfessionalProfileScreen(
          user: u,
          professional: proEntity,
          onBack: () => setState(() => _navIndex = 0),
          onLogout: () async => Supabase.instance.client.auth.signOut(),
        );
      }

      // ── Booking Requests tab (navIndex 1)
      if (_navIndex == 1) {
        return BookingRequestsScreen(
          bookings: bookingEntities,
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
            try {
              await _ds.updateBookingStatus(booking.id, BookingStatus.accepted);
              await _refreshBookings();
              _notify('Booking accepted! Customer has been notified.');
            } catch (e) {
              _notify('Error: $e');
            }
          },
          onDecline: (booking) async {
            try {
              await _ds.updateBookingStatus(
                  booking.id, BookingStatus.cancelled);
              await _refreshBookings();
              _notify('Booking declined.');
            } catch (e) {
              _notify('Error: $e');
            }
          },
        );
      }

      // ── Earnings tab (navIndex 2)  <-- ADD THIS SECTION
      // ── Earnings tab (navIndex 2)
      if (_navIndex == 2) {
        return EarningsHandymanScreen(
          professionalId: _pro?.id,
          currentNavIndex: _navIndex, // <-- ADD THIS
          onNavTap: (i) {
            // <-- ADD THIS
            setState(() {
              _navIndex = i;
              _screen = 'home';
            });
          },
          onBack: () => setState(() {
            _navIndex = 0;
            _screen = 'home';
          }),
          onWithdraw: (amount, method) async {
            _notify('Withdrawal of ₱$amount requested via $method');
            return Future.value();
          },
          onAddPaymentMethod: (method) async {
            _notify('Payment method added: ${method['method']}');
            return Future.value();
          },
        );
      }

      // ── Booking History screen (from dashboard "Booking History" card)
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
        );
      }

      // ── Apply screen
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

      // ── Verification status screen
      if (_screen == 'verification_status') {
        return VerificationStatusScreen(
          applications: _applications,
          onBack: () => setState(() => _screen = 'home'),
          onApplyNew: () => setState(() => _screen = 'apply'),
        );
      }

      // ── Professional Dashboard (navIndex 0)
      return ProfessionalDashboardScreen(
        user: u,
        professional: proEntity,
        bookings: bookingEntities,
        pendingApplications:
            _applications.where((a) => a.status == 'pending').length,
        currentNavIndex: _navIndex,
        onNavTap: (i) async {
          setState(() {
            _navIndex = i;
            _screen = 'home';
          });
          if (i == 1)
            await _refreshBookings(); // Refresh pending requests when switching to Requests tab
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
        onApplyCredentials: () => setState(() => _screen = 'apply'),
        onViewVerification: () =>
            setState(() => _screen = 'verification_status'),
        onToggleAvailability: (_) {},
      );
    }

    // ── CUSTOMER ──────────────────────────────────────────
    return _customerFlow();
  }

  Widget _customerFlow() {
    final bookingEntities = _bookings.map((b) => b.toEntity()).toList();

    // ── Bookings tab (navIndex 1) — full list with tabs
    if (_navIndex == 1 && _screen == 'home') {
      return CustomerBookingsScreen(
        bookings: bookingEntities,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = i == 3 ? 'profile' : 'home';
        }),
        onRefresh: _refreshBookings,
        // Tap any booking card → go to its status/detail screen
        onBookingTap: (booking) {
          final model = _bookings.firstWhere((b) => b.id == booking.id,
              orElse: () => _bookings.first);
          setState(() {
            _selectedBooking = model;
            _screen = 'booking_status';
          });
        },
      );
    }

    switch (_screen) {
      case 'request_service':
        return RequestServiceScreen(
          professionals: _professionals,
          initialServiceType: _preselectedServiceType,
          onBack: () => setState(() {
            _screen = 'home';
            _preselectedServiceType = null;
          }),
          onSubmit: (result) async {
            try {
              final booking = await _ds.createBooking(
                customerId: _user!.id,
                professionalId: result.matchedPro.id,
                serviceType: result.serviceType,
                scheduledDate: DateTime.now().add(const Duration(days: 1)),
                notes: [
                  result.problemTitle,
                  if (result.description.isNotEmpty) result.description,
                  if (result.notes != null) result.notes!,
                ].join('\n'),
                address: result.address,
                priceEstimate: result.matchedPro.priceMin,
              );
              setState(() {
                _selectedBooking = booking;
                _bookings = [booking, ..._bookings];
                _screen = 'booking_status';
              });
              _ds.subscribeToBookingUpdates(
                  bookingId: booking.id,
                  onUpdate: (u) => setState(() {
                        _selectedBooking = u;
                        _bookings =
                            _bookings.map((b) => b.id == u.id ? u : b).toList();
                      }));
              _notify('Service request submitted!');
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
          professional: _selectedPro!.toEntity(),
          reviews: const [],
          onBack: () => setState(() => _screen = 'home'),
          onBookNow: () => setState(() => _screen = 'request_service'),
        );

      case 'booking':
        if (_selectedPro == null) return _home();
        return customer.BookingScreen(
          professional: _selectedPro!.toEntity(),
          onBack: () => setState(() => _screen = 'professional_profile'),
          onConfirmBooking: _createBooking,
        );

      case 'booking_status':
        if (_selectedBooking == null) return _home();
        return BookingStatusScreen(
          booking: _selectedBooking!.toEntity(),
          // Back: if we came from the Bookings tab, return there
          onBack: () => setState(() {
            _screen = 'home';
            // Keep _navIndex as-is so pressing back from a booking detail
            // opened via the Bookings tab returns to the Bookings tab list
          }),
          onWriteReview: _selectedBooking!.status == BookingStatus.completed
              ? () => setState(() => _screen = 'review')
              : null,
          onCancelBooking: _selectedBooking!.status == BookingStatus.pending
              ? () async {
                  try {
                    await _ds.updateBookingStatus(
                        _selectedBooking!.id, BookingStatus.cancelled);
                    await _refreshBookings();
                    // Refresh selectedBooking too
                    final updated = _bookings.firstWhere(
                        (b) => b.id == _selectedBooking!.id,
                        orElse: () => _selectedBooking!);
                    setState(() {
                      _selectedBooking = updated;
                    });
                  } catch (e) {
                    _notify('Error: $e');
                  }
                }
              : null,
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
          onLogout: () async => Supabase.instance.client.auth.signOut(),
        );

      default:
        return _home();
    }
  }

  Widget _home() => CustomerDashboardScreen(
        user: _user?.toEntity(),
        professionals: _professionals.map((p) => p.toEntity()).toList(),
        recentBookings: _bookings.map((b) => b.toEntity()).toList(),
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() {
          _navIndex = i;
          _screen = i == 2 ? 'profile' : 'home'; // Profile is now index 2
        }),
        onRequestService: () => setState(() {
          _preselectedServiceType = null;
          _screen = 'request_service';
        }),
        onRequestServiceWithType: (serviceType) => setState(() {
          _preselectedServiceType = serviceType;
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
            _screen = 'professional_profile';
          });
        },
        // ADD THIS FOR PROFILE ICON TAP:
        onProfileTap: () {
          setState(() {
            _navIndex = 3; // Set to profile tab index
            _screen = 'profile';
          });
        },
      );

  Future<void> _createBooking(
      DateTime date, String serviceType, String? notes, String? address) async {
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
      );
      setState(() {
        _selectedBooking = booking;
        _bookings = [booking, ..._bookings];
        _screen = 'booking_status';
      });
      _ds.subscribeToBookingUpdates(
          bookingId: booking.id,
          onUpdate: (u) => setState(() {
                _selectedBooking = u;
                _bookings = _bookings.map((b) => b.id == u.id ? u : b).toList();
              }));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    }
  }

  Future<void> _updateStatus(
      BookingEntity booking, BookingStatus newStatus) async {
    try {
      await _ds.updateBookingStatus(booking.id, newStatus);
      setState(() {
        _bookings = _bookings
            .map((b) => b.id == booking.id ? b.copyWithStatus(newStatus) : b)
            .toList();
        if (_selectedBooking?.id == booking.id)
          _selectedBooking = _selectedBooking!.copyWithStatus(newStatus);
      });
    } catch (e) {
      debugPrint('UpdateStatus error: $e');
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
          comment: comment);
      setState(() => _screen = 'home');
      _notify('Review submitted! Thank you.');
    } catch (e) {
      debugPrint('Review error: $e');
    }
  }
}
