extends RefCounted
## Revisão no GAME existente. Contrato a conferir pelo responsável pelo Supabase;
## não usa Worker, token administrativo, endpoint novo de hospedagem nem GitHub API.
const BUCKET := "qse-deck-originals"
var _services: PlayerServices
var _client: SupabaseClient
var _owner := ""
var _generation := 0
var _paths := {}

func _init() -> void:
	_services=PlayerServices.current
	if _services!=null:
		_client=_services.client
		_owner=str(_services.session.user.get("id",""))
		_generation=_client.generation

func available() -> bool:
	return is_instance_valid(_services) and is_instance_valid(_client) and _client.configured() and PlayerServices.current==_services and _services.client==_client and _client.generation==_generation and _services.session.authenticated() and str(_services.session.user.get("id",""))==_owner

static func message(code: String) -> String:
	match code:
		"backend_pending": return "A revisão pelo jogo ainda precisa ser habilitada no Supabase. Seus decks e envios continuam salvos."
		"forbidden": return "Só uma conta autorizada pela administração pode revisar decks. Acompanhe seus envios em Meus Decks."
		"not_authenticated", "session_changed": return "Entre novamente na sua conta para continuar."
		"invalid_status": return "Este deck já mudou de situação. Atualize a fila."
		"invalid_reason": return "Informe o motivo da reprovação, de 3 a 280 caracteres."
		"invalid_image": return "Não foi possível abrir todas as prévias. Atualize o deck antes de aprovar."
	return "Não foi possível concluir agora. Atualize a fila e tente novamente."

func _rpc(name: String,params := {}) -> Dictionary:
	if not available(): return ServiceResult.failure("not_authenticated")
	var result: Dictionary=CommunityService._unwrap(await _client.call_rpc(name,params))
	if not available(): return ServiceResult.failure("session_changed")
	if not result.ok:
		if str(result.code) in ["PGRST202","42883","unknown_rpc"]: return ServiceResult.failure("backend_pending")
		return result
	if not result.data is Dictionary: return ServiceResult.failure("invalid_contract")
	return result

func access() -> Dictionary:
	var result := await _rpc("qse_deck_review_access")
	if result.ok and not result.data.get("is_moderator") is bool: return ServiceResult.failure("invalid_contract")
	return result

func pending() -> Dictionary:
	var result := await _rpc("qse_deck_review_queue",{"p_limit":50})
	if not result.ok: return result
	if not result.data.get("items") is Array or result.data.items.size()>50: return ServiceResult.failure("invalid_contract")
	for row: Variant in result.data.items:
		if not row is Dictionary or not CreatorSync.is_uuid(str(row.get("id",""))) or not row.get("name") is String or row.get("status")!="pending_review": return ServiceResult.failure("invalid_contract")
	return result

func open_deck(id: String) -> Dictionary:
	_paths.clear()
	if not CreatorSync.is_uuid(id): return ServiceResult.failure("invalid_contract")
	var result := await _rpc("qse_deck_review_detail",{"p_deck":id})
	if not result.ok: return result
	var deck: Variant=result.data.get("deck")
	var cards: Variant=result.data.get("cards")
	if not deck is Dictionary or str(deck.get("id",""))!=id or not deck.get("name") is String or not deck.get("creator") is Dictionary or not cards is Array or cards.size()>30: return ServiceResult.failure("invalid_contract")
	for card: Variant in cards:
		if not card is Dictionary or not CreatorSync.is_uuid(str(card.get("id",""))) or not card.get("name") is String: return ServiceResult.failure("invalid_contract")
		for format in ["library","duel"]:
			var path := str(card.get("preview_"+format+"_path",""))
			if _valid_path(path,id,str(card.id)+"_"+format+".png"): _paths[path]=true
	var cover := str(deck.get("cover_path","")) if deck.get("cover_path")!=null else ""
	if _valid_path(cover,id,"deck_cover.png"): _paths[cover]=true
	# A capa pode ser uma das prévias já validadas; originais nunca são baixados aqui.
	return result

static func _valid_path(path: String,deck_id: String,file: String) -> bool:
	var parts := path.split("/")
	return parts.size()==3 and CreatorSync.is_uuid(parts[0]) and parts[1]==deck_id and parts[2]==file

func image(path: String) -> String:
	if not available() or not _paths.has(path): return ""
	var local := OwnerStorage.path(OwnerStorage.safe(_owner),"deck_review/"+path.sha256_text()+".png")
	if FileAccess.file_exists(local): return local
	var result := await _client.send("/storage/v1/object/authenticated/"+BUCKET+"/"+path,HTTPClient.METHOD_GET,null,PackedStringArray(),PackedByteArray(),"application/octet-stream",60.0)
	if not available() or not result.ok or not result.data is Dictionary: return ""
	var bytes: PackedByteArray=result.data.get("bytes",PackedByteArray())
	if bytes.is_empty() or bytes.size()>4*1024*1024: return ""
	var preview := Image.new()
	if preview.load_png_from_buffer(bytes)!=OK or preview.get_width()>2048 or preview.get_height()>2048: return ""
	var file := FileAccess.open(local,FileAccess.WRITE)
	if file==null: return ""
	file.store_buffer(bytes)
	file.close()
	return local

func decide(id: String,approved: bool,reason: String) -> Dictionary:
	if not CreatorSync.is_uuid(id): return ServiceResult.failure("invalid_contract")
	reason=reason.strip_edges()
	if not approved and (reason.length()<3 or reason.length()>280): return ServiceResult.failure("invalid_reason")
	var result := await _rpc("qse_deck_review_decide",{"p_deck":id,"p_approved":approved,"p_reason":null if approved else reason})
	if not result.ok: return result
	if str(result.data.get("deck_id",""))!=id or str(result.data.get("status",""))!=("published" if approved else "rejected"): return ServiceResult.failure("invalid_contract")
	CommunityService.loaded_at=-1000.0
	return result
