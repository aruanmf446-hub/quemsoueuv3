// T32 — LiveKit room tokens, issued only after GAME authorization.
// Never place LiveKit API credentials in the Godot or web client.
import { AccessToken, RoomServiceClient, TrackSource } from "npm:livekit-server-sdk@2.19.2";
import { withSupabase } from "npm:@supabase/server@1";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TAG = /^[a-f0-9]{64}$/;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
  "Content-Type": "application/json",
};

const response = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), { status, headers: CORS });

type Member = { tag: string; member_id: string; nickname: string };
type Access = { allowed: boolean; participants?: Member[] };

async function identityTag(roomId: string, userId: string): Promise<string> {
  // Exactly the same pseudonymous scheme as qse_duel_chat_access (T16D).
  const input = new TextEncoder().encode(
    "qse-room-member-v1:" + roomId.toLowerCase() + ":" + userId.toLowerCase(),
  );
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", input));
  return [...digest].map((value) => value.toString(16).padStart(2, "0")).join("");
}

function serverConfig() {
  const url = Deno.env.get("LIVEKIT_URL")?.trim() ?? "";
  const key = Deno.env.get("LIVEKIT_API_KEY")?.trim() ?? "";
  const secret = Deno.env.get("LIVEKIT_API_SECRET")?.trim() ?? "";
  // Only allow wss LiveKit endpoints, never an arbitrary host supplied by a caller.
  if (!/^wss:\/\/[a-z0-9.-]+\.livekit\.cloud\/?$/i.test(url) || !key || !secret) {
    return null;
  }
  return { url: url.replace(/\/$/, ""), key, secret };
}

const handler = withSupabase({ auth: "user" }, async (req, ctx) => {
  if (req.method !== "POST") return response({ code: "method_not_allowed" }, 405);
  const userId = ctx.userClaims?.id;
  if (typeof userId !== "string" || !UUID.test(userId)) {
    return response({ code: "unauthorized" }, 401);
  }

  const length = Number(req.headers.get("content-length") ?? 0);
  if (length > 2048) return response({ code: "invalid_request" }, 413);
  const body = await req.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return response({ code: "invalid_request" }, 400);
  }
  const roomId = typeof body.room_id === "string" ? body.room_id.toLowerCase() : "";
  const action = body.action ?? "join";
  if (!UUID.test(roomId) || !["join", "leave", "reconcile"].includes(action)) {
    return response({ code: "invalid_request" }, 400);
  }

  const config = serverConfig();
  if (!config) {
    console.error("qse-voice-token: LIVEKIT_CONFIG_MISSING");
    return response({ code: "voice_unavailable" }, 503);
  }

  const roomName = "qse-v3-" + roomId;
  const tag = await identityTag(roomId, userId);
  const api = new RoomServiceClient(
    config.url.replace(/^wss:/, "https:"),
    config.key,
    config.secret,
  );

  // A former participant may still leave/revoke their own token after leaving GAME.
  // The identity is always derived from the authenticated user, never from the body.
  if (action === "leave") {
    try {
      await api.removeParticipant(roomName, tag);
    } catch {
      // Empty rooms or already-disconnected participants are normal.
    }
    return response({ ok: true });
  }

  // GAME is the only authorization authority. This RPC checks active room,
  // membership, spectator role and kicks using the JWT/RLS of this exact user.
  const { data, error } = await ctx.supabase.rpc("qse_duel_chat_access", {
    p_room: roomId,
  });
  if (error || !data || typeof data.allowed !== "boolean") {
    console.warn("qse-voice-token: GAME_ROOM_ACCESS_UNAVAILABLE");
    return response({ code: "game_unavailable" }, 503);
  }
  const access = data as Access;
  const members = Array.isArray(access.participants)
    ? access.participants.filter((member) => member && TAG.test(member.tag))
    : [];
  if (!access.allowed || !members.some((member) => member.tag === tag)) {
    return response({ code: "room_access_denied" }, 403);
  }

  // Reconcile actual LiveKit participants with GAME membership. During an
  // ongoing room, each connected client calls this periodically. Removes
  // players who have left or been kicked, revoking their connection tokens.
  if (action === "reconcile") {
    const allowedTags = new Set(members.map((member) => member.tag));
    let removed = 0;
    try {
      // LiveKit creates a room when the first participant connects. A room
      // without connected participants is not an error or a reason to deny
      // membership in the GAME room.
      const liveRooms = await api.listRooms([roomName]);
      if (liveRooms.some((liveRoom) => liveRoom.name === roomName)) {
        const connected = await api.listParticipants(roomName);
        for (const participant of connected) {
          if (!allowedTags.has(participant.identity)) {
            await api.removeParticipant(roomName, participant.identity);
            removed++;
          }
        }
      }
    } catch (e) {
      // Do not expose credentials, token, room IDs, or external error messages.
      const code = typeof e === "object" && e !== null && "code" in e
        ? String(e.code) : "unknown";
      console.warn("qse-voice-token: LIVEKIT_RECONCILE_ERROR", {
        code: /^[A-Za-z0-9_-]{1,32}$/.test(code) ? code : "unknown",
      });
      return response({ code: "voice_unavailable" }, 503);
    }
    return response({
      ok: true,
      removed,
      participants: members.map((member) => ({ tag: member.tag, nickname: member.nickname })),
    });
  }

  // A short-lived, microphone-only token. Token TTL is *not* active-session
  // revocation; the reconcile/removeParticipant path handles live disconnects.
  const token = new AccessToken(config.key, config.secret, {
    identity: tag,
    ttl: "2m",
  });
  token.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    // The SDK expects TrackSource enum values; a plain "microphone" string makes
    // toJwt() throw ("Cannot convert TrackSource microphone to string").
    canPublishSources: [TrackSource.MICROPHONE],
    canPublishData: false,
    roomAdmin: false,
  });

  let participantToken = "";
  try {
    participantToken = await token.toJwt();
  } catch (e) {
    console.error("qse-voice-token: TOKEN_SIGN_FAILED", {
      kind: e instanceof Error ? e.name : "unknown",
    });
    return response({ code: "voice_unavailable" }, 503);
  }

  return response({
    server_url: config.url,
    participant_token: participantToken,
    room: roomName,
    participants: members.map((member) => ({ tag: member.tag, nickname: member.nickname })),
    expires_in: 120,
  });
});

Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS });
  }
  return handler(req);
});
