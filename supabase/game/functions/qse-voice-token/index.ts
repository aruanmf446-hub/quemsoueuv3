import { AccessToken, RoomServiceClient } from "npm:livekit-server-sdk@2.19.2";
import { withSupabase } from "npm:@supabase/server@1";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const response = (payload: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(payload), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const livekitRoom = (id: string) => "qse-voice-" + id.toLowerCase();
async function memberIdentity(room: string, user: string): Promise<string> {
  const bytes = new TextEncoder().encode("qse-room-member-v1:" + room + ":" + user);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map(n => n.toString(16).padStart(2, "0")).join("");
}

const handler = withSupabase({ auth: "user" }, async (request, context) => {
  if (request.method !== "POST") return response({ code: "method_not_allowed" }, 405);
  const userId = context.userClaims?.id;
  if (!userId || !uuid.test(userId)) return response({ code: "unauthorized" }, 401);

  let input: Record<string, unknown>;
  try {
    input = await request.json();
    if (!input || Array.isArray(input) || typeof input !== "object") throw Error("invalid_json");
  } catch {
    return response({ code: "invalid_json" }, 400);
  }
  const roomId = typeof input.room_id === "string" ? input.room_id.toLowerCase() : "";
  const action = input.action === "disconnect" ? "disconnect" : input.action === "sync" ? "sync" : input.action === undefined || input.action === "token" ? "token" : "unknown";
  if (!uuid.test(roomId) || action === "unknown") return response({ code: "invalid_request" }, 400);

  const endpoint = Deno.env.get("LIVEKIT_URL") ?? "";
  const key = Deno.env.get("LIVEKIT_API_KEY") ?? "";
  const secret = Deno.env.get("LIVEKIT_API_SECRET") ?? "";
  if (!/^wss:\/\/[a-z0-9.-]+\.livekit\.cloud\/?$/i.test(endpoint) || !key || !secret) {
    return response({ code: "voice_not_configured" }, 503);
  }
  const roomName = livekitRoom(roomId);
  const identity = await memberIdentity(roomId, userId);
  const admin = new RoomServiceClient(endpoint.replace(/^wss:/, "https:").replace(/\/$/, ""), key, secret);

  // Voluntary disconnect remains possible immediately after leaving the GAME lobby.
  if (action === "disconnect") {
    try { await admin.removeParticipant(roomName, identity); } catch { /* already disconnected */ }
    return response({ ok: true });
  }

  // The client-provided room_id never authorizes membership.
  const { data, error } = await context.supabase.rpc("qse_duel_chat_access", { p_room: roomId });
  if (error) return response({ code: "game_unavailable" }, 503);
  if (!data || data.allowed !== true) return response({ code: "room_access_denied" }, 403);
  const members = Array.isArray(data.participants) ? data.participants : [];
  const roster = members
    .filter((m: { tag?: unknown }) => m && typeof m.tag === "string" && /^[a-f0-9]{64}$/.test(m.tag))
    .map((m: { tag: string; nickname?: unknown }) => ({
      tag: m.tag,
      nickname: typeof m.nickname === "string" ? m.nickname.slice(0, 80) : "Jogador",
    }));
  const allowed = new Set(roster.map((m: { tag: string }) => m.tag));
  if (!allowed.has(identity)) return response({ code: "room_access_denied" }, 403);

  // LiveKit auto-creates a room on the FIRST participant connection. Calling
  // listParticipants on a non-existent room produces an API error and must not
  // block the very first authorized player from receiving a joining token.
  // Room listing is also an authenticated service call: fail closed on outages.
  if (action === "sync" || action === "token") {
    try {
      const rooms = await admin.listRooms([roomName]);
      if (rooms.some((room) => room.name === roomName)) {
        try {
          const present = await admin.listParticipants(roomName);
          for (const participant of present) {
            if (participant.identity && !allowed.has(participant.identity)) {
              await admin.removeParticipant(roomName, participant.identity);
            }
          }
        } catch (e) {
          // A room can disappear between listRooms and listParticipants when its
          // last participant leaves. Only the structured not_found code is safe.
          const code = typeof e === "object" && e !== null && "code" in e
            ? String(e.code) : "";
          if (code !== "not_found" && code !== "404") throw e;
        }
      }
    } catch (e) {
      const code = typeof e === "object" && e !== null && "code" in e
        ? String(e.code).slice(0, 32) : "unknown";
      const status = typeof e === "object" && e !== null && "status" in e
        ? Number(e.status) : 0;
      // No message, URL, key or token in logs.
      console.error("qse-voice LiveKit maintenance error", {
        code: /^[a-z0-9_]{1,32}$/i.test(code) ? code : "unknown",
        status: Number.isInteger(status) && status >= 100 && status <= 599 ? status : 0,
      });
      return response({ code: "voice_reconciliation_unavailable" }, 503);
    }
  }
  if (action === "sync") return response({ ok: true, participants: roster });

  const token = new AccessToken(key, secret, {
    identity,
    ttl: "2m",
  });
  token.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishSources: ["microphone"],
    canPublishData: false,
    roomAdmin: false,
  });
  return response({
    room: roomName,
    server_url: endpoint.replace(/\/$/, ""),
    participant_token: await token.toJwt(),
    participants: roster,
  });
});

Deno.serve((request: Request) => request.method === "OPTIONS"
  ? new Response(null, { status: 204, headers: cors })
  : handler(request));
