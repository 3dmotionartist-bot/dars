// turn-credentials: the decisions, kept free of Deno / Supabase so they can be tested anywhere
// (tests/turn_credentials.test.mjs). index.ts wires them to the real services.

export type IceServer = { urls: string | string[]; username?: string; credential?: string };

/** Rooms the app makes: four groups of five letters (no i, l, o, no digits). */
export const ROOM_RE = /^[a-hjkmnp-z]{5}(-[a-hjkmnp-z]{5}){3}$/;
// Signed-in users: 4 hours — longer than the longest lesson (3 hours), so a reconnect late in a lesson still works.
export const TTL_USER = 4 * 60 * 60;
export const TTL_GUEST = 60 * 60; // guests on the browser call page: 1 hour
export const STUN: IceServer = { urls: ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"] };

export const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

export type Deps = {
  cfKeyId: string; // Supabase secret CF_TURN_KEY_ID (typed in by the owner)
  cfToken: string; // Supabase secret CF_TURN_API_TOKEN (typed in by the owner)
  fetch: typeof fetch;
  userId: (jwt: string) => Promise<string | null>; // null = not a signed-in user's token
  userAllowed: (uid: string) => Promise<boolean>; // turn_user_allowed(): active account, 30 an hour
  guestAllowed: (ip: string, room: string) => Promise<boolean>; // turn_guest_allowed(): real room, 10 an hour
  legacyIce: (jwt: string) => Promise<IceServer[]>; // call_ice_servers (current relay) for signed-in users
};

/** The caller's address, from the headers the platform sets — never from ones the caller can write.
 * Supabase is reached through Cloudflare, which sets cf-connecting-ip itself (a copy sent by the caller is
 * replaced). x-forwarded-for is NOT trusted as a whole: a caller can send his own, and the proxies only add
 * the real address at the END — so only its last value is used, and only when cf-connecting-ip is missing. */
export function clientIp(h: Headers): string {
  const cf = (h.get("cf-connecting-ip") ?? "").trim();
  if (cf) return cf.slice(0, 64);
  const parts = (h.get("x-forwarded-for") ?? "").split(",").map((x) => x.trim()).filter(Boolean);
  return (parts.length ? parts[parts.length - 1] : "").slice(0, 64);
}

/** Browsers block port 53, so those relay addresses would only make the call wait. */
export function withoutPort53(list: IceServer[]): IceServer[] {
  const out: IceServer[] = [];
  for (const s of list) {
    const urls = (Array.isArray(s.urls) ? s.urls : [s.urls]).filter((u) => !/:53(\?|$)/.test(u));
    if (urls.length) out.push({ ...s, urls });
  }
  return out;
}

/** Short-lived relay credentials from Cloudflare Realtime TURN; null if not set up or not reachable. */
export async function cloudflareIce(d: Deps, ttl: number): Promise<IceServer[] | null> {
  if (!d.cfKeyId || !d.cfToken) return null;
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 4000);
  try {
    const r = await d.fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(d.cfKeyId)}/credentials/generate-ice-servers`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${d.cfToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({ ttl }),
        signal: ctl.signal,
      },
    );
    if (!r.ok) return null;
    const j = await r.json();
    const list = withoutPort53(Array.isArray(j?.iceServers) ? j.iceServers : j?.iceServers ? [j.iceServers] : []);
    return list.some((s) => (Array.isArray(s.urls) ? s.urls : [s.urls]).some((u) => u.startsWith("turn"))) ? list : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

export async function handle(req: Request, d: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST" && req.method !== "GET") return json(405, { error: "method" });

  let room = new URL(req.url).searchParams.get("room") ?? "";
  if (req.method === "POST") {
    try {
      const b = await req.json();
      if (typeof b?.room === "string") room = b.room;
    } catch { /* no body */ }
  }
  room = room.trim().toLowerCase();

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  const uid = jwt && jwt.startsWith("eyJ") ? await d.userId(jwt).catch(() => null) : null;

  if (uid) {
    // Blocked accounts and more than 30 requests an hour are refused.
    if (!(await d.userAllowed(uid).catch(() => false))) return json(403, { error: "not allowed", iceServers: [STUN] });
    const cf = await cloudflareIce(d, TTL_USER);
    if (cf) return json(200, { iceServers: cf, source: "cloudflare", ttl: TTL_USER });
    // Cloudflare not set up / not reachable: the current relay, so calls still connect.
    const old = await d.legacyIce(jwt).catch(() => [] as IceServer[]);
    return json(200, { iceServers: [STUN, ...old], source: "fallback", ttl: 0 });
  }

  // Guest (browser call page, no account): only for a real Dars call room, at most 10 an hour per address.
  const ip = clientIp(req.headers);
  if (!ROOM_RE.test(room) || !ip || !(await d.guestAllowed(ip, room).catch(() => false))) {
    return json(403, { error: "not allowed", iceServers: [STUN] });
  }
  const cf = await cloudflareIce(d, TTL_GUEST);
  if (cf) return json(200, { iceServers: cf, source: "cloudflare", ttl: TTL_GUEST });
  return json(200, { iceServers: [STUN], source: "fallback", ttl: 0 }); // guests never got the old relay
}
