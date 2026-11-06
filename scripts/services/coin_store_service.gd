class_name CoinStoreService
extends RemoteDataService

## Money is handled only by hosted Stripe Checkout; this service cannot credit a wallet.
var session: SessionService
var _creating := false
const INTENTS := "user://coin_checkout.cfg"
const FINAL := ["paid","test_paid","expired","payment_review"]

func refresh() -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	return await load_rpc("qse_coin_store")

func create_checkout(pack: Dictionary) -> Dictionary:
	if not session.authenticated(): return ServiceResult.failure("not_authenticated")
	if _creating: return ServiceResult.failure("request_in_progress")
	if not data.get("enabled",false): return ServiceResult.failure("payments_unavailable")
	if not data.get("packages",[]).has(pack): return ServiceResult.failure("package_unavailable")
	var owner := str(session.user.id)
	var key := str(pack.id)+":"+str(pack.price_brl_cents)+":"+str(pack.coins)+":"+str(data.live_mode)
	var saved := ConfigFile.new()
	saved.load(INTENTS)
	var request := str(saved.get_value(owner,key,""))
	for order: Dictionary in data.get("orders",[]):
		if order.get("request_id")==request and order.status in FINAL: request=""
	if not uuid_valid(request): request=PlayerContracts.uuid()
	saved.set_value(owner,key,request)
	if saved.save(INTENTS)!=OK: return ServiceResult.failure("local_storage_unavailable")
	_creating=true
	var epoch := client.generation
	var result := await client.send("/functions/v1/qse-coin-checkout",HTTPClient.METHOD_POST,{
		"package_id":pack.id,"request_id":request,"expected_amount":pack.price_brl_cents,"expected_coins":pack.coins})
	_creating=false
	if epoch!=client.generation or owner!=str(session.user.get("id","")): return ServiceResult.failure("session_changed")
	if not result.ok:
		if result.code=="order_expired":
			saved.erase_section_key(owner,key)
			saved.save(INTENTS)
		return result
	var receipt: Variant=result.data.get("data")
	if not receipt is Dictionary or not uuid_valid(str(receipt.get("order_id",""))) or not safe_checkout(str(receipt.get("url",""))):
		return ServiceResult.failure("invalid_contract")
	return ServiceResult.success(receipt)

func valid_data(value: Variant) -> bool:
	if not value is Dictionary or not value.get("enabled") is bool or not value.get("live_mode") is bool:
		return false
	if not value.get("packages") is Array or not value.get("orders") is Array: return false
	for pack: Variant in value.packages:
		if not pack is Dictionary or not pack.get("id") is String or not pack.get("name") is String: return false
		if not pack.get("coins") is String or not str(pack.coins).is_valid_int() or str(pack.coins).to_int()<1: return false
		if not (pack.get("price_brl_cents") is int or pack.get("price_brl_cents") is float): return false
		if not is_finite(float(pack.price_brl_cents)) or float(pack.price_brl_cents)!=floor(float(pack.price_brl_cents)) or pack.price_brl_cents<50 or pack.price_brl_cents>99999999: return false
	for order: Variant in value.orders:
		if not order is Dictionary or not uuid_valid(str(order.get("id",""))) or not uuid_valid(str(order.get("request_id",""))): return false
		if not order.get("coins") is String or not str(order.coins).is_valid_int() or str(order.coins).to_int()<1: return false
		if not order.get("live_mode") is bool or not order.get("created_at") is String: return false
		if order.get("status") not in ["pending","paid","test_paid","expired","payment_review"]: return false
	return true

static func uuid_valid(value: String) -> bool:
	return RegEx.create_from_string("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").search(value)!=null

static func safe_checkout(value: String) -> bool:
	return value.begins_with("https://checkout.stripe.com/c/") and not value.contains("\n") and not value.contains("\r")

static func message(code: String) -> String:
	match code:
		"payments_unavailable": return "A compra de moedas ainda não está disponível."
		"payment_service_unavailable": return "Não foi possível preparar o pagamento. Tente novamente."
		"price_changed": return "O pacote mudou. Atualize e confira o novo valor."
		"order_expired": return "Este pagamento expirou. Escolha o pacote novamente."
		"payment_review": return "Há um pagamento em análise. Entre em contato com o suporte."
		"package_unavailable": return "Este pacote não está disponível. Atualize a loja."
		"local_storage_unavailable": return "Não foi possível guardar esta tentativa. Confira o armazenamento do app."
	return ServiceResult.message(ServiceResult.failure(code))

static func order_message(state: String) -> String:
	match state:
		"paid": return "Pagamento confirmado · moedas adicionadas"
		"test_paid": return "Teste confirmado · nenhuma moeda real adicionada"
		"expired": return "Pagamento expirado"
		"payment_review": return "Pagamento em análise · fale com o suporte"
	return "Aguardando confirmação do pagamento"
