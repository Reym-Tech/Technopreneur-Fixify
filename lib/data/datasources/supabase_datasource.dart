// lib/data/datasources/supabase_datasource.dart
//
// SCHEDULING UPDATE:
//   proposeSchedule()    — Handyman sets a start date/time after accepting.
//                          Sets status = 'schedule_proposed' and writes
//                          scheduled_time to the bookings row.
//                          ✅ Validates proposedTime is in the future.
//   respondToSchedule()  — Customer accepts (→ 'scheduled') or rejects
//                          (→ 'cancelled') the proposed schedule.
//   proposeReschedule()  — Handyman is running late and proposes a new time.
//                          Sets status = 'schedule_proposed' again and writes
//                          the new scheduled_time + reschedule_reason.
//                          ✅ Validates newProposedTime is in the future.
//
// COMPLETION UPDATE:
//   markJobDoneByPro()          — Pro marks job done → status = 'pending_customer_confirmation'.
//   customerConfirmCompletion() — Customer confirms job done → status = 'completed'.
//
// DATE VALIDATION:
//   createBooking() ✅ Validates scheduledDate is not in the past (date only,
//                      time-of-day not enforced since it is a preferred date).
//   proposeSchedule() / proposeReschedule() ✅ Reject times already in the past.
//
// All other public methods are unchanged.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../../core/constants/app_config.dart';
// NOTE: AppConfig must define:
//   static const String bookingPhotosBucket = 'booking_photos';
// Add this alongside avatarsBucket in lib/core/constants/app_config.dart.
// IMPORTANT: The bucket name must match the Supabase Storage bucket exactly
// (underscores, not hyphens). The RLS INSERT policy requires the first path
// segment to equal auth.uid() — so we always use the auth UID, not a
// database row ID, as the folder name.
import '../../domain/entities/entities.dart';

class SupabaseDataSource {
  final SupabaseClient _client;
  SupabaseDataSource(this._client);

  // ── AUTH ──────────────────────────────────────────────────

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);
    if (res.user == null) throw Exception('Sign up failed');

    await _client.from(AppConfig.usersTable).insert({
      'id': res.user!.id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (role == 'professional') {
      try {
        await _client.from(AppConfig.professionalsTable).insert({
          'user_id': res.user!.id,
          'skills': [],
          'verified': false,
          'rating': 0.0,
          'review_count': 0,
          'available': true,
          'years_experience': 0,
        });
      } catch (e) {
        debugPrint('⚠️ Could not create professionals row during signUp: $e');
      }
    }

    final data = await _client
        .from(AppConfig.usersTable)
        .select()
        .eq('id', res.user!.id)
        .single();
    return UserModel.fromJson(data);
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    final res =
        await _client.auth.signInWithPassword(email: email, password: password);
    if (res.user == null) throw Exception('Sign in failed');

    final data = await _client
        .from(AppConfig.usersTable)
        .select()
        .eq('id', res.user!.id)
        .single();
    return UserModel.fromJson(data);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from(AppConfig.usersTable)
        .select()
        .eq('id', user.id)
        .single();
    return UserModel.fromJson(data);
  }

  // ── PROFESSIONALS ─────────────────────────────────────────

  Future<List<ProfessionalModel>> getProfessionals({
    String? skill,
    String? city,
    bool? verified,
  }) async {
    var query = _client
        .from(AppConfig.professionalsTable)
        .select(
          'id, user_id, skills, verified, rating, review_count, '
          'price_range, price_min, price_max, city, bio, '
          'years_experience, available, latitude, longitude, '
          'users(id, name, avatar_url, phone)',
        )
        .eq('available', true);

    if (verified != null) query = query.eq('verified', verified);
    if (city != null && city.isNotEmpty) query = query.eq('city', city);

    final response = await query.order('rating', ascending: false);

    var list = (response as List)
        .map((j) => ProfessionalModel.fromJson(j as Map<String, dynamic>))
        .toList();

    if (skill != null && skill.isNotEmpty && skill != 'All') {
      list = list.where((p) => p.skills.contains(skill.toLowerCase())).toList();
    }
    return list;
  }

  Future<ProfessionalModel?> getProfessionalById(String id) async {
    final data = await _client
        .from(AppConfig.professionalsTable)
        .select('*, users(id, name, avatar_url, phone, email)')
        .eq('id', id)
        .single();
    return ProfessionalModel.fromJson(data);
  }

  Future<ProfessionalModel?> getProfessionalByUserId(String userId) async {
    final data = await _client
        .from(AppConfig.professionalsTable)
        .select('*, users(id, name, avatar_url, phone)')
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ProfessionalModel.fromJson(data);
  }

  Future<({double? latitude, double? longitude})> getProfessionalLocation(
      String professionalId) async {
    try {
      final data = await _client
          .from(AppConfig.professionalsTable)
          .select('latitude, longitude')
          .eq('id', professionalId)
          .single();
      return (
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
      );
    } catch (e) {
      return (latitude: null, longitude: null);
    }
  }

  Future<ProfessionalModel> createProfessionalProfile({
    required String userId,
    required List<String> skills,
    String? priceRange,
    double? priceMin,
    double? priceMax,
    String? city,
    String? bio,
    int yearsExperience = 0,
  }) async {
    final data = await _client
        .from(AppConfig.professionalsTable)
        .insert({
          'user_id': userId,
          'skills': skills,
          'verified': false,
          'rating': 0.0,
          'review_count': 0,
          'price_range': priceRange,
          'price_min': priceMin,
          'price_max': priceMax,
          'city': city,
          'bio': bio,
          'years_experience': yearsExperience,
          'available': true,
        })
        .select('*, users(id, name, avatar_url, phone)')
        .single();
    return ProfessionalModel.fromJson(data);
  }

  Future<List<ReviewModel>> getProfessionalReviewsById(
      String professionalId) async {
    final data = await _client
        .from('reviews')
        .select('*, users!customer_id(name, avatar_url)')
        .eq('professional_id', professionalId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── SERVICE OFFERS ─────────────────────────────────────

  // ── Service Offers — reads approved service_proposals rows ───────────────
  // Approved proposals are the canonical source of service offers.
  // Falls back to the legacy 'services' table (AppConfig.servicesTable) if
  // service_proposals returns nothing, so hardcoded seed data still works
  // during the migration period.

  Future<List<ServiceOfferModel>> getServiceOffers() async {
    try {
      final data = await _client
          .from('service_proposals')
          .select()
          .eq('status', 'approved')
          .order('submitted_at', ascending: false);
      if ((data as List).isNotEmpty) {
        return data.map((j) => ServiceOfferModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('[getServiceOffers] service_proposals error: $e');
    }
    // Legacy fallback — existing services table seed data
    try {
      final data = await _client
          .from(AppConfig.servicesTable)
          .select()
          .order('created_at', ascending: false);
      return (data as List).map((j) => ServiceOfferModel.fromJson(j)).toList();
    } catch (e) {
      debugPrint('[getServiceOffers] legacy fallback error: $e');
      return [];
    }
  }

  Future<ServiceOfferModel?> getServiceOfferBySlug(String slug) async {
    final maybe = await _client
        .from(AppConfig.servicesTable)
        .select()
        .eq('slug', slug)
        .maybeSingle();
    if (maybe == null) return null;
    return ServiceOfferModel.fromJson(maybe);
  }

  // ── PROFESSIONALS REALTIME ────────────────────────────────

  RealtimeChannel subscribeToProfessionalsUpdates({
    required void Function(String professionalId) onUpdate,
  }) {
    return _client
        .channel('professionals_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConfig.professionalsTable,
          callback: (payload) {
            final id = payload.newRecord['id']?.toString();
            if (id != null && id.isNotEmpty) onUpdate(id);
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToReviewsInserts({
    required void Function(Map<String, dynamic> payload) onInsert,
  }) {
    return _client
        .channel('reviews_inserts_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reviews',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

  // ── BOOKINGS ──────────────────────────────────────────────

  /// MODEL: Persists a new booking row.
  /// Validates that scheduledDate is not strictly in the past (date-level check;
  /// time of day is not enforced because this is a preferred date, not an exact
  /// arrival time).
  Future<BookingModel> createBooking({
    required String customerId,
    String? professionalId,
    required String serviceType,
    required DateTime scheduledDate,
    String? description,
    String? address,
    String? notes,
    double? priceEstimate,
    double? latitude,
    double? longitude,
    // Local file path of the photo selected by the customer in Step 2.
    // When provided, the file is uploaded to Supabase Storage and the
    // returned public URL is stored in bookings.photo_url.
    String? photoPath,
  }) async {
    // ── Validation: reject dates in the past ──────────────────────────────
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final requestedDateOnly =
        DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    if (requestedDateOnly.isBefore(todayDateOnly)) {
      throw ArgumentError(
          'Preferred date cannot be in the past. Please choose today or a future date.');
    }

    // ── Upload photo to Storage (if provided) ─────────────────────────────
    // RLS policy on booking_photos bucket:
    //   (storage.foldername(name))[1] = auth.uid()::text
    // This means the first path segment MUST be the authenticated user's UID,
    // not the professionals/customers table row ID (which can differ).
    // Path: booking_photos/<authUid>/<timestamp>.jpg
    String? photoUrl;
    if (photoPath != null && photoPath.isNotEmpty) {
      try {
        final authUid = _client.auth.currentUser?.id;
        if (authUid == null) throw Exception('No authenticated user');

        final file = File(photoPath);
        final fileBytes = await file.readAsBytes();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '$authUid/$timestamp.jpg';

        await _client.storage.from(AppConfig.bookingPhotosBucket).uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );

        photoUrl = _client.storage
            .from(AppConfig.bookingPhotosBucket)
            .getPublicUrl(storagePath);

        debugPrint('[Supabase] createBooking: photo uploaded ✅ $photoUrl');
      } catch (e) {
        // Photo upload failure is non-fatal — booking is still created,
        // but without a photo. Log the error for debugging.
        debugPrint('[Supabase] createBooking: photo upload failed: $e');
      }
    }

    final payload = {
      'customer_id': customerId,
      if (professionalId != null) 'professional_id': professionalId,
      'service_type': serviceType,
      'description': description,
      'price_estimate': priceEstimate,
      'status': 'pending',
      // Store dates in UTC so all devices interpret times consistently.
      'scheduled_date': scheduledDate.toUtc().toIso8601String(),
      'address': address,
      'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      // Only include photo_url when a URL was successfully obtained.
      if (photoUrl != null) 'photo_url': photoUrl,
    };
    try {
      // Insert the booking row, then immediately re-fetch with full joins
      // (_fullBookingSelect) so the returned BookingModel has professional,
      // customer, and photo_url populated — same as every other fetch method.
      final inserted = await _client
          .from(AppConfig.bookingsTable)
          .insert(payload)
          .select('id')
          .single();

      final data = await _client
          .from(AppConfig.bookingsTable)
          .select(_fullBookingSelect)
          .eq('id', inserted['id'] as String)
          .single();

      return BookingModel.fromJson(data);
    } catch (e, st) {
      debugPrint('[Supabase] createBooking error: $e\n$st');
      rethrow;
    }
  }

  Future<BookingModel> claimBooking({
    required String bookingId,
    required String professionalId,
  }) async {
    debugPrint(
        '[Supabase] claimBooking: booking=$bookingId pro=$professionalId');

    final current = await _client
        .from(AppConfig.bookingsTable)
        .select('professional_id, status')
        .eq('id', bookingId)
        .single();

    if (current['professional_id'] != null) {
      throw const BookingAlreadyClaimedException(
          'This request was already accepted by another handyman.');
    }
    if (current['status'] != 'pending') {
      throw const BookingAlreadyClaimedException(
          'This request is no longer available.');
    }

    await _client
        .from(AppConfig.bookingsTable)
        .update({
          'professional_id': professionalId,
          'status': 'accepted',
        })
        .eq('id', bookingId)
        .eq('status', 'pending')
        .isFilter('professional_id', null);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();

    debugPrint('[Supabase] claimBooking: done ✅');
    return BookingModel.fromJson(data);
  }

  // ── SCHEDULING ────────────────────────────────────────────

  /// Called by the handyman after accepting a booking.
  /// Sets status = 'schedule_proposed' and stores the proposed start time.
  /// The customer will see a CTA to review the proposed schedule.
  ///
  /// ✅ Validates that proposedTime is at least 1 minute in the future.
  Future<BookingModel> proposeSchedule({
    required String bookingId,
    required DateTime proposedTime,
  }) async {
    _assertFutureTime(proposedTime, label: 'Proposed start time');
    debugPrint('[Supabase] proposeSchedule: id=$bookingId time=$proposedTime');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'schedule_proposed',
      'scheduled_time': proposedTime.toUtc().toIso8601String(),
      'reschedule_reason': null, // clear any previous reason
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] proposeSchedule: done ✅');
    return BookingModel.fromJson(data);
  }

  /// Called when the customer responds to a proposed schedule.
  /// [accepted] = true  → status becomes 'scheduled'
  /// [accepted] = false → status becomes 'cancelled'
  Future<BookingModel> respondToSchedule({
    required String bookingId,
    required bool accepted,
  }) async {
    final newStatus = accepted ? 'scheduled' : 'cancelled';
    debugPrint(
        '[Supabase] respondToSchedule: id=$bookingId accepted=$accepted');
    await _client.from(AppConfig.bookingsTable).update({
      'status': newStatus,
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] respondToSchedule: done ✅');
    return BookingModel.fromJson(data);
  }

  /// Called when the handyman needs to reschedule (running late, prior job
  /// still in progress, etc.). Sets status back to 'schedule_proposed' with
  /// the new proposed time and an optional reason.
  ///
  /// ✅ Validates that newProposedTime is at least 1 minute in the future.
  Future<BookingModel> proposeReschedule({
    required String bookingId,
    required DateTime newProposedTime,
    String? reason,
  }) async {
    _assertFutureTime(newProposedTime, label: 'Rescheduled time');
    debugPrint(
        '[Supabase] proposeReschedule: id=$bookingId time=$newProposedTime reason=$reason');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'schedule_proposed',
      'scheduled_time': newProposedTime.toUtc().toIso8601String(),
      'reschedule_reason': reason,
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] proposeReschedule: done ✅');
    return BookingModel.fromJson(data);
  }

  // ── SCHEDULE CONFIRMATION ─────────────────────────────────

  /// Called when the handyman confirms the customer's own preferred time.
  ///
  /// Under the simplified scheduling model, customers declare their preferred
  /// time at booking creation. Handymen who can make that time confirm it here,
  /// jumping the booking directly to 'scheduled' — no schedule_proposed /
  /// customer-review step needed.
  ///
  /// NOTE: Intentionally skips _assertFutureTime() — the customer's preferred
  /// time may be "now" or very soon, which would incorrectly fail the 1-minute
  /// future guard for valid same-day confirmations.
  Future<BookingModel> confirmSchedule({
    required String bookingId,
    required DateTime confirmedTime,
  }) async {
    debugPrint('[Supabase] confirmSchedule: id=$bookingId time=$confirmedTime');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'scheduled',
      'scheduled_time': confirmedTime.toUtc().toIso8601String(),
      'reschedule_reason': null,
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] confirmSchedule: done ✅');
    return BookingModel.fromJson(data);
  }

  // ── ARRIVAL CONFIRMATION ──────────────────────────────────

  /// Called by the handyman when they tap "I've Arrived".
  /// Sets status = 'pending_arrival_confirmation'.
  /// The customer will see a CTA to confirm the handyman has arrived.
  /// Only after the customer confirms does the booking advance to 'assessment'
  /// and the price-setting tools unlock for the handyman.
  Future<BookingModel> markHandymanArrived(String bookingId) async {
    debugPrint('[Supabase] markHandymanArrived: id=$bookingId');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'pending_arrival_confirmation',
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] markHandymanArrived: done ✅');
    return BookingModel.fromJson(data);
  }

  /// Called by the customer to confirm the handyman has arrived.
  /// Sets status = 'assessment', unlocking the price-setting tools for the handyman.
  Future<BookingModel> confirmHandymanArrival(String bookingId) async {
    debugPrint('[Supabase] confirmHandymanArrival: id=$bookingId');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'assessment',
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] confirmHandymanArrival: done ✅');
    return BookingModel.fromJson(data);
  }

  // ── COMPLETION ────────────────────────────────────────────

  /// Called by the professional when they believe the job is done.
  /// Sets status = 'pending_customer_confirmation' so the customer can verify.
  Future<BookingModel> markJobDoneByPro(String bookingId) async {
    debugPrint('[Supabase] markJobDoneByPro: id=$bookingId');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'pending_customer_confirmation',
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] markJobDoneByPro: done ✅');
    return BookingModel.fromJson(data);
  }

  /// Called by the customer to confirm the job is truly complete.
  /// Sets status = 'completed'.
  Future<BookingModel> customerConfirmCompletion(String bookingId) async {
    debugPrint('[Supabase] customerConfirmCompletion: id=$bookingId');
    await _client.from(AppConfig.bookingsTable).update({
      'status': 'completed',
    }).eq('id', bookingId);

    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('id', bookingId)
        .single();
    debugPrint('[Supabase] customerConfirmCompletion: done ✅');
    return BookingModel.fromJson(data);
  }

  // ── Internal Validation Helper ────────────────────────────

  /// Throws [ArgumentError] if [time] is not at least 1 minute in the future.
  /// Used by proposeSchedule() and proposeReschedule() to prevent past-time submissions.
  void _assertFutureTime(DateTime time, {String label = 'Time'}) {
    final minAllowed = DateTime.now().add(const Duration(minutes: 1));
    if (time.isBefore(minAllowed)) {
      throw ArgumentError('$label must be at least 1 minute in the future. '
          'Please select a valid date and time.');
    }
  }

  // ── Shared join string ─────────────────────────────────────
  static const String _fullBookingSelect = '*, '
      'users!customer_id(id, name, avatar_url, phone), '
      'professionals!professional_id(id, user_id, skills, verified, '
      'rating, review_count, price_range, price_min, price_max, city, '
      'bio, years_experience, available, latitude, longitude, '
      'users(id, name, avatar_url, phone))';

  // ── BOOKING QUERIES ───────────────────────────────────────

  Future<List<BookingModel>> getOpenBookingRequests({
    required List<String> skills,
  }) async {
    if (skills.isEmpty) return [];

    final response = await _client
        .from(AppConfig.bookingsTable)
        .select('*, users!customer_id(id, name, avatar_url, phone)')
        .eq('status', 'pending')
        .isFilter('professional_id', null)
        .order('created_at', ascending: false);

    final normalizedSkills = skills.map((s) => s.toLowerCase()).toSet();

    return (response as List)
        .map((j) => BookingModel.fromJson(j as Map<String, dynamic>))
        .where((b) => normalizedSkills.contains(b.serviceType.toLowerCase()))
        .toList();
  }

  Future<List<BookingModel>> getCustomerBookings(String customerId) async {
    final response = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((j) => BookingModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<BookingModel>> getProfessionalBookings(
      String professionalId) async {
    final response = await _client
        .from(AppConfig.bookingsTable)
        .select(_fullBookingSelect)
        .eq('professional_id', professionalId)
        .order('created_at', ascending: false);

    return (response as List).map((j) {
      final map = Map<String, dynamic>.from(j as Map<String, dynamic>);
      return BookingModel.fromJson(map);
    }).toList();
  }

  Future<void> updateBookingStatus(
      String bookingId, BookingStatus status) async {
    await _client.from(AppConfig.bookingsTable).update(
        {'status': BookingModel.statusToString(status)}).eq('id', bookingId);
  }

  Future<void> updateBookingAssessmentPrice({
    required String bookingId,
    required double price,
  }) async {
    debugPrint(
        '[Supabase] updateBookingAssessmentPrice: id=$bookingId price=$price');
    await _client.from('bookings').update({
      'assessment_price': price,
      'status': 'assessment',
    }).eq('id', bookingId);
    debugPrint('[Supabase] updateBookingAssessmentPrice: done ✅');
  }

  Future<void> confirmAssessment(String bookingId) async {
    debugPrint('[Supabase] confirmAssessment: id=$bookingId');
    await _client
        .from('bookings')
        .update({'status': 'in_progress'}).eq('id', bookingId);
    debugPrint('[Supabase] confirmAssessment: done ✅');
  }

  // ── REALTIME ──────────────────────────────────────────────

  RealtimeChannel subscribeToBookingUpdates({
    required String bookingId,
    required Function(BookingModel) onUpdate,
  }) {
    return _client
        .channel('booking_$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConfig.bookingsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (payload) async {
            try {
              final data = await _client
                  .from(AppConfig.bookingsTable)
                  .select(_fullBookingSelect)
                  .eq('id', bookingId)
                  .single();
              onUpdate(BookingModel.fromJson(data));
            } catch (e) {
              debugPrint(
                  '[Realtime] Could not re-fetch booking $bookingId: $e');
              onUpdate(BookingModel.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToOpenBookingRequests({
    required List<String> skills,
    required Function(BookingModel) onNewRequest,
  }) {
    final normalizedSkills = skills.map((s) => s.toLowerCase()).toSet();

    return _client
        .channel('open_requests_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConfig.bookingsTable,
          callback: (payload) async {
            final record = payload.newRecord;
            if (record['professional_id'] != null) return;
            final serviceType =
                (record['service_type'] as String?)?.toLowerCase() ?? '';
            if (!normalizedSkills.contains(serviceType)) return;

            try {
              final data = await _client
                  .from(AppConfig.bookingsTable)
                  .select('*, users!customer_id(id, name, avatar_url, phone)')
                  .eq('id', record['id'])
                  .single();
              onNewRequest(BookingModel.fromJson(data));
            } catch (e) {
              debugPrint('[Realtime] Could not re-fetch open request: $e');
              onNewRequest(BookingModel.fromJson(record));
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToProfessionalBookings({
    required String professionalId,
    required Function(BookingModel) onNewBooking,
  }) {
    return _client
        .channel('pro_bookings_$professionalId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConfig.bookingsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'professional_id',
            value: professionalId,
          ),
          callback: (payload) async {
            final newStatus = payload.newRecord['status'] as String?;
            final oldProId = payload.oldRecord['professional_id'] as String?;
            if (newStatus == 'accepted' && oldProId == null) {
              try {
                final data = await _client
                    .from(AppConfig.bookingsTable)
                    .select(_fullBookingSelect)
                    .eq('id', payload.newRecord['id'])
                    .single();
                onNewBooking(BookingModel.fromJson(data));
              } catch (e) {
                debugPrint('[Realtime] Could not re-fetch claimed booking: $e');
                onNewBooking(BookingModel.fromJson(payload.newRecord));
              }
            }
          },
        )
        .subscribe();
  }

  void unsubscribeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);

  /// Listens for ANY update to a specific booking the pro is working on.
  /// Use this on ProBookingDetailScreen so status changes (e.g. customer
  /// confirms schedule) reflect immediately without a hot restart.
  RealtimeChannel subscribeToProfessionalActiveBooking({
    required String bookingId,
    required Function(BookingModel) onUpdate,
  }) {
    return _client
        .channel('pro_active_booking_$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConfig.bookingsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (payload) async {
            try {
              final data = await _client
                  .from(AppConfig.bookingsTable)
                  .select(_fullBookingSelect)
                  .eq('id', bookingId)
                  .single();
              onUpdate(BookingModel.fromJson(data));
            } catch (e) {
              debugPrint('[Realtime] pro active booking re-fetch failed: $e');
            }
          },
        )
        .subscribe();
  }

  // ── REVIEWS ───────────────────────────────────────────────

  Future<bool> hasReviewedBooking({
    required String bookingId,
    required String customerId,
  }) async {
    final response = await _client
        .from(AppConfig.reviewsTable)
        .select('id')
        .eq('booking_id', bookingId)
        .eq('customer_id', customerId)
        .maybeSingle();
    return response != null;
  }

  Future<ReviewModel> createReview({
    required String bookingId,
    required String customerId,
    required String professionalId,
    required int rating,
    String? comment,
  }) async {
    final alreadyReviewed = await hasReviewedBooking(
      bookingId: bookingId,
      customerId: customerId,
    );
    if (alreadyReviewed) {
      throw Exception('You have already submitted a review for this booking.');
    }

    final data = await _client
        .from(AppConfig.reviewsTable)
        .insert({
          'booking_id': bookingId,
          'customer_id': customerId,
          'professional_id': professionalId,
          'rating': rating,
          'comment': comment,
        })
        .select('*, users!customer_id(name, avatar_url)')
        .single();

    return ReviewModel.fromJson(data);
  }

  Future<List<ReviewModel>> getProfessionalReviews(
      String professionalId) async {
    final response = await _client
        .from(AppConfig.reviewsTable)
        .select('*, users!customer_id(name, avatar_url)')
        .eq('professional_id', professionalId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((j) => ReviewModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── PROFESSIONAL LOCATION ─────────────────────────────────

  Future<void> updateProfessionalLocation({
    required String professionalId,
    required double latitude,
    required double longitude,
  }) async {
    await _client.from(AppConfig.professionalsTable).update({
      'latitude': latitude,
      'longitude': longitude,
    }).eq('id', professionalId);
  }

  // ── PROFESSIONAL AVAILABILITY ─────────────────────────────

  Future<void> updateProfessionalAvailability({
    required String professionalId,
    required bool available,
  }) async {
    await _client
        .from(AppConfig.professionalsTable)
        .update({'available': available}).eq('id', professionalId);
  }

  // ── USER PROFILE ──────────────────────────────────────────

  Future<UserModel> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return (await getCurrentUser())!;

    await _client.from(AppConfig.usersTable).update(updates).eq('id', userId);

    final data = await _client
        .from(AppConfig.usersTable)
        .select()
        .eq('id', userId)
        .single();
    return UserModel.fromJson(data);
  }

  Future<String> uploadAvatar(
      String userId, List<int> fileBytes, String fileName) async {
    final path = '$userId/avatar.jpg';

    await _client.storage.from(AppConfig.avatarsBucket).uploadBinary(
          path,
          Uint8List.fromList(fileBytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final base =
        _client.storage.from(AppConfig.avatarsBucket).getPublicUrl(path);
    final busted = '$base?t=${DateTime.now().millisecondsSinceEpoch}';
    return busted;
  }
}

// ── Custom Exceptions ─────────────────────────────────────

class BookingAlreadyClaimedException implements Exception {
  final String message;
  const BookingAlreadyClaimedException(this.message);
  @override
  String toString() => message;
}
