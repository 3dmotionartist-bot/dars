// push-notifications: the decisions, kept free of Deno / Supabase so they can be tested anywhere
// (tests/push_notifications.test.mjs). index.ts wires them to the database and to Firebase.
//
// Called by two database webhooks (Supabase dashboard → Database → Webhooks), both with the header
// x-dars-hook: <DARS_HOOK_SECRET>:
//   * messages      INSERT → chat message (sender name + short preview) or incoming call (rings the phone);
//   * notifications INSERT → missed call, lesson reminder, and every other app notification.
// Messages are sent as Android "data" messages, so the app's own code (DarsMessagingService.kt) shows them
// the same way whether the app is open, in the background or closed.

export type Lang = "ar" | "en";
export type Kind = "message" | "call" | "missed_call" | "reminder" | "general";
export type Prefs = { messages: boolean; calls: boolean; reminders: boolean };
export type Token = { token: string; lang: Lang };

export type MessageRow = {
  id: number | string;
  conversation_id: string;
  sender_id: string | null;
  kind: string;
  body: string | null;
  blocked?: boolean | null;
  created_at?: string;
};
export type NotificationRow = {
  id: number | string;
  user_id: string;
  title: string;
  body: string;
  data?: Record<string, unknown> | null;
  created_at?: string;
};

export type Push = {
  kind: Kind;
  title: string;
  body: string;
  data: Record<string, string>; // everything the phone needs, as text
  urgent: boolean; // Android "high priority": wakes a sleeping phone
  ttlSeconds?: number; // a call that is not delivered within this time is dropped
};

const ROOM_RE = /^[a-hjkmnp-z]{5}(-[a-hjkmnp-z]{5}){3}$/;
export const CALL_TTL = 45; // seconds — the same as the ringing on the phone
const PREVIEW = 120;

const t = (lang: Lang, ar: string, en: string) => (lang === "ar" ? ar : en);

/** Arabic minutes: دقيقة / دقيقتين / 3–10 دقائق / 11+ دقيقة. */
export function arMinutes(n: number): string {
  if (n <= 1) return "دقيقة";
  if (n === 2) return "دقيقتين";
  if (n <= 10) return `${n} دقائق`;
  return `${n} دقيقة`;
}

/** "in 24 hours" / "in 1 hour" / "in 8 minutes" from the lesson start, in the phone's language. */
export function startsIn(lang: Lang, startsAt: string | undefined, kind: string, now = Date.now()): string {
  const at = startsAt ? Date.parse(startsAt) : NaN;
  let min = Number.isFinite(at) ? Math.max(1, Math.round((at - now) / 60000)) : kind === "24h" ? 1440 : kind === "1h" ? 60 : 10;
  if (min >= 90) {
    const h = Math.min(24, Math.round(min / 60));
    const ar = h === 2 ? "ساعتين" : h <= 10 ? `${h} ساعات` : `${h} ساعة`;
    return t(lang, `يبدأ درسك بعد ${ar}`, `Your lesson starts in ${h} hours`);
  }
  if (min >= 55) return t(lang, "يبدأ درسك بعد ساعة", "Your lesson starts in 1 hour");
  min = Math.max(1, min);
  return t(lang, `يبدأ درسك بعد ${arMinutes(min)}`, `Your lesson starts in ${min} minute${min === 1 ? "" : "s"}`);
}

/** Short preview of a chat message. A message hidden by the contact filter never shows its text. */
export function preview(lang: Lang, m: MessageRow): string {
  if (m.blocked) return t(lang, "رسالة جديدة", "New message");
  const body = (m.body ?? "").trim();
  switch (m.kind) {
    case "voice":
      return t(lang, "🎤 رسالة صوتية", "🎤 Voice message");
    case "image":
      return t(lang, "📷 صورة", "📷 Photo");
    case "file":
      return /\.(mp4|mov|m4v|webm|3gp|mkv)$/i.test(body) ? t(lang, "🎬 فيديو", "🎬 Video") : t(lang, "📎 ملف", "📎 File");
    case "call":
      return body.startsWith("meet:") ? t(lang, "أرسل رابط اجتماع", "sent a meeting link") : t(lang, "مكالمة", "Call");
    default: {
      if (!body) return t(lang, "رسالة جديدة", "New message");
      const one = body.replace(/\s+/g, " ");
      return one.length > PREVIEW ? one.slice(0, PREVIEW - 1) + "…" : one;
    }
  }
}

/** A new chat message → what the other person's phone shows (null = nothing to send). */
export function messagePush(m: MessageRow, senderName: string, lang: Lang, now = Date.now()): Push | null {
  if (!m.sender_id || m.kind === "system") return null; // system notes are shown inside the chat only
  const name = senderName.trim() || "Dars";
  const created = m.created_at ? Date.parse(m.created_at) : now;
  const base = { conversation_id: String(m.conversation_id), name, message_id: String(m.id) };
  const body = (m.body ?? "").trim();
  const call = /^(voice|video):(.+)$/.exec(body);
  if (m.kind === "call" && call) {
    if (!ROOM_RE.test(call[2])) return null;
    if (Number.isFinite(created) && now - created > CALL_TTL * 1000) return null; // the call is already over
    const video = call[1] === "video";
    return {
      kind: "call",
      title: name,
      body: video ? t(lang, "مكالمة فيديو واردة", "Incoming video call") : t(lang, "مكالمة صوتية واردة", "Incoming voice call"),
      data: { ...base, room: call[2], video: String(video), sent_at: m.created_at ?? new Date(now).toISOString() },
      urgent: true,
      ttlSeconds: CALL_TTL,
    };
  }
  return { kind: "message", title: name, body: preview(lang, m), data: base, urgent: true };
}

// Server notifications are written in English; the usual titles in Arabic (same list as the app).
export const AR_TITLES: Record<string, string> = {
  "New lesson booked": "تم حجز درس جديد",
  "New package purchased": "تم شراء باقة جديدة",
  "Payment & booking confirmed": "تم تأكيد الدفع والحجز",
  "New booking": "حجز جديد",
  "Refund issued": "تم استرداد المبلغ لرصيدك",
  "Profile under review": "ملفك قيد المراجعة",
  "Payout approved": "تمت الموافقة على طلب التحويل",
  "Payout paid": "تم تحويل أرباحك",
  "Payout rejected": "تم رفض طلب التحويل",
  "Lesson cancelled": "تم إلغاء الدرس",
  "Lesson rescheduled": "تم تغيير موعد الدرس",
  "We value your opinion!": "رأيك يهمنا!",
  "New review received": "وصلك تقييم جديد",
  "Missed lesson": "درس فائت",
  "Real time request!": "طلب مساعدة فورية!",
  "A tutor accepted your request": "قبِل مدرس طلبك",
  "Your profile is approved": "تم اعتماد ملفك",
  "Your profile needs changes": "ملفك يحتاج تعديلات",
  "Lesson reminder": "تذكير بالدرس",
  "Missed call": "مكالمة فائتة",
};

/** A new row in `notifications` → what the phone shows. */
export function notificationPush(n: NotificationRow, lang: Lang, now = Date.now()): Push | null {
  const data = (n.data ?? {}) as Record<string, unknown>;
  const type = String(data.type ?? "");
  const str: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) if (v !== null && v !== undefined) str[k] = typeof v === "string" ? v : JSON.stringify(v);
  str.notification_id = String(n.id);
  if (type === "missed_call") {
    const who = (n.body ?? "").trim() || "Dars";
    return { kind: "missed_call", title: t(lang, "مكالمة فائتة", "Missed call"), body: t(lang, `من ${who}`, `From ${who}`), data: str, urgent: true };
  }
  if (type === "reminder") {
    return {
      kind: "reminder",
      title: t(lang, "تذكير بالدرس", "Lesson reminder"),
      body: startsIn(lang, typeof data.starts_at === "string" ? data.starts_at : undefined, String(data.kind ?? ""), now),
      data: str,
      urgent: true,
    };
  }
  const urgent = data.urgent === true || data.urgent === "true"; // live-help requests ring like a call
  return {
    kind: "general",
    // Round H1: the Arabic saved with the notification (server_texts), else the usual titles.
    title: lang === "ar" ? (typeof data.title_ar === "string" ? data.title_ar : AR_TITLES[n.title] ?? n.title) : n.title,
    body: lang === "ar" && typeof data.body_ar === "string" ? data.body_ar : n.body ?? "",
    data: str,
    urgent,
  };
}

/** The person's switches: messages / calls (incoming + missed) / reminders. Other notices always go. */
export function allowed(kind: Kind, p: Prefs): boolean {
  switch (kind) {
    case "message":
      return p.messages;
    case "call":
    case "missed_call":
      return p.calls;
    case "reminder":
      return p.reminders;
    default:
      return true;
  }
}

/**
 * Firebase refuses a whole message whose data uses one of its reserved keys ("from", "notification",
 * "message_type", "collapse_key", or anything starting with "google" / "gcm"). The missed-call row carries
 * "from" (the caller's id), so missed calls never reached the phone (phone test, 19 Nov 2026). Such keys are
 * sent as "x_<key>" instead; the app does not read them.
 */
export function safeData(data: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    out[/^(from|notification|message_type|collapse_key)$|^(google|gcm)/i.test(k) ? `x_${k}` : k] = v;
  }
  return out;
}

/** Firebase Cloud Messaging HTTP v1 body: a data-only Android message (the app's own code shows it). */
export function fcmMessage(token: string, p: Push): Record<string, unknown> {
  return {
    message: {
      token,
      data: safeData({ ...p.data, type: p.kind, title: p.title, body: p.body }),
      android: {
        priority: p.urgent ? "HIGH" : "NORMAL",
        ...(p.ttlSeconds ? { ttl: `${p.ttlSeconds}s` } : {}),
      },
    },
  };
}

/** Firebase says this phone's token is no longer valid (app removed / data cleared) → forget it. */
export function deadToken(status: number, body: unknown): boolean {
  if (status === 404) return true;
  if (status !== 400) return false;
  const err = (body as { error?: { message?: string; details?: { errorCode?: string }[] } })?.error;
  const codes = (err?.details ?? []).map((d) => d?.errorCode);
  return codes.includes("UNREGISTERED") || (codes.includes("INVALID_ARGUMENT") && /registration token/i.test(err?.message ?? ""));
}

export type Deps = {
  hookSecret: string;
  /** Both people of a chat. */
  conversation: (id: string) => Promise<{ student_id: string; tutor_id: string } | null>;
  name: (userId: string) => Promise<string>;
  tokens: (userId: string) => Promise<Token[]>;
  prefs: (userId: string) => Promise<Prefs>;
  send: (message: Record<string, unknown>) => Promise<{ status: number; body: unknown }>;
  dropToken: (token: string) => Promise<void>;
  now?: () => number;
};

/** Constant-time comparison, so the secret cannot be guessed from response times. */
export function sameSecret(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a), y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

export async function handle(req: Request, d: Deps): Promise<Response> {
  // Only the database webhooks may call this (anyone with the public app key could otherwise send fake notices).
  if (!d.hookSecret || !sameSecret(req.headers.get("x-dars-hook") ?? "", d.hookSecret)) {
    return new Response("Unauthorized", { status: 401 });
  }
  let payload: { type?: string; table?: string; record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return new Response("Bad request", { status: 400 });
  }
  if (payload.type && payload.type !== "INSERT") return Response.json({ skipped: "not an insert" });
  const now = d.now ? d.now() : Date.now();
  const rec = payload.record ?? {};

  let userId = "";
  let build: (lang: Lang) => Push | null;
  if (payload.table === "messages") {
    const m = rec as unknown as MessageRow;
    if (!m.sender_id || !m.conversation_id) return Response.json({ skipped: "system message" });
    const c = await d.conversation(String(m.conversation_id));
    if (!c) return Response.json({ skipped: "no chat" });
    userId = m.sender_id === c.student_id ? c.tutor_id : m.sender_id === c.tutor_id ? c.student_id : "";
    if (!userId) return Response.json({ skipped: "sender not in chat" });
    const sender = await d.name(m.sender_id);
    build = (lang) => messagePush(m, sender, lang, now);
  } else if (payload.table === "notifications") {
    const n = rec as unknown as NotificationRow;
    if (!n.user_id) return new Response("No record", { status: 400 });
    userId = n.user_id;
    build = (lang) => notificationPush(n, lang, now);
  } else {
    return Response.json({ skipped: "other table" });
  }

  const probe = build("en");
  if (!probe) return Response.json({ skipped: "nothing to show" });
  if (!allowed(probe.kind, await d.prefs(userId))) return Response.json({ skipped: "turned off" });
  const tokens = await d.tokens(userId);
  if (!tokens.length) return Response.json({ skipped: "no device" });

  let sent = 0;
  for (const tk of tokens) {
    const p = build(tk.lang === "en" ? "en" : "ar");
    if (!p) continue;
    const r = await d.send(fcmMessage(tk.token, p));
    if (r.status >= 200 && r.status < 300) sent++;
    else if (deadToken(r.status, r.body)) await d.dropToken(tk.token);
    // Visible in Supabase → Edge Functions → push-notifications → Logs (no message text, no token).
    else console.warn(`FCM refused a ${p.kind} push: ${r.status} ${JSON.stringify(r.body).slice(0, 300)}`);
  }
  return Response.json({ sent, devices: tokens.length });
}
