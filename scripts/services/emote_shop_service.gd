class_name EmoteShopService
extends RemoteDataService
var session: SessionService
var _pending: Dictionary = {}
var _buying := false
var _owner := ""
const MOTIONS=preload("res://scripts/skins/universal_emotes.gd")

func clear() -> void:
	_pending={}
	_owner=""
	super.clear()

func refresh() -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	var owner := str(session.user.get("id",""))
	var epoch := client.generation
	var result := await load_rpc("qse_emote_shop")
	if epoch!=client.generation or owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if result.ok and state=="success": _owner=owner
	return result

func product(id: String) -> Dictionary:
	for item: Dictionary in data.get("items",[]):
		if item.id==id: return item
	return {}

func owned(id: String) -> bool:
	return session.authenticated() and _owner==str(session.user.get("id","")) and product(id).get("owned",false)==true

## Use entitlement confirmed for this session; changing avatar neither buys nor waits on HTTP.
func play_owned(slot: CharacterSlot,id: String,still_current: Callable=Callable()) -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	if not is_instance_valid(slot): return ServiceResult.failure("emote_target_changed")
	var owner := str(session.user.get("id",""))
	var epoch := client.generation
	var character := str(slot.character_id)
	var guarded := not still_current.is_null()
	if not owned(id):
		var result := await refresh()
		if not result.ok: return result
	if owner!=str(session.user.get("id","")) or epoch!=client.generation: return ServiceResult.failure("session_changed")
	if not owned(id): return ServiceResult.failure("emote_not_owned")
	if not is_instance_valid(slot) or slot.is_queued_for_deletion(): return ServiceResult.failure("emote_target_changed")
	if str(slot.character_id)!=character or (guarded and (not still_current.is_valid() or not still_current.call())): return ServiceResult.failure("emote_target_changed")
	var key := str(product(id).get("animation_key",""))
	if not MOTIONS.install(slot,key): return ServiceResult.failure("emote_motion_unavailable")
	if not slot.play_emote(StringName(key)): return ServiceResult.failure("emote_motion_unavailable")
	return ServiceResult.success({"emote_id":id,"scope":"account","character_id":character})

func buy(id: String,expected_price: int) -> Dictionary:
	if not ReleaseFeatures.COMMERCE_ENABLED: return ServiceResult.failure("sales_disabled")
	if MOTIONS.price_pending(id) and product(id).is_empty(): return ServiceResult.failure("price_pending")
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	if _buying: return ServiceResult.failure("request_in_progress")
	var owner := str(session.user.get("id",""))
	var key := owner+":"+id+":"+str(expected_price)
	if not _pending.has(key): _pending[key]=PlayerContracts.uuid()
	_buying=true
	var result := await client.call_rpc("qse_emote_purchase",{"p_emote":id,"p_request":_pending[key],"p_expected_price":expected_price})
	_buying=false
	if owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if result.ok and result.data is Dictionary and result.data.has("error"):
		return ServiceResult.failure(str(result.data.error))
	if result.ok:
		if not result.data is Dictionary or result.data.get("owned")!=true or result.data.get("emote_id")!=id or not result.data.get("already_owned") is bool:
			return ServiceResult.failure("invalid_contract")
		if not result.data.get("coins_after") is String or not str(result.data.coins_after).is_valid_int() or str(result.data.coins_after).to_int()<0 or not result.data.get("transaction_id") is String or str(result.data.transaction_id).length()!=36:
			return ServiceResult.failure("invalid_contract")
		var item := product(id)
		if not item.is_empty(): item.owned=true
		_owner=owner
		data.coins=result.data.coins_after
		changed.emit()
		await refresh()
	return result

func valid_data(value: Variant) -> bool:
	if not value is Dictionary or not value.get("items") is Array or not value.get("coins") is String: return false
	if not str(value.coins).is_valid_int() or str(value.coins).to_int()<0: return false
	for item: Variant in value.items:
		if not item is Dictionary: return false
		for field in ["id","name","animation_key","price_coins"]:
			if not item.get(field) is String: return false
		if not str(item.price_coins).is_valid_int() or str(item.price_coins).to_int()<1: return false
		if not item.get("available") is bool or not item.get("owned") is bool: return false
	return true

static func message(code: String) -> String:
	match code:
		"sales_disabled": return "As vendas estão desabilitadas. A prévia continua disponível."
		"product_unavailable": return "Este item não está disponível para compra."
		"not_owned": return "Esta variação ainda não está na sua conta."
		"price_pending": return "O preço deste emote ainda não foi definido."
		"emote_not_owned": return "Este emote ainda não está na sua conta."
		"emote_target_changed": return "O personagem mudou. Toque em usar novamente."
		"emote_motion_unavailable": return "O movimento deste emote ainda não está disponível para este personagem nesta versão."
		"insufficient_funds": return "Você não tem moedas suficientes."
		"emote_unavailable": return "Este emote ainda não está à venda. A prévia continua disponível."
		"price_changed": return "O preço mudou. Abra a confirmação novamente."
		"emote_not_found": return "Emote não encontrado na loja."
		"idempotency_conflict": return "A tentativa de compra mudou. Abra a confirmação novamente."
	return ServiceResult.message(ServiceResult.failure(code))
