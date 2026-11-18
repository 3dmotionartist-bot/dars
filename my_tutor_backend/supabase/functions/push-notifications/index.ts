// Supabase Edge Function: push-notifications (Round D, D1)
// Sends chat messages, incoming calls, missed calls, lesson reminders and other app notices to the person's
// phones with Firebase Cloud Messaging (HTTP v1). The decisions are in logic.ts (tested by
// tests/push_notifications.test.mjs); this file connects them to the database and to Firebase.
//
// Setup (the owner, in the dashboards — never in chat):
//   1. Firebase console → Project settings → Service accounts → Generate new private key (a JSON file).
//   2. Supabase → Edge Functions → Secrets: FCM_SERVICE_ACCOUNT = the whole JSON file;
//      DARS_HOOK_SECRET = a long random password you make up.
//   3. Deploy this function with "Verify JWT" OFF (the webhooks prove themselves with x-dars-hook instead):
//        supabase functions deploy push-notifications --no-verify-jwt
//   4. Supabase → Database → Webhooks → two webhooks, each type "Supabase Edge Functions" → push-notifications,
//      method POST, with the HTTP header  x-dars-hook: <the same password>:
//        dars_push_messages       on table messages,      event Insert
//        dars_push_notifications  on table notifications, event Insert
//   Requests without the header are refused (401).
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { handle, type Lang, type Prefs, type Token } from "./logic.ts";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});
const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") || "{}");

let cached: { token: string; exp: number } | null = null;

const b64url = (data: ArrayBuffer | string) =>
  btoa(typeof data === "string" ? data : String.fromCharCode(...new Uint8Array(data)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

/** A Google access token for FCM, signed with the service account's key (kept for its lifetime). */
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
  if (!json.access_token) throw new Error("Google sign-in for FCM failed: " + JSON.stringify(json).slice(0, 200));
  cached = { token: json.access_token, exp: now + (json.expires_in ?? 3600) };
  return cached.token;
}

Deno.serve((req) =>
  handle(req, {
    hookSecret: Deno.env.get("DARS_HOOK_SECRET") ?? "",
    conversation: async (id) => {
      const { data } = await db.from("conversations").select("student_id, tutor_id").eq("id", id).maybeSingle();
      return data ?? null;
    },
    name: async (uid) => {
      const { data } = await db.from("profiles").select("full_name").eq("id", uid).maybeSingle();
      return (data?.full_name as string | undefined) ?? "";
    },
    tokens: async (uid) => {
      const { data } = await db.from("device_tokens").select("token, lang").eq("user_id", uid)
        .order("updated_at", { ascending: false }).limit(10);
      return (data ?? []).map((r) => ({ token: r.token as string, lang: (r.lang === "en" ? "en" : "ar") as Lang })) as Token[];
    },
    prefs: async (uid) => {
      const { data } = await db.from("notification_prefs").select("messages, calls, reminders").eq("user_id", uid).maybeSingle();
      return { messages: data?.messages ?? true, calls: data?.calls ?? true, reminders: data?.reminders ?? true } as Prefs;
    },
    send: async (message) => {
      if (!sa.project_id) return { status: 503, body: { error: { message: "FCM_SERVICE_ACCOUNT is not set" } } };
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: "POST",
        headers: { Authorization: `Bearer ${await googleAccessToken()}`, "Content-Type": "application/json" },
        body: JSON.stringify(message),
      });
      let body: unknown = null;
      try {
        body = await res.json();
      } catch { /* empty */ }
      return { status: res.status, body };
    },
    dropToken: async (token) => {
      await db.from("device_tokens").delete().eq("token", token);
    },
  })
);
