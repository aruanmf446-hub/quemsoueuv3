extends "res://tests/skin_emotes/fake_game.gd"
## Synthetic prices below exist only in tests, never in the production catalogue.
var packages := [{"id":"fixture_pack","name":"Pacote de teste","coins":"500","price_brl_cents":990}]
var orders: Array=[]
var enabled := true
var live_mode := false
var checkout_calls: Array=[]
var checkout_error := ""
var checkout_url := "https://checkout.stripe.com/c/pay/fixture"
var checkout_hold := false
func call_rpc(rpc: String,params: Dictionary={}) -> Dictionary:
	if rpc=="qse_coin_store":
		await get_tree().process_frame
		return ServiceResult.success({"enabled":enabled,"live_mode":live_mode,"packages":packages.duplicate(true),"orders":orders.duplicate(true)})
	return await super.call_rpc(rpc,params)
func send(path: String,method: HTTPClient.Method=HTTPClient.METHOD_GET,body: Variant=null,headers: PackedStringArray=PackedStringArray(),raw: PackedByteArray=PackedByteArray(),content_type: String="application/json",timeout: float=30.0) -> Dictionary:
	if path=="/functions/v1/qse-coin-checkout":
		checkout_calls.append(body.duplicate(true))
		await get_tree().process_frame
		while checkout_hold: await get_tree().process_frame
		if not checkout_error.is_empty(): return ServiceResult.failure(checkout_error)
		return ServiceResult.success({"status":200,"data":{"order_id":"00000000-0000-4000-8000-0000000000aa","url":checkout_url},"bytes":PackedByteArray()})
	return await super.send(path,method,body,headers,raw,content_type,timeout)
