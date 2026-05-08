# Implementation Plan: Chat Push Notifications

## Overview

This plan implements a complete chat push notification system for a Flutter app with Supabase backend and Firebase Cloud Messaging. The implementation covers foreground local notifications, database webhook configuration, notification tap handling across all app states, Android notification channel setup, and token lifecycle management. All tasks build incrementally to ensure early validation of core functionality.

## Tasks

- [x] 1. Set up NotificationService foundation and Android notification channel
  - Create `lib/core/services/notification_service.dart` with class structure
  - Add `flutter_local_notifications` dependency to `pubspec.yaml`
  - Initialize `FlutterLocalNotificationsPlugin` in the service
  - Create Android notification channel with id "chat", name "Chat Messages", HIGH importance
  - Add iOS notification configuration with sound and badge settings
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 1.1 Write unit tests for NotificationService initialization
  - Test Android channel creation with correct configuration
  - Test iOS notification settings
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 2. Implement message truncation and notification display
  - [x] 2.1 Create message truncation utility function
    - Implement function that truncates messages to 140 characters with ellipsis
    - Handle edge cases: empty strings, exactly 140 chars, less than 140 chars
    - _Requirements: 1.4, 10.2, 10.3_
  
  - [x] 2.2 Write property test for message truncation
    - **Property 1: Message Truncation**
    - **Validates: Requirements 1.4, 10.2, 10.3**
    - Generate random messages (0-500 chars), verify truncation logic for all lengths
  
  - [x] 2.3 Implement showChatNotification method in NotificationService
    - Accept title, body, and bookingId parameters
    - Create notification with "New message" title
    - Truncate body using utility function
    - Include booking_id and type in notification payload
    - Display notification using flutter_local_notifications
    - _Requirements: 1.1, 1.2, 10.1, 10.2_
  
  - [x] 2.4 Write unit tests for showChatNotification
    - Test notification displays with correct title "New message"
    - Test body truncation is applied
    - Test payload includes booking_id and type fields
    - _Requirements: 1.1, 10.1, 10.2_
  
  - [x] 2.5 Write property test for notification title consistency
    - **Property 5: Notification Title Consistency**
    - **Validates: Requirements 10.1**
    - Generate random message data, verify title is always "New message"
  
  - [x] 2.6 Write property test for notification payload structure
    - **Property 4: Notification Payload Structure**
    - **Validates: Requirements 1.5, 10.5**
    - Generate random booking IDs, verify payload always contains booking_id and type fields

- [ ] 3. Implement FCM foreground listener with local notification display
  - [x] 3.1 Add setupFcmListeners method to NotificationService
    - Set up `FirebaseMessaging.onMessage` listener for foreground messages
    - Extract title, body, and booking_id from FCM message data
    - Call showChatNotification to display local notification
    - Add error handling and logging
    - _Requirements: 1.1, 1.2_
  
  - [x] 3.2 Write property test for foreground notification display
    - **Property 13: Foreground Notification Display**
    - **Validates: Requirements 1.1**
    - Generate random FCM messages, verify local notification is displayed for each
  
  - [x] 3.3 Write unit tests for FCM foreground listener
    - Test listener extracts correct data from FCM message
    - Test showChatNotification is called with correct parameters
    - Test error handling when message data is malformed
    - _Requirements: 1.1_

- [x] 4. Checkpoint - Verify foreground notifications work
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement notification tap handling and navigation
  - [x] 5.1 Create navigation handler function
    - Accept notification data map as parameter
    - Extract booking_id from data payload
    - Validate booking_id is not null or empty
    - Navigate to chat screen with booking_id parameter
    - Handle invalid booking_id with error message and home navigation
    - Add to `lib/main.dart` or dedicated router file
    - _Requirements: 1.3, 5.4, 5.6_
  
  - [x] 5.2 Wire notification tap handler to NotificationService
    - Add onNotificationTap callback parameter to NotificationService constructor
    - Implement _onNotificationTapped method to handle local notification taps
    - Extract booking_id from NotificationResponse payload
    - Call navigation handler with extracted data
    - _Requirements: 1.3, 5.3_
  
  - [x] 5.3 Set up background and terminated state handlers
    - Add `FirebaseMessaging.onMessageOpenedApp` listener for background taps
    - Add `FirebaseMessaging.getInitialMessage` check for terminated state
    - Both handlers extract booking_id and call navigation handler
    - Add to app initialization in main.dart
    - _Requirements: 5.1, 5.2, 2.7_
  
  - [x] 5.4 Write property test for booking ID extraction
    - **Property 3: Booking ID Extraction**
    - **Validates: Requirements 5.1, 5.2, 5.3**
    - Generate random notification payloads with booking IDs, verify extraction succeeds
  
  - [x] 5.5 Write property test for notification tap navigation
    - **Property 2: Notification Tap Navigation**
    - **Validates: Requirements 1.3, 2.7, 5.4**
    - Generate random valid booking IDs, verify navigation is triggered with correct parameter
  
  - [x] 5.6 Write unit tests for navigation handler
    - Test navigation with valid booking_id
    - Test error handling with null booking_id
    - Test error handling with empty booking_id
    - Test error handling with invalid UUID format
    - _Requirements: 5.4, 5.6_

- [x] 6. Implement token lifecycle management
  - [x] 6.1 Add token refresh listener
    - Create setupTokenRefreshListener method in NotificationService
    - Listen to `FirebaseMessaging.instance.onTokenRefresh`
    - Call upsertMyPushToken with new token and platform
    - Add error handling and logging
    - _Requirements: 8.4_
  
  - [x] 6.2 Add token cleanup on logout
    - Locate existing logout function in the codebase
    - Get current FCM token using `FirebaseMessaging.instance.getToken()`
    - Delete token from user_push_tokens table using Supabase client
    - Add before existing signOut call
    - _Requirements: 8.3_
  
  - [x] 6.3 Write property test for token refresh handling
    - **Property 12: Token Refresh Handling**
    - **Validates: Requirements 8.4**
    - Generate random token strings, verify upsertMyPushToken is called for each
  
  - [x] 6.4 Write property test for token cleanup on logout
    - **Property 11: Token Cleanup on Logout**
    - **Validates: Requirements 8.3**
    - Generate random tokens, verify deletion is attempted for each on logout
  
  - [x] 6.5 Write unit tests for token lifecycle
    - Test token refresh triggers upsert with correct platform
    - Test logout deletes current device token
    - Test logout handles null token gracefully
    - Test token refresh handles upsert failure gracefully
    - _Requirements: 8.3, 8.4_

- [x] 7. Checkpoint - Verify token lifecycle and navigation work
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Configure database webhook in Supabase
  - [x] 8.1 Create webhook configuration documentation
    - Document webhook settings: name, table, events, Edge Function
    - Add SQL comments explaining webhook purpose
    - Create file `supabase/webhook_setup.md` with step-by-step instructions
    - Include Supabase Dashboard navigation steps
    - _Requirements: 3.1, 3.2, 3.3, 3.5_
  
  - [x] 8.2 Add webhook verification instructions
    - Document how to verify webhook is triggered (check Edge Function logs)
    - Document expected webhook payload structure
    - Add troubleshooting steps for common webhook issues
    - _Requirements: 3.4, 9.5_

- [x] 9. Write property-based tests for Edge Function logic
  - [x] 9.1 Write property test for recipient identification
    - **Property 6: Recipient Identification**
    - **Validates: Requirements 2.2**
    - Generate random sender/booking combinations, verify correct recipient identification
  
  - [x] 9.2 Write property test for token retrieval completeness
    - **Property 7: Token Retrieval Completeness**
    - **Validates: Requirements 2.3**
    - Generate random user IDs with varying token counts, verify all tokens retrieved
  
  - [x] 9.3 Write property test for FCM delivery to all tokens
    - **Property 8: FCM Delivery to All Tokens**
    - **Validates: Requirements 2.4**
    - Generate random token sets, verify FCM send is attempted for each token
  
  - [x] 9.4 Write property test for input validation
    - **Property 9: Input Validation**
    - **Validates: Requirements 4.2**
    - Generate random payloads with missing/empty fields, verify 400 response
  
  - [x] 9.5 Write property test for error resilience in token delivery
    - **Property 10: Error Resilience in Token Delivery**
    - **Validates: Requirements 4.6**
    - Generate token sets with simulated failures, verify delivery continues to remaining tokens

- [x] 10. Write unit tests for Edge Function error scenarios
  - [x] 10.1 Write unit tests for Edge Function validation
    - Test returns 400 when booking_id is missing
    - Test returns 400 when sender_id is missing
    - Test returns 500 when booking lookup fails
    - Test returns 200 with pushed: 0 when no tokens exist
    - _Requirements: 4.2, 4.3, 4.4, 4.5_
  
  - [x] 10.2 Write unit tests for Edge Function recipient logic
    - Test identifies customer as recipient when sender is professional
    - Test identifies professional as recipient when sender is customer
    - Test handles booking with no professional assigned
    - _Requirements: 2.2_
  
  - [x] 10.3 Write unit tests for Edge Function delivery
    - Test sends FCM to all tokens for recipient
    - Test continues delivery when one token fails
    - Test logs errors for failed tokens
    - _Requirements: 2.4, 4.6, 4.7_

- [x] 11. Create integration testing documentation
  - [x] 11.1 Document manual test scenarios
    - Write step-by-step instructions for foreground notification test
    - Write step-by-step instructions for background notification test
    - Write step-by-step instructions for terminated state notification test
    - Write step-by-step instructions for token refresh test
    - Write step-by-step instructions for logout token cleanup test
    - Create file `supabase/integration_testing.md`
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.6_
  
  - [x] 11.2 Document Edge Function verification steps
    - Add instructions for checking Supabase Edge Function logs
    - Add instructions for verifying FCM token storage in database
    - Add instructions for verifying webhook execution
    - _Requirements: 9.5, 9.6_

- [x] 12. Create deployment and configuration documentation
  - [x] 12.1 Document FCM configuration requirements
    - List all required Edge Function secrets with descriptions
    - Document how to obtain Firebase service account JSON
    - Document how to set Edge Function secrets in Supabase Dashboard
    - Document how to add google-services.json and GoogleService-Info.plist
    - Create file `supabase/deployment_guide.md`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [x] 12.2 Document token cleanup recommendations
    - Add recommendation for periodic cleanup of stale tokens
    - Provide SQL query for identifying tokens older than 90 days
    - Document cleanup strategy and frequency
    - _Requirements: 8.2_

- [ ] 13. Final checkpoint - Complete integration verification
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property-based tests use 100 iterations each to verify universal correctness
- Edge Function is already complete and requires no code changes
- Checkpoints ensure incremental validation at key milestones
- All code examples use Dart/Flutter as specified in the design document
