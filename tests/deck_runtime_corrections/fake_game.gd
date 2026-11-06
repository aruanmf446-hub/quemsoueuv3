extends "res://tests/community_t27/fake_game.gd"
var report_code := ""
var report_requests := 0
var hold_report := false
var empty_confirmation := false
func call_rpc(name: String, params: Dictionary={}) -> Dictionary:
	if name=="qse_deck_report":
		report_requests+=1
		await get_tree().process_frame
		while hold_report: await get_tree().process_frame
		if report_code=="PGRST202": return ServiceResult.failure(report_code)
		if not report_code.is_empty(): return ServiceResult.success({"error":report_code})
		if empty_confirmation: return ServiceResult.success({})
	return await super.call_rpc(name,params)
