// Supabase Edge Function: payment-webhook
// Your payment provider calls this URL after a charge succeeds or fails.
// It verifies the signature, then confirms the booking in the database.
//
// Deploy:  supabase functions deploy payment-webhook --no-verify-jwt
// Secrets: supabase secrets set PAYMENT_WEBHOOK_SECRET=...   (shared with the provider)
//
// Expected body (adapt `parseEvent` to your provider: Tap, Moyasar, Checkout.com, PayTabs, Stripe…):
//   { "payment_id": "<payments.id>", "status": "paid" | "failed", "provider": "tap", "reference": "chg_..." }
// Signature header: x-dars-signature = hex(HMAC-SHA256(rawBody, PAYMENT_WEBHOOK_SECRET))
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const secret = Deno.env.get("PAYMENT_WEBHOOK_SECRET") ?? "";

async function hmacHex(body: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

type PaymentEvent = { paymentId: string; status: "paid" | "failed"; provider: string; reference: string | null };

// Map your provider's payload to our event. Put our payments.id in the provider's metadata / reference field
// when you create the charge so it comes back here.
function parseEvent(body: Record<string, unknown>): PaymentEvent | null {
  const paymentId = String(body.payment_id ?? (body.metadata as Record<string, unknown> | undefined)?.payment_id ?? "");
  const raw = String(body.status ?? "").toLowerCase();
  if (!paymentId) return null;
  const status = ["paid", "captured", "succeeded", "success"].includes(raw) ? "paid" : "failed";
  return { paymentId, status, provider: String(body.provider ?? "gateway"), reference: body.reference ? String(body.reference) : null };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const raw = await req.text();
  if (!secret || !safeEqual(await hmacHex(raw), req.headers.get("x-dars-signature") ?? "")) {
    return new Response("Invalid signature", { status: 401 });
  }
  let event: PaymentEvent | null = null;
  try { event = parseEvent(JSON.parse(raw)); } catch { /* fall through */ }
  if (!event) return new Response("Unrecognised payload", { status: 400 });

  const fn = event.status === "paid" ? "confirm_payment" : "fail_payment";
  const args = event.status === "paid"
    ? { p_payment: event.paymentId, p_provider: event.provider, p_ref: event.reference }
    : { p_payment: event.paymentId, p_ref: event.reference };
  const { error } = await supabase.rpc(fn, args);
  if (error) return new Response(error.message, { status: 500 });          // provider will retry; confirm_payment is idempotent
  return Response.json({ ok: true });
});
