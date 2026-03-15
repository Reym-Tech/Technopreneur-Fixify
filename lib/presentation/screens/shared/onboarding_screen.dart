// lib/presentation/screens/shared/onboarding_screen.dart
//
// OnboardingScreen — shown once to first-time users after the splash screen
// and before the login/register screens.
//
// Design: consistent dark-green brand gradient across all slides (matching
// the app header), with per-slide accent colors used only for the icon bubble
// and the active dot indicator. This keeps the visual identity stable while
// still giving each slide its own personality.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fixify/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  // Constant brand gradient — same as the app header across all screens.
  static const _bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF082218), Color(0xFF0F3D2E), Color(0xFF1A5C43)],
  );

  static const _slides = [
    _SlideDef(
      icon: Icons.engineering_rounded,
      accentColor: Color(0xFF34C759),
      title: 'Find a Verified\nHandyman',
      body: 'Browse skilled professionals in your area. Every handyman is '
          'verified, rated, and reviewed by real customers.',
    ),
    _SlideDef(
      icon: Icons.calendar_month_rounded,
      accentColor: Color(0xFF5AC8FA),
      title: 'Book in\nMinutes',
      body: 'Describe your issue, set your preferred time, and a handyman '
          'comes to you. No calls, no hassle.',
    ),
    _SlideDef(
      icon: Icons.verified_rounded,
      accentColor: Color(0xFFFF9500),
      title: 'Safe &\nTransparent',
      body: 'Confirm arrivals, agree on price before work starts, and review '
          'completion proof — all inside the app.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    final slide = _slides[_currentPage];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: Stack(
          children: [
            // ── Subtle constant background circles ──────────────────────
            Positioned(
              top: -60,
              right: -40,
              child: _circle(220, Colors.white.withOpacity(0.04)),
            ),
            Positioned(
              top: 80,
              right: 60,
              child: _circle(100, Colors.white.withOpacity(0.03)),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: _circle(280, Colors.white.withOpacity(0.03)),
            ),
            // ── Per-slide accent glow behind the icon ───────────────────
            Positioned(
              top: MediaQuery.of(context).size.height * 0.22,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: slide.accentColor.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Skip button ───────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                      child: AnimatedOpacity(
                        opacity: isLast ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: isLast ? null : widget.onDone,
                          child: const Text('Skip',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                  ),

                  // ── PageView ──────────────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (_, i) => _SlideContent(slide: _slides[i]),
                    ),
                  ),

                  // ── Dot indicator ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? slide.accentColor
                                : Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),

                  // ── Next / Get Started button ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast
                                  ? Icons.arrow_forward_rounded
                                  : Icons.chevron_right_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.1, end: 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ── Slide content ─────────────────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  final _SlideDef slide;
  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon bubble — accent color is the only per-slide visual change
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: slide.accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: slide.accentColor.withOpacity(0.25), width: 2),
            ),
            child: Icon(slide.icon, size: 64, color: slide.accentColor),
          )
              .animate()
              .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1.0, 1.0),
                  duration: 500.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(duration: 400.ms),

          const SizedBox(height: 48),

          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 400.ms)
              .slideY(begin: 0.15, end: 0),

          const SizedBox(height: 20),

          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.72),
              height: 1.65,
            ),
          )
              .animate()
              .fadeIn(delay: 250.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

// ── Slide definition ──────────────────────────────────────────────────────────

class _SlideDef {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String body;

  const _SlideDef({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.body,
  });
}
