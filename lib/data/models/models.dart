// lib/data/models/models.dart
// Self-contained models — NO inheritance from entity classes.
//
// SCHEDULING UPDATE:
//   • Added BookingStatus.scheduleProposed and BookingStatus.scheduled.
//   • _parseStatus() and statusToString() handle 'schedule_proposed' and
//     'scheduled' DB values.
//   • BookingModel now carries scheduledTime (DateTime?) and
//     rescheduleReason (String?) — mapped from the new DB columns
//     scheduled_time and reschedule_reason.
//
// COMPLETION UPDATE:
//   • Added BookingStatus.pendingCustomerConfirmation.
//   • DB value: 'pending_customer_confirmation'.
//   • Pro marks job done → status = pendingCustomerConfirmation.
//   • Customer confirms → status = completed.
//
// ARRIVAL CONFIRMATION UPDATE:
//   • Added BookingStatus.pendingArrivalConfirmation between scheduled and assessment.
//   • Handyman taps "I've Arrived" → status = pendingArrivalConfirmation.
//   • Customer confirms arrival → status = assessment (price-setting unlocked).
//   • DB value: 'pending_arrival_confirmation'.
//   • _parseStatus() and statusToString() handle the new value.
//
// BACKJOB / WARRANTY UPDATE:
//   • ServiceOfferModel — added `warrantyDays` (int, default 0).
//     Reads `warranty_days` from service_proposals DB column.
//   • BookingModel — added:
//       isBackjob         — bool, reads `is_backjob` DB column.
//       originalBookingId — String?, reads `original_booking_id` DB column.
//       warrantyExpiresAt — DateTime?, reads `warranty_expires_at` DB column.
//     All three included in fromJson, toJson, toEntity, copyWithStatus,
//     and copyWithProLocation.

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

  factory UserModel.fromJsonSafe(Map<String, dynamic> json) {
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
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int subscriptionTier;
  final DateTime? tierExpiresAt;

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
    this.phone,
    this.latitude,
    this.longitude,
    this.subscriptionTier = 0,
    this.tierExpiresAt,
  });

  factory ProfessionalModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return ProfessionalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: user?['name'] as String? ?? '',
      avatarUrl: user?['avatar_url'] as String?,
      phone: user?['phone'] as String?,
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      subscriptionTier: json['subscription_tier'] as int? ?? 0,
      tierExpiresAt: json['tier_expires_at'] != null
          ? DateTime.tryParse(json['tier_expires_at'] as String)
          : null,
    );
  }

  ProfessionalModel copyWithLocation(double? lat, double? lng) =>
      ProfessionalModel(
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
        phone: phone,
        latitude: lat,
        longitude: lng,
        subscriptionTier: subscriptionTier,
        tierExpiresAt: tierExpiresAt,
      );

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
        phone: phone,
        latitude: latitude,
        longitude: longitude,
        subscriptionTier: subscriptionTier,
        tierExpiresAt: tierExpiresAt,
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
        'latitude': latitude,
        'longitude': longitude,
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        skills,
        verified,
        rating,
        reviewCount,
        subscriptionTier
      ];
}

// ─────────────────────────────────────────
// BOOKING MODEL
// ─────────────────────────────────────────

class BookingModel extends Equatable {
  final String id;
  final String customerId;
  final String professionalId;
  final String serviceType;

  /// The specific service name selected by the customer (e.g. 'Faucet/Bidet Install').
  /// Stored in bookings.service_title. Used for exact matching against
  /// professional_services so only handymen who offer this exact service
  /// receive the booking request.
  final String? serviceTitle;

  final String? description;
  final double? priceEstimate;
  final BookingStatus status;
  final DateTime scheduledDate;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final ProfessionalModel? professional;
  final UserModel? customer;
  final double? latitude;
  final double? longitude;
  final double? assessmentPrice;

  /// Public URL of the customer's uploaded photo — stored in Supabase Storage
  /// (booking-photos bucket) and written to the bookings.photo_url column.
  final String? photoUrl;

  /// Date/time proposed by the handyman (status = scheduleProposed or scheduled).
  final DateTime? scheduledTime;

  /// Reason given when the handyman proposes a reschedule.
  final String? rescheduleReason;

  /// True when the customer submitted a free-text service request via the
  /// "Can't find what you need?" flow (no catalogue entry, no price range).
  /// Set at booking-creation time and persisted to the DB as is_custom_request.
  /// Drives the amber "Custom Request" banner so the professional knows
  /// pricing must be set on-site.
  final bool isCustomRequest;

  // ── BACKJOB / WARRANTY ────────────────────────────────────────────────────

  /// True when this booking was created as a warranty / backjob claim.
  final bool isBackjob;

  /// UUID of the completed booking that triggered this warranty claim.
  /// Null for regular (non-backjob) bookings.
  final String? originalBookingId;

  /// UTC timestamp after which the warranty on the original booking expires.
  /// Written when [customerConfirmCompletion] is called and the service
  /// has warrantyDays > 0.  Null means no warranty for this booking.
  final DateTime? warrantyExpiresAt;

  const BookingModel({
    required this.id,
    required this.customerId,
    required this.professionalId,
    required this.serviceType,
    this.serviceTitle,
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
    this.photoUrl,
    this.scheduledTime,
    this.rescheduleReason,
    this.isCustomRequest = false,
    this.isBackjob = false,
    this.originalBookingId,
    this.warrantyExpiresAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    try {
      final proJson = json['professionals'] as Map<String, dynamic>?;
      final custJson = json['users'] as Map<String, dynamic>?;

      final id = json['id']?.toString() ?? '';
      final customerId = json['customer_id']?.toString() ?? '';
      final professionalId = json['professional_id']?.toString() ?? '';
      final serviceType = json['service_type']?.toString() ?? '';
      final serviceTitle = json['service_title'] as String?;
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

      // Parse scheduledTime from the scheduled_time column
      DateTime? scheduledTime;
      try {
        final st = json['scheduled_time']?.toString();
        if (st != null && st.isNotEmpty) scheduledTime = DateTime.parse(st);
      } catch (_) {}

      final rescheduleReason = json['reschedule_reason'] as String?;

      // Parse photo_url — set when customer uploads a photo during booking creation.
      final photoUrl = json['photo_url'] as String?;

      // Parse isCustomRequest — indicates free-text / unlisted service.
      final isCustomRequest = json['is_custom_request'] as bool? ?? false;

      // ── Backjob / warranty fields ─────────────────────────────────────────
      final isBackjob = json['is_backjob'] as bool? ?? false;
      final originalBookingId = json['original_booking_id'] as String?;
      DateTime? warrantyExpiresAt;
      try {
        final wea = json['warranty_expires_at']?.toString();
        if (wea != null && wea.isNotEmpty) {
          warrantyExpiresAt = DateTime.parse(wea);
        }
      } catch (_) {}

      return BookingModel(
        id: id,
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        serviceTitle: serviceTitle,
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
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        assessmentPrice: (json['assessment_price'] as num?)?.toDouble(),
        photoUrl: photoUrl,
        scheduledTime: scheduledTime,
        rescheduleReason: rescheduleReason,
        isCustomRequest: isCustomRequest,
        isBackjob: isBackjob,
        originalBookingId: originalBookingId,
        warrantyExpiresAt: warrantyExpiresAt,
      );
    } catch (e, st) {
      debugPrint('[BookingModel.fromJson] error parsing json: $e');
      debugPrint('payload: $json');
      debugPrint(st.toString());
      rethrow;
    }
  }

  // ── Status parsing ────────────────────────────────────────
  static BookingStatus _parseStatus(String s) {
    switch (s) {
      case 'accepted':
        return BookingStatus.accepted;
      case 'schedule_proposed':
        return BookingStatus.scheduleProposed;
      case 'scheduled':
        return BookingStatus.scheduled;
      case 'pending_arrival_confirmation':
        return BookingStatus.pendingArrivalConfirmation;
      case 'assessment':
        return BookingStatus.assessment;
      case 'in_progress':
        return BookingStatus.inProgress;
      // Pro marked done; customer must confirm before status = completed
      case 'pending_customer_confirmation':
        return BookingStatus.pendingCustomerConfirmation;
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
      case BookingStatus.scheduleProposed:
        return 'schedule_proposed';
      case BookingStatus.scheduled:
        return 'scheduled';
      case BookingStatus.pendingArrivalConfirmation:
        return 'pending_arrival_confirmation';
      case BookingStatus.assessment:
        return 'assessment';
      case BookingStatus.inProgress:
        return 'in_progress';
      case BookingStatus.pendingCustomerConfirmation:
        return 'pending_customer_confirmation';
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
        serviceTitle: serviceTitle,
        description: description,
        priceEstimate: priceEstimate,
        status: status,
        scheduledDate: scheduledDate,
        address: address,
        notes: notes,
        createdAt: createdAt,
        professional: professional?.toEntity(),
        customer: customer?.toEntity(),
        latitude: latitude,
        longitude: longitude,
        photoUrl: photoUrl,
        assessmentPrice: assessmentPrice,
        scheduledTime: scheduledTime,
        rescheduleReason: rescheduleReason,
        isCustomRequest: isCustomRequest,
        isBackjob: isBackjob,
        originalBookingId: originalBookingId,
        warrantyExpiresAt: warrantyExpiresAt,
      );

  BookingModel copyWithStatus(BookingStatus newStatus) => BookingModel(
        id: id,
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        serviceTitle: serviceTitle,
        description: description,
        priceEstimate: priceEstimate,
        status: newStatus,
        scheduledDate: scheduledDate,
        address: address,
        notes: notes,
        createdAt: createdAt,
        professional: professional,
        customer: customer,
        latitude: latitude,
        longitude: longitude,
        assessmentPrice: assessmentPrice,
        photoUrl: photoUrl,
        scheduledTime: scheduledTime,
        rescheduleReason: rescheduleReason,
        isCustomRequest: isCustomRequest,
        isBackjob: isBackjob,
        originalBookingId: originalBookingId,
        warrantyExpiresAt: warrantyExpiresAt,
      );

  BookingModel copyWithProLocation(double? lat, double? lng) => BookingModel(
        id: id,
        customerId: customerId,
        professionalId: professionalId,
        serviceType: serviceType,
        serviceTitle: serviceTitle,
        description: description,
        priceEstimate: priceEstimate,
        status: status,
        scheduledDate: scheduledDate,
        address: address,
        notes: notes,
        createdAt: createdAt,
        professional: professional?.copyWithLocation(lat, lng),
        customer: customer,
        latitude: latitude,
        longitude: longitude,
        assessmentPrice: assessmentPrice,
        photoUrl: photoUrl,
        scheduledTime: scheduledTime,
        rescheduleReason: rescheduleReason,
        isCustomRequest: isCustomRequest,
        isBackjob: isBackjob,
        originalBookingId: originalBookingId,
        warrantyExpiresAt: warrantyExpiresAt,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'professional_id': professionalId,
        'service_type': serviceType,
        'service_title': serviceTitle,
        'description': description,
        'price_estimate': priceEstimate,
        'status': statusToString(status),
        // Persist scheduled date in UTC so parsing is consistent across devices.
        'scheduled_date': scheduledDate.toUtc().toIso8601String(),
        'address': address,
        'notes': notes,
        'latitude': latitude,
        'longitude': longitude,
        'assessment_price': assessmentPrice,
        'scheduled_time': scheduledTime?.toUtc().toIso8601String(),
        'reschedule_reason': rescheduleReason,
        'is_custom_request': isCustomRequest,
        'is_backjob': isBackjob,
        if (originalBookingId != null) 'original_booking_id': originalBookingId,
        if (warrantyExpiresAt != null)
          'warranty_expires_at': warrantyExpiresAt!.toUtc().toIso8601String(),
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

// ─────────────────────────────────────────
// SERVICE OFFER MODEL
// ─────────────────────────────────────────

class ServiceOfferModel extends Equatable {
  final String id;
  final String slug;
  final String serviceName;
  final String serviceType;
  final String? description;

  /// Network URL (Supabase Storage). Previously `imagePath` (local asset).
  final String? imageUrl;

  final List<String> includes;
  final String? priceRange;
  final String? duration;
  final String? tips;
  final DateTime? createdAt;

  /// professional_id from service_proposals — null for admin-seeded rows.
  final String? professionalId;

  /// Warranty period in days. 0 = no warranty.
  /// Stored in service_proposals.warranty_days.
  /// Used to compute warrantyExpiresAt when a booking is completed and to
  /// drive the Backjob CTA visibility on the customer side.
  final int warrantyDays;

  const ServiceOfferModel({
    required this.id,
    required this.slug,
    required this.serviceName,
    required this.serviceType,
    this.description,
    this.imageUrl,
    required this.includes,
    this.priceRange,
    this.duration,
    this.tips,
    this.createdAt,
    this.professionalId,
    this.warrantyDays = 0,
  });

  factory ServiceOfferModel.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    try {
      final ca = json['created_at']?.toString();
      if (ca != null && ca.isNotEmpty) created = DateTime.parse(ca);
    } catch (_) {}

    return ServiceOfferModel(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['service_name']?.toString() ?? '',
      serviceName: json['service_name']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      description: json['description'] as String?,
      // Reads 'image_url' from service_proposals; falls back to legacy
      // 'image_path' field for any existing rows in the old services table.
      imageUrl:
          (json['image_url'] as String?) ?? (json['image_path'] as String?),
      includes: (json['includes'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          [],
      priceRange: json['price_range'] as String?,
      duration: json['duration'] as String?,
      tips: json['tips'] as String?,
      createdAt: created,
      professionalId: json['professional_id'] as String?,
      warrantyDays: (json['warranty_days'] as int?) ?? 0,
    );
  }

  ServiceOfferEntity toEntity() => ServiceOfferEntity(
        id: id,
        slug: slug,
        serviceName: serviceName,
        serviceType: serviceType,
        description: description,
        imageUrl: imageUrl,
        includes: includes,
        priceRange: priceRange,
        duration: duration,
        tips: tips,
        createdAt: createdAt,
        professionalId: professionalId,
        warrantyDays: warrantyDays,
      );

  @override
  List<Object?> get props => [id, slug, serviceName, serviceType];
}

// ─────────────────────────────────────────
// SUBSCRIPTION REQUEST MODEL
// ─────────────────────────────────────────

class SubscriptionRequestModel extends Equatable {
  final String id;
  final String professionalId;
  final String? handymanName;
  final int requestedTier;
  final int currentTier;
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SubscriptionRequestModel({
    required this.id,
    required this.professionalId,
    this.handymanName,
    required this.requestedTier,
    required this.currentTier,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionRequestModel.fromJson(Map<String, dynamic> json) {
    final proJson = json['professionals'] as Map<String, dynamic>?;
    final userJson = proJson?['users'] as Map<String, dynamic>?;
    final handymanName = userJson?['name'] as String?;
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['created_at'] as String);
    } catch (_) {
      createdAt = DateTime.now();
    }
    DateTime? updatedAt;
    try {
      final ua = json['updated_at'] as String?;
      if (ua != null) updatedAt = DateTime.parse(ua);
    } catch (_) {}
    return SubscriptionRequestModel(
      id: json['id'] as String,
      professionalId: json['professional_id'] as String,
      handymanName: handymanName,
      requestedTier: json['requested_tier'] as int? ?? 1,
      currentTier: json['current_tier'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      adminNote: json['admin_note'] as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  SubscriptionRequestEntity toEntity() => SubscriptionRequestEntity(
        id: id,
        professionalId: professionalId,
        handymanName: handymanName,
        requestedTier: requestedTier,
        currentTier: currentTier,
        status: status,
        adminNote: adminNote,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  String get requestedTierLabel {
    switch (requestedTier) {
      case 2:
        return 'AYO Elite';
      case 1:
        return 'AYO Pro';
      default:
        return 'Free';
    }
  }

  String get currentTierLabel {
    switch (currentTier) {
      case 2:
        return 'AYO Elite';
      case 1:
        return 'AYO Pro';
      default:
        return 'Free';
    }
  }

  bool get isPending => status == 'pending';

  Map<String, dynamic> toJson() => {
        'professional_id': professionalId,
        'requested_tier': requestedTier,
        'current_tier': currentTier,
        'status': status,
        if (adminNote != null) 'admin_note': adminNote,
      };

  @override
  List<Object?> get props => [id, professionalId, requestedTier, status];
}
