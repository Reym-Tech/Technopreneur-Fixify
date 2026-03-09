// lib/presentation/widgets/shared_widgets.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/entities.dart';

// ===================== GLASS CARD =====================

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final double blur;
  final Border? border;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.backgroundColor,
    this.blur = 10,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(borderRadius),
                border: border ??
                    Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== PRIMARY GLASS CARD (Dark) =====================

class PrimaryGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const PrimaryGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.9),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ===================== VERIFIED BADGE =====================

class VerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final bool small;

  const VerifiedBadge(
      {super.key, required this.isVerified, this.small = false});

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF0F3D2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded,
              color: Colors.white, size: small ? 10 : 12),
          SizedBox(width: small ? 3 : 4),
          Text(
            'Verified',
            style: TextStyle(
              color: Colors.white,
              fontSize: small ? 9 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== STATUS BADGE =====================

class StatusBadge extends StatelessWidget {
  final BookingStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config['color'].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config['color'],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            config['label'],
            style: TextStyle(
              color: config['color'],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return {'color': AppColors.statusPending, 'label': 'Pending'};
      case BookingStatus.accepted:
        return {'color': AppColors.statusAccepted, 'label': 'Accepted'};
      case BookingStatus.inProgress:
        return {'color': AppColors.statusInProgress, 'label': 'In Progress'};
      case BookingStatus.completed:
        return {'color': AppColors.statusCompleted, 'label': 'Completed'};
      case BookingStatus.cancelled:
        return {'color': AppColors.error, 'label': 'Cancelled'};
    }
  }
}

// ===================== RATING STARS =====================

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool showLabel;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RatingBarIndicator(
          rating: rating,
          itemBuilder: (context, _) => const Icon(
            Icons.star_rounded,
            color: Color(0xFFFFB800),
          ),
          itemCount: 5,
          itemSize: size,
          unratedColor: const Color(0xFFE0E0E0),
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ],
    );
  }
}

// ===================== PROFESSIONAL CARD =====================

class ProfessionalCard extends StatelessWidget {
  final ProfessionalEntity professional;
  final VoidCallback onTap;

  const ProfessionalCard({
    super.key,
    required this.professional,
    required this.onTap,
  });

  /// Launches the device's native phone dialer pre-filled with [phone].
  Future<void> _callPhone(BuildContext context, String phone) async {
    // Strip spaces/dashes so the URI is clean, e.g. "tel:+639171234567"
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $phone'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        professional.phone != null && professional.phone!.trim().isNotEmpty;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: professional.avatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          professional.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                        ),
                      )
                    : _buildDefaultAvatar(),
              ),
              if (professional.available)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Info ─────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        professional.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    VerifiedBadge(
                        isVerified: professional.verified, small: true),
                  ],
                ),
                const SizedBox(height: 4),
                // Skills chips
                Wrap(
                  spacing: 4,
                  children: professional.skills.take(2).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _capitalizeSkill(skill),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    RatingStars(
                        rating: professional.rating, size: 13, showLabel: true),
                    const SizedBox(width: 4),
                    Text(
                      '(${professional.reviewCount})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                    const Spacer(),
                    if (professional.priceMin != null &&
                        professional.priceMax != null)
                      Text(
                        '₱${professional.priceMin!.toInt()}-₱${professional.priceMax!.toInt()}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                if (professional.city != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 2),
                        Text(
                          professional.city!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Phone row — only shown when a number is available ─────
                if (hasPhone)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      // Stop propagation so the card tap (view profile) is
                      // not triggered when the user taps the phone button.
                      onTap: () => _callPhone(context, professional.phone!),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.phone_rounded,
                              size: 13,
                              color: Color(0xFF34C759),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            professional.phone!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF34C759),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        professional.name.isNotEmpty ? professional.name[0].toUpperCase() : 'P',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _capitalizeSkill(String skill) {
    if (skill.isEmpty) return skill;
    return skill[0].toUpperCase() + skill.substring(1);
  }
}

// ===================== SERVICE CATEGORY CHIP =====================

class ServiceCategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const ServiceCategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE8EDE9),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : (color ?? AppColors.primary),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== SECTION HEADER =====================

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ===================== CUSTOM BOTTOM NAV =====================

class FixifyBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isProfessional;

  const FixifyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isProfessional = false,
  });

  @override
  Widget build(BuildContext context) {
    final customerItems = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.search_rounded, 'label': 'Explore'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Bookings'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    final professionalItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
      {'icon': Icons.work_outline_rounded, 'label': 'Jobs'},
      {'icon': Icons.star_outline_rounded, 'label': 'Reviews'},
      {'icon': Icons.person_rounded, 'label': 'Profile'},
    ];

    final items = isProfessional ? professionalItems : customerItems;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textLight,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ===================== CUSTOM TEXT FIELD =====================

class FixifyTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final String? label;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final int? maxLines;

  const FixifyTextField({
    super.key,
    this.controller,
    required this.hint,
    this.label,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.textLight, size: 20)
                : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

// ===================== LOADING OVERLAY =====================

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: GlassCard(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please wait...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
