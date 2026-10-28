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
	var result := await client.rpc("qse_find_players", {"p_term": term})
	if result.ok and (not result.data is Dictionary or not PlayerContracts.valid_players(result.data.get("players"))):
		return ServiceResult.failure("invalid_contract")
	return result


func act(action: String, target_id: String, request_id: String = "") -> Dictionary:
	if action not in ["send", "accept", "decline", "cancel", "remove"]:
		return ServiceResult.failure("invalid_action")
	var result := await client.rpc("qse_friend_action", {"p_action": action, "p_target": target_id,
		"p_request_id": PlayerContracts.uuid() if request_id.is_empty() else request_id})
	if result.ok:
		await refresh()
	return result


func presence_label(player_id: String) -> String:
	if not presence_known.has(player_id):
		return "Presença indisponível"
	return "Online" if online_ids.has(player_id) else "Offline"


func valid_data(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3:
		return false
	for key: String in ["friends", "incoming", "outgoing"]:
		if not PlayerContracts.valid_players(value.get(key)):
			return false
	return true
