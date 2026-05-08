import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for handling push notifications and local notifications
/// Manages FCM integration, notification display, and notification tap handling
class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseMessaging _messaging;
  final Function(Map<String, dynamic> data)? onNotificationTap;

  NotificationService({
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseMessaging? messaging,
    this.onNotificationTap,
  })  : _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _messaging = messaging ?? FirebaseMessaging.instance;

  /// Initialize notification service and create Android notification channel
  /// Must be called before displaying any notifications
  Future<void> initialize() async {
    try {
      // Create Android notification channel
      if (Platform.isAndroid) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'chat', // id
          'Chat Messages', // name
          description: 'Notifications for new chat messages',
          importance: Importance.high, // Enables heads-up notifications
          playSound: true,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

        debugPrint('[NotificationService] Android notification channel created');
      }

      // Initialize notification settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      debugPrint('[NotificationService] Notification service initialized');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
      rethrow;
    }
  }

  /// Truncate message to 140 characters with ellipsis if needed
  /// Handles edge cases: empty strings, exactly 140 chars, less than 140 chars
  static String truncateMessage(String message) {
    if (message.length <= 140) {
      return message;
    }
    return '${message.substring(0, 140)}…';
  }

  /// Display local notification for chat messages
  /// Shows notification with "New message" title and truncated body
  /// Includes booking_id and type in notification payload for tap handling
  Future<void> showChatNotification({
    required String title,
    required String body,
    required String bookingId,
  }) async {
    try {
      // Truncate message body to 140 characters
      final truncatedBody = truncateMessage(body);

      // Create notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'chat', // channel id
        'Chat Messages', // channel name
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Create payload with booking_id and type
      final payload = 'booking_id:$bookingId';

      // Display notification
      await _localNotifications.show(
        bookingId.hashCode, // Use booking_id hash as notification ID
        'New message', // Always use "New message" as title
        truncatedBody,
        notificationDetails,
        payload: payload,
      );

      debugPrint('[NotificationService] Notification displayed for booking: $bookingId');
    } catch (e) {
      debugPrint('[NotificationService] Error displaying notification: $e');
      // Don't rethrow - notification failure shouldn't crash the app
    }
  }

  /// Handle notification tap from local notifications
  /// Extracts booking_id from NotificationResponse payload
  /// Calls navigation handler with extracted data
  /// Requirements: 1.3, 5.3
  void _onNotificationTapped(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) {
        debugPrint('[NotificationService] No payload in notification tap');
        return;
      }

      // Parse payload to extract booking_id
      // Expected format: "booking_id:uuid"
      final parts = payload.split(':');
      if (parts.length == 2 && parts[0] == 'booking_id') {
        final bookingId = parts[1];
        debugPrint('[NotificationService] Notification tapped, booking_id: $bookingId');
        
        // Create data map with booking_id and type
        final data = {
          'booking_id': bookingId,
          'type': 'chat_message',
        };
        
        // Call navigation handler with extracted data
        onNotificationTap?.call(data);
      } else {
        debugPrint('[NotificationService] Invalid payload format: $payload');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error handling notification tap: $e');
    }
  }

  /// Set up FCM listeners for foreground messages
  /// Listens to incoming FCM messages when app is in foreground
  /// Extracts message data and displays local notification
  void setupFcmListeners() {
    try {
      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        try {
          debugPrint('[NotificationService] Foreground message received: ${message.messageId}');
          
          // Extract data from FCM message
          final data = message.data;
          final bookingId = data['booking_id'] as String?;
          
          // Validate booking_id is present
          if (bookingId == null || bookingId.isEmpty) {
            debugPrint('[NotificationService] Missing booking_id in FCM message data');
            return;
          }
          
          // Extract notification content
          // Use notification title/body if available, otherwise use data fields
          final title = message.notification?.title ?? data['title'] as String? ?? 'New message';
          final body = message.notification?.body ?? data['body'] as String? ?? '';
          
          if (body.isEmpty) {
            debugPrint('[NotificationService] Empty message body in FCM message');
            return;
          }
          
          // Display local notification
          showChatNotification(
            title: title,
            body: body,
            bookingId: bookingId,
          );
          
          debugPrint('[NotificationService] Foreground notification displayed for booking: $bookingId');
        } catch (e) {
          debugPrint('[NotificationService] Error processing foreground message: $e');
          // Don't rethrow - message processing failure shouldn't crash the app
        }
      });
      
      debugPrint('[NotificationService] FCM listeners set up successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error setting up FCM listeners: $e');
      // Don't rethrow - listener setup failure shouldn't crash the app
    }
  }

  /// Set up token refresh listener
  /// Listens to FCM token refresh events and updates the database
  /// Requirements: 8.4
  void setupTokenRefreshListener(
    Future<void> Function({required String platform, required String token}) upsertMyPushToken,
  ) {
    try {
      // Listen for token refresh events
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          debugPrint('[NotificationService] FCM token refreshed: ${newToken.substring(0, 20)}...');
          
          // Determine platform
          final platform = Platform.isIOS 
              ? 'ios' 
              : Platform.isAndroid 
                  ? 'android' 
                  : 'web';
          
          // Update token in database
          await upsertMyPushToken(
            platform: platform,
            token: newToken,
          );
          
          debugPrint('[NotificationService] Token refresh upserted successfully');
        } catch (e) {
          debugPrint('[NotificationService] Error upserting refreshed token: $e');
          // Don't rethrow - token refresh failure shouldn't crash the app
        }
      });
      
      debugPrint('[NotificationService] Token refresh listener set up successfully');
    } catch (e) {
      debugPrint('[NotificationService] Error setting up token refresh listener: $e');
      // Don't rethrow - listener setup failure shouldn't crash the app
    }
  }
}
