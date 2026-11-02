extends SupabaseClient
## FIXTURE DE TESTE (T24): respostas no formato exato de qse_deck_stats / qse_deck_record_play, sem rede.
var stats: Array = []
var fail := false
var calls: Array = []


func configured() -> bool:
	return true


func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	await get_tree().process_frame
	calls.append([name, params.duplicate(true)])
	if fail: return ServiceResult.failure("network")
	match name:
		"qse_deck_stats": return ServiceResult.success(stats.duplicate(true))
		"qse_deck_record_play":
			return ServiceResult.success({"deck_ref": params.p_deck_ref, "recorded": true, "played_at": "2026-11-02T10:00:00Z", "reason": null})
	return ServiceResult.failure("unknown_rpc")
