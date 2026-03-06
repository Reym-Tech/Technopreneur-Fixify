// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fixify/core/constants/supabase_config.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/data/datasources/supabase_datasource.dart';
import 'package:fixify/data/models/models.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/screens/shared/splash_screen.dart';
import 'package:fixify/presentation/screens/auth/login_screen.dart';
import 'package:fixify/presentation/screens/customer/dashboard_customer.dart';
import 'package:fixify/presentation/screens/customer/profile_customer.dart';
import 'package:fixify/presentation/screens/customer/professional_profile_screen.dart'
    as customer;
import 'package:fixify/presentation/screens/customer/booking_status_screen.dart';
import 'package:fixify/presentation/screens/professional/dashboard_professional.dart';
import 'package:fixify/presentation/screens/professional/profile_professional.dart';
import 'package:fixify/presentation/screens/admin/dashboard_admin.dart';
import 'package:fixify/presentation/screens/admin/profile_admin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const FixifyApp());
}

// ── ROOT APP ──────────────────────────────────────────────────

class FixifyApp extends StatelessWidget {
  const FixifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppNavigator(),
    );
  }
}

// ── APP NAVIGATOR ─────────────────────────────────────────────

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? const MainApp() : const AuthFlow();
      },
    );
  }
}

// ── AUTH FLOW ─────────────────────────────────────────────────

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _showSplash = true;
  bool _showRegister = false;

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
        onNavigateToLogin: () => setState(() => _showRegister = false),
        onRegister: _handleRegister,
      );
    }
    return LoginScreen(
      onNavigateToRegister: () => setState(() => _showRegister = true),
      onLogin: _handleLogin,
    );
  }

  Future<void> _handleLogin(String email, String password) async {
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
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

  UserModel? _user;
  ProfessionalModel? _pro;
  List<ProfessionalModel> _professionals = [];
  List<BookingModel> _bookings = [];
  int _navIndex = 0;

  String _screen = 'home';
  ProfessionalModel? _selectedPro;
  BookingModel? _selectedBooking;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ds = SupabaseDataSource(Supabase.instance.client);
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
            _ds.subscribeToProfessionalBookings(
              professionalId: _pro!.id,
              onNewBooking: (b) {
                setState(() => _bookings = [b, ..._bookings]);
                _notify('New booking request received!');
              },
            );
          }
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
        Text(msg),
      ]),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    if (_user == null) return const AuthFlow();

    // ── Admin flow
    if (_user!.role == 'admin') {
      final userEntity = _user!.toEntity();
      if (_navIndex == 3) {
        return AdminProfileScreen(
          adminName: userEntity.name,
          adminEmail: userEntity.email,
          adminPhone: userEntity.phone,
          accessLevel: 'SUPERADMIN',
          lastLogin: DateTime.now(),
          twoFactorEnabled: false,
          onBack: () => setState(() => _navIndex = 0),
          onLogout: () async {
            await Supabase.instance.client.auth.signOut();
          },
        );
      }
      return AdminDashboardScreen(
        adminName: userEntity.name,
        pendingApprovals:
            _professionals.where((p) => p.verified == false).length,
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

    // ── Professional flow
    if (_user!.isProfessional) {
      // Convert models to entities for the screen
      final userEntity = _user!.toEntity();
      final proEntity = _pro?.toEntity();
      final bookingEntities = _bookings.map((b) => b.toEntity()).toList();

      // Show profile screen when nav index 3 is tapped
      if (_navIndex == 3) {
        return ProfessionalProfileScreen(
          user: userEntity,
          professional: proEntity,
          onBack: () => setState(() => _navIndex = 0),
          onLogout: () async {
            await Supabase.instance.client.auth.signOut();
          },
        );
      }

      return ProfessionalDashboardScreen(
        user: userEntity,
        professional: proEntity,
        bookings: bookingEntities,
        currentNavIndex: _navIndex,
        onNavTap: (i) => setState(() => _navIndex = i),
        onUpdateStatus: _updateStatus,
        onViewRequests: () => setState(() => _navIndex = 1),
        onViewEarnings: () => setState(() => _navIndex = 2),
        onToggleAvailability: (_) {},
      );
    }

    // ── Customer flow
    return _customerFlow();
  }

  Widget _customerFlow() {
    switch (_screen) {
      case 'professional_profile':
        if (_selectedPro == null) return _home();
        return customer.ProfessionalProfileScreen(
          professional: _selectedPro!.toEntity(),
          reviews: const [],
          onBack: () => setState(() => _screen = 'home'),
          onBookNow: () => setState(() => _screen = 'booking'),
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
          onBack: () => setState(() => _screen = 'home'),
          onLogout: () async {
            await Supabase.instance.client.auth.signOut();
          },
        );

      default:
        return _home();
    }
  }

  Widget _home() {
    return CustomerDashboardScreen(
      user: _user?.toEntity(),
      professionals: _professionals.map((p) => p.toEntity()).toList(),
      recentBookings: _bookings.map((b) => b.toEntity()).toList(),
      currentNavIndex: _navIndex,
      onNavTap: (i) {
        setState(() {
          _navIndex = i;
          if (i == 3)
            _screen = 'profile';
          else if (i == 0) _screen = 'home';
        });
      },
      onRequestService: () =>
          setState(() => _screen = 'professional_profile_browse'),
      onFilterBySkill: (skill) async {
        try {
          final list = await _ds.getProfessionals(skill: skill);
          setState(() => _professionals = list);
        } catch (e) {
          debugPrint('Filter error: $e');
        }
      },
      onProfessionalTap: (entity) {
        // find the matching model by id
        final model = _professionals.firstWhere((p) => p.id == entity.id);
        setState(() {
          _selectedPro = model;
          _screen = 'professional_profile';
        });
      },
    );
  }

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
        onUpdate: (updated) {
          setState(() {
            _selectedBooking = updated;
            _bookings =
                _bookings.map((b) => b.id == updated.id ? updated : b).toList();
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Booking failed: $e')));
      }
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
        if (_selectedBooking?.id == booking.id) {
          _selectedBooking = _selectedBooking!.copyWithStatus(newStatus);
        }
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
        comment: comment,
      );
      setState(() => _screen = 'home');
      _notify('Review submitted! Thank you.');
    } catch (e) {
      debugPrint('Review error: $e');
    }
  }
}
