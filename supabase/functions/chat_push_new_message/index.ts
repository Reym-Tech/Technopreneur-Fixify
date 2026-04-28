// supabase/functions/chat_push_new_message/index.ts
//
// Supabase Edge Function
// Trigger: Database Webhook on `public.chat_messages` INSERT (recommended).
//
// Responsibilities:
//  - Determine recipient (customer vs professional) for booking-scoped chat.
//  - Insert in-app notification into `public.notifications`.
//  - Send FCM push notification to recipient devices (tokens in `public.user_push_tokens`).
//
// Secrets required:
//  - SUPABASE_URL
//  - SUPABASE_SERVICE_ROLE_KEY
//  - FIREBASE_PROJECT_ID
//  - FIREBASE_SERVICE_ACCOUNT_JSON  (stringified JSON; includes private_key, client_email)

import { createClient } from "npm:@supabase/supabase-js@2";

type DbWebhookPayload = {
  type?: string;
  table?: string;
  schema?: string;
  record?: Record<string, unknown>;
  old_record?: Record<string, unknown> | null;
};

type ServiceAccount = {
  client_email: string;
  private_key: string;
};

function json(resBody: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(resBody), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}

function base64UrlEncode(bytes: Uint8Array) {
  const b64 = btoa(String.fromCharCode(...bytes));
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function importPrivateKey(pem: string) {
  // PEM PKCS8: -----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----
  const clean = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const raw = Uint8Array.from(atob(clean), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    raw.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getGoogleAccessToken(sa: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 60 * 50,
  };

  const enc = new TextEncoder();
  const headerB64 = base64UrlEncode(enc.encode(JSON.stringify(header)));
  const claimB64 = base64UrlEncode(enc.encode(JSON.stringify(claimSet)));
  const toSign = `${headerB64}.${claimB64}`;

  const key = await importPrivateKey(sa.private_key);
  const sig = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    enc.encode(toSign),
  );
  const sigB64 = base64UrlEncode(new Uint8Array(sig));
  const jwt = `${toSign}.${sigB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`oauth token error: ${tokenRes.status} ${text}`);
  }
  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

async function sendFcm({
  accessToken,
  projectId,
  token,
  title,
  body,
  data,
}: {
  accessToken: string;
  projectId: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: {
          priority: "high",
          notification: {
            channel_id: "chat",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: { sound: "default" },
          },
        },
      },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`fcm send error: ${res.status} ${text}`);
  }
}

Deno.serve(async (req) => {
  try {
    const payload = (await req.json()) as DbWebhookPayload;
    const record = payload.record ?? {};

    const bookingId = String(record["booking_id"] ?? "");
    const senderId = String(record["sender_id"] ?? "");
    const messageBody = String(record["body"] ?? "");

    if (!bookingId || !senderId) {
      return json({ ok: false, error: "missing booking_id or sender_id" }, {
        status: 400,
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!;
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!;

    const sa = JSON.parse(saRaw) as ServiceAccount;

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    // Get booking participants
    const { data: booking, error: bookingErr } = await supabase
      .from("bookings")
      .select("id, customer_id, professional_id")
      .eq("id", bookingId)
      .maybeSingle();

    if (bookingErr || !booking) {
      throw new Error(`booking lookup failed: ${bookingErr?.message ?? "null"}`);
    }

    let proUserId: string | null = null;
    if (booking.professional_id) {
      const { data: pro, error: proErr } = await supabase
        .from("professionals")
        .select("user_id")
        .eq("id", booking.professional_id)
        .maybeSingle();
      if (proErr) throw new Error(`professional lookup failed: ${proErr.message}`);
      proUserId = pro?.user_id ?? null;
    }

    const customerId = booking.customer_id as string;
    const recipientId = senderId === customerId ? proUserId : customerId;
    if (!recipientId) {
      // No assigned professional yet (or malformed data) — nothing to notify.
      return json({ ok: true, skipped: "no recipient" });
    }

    // Insert in-app notification
    await supabase.from("notifications").insert({
      user_id: recipientId,
      role: "customer", // UI filters by user_id, role is informational here
      type: "chat_message",
      title: "New message",
      message: messageBody.length > 140 ? `${messageBody.slice(0, 140)}…` : messageBody,
      reference_id: bookingId,
      reference_type: "booking",
      data: { booking_id: bookingId },
    });

    // Send push to all tokens
    const { data: tokens, error: tokensErr } = await supabase
      .from("user_push_tokens")
      .select("token")
      .eq("user_id", recipientId);
    if (tokensErr) throw new Error(`token lookup failed: ${tokensErr.message}`);

    if (!tokens || tokens.length === 0) return json({ ok: true, pushed: 0 });

    const accessToken = await getGoogleAccessToken(sa);
    const title = "New message";
    const body = messageBody.length > 140 ? `${messageBody.slice(0, 140)}…` : messageBody;

    let pushed = 0;
    for (const t of tokens) {
      const token = String(t.token ?? "");
      if (!token) continue;
      await sendFcm({
        accessToken,
        projectId,
        token,
        title,
        body,
        data: { booking_id: bookingId, type: "chat_message" },
      });
      pushed++;
    }

    return json({ ok: true, pushed });
  } catch (e) {
    return json({ ok: false, error: String(e?.message ?? e) }, { status: 500 });
  }
});

