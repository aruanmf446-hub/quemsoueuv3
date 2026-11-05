extends RefCounted
## Transporte de revisão manual. Só o JWT da sessão vai ao servidor configurado;
## credenciais do GitHub nunca existem no cliente. Nenhuma cobrança é realizada.
const CONFIG := "res://data/community/repository.json"
const MAX_TOTAL := 6*1024*1024
const MAX_IMAGE := 768*1024
var services: PlayerServices
var _owner := ""
var _base := ""

func _init() -> void:
	services=PlayerServices.current
	if services!=null: _owner=str(services.session.user.get("id",""))
	_base=str(PlayerContracts.read_json(CONFIG).get("api_url","")).strip_edges().trim_suffix("/")

static func for_draft(draft: Dictionary) -> bool:
	return draft.get("publication_backend","")=="repository"

func configured() -> bool:
	return _base.begins_with("https://") and not _base.contains("@") and not _base.contains("?") and not _base.contains("#")
func available() -> bool:
	return configured() and services!=null and services.session.authenticated() and str(services.session.user.get("id",""))==_owner

static func message(code: String) -> String:
	match code:
		"bridge_not_configured": return "O envio para revisão ainda não foi ativado. Seu rascunho continua salvo."
		"not_authenticated", "session_changed": return "Entre novamente na sua conta para continuar."
		"nickname_required": return "Cadastre seu nickname antes de enviar."
		"deck_too_large": return "As imagens do deck devem somar até 6 MB após otimização."
		"image_too_large": return "Uma imagem ficou grande demais. Reduza a resolução e tente novamente."
		"invalid_image": return "Não foi possível preparar uma imagem válida para o envio."
		"submission_limit": return "Você já tem três envios em análise ou atingiu cinco envios no dia."
		"forbidden": return "Esta conta não tem permissão para revisar decks."
		"retry_conflict": return "Outro envio foi atualizado. Atualize a lista e tente novamente."
		"invalid_status": return "Este envio já mudou de situação. Atualize a lista."
		"duplicate_card": return "Use nomes diferentes para as cartas."
	return "Não foi possível concluir agora. O rascunho permanece salvo; tente novamente."

func request(path: String, method := HTTPClient.METHOD_GET, body: Variant=null) -> Dictionary:
	if not configured(): return ServiceResult.failure("bridge_not_configured")
	if not available(): return ServiceResult.failure("not_authenticated")
	var generation := services.client.generation
	var http := HTTPRequest.new()
	http.timeout=90.0
	http.body_size_limit=12*1024*1024
	http.accept_gzip=not OS.has_feature("web")
	services.add_child(http)
	var headers := PackedStringArray(["Authorization: Bearer "+services.client.access_token,"Content-Type: application/json"])
	var started := http.request(_base+path,headers,method,"" if body==null else JSON.stringify(body))
	if started!=OK:
		http.queue_free()
		return ServiceResult.failure("network")
	var response: Array=await http.request_completed
	http.queue_free()
	if not is_instance_valid(services) or generation!=services.client.generation or str(services.session.user.get("id",""))!=_owner: return ServiceResult.failure("session_changed")
	if response[0]!=HTTPRequest.RESULT_SUCCESS: return ServiceResult.failure("network")
	var data: Variant=JSON.parse_string(response[3].get_string_from_utf8())
	if not data is Dictionary: return ServiceResult.failure("invalid_contract")
	if int(response[1])<200 or int(response[1])>=300: return ServiceResult.failure(str(data.get("error","network")))
	return ServiceResult.success(data)

static func bundle(store: DeckDrafts,draft: Dictionary) -> Dictionary:
	if draft.get("visibility","")!="public" or not DeckDrafts.problems(draft).is_empty(): return ServiceResult.failure("invalid_submission")
	var cards: Array=[]
	var total := 0
	for card: Dictionary in draft.cards:
		var original := store.original_image(str(draft.id),card)
		if original==null: return ServiceResult.failure("invalid_image")
		var image := original.duplicate() as Image
		if image.is_compressed() and image.decompress()!=OK: return ServiceResult.failure("invalid_image")
		var longest := maxi(image.get_width(),image.get_height())
		if longest>1600:
			var ratio := 1600.0/longest
			image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		var bytes := image.save_webp_to_buffer(true,0.9)
		if bytes.is_empty(): return ServiceResult.failure("invalid_image")
		if bytes.size()>MAX_IMAGE: return ServiceResult.failure("image_too_large")
		total+=bytes.size()
		if total>MAX_TOTAL: return ServiceResult.failure("deck_too_large")
		if Engine.get_main_loop() is SceneTree: await (Engine.get_main_loop() as SceneTree).process_frame
		cards.append({"name":str(card.name),"description":str(card.get("description","")).replace("\n"," ").replace("\r"," "),"image":Marshalls.raw_to_base64(bytes),"crops":card.get("crops",{})})
	var cover: Variant=null
	var resolved := DeckCover.resolve_draft(store,draft)
	if DeckCover.exists(str(resolved.path)):
		var texture := DeckCover.framed(str(resolved.path),DeckCover.ASPECT,resolved.focus)
		if texture!=null:
			var image := texture.get_image()
			if image.is_compressed(): image.decompress()
			var bytes := image.save_webp_to_buffer(true,0.9)
			if bytes.size()>MAX_IMAGE: return ServiceResult.failure("image_too_large")
			if total+bytes.size()>MAX_TOTAL: return ServiceResult.failure("deck_too_large")
			cover={"image":Marshalls.raw_to_base64(bytes)}
	return ServiceResult.success({"visibility":"public","name":str(draft.name),"description":str(draft.description).replace("\n"," ").replace("\r"," "),"category":str(draft.category),"style_reference":str(draft.get("style_reference","lendas_urbanas")),"cards":cards,"cover":cover})

func submit(store: DeckDrafts,draft: Dictionary) -> Dictionary:
	if not available(): return ServiceResult.failure("bridge_not_configured" if not configured() else "not_authenticated")
	if OwnerStorage.safe(_owner)!=store.owner: return ServiceResult.failure("session_changed")
	var prepared: Dictionary=await bundle(store,draft)
	if not prepared.ok: return prepared
	var result := await request("/submissions",HTTPClient.METHOD_POST,prepared.data)
	if not result.ok: return result
	var row: Variant=result.data.get("submission")
	if not row is Dictionary or not row.get("id") is String or RegEx.create_from_string("^[a-f0-9]{32}$").search(row.id)==null: return ServiceResult.failure("invalid_contract")
	draft.repo_submission_id=row.id
	draft.repo_status={"approved":"published","publishing":"pending_review"}.get(str(row.get("status","")),str(row.get("status","pending_review")))
	draft.review_note=str(row.get("review_note",""))
	store.save(draft)
	return result

func approve(id: String) -> Dictionary:
	if RegEx.create_from_string("^[a-f0-9]{32}$").search(id)==null: return ServiceResult.failure("invalid_submission")
	var action := "approve"
	for step in 3:
		var result := await request("/submissions/"+id+"/"+action,HTTPClient.METHOD_POST,{})
		if not result.ok: return result
		action=str(result.data.get("next",""))
		if action.is_empty(): return result
		if not action in ["publish","finalize"]: return ServiceResult.failure("invalid_contract")
	return ServiceResult.failure("publication_pending")

func sync_statuses(store: DeckDrafts) -> Dictionary:
	if OwnerStorage.safe(_owner)!=store.owner: return ServiceResult.failure("session_changed")
	var result := await request("/submissions")
	if not result.ok: return result
	var by_id := {}
	for row: Variant in result.data.get("items",[]):
		if row is Dictionary and row.get("id") is String: by_id[row.id]=row
	var changed := false
	for draft: Dictionary in store.list():
		if not for_draft(draft) or not by_id.has(str(draft.get("repo_submission_id",""))): continue
		var row: Dictionary=by_id[str(draft.repo_submission_id)]
		var status := str({"approved":"published","publishing":"pending_review"}.get(str(row.get("status","")),str(row.get("status",""))))
		if not status in ["pending_review","published","rejected"]: continue
		var note := str(row.get("review_note",""))
		if str(draft.get("repo_status",""))!=status or str(draft.get("review_note",""))!=note:
			draft.repo_status=status
			draft.review_note=note
			store.save(draft)
			changed=true
	return ServiceResult.success({"changed":changed})
