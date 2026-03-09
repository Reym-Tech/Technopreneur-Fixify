// lib/data/datasources/supabase_datasource.dart

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

  /// Fetches just the latest latitude/longitude for a professional.
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

  /// Fetches reviews for [professionalId]. Used by the customer-side
  /// ProfessionalProfileScreen so it doesn't always show "No reviews yet".
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
  //
  // Fires [onUpdate] with the updated professional's id whenever the
  // DB trigger (trg_update_professional_rating) writes a new rating or
  // review_count to the professionals table.
  //
  // The caller should respond by re-fetching the full professionals list.
  //
  // IMPORTANT: The professionals table must be included in the Supabase
  // realtime publication. Run this once in the Supabase SQL editor if it
  // isn't already:
  //   ALTER PUBLICATION supabase_realtime ADD TABLE professionals;
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

  /// Subscribes to new review inserts. More reliable than watching
  /// professionals UPDATE events because INSERT payloads are always
  /// complete regardless of REPLICA IDENTITY settings.
  ///
  /// Returns the channel so the caller can unsubscribe via
  /// [unsubscribeChannel] when done.
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

  Future<BookingModel> createBooking({
    required String customerId,
    required String professionalId,
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
      'professional_id': professionalId,
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
    await _client
        .from('bookings')
        .update({'assessment_price': price}).eq('id', bookingId);
  }

  Future<void> confirmAssessment(String bookingId) async {
    await _client
        .from('bookings')
        .update({'status': 'in_progress'}).eq('id', bookingId);
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
                    '*, professionals(id, user_id, skills, verified, rating, '
                    'review_count, price_range, price_min, price_max, city, bio, '
                    'years_experience, available, latitude, longitude, '
                    'users(id, name, avatar_url, phone))',
                  )
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

  RealtimeChannel subscribeToProfessionalBookings({
    required String professionalId,
    required Function(BookingModel) onNewBooking,
  }) {
    return _client
        .channel('pro_bookings_$professionalId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConfig.bookingsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'professional_id',
            value: professionalId,
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
                  .eq('id', payload.newRecord['id'])
                  .single();
              onNewBooking(BookingModel.fromJson(data));
            } catch (e) {
              debugPrint('[Realtime] Could not re-fetch new booking: $e');
              onNewBooking(BookingModel.fromJson(payload.newRecord));
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
