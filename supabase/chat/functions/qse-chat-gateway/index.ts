// Quem Sou Eu V3 — T16A — CHAT gateway. Fonte de verdade: docs/backend/CHAT_API_V1.md
// Verify JWT = false: a identidade vem EXCLUSIVAMENTE do JWT do projeto GAME,
// verificado localmente via JWKS ou pelo endpoint /auth/v1/user do GAME.
import { withSupabase } from "jsr:@supabase/server@1";
import { createRemoteJWKSet, decodeProtectedHeader, jwtVerify } from "npm:jose@6.1.0";

const GAME_URL = (Deno.env.get("GAME_URL") ?? "").replace(/\/$/, "");
const GAME_KEY = Deno.env.get("GAME_PUBLISHABLE_KEY") ?? "";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_REQUEST_BYTES = 8192;
const MAX_MESSAGE_CHARS = 2000;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
  "Content-Type": "application/json",
};
const respond = (obj: unknown, status = 200): Response =>
  new Response(JSON.stringify(obj), { status, headers: cors });
const jwks = GAME_URL ? createRemoteJWKSet(new URL(`${GAME_URL}/auth/v1/.well-known/jwks.json`)) : null;

async function gameIdentity(token: string): Promise<string | null> {
  if (!jwks || !GAME_KEY || !GAME_URL || token.length > 8192) return null;
  try {
    const header = decodeProtectedHeader(token);
    if (header.alg === "RS256" || header.alg === "ES256") {
      const result = await jwtVerify(token, jwks, {
        issuer: `${GAME_URL}/auth/v1`, audience: "authenticated",
      });
      const id = result.payload.sub;
      return result.payload.role === "authenticated" && typeof id === "string" && UUID.test(id)
        ? id : null;
    }
    if (header.alg !== "HS256") return null;
  } catch {
    return null;
  }
  // Para tokens HS256 legados, a validação é feita no próprio GAME.
  const response = await fetch(`${GAME_URL}/auth/v1/user`, {
    headers: { apikey: GAME_KEY, Authorization: `Bearer ${token}` },
  }).catch(() => null);
  if (!response?.ok) return null;
  const user = await response.json().catch(() => null);
  return typeof user?.id === "string" && UUID.test(user.id) ? user.id : null;
}

// null = GAME indisponível, false = não é amigo ou há bloqueio em qualquer direção.
// RPC lê apenas índices do GAME; nenhuma lista de perfis ou nicknames.
async function canMessage(token: string, peerId: string): Promise<boolean | null> {
  const result = await fetch(`${GAME_URL}/rest/v1/rpc/qse_chat_can_message`, {
    method: "POST",
    headers: {
      apikey: GAME_KEY, Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ p_peer: peerId }),
  }).catch(() => null);
  if (!result?.ok) return null;
  const value = await result.json().catch(() => null);
  return typeof value?.allowed === "boolean" ? value.allowed : null;
}

// 16D: autorização pontual (SEM cache) no GAME para membro atual de sala;
// recusa sala encerrada, saída, kick, sala inexistente ou falha da rede.
async function canAccessRoom(token: string, roomId: string): Promise<boolean | null> {
  const response = await fetch(`${GAME_URL}/rest/v1/rpc/qse_duel_chat_access`, {
    method: "POST",
    headers: { apikey: GAME_KEY, Authorization: `Bearer ${token}`,
               "Content-Type": "application/json" },
    body: JSON.stringify({p_room:roomId}),
  }).catch(() => null);
  if (!response?.ok) return null;
  const value = await response.json().catch(() => null);
  return typeof value?.allowed === "boolean" ? value.allowed : null;
}

async function roomConversationId(roomId: string): Promise<string> {
  const raw = new TextEncoder().encode(`qse-room-v1:${roomId.toLowerCase()}`);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256",raw));
  hash[6] = (hash[6] & 15) | 0x80;
  hash[8] = (hash[8] & 63) | 0x80;
  const hex = [...hash.slice(0,16)].map(x=>x.toString(16).padStart(2,"0")).join("");
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

async function directId(a: string, b: string): Promise<string> {
  const raw = new TextEncoder().encode(`qse-direct-v1:${[a,b].sort().join(":")}`);
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", raw));
  hash[6] = (hash[6] & 15) | 0x80;
  hash[8] = (hash[8] & 63) | 0x80;
  const hex = [...hash.slice(0,16)].map(x => x.toString(16).padStart(2,"0")).join("");
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-${hex.slice(12,16)}-${hex.slice(16,20)}-${hex.slice(20)}`;
}

export default {
  fetch: withSupabase({ auth: "none" }, async (req, ctx) => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (req.method !== "POST") return respond({error:"method_not_allowed"},405);

    const bearer = req.headers.get("Authorization") ?? "";
    const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : "";
    if (!token) return respond({error:"unauthorized"},401);
    const userId = await gameIdentity(token);
    if (!userId) return respond({error:"unauthorized"},401);

    const contentLength = Number(req.headers.get("Content-Length") ?? "0");
    if (contentLength > MAX_REQUEST_BYTES) return respond({error:"payload_too_large"},413);
    // Verifica o tamanho REAL mesmo se Content-Length estiver ausente ou falsificado.
    const raw = await req.text().catch(() => "");
    if (new TextEncoder().encode(raw).byteLength > MAX_REQUEST_BYTES)
      return respond({error:"payload_too_large"},413);
    const payload = (() => { try { return JSON.parse(raw); } catch { return null; } })();
    if (!payload || typeof payload !== "object" || Array.isArray(payload))
      return respond({error:"invalid_json"},400);

    const db = ctx.supabaseAdmin; // service_role SÓ no servidor, nunca no Godot.
    const action = payload.action;
    if (typeof action !== "string") return respond({error:"invalid_action"},400);

    try {
      // Duelo: ligação efêmera a uma sala GAME existente, sem espelhar membros.
      if (action === "open_room") {
        const roomId = payload.room_id;
        if (typeof roomId !== "string" || !UUID.test(roomId))
          return respond({error:"invalid_room"},400);
        const permitted = await canAccessRoom(token,roomId);
        if (permitted === null) return respond({error:"game_unavailable"},503);
        if (!permitted) return respond({error:"room_access_denied"},403);
        const id = await roomConversationId(roomId);
        const {error} = await db.from("qse_chat_conversations").upsert(
          {id,kind:"room",game_room_id:roomId,created_by_game_user_id:userId},
          {onConflict:"id",ignoreDuplicates:true},
        );
        if (error) throw error;
        return respond({conversation_id:id});
      }

      if (action === "open_direct") {
        const peerId = payload.peer_id;
        if (typeof peerId !== "string" || !UUID.test(peerId) || peerId === userId)
          return respond({error:"invalid_peer"},400);
        const allowed = await canMessage(token, peerId);
        if (allowed === null) return respond({error:"game_unavailable"},503);
        if (!allowed) return respond({error:"friend_required"},403);

        const id = await directId(userId, peerId);
        const { error: roomError } = await db.from("qse_chat_conversations").upsert(
          { id, kind: "direct", created_by_game_user_id: userId },
          { onConflict: "id", ignoreDuplicates: true },
        );
        if (roomError) throw roomError;
        const { error: memberError } = await db.from("qse_chat_members").upsert(
          [ { conversation_id:id, game_user_id:userId },
            { conversation_id:id, game_user_id:peerId } ],
          { onConflict:"conversation_id,game_user_id", ignoreDuplicates:true },
        );
        if (memberError) throw memberError;
        return respond({conversation_id:id});
      }

      if (action === "list") {
        const {data: members,error:memberError} = await db.from("qse_chat_members")
          .select("conversation_id").eq("game_user_id",userId).limit(50);
        if (memberError) throw memberError;
        const ids = (members ?? []).map((m:{conversation_id:string}) => m.conversation_id);
        if (!ids.length) return respond({conversations:[]});
        const {data:rooms,error:roomError} = await db.from("qse_chat_conversations")
          .select("id,kind,created_at").in("id",ids)
          .order("created_at",{ascending:false});
        if (roomError) throw roomError;
        return respond({conversations:rooms ?? []});
      }

      if (action === "messages" || action === "send") {
        const id = payload.conversation_id;
        if (typeof id !== "string" || !UUID.test(id))
          return respond({error:"invalid_conversation"},400);

        // Chat da sala usa o MESMO messages/send e request_id do privado.
        // A autorização é refeita em TODA leitura e envio; o CHAT não armazena membros da sala.
        const {data:room,error:roomError} = await db.from("qse_chat_conversations")
          .select("kind,game_room_id").eq("id",id).maybeSingle();
        if (roomError) throw roomError;
        if (room?.kind === "room") {
          if (typeof room.game_room_id !== "string" || !UUID.test(room.game_room_id))
            return respond({error:"room_access_denied"},403);
          const permitted = await canAccessRoom(token,room.game_room_id);
          if (permitted === null) return respond({error:"game_unavailable"},503);
          if (!permitted) return respond({error:"room_access_denied"},403);
          if (action === "messages") {
            const {data,error} = await db.rpc("qse_chat_room_read",{
              p_user_id:userId,p_conversation_id:id,p_limit:50,
            });
            if (error) throw error;
            if (data?.error) return respond({error:data.error},403);
            return respond({messages:data?.messages ?? []});
          }
          const requestId = payload.request_id;
          const body = typeof payload.body === "string" ? payload.body.trim() : "";
          if (typeof requestId !== "string" || !UUID.test(requestId))
            return respond({error:"invalid_request_id"},400);
          if (!body.length || [...body].length > MAX_MESSAGE_CHARS)
            return respond({error:"invalid_body"},400);
          const {data,error} = await db.rpc("qse_chat_room_send",{
            p_sender:userId,p_conversation_id:id,p_request_id:requestId,p_body:body,
          });
          if (error) throw error;
          if (data?.error) return respond({error:data.error},
            data.error === "rate_limited" ? 429 :
            data.error === "idempotency_conflict" ? 409 :
            data.error === "forbidden" ? 403 : 400);
          return respond({message:data.message,duplicate:data.duplicate === true});
        }

        // Verifica ambos os integrantes no CHAT, evitando identidade fornecida pelo cliente.
        const {data:members,error:membersError} = await db.from("qse_chat_members")
          .select("game_user_id").eq("conversation_id",id).limit(3);
        if (membersError) throw membersError;
        if (!members || members.length !== 2 ||
            !members.some((m:{game_user_id:string})=>m.game_user_id === userId))
          return respond({error:"forbidden"},403);
        const peerId = members.find((m:{game_user_id:string})=>m.game_user_id !== userId)?.game_user_id;
        if (!peerId) return respond({error:"forbidden"},403);

        // Sem cache de autorização positiva: remoção de amizade e bloqueio negam o próximo envio.
        const allowed = await canMessage(token,peerId);
        if (allowed === null) return respond({error:"game_unavailable"},503);
        if (!allowed) return respond({error:"friend_required"},403);

        if (action === "messages") {
          const {data,error} = await db.rpc("qse_chat_read",{
            p_user_id:userId,p_conversation_id:id,p_limit:50
          });
          if (error) throw error;
          if (data?.error) return respond({error:data.error},403);
          return respond({messages:data?.messages ?? []});
        }
        const requestId = payload.request_id;
        const body = typeof payload.body === "string" ? payload.body.trim() : "";
        if (typeof requestId !== "string" || !UUID.test(requestId))
          return respond({error:"invalid_request_id"},400);
        if (body.length === 0 || [...body].length > MAX_MESSAGE_CHARS)
          return respond({error:"invalid_body"},400);

        const {data,error} = await db.rpc("qse_chat_send",{
          p_sender:userId,p_conversation_id:id,p_request_id:requestId,p_body:body
        });
        if (error) throw error;
        if (data?.error) return respond({error:data.error},
          data.error === "rate_limited" ? 429 :
          data.error === "idempotency_conflict" ? 409 :
          data.error === "forbidden" ? 403 : 400);
        return respond({message:data.message,duplicate:data.duplicate === true});
      }

      return respond({error:"invalid_action"},400);
    } catch (err) {
      console.error("qse-chat-gateway:",err instanceof Error ? err.message : "backend_error");
      return respond({error:"backend_unavailable"},503);
    }
  }),
};
