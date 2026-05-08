# Integration Testing Guide: Chat Push Notifications

## Overview

This document provides step-by-step instructions for manually testing the chat push notification feature across all app states and verifying backend functionality. These tests ensure that notifications are delivered correctly, navigation works as expected, and the Edge Function executes properly.

## Prerequisites

Before testing, ensure:
- The app is installed on a physical device (push notifications don't work reliably on emulators)
- Firebase Cloud Messaging is configured with valid credentials
- The database webhook is configured and active (see `webhook_setup.md`)
- You have access to the Supabase Dashboard for log verification
- You have two test accounts: one sender and one recipient
- Both devices have granted notification permissions to the app

## Test Scenarios

### Test 1: Foreground Notification Display

**Objective:** Verify that a local notification appears when a message is received while the app is open.

**Requirements Validated:** 9.1

**Steps:**

1. **Setup:**
   - Log in to the recipient account on Device A
   - Open the app and navigate to any screen EXCEPT the chat screen
   - Keep the app in the foreground (visible on screen)

2. **Send Message:**
   - On Device B (or web), log in as a different user
   - Navigate to a booking that both users share
   - Send a chat message to the recipient

3. **Verify Notification Display:**
   - On Device A, observe that a heads-up notification appears at the top of the screen
   - Verify the notification shows:
     - Title: "New message"
     - Body: The message text (truncated to 140 characters if longer)
   - The notification should appear within 1-2 seconds of sending

4. **Verify Notification Tap:**
   - Tap the notification
   - Verify the app navigates to the chat screen for the correct booking
   - Verify the new message is visible in the chat thread

**Expected Results:**
- ✅ Heads-up notification appears while app is in foreground
- ✅ Notification displays correct title and message preview
- ✅ Tapping notification navigates to the correct chat screen
- ✅ Message is visible in the chat thread

**Troubleshooting:**
- If no notification appears, check that the NotificationService is initialized in main.dart
- Verify the Android notification channel is created with HIGH importance
- Check device notification settings for the app
- Review app logs for any errors in the FCM listener

---

### Test 2: Background Notification Delivery

**Objective:** Verify that a system notification is delivered when a message is received while the app is in the background.

**Requirements Validated:** 9.2

**Steps:**

1. **Setup:**
   - Log in to the recipient account on Device A
   - Open the app to ensure it's running
   - Press the home button to send the app to the background
   - Verify the app is still running (check recent apps list)

2. **Send Message:**
   - On Device B (or web), log in as a different user
   - Navigate to a booking that both users share
   - Send a chat message to the recipient

3. **Verify Notification Delivery:**
   - On Device A, observe that a system notification appears in the notification tray
   - Pull down the notification shade to view the notification
   - Verify the notification shows:
     - Title: "New message"
     - Body: The message text (truncated to 140 characters if longer)
   - The notification should appear within 2-3 seconds of sending

4. **Verify Notification Tap:**
   - Tap the notification in the notification tray
   - Verify the app resumes and navigates to the chat screen for the correct booking
   - Verify the new message is visible in the chat thread

**Expected Results:**
- ✅ System notification appears in notification tray
- ✅ Notification displays correct title and message preview
- ✅ Tapping notification resumes the app and navigates to the correct chat screen
- ✅ Message is visible in the chat thread

**Troubleshooting:**
- If no notification appears, verify the device has an active internet connection
- Check that FCM tokens are stored in the user_push_tokens table (see Test 6)
- Verify the Edge Function executed successfully (see Test 7)
- Check device battery optimization settings aren't blocking notifications
- Review FCM logs in Firebase Console for delivery status

---

### Test 3: Terminated State Notification Delivery

**Objective:** Verify that a system notification is delivered when a message is received while the app is completely closed.

**Requirements Validated:** 9.3

**Steps:**

1. **Setup:**
   - Log in to the recipient account on Device A
   - Completely close the app:
     - **Android:** Open recent apps, swipe the app away
     - **iOS:** Double-tap home button, swipe the app up
   - Verify the app is not running in the background

2. **Send Message:**
   - On Device B (or web), log in as a different user
   - Navigate to a booking that both users share
   - Send a chat message to the recipient

3. **Verify Notification Delivery:**
   - On Device A, observe that a system notification appears in the notification tray
   - Pull down the notification shade to view the notification
   - Verify the notification shows:
     - Title: "New message"
     - Body: The message text (truncated to 140 characters if longer)
   - The notification should appear within 2-3 seconds of sending

4. **Verify Notification Tap:**
   - Tap the notification in the notification tray
   - Verify the app launches from scratch
   - Verify the app navigates to the chat screen for the correct booking
   - Verify the new message is visible in the chat thread

**Expected Results:**
- ✅ System notification appears even when app is completely closed
- ✅ Notification displays correct title and message preview
- ✅ Tapping notification launches the app and navigates to the correct chat screen
- ✅ Message is visible in the chat thread

**Troubleshooting:**
- If no notification appears, verify FCM tokens are stored correctly (see Test 6)
- Check that the device hasn't revoked notification permissions
- Verify the Edge Function executed successfully (see Test 7)
- On Android, check that the app isn't restricted in battery optimization settings
- Review FCM logs in Firebase Console for delivery status

---

### Test 4: Token Refresh Handling

**Objective:** Verify that FCM token updates are properly stored in the database.

**Requirements Validated:** 9.4

**Steps:**

1. **Setup:**
   - Log in to the recipient account on Device A
   - Note the current FCM token from the database:
     ```sql
     SELECT token, created_at 
     FROM user_push_tokens 
     WHERE user_id = '<recipient_user_id>';
     ```

2. **Trigger Token Refresh:**
   - Choose one of these methods to force a token refresh:
     - **Method A (Android):** Clear app data in device settings
     - **Method B (iOS):** Uninstall and reinstall the app
     - **Method C (Both):** Wait for automatic token rotation (may take days)

3. **Verify Token Update:**
   - Log in again to the recipient account
   - Wait 5-10 seconds for token initialization
   - Query the database again:
     ```sql
     SELECT token, created_at 
     FROM user_push_tokens 
     WHERE user_id = '<recipient_user_id>'
     ORDER BY created_at DESC;
     ```
   - Verify a new token record exists with a recent created_at timestamp

4. **Verify Notifications Still Work:**
   - Send a test message to the recipient
   - Verify the notification is received (use any app state)

**Expected Results:**
- ✅ New FCM token is stored in the database after refresh
- ✅ Old token may still exist (will be cleaned up later)
- ✅ Notifications are delivered to the new token
- ✅ No errors in app logs during token refresh

**Troubleshooting:**
- If token isn't updated, check that setupTokenRefreshListener is called in NotificationService
- Verify the upsertMyPushToken function is working correctly
- Check app logs for any errors during token refresh
- Ensure the device has an active internet connection

---

### Test 5: Logout Token Cleanup

**Objective:** Verify that FCM tokens are removed from the database when a user logs out.

**Requirements Validated:** 9.6

**Steps:**

1. **Setup:**
   - Log in to a test account on Device A
   - Ensure the app has registered an FCM token
   - Query the database to confirm the token exists:
     ```sql
     SELECT token, user_id, platform 
     FROM user_push_tokens 
     WHERE user_id = '<test_user_id>';
     ```
   - Note the token value for verification

2. **Perform Logout:**
   - In the app, navigate to the logout function
   - Tap the logout button
   - Wait for the logout process to complete
   - Verify you're returned to the login screen

3. **Verify Token Deletion:**
   - Query the database again:
     ```sql
     SELECT token, user_id, platform 
     FROM user_push_tokens 
     WHERE token = '<noted_token_value>';
     ```
   - Verify the token record has been deleted (query returns no rows)

4. **Verify No Notifications After Logout:**
   - From another device, send a message to the logged-out user
   - Verify NO notification is received on Device A
   - This confirms the token was properly removed

**Expected Results:**
- ✅ Token is deleted from user_push_tokens table after logout
- ✅ No notifications are received after logout
- ✅ Logout completes successfully without errors
- ✅ User is returned to login screen

**Troubleshooting:**
- If token isn't deleted, verify the logout function includes token cleanup code
- Check that FirebaseMessaging.instance.getToken() returns a valid token before deletion
- Review app logs for any errors during logout
- Verify the Supabase client has proper authentication for the delete operation

---

## Backend Verification

### Test 6: Verify FCM Token Storage in Database

**Objective:** Confirm that FCM tokens are correctly stored in the user_push_tokens table.

**Requirements Validated:** 9.6

**Steps:**

1. **Access Supabase Dashboard:**
   - Log in to your Supabase project dashboard
   - Navigate to: **Table Editor** → **user_push_tokens**

2. **Verify Token Records:**
   - Locate records for your test users
   - Verify each record contains:
     - `id`: Valid UUID
     - `user_id`: Valid UUID matching a user in the users table
     - `platform`: One of 'android', 'ios', or 'web'
     - `token`: Long string (FCM token format)
     - `created_at`: Recent timestamp

3. **Verify Token Format:**
   - FCM tokens should be long strings (150+ characters)
   - Android tokens typically start with various prefixes
   - iOS tokens are typically 64 hexadecimal characters
   - Verify no duplicate tokens exist for the same user/device combination

4. **Test Query:**
   - Run this query to check token counts per user:
     ```sql
     SELECT user_id, platform, COUNT(*) as token_count
     FROM user_push_tokens
     GROUP BY user_id, platform
     ORDER BY token_count DESC;
     ```
   - Verify counts are reasonable (typically 1-3 tokens per user per platform)

**Expected Results:**
- ✅ Tokens are stored with correct user_id associations
- ✅ Platform field accurately reflects device type
- ✅ Tokens are in valid FCM format
- ✅ No excessive duplicate tokens for the same user

**Troubleshooting:**
- If no tokens exist, verify FCM initialization in main.dart
- Check that upsertMyPushToken is called after successful login
- Verify notification permissions are granted on the device
- Review app logs for FCM token generation errors

---

### Test 7: Verify Edge Function Execution

**Objective:** Confirm that the Edge Function is triggered and executes successfully when messages are sent.

**Requirements Validated:** 9.5

**Steps:**

1. **Access Edge Function Logs:**
   - Log in to your Supabase project dashboard
   - Navigate to: **Edge Functions** → **chat_push_new_message** → **Logs**
   - Set the time filter to "Last 15 minutes"

2. **Send Test Message:**
   - Send a chat message between two test users
   - Wait 5-10 seconds for the Edge Function to execute

3. **Verify Function Execution:**
   - Refresh the logs page
   - Look for a new log entry with timestamp matching your message send time
   - Verify the log shows:
     - Status: 200 (success)
     - Execution time: < 2 seconds
     - Response body containing: `{ "ok": true, "pushed": <number> }`

4. **Verify Detailed Logs:**
   - Click on the log entry to expand details
   - Verify the request payload contains:
     - `type`: "INSERT"
     - `table`: "chat_messages"
     - `record`: Object with booking_id, sender_id, body, etc.
   - Check for any error messages in the logs

5. **Test Error Scenarios:**
   - **Missing Recipient:** Send a message for a booking with no professional assigned
     - Expected: Status 200, response: `{ "ok": true, "skipped": "no recipient" }`
   - **No Tokens:** Send a message to a user with no FCM tokens
     - Expected: Status 200, response: `{ "ok": true, "pushed": 0 }`

**Expected Results:**
- ✅ Edge Function executes within 2 seconds of message insert
- ✅ Function returns 200 status for successful execution
- ✅ Response indicates correct number of tokens pushed to
- ✅ No error messages in logs for valid scenarios
- ✅ Appropriate responses for edge cases (no recipient, no tokens)

**Troubleshooting:**
- If no logs appear, verify the database webhook is configured (see webhook_setup.md)
- Check that the webhook is enabled in the Supabase Dashboard
- Verify the Edge Function is deployed and active
- Review the webhook configuration for correct table and event type
- Check Edge Function secrets are properly configured (SUPABASE_URL, FIREBASE_PROJECT_ID, etc.)

---

### Test 8: Verify Webhook Execution

**Objective:** Confirm that the database webhook triggers the Edge Function on message insert.

**Requirements Validated:** 9.6

**Steps:**

1. **Access Webhook Configuration:**
   - Log in to your Supabase project dashboard
   - Navigate to: **Database** → **Webhooks**
   - Locate the webhook named "chat_message_push_notification"

2. **Verify Webhook Settings:**
   - **Table:** public.chat_messages
   - **Events:** INSERT (checked)
   - **Type:** Edge Function
   - **Edge Function:** chat_push_new_message
   - **Status:** Enabled (toggle should be ON)

3. **Send Test Message:**
   - Send a chat message between two test users
   - Note the exact time of the message send

4. **Check Webhook Execution:**
   - In the webhook configuration page, look for execution history or logs
   - Verify a webhook execution occurred at the time of your message send
   - Check the execution status (should be success/200)

5. **Verify Webhook Payload:**
   - If available, inspect the webhook payload sent to the Edge Function
   - Verify it contains the complete message record:
     - id, thread_id, booking_id, sender_id, body, created_at

6. **Test Webhook Retry (Optional):**
   - Temporarily disable the Edge Function
   - Send a test message
   - Verify the webhook shows a failed execution
   - Re-enable the Edge Function
   - Check if the webhook retries (Supabase default: 3 retries with exponential backoff)

**Expected Results:**
- ✅ Webhook is properly configured and enabled
- ✅ Webhook executes immediately after message insert
- ✅ Webhook payload contains complete message record
- ✅ Webhook execution status shows success
- ✅ Failed executions trigger automatic retries

**Troubleshooting:**
- If webhook doesn't execute, verify it's enabled in the dashboard
- Check that the table name and schema are correct (public.chat_messages)
- Verify the Edge Function name matches exactly
- Ensure the INSERT event is selected
- Check Supabase project status for any service disruptions
- Review database logs for any trigger errors

---

## Test Data Scenarios

### Message Length Variations

Test notifications with different message lengths to verify truncation:

1. **Short Message (< 140 chars):**
   - Message: "Hello, how are you?"
   - Expected: Full message displayed in notification

2. **Exact 140 Characters:**
   - Message: "This message is exactly one hundred and forty characters long to test the boundary condition for message truncation in notifications."
   - Expected: Full message displayed without ellipsis

3. **Long Message (> 140 chars):**
   - Message: "This is a very long message that exceeds the one hundred and forty character limit and should be truncated with an ellipsis to ensure the notification body doesn't become too long for display."
   - Expected: First 140 characters + "…" displayed

4. **Very Long Message (500+ chars):**
   - Message: [Generate a 500+ character message]
   - Expected: First 140 characters + "…" displayed

### Special Characters

Test notifications with special characters:

1. **Emoji:** "Hello! 👋 How are you doing today? 😊"
2. **Newlines:** "Line 1\nLine 2\nLine 3"
3. **Special Symbols:** "Price: $100.00 (20% off!)"
4. **Unicode:** "Héllo Wörld! 你好世界"

### Edge Cases

1. **Empty Message:** "" (should not occur in production, but test error handling)
2. **Whitespace Only:** "     " (should display as-is or be handled gracefully)
3. **HTML/Markdown:** "<b>Bold</b> and **markdown**" (should display as plain text)

---

## Performance Benchmarks

During testing, measure and verify these performance targets:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Foreground notification display | < 500ms | Time from message send to notification appearance |
| Edge Function execution | < 2 seconds | Check execution time in Edge Function logs |
| Token upsert | < 1 second | Check app logs for upsert duration |
| Background notification delivery | < 3 seconds | Time from message send to notification appearance |
| Terminated notification delivery | < 5 seconds | Time from message send to notification appearance |

**Note:** Actual times may vary based on network conditions and device performance.

---

## Common Issues and Solutions

### Issue: No Notifications Received

**Possible Causes:**
1. Notification permissions not granted
2. FCM token not stored in database
3. Edge Function not executing
4. Database webhook not configured
5. Device in Do Not Disturb mode

**Solutions:**
1. Check device notification settings for the app
2. Verify token exists in user_push_tokens table (Test 6)
3. Check Edge Function logs (Test 7)
4. Verify webhook configuration (Test 8)
5. Disable Do Not Disturb mode temporarily

### Issue: Notification Appears But Tap Doesn't Navigate

**Possible Causes:**
1. Navigation handler not properly wired
2. booking_id missing from notification payload
3. Invalid booking_id format
4. Navigation route not configured

**Solutions:**
1. Verify onNotificationTap callback is set in NotificationService
2. Check notification payload includes booking_id (review Edge Function logs)
3. Validate booking_id is a valid UUID
4. Ensure chat route is properly configured in app router

### Issue: Foreground Notifications Don't Appear

**Possible Causes:**
1. Android notification channel not created
2. Channel importance too low
3. flutter_local_notifications not initialized
4. FCM listener not set up

**Solutions:**
1. Verify channel creation in NotificationService.initialize()
2. Ensure channel importance is set to HIGH
3. Check that FlutterLocalNotificationsPlugin is initialized before use
4. Verify FirebaseMessaging.onMessage listener is active

### Issue: Tokens Not Cleaned Up on Logout

**Possible Causes:**
1. Token cleanup code not in logout function
2. Token deletion query failing
3. Network error during deletion

**Solutions:**
1. Add token deletion code before signOut() call
2. Check Supabase client authentication
3. Add error handling and logging to token deletion

---

## Test Completion Checklist

Use this checklist to track your testing progress:

- [ ] Test 1: Foreground notification display ✅
- [ ] Test 2: Background notification delivery ✅
- [ ] Test 3: Terminated state notification delivery ✅
- [ ] Test 4: Token refresh handling ✅
- [ ] Test 5: Logout token cleanup ✅
- [ ] Test 6: FCM token storage verification ✅
- [ ] Test 7: Edge Function execution verification ✅
- [ ] Test 8: Webhook execution verification ✅
- [ ] Message length variations tested ✅
- [ ] Special characters tested ✅
- [ ] Edge cases tested ✅
- [ ] Performance benchmarks measured ✅
- [ ] All issues documented and resolved ✅

---

## Next Steps

After completing all integration tests:

1. **Document Results:** Record test outcomes, performance metrics, and any issues encountered
2. **Fix Issues:** Address any failures or performance problems identified during testing
3. **Retest:** Re-run failed tests after fixes are applied
4. **Production Readiness:** Once all tests pass, the feature is ready for production deployment
5. **Monitoring:** Set up monitoring for Edge Function execution and notification delivery rates in production

For deployment instructions, see `deployment_guide.md`.
