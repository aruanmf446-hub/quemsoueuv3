class_name FriendsService
extends RemoteDataService

var online_ids: Dictionary = {}
var presence_known: Dictionary = {}
var presence_connected := false


func clear() -> void:
	online_ids.clear()
	presence_known.clear()
	presence_connected = false
	super.clear()


func refresh() -> Dictionary:
	return await load_rpc("qse_friends")


func search(term: String) -> Dictionary:
	term = term.strip_edges()
	if term.length() < 2 or term.length() > 64:
		return ServiceResult.failure("invalid_search")
	var result := await client.call_rpc("qse_find_players", {"p_term": term})
	if result.ok and (not result.data is Dictionary or not PlayerContracts.valid_players(result.data.get("players"))):
		return ServiceResult.failure("invalid_contract")
	return result


func report_player(public_id: String, reason: String) -> Dictionary:
	if client == null or client.access_token.is_empty(): return ServiceResult.failure("not_authenticated")
	var value := reason.strip_edges()
	if value.length()<3 or value.length()>280: return ServiceResult.failure("invalid_reason")
	if public_id.strip_edges().is_empty(): return ServiceResult.failure("player_not_found")
	var result := await client.call_rpc("qse_player_report",{"p_public_id":public_id,"p_reason":value})
	if result.ok and result.data is Dictionary and result.data.has("error"):
		return ServiceResult.failure(str(result.data.error))
	if not result.ok and str(result.code) in ["PGRST202","42883","unknown_rpc"]:
		return ServiceResult.failure("report_unavailable")
	if result.ok and (not result.data is Dictionary or result.data.get("reported")!=true):
		return ServiceResult.failure("report_invalid_response")
	return result


static func report_message(code: String) -> String:
	match code:
		"invalid_reason": return "Descreva o motivo com 3 a 280 caracteres."
		"cannot_report_self": return "Você não pode denunciar a própria conta."
		"already_reported": return "Você já denunciou este jogador. A denúncia aguarda análise."
		"player_not_found": return "Jogador não encontrado. Abra o perfil novamente."
	return CommunityService.message(code)


func act(action: String, target_id: String, request_id: String = "", message: String = "") -> Dictionary:
	if action not in ["send", "accept", "decline", "cancel", "remove"]:
		return ServiceResult.failure("invalid_action")
	message = message.strip_edges()
	if message.length() > 140:
		return ServiceResult.failure("invalid_message")
	var params := {"p_action": action, "p_target": target_id,
		"p_request_id": PlayerContracts.uuid() if request_id.is_empty() else request_id}
	# T22: mensagem opcional só no pedido; sem ela, a assinatura antiga (3 parâmetros).
	if action == "send" and not message.is_empty(): params.p_message = message
	var result := await client.call_rpc("qse_friend_action", params)
	if result.ok and (not result.data is Dictionary or result.data.get("status") not in ["applied", "noop"]):
		return ServiceResult.failure("invalid_contract")
	if result.ok:
		await refresh()
	return result


## Estado do amigo: Realtime (online agora) vence; senão o heartbeat do servidor (T22):
## "online", "in_match" ou "offline" (com last_seen_at). Sem dado: "unknown".
func presence_status(player_id: String) -> String:
	if online_ids.has(player_id): return "in_match" if _server_status(player_id) == "in_match" else "online"
	var server := _server_status(player_id)
	if not server.is_empty(): return server
	return "offline" if presence_known.has(player_id) else "unknown"


func last_seen(player_id: String) -> float:
	var entry: Variant = data.get("presence", {}).get(player_id) if data.get("presence") is Dictionary else null
	return PlayerContracts.iso_seconds(str(entry.get("last_seen_at", ""))) if entry is Dictionary and entry.get("last_seen_at") is String else 0.0


func _server_status(player_id: String) -> String:
	var presence: Variant = data.get("presence")
	if not presence is Dictionary: return ""
	var entry: Variant = presence.get(player_id)
	return str(entry.get("status", "")) if entry is Dictionary else ""


## Dados do pedido (T22): {"message": String|null, "requested_at": "ISO"}.
func request_info(player_id: String) -> Dictionary:
	var requests: Variant = data.get("requests")
	var entry: Variant = requests.get(player_id) if requests is Dictionary else null
	return entry if entry is Dictionary else {}


func presence_label(player_id: String) -> String:
	match presence_status(player_id):
		"online": return "Online"
		"in_match": return "Em partida"
		"offline": return "Offline"
	return "Presença indisponível"


## T05 (3 listas) ou T22 (+ requests e presence, fora dos perfis de 5 campos).
func valid_data(value: Variant) -> bool:
	if not value is Dictionary or not value.size() in [3, 5]:
		return false
	for key: String in ["friends", "incoming", "outgoing"]:
		if not PlayerContracts.valid_players(value.get(key)):
			return false
	if value.size() == 5 and (not value.get("requests") is Dictionary or not value.get("presence") is Dictionary):
		return false
	return true


func call_game(name: String, params: Dictionary = {}) -> Dictionary:
	return await client.call_rpc(name, params)
