// Supabase Edge Function: push-notifications
// Sends every new row of `notifications` to the user's phone with Firebase Cloud Messaging (HTTP v1).
//
// Setup:
//   1. Firebase console → Project settings → Service accounts → Generate new private key (JSON).
//   2. supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"
//   3. supabase functions deploy push-notifications
//   4. Supabase dashboard → Database → Webhooks → new webhook on table `notifications`, event INSERT,
//      type "Supabase Edge Functions" → push-notifications.
// The app saves the device token in profiles.fcm_token after sign-in.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");

let cached: { token: string; exp: number } | null = null;

const b64url = (data: ArrayBuffer | string) =>
  btoa(typeof data === "string" ? data : String.fromCharCode(...new Uint8Array(data)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function googleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp > now + 60) return cached.token;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }));
  const pem = String(sa.private_key).replace(/-----[^-]+-----|\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claim}`));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${header}.${claim}.${b64url(sig)}` }),
  });
  const json = await res.json();
  cached = { token: json.access_token, exp: now + (json.expires_in ?? 3600) };
  return cached.token;
}

Deno.serve(async (req) => {
  const payload = await req.json();                       // Database webhook: { type, table, record, ... }
  const n = payload.record;
  if (!n?.user_id) return new Response("No record", { status: 400 });

  const { data: profile } = await supabase.from("profiles").select("fcm_token").eq("id", n.user_id).single();
  if (!profile?.fcm_token) return Response.json({ skipped: "no device token" });

  const urgent = n.data?.urgent === true || n.data?.urgent === "true";   // live requests ring like a call
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await googleAccessToken()}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token: profile.fcm_token,
        notification: { title: n.title, body: n.body },
        data: Object.fromEntries(Object.entries(n.data ?? {}).map(([k, v]) => [k, String(v)])),
        android: { priority: urgent ? "HIGH" : "NORMAL", notification: { channel_id: urgent ? "live_requests" : "general" } },
        apns: { headers: { "apns-priority": urgent ? "10" : "5" }, payload: { aps: { sound: "default" } } },
      },
    }),
  });
  if (res.status === 404 || res.status === 400) {
    await supabase.from("profiles").update({ fcm_token: null }).eq("id", n.user_id);   // stale token
  }
  return Response.json({ sent: res.ok, status: res.status });
});
