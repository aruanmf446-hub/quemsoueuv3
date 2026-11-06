extends "res://tests/player_reports/fake_game.gd"
var coins := 250
var owned := false
var available := true
var purchase_code := ""
var shop_code := ""
var lose_response := false
var hold_purchase := false
var purchase_calls: Array = []
func call_rpc(rpc: String,params: Dictionary={}) -> Dictionary:
	if rpc=="qse_emote_shop":
		await get_tree().process_frame
		if not shop_code.is_empty(): return ServiceResult.failure(shop_code)
		return ServiceResult.success({"coins":str(coins),"items":[{"id":"dance_01","name":"Dancinha","price_coins":"100","available":available,"owned":owned,"animation_key":"dance_preview"}]})
	if rpc=="qse_wallet":
		return ServiceResult.success({"coins":str(coins),"gems":"33","revision":"1","transactions":[],"next_cursor":null})
	if rpc=="qse_emote_purchase":
		purchase_calls.append(params.duplicate())
		await get_tree().process_frame
		while hold_purchase: await get_tree().process_frame
		if not purchase_code.is_empty(): return ServiceResult.failure(purchase_code)
		var already := owned
		if not owned: coins-=100;owned=true
		if lose_response:
			lose_response=false
			return ServiceResult.failure("network")
		return ServiceResult.success({"owned":true,"already_owned":already,"emote_id":"dance_01","coins_after":str(coins),"transaction_id":"00000000-0000-4000-8000-0000000000a1"})
	return await super.call_rpc(rpc,params)
