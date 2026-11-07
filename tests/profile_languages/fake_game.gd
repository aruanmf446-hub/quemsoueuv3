extends "res://tests/player_reports/fake_game.gd"
## Public appearance observed in the authorized aruan search; identity IDs are fixtures.
func _ready() -> void:
	target={"user_id":"00000000-0000-4000-8000-000000000022","public_id":"QSE-00000000000000000000000000000022","nickname":"aruan","equipped_character_id":"cowboy","level":null}
func call_rpc(rpc: String, params: Dictionary={}) -> Dictionary:
	match rpc:
		"qse_find_players": return ServiceResult.success({"players":[target.duplicate()]})
		"qse_friends": return ServiceResult.success({"friends":[],"incoming":[],"outgoing":[],"presence":{}})
		"qse_friend_action": return ServiceResult.success({"status":"applied"})
		"qse_mutual_friends": return ServiceResult.success({"players":[]})
		"qse_recent_matches_with": return ServiceResult.success({"matches":[],"count":0})
		"qse_player_suggestions": return ServiceResult.success({"players":[]})
	return await super.call_rpc(rpc, params)
