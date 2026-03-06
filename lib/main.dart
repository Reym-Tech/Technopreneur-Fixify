// lib/main.dart

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
import 'package:fixify/presentation/screens/customer/professional_profile_screen.dart'
    as customer;
import 'package:fixify/presentation/screens/customer/booking_status_screen.dart';
import 'package:fixify/presentation/screens/professional/dashboard_professional.dart';
import 'package:fixify/presentation/screens/professional/profile_professional.dart';
import 'package:fixify/presentation/screens/professional/apply_professional.dart';
import 'package:fixify/presentation/screens/professional/verificationstatus_professional.dart';
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

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (_, __) {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? const MainApp() : const AuthFlow();
      });
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
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: AppColors.error));
    }
  }

  Future<void> _handleRegister(String name, String email, String password,
      String role, String? phone) async {
    try {
      final res = await Supabase.instance.client.auth
          .signUp(email: email, password: password);
      if (res.user != null) {
        await Supabase.instance.client.from('users').insert({
          'id': res.user!.id,
          'name': name,
          'email': email,
          'role': role,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });
        // Auto-create professionals row for handyman registrations
        if (role == 'professional') {
          await Supabase.instance.client.from('professionals').insert({
            'user_id': res.user!.id,
            'skills': [],
            'verified': false,
            'rating': 0.0,
            'review_count': 0,
            'available': true,
            'years_experience': 0,
          });
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: AppColors.error));
    }
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

  UserModel? _user;
  ProfessionalModel? _pro;
  List<ProfessionalModel> _professionals = [];
  List<BookingModel> _bookings = [];
  List<ApplicationModel> _applications =
      []; // for pro: my apps; for admin: all apps
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
                // Refresh professionals list so customer sees new availability
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
      debugPrint('Init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.notifications_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg))
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

    // ── ADMIN ─────────────────────────────────────────────
    if (_user!.role == 'admin') {
      final u = _user!.toEntity();
      // Approvals tab
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
        );
      }
      // Profile tab
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

      // Apply screen
      if (_screen == 'apply') {
        // THIS IS ADDED - 005
        if (_pro == null) {
          return const Scaffold(
            body: Center(child: Text("Professional profile not found")),
          );
        }
        return ApplyScreen(
          professionalId: _pro!.id,
          userId: _user!.id,
          onBack: () => setState(() => _screen = 'home'),
          onSubmit: (data) async {
            try {
              // THIS IS CHANGED - 005
              // final app = await _appDs.submitApplication(
              //   professionalId: _pro!.id,
              // INTO
              final app = await _appDs.submitApplication(
                professionalId: _pro?.id ?? '',
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
                  'Application submitted! We\'ll review it within 24–48 hours.');
            } catch (e) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Submission failed: $e')));
            }
          },
        );
      }

      // Verification status screen
      if (_screen == 'verification_status') {
        return VerificationStatusScreen(
          applications: _applications,
          onBack: () => setState(() => _screen = 'home'),
          onApplyNew: () => setState(() => _screen = 'apply'),
        );
      }

      // Profile tab
      if (_navIndex == 3) {
        return ProfessionalProfileScreen(
          user: u,
          professional: proEntity,
          onBack: () => setState(() => _navIndex = 0),
          onLogout: () async => Supabase.instance.client.auth.signOut(),
        );
      }

      return ProfessionalDashboardScreen(
        user: u, professional: proEntity, bookings: bookingEntities,
        pendingApplications:
            _applications.where((a) => a.status == 'pending').length,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() => _navIndex = i),
        onUpdateStatus: _updateStatus,
        onViewRequests: () => setState(() => _navIndex = 1),
        onViewEarnings: () => setState(() => _navIndex = 2),
        // Verification flow entry points
        onViewHistory: () => setState(() => _screen = 'verification_status'),
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
    switch (_screen) {
      case 'request_service':
        return RequestServiceScreen(
          professionals: _professionals,
          onBack: () => setState(() => _screen = 'home'),
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
                  if (result.notes != null) result.notes!
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
          onBack: () => setState(() => _screen = 'home'),
          onWriteReview: _selectedBooking!.status == BookingStatus.completed
              ? () => setState(() => _screen = 'review')
              : null,
          onCancelBooking: _selectedBooking!.status == BookingStatus.pending
              ? () => _updateStatus(
                  _selectedBooking!.toEntity(), BookingStatus.cancelled)
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
          _screen = i == 3 ? 'profile' : 'home';
        }),
        onRequestService: () => setState(() => _screen = 'request_service'),
        onFilterBySkill: (skill) async {
          try {
            final list = await _ds.getProfessionals(skill: skill);
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
