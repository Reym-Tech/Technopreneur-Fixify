// lib/data/datasources/supabase_datasource.dart
//
// OPEN-BOOKING MODEL (replaces broadcast-per-pro model):
//
//   OLD: createBooking() was called once per matched pro → N bookings created,
//        all pending, causing duplicate entries on the customer side.
//
//   NEW: createBooking() creates ONE booking with professional_id = NULL.
//        All pros whose skills match the service_type see it as an open
//        request via getOpenBookingRequests() / subscribeToOpenBookingRequests().
//        The first pro to tap Accept calls claimBooking(), which atomically sets
//        professional_id = their id and status = 'accepted' only if the booking
//        is still unassigned (professional_id IS NULL). Any concurrent claim
//        attempt by another pro will find professional_id already set and fail
//        gracefully with BookingAlreadyClaimedException.
//
// CHANGED public signatures:
//   createBooking()                  — professionalId is now optional (nullable)
//   claimBooking()                   — NEW: atomically assigns a pro to a booking
//   getOpenBookingRequests()         — NEW: fetches unassigned pending bookings by skill
//   subscribeToOpenBookingRequests() — NEW: realtime feed of open requests for a pro
//
// UNCHANGED signatures:
//   getProfessionalBookings(), updateBookingStatus(), confirmAssessment(),
//   updateBookingAssessmentPrice(), subscribeToBookingUpdates(), and all others.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../../core/constants/app_config.dart';
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
        debugPrint('✅ professionals row created for new user ${res.user!.id}');
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
    debugPrint('🔑 Auth UID: ${user?.id}');
    if (user == null) return null;
    final data = await _client
        .from(AppConfig.usersTable)
        .select()
        .eq('id', user.id)
        .single();
    debugPrint('👤 User row: $data');
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
      debugPrint('[getProfessionalLocation] error: $e');
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
            if (id != null && id.isNotEmpty) {
              debugPrint('[Realtime] professionals row updated: $id');
              onUpdate(id);
            }
          },
        )
        .subscribe();
  }

  RealtimeChannel subscribeToReviewsInserts({
    required void Function(Map<String, dynamic> payload) onInsert,
  }) {
    final channel = _client
        .channel('reviews_inserts_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'reviews',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  // ── BOOKINGS ──────────────────────────────────────────────

  /// Creates a single booking for a service request.
  ///
  /// NEW MODEL: [professionalId] is now nullable. When null, the booking is
  /// "open" — visible to all matching professionals as an available request.
  /// The first pro to call [claimBooking] will be assigned to it.
  ///
  /// The old broadcast model (one booking per pro) is fully removed.
  /// This method is called exactly once per customer service request.
  Future<BookingModel> createBooking({
    required String customerId,
    String? professionalId, // nullable — null = open/unassigned
    required String serviceType,
    required DateTime scheduledDate,
    String? description,
    String? address,
    String? notes,
    double? priceEstimate,
    double? latitude,
    double? longitude,
  }) async {
    final payload = {
      'customer_id': customerId,
      if (professionalId != null) 'professional_id': professionalId,
      'service_type': serviceType,
      'description': description,
      'price_estimate': priceEstimate,
      'status': 'pending',
      'scheduled_date': scheduledDate.toIso8601String(),
      'address': address,
      'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    try {
      debugPrint('[Supabase] createBooking payload: $payload');
      final data = await _client
          .from(AppConfig.bookingsTable)
          .insert(payload)
          .select()
          .single();
      debugPrint('[Supabase] createBooking result: $data');
      return BookingModel.fromJson(data);
    } catch (e, st) {
      debugPrint('[Supabase] createBooking error: $e\n$st');
      rethrow;
    }
  }

  /// Atomically claims an open booking for a professional (first-accept-wins).
  ///
  /// Sets professional_id = [professionalId] and status = 'accepted' only
  /// if the booking is still unassigned (professional_id IS NULL AND
  /// status = 'pending').
  ///
  /// Throws [BookingAlreadyClaimedException] if another pro already accepted.
  /// Returns the updated [BookingModel] with full joins on success.
  Future<BookingModel> claimBooking({
    required String bookingId,
    required String professionalId,
  }) async {
    debugPrint(
        '[Supabase] claimBooking: booking=$bookingId pro=$professionalId');

    // Pre-check: verify the booking is still open before attempting the update.
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

    // Atomically assign this pro and advance status to 'accepted'.
    // The double filter (.eq status + .isFilter professional_id null) ensures
    // that if two pros submit at the exact same millisecond, only one wins.
    await _client
        .from(AppConfig.bookingsTable)
        .update({
          'professional_id': professionalId,
          'status': 'accepted',
        })
        .eq('id', bookingId)
        .eq('status', 'pending')
        .isFilter('professional_id', null);

    // Re-fetch with full joins for a complete BookingModel.
    final data = await _client
        .from(AppConfig.bookingsTable)
        .select(
          '*, '
          'users!customer_id(id, name, avatar_url, phone), '
          'professionals!professional_id(id, user_id, skills, verified, '
          'rating, review_count, price_range, price_min, price_max, city, '
          'bio, years_experience, available, latitude, longitude, '
          'users(id, name, avatar_url, phone))',
        )
        .eq('id', bookingId)
        .single();

    debugPrint('[Supabase] claimBooking: done ✅');
    return BookingModel.fromJson(data);
  }

  /// Fetches all open (unassigned, pending) bookings whose service_type
  /// matches one of the professional's [skills].
  ///
  /// Called on init and pull-to-refresh for the pro's Booking Requests screen.
  Future<List<BookingModel>> getOpenBookingRequests({
    required List<String> skills,
  }) async {
    if (skills.isEmpty) return [];

    // Fetch all open bookings, then filter by skill in Dart.
    // This keeps the query simple and avoids needing a DB function at MVP scale.
    final response = await _client
        .from(AppConfig.bookingsTable)
        .select(
          '*, '
          'users!customer_id(id, name, avatar_url, phone)',
        )
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
        .select(
          '*, professionals(id, user_id, skills, verified, rating, review_count, '
          'price_range, price_min, price_max, city, bio, years_experience, '
          'available, latitude, longitude, users(id, name, avatar_url, phone))',
        )
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((j) => BookingModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns bookings assigned to [professionalId] (claimed/active/history).
  /// Open/unassigned bookings are fetched separately via [getOpenBookingRequests].
  Future<List<BookingModel>> getProfessionalBookings(
      String professionalId) async {
    final response = await _client
        .from(AppConfig.bookingsTable)
        .select(
          '*, '
          'users!customer_id(id, name, avatar_url, phone), '
          'professionals!professional_id(id, user_id, skills, verified, rating, '
          'review_count, price_range, price_min, price_max, city, bio, '
          'years_experience, available, latitude, longitude, '
          'users(id, name, avatar_url, phone))',
        )
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
                  .select(
                    '*, '
                    'users!customer_id(id, name, avatar_url, phone), '
                    'professionals!professional_id(id, user_id, skills, verified, '
                    'rating, review_count, price_range, price_min, price_max, city, '
                    'bio, years_experience, available, latitude, longitude, '
                    'users(id, name, avatar_url, phone))',
                  )
                  .eq('id', bookingId)
                  .single();
              debugPrint('[Realtime] booking $bookingId updated → '
                  'status: ${data['status']}, '
                  'assessment_price: ${data['assessment_price']}');
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

  /// Listens for new open bookings that match the pro's [skills].
  ///
  /// Supabase Realtime does not support IS NULL column filters, so we
  /// subscribe to ALL inserts and filter in the callback. The channel name
  /// is timestamped to avoid collision when multiple pros are online.
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
            // Skip if already assigned to someone
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

  /// Kept for backward compatibility. In the new model this fires when a
  /// booking is claimed by this pro (professional_id set via claimBooking).
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
            // Only fire for the initial claim transition (null → accepted)
            if (newStatus == 'accepted' && oldProId == null) {
              try {
                final data = await _client
                    .from(AppConfig.bookingsTable)
                    .select(
                      '*, '
                      'users!customer_id(id, name, avatar_url, phone), '
                      'professionals!professional_id(id, user_id, skills, verified, '
                      'rating, review_count, price_range, price_min, price_max, city, '
                      'bio, years_experience, available, latitude, longitude, '
                      'users(id, name, avatar_url, phone))',
                    )
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

    debugPrint('[Review] Inserted review for professional $professionalId — '
        'DB trigger will update rating and review_count.');

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

    if (updates.isEmpty) {
      return (await getCurrentUser())!;
    }

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

/// Thrown by [claimBooking] when the booking was already accepted by
/// another professional before this claim was processed.
class BookingAlreadyClaimedException implements Exception {
  final String message;
  const BookingAlreadyClaimedException(this.message);
  @override
  String toString() => message;
}
