/// Firebase Cloud Messaging (HTTP v1) sender.
///
/// No-op unless a `FIREBASE_SERVICE_ACCOUNT` secret (the full service-account
/// JSON) is set, so everything works with push simply disabled until you
/// configure Firebase:
///
///   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
///
/// See docs/PUSH.md.
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function b64urlJson(obj: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(obj)));
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

// deno-lint-ignore no-explicit-any
async function getAccessToken(sa: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${b64urlJson({ alg: "RS256", typ: "JWT" })}.${
    b64urlJson(claim)
  }`;
  const key = await importPrivateKey(sa.private_key);
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const jwt = `${unsigned}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" +
      `&assertion=${jwt}`,
  });
  const j = await res.json();
  if (!j.access_token) {
    throw new Error("FCM token exchange failed: " + JSON.stringify(j));
  }
  return j.access_token as string;
}

/// Sends a push to every device token of the given users. Silently returns if
/// push is not configured or the users have no registered tokens.
export async function sendPushToUsers(
  admin: SupabaseClient,
  userIds: string[],
  msg: PushMessage,
): Promise<void> {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!raw || userIds.length === 0) return;
  const sa = JSON.parse(raw);

  const { data: rows } = await admin
    .from("device_tokens")
    .select("token")
    .in("user_id", userIds);
  const tokens = (rows ?? []).map((r) => (r as { token: string }).token);
  if (tokens.length === 0) return;

  const accessToken = await getAccessToken(sa);
  const url =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  await Promise.all(tokens.map((token) =>
    fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: msg.title, body: msg.body },
          data: msg.data ?? {},
        },
      }),
    }).catch(() => {/* dead tokens are ignored */})
  ));
}
