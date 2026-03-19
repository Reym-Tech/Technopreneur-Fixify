// lib/presentation/screens/shared/splash_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Navigate based on auth state
        // Navigator.of(context).pushReplacementNamed('/auth');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF082218),
              Color(0xFF0F3D2E),
              Color(0xFF1A5C43),
              Color(0xFF0F3D2E),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            Positioned(
              top: 120,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2E7D5E).withOpacity(0.3),
                ),
              ),
            ),

            // Glass overlay cards
            Positioned(
              bottom: 200,
              right: -30,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2E7D5E),
                          Color(0xFF34C759),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF34C759).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      // <-- ADD THIS
                      borderRadius: BorderRadius.circular(
                          28), // Match container border radius
                      child: Image.asset(
                        'assets/images/logo.jpg', // <-- PATH TO YOUR IMAGE
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback icon if image fails to load
                          return const Icon(
                            Icons.construction_rounded,
                            color: Colors.white,
                            size: 52,
                          );
                        },
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      delay: 200.ms,
                      duration: 800.ms,
                      curve: Curves.elasticOut),

                  const SizedBox(height: 28),

                  // App name
                  Text(
                    'AYO',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(
                      begin: 0.3,
                      end: 0,
                      delay: 600.ms,
                      duration: 600.ms,
                      curve: Curves.easeOutCubic),

                  const SizedBox(height: 10),

                  // Tagline
                  Text(
                    'Appliance and Homecare Online',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.65),
                      letterSpacing: 0.3,
                    ),
                  ).animate().fadeIn(delay: 900.ms, duration: 600.ms).slideY(
                      begin: 0.2, end: 0, delay: 900.ms, duration: 600.ms),

                  const SizedBox(height: 60),

                  // Service icons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildServiceIcon('assets/icons/plumber-.svg', 'Plumber',
                          iconSize: 70, containerSize: 100),
                      const SizedBox(width: 20),
                      _buildServiceIcon(
                          'assets/icons/electrician-.svg', 'Electrician',
                          iconSize: 70, containerSize: 100),
                      const SizedBox(width: 20),
                      _buildServiceIcon(
                          'assets/icons/technician-.svg', 'Technician',
                          iconSize: 70, containerSize: 100),
                    ],
                  ).animate().fadeIn(delay: 1200.ms, duration: 600.ms),
                ],
              ),
            ),

            // Bottom loading indicator
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(Colors.white.withOpacity(0.6)),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading your experience...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 1500.ms, duration: 600.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceIcon(String imagePath, String label,
      {double iconSize = 26, double containerSize = 72}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use SvgPicture.asset for SVG files
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SvgPicture.asset(
                  imagePath,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.cover,
                  // If you need to apply a color filter, use the colorFilter parameter:
                  // colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  placeholderBuilder: (context) => Container(
                    width: iconSize,
                    height: iconSize,
                    color: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.image, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
