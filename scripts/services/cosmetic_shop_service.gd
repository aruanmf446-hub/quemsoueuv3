class_name CosmeticShopService
extends RemoteDataService
var session: SessionService
var _owner := ""
var _buying := false
var _requests: Dictionary = {}

func clear() -> void:
	_owner=""
	_requests.clear()
	super.clear()

func refresh() -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	var owner := str(session.user.get("id",""))
	var epoch := client.generation
	var result := await load_rpc("qse_cosmetic_shop")
	if epoch!=client.generation or owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if result.ok:
		_owner=owner
		changed.emit()
	return result

func product(character: String,style: String) -> Dictionary:
	for item: Dictionary in data.get("items",[]):
		if item.character_id==character and str(item.get("style_id",""))==style: return item
	return {}

func equipped(character: String) -> String:
	if not session.authenticated() or _owner!=str(session.user.get("id","")): return "original"
	return str(data.get("equipped",{}).get(character,"original"))

func buy(item: Dictionary) -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	if _owner!=str(session.user.get("id","")) or not data.get("enabled",false) or not item.get("available",false): return ServiceResult.failure("sales_disabled")
	if _buying: return ServiceResult.failure("request_in_progress")
	var owner := _owner
	var epoch := client.generation
	var key := owner+":"+str(item.id)+":"+str(item.price_coins)
	if not _requests.has(key): _requests[key]=PlayerContracts.uuid()
	_buying=true
	var result := await client.call_rpc("qse_cosmetic_purchase",{"p_product":item.id,"p_request":_requests[key],"p_expected_price":str(item.price_coins).to_int()})
	_buying=false
	if epoch!=client.generation or owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if result.ok and (not result.data is Dictionary or result.data.get("owned")!=true or result.data.get("product_id")!=str(item.id) or not result.data.get("already_owned") is bool or not result.data.get("coins_after") is String or not str(result.data.coins_after).is_valid_int() or str(result.data.coins_after).to_int()<0): return ServiceResult.failure("invalid_contract")
	if result.ok: await refresh()
	return result

func equip(character: String,style: String) -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	var owner := str(session.user.get("id",""))
	var epoch := client.generation
	var result := await client.call_rpc("qse_variation_equip",{"p_character":character,"p_style":style})
	if epoch!=client.generation or owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if result.ok and (not result.data is Dictionary or result.data.get("character_id")!=character or result.data.get("style_id")!=style): return ServiceResult.failure("invalid_contract")
	if result.ok: await refresh()
	return result

func valid_data(value: Variant) -> bool:
	if not value is Dictionary or not value.get("enabled") is bool or not value.get("deck_credits_required") is bool: return false
	if not value.get("deck_credits") is String or not str(value.deck_credits).is_valid_int() or str(value.deck_credits).to_int()<0: return false
	if not value.get("items") is Array or not value.get("equipped") is Dictionary: return false
	for item: Variant in value.items:
		if not item is Dictionary or not item.get("id") is String or not item.get("name") is String or not item.get("character_id") is String: return false
		if item.get("kind") not in ["skin","variation"] or not item.get("price_coins") is String or not str(item.price_coins).is_valid_int() or str(item.price_coins).to_int()<1: return false
		if not item.get("owned") is bool or not item.get("available") is bool: return false
	return true
