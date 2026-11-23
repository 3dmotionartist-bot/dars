// Tests for the push-notifications edge function's decisions (Round D, D1), with fake database / Firebase.
// Run: node --experimental-strip-types tests/push_notifications.test.mjs   (Node 22.6+; part of tests/run.sh)
import {
  handle, messagePush, notificationPush, allowed, fcmMessage, safeData, deadToken, preview, startsIn, arMinutes, CALL_TTL,
} from "../supabase/functions/push-notifications/logic.ts";

let failed = 0;
const ok = (cond, label) => {
  if (cond) console.log("ok   " + label);
  else { failed++; console.log("FAIL " + label); }
};

const STU = "11111111-1111-1111-1111-111111111111";
const TUT = "22222222-2222-2222-2222-222222222222";
const CONV = "33333333-3333-3333-3333-333333333333";
const NOW = Date.parse("2026-11-18T12:00:00Z");
const ROOM = "kqzpt-mwhra-bcdeg-xyzab";
const SECRET = "a-long-random-hook-secret";

function deps(over = {}) {
  const calls = { sent: [], dropped: [] };
  const d = {
    hookSecret: SECRET,
    conversation: async (id) => (id === CONV ? { student_id: STU, tutor_id: TUT } : null),
    name: async (uid) => (uid === STU ? "ليان" : "سامر"),
    tokens: async (uid) => (uid === TUT ? [{ token: "tok-tutor-ar", lang: "ar" }, { token: "tok-tutor-en", lang: "en" }] : [{ token: "tok-stu", lang: "ar" }]),
    prefs: async () => ({ messages: true, calls: true, reminders: true }),
    send: async (m) => { calls.sent.push(m.message); return { status: 200, body: { name: "projects/x/messages/1" } }; },
    dropToken: async (t) => { calls.dropped.push(t); },
    now: () => NOW,
    ...over,
  };
  return { d, calls };
}
const hook = (table, record, secret = SECRET, type = "INSERT") => new Request("https://x.supabase.co/functions/v1/push-notifications", {
  method: "POST",
  headers: { "content-type": "application/json", ...(secret === null ? {} : { "x-dars-hook": secret }) },
  body: JSON.stringify({ type, table, schema: "public", record }),
});
const msg = (over = {}) => ({ id: 7, conversation_id: CONV, sender_id: STU, kind: "text", body: "مرحبا أستاذ، هل الدرس غداً؟", blocked: false,
  created_at: new Date(NOW - 2000).toISOString(), ...over });

{ // the webhook's secret
  const { d, calls } = deps();
  ok((await handle(hook("messages", msg(), null), d)).status === 401, "no x-dars-hook header → refused (401)");
  ok((await handle(hook("messages", msg(), "wrong"), d)).status === 401, "wrong secret → refused");
  const { d: d2 } = deps({ hookSecret: "" });
  ok((await handle(hook("messages", msg()), d2)).status === 401, "secret not set up yet → everything refused");
  ok(calls.sent.length === 0, "… and nothing is sent");
}
{ // a chat message
  const { d, calls } = deps();
  const r = await (await handle(hook("messages", msg()), d)).json();
  ok(r.sent === 2 && calls.sent.length === 2, "a message goes to every phone of the other person (the tutor has 2)");
  const ar = calls.sent.find((m) => m.token === "tok-tutor-ar"), en = calls.sent.find((m) => m.token === "tok-tutor-en");
  ok(ar.data.type === "message" && ar.data.title === "ليان" && ar.data.body === "مرحبا أستاذ، هل الدرس غداً؟", "… sender name + the message text");
  ok(ar.data.conversation_id === CONV, "… with the chat to open when tapped (and to group by)");
  ok(ar.android.priority === "HIGH" && !ar.notification, "… a high-priority data message, shown by the app's own code");
  ok(Object.values(ar.data).every((v) => typeof v === "string"), "… all data values are text (FCM rule)");
  ok(en.data.body === ar.data.body, "the preview is the same text in both languages");
}
{ // previews
  ok(preview("ar", msg({ blocked: true, body: "اتصل بي على 0933123456" })) === "رسالة جديدة", "a hidden message never shows its text");
  ok(preview("en", msg({ blocked: true })) === "New message", "… in English: New message");
  ok(preview("ar", msg({ kind: "voice", body: "🎤" })) === "🎤 رسالة صوتية", "voice note");
  ok(preview("en", msg({ kind: "image", body: "" })) === "📷 Photo", "photo");
  ok(preview("ar", msg({ kind: "file", body: "lesson.mp4" })) === "🎬 فيديو" && preview("en", msg({ kind: "file", body: "notes.pdf" })) === "📎 File", "video / file (no file name)");
  ok(preview("en", msg({ kind: "call", body: "meet:" + ROOM })) === "sent a meeting link", "meeting link");
  const long = "ا".repeat(300);
  ok(preview("ar", msg({ body: long })).length === 120, "long text is cut to a short preview");
  ok(preview("en", msg({ body: "line one\n\nline two" })) === "line one line two", "line breaks become spaces");
}
{ // calls
  const p = messagePush(msg({ kind: "call", body: "video:" + ROOM, created_at: new Date(NOW - 3000).toISOString() }), "ليان", "ar", NOW);
  ok(p.kind === "call" && p.data.room === ROOM && p.data.video === "true" && p.title === "ليان" && p.body === "مكالمة فيديو واردة", "a video call rings with the caller's name");
  ok(p.urgent && p.ttlSeconds === CALL_TTL && fcmMessage("t", p).message.android.ttl === "45s", "… high priority, dropped if not delivered within 45 s");
  const v = messagePush(msg({ kind: "call", body: "voice:" + ROOM }), "Layan", "en", NOW);
  ok(v.body === "Incoming voice call" && v.data.video === "false", "voice call, in English");
  ok(messagePush(msg({ kind: "call", body: "video:" + ROOM, created_at: new Date(NOW - 60000).toISOString() }), "x", "ar", NOW) === null,
    "a call older than 45 s does not ring (it is over)");
  ok(messagePush(msg({ kind: "call", body: "video:not-a-room" }), "x", "ar", NOW) === null, "a call with a room in another format is ignored");
  ok(messagePush(msg({ kind: "call", body: "meet:" + ROOM }), "x", "ar", NOW).kind === "message", "a meeting link is a message, not a ringing call");
  ok(messagePush(msg({ sender_id: null, kind: "system" }), "x", "ar", NOW) === null, "system notes are not pushed");
}
{ // who gets it
  const { d, calls } = deps();
  await handle(hook("messages", msg({ sender_id: TUT })), d);
  ok(calls.sent.length === 1 && calls.sent[0].token === "tok-stu" && calls.sent[0].data.title === "سامر", "a tutor's message goes to the student");
  const { d: d2, calls: c2 } = deps();
  const r = await (await handle(hook("messages", msg({ sender_id: "99999999-9999-9999-9999-999999999999" })), d2)).json();
  ok(r.skipped && c2.sent.length === 0, "a sender who is not in the chat → nothing sent");
  const { d: d3, calls: c3 } = deps();
  await handle(hook("messages", msg({ conversation_id: "00000000-0000-0000-0000-000000000000" })), d3);
  ok(c3.sent.length === 0, "unknown chat → nothing sent");
  const { d: d4, calls: c4 } = deps();
  await handle(hook("messages", msg(), SECRET, "UPDATE"), d4);
  ok(c4.sent.length === 0, "only new rows (\"read\" ticks are not pushed)");
}
{ // switches
  ok(!allowed("message", { messages: false, calls: true, reminders: true }) && allowed("call", { messages: false, calls: true, reminders: true }), "messages off: calls still ring");
  ok(!allowed("call", { messages: true, calls: false, reminders: true }) && !allowed("missed_call", { messages: true, calls: false, reminders: true }), "calls off: no ringing and no missed-call notice");
  ok(!allowed("reminder", { messages: true, calls: true, reminders: false }), "reminders off");
  ok(allowed("general", { messages: false, calls: false, reminders: false }), "bookings / payments always go");
  const { d, calls } = deps({ prefs: async () => ({ messages: false, calls: true, reminders: true }) });
  const r = await (await handle(hook("messages", msg()), d)).json();
  ok(r.skipped === "turned off" && calls.sent.length === 0, "a person who turned messages off gets none");
}
{ // missed call, reminders, other notices
  const n = { id: 5, user_id: TUT, title: "Missed call", body: "ليان", data: { type: "missed_call", room: ROOM, conversation_id: CONV, video: true } };
  const p = notificationPush(n, "ar", NOW);
  ok(p.kind === "missed_call" && p.title === "مكالمة فائتة" && p.body === "من ليان" && p.data.room === ROOM && p.data.video === "true", "missed call: who called, which call");
  ok(notificationPush(n, "en", NOW).body === "From ليان", "… in English");
  const rem = (kind, at) => notificationPush({ id: 6, user_id: STU, title: "Lesson reminder", body: "Lesson #12 starts in 1 hour.",
    data: { type: "reminder", lesson_id: "L1", kind, starts_at: new Date(NOW + at * 60000).toISOString() } }, "ar", NOW);
  ok(rem("24h", 1440).body === "يبدأ درسك بعد 24 ساعة" && rem("24h", 1440).title === "تذكير بالدرس", "reminder 24 h, Arabic");
  ok(rem("1h", 60).body === "يبدأ درسك بعد ساعة", "reminder 1 h");
  ok(rem("10m", 9).body === "يبدأ درسك بعد 9 دقائق", "reminder 10 min (real minutes left)");
  ok(rem("1h", 30).body === "يبدأ درسك بعد 30 دقيقة", "a lesson booked late says the real time left");
  ok(startsIn("en", new Date(NOW + 60000).toISOString(), "10m", NOW) === "Your lesson starts in 1 minute", "English, one minute");
  ok(arMinutes(2) === "دقيقتين" && arMinutes(11) === "11 دقيقة", "Arabic number words");
  const g = notificationPush({ id: 8, user_id: STU, title: "Payment & booking confirmed", body: "Your payment was received.", data: { payment_id: "P1" } }, "ar", NOW);
  ok(g.kind === "general" && g.title === "تم تأكيد الدفع والحجز" && g.data.payment_id === "P1", "other notices: Arabic title, original details");
  const live = notificationPush({ id: 9, user_id: TUT, title: "Real time request!", body: "x", data: { live_request_id: "Q", urgent: true } }, "en", NOW);
  ok(live.urgent && live.title === "Real time request!", "live-help requests are high priority");
  const { d, calls } = deps();
  await handle(hook("notifications", n), d);
  ok(calls.sent.length === 2 && calls.sent.every((m) => m.data.type === "missed_call"), "a notification row goes to the person's phones");
  const { d: d2, calls: c2 } = deps({ prefs: async () => ({ messages: true, calls: true, reminders: false }) });
  await handle(hook("notifications", { id: 6, user_id: STU, title: "Lesson reminder", body: "x", data: { type: "reminder", kind: "1h" } }), d2);
  ok(c2.sent.length === 0, "reminders off → no reminder");
}
{ // old phones
  ok(deadToken(404, {}) && deadToken(400, { error: { message: "x", details: [{ errorCode: "UNREGISTERED" }] } }), "Firebase \"not registered\" → token is dead");
  ok(deadToken(400, { error: { message: "The registration token is not a valid FCM registration token", details: [{ errorCode: "INVALID_ARGUMENT" }] } }), "… or not a valid token");
  ok(!deadToken(500, {}) && !deadToken(429, {}) && !deadToken(400, { error: { message: "Invalid JSON payload", details: [{ errorCode: "INVALID_ARGUMENT" }] } }),
    "server busy / our own mistake → token kept");
  const { d, calls } = deps({ send: async (m) => (m.message.token === "tok-tutor-en" ? { status: 404, body: {} } : { status: 200, body: {} }) });
  const r = await (await handle(hook("messages", msg()), d)).json();
  ok(r.sent === 1 && calls.dropped.length === 1 && calls.dropped[0] === "tok-tutor-en", "a phone that removed the app is forgotten; the others still get it");
  const { d: d2 } = deps({ tokens: async () => [] });
  ok((await (await handle(hook("messages", msg()), d2)).json()).skipped === "no device", "no phone saved (old app / web) → nothing sent");
}

// Phone test 19 Nov 2026: the real missed-call row (call_not_answered) also carries "from" = the caller's id.
// Firebase refuses any message with that data key, so missed calls never arrived. Reserved keys are renamed.
{
  const row = { id: 9, user_id: TUT, title: "Missed call", body: "ليان", data: { type: "missed_call", room: ROOM, conversation_id: CONV, video: true, from: STU } };
  const p = notificationPush(row, "ar", NOW);
  const data = fcmMessage("t", p).message.data;
  ok(!("from" in data) && data.x_from === STU && data.type === "missed_call" && data.room === ROOM && data.conversation_id === CONV,
    "missed call: Firebase-reserved key \"from\" is sent as x_from, everything the phone reads is unchanged");
  const s = safeData({ from: "a", notification: "b", message_type: "c", collapse_key: "d", "google.x": "e", gcm_y: "f", Google: "g", room: "r", fromage: "h" });
  ok(Object.keys(s).sort().join(",") === "fromage,room,x_Google,x_collapse_key,x_from,x_gcm_y,x_google.x,x_message_type,x_notification",
    "every Firebase-reserved key is renamed; other keys (even ones starting with \"from\") stay");
  const strict = async (m) => {
    const bad = Object.keys(m.message.data).find((k) => /^(from|notification|message_type|collapse_key)$|^(google|gcm)/i.test(k));
    return bad ? { status: 400, body: { error: { message: `Invalid data payload key: ${bad}`, details: [{ errorCode: "INVALID_ARGUMENT" }] } } } : { status: 200, body: {} };
  };
  const { d, calls } = deps({ send: async (m) => { calls.sent.push(m.message); return strict(m); } });
  const r = await (await handle(hook("notifications", row), d)).json();
  ok(r.sent === 2 && calls.dropped.length === 0, "a missed call passes a Firebase that rejects reserved keys (both phones)");
}

if (failed) { console.log(failed + " FAILED"); process.exit(1); }
