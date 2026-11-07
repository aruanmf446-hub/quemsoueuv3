extends "res://tests/skin_emotes/fake_game.gd"
var account := ""
var entitlements: Dictionary={}
var balances: Dictionary={}
var shop_reads := 0
var hold_shop := false
func call_rpc(rpc: String,params: Dictionary={}) -> Dictionary:
	if rpc=="qse_wallet": return ServiceResult.success({"coins":str(balances.get(account,250)),"gems":"33","revision":"1","transactions":[],"next_cursor":null})
	if rpc=="qse_emote_shop":
		shop_reads+=1
		var owner := account
		while hold_shop: await get_tree().process_frame
		return ServiceResult.success({"coins":str(balances.get(owner,250)),"items":[{"id":"dance_01","name":"Fixture universal","price_coins":"100","available":true,"owned":entitlements.get(owner,false),"animation_key":"emote_dance_01"}]})
	if rpc=="qse_emote_purchase":
		purchase_calls.append(params.duplicate(true))
		var already: bool=entitlements.get(account,false)
		if not already:
			entitlements[account]=true
			balances[account]=int(balances.get(account,250))-100
		return ServiceResult.success({"owned":true,"already_owned":already,"emote_id":"dance_01","coins_after":str(balances[account]),"transaction_id":"00000000-0000-4000-8000-0000000000a1"})
	return await super.call_rpc(rpc,params)
