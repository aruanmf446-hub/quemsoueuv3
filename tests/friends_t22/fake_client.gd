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
		"qse_friends":
			var copy := data.duplicate(true)
			copy.erase("last_message")
			return ServiceResult.success(copy)
		"qse_find_players": return ServiceResult.success({"players": []})
		"qse_mutual_friends": return ServiceResult.success({"count": 2, "players": data.friends.slice(0, 2)})
		"qse_duel_invites_between": return ServiceResult.success([{"room_id": "00000000-0000-4000-8000-0000000000aa", "room_name": "Sala da Luna", "sent_by": str(params.p_friend), "created_at": Time.get_datetime_string_from_system(true), "expires_at": Time.get_datetime_string_from_system(true), "token": "ab".repeat(24)}])
		"qse_friend_stats": return ServiceResult.success({"matches_together": 4, "last_played_at": Time.get_datetime_string_from_system(true)})
		"qse_recent_matches_with": return ServiceResult.success({"count": 1, "matches": [{"match_id": "m", "room_id": "r", "played_at": Time.get_datetime_string_from_system(true)}]})
		"qse_player_suggestions": return ServiceResult.success({"players": [data.incoming[0]] if not data.incoming.is_empty() else [], "mutual_counts": {}})
		"qse_presence_heartbeat": return ServiceResult.success({"status": "online", "last_seen_at": Time.get_datetime_string_from_system(true)})
		"qse_friend_action":
			var target := str(params.p_target)
			var take := func(key: String) -> Dictionary:
				for i in range(data[key].size()):
					if str(data[key][i].user_id) == target: return data[key].pop_at(i)
				return {}
			if params.has("p_message"): data["last_message"] = params.p_message
			match str(params.p_action):
				"accept":
					var p: Dictionary = take.call("incoming")
					if not p.is_empty(): data.friends.append(p)
				"decline": take.call("incoming")
				"cancel": take.call("outgoing")
				"remove": take.call("friends")
			return ServiceResult.success({"status": "applied"})
	return ServiceResult.failure("unsupported")
