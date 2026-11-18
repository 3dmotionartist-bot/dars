// Supabase Edge Function: turn-credentials (Stage 3 B2)
// Gives call relay (TURN) passwords that expire: 4 hours for signed-in users (active accounts, 30 an hour),
// 1 hour for guests on the browser call page (only for a recent Dars call room; 10 an hour per address,
// 20 an hour per room). The passwords come
// from Cloudflare Realtime TURN. If Cloudflare is not set up or not reachable, signed-in users get the
// current relay (call_ice_servers) so calls still connect; guests get direct connection only (as before).
//
// Setup (the owner, in the Supabase dashboard — never in chat):
//   1. Cloudflare dashboard → Realtime → TURN Server → Create → copy the "Turn Token ID" and "API Token".
//   2. Supabase → Edge Functions → Secrets: add CF_TURN_KEY_ID and CF_TURN_API_TOKEN with those values.
//   3. Deploy this function with "Verify JWT" OFF (guests have no account; the function checks tokens itself):
//        supabase functions deploy turn-credentials --no-verify-jwt
//      (config.toml has the same setting for the CLI.)
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { handle, type IceServer } from "./logic.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

Deno.serve((req) =>
  handle(req, {
    cfKeyId: Deno.env.get("CF_TURN_KEY_ID") ?? "",
    cfToken: Deno.env.get("CF_TURN_API_TOKEN") ?? "",
    fetch,
    userId: async (jwt) => {
      const { data, error } = await admin.auth.getUser(jwt);
      return error || !data?.user ? null : data.user.id;
    },
    userAllowed: async (uid) => {
      const { data, error } = await admin.rpc("turn_user_allowed", { p_user: uid });
      return !error && data === true;
    },
    guestAllowed: async (ip, room) => {
      const { data, error } = await admin.rpc("turn_guest_allowed", { p_ip: ip, p_room: room });
      return !error && data === true;
    },
    legacyIce: async (jwt) => {
      const asUser = createClient(url, anonKey, {
        auth: { persistSession: false },
        global: { headers: { Authorization: `Bearer ${jwt}` } },
      });
      const { data, error } = await asUser.rpc("call_ice_servers");
      return error || !Array.isArray(data) ? [] : (data as IceServer[]);
    },
  })
);
