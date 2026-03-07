// lib/presentation/screens/customer/review_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/entities.dart';
import '../../widgets/shared_widgets.dart';

class ReviewScreen extends StatefulWidget {
  final BookingEntity booking;
  final Function(int rating, String? comment)? onSubmitReview;
  final VoidCallback? onBack;

  const ReviewScreen({
    super.key,
    required this.booking,
    this.onSubmitReview,
    this.onBack,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pro = widget.booking.professional;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Pro avatar
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      pro?.name.isNotEmpty == true ? pro!.name[0] : 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ).animate().scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 16),
                Text(
                  pro?.name ?? 'Professional',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'How was your experience?',
                  style: TextStyle(fontSize: 15, color: AppColors.textMedium),
                ),
                const SizedBox(height: 32),

                // Star rating
                GlassCard(
                  child: Column(
                    children: [
                      const Text(
                        'Rate your experience',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      RatingBar.builder(
                        initialRating: _rating.toDouble(),
                        minRating: 1,
                        itemCount: 5,
                        itemSize: 48,
                        glow: true,
                        glowColor: const Color(0xFFFFB800).withOpacity(0.3),
                        itemBuilder: (context, _) => const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB800),
                        ),
                        onRatingUpdate: (r) =>
                            setState(() => _rating = r.toInt()),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getRatingLabel(_rating),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getRatingColor(_rating),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 20),

                // Comment field
                GlassCard(
                  child: FixifyTextField(
                    controller: _commentController,
                    hint: 'Share your experience (optional)...',
                    label: 'Your Comment',
                    prefixIcon: Icons.comment_outlined,
                    maxLines: 4,
                  ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 28),

                // Submit button
                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.star_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Very Poor 😞';
      case 2:
        return 'Poor 😐';
      case 3:
        return 'Average 🙂';
      case 4:
        return 'Good 😊';
      case 5:
        return 'Excellent! 🌟';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating <= 2) return AppColors.error;
    if (rating == 3) return AppColors.warning;
    return AppColors.success;
  }

  void _handleSubmit() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isLoading = false);
    widget.onSubmitReview?.call(
      _rating,
      _commentController.text.isEmpty ? null : _commentController.text,
    );
  }
}
