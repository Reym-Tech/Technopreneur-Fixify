// lib/data/datasources/notification_datasource.dart
//
// NotificationDataSource — reads/writes the `notifications` table.
//
// Table schema (created by notifications_setup.sql):
//   id              UUID PK
//   user_id         UUID FK → users.id
//   role            TEXT    — 'customer' | 'professional' | 'admin'
//   type            TEXT    — fine-grained event type (see NotificationTypeStrings)
//   title           TEXT
//   message         TEXT
//   is_read         BOOL    DEFAULT false
//   reference_id    UUID?   — booking_id / application_id / review_id
//   reference_type  TEXT?   — 'booking' | 'application' | 'review'
//   data            JSONB?  — arbitrary extra payload
//   created_at      TIMESTAMPTZ

import 'package:supabase_flutter/supabase_flutter.dart';

// ── Type-string constants ─────────────────────────────────────
abstract class NotificationTypeStrings {
  // Customer
  static const bookingSubmitted = 'booking_submitted';
  static const bookingAccepted = 'booking_accepted';
  static const bookingInProgress = 'booking_in_progress';
  static const bookingCompleted = 'booking_completed';
  static const promotion = 'promotion';
  static const systemCustomer = 'system_customer';

  // Professional
  static const bookingRequest = 'booking_request';
  static const bookingCancelled = 'booking_cancelled';
  static const applicationSubmitted = 'application_submitted';
  static const applicationApproved = 'application_approved';
  static const applicationRejected = 'application_rejected';
  static const reviewReceived = 'review_received';
  static const paymentProcessed = 'payment_processed';

  // Admin
  static const newApplication = 'new_application';
  static const applicationReviewed = 'application_reviewed';
  static const userReport = 'user_report';
  static const systemAdmin = 'system_admin';
}

// ── Model ─────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String userId;
  final String role;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String? referenceId;
  final String? referenceType;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.role,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.referenceId,
    this.referenceType,
    this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      role: j['role'] as String,
      type: j['type'] as String,
      title: j['title'] as String,
      message: j['message'] as String,
      isRead: j['is_read'] as bool? ?? false,
      referenceId: j['reference_id'] as String?,
      referenceType: j['reference_type'] as String?,
      data: j['data'] != null
          ? Map<String, dynamic>.from(j['data'] as Map)
          : null,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  /// Returns a copy with [isRead] set to true.
  AppNotification copyAsRead() => AppNotification(
        id: id,
        userId: userId,
        role: role,
        type: type,
        title: title,
        message: message,
        isRead: true,
        referenceId: referenceId,
        referenceType: referenceType,
        data: data,
        createdAt: createdAt,
      );
}

// ── DataSource ────────────────────────────────────────────────

class NotificationDataSource {
  final SupabaseClient _client;
  static const _table = 'notifications';

  NotificationDataSource(this._client);

  // ── Fetch notifications for a user (role-scoped) ──────────
  //
  // Pass [limit] to cap results (default 50).
  // Pass [onlyUnread] = true to fetch only unread items.
  Future<List<AppNotification>> getNotifications({
    required String userId,
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    // All .eq() filters must be applied BEFORE .order() and .limit()
    // because .limit() returns a PostgrestTransformBuilder which does
    // not support filter methods like .eq().
    var query = _client.from(_table).select().eq('user_id', userId);

    if (onlyUnread) {
      query = query.eq('is_read', false);
    }

    final data = await query.order('created_at', ascending: false).limit(limit);

    return (data as List)
        .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Mark a single notification as read ───────────────────
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from(_table)
        .update({'is_read': true}).eq('id', notificationId);
  }

  // ── Mark all notifications as read for a user ────────────
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from(_table)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ── Get unread count only (lightweight) ──────────────────
  Future<int> getUnreadCount(String userId) async {
    final data = await _client
        .from(_table)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }

  // ── Admin: manually push a broadcast notification ────────
  // Useful for promotions, system alerts, announcements.
  Future<void> pushToUser({
    required String targetUserId,
    required String role,
    required String type,
    required String title,
    required String message,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? data,
  }) async {
    await _client.from(_table).insert({
      'user_id': targetUserId,
      'role': role,
      'type': type,
      'title': title,
      'message': message,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'data': data,
    });
  }

  // ── Realtime: subscribe to new notifications for a user ──
  //
  // The channel fires [onNew] whenever a row is INSERT-ed for this user.
  // Call [unsubscribe] on the returned channel when the widget disposes.
  RealtimeChannel subscribeToNotifications({
    required String userId,
    required void Function(AppNotification) onNew,
  }) {
    return _client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notification = AppNotification.fromJson(payload.newRecord);
            onNew(notification);
          },
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}
