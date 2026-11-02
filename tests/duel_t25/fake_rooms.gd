extends SupabaseClient
## FIXTURE DE TESTE (T25): salas no formato de qse_duel_list, sem rede. Só testes/capturas.
var rooms: Array = []
var calls: Array = []
var fail := false
var joins := 0


func configured() -> bool:
	return true


static func room(code: String, players: int, max_players: int, decks: Array) -> Dictionary:
	return {"id": "00000000-0000-4000-8000-%012d" % code.hash(), "code": code, "name": "nome técnico", "players": players,
		"max_players": max_players, "bots": 0, "cards_per_player": 3, "turn_seconds": 60, "admin": "Demo",
		"decks": decks.map(func(n: String) -> Dictionary: return {"id": n.to_lower().replace(" ", "_"), "name": n, "size": 9})}


func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	await get_tree().process_frame
	calls.append([name, params.duplicate()])
	if fail: return ServiceResult.failure("network", "offline")
	match name:
		"qse_duel_list": return ServiceResult.success({"rooms": rooms.duplicate(true)})
		"qse_duel_join":
			joins += 1
			return ServiceResult.failure("room_full")
		"qse_duel_invite_join": return ServiceResult.failure("invalid_invite")
		"qse_duel_heartbeat": return ServiceResult.success({"member": false})
	return ServiceResult.failure("request_failed")
