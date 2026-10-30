class_name ChatGateway
extends Node
## Transporte real do CHAT: Edge Function qse-chat-gateway (contrato docs/backend/CHAT_API_V1.md,
## Tarefa 16A). Ações: open_direct, messages, send (list não é usada pela tela).
## apikey = chave publicável do CHAT; Authorization = token da sessão GAME (lido a cada chamada,
## nunca guardado). A identidade do remetente vem do token verificado no servidor.

const PATH := "/functions/v1/qse-chat-gateway"
const RETENTION := 24 * 3600.0
const TIMEOUT := 15.0
var chat_client: SupabaseClient
var game_client: SupabaseClient


func open_conversation(friend_id: String) -> Dictionary:
	var result := await _post({"action": "open_direct", "peer_id": friend_id})
	if not result.ok: return result
	var id := str((result.data as Dictionary).get("conversation_id", ""))
	return ServiceResult.success({"conversation_id": id}) if not id.is_empty() else ServiceResult.failure("invalid_contract")


## O servidor devolve as últimas 50 válidas (mais recentes primeiro), sem paginação.
func list_messages(conversation_id: String, _after: Variant = null) -> Dictionary:
	var result := await _post({"action": "messages", "conversation_id": conversation_id})
	if not result.ok: return result
	var rows: Variant = (result.data as Dictionary).get("messages")
	if not rows is Array: return ServiceResult.failure("invalid_contract")
	var messages: Array = []
	for row: Variant in rows:
		if not row is Dictionary or not row.get("id") is String or not row.get("body") is String: continue
		var sent := _time(str(row.get("sent_at", "")))
		var message := {"id": row.id, "sender_id": str(row.get("sender_game_user_id", "")), "text": row.body,
			"created_at": sent, "expires_at": sent + RETENTION}
		# Sala (gateway v5): nome e membro do remetente, sem UUID privado do jogador.
		if row.has("is_you"):
			message.is_you = bool(row.is_you)
			message.sender_name = str(row.get("sender_name", "Participante")) if row.get("sender_name") is String else "Participante"
			message.sender_member_id = str(row.get("sender_member_id", "")) if row.get("sender_member_id") is String else ""
		messages.append(message)
	return ServiceResult.success({"messages": messages, "complete": true})


## Chat da sala do Duelo (DUEL_ROOM_CHAT_API_V1): o GAME confirma que o jogador ainda é
## membro da sala em toda abertura, leitura e envio.
func open_room(room_id: String) -> Dictionary:
	var result := await _post({"action": "open_room", "room_id": room_id})
	if not result.ok: return result
	var id := str((result.data as Dictionary).get("conversation_id", ""))
	return ServiceResult.success({"conversation_id": id}) if not id.is_empty() else ServiceResult.failure("invalid_contract")


## request_id: o mesmo em reenvios da mesma intenção (o servidor não duplica).
func send_message(conversation_id: String, request_id: String, text: String, me_id: String = "") -> Dictionary:
	var result := await _post({"action": "send", "conversation_id": conversation_id, "request_id": request_id, "body": text})
	if not result.ok: return result
	var message: Variant = (result.data as Dictionary).get("message")
	if not message is Dictionary or not message.get("id") is String: return ServiceResult.failure("invalid_contract")
	var sent := _time(str(message.get("sent_at", "")))
	return ServiceResult.success({"message": {"id": message.id, "sender_id": me_id, "is_you": true, "text": text,
		"created_at": sent, "expires_at": sent + RETENTION}})


func _post(body: Dictionary) -> Dictionary:
	if chat_client == null or not chat_client.configured(): return ServiceResult.failure("chat_unavailable", "offline")
	var token := game_client.access_token if game_client != null else ""
	if token.is_empty(): return ServiceResult.failure("not_authenticated", "unauthorized")
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.body_size_limit = 262144
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + chat_client.publishable_key,
		"Authorization: Bearer " + token])
	if http.request(chat_client.endpoint + PATH, headers, HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		http.queue_free()
		return ServiceResult.failure("network", "offline")
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] == HTTPRequest.RESULT_TIMEOUT: return ServiceResult.failure("timeout", "offline")
	if response[0] != HTTPRequest.RESULT_SUCCESS: return ServiceResult.failure("network", "offline")
	var data: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	var status := int(response[1])
	if status >= 200 and status < 300 and data is Dictionary and not data.has("error"): return ServiceResult.success(data)
	var code := str(data.get("error", "")) if data is Dictionary else ""
	return ServiceResult.failure(code_for(code, status))


## Códigos do gateway -> códigos do jogo (mensagens curtas em ChatService.message_for).
static func code_for(code: String, status: int) -> String:
	match code:
		"unauthorized": return "not_authenticated"
		"friend_required", "invalid_peer": return "not_friend"
		"room_access_denied", "invalid_room": return "room_access_denied"
		"forbidden", "invalid_conversation": return "conversation_unavailable"
		"rate_limited": return "rate_limit"
		"invalid_body", "invalid_message", "payload_too_large": return "message_blocked"
		"idempotency_conflict", "expired_request": return "duplicate_send"
		"game_unavailable", "backend_unavailable": return "network"
	if status == 401: return "not_authenticated"
	if status == 429: return "rate_limit"
	if status >= 500: return "network"
	return "request_failed"


## "2026-10-30T16:10:00+00:00" (ou com fração/Z) -> segundos Unix (UTC).
static func _time(text: String) -> float:
	if text.length() < 19: return Time.get_unix_time_from_system()
	return float(Time.get_unix_time_from_datetime_string(text.substr(0, 19)))
