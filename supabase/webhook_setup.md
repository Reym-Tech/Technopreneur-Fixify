# Database Webhook Setup Guide

## Overview

This guide provides step-by-step instructions for configuring the Supabase database webhook that triggers push notifications when new chat messages are created. The webhook automatically invokes the `chat_push_new_message` Edge Function whenever a record is inserted into the `chat_messages` table.

## Prerequisites

- Supabase project with the `chat_messages` table created
- `chat_push_new_message` Edge Function deployed to Supabase
- Admin access to the Supabase Dashboard

## Webhook Configuration

### Step 1: Navigate to Database Webhooks

1. Open your Supabase project dashboard at `https://app.supabase.com`
2. Select your project from the project list
3. In the left sidebar, click **Database**
4. Click the **Webhooks** tab in the database section

### Step 2: Create New Webhook

1. Click the **Create a new hook** button (or **Enable Webhooks** if this is your first webhook)
2. You will see the webhook creation form

### Step 3: Configure Webhook Settings

Fill in the webhook configuration form with the following values:

| Field | Value | Description |
|-------|-------|-------------|
| **Name** | `chat_message_push_notification` | Human-readable identifier for the webhook |
| **Table** | `public.chat_messages` | The table to monitor for changes |
| **Events** | `INSERT` | Trigger only on new message inserts (uncheck UPDATE and DELETE) |
| **Type** | `Supabase Edge Function` | Use Edge Function instead of HTTP webhook |
| **Edge Function** | `chat_push_new_message` | Select the deployed Edge Function from dropdown |
| **HTTP Headers** | _(leave empty)_ | No custom headers required |

### Step 4: Review Configuration

Before saving, verify your configuration matches:

```
Name: chat_message_push_notification
Table: public.chat_messages
Events: ☑ INSERT  ☐ UPDATE  ☐ DELETE
Type: Supabase Edge Function
Edge Function: chat_push_new_message
```

### Step 5: Save Webhook

1. Click **Create webhook** or **Confirm** button
2. The webhook will appear in your webhooks list with status **Active**

## Webhook Behavior

### What Happens When a Message is Inserted

1. **Trigger**: A new record is inserted into `public.chat_messages`
2. **Webhook Fires**: Supabase detects the INSERT event
3. **Edge Function Invoked**: The `chat_push_new_message` function is called with the webhook payload
4. **Payload Structure**: The function receives:
   ```json
   {
     "type": "INSERT",
     "table": "chat_messages",
     "schema": "public",
     "record": {
       "id": "uuid",
       "thread_id": "uuid",
       "booking_id": "uuid",
       "sender_id": "uuid",
       "body": "message text",
       "created_at": "timestamp"
     },
     "old_record": null
   }
   ```
5. **Processing**: The Edge Function:
   - Identifies the recipient (customer or professional)
   - Retrieves all FCM tokens for the recipient
   - Sends push notifications to all recipient devices
   - Logs the result

### Retry Policy

Supabase webhooks have built-in retry logic:
- **Retries**: 3 attempts with exponential backoff
- **Timeout**: 60 seconds per attempt
- **Failure Handling**: After 3 failed attempts, the webhook gives up (message is lost)

## Alternative: SQL Trigger Approach

If you prefer to configure the webhook via SQL instead of the Dashboard, you can use Supabase's `pg_net` extension:

```sql
-- Note: This is an alternative approach using SQL triggers
-- The Dashboard method (above) is recommended for easier management

-- Create a function to invoke the Edge Function
CREATE OR REPLACE FUNCTION notify_chat_push()
RETURNS TRIGGER AS $$
BEGIN
  -- Invoke Edge Function via pg_net (requires pg_net extension)
  PERFORM net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/chat_push_new_message',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'chat_messages',
      'schema', 'public',
      'record', row_to_json(NEW),
      'old_record', NULL
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on chat_messages table
CREATE TRIGGER chat_message_push_trigger
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_chat_push();
```

**Important**: Replace `YOUR_PROJECT_REF` with your actual Supabase project reference. The Dashboard method is preferred as it handles authentication and retry logic automatically.

## Verification

After creating the webhook, proceed to the verification steps in the next section to ensure it's working correctly.

## Troubleshooting

See the **Webhook Verification Instructions** section below for common issues and solutions.


---

# Webhook Verification Instructions

## How to Verify the Webhook is Working

After configuring the webhook, follow these steps to verify it's triggering correctly.

### Method 1: Check Edge Function Logs

1. **Navigate to Edge Functions Logs**:
   - Open Supabase Dashboard
   - Click **Edge Functions** in the left sidebar
   - Click on the `chat_push_new_message` function
   - Click the **Logs** tab

2. **Send a Test Message**:
   - Open your Flutter app
   - Navigate to a chat screen
   - Send a test message

3. **Verify Log Entry**:
   - Refresh the Edge Function logs page
   - Look for a new log entry with timestamp matching your test message
   - Successful execution shows:
     ```
     [INFO] Recipient identified: <user_id>
     [INFO] Found <N> push tokens for recipient
     [INFO] Successfully pushed to <N> tokens
     ```

4. **Check for Errors**:
   - If you see `[ERROR]` entries, check the error message
   - Common errors are listed in the Troubleshooting section below

### Method 2: Check Webhook Status in Dashboard

1. **Navigate to Webhooks**:
   - Open Supabase Dashboard
   - Click **Database** → **Webhooks**

2. **View Webhook Details**:
   - Find `chat_message_push_notification` in the list
   - Check the **Status** column shows **Active**
   - Click on the webhook name to see execution history

3. **Review Recent Executions**:
   - The webhook detail page shows recent invocations
   - Green checkmarks indicate successful executions
   - Red X marks indicate failures

### Method 3: Query the Notifications Table

The Edge Function inserts a record into the `notifications` table for each message:

```sql
-- Check recent notifications
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  created_at
FROM notifications
WHERE type = 'chat_message'
ORDER BY created_at DESC
LIMIT 10;
```

If notifications appear after sending messages, the webhook is triggering successfully.

### Method 4: Verify FCM Token Storage

Ensure recipient devices have FCM tokens stored:

```sql
-- Check tokens for a specific user
SELECT 
  user_id,
  platform,
  token,
  created_at
FROM user_push_tokens
WHERE user_id = '<recipient_user_id>';
```

If no tokens exist, the Edge Function will return `pushed: 0` (this is expected behavior, not an error).

## Expected Webhook Payload Structure

When the webhook triggers, it sends this payload to the Edge Function:

```json
{
  "type": "INSERT",
  "table": "chat_messages",
  "schema": "public",
  "record": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "thread_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
    "booking_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "sender_id": "886313e1-3b8a-5372-9b90-0c9aee199e5d",
    "body": "Hello, when will you arrive?",
    "created_at": "2026-05-08T10:30:00.000Z"
  },
  "old_record": null
}
```

### Payload Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Event type, always "INSERT" for new messages |
| `table` | string | Table name, always "chat_messages" |
| `schema` | string | Database schema, always "public" |
| `record` | object | The complete inserted chat message record |
| `record.id` | uuid | Unique message identifier |
| `record.thread_id` | uuid | Chat thread this message belongs to |
| `record.booking_id` | uuid | Booking associated with the chat |
| `record.sender_id` | uuid | User ID of the message sender |
| `record.body` | string | Message text content |
| `record.created_at` | timestamp | Message creation timestamp |
| `old_record` | null | Always null for INSERT events |

## Troubleshooting Common Issues

### Issue 1: Webhook Not Triggering

**Symptoms**: No logs appear in Edge Function after sending messages

**Possible Causes**:
- Webhook not created or disabled
- Wrong table selected in webhook configuration
- INSERT event not checked in webhook settings

**Solutions**:
1. Verify webhook exists: Database → Webhooks → Check for `chat_message_push_notification`
2. Check webhook status is **Active** (not Paused or Disabled)
3. Verify Events setting includes **INSERT** checkbox
4. Verify Table is set to `public.chat_messages`
5. Try deleting and recreating the webhook

### Issue 2: Edge Function Returns 400 Error

**Symptoms**: Logs show `[ERROR] missing booking_id or sender_id`

**Possible Causes**:
- `chat_messages` table missing required columns
- Webhook payload structure incorrect

**Solutions**:
1. Verify `chat_messages` table has `booking_id` and `sender_id` columns:
   ```sql
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'chat_messages';
   ```
2. Check that messages are being inserted with non-null values for these fields
3. Review the webhook payload in Edge Function logs to see what data is being sent

### Issue 3: Edge Function Returns 500 Error

**Symptoms**: Logs show `[ERROR] booking lookup failed` or `[ERROR] professional lookup failed`

**Possible Causes**:
- Missing or incorrect Service Role Key in Edge Function secrets
- Row Level Security (RLS) blocking queries
- Referenced booking or professional doesn't exist

**Solutions**:
1. Verify Edge Function secrets are set correctly:
   - Navigate to Edge Functions → `chat_push_new_message` → Settings
   - Check `SUPABASE_SERVICE_ROLE_KEY` is set
2. Verify the booking exists:
   ```sql
   SELECT id, customer_id, professional_id 
   FROM bookings 
   WHERE id = '<booking_id_from_error>';
   ```
3. Check Edge Function is using Service Role Key for queries (bypasses RLS)

### Issue 4: No Push Notifications Received

**Symptoms**: Edge Function succeeds but no notifications appear on device

**Possible Causes**:
- No FCM tokens stored for recipient
- FCM tokens are invalid or expired
- Firebase configuration missing or incorrect
- App doesn't have notification permissions

**Solutions**:
1. Check recipient has FCM tokens:
   ```sql
   SELECT * FROM user_push_tokens WHERE user_id = '<recipient_id>';
   ```
2. Verify Firebase secrets in Edge Function:
   - `FIREBASE_PROJECT_ID` is set
   - `FIREBASE_SERVICE_ACCOUNT_JSON` is valid JSON with `client_email` and `private_key`
3. Check Edge Function logs for FCM errors:
   - `401 Unauthorized`: Invalid service account credentials
   - `404 Not Found`: Invalid project ID
   - `400 Bad Request`: Invalid token format
4. Verify app has notification permissions enabled on device
5. Test with a fresh FCM token (reinstall app or clear app data)

### Issue 5: Webhook Succeeds but Pushed Count is 0

**Symptoms**: Logs show `[INFO] Successfully pushed to 0 tokens`

**Possible Causes**:
- Recipient has no devices registered (no FCM tokens)
- Recipient identification logic incorrect

**Solutions**:
1. This is **expected behavior** if the recipient hasn't logged in or granted notification permissions
2. Verify recipient identification:
   - If sender is customer, recipient should be professional's user_id
   - If sender is professional's user_id, recipient should be customer
3. Check the booking has both customer and professional assigned:
   ```sql
   SELECT customer_id, professional_id 
   FROM bookings 
   WHERE id = '<booking_id>';
   ```
4. Verify the recipient user exists and has logged in at least once

### Issue 6: Webhook Retries Exhausted

**Symptoms**: Webhook shows failed status after 3 attempts

**Possible Causes**:
- Edge Function timeout (> 60 seconds)
- Edge Function crashes or throws unhandled exception
- Network issues between Supabase services

**Solutions**:
1. Check Edge Function logs for the error that caused the failure
2. Verify Edge Function completes within 60 seconds
3. Add error handling to prevent unhandled exceptions
4. If issue persists, contact Supabase support

### Issue 7: Duplicate Notifications

**Symptoms**: Users receive multiple notifications for the same message

**Possible Causes**:
- Multiple webhooks configured for the same table
- Webhook retry logic triggering multiple times
- User has multiple devices with same token

**Solutions**:
1. Check for duplicate webhooks: Database → Webhooks → Verify only one webhook for `chat_messages`
2. Ensure Edge Function returns success (200) to prevent retries
3. Check for duplicate tokens in `user_push_tokens`:
   ```sql
   SELECT token, COUNT(*) 
   FROM user_push_tokens 
   GROUP BY token 
   HAVING COUNT(*) > 1;
   ```

## Testing Checklist

Use this checklist to verify complete webhook functionality:

- [ ] Webhook appears in Database → Webhooks with status **Active**
- [ ] Sending a message creates a log entry in Edge Function logs
- [ ] Edge Function logs show successful recipient identification
- [ ] Edge Function logs show token retrieval (count > 0 if recipient has devices)
- [ ] Edge Function logs show successful FCM delivery
- [ ] Notification appears on recipient device (if app is closed/background)
- [ ] Local notification appears if app is in foreground
- [ ] Tapping notification navigates to correct chat screen
- [ ] No error messages in Edge Function logs
- [ ] Webhook execution history shows green checkmarks

## Performance Monitoring

Monitor webhook performance to ensure timely delivery:

**Expected Metrics**:
- Webhook trigger latency: < 1 second after message insert
- Edge Function execution time: < 2 seconds for single recipient
- End-to-end delivery time: < 5 seconds from message send to notification display

**How to Monitor**:
1. Check Edge Function logs for execution duration
2. Compare message `created_at` timestamp with notification receipt time
3. Monitor webhook failure rate in Dashboard

**Performance Issues**:
- If execution time > 5 seconds, check for slow database queries
- If failure rate > 5%, investigate error logs
- Consider adding database indexes on `bookings.id` and `user_push_tokens.user_id`

## Next Steps

After verifying the webhook is working correctly:

1. Proceed to integration testing (see `supabase/integration_testing.md`)
2. Review deployment configuration (see `supabase/deployment_guide.md`)
3. Test notification delivery in all app states (foreground, background, terminated)
4. Verify notification tap navigation works correctly
