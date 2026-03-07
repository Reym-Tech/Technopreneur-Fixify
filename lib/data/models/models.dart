// lib/data/models/models.dart
// Self-contained models — NO inheritance from entity classes.
// Each model holds its own fields and converts from/to JSON.

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/entities.dart';

// ─────────────────────────────────────────
// USER MODEL
// ─────────────────────────────────────────

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Parse a possibly-partial user object (e.g. joined selects that only include
  /// `name`/`phone`/`avatar_url`). Falls back to sensible defaults to avoid
  /// casting errors when fields are missing.
  ///
  /// NOTE: `id` is NOT defaulted to '' — if it is missing the caller should
  /// handle the null case rather than silently getting an empty UUID that will
  /// later crash Postgres with "invalid input syntax for type uuid: """.
  factory UserModel.fromJsonSafe(Map<String, dynamic> json) {
    // Pull id — keep null if absent so callers can detect the problem early.
    final rawId = json['id']?.toString();
    final id = (rawId != null && rawId.isNotEmpty) ? rawId : '';

    final name = json['name']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final role = json['role']?.toString() ?? 'customer';
    final phone = json['phone'] as String?;
    final avatarUrl = json['avatar_url'] as String?;
    DateTime createdAt;
    try {
      final ca = json['created_at']?.toString();
      createdAt =
          ca != null && ca.isNotEmpty ? DateTime.parse(ca) : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }
    return UserModel(
      id: id,
      name: name,
      email: email,
      role: role,
      phone: phone,
      avatarUrl: avatarUrl,
      createdAt: createdAt,
    );
  }

  UserEntity toEntity() => UserEntity(
        id: id,
        name: name,
        email: email,
        role: role,
        phone: phone,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'phone': phone,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, name, email, role, phone, avatarUrl, createdAt];
}

// ─────────────────────────────────────────
// PROFESSIONAL MODEL
// ─────────────────────────────────────────

class ProfessionalModel extends Equatable {
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

  const ProfessionalModel({
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
  });

  factory ProfessionalModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return ProfessionalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: user?['name'] as String? ?? '',
      avatarUrl: user?['avatar_url'] as String?,
      skills: List<String>.from(json['skills'] as List? ?? []),
      verified: json['verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      priceRange: json['price_range'] as String?,
      priceMin: (json['price_min'] as num?)?.toDouble(),
      priceMax: (json['price_max'] as num?)?.toDouble(),
      city: json['city'] as String?,
      bio: json['bio'] as String?,
      yearsExperience: json['years_experience'] as int? ?? 0,
      available: json['available'] as bool? ?? true,
    );
  }

  ProfessionalEntity toEntity() => ProfessionalEntity(
        id: id,
        userId: userId,
        name: name,
        avatarUrl: avatarUrl,
        skills: skills,
        verified: verified,
        rating: rating,
        reviewCount: reviewCount,
        priceRange: priceRange,
        priceMin: priceMin,
        priceMax: priceMax,
        city: city,
        bio: bio,
        yearsExperience: yearsExperience,
        available: available,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'skills': skills,
        'verified': verified,
        'price_range': priceRange,
        'price_min': priceMin,
        'price_max': priceMax,
        'city': city,
        'bio': bio,
        'years_experience': yearsExperience,
        'available': available,
      };

  @override
  List<Object?> get props =>
      [id, userId, name, skills, verified, rating, reviewCount];
}

// ─────────────────────────────────────────
// BOOKING MODEL
// ─────────────────────────────────────────

class BookingModel extends Equatable {
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
  final ProfessionalModel? professional;
  final UserModel? customer;

  const BookingModel({
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
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    try {
      final proJson = json['professionals'] as Map<String, dynamic>?;
      final custJson = json['users'] as Map<String, dynamic>?;

      final id = json['id']?.toString() ?? '';
      final customerId = json['customer_id']?.toString() ?? '';
      final professionalId = json['professional_id']?.toString() ?? '';
      final serviceType = json['service_type']?.toString() ?? '';
      final description = json['description'] as String?;
      final priceEstimate = (json['price_estimate'] as num?)?.toDouble();
      final status = _parseStatus(json['status']?.toString() ?? 'pending');

      DateTime scheduledDate;
      try {
        final sd = json['scheduled_date']?.toString();
        scheduledDate =
            sd != null && sd.isNotEmpty ? DateTime.parse(sd) : DateTime.now();
      } catch (_) {
        scheduledDate = DateTime.now();
      }

      final address = json['address'] as String?;
      final notes = json['notes'] as String?;

      DateTime createdAt;
      try {
        final ca = json['created_at']?.toString();
        createdAt =
            ca != null && ca.isNotEmpty ? DateTime.parse(ca) : DateTime.now();
      } catch (_) {
        createdAt = DateTime.now();
      }

      return BookingModel(
        id: id,
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        description: description,
        priceEstimate: priceEstimate,
        status: status,
        scheduledDate: scheduledDate,
        address: address,
        notes: notes,
        createdAt: createdAt,
        professional:
            proJson != null ? ProfessionalModel.fromJson(proJson) : null,
        customer: custJson != null ? UserModel.fromJsonSafe(custJson) : null,
      );
    } catch (e, st) {
      debugPrint('[BookingModel.fromJson] error parsing json: $e');
      debugPrint('payload: $json');
      debugPrint(st.toString());
      rethrow;
    }
  }

  static BookingStatus _parseStatus(String s) {
    switch (s) {
      case 'accepted':
        return BookingStatus.accepted;
      case 'in_progress':
        return BookingStatus.inProgress;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  static String statusToString(BookingStatus s) {
    switch (s) {
      case BookingStatus.accepted:
        return 'accepted';
      case BookingStatus.inProgress:
        return 'in_progress';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  BookingEntity toEntity() => BookingEntity(
        id: id,
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        description: description,
        priceEstimate: priceEstimate,
        status: status,
        scheduledDate: scheduledDate,
        address: address,
        notes: notes,
        createdAt: createdAt,
        professional: professional?.toEntity(),
        customer: customer?.toEntity(),
      );

  /// Copy with a new status (used when updating locally before API confirms).
  BookingModel copyWithStatus(BookingStatus newStatus) => BookingModel(
        id: id,
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        description: description,
        priceEstimate: priceEstimate,
        status: newStatus,
        scheduledDate: scheduledDate,
        address: address,
        notes: notes,
        createdAt: createdAt,
        professional: professional,
        customer: customer,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'professional_id': professionalId,
        'service_type': serviceType,
        'description': description,
        'price_estimate': priceEstimate,
        'status': statusToString(status),
        'scheduled_date': scheduledDate.toIso8601String(),
        'address': address,
        'notes': notes,
      };

  @override
  List<Object?> get props =>
      [id, customerId, professionalId, status, scheduledDate];
}

// ─────────────────────────────────────────
// REVIEW MODEL
// ─────────────────────────────────────────

class ReviewModel extends Equatable {
  final String id;
  final String bookingId;
  final String customerId;
  final String professionalId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? customerName;
  final String? customerAvatar;

  const ReviewModel({
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

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      customerId: json['customer_id'] as String,
      professionalId: json['professional_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      customerName: user?['name'] as String?,
      customerAvatar: user?['avatar_url'] as String?,
    );
  }

  ReviewEntity toEntity() => ReviewEntity(
        id: id,
        bookingId: bookingId,
        customerId: customerId,
        professionalId: professionalId,
        rating: rating,
        comment: comment,
        createdAt: createdAt,
        customerName: customerName,
        customerAvatar: customerAvatar,
      );

  Map<String, dynamic> toJson() => {
        'booking_id': bookingId,
        'customer_id': customerId,
        'professional_id': professionalId,
        'rating': rating,
        'comment': comment,
      };

  @override
  List<Object?> get props => [id, bookingId, rating, comment];
}
