// lib/domain/entities/entities.dart
// Single file containing ALL domain entities for Fixify

import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────
// USER
// ─────────────────────────────────────────

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role; // 'customer' | 'professional'
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
  });

  bool get isCustomer => role == 'customer';
  bool get isProfessional => role == 'professional';

  @override
  List<Object?> get props =>
      [id, name, email, role, phone, avatarUrl, createdAt];
}

// ─────────────────────────────────────────
// PROFESSIONAL
// ─────────────────────────────────────────

class ProfessionalEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final List<String> skills;
  final bool verified;
  final double rating;
  final int reviewCount;
  final String? priceRange;
  final double? priceMin;
  final double? priceMax;
  final String? city;
  final String? bio;
  final int yearsExperience;
  final bool available;

  /// Phone number sourced from the professional's users row.
  final String? phone;

  /// Handyman's registered GPS location — used to draw the route on the
  /// AssessmentScreen map.
  final double? latitude;
  final double? longitude;

  const ProfessionalEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.skills,
    required this.verified,
    required this.rating,
    required this.reviewCount,
    this.priceRange,
    this.priceMin,
    this.priceMax,
    this.city,
    this.bio,
    required this.yearsExperience,
    required this.available,
    this.phone,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props =>
      [id, userId, name, skills, verified, rating, reviewCount];
}

// ─────────────────────────────────────────
// BOOKING
// ─────────────────────────────────────────

// CHANGE: Added `assessment` between `accepted` and `inProgress`.
//
// Full lifecycle:
//   pending    → Handyman not yet responded
//   accepted   → Handyman accepted; can now set a price
//   assessment → Handyman has set a price; awaiting customer confirmation
//   inProgress → Customer confirmed the price; Handyman can now start the job
//   completed  → Handyman marked the job done
//   cancelled  → Either side cancelled
enum BookingStatus {
  pending,
  accepted,
  assessment, // NEW — price set by handyman, awaiting customer confirmation
  inProgress,
  completed,
  cancelled,
}

class BookingEntity extends Equatable {
  final String id;
  final String customerId;
  final String professionalId;
  final String serviceType;
  final String? description;
  final double? priceEstimate;
  final BookingStatus status;
  final DateTime scheduledDate;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final ProfessionalEntity? professional;
  final UserEntity? customer;

  /// Customer's pinned GPS location from RequestServiceScreen.
  final double? latitude;
  final double? longitude;

  /// Price set by the handyman after accepting the booking.
  /// Moving to `assessment` status means this is non-null.
  final double? assessmentPrice;

  const BookingEntity({
    required this.id,
    required this.customerId,
    required this.professionalId,
    required this.serviceType,
    this.description,
    this.priceEstimate,
    required this.status,
    required this.scheduledDate,
    this.address,
    this.notes,
    required this.createdAt,
    this.professional,
    this.customer,
    this.latitude,
    this.longitude,
    this.assessmentPrice,
  });

  @override
  List<Object?> get props =>
      [id, customerId, professionalId, status, scheduledDate];
}

// ─────────────────────────────────────────
// REVIEW
// ─────────────────────────────────────────

class ReviewEntity extends Equatable {
  final String id;
  final String bookingId;
  final String customerId;
  final String professionalId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? customerName;
  final String? customerAvatar;

  const ReviewEntity({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.professionalId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.customerName,
    this.customerAvatar,
  });

  @override
  List<Object?> get props => [id, bookingId, rating, comment];
}
