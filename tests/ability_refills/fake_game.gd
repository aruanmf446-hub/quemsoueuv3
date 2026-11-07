extends "res://tests/skin_emotes/fake_game.gd"
var quantity := 2
var deliveries: Dictionary={}
var bought: Dictionary={}
var refill_calls: Array=[]
var lose_reserve := false
var lose_buy := false
var fail_ack := false
var on_reserve := Callable()
func call_rpc(rpc: String,params: Dictionary={}) -> Dictionary:
 refill_calls.append({"rpc":rpc,"params":params.duplicate(true)})
 await get_tree().process_frame
 if rpc=="qse_ability_refills":
  var pending: Array=[]
  for id: String in deliveries:
   if deliveries[id].status=="pending": pending.append({"id":id,"ability":deliveries[id].ability})
  return ServiceResult.success({"price_coins":"10","available":true,"quantity":str(quantity),"pending":pending})
 if rpc=="qse_ability_refill_buy":
  var id := str(params.p_request);var prior: bool=bought.has(id)
  if not prior:
   if coins<10: return ServiceResult.failure("insufficient_funds")
   coins-=10;quantity+=1;bought[id]=true
  if lose_buy:lose_buy=false;return ServiceResult.failure("network")
  return ServiceResult.success({"purchased":true,"already_purchased":prior,"request_id":id})
 if rpc=="qse_ability_refill_reserve":
  var id := str(params.p_request)
  if not deliveries.has(id):
   if quantity<1:return ServiceResult.failure("no_refills")
   quantity-=1;deliveries[id]={"ability":params.p_ability,"status":"pending"}
  if on_reserve.is_valid():on_reserve.call()
  if lose_reserve:lose_reserve=false;return ServiceResult.failure("network")
  return ServiceResult.success({"id":id,"ability":deliveries[id].ability,"status":deliveries[id].status})
 if rpc=="qse_ability_refill_ack":
  if fail_ack:return ServiceResult.failure("network")
  var id := str(params.p_receipt)
  if not deliveries.has(id):return ServiceResult.failure("receipt_not_found")
  deliveries[id].status="used"
  return ServiceResult.success({"id":id,"used":true})
 return await super.call_rpc(rpc,params)
