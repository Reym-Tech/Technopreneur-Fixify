# Requirements Document

## Introduction

This document specifies the requirements for completing the chat push notification feature in a Flutter application with Supabase backend and Firebase Cloud Messaging (FCM) integration. The feature enables real-time push notifications when chat messages are sent, with support for foreground, background, and terminated app states.

The system already has partial implementation including FCM token collection, permission handling, database tables, and a Supabase Edge Function. This specification focuses on completing the missing functionality to deliver a fully operational push notification system.

## Glossary

- **FCM**: Firebase Cloud Messaging - Google's cross-platform messaging solution
- **Push_Token**: A unique device identifier used by FCM to deliver notifications to specific devices
- **Chat_Message**: A message record in the `chat_messages` table containing sender, recipient, and message content
- **Edge_Function**: A Supabase serverless function that executes in response to database events
- **Foreground_State**: Application state where the app is open and actively being used by the user
- **Background_State**: Application state where the app is running but not visible to the user
- **Terminated_State**: Application state where the app process has been completely stopped
- **Local_Notification**: A notification displayed by the device OS using flutter_local_notifications or native APIs
- **Database_Webhook**: A Supabase trigger that invokes an Edge Function when specific database events occur
- **Notification_Service**: The Flutter service responsible for handling FCM messages and displaying notifications
- **Service_Role_Key**: A Supabase administrative key with elevated privileges for server-side operations

## Requirements

### Requirement 1: Foreground Notification Display

**User Story:** As a user with the app open, I want to see a heads-up notification when I receive a chat message, so that I am immediately aware of new messages without switching screens.

#### Acceptance Criteria

1. WHEN a chat message is received AND THE App SHALL be in Foreground_State, THE Notification_Service SHALL display a Local_Notification with the sender name and message preview
2. THE Local_Notification SHALL appear as a heads-up notification at the top of the screen
3. WHEN the user taps the Local_Notification, THE App SHALL navigate to the chat screen for the relevant booking
4. THE Local_Notification SHALL include the message body truncated to 140 characters if longer
5. THE Local_Notification SHALL include the booking_id in the notification data payload

### Requirement 2: Background and Terminated State Notification Delivery

**User Story:** As a user with the app in the background or closed, I want to receive push notifications for new chat messages, so that I stay informed even when not actively using the app.

#### Acceptance Criteria

1. WHEN a chat message is inserted into the chat_messages table, THE Edge_Function SHALL be triggered via Database_Webhook
2. THE Edge_Function SHALL identify the recipient user_id by comparing the sender_id with the booking participants
3. THE Edge_Function SHALL retrieve all Push_Tokens associated with the recipient user_id from the user_push_tokens table
4. THE Edge_Function SHALL send an FCM push notification to each retrieved Push_Token
5. THE FCM notification payload SHALL include the message title, body preview (truncated to 140 characters), and booking_id in the data field
6. WHEN the app is in Background_State or Terminated_State AND a notification is received, THE device operating system SHALL display the notification
7. WHEN the user taps the notification, THE App SHALL open and navigate to the chat screen for the booking_id specified in the notification data

### Requirement 3: Database Webhook Configuration

**User Story:** As a system administrator, I want the Edge Function to be automatically invoked when chat messages are created, so that push notifications are sent without manual intervention.

#### Acceptance Criteria

1. THE Database_Webhook SHALL be configured to trigger on INSERT events for the public.chat_messages table
2. THE Database_Webhook SHALL invoke the chat_push_new_message Edge_Function
3. THE Database_Webhook SHALL pass the complete inserted record to the Edge_Function
4. IF the Edge_Function invocation fails, THE Database_Webhook SHALL retry according to Supabase default retry policy
5. THE Database_Webhook configuration SHALL be documented in the deployment instructions

### Requirement 4: Edge Function Security and Error Handling

**User Story:** As a security-conscious developer, I want the Edge Function to validate requests and handle errors gracefully, so that the system remains secure and resilient.

#### Acceptance Criteria

1. THE Edge_Function SHALL use the Service_Role_Key for database queries to bypass Row Level Security policies
2. THE Edge_Function SHALL validate that booking_id and sender_id are present in the webhook payload
3. IF booking_id or sender_id are missing, THE Edge_Function SHALL return a 400 status code with an error message
4. IF the booking lookup fails, THE Edge_Function SHALL return a 500 status code with an error message
5. IF no Push_Tokens exist for the recipient, THE Edge_Function SHALL return a 200 status code with pushed count of 0
6. IF FCM token delivery fails for a specific token, THE Edge_Function SHALL continue attempting delivery to remaining tokens
7. THE Edge_Function SHALL log all errors with sufficient detail for debugging

### Requirement 5: Notification Tap Handling and Navigation

**User Story:** As a user, I want to be taken directly to the relevant chat when I tap a notification, so that I can quickly respond to messages.

#### Acceptance Criteria

1. WHEN a notification is tapped AND the app is in Terminated_State, THE App SHALL initialize and extract the booking_id from the notification data
2. WHEN a notification is tapped AND the app is in Background_State, THE App SHALL resume and extract the booking_id from the notification data
3. WHEN a notification is tapped AND the app is in Foreground_State, THE Notification_Service SHALL extract the booking_id from the notification data
4. THE App SHALL navigate to the chat screen with the extracted booking_id
5. THE App SHALL load the chat thread associated with the booking_id
6. IF the booking_id is invalid or the chat thread does not exist, THE App SHALL display an error message and navigate to the home screen

### Requirement 6: FCM Configuration and Secrets Management

**User Story:** As a developer, I want clear documentation of required FCM configuration and secrets, so that I can deploy the feature correctly.

#### Acceptance Criteria

1. THE deployment documentation SHALL list all required Supabase Edge Function secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FIREBASE_PROJECT_ID, FIREBASE_SERVICE_ACCOUNT_JSON
2. THE deployment documentation SHALL specify that FIREBASE_SERVICE_ACCOUNT_JSON must be a stringified JSON object containing client_email and private_key
3. THE deployment documentation SHALL include instructions for obtaining the Firebase service account JSON from the Firebase Console
4. THE deployment documentation SHALL include instructions for setting Edge Function secrets in the Supabase dashboard
5. THE deployment documentation SHALL include instructions for adding google-services.json (Android) and GoogleService-Info.plist (iOS) to the Flutter project

### Requirement 7: Notification Channel Configuration (Android)

**User Story:** As an Android user, I want chat notifications to use an appropriate notification channel, so that I can control notification behavior through system settings.

#### Acceptance Criteria

1. THE Notification_Service SHALL create a notification channel with id "chat" on Android devices
2. THE notification channel SHALL have a user-visible name "Chat Messages"
3. THE notification channel SHALL have importance level set to HIGH for heads-up notifications
4. THE notification channel SHALL enable sound by default
5. THE notification channel SHALL be created during app initialization before any notifications are displayed

### Requirement 8: Token Refresh and Cleanup

**User Story:** As a system maintainer, I want stale FCM tokens to be handled gracefully, so that the system does not waste resources on invalid tokens.

#### Acceptance Criteria

1. WHEN FCM returns an error indicating an invalid or expired token, THE Edge_Function SHALL log the error with the token identifier
2. THE deployment documentation SHALL recommend periodic cleanup of stale tokens from the user_push_tokens table
3. WHEN a user logs out, THE App SHALL delete the current device's Push_Token from the user_push_tokens table
4. WHEN FCM generates a new token for a device, THE App SHALL call upsertMyPushToken to update the token in the database

### Requirement 9: Testing and Verification

**User Story:** As a quality assurance engineer, I want to verify that notifications work correctly in all app states, so that I can ensure a reliable user experience.

#### Acceptance Criteria

1. THE testing documentation SHALL include steps to verify foreground notification display
2. THE testing documentation SHALL include steps to verify background notification delivery
3. THE testing documentation SHALL include steps to verify terminated state notification delivery
4. THE testing documentation SHALL include steps to verify notification tap navigation
5. THE testing documentation SHALL include steps to verify Edge Function execution via Supabase logs
6. THE testing documentation SHALL include steps to verify FCM token storage in the user_push_tokens table

### Requirement 10: Notification Content and Formatting

**User Story:** As a user, I want notifications to display meaningful information about the message, so that I can decide whether to open the app immediately.

#### Acceptance Criteria

1. THE notification title SHALL be "New message" for all chat notifications
2. THE notification body SHALL contain the message text truncated to 140 characters
3. IF the message exceeds 140 characters, THE notification body SHALL append an ellipsis (…) to indicate truncation
4. THE notification SHALL NOT include sensitive information beyond the message preview
5. THE notification data payload SHALL include booking_id and type fields for routing purposes
