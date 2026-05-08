# Deployment Guide: Chat Push Notifications

## Overview

This guide provides step-by-step instructions for deploying and configuring the chat push notification feature. Follow these steps to ensure proper integration between Firebase Cloud Messaging (FCM), Supabase Edge Functions, and your Flutter application.

## Prerequisites

- Active Firebase project with Cloud Messaging enabled
- Supabase project with Edge Functions deployed
- Flutter development environment configured
- Admin access to Firebase Console and Supabase Dashboard

---

## Part 1: Firebase Configuration

### 1.1 Obtain Firebase Service Account JSON

The Edge Function requires a Firebase service account to send FCM messages programmatically.

**Steps:**

1. Navigate to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click the gear icon (⚙️) next to "Project Overview" → **Project settings**
4. Navigate to the **Service accounts** tab
5. Click **Generate new private key**
6. Confirm by clicking **Generate key**
7. Save the downloaded JSON file securely (e.g., `firebase-service-account.json`)

**Important:** This file contains sensitive credentials. Never commit it to version control.

### 1.2 Extract Required Credentials

Open the downloaded JSON file and locate these fields:

```json
{
  "project_id": "your-project-id",
  "client_email": "firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
}
```

You'll need:
- `project_id` → for `FIREBASE_PROJECT_ID` secret
- The entire JSON object → for `FIREBASE_SERVICE_ACCOUNT_JSON` secret

### 1.3 Add Firebase Configuration Files to Flutter Project

**For Android:**

1. In Firebase Console, go to **Project settings** → **General**
2. Scroll to **Your apps** section
3. Select your Android app (or add one if not exists)
4. Download `google-services.json`
5. Place the file in your Flutter project at: `android/app/google-services.json`

**For iOS:**

1. In Firebase Console, go to **Project settings** → **General**
2. Scroll to **Your apps** section
3. Select your iOS app (or add one if not exists)
4. Download `GoogleService-Info.plist`
5. Place the file in your Flutter project at: `ios/Runner/GoogleService-Info.plist`
6. Open `ios/Runner.xcworkspace` in Xcode
7. Right-click on `Runner` folder → **Add Files to "Runner"**
8. Select `GoogleService-Info.plist` and ensure **Copy items if needed** is checked

---

## Part 2: Supabase Edge Function Secrets

### 2.1 Required Secrets

The `chat_push_new_message` Edge Function requires four secrets:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SUPABASE_URL` | Your Supabase project URL | `https://xxxxx.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key with elevated privileges | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |
| `FIREBASE_PROJECT_ID` | Firebase project identifier | `my-app-12345` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Stringified Firebase service account JSON | `{"type":"service_account",...}` |

### 2.2 Set Secrets in Supabase Dashboard

**Steps:**

1. Navigate to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Go to **Edge Functions** in the left sidebar
4. Click on the **chat_push_new_message** function
5. Navigate to the **Secrets** tab
6. Add each secret:

#### SUPABASE_URL

- **Name:** `SUPABASE_URL`
- **Value:** Your project URL (found in **Settings** → **API** → **Project URL**)
- Example: `https://abcdefghijklmnop.supabase.co`

#### SUPABASE_SERVICE_ROLE_KEY

- **Name:** `SUPABASE_SERVICE_ROLE_KEY`
- **Value:** Your service role key (found in **Settings** → **API** → **Project API keys** → **service_role**)
- **Warning:** This key bypasses Row Level Security. Keep it secret.

#### FIREBASE_PROJECT_ID

- **Name:** `FIREBASE_PROJECT_ID`
- **Value:** The `project_id` from your Firebase service account JSON
- Example: `my-flutter-app-12345`

#### FIREBASE_SERVICE_ACCOUNT_JSON

- **Name:** `FIREBASE_SERVICE_ACCOUNT_JSON`
- **Value:** The entire Firebase service account JSON as a **single-line string**

**How to stringify the JSON:**

```bash
# Using jq (recommended)
cat firebase-service-account.json | jq -c

# Using Node.js
node -e "console.log(JSON.stringify(require('./firebase-service-account.json')))"

# Using Python
python -c "import json; print(json.dumps(json.load(open('firebase-service-account.json'))))"
```

Copy the output and paste it as the secret value.

**Example stringified JSON:**
```
{"type":"service_account","project_id":"my-app","private_key_id":"abc123","private_key":"-----BEGIN PRIVATE KEY-----\nMIIE...","client_email":"firebase-adminsdk@my-app.iam.gserviceaccount.com","client_id":"123456789","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk%40my-app.iam.gserviceaccount.com"}
```

### 2.3 Verify Secrets

After adding all secrets:

1. Click **Save** or **Update**
2. Verify all four secrets appear in the secrets list
3. Redeploy the Edge Function if prompted

---

## Part 3: Database Webhook Configuration

### 3.1 Create Webhook

The webhook triggers the Edge Function when a new chat message is inserted.

**Steps:**

1. In Supabase Dashboard, go to **Database** → **Webhooks**
2. Click **Create a new hook** or **Enable Webhooks** (if first time)
3. Configure the webhook:

**Webhook Configuration:**

| Field | Value |
|-------|-------|
| **Name** | `chat_message_push_notification` |
| **Table** | `public.chat_messages` |
| **Events** | ✅ INSERT (check only this) |
| **Type** | Edge Function |
| **Edge Function** | `chat_push_new_message` |
| **HTTP Headers** | (leave empty) |
| **Timeout** | 5000 ms (default) |

4. Click **Create webhook** or **Confirm**

### 3.2 Verify Webhook

1. Go to **Database** → **Webhooks**
2. Confirm `chat_message_push_notification` appears in the list
3. Status should show as **Active** or **Enabled**

---

## Part 4: Flutter Application Configuration

### 4.1 Update pubspec.yaml

Ensure these dependencies are present:

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.3.0
  supabase_flutter: ^2.0.0
```

Run:
```bash
flutter pub get
```

### 4.2 Android Configuration

**Update android/app/build.gradle:**

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Required for FCM
    }
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

**Update android/build.gradle:**

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

**Update android/app/build.gradle (bottom of file):**

```gradle
apply plugin: 'com.google.gms.google-services'
```

**Add notification sound (optional):**

Place `notification.mp3` in `android/app/src/main/res/raw/notification.mp3`

### 4.3 iOS Configuration

**Update ios/Runner/Info.plist:**

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

**Enable Push Notifications capability:**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** (if not present)
7. Check **Remote notifications** under Background Modes

**Add notification sound (optional):**

Place `notification.aiff` in `ios/Runner/` and add to Xcode project.

### 4.4 Initialize Firebase in Flutter

**Update lib/main.dart:**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Generated by flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  runApp(MyApp());
}
```

**Generate firebase_options.dart:**

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase
flutterfire configure
```

---

## Part 5: Token Cleanup Maintenance

### 5.1 Stale Token Cleanup Strategy

Over time, FCM tokens can become stale due to:
- App uninstalls
- Device resets
- Token expiration
- User switching devices

**Recommended cleanup frequency:** Weekly (every Sunday at 2 AM)

**Why cleanup is important:**
- Reduces database storage costs
- Improves Edge Function performance (fewer failed FCM calls)
- Maintains accurate user engagement metrics
- Prevents hitting FCM rate limits with invalid tokens

**Cleanup strategy:**
1. **Immediate cleanup:** Remove tokens when FCM returns "invalid-registration-token" errors
2. **Periodic cleanup:** Weekly removal of tokens older than 90 days
3. **User-based cleanup:** Remove tokens for users inactive for 60+ days
4. **Platform-specific cleanup:** Monitor and clean tokens by platform (Android/iOS/Web)

### 5.2 Identify Stale Tokens

Use these SQL queries to identify different types of stale tokens:

**Basic stale tokens (90+ days old):**
```sql
-- Find tokens that haven't been updated in 90+ days
SELECT 
  id,
  user_id,
  platform,
  token,
  created_at,
  CURRENT_TIMESTAMP - created_at AS age
FROM user_push_tokens
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
ORDER BY created_at ASC;
```

**Tokens for inactive users:**
```sql
-- Find tokens for users who haven't logged in for 60+ days
SELECT 
  upt.id,
  upt.user_id,
  upt.platform,
  upt.created_at AS token_created,
  u.last_sign_in_at,
  CURRENT_TIMESTAMP - u.last_sign_in_at AS user_inactive_duration
FROM user_push_tokens upt
JOIN users u ON upt.user_id = u.id
WHERE u.last_sign_in_at < CURRENT_TIMESTAMP - INTERVAL '60 days'
ORDER BY u.last_sign_in_at ASC;
```

**Token count by age groups:**
```sql
-- Analyze token age distribution
SELECT 
  CASE 
    WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN '< 1 week'
    WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN '1-4 weeks'
    WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '90 days' THEN '1-3 months'
    ELSE '> 3 months (STALE)'
  END AS age_group,
  COUNT(*) AS token_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM user_push_tokens
GROUP BY age_group
ORDER BY 
  CASE age_group
    WHEN '< 1 week' THEN 1
    WHEN '1-4 weeks' THEN 2
    WHEN '1-3 months' THEN 3
    ELSE 4
  END;
```

### 5.3 Delete Stale Tokens

**Manual cleanup (run in Supabase SQL Editor):**

```sql
-- Option 1: Delete tokens older than 90 days (basic cleanup)
DELETE FROM user_push_tokens
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';

-- Option 2: Delete tokens for inactive users (recommended)
DELETE FROM user_push_tokens
WHERE user_id IN (
  SELECT id FROM users 
  WHERE last_sign_in_at < CURRENT_TIMESTAMP - INTERVAL '60 days'
)
AND created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';

-- Option 3: Conservative cleanup (keeps tokens for recently active users)
DELETE FROM user_push_tokens
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
  AND user_id NOT IN (
    SELECT DISTINCT user_id FROM chat_messages 
    WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
  );
```

**Cleanup verification:**
```sql
-- Check how many tokens would be deleted (run before actual deletion)
SELECT COUNT(*) AS tokens_to_delete
FROM user_push_tokens
WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days';

-- After deletion, verify cleanup results
SELECT 
  'After cleanup' AS status,
  COUNT(*) AS remaining_tokens,
  COUNT(DISTINCT user_id) AS active_users
FROM user_push_tokens;
```

**Automated cleanup (recommended):**

Create a Supabase Edge Function scheduled to run weekly:

```typescript
// supabase/functions/cleanup_stale_tokens/index.ts
import { createClient } from '@supabase/supabase-js';

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  try {
    // Delete tokens older than 90 days for users inactive for 60+ days
    const { data, error } = await supabase
      .from('user_push_tokens')
      .delete()
      .lt('created_at', new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString())
      .in('user_id', 
        supabase
          .from('users')
          .select('id')
          .lt('last_sign_in_at', new Date(Date.now() - 60 * 24 * 60 * 60 * 1000).toISOString())
      );

    if (error) {
      console.error('Cleanup error:', error);
      return new Response(JSON.stringify({ 
        ok: false, 
        error: error.message 
      }), { status: 500 });
    }

    // Log cleanup results
    console.log(`Cleaned up ${data?.length || 0} stale tokens`);

    return new Response(JSON.stringify({ 
      ok: true, 
      deleted: data?.length || 0,
      timestamp: new Date().toISOString()
    }), { 
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({ 
      ok: false, 
      error: 'Internal server error' 
    }), { status: 500 });
  }
});
```

**Schedule the function using GitHub Actions:**

Create `.github/workflows/token-cleanup.yml`:

```yaml
name: Weekly Token Cleanup

on:
  schedule:
    - cron: '0 2 * * 0'  # Every Sunday at 2 AM UTC
  workflow_dispatch:  # Allow manual trigger

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Cleanup Stale Tokens
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/cleanup_stale_tokens"
```

**Alternative: Use Supabase Cron (if available):**

```sql
-- Schedule weekly cleanup (requires Supabase Pro plan)
SELECT cron.schedule(
  'weekly-token-cleanup',
  '0 2 * * 0',  -- Every Sunday at 2 AM
  $$
  DELETE FROM user_push_tokens
  WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '90 days'
    AND user_id IN (
      SELECT id FROM users 
      WHERE last_sign_in_at < CURRENT_TIMESTAMP - INTERVAL '60 days'
    );
  $$
);
```

### 5.4 Monitor Token Health

**Query to check token distribution:**

```sql
-- Token count by platform
SELECT 
  platform,
  COUNT(*) AS token_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM user_push_tokens
GROUP BY platform;

-- Token age distribution
SELECT 
  CASE 
    WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN '< 1 week'
    WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN '1-4 weeks'
    WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '90 days' THEN '1-3 months'
    ELSE '> 3 months'
  END AS age_group,
  COUNT(*) AS token_count
FROM user_push_tokens
GROUP BY age_group
ORDER BY age_group;
```

### 5.5 Cleanup Best Practices

**Timing and Frequency:**
1. **Run cleanup during low-traffic hours** (e.g., 2-4 AM in your primary timezone)
2. **Weekly frequency is optimal** - balances database performance with storage costs
3. **Avoid cleanup during peak usage** to prevent impacting active users

**Safety and Monitoring:**
4. **Always test cleanup queries in staging** before running in production
5. **Log cleanup results** for monitoring and auditing purposes
6. **Set up alerts** if token count grows unexpectedly (>10% week-over-week)
7. **Monitor cleanup impact** on notification delivery rates

**Advanced Strategies:**
8. **Consider user activity patterns** - keep tokens for users with recent app activity
9. **Platform-specific cleanup** - iOS tokens may need different retention periods than Android
10. **Gradual cleanup** - delete in batches of 1000 tokens to avoid database locks

**Cleanup Monitoring Queries:**

```sql
-- Weekly cleanup report
WITH cleanup_stats AS (
  SELECT 
    DATE_TRUNC('week', created_at) AS week,
    COUNT(*) AS tokens_created,
    COUNT(DISTINCT user_id) AS unique_users
  FROM user_push_tokens
  WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '8 weeks'
  GROUP BY DATE_TRUNC('week', created_at)
)
SELECT 
  week,
  tokens_created,
  unique_users,
  LAG(tokens_created) OVER (ORDER BY week) AS prev_week_tokens,
  ROUND(
    (tokens_created - LAG(tokens_created) OVER (ORDER BY week)) * 100.0 / 
    NULLIF(LAG(tokens_created) OVER (ORDER BY week), 0), 2
  ) AS growth_percentage
FROM cleanup_stats
ORDER BY week DESC;

-- Token health dashboard
SELECT 
  platform,
  COUNT(*) AS total_tokens,
  COUNT(DISTINCT user_id) AS unique_users,
  ROUND(AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - created_at)) / 86400), 1) AS avg_age_days,
  COUNT(CASE WHEN created_at > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 1 END) AS recent_tokens,
  COUNT(CASE WHEN created_at < CURRENT_TIMESTAMP - INTERVAL '90 days' THEN 1 END) AS stale_tokens
FROM user_push_tokens
GROUP BY platform
ORDER BY total_tokens DESC;
```

**Emergency Cleanup (if database is overwhelmed):**

```sql
-- Aggressive cleanup for emergency situations
-- WARNING: Only use if token table is causing performance issues

-- Step 1: Delete tokens for users who haven't logged in for 30+ days
DELETE FROM user_push_tokens
WHERE user_id IN (
  SELECT id FROM users 
  WHERE last_sign_in_at < CURRENT_TIMESTAMP - INTERVAL '30 days'
);

-- Step 2: Keep only the most recent token per user per platform
DELETE FROM user_push_tokens
WHERE id NOT IN (
  SELECT DISTINCT ON (user_id, platform) id
  FROM user_push_tokens
  ORDER BY user_id, platform, created_at DESC
);
```

---

## Part 6: Verification

### 6.1 Test Edge Function

Send a test message and verify:

1. Go to **Edge Functions** → **chat_push_new_message** → **Logs**
2. Send a chat message in your app
3. Check logs for successful execution
4. Look for: `"ok": true, "pushed": N` where N > 0

### 6.2 Test Notifications

Follow the integration testing guide in `supabase/integration_testing.md`:

- ✅ Foreground notification display
- ✅ Background notification delivery
- ✅ Terminated state notification
- ✅ Notification tap navigation
- ✅ Token refresh handling
- ✅ Logout token cleanup

### 6.3 Verify Database Records

**Check tokens are stored:**

```sql
SELECT * FROM user_push_tokens WHERE user_id = 'YOUR_USER_ID';
```

**Check notifications are logged:**

```sql
SELECT * FROM notifications 
WHERE type = 'chat_message' 
ORDER BY created_at DESC 
LIMIT 10;
```

---

## Troubleshooting

### Edge Function Not Triggering

**Symptoms:** Messages sent but no Edge Function logs

**Solutions:**
1. Verify webhook is active: **Database** → **Webhooks**
2. Check webhook events include INSERT
3. Verify Edge Function is deployed
4. Check Edge Function secrets are set correctly

### No Notifications Received

**Symptoms:** Edge Function succeeds but no notification appears

**Solutions:**
1. Verify FCM token exists in `user_push_tokens` table
2. Check Firebase project has Cloud Messaging enabled
3. Verify `google-services.json` / `GoogleService-Info.plist` are correct
4. Check device notification permissions are granted
5. Review Edge Function logs for FCM errors

### Invalid Token Errors

**Symptoms:** Edge Function logs show "invalid-registration-token"

**Solutions:**
1. Token may be expired - trigger token refresh by reinstalling app
2. Run stale token cleanup query
3. Verify token format matches FCM requirements

### Foreground Notifications Not Showing

**Symptoms:** Background works but foreground doesn't show notification

**Solutions:**
1. Verify `NotificationService.setupFcmListeners()` is called
2. Check Android notification channel is created
3. Verify `flutter_local_notifications` is initialized
4. Check app has notification permissions

---

## Security Checklist

- [ ] Firebase service account JSON is stored securely (not in version control)
- [ ] Supabase service role key is set as Edge Function secret (not hardcoded)
- [ ] `google-services.json` and `GoogleService-Info.plist` are in `.gitignore`
- [ ] Edge Function secrets are set in Supabase Dashboard
- [ ] Row Level Security policies are enabled on `user_push_tokens` table
- [ ] Token cleanup job is scheduled and monitored

---

## Support

For issues or questions:

- **Firebase:** [Firebase Support](https://firebase.google.com/support)
- **Supabase:** [Supabase Discord](https://discord.supabase.com)
- **Flutter:** [Flutter Documentation](https://docs.flutter.dev)

---

**Deployment guide complete.** Follow each section in order for successful configuration.
