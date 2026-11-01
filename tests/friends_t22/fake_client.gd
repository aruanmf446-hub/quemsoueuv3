extends SupabaseClient
## FIXTURE DE TESTE: aplica qse_friend_action sobre os dados da fixture, sem rede.
var data: Dictionary
var calls: Array = []


func configured() -> bool:
	return true


func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	await get_tree().process_frame
	calls.append([name, params.duplicate()])
	match name:
		"qse_friends": return ServiceResult.success(data.duplicate(true))
		"qse_find_players": return ServiceResult.success({"players": []})
		"qse_friend_action":
			var target := str(params.p_target)
			var take := func(key: String) -> Dictionary:
				for i in range(data[key].size()):
					if str(data[key][i].user_id) == target: return data[key].pop_at(i)
				return {}
			match str(params.p_action):
				"accept":
					var p: Dictionary = take.call("incoming")
					if not p.is_empty(): data.friends.append(p)
				"decline": take.call("incoming")
				"cancel": take.call("outgoing")
				"remove": take.call("friends")
			return ServiceResult.success({"status": "applied"})
	return ServiceResult.failure("unsupported")
