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

// Full lifecycle:
//   pending                    → Open request, no pro assigned yet
//   accepted                   → Pro claimed the booking; must now propose a schedule
//   scheduleProposed           → Pro has proposed a start date/time; customer reviewing
//   scheduled                  → Customer accepted the proposed schedule; waiting for arrival
//   assessment                 → Pro arrived, set a price; customer must confirm
//   inProgress                 → Customer confirmed price; job underway
//   pendingCustomerConfirmation → Pro marked job done; waiting for customer to confirm
//   completed                  → Customer confirmed the job is done
//   cancelled                  → Either side cancelled at any point
enum BookingStatus {
  pending,
  accepted,
  scheduleProposed,
  scheduled,
  assessment,
  inProgress,
  pendingCustomerConfirmation, // Pro marked done; awaiting customer confirmation
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

  /// Price set by the handyman during the assessment phase.
  final double? assessmentPrice;

  /// Date/time proposed by the handyman for the job start.
  /// Set when status transitions to scheduleProposed.
  final DateTime? scheduledTime;

  /// Reason provided by the handyman when proposing a reschedule
  /// (i.e. they are running late / still on another job).
  final String? rescheduleReason;

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
    this.scheduledTime,
    this.rescheduleReason,
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
