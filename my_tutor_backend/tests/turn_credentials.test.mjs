// Tests for the turn-credentials edge function's decisions (Stage 3 B2), with fake Cloudflare / Supabase.
// Run: node --experimental-strip-types tests/turn_credentials.test.mjs   (Node 22.6+; part of tests/run.sh)
import { handle, TTL_GUEST, TTL_USER } from "../supabase/functions/turn-credentials/logic.ts";

let failed = 0;
const ok = (cond, label) => {
  if (cond) console.log("ok   " + label);
  else { failed++; console.log("FAIL " + label); }
};

const USER_JWT = "eyJhbGciOi.user.sig";
const ROOM = "kqzpt-mwhra-bcdeg-xyzab";
const CF_REPLY = {
  iceServers: [
    { urls: ["stun:stun.cloudflare.com:3478", "stun:stun.cloudflare.com:53"] },
    {
      urls: ["turn:turn.cloudflare.com:3478?transport=udp", "turn:turn.cloudflare.com:53?transport=udp", "turns:turn.cloudflare.com:443?transport=tcp"],
      username: "u1", credential: "c1",
    },
  ],
};

function deps(over = {}) {
  const calls = { cf: [], guest: [], legacy: 0 };
  const d = {
    cfKeyId: "key-id", cfToken: "api-token",
    fetch: async (url, init) => {
      calls.cf.push({ url, init, body: JSON.parse(init.body) });
      return new Response(JSON.stringify(CF_REPLY), { status: 201 });
    },
    userId: async (jwt) => (jwt === USER_JWT ? "user-1" : null),
    userAllowed: async (uid) => { calls.user = (calls.user ?? 0) + 1; return uid === "user-1"; },
    guestAllowed: async (ip, room) => { calls.guest.push([ip, room]); return true; },
    legacyIce: async () => { calls.legacy++; return [{ urls: ["turn:old.relay:80"], username: "old", credential: "old" }]; },
    ...over,
  };
  return { d, calls };
}
const req = (opts = {}) => new Request("https://x.supabase.co/functions/v1/turn-credentials", {
  method: opts.method ?? "POST",
  headers: { "content-type": "application/json", "x-forwarded-for": opts.ip ?? "10.9.9.9, 203.0.113.7", ...(opts.cf ? { "cf-connecting-ip": opts.cf } : {}), ...(opts.auth ? { authorization: "Bearer " + opts.auth } : {}) },
  body: (opts.method ?? "POST") === "POST" ? JSON.stringify(opts.body ?? {}) : undefined,
});
const urlsOf = (list) => list.flatMap((s) => (Array.isArray(s.urls) ? s.urls : [s.urls]));

{ // preflight
  const r = await handle(new Request("https://x/f", { method: "OPTIONS" }), deps().d);
  ok(r.status === 204 && r.headers.get("access-control-allow-headers").includes("apikey"), "browser preflight is answered (call page on another site)");
}
{ // signed-in user
  const { d, calls } = deps();
  const r = await handle(req({ auth: USER_JWT }), d);
  const j = await r.json();
  ok(r.status === 200 && j.source === "cloudflare", "signed-in user gets Cloudflare relay passwords");
  ok(calls.cf[0].body.ttl === TTL_USER && TTL_USER === 4 * 3600, "… valid for 4 hours (longer than the longest lesson)");
  ok(calls.user === 1, "… after the account / 30-an-hour check");
  ok(calls.cf[0].url.endsWith("/v1/turn/keys/key-id/credentials/generate-ice-servers") && calls.cf[0].init.headers.Authorization === "Bearer api-token",
    "… asked from Cloudflare's generate-ice-servers with the owner's key and token");
  ok(!urlsOf(j.iceServers).some((u) => /:53\b/.test(u)), "… without port 53 (browsers block it)");
  ok(urlsOf(j.iceServers).some((u) => u.startsWith("turns:")) && j.iceServers.some((s) => s.username === "u1"), "… with the relay addresses and the short-lived password");
  ok(calls.guest.length === 0 && calls.legacy === 0, "… no room check or old relay needed");
}
{ // blocked account or over 30 an hour
  const { d, calls } = deps({ userAllowed: async () => false });
  const r = await handle(req({ auth: USER_JWT }), d);
  ok(r.status === 403 && calls.cf.length === 0 && calls.legacy === 0, "blocked account / over 30 an hour → refused, no relay at all");
}
{ // which address is counted
  const { d, calls } = deps();
  await handle(req({ body: { room: ROOM }, cf: "198.51.100.9", ip: "1.1.1.1, 198.51.100.9" }), d);
  ok(calls.guest[0][0] === "198.51.100.9", "the address Cloudflare sets (cf-connecting-ip) is counted, not what the caller wrote");
  await handle(req({ body: { room: ROOM }, ip: "6.6.6.6, 203.0.113.7" }), d);
  ok(calls.guest[1][0] === "203.0.113.7", "without it, only the LAST x-forwarded-for value (added by the proxy) is used");
  await handle(req({ body: { room: ROOM }, ip: "6.6.6.6, 203.0.113.7", cf: "203.0.113.7" }), d);
  await handle(req({ body: { room: ROOM }, ip: "7.7.7.7, 203.0.113.7", cf: "203.0.113.7" }), d);
  ok(calls.guest[2][0] === calls.guest[3][0], "a spoofed x-forwarded-for does not change the counted address");
}
{ // Cloudflare down
  const { d, calls } = deps({ fetch: async () => new Response("err", { status: 500 }) });
  const j = await (await handle(req({ auth: USER_JWT }), d)).json();
  ok(j.source === "fallback" && calls.legacy === 1 && urlsOf(j.iceServers).includes("turn:old.relay:80"), "Cloudflare failing → the current relay (call_ice_servers), calls still connect");
}
{ // not set up yet
  let fetched = 0;
  const { d } = deps({ cfKeyId: "", cfToken: "", fetch: async () => { fetched++; return new Response("{}"); } });
  const j = await (await handle(req({ auth: USER_JWT }), d)).json();
  ok(j.source === "fallback" && fetched === 0, "secrets not typed in yet → old relay, Cloudflare not asked");
}
{ // Cloudflare hangs
  const { d } = deps({ fetch: (url, init) => new Promise((_, no) => init.signal.addEventListener("abort", () => no(new Error("aborted")))) });
  const t = Date.now();
  const j = await (await handle(req({ auth: USER_JWT }), d)).json();
  ok(j.source === "fallback" && Date.now() - t < 6000, "Cloudflare not answering → old relay after about 4 s");
}
{ // guest with a real room
  const { d, calls } = deps();
  const r = await handle(req({ body: { room: ROOM } }), d);
  const j = await r.json();
  ok(r.status === 200 && j.source === "cloudflare" && calls.cf[0].body.ttl === TTL_GUEST && TTL_GUEST === 3600, "guest with a real call room → relay passwords valid 1 hour");
  ok(calls.guest[0][0] === "203.0.113.7" && calls.guest[0][1] === ROOM, "… after the room / address / per-room check");
  ok(calls.legacy === 0, "… never the old permanent relay password");
}
{ // guest, bad room
  const { d, calls } = deps();
  const r = await handle(req({ body: { room: "voice:0944555666" } }), d);
  ok(r.status === 403 && calls.guest.length === 0 && calls.cf.length === 0, "guest with a room in another format → refused (403)");
  const r2 = await handle(req({ body: {} }), d);
  ok(r2.status === 403, "guest with no room → refused");
}
{ // guest refused by the database (made-up room or 11th in an hour)
  const { d, calls } = deps({ guestAllowed: async () => false });
  const r = await handle(req({ body: { room: ROOM } }), d);
  const j = await r.json();
  ok(r.status === 403 && calls.cf.length === 0 && urlsOf(j.iceServers).every((u) => u.startsWith("stun:")), "made-up room / over the hourly limit → refused, no relay");
}
{ // tokens that are not a user's
  const { d, calls } = deps();
  const r = await handle(req({ auth: "sb_publishable_xyz" }), d);
  ok(r.status === 403 && calls.cf.length === 0, "the public site key alone is not a signed-in user");
  const r2 = await handle(req({ auth: "eyJexpired.token.sig" }), d);
  ok(r2.status === 403, "an expired / forged sign-in token is treated as a guest (refused without a room)");
}
{ // room in the query string (GET)
  const { d } = deps();
  const r = await handle(new Request("https://x/f?room=" + ROOM, { method: "GET", headers: { "x-forwarded-for": "198.51.100.2" } }), d);
  ok(r.status === 200, "GET ?room=… works too");
}

if (failed) { console.log(failed + " FAILED"); process.exit(1); }
