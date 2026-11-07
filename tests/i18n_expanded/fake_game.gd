extends "res://tests/community_t27/fake_game.gd"
var target := {"user_id":"00000000-0000-4000-8000-000000000022","public_id":"QSE-00000000000000000000000000000022","nickname":"Configurações","equipped_character_id":"cowboy","level":null}
func call_rpc(rpc: String, params: Dictionary={}) -> Dictionary:
	match rpc:
		"qse_profile_public": return ServiceResult.success(target.duplicate())
		"qse_find_players": return ServiceResult.success({"players":[target.duplicate()]})
		"qse_friends": return ServiceResult.success({"friends":[],"incoming":[],"outgoing":[]})
		"qse_mutual_friends": return ServiceResult.success({"count":0,"players":[]})
		"qse_recent_matches_with": return ServiceResult.success({"matches":[],"count":0})
		"qse_player_suggestions": return ServiceResult.success({"players":[]})
	return await super.call_rpc(rpc,params)
