## `chat_push_new_message` (Supabase Edge Function)

### What it does
- Called when a row is INSERT-ed into `public.chat_messages`
- Determines the recipient for the booking chat (customer vs assigned professional)
- Inserts an in-app row into `public.notifications`
- Sends an FCM push to recipient tokens stored in `public.user_push_tokens`

### Recommended trigger
Use a **Database Webhook** in Supabase:
- **Table**: `public.chat_messages`
- **Events**: `INSERT`
- **Destination**: this Edge Function endpoint

### Required secrets
Set these in Supabase project settings (Edge Functions → Secrets):
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON` (stringified service account JSON)

### Notes
- This function uses the **FCM HTTP v1** API and generates an OAuth access token from the service account at runtime.\n
