// lib/presentation/screens/customer/booking_status_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:fixify/core/theme/app_theme.dart';
import 'package:fixify/domain/entities/entities.dart';
import 'package:fixify/presentation/widgets/shared_widgets.dart';

class BookingStatusScreen extends StatelessWidget {
  final BookingEntity booking;
  final VoidCallback? onBack;
  final VoidCallback? onWriteReview;
  final VoidCallback? onCancelBooking;

  const BookingStatusScreen({
    super.key,
    required this.booking,
    this.onBack,
    this.onWriteReview,
    this.onCancelBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),

          // Status timeline
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStatusTimeline(),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
          ),

          // Details card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Booking Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.build_circle_rounded, 'Service',
                        _capitalizeSkill(booking.serviceType)),
                    _buildDetailRow(Icons.calendar_today_rounded, 'Scheduled',
                        _formatDate(booking.scheduledDate)),
                    if (booking.priceEstimate != null)
                      _buildDetailRow(Icons.payments_rounded, 'Estimate',
                          '\$${booking.priceEstimate!.toStringAsFixed(0)}+'),
                    if (booking.address != null)
                      _buildDetailRow(Icons.location_on_outlined, 'Address',
                          booking.address!),
                    if (booking.notes != null)
                      _buildDetailRow(
                          Icons.notes_rounded, 'Notes', booking.notes!),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),
          ),

          // Professional card
          if (booking.professional != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            booking.professional!.name.isNotEmpty
                                ? booking.professional!.name[0]
                                : 'P',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  booking.professional!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                VerifiedBadge(
                                    isVerified: booking.professional!.verified,
                                    small: true),
                              ],
                            ),
                            const SizedBox(height: 4),
                            RatingStars(
                                rating: booking.professional!.rating, size: 13),
                          ],
                        ),
                      ),
                      // Call button
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.call_rounded,
                            color: AppColors.success, size: 20),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ),

          // Actions
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  if (booking.status == BookingStatus.completed &&
                      onWriteReview != null)
                    ElevatedButton.icon(
                      onPressed: onWriteReview,
                      icon: const Icon(Icons.star_rounded, size: 18),
                      label: const Text('Write a Review'),
                    ),
                  if (booking.status == BookingStatus.pending &&
                      onCancelBooking != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onCancelBooking,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('Cancel Booking'),
                    ),
                  ],
                ],
              ).animate().fadeIn(delay: 500.ms),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getStatusGradient(booking.status),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Booking Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Status icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(booking.status),
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getStatusTitle(booking.status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _getStatusDescription(booking.status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildStatusTimeline() {
    final statuses = [
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.inProgress,
      BookingStatus.completed,
    ];

    return Column(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isCompleted = _isStatusCompleted(status, booking.status);
        final isCurrent = status == booking.status;
        final isLast = index == statuses.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? AppColors.primary
                        : const Color(0xFFE0E0E0),
                    shape: BoxShape.circle,
                    boxShadow: isCompleted || isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10,
                            )
                          ]
                        : [],
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : _getStatusIcon(status),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                if (!isLast)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 2,
                    height: 40,
                    color: isCompleted
                        ? AppColors.primary
                        : const Color(0xFFE0E0E0),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusTitle(status),
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                        color: isCompleted || isCurrent
                            ? AppColors.textDark
                            : AppColors.textLight,
                      ),
                    ),
                    if (isCurrent)
                      Text(
                        _getStatusDescription(status),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getStatusGradient(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return [const Color(0xFFE65C00), const Color(0xFFF9D423)];
      case BookingStatus.accepted:
        return [const Color(0xFF1565C0), const Color(0xFF1976D2)];
      case BookingStatus.inProgress:
        return [const Color(0xFF4527A0), const Color(0xFF5E35B1)];
      case BookingStatus.completed:
        return [const Color(0xFF2E7D32), AppColors.primary];
      case BookingStatus.cancelled:
        return [const Color(0xFFC62828), const Color(0xFFE53935)];
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.hourglass_empty_rounded;
      case BookingStatus.accepted:
        return Icons.thumb_up_rounded;
      case BookingStatus.inProgress:
        return Icons.build_rounded;
      case BookingStatus.completed:
        return Icons.check_circle_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  String _getStatusTitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getStatusDescription(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Waiting for professional to accept';
      case BookingStatus.accepted:
        return 'Professional is on their way';
      case BookingStatus.inProgress:
        return 'Service is currently underway';
      case BookingStatus.completed:
        return 'Service has been completed';
      case BookingStatus.cancelled:
        return 'This booking was cancelled';
    }
  }

  bool _isStatusCompleted(BookingStatus check, BookingStatus current) {
    final order = [
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.inProgress,
      BookingStatus.completed,
    ];
    final checkIndex = order.indexOf(check);
    final currentIndex = order.indexOf(current);
    return checkIndex < currentIndex;
  }

  String _capitalizeSkill(String skill) {
    if (skill.isEmpty) return skill;
    return skill[0].toUpperCase() + skill.substring(1);
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================
// REVIEW SCREEN
// ============================================================

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
