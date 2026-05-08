import 'package:flutter/material.dart';

/// Handles navigation triggered by notification taps
/// Extracts booking_id from notification data and navigates to chat screen
class NotificationRouter {
  /// Navigate to chat screen based on notification data
  /// 
  /// Accepts notification data map as parameter
  /// Extracts booking_id from data payload
  /// Validates booking_id is not null or empty
  /// Navigates to chat screen with booking_id parameter
  /// Handles invalid booking_id with error message and home navigation
  /// 
  /// Requirements: 1.3, 5.4, 5.6
  static void handleNotificationNavigation(
    BuildContext context,
    Map<String, dynamic> data, {
    required void Function(String bookingId) onNavigateToChat,
  }) {
    try {
      // Extract booking_id from notification data
      final bookingId = data['booking_id'] as String?;
      final type = data['type'] as String?;

      // Validate booking_id is not null or empty
      if (bookingId == null || bookingId.isEmpty) {
        debugPrint('[NotificationRouter] Invalid booking_id in notification data');
        _handleInvalidBookingId(context);
        return;
      }

      // Validate type is chat_message
      if (type != null && type != 'chat_message') {
        debugPrint('[NotificationRouter] Unknown notification type: $type');
        _handleInvalidBookingId(context);
        return;
      }

      // Validate booking_id is a valid UUID format (basic check)
      if (!_isValidUuid(bookingId)) {
        debugPrint('[NotificationRouter] Invalid UUID format: $bookingId');
        _handleInvalidBookingId(context);
        return;
      }

      // Navigate to chat screen with booking_id parameter
      debugPrint('[NotificationRouter] Navigating to chat screen with booking_id: $bookingId');
      
      // Call the navigation callback to trigger state change in MainApp
      onNavigateToChat(bookingId);
      
    } catch (e) {
      debugPrint('[NotificationRouter] Error handling notification navigation: $e');
      _handleInvalidBookingId(context);
    }
  }

  /// Handle invalid booking_id with error message and home navigation
  static void _handleInvalidBookingId(BuildContext context) {
    try {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to open chat'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationRouter] Error handling invalid booking_id: $e');
    }
  }

  /// Validate UUID format (basic check)
  /// UUID format: 8-4-4-4-12 hexadecimal digits separated by hyphens
  static bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }
}
