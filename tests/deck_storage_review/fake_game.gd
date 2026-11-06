extends "res://tests/community_t27/fake_game.gd"
## Fixture dos retornos registrados no PR #100; nenhum backend real ou HTTP.
var reviewer := true
var review_enabled := true
var review_status := "pending_review"
var review_note := ""
var decisions := 0
var break_preview := false
var missing_preview := false
var fail_decision := false
var null_nickname := false
var cover_from_card := false
var asset_reads := 0
var asset_urls: Array[String]=[]
var review_calls: Array=[]
func _ready() -> void:
	super._ready()
	var image := Image.create(320,100,false,Image.FORMAT_RGB8)
	image.fill(Color.STEEL_BLUE)
	for i in 5:
		var card := "00000000-0000-4000-8000-"+str(i+1).pad_zeros(12)
		files["%s/%s/%s_library.png" % [OTHER,PUBLISHED,card]]=files["%s/%s/c%d_library.png" % [OTHER,PUBLISHED,i]]
		files["%s/%s/%s_duel.png" % [OTHER,PUBLISHED,card]]=image.save_png_to_buffer()

func send(path: String,method: HTTPClient.Method,body: Variant=null,headers:=PackedStringArray(),raw:=PackedByteArray(),type:="",timeout:=30.0) -> Dictionary:
	if path.begins_with("/storage/v1/object/authenticated/qse-deck-originals/"+OTHER+"/"):
		await get_tree().process_frame
		if not reviewer: return ServiceResult.failure("forbidden")
		asset_reads+=1
		asset_urls.append(path)
		var key := path.get_slice("?",0).trim_prefix("/storage/v1/object/authenticated/qse-deck-originals/")
		if break_preview or key.contains("original") or not files.has(key): return ServiceResult.failure("not_found")
		return ServiceResult.success({"bytes":files[key]})
	return await super.send(path,method,body,headers,raw,type,timeout)

func call_rpc(name: String,params: Dictionary={}) -> Dictionary:
	if not name.begins_with("qse_deck_review_"): return await super.call_rpc(name,params)
	await get_tree().process_frame
	review_calls.append([name,params.duplicate(true)])
	if not review_enabled: return ServiceResult.failure("PGRST202")
	if name=="qse_deck_review_access": return ServiceResult.success({"is_moderator":reviewer})
	if not reviewer: return ServiceResult.success({"error":"forbidden"})
	match name:
		"qse_deck_review_queue": return ServiceResult.success({"items":[{"id":PUBLISHED,"name":"[TESTE] Deck em revisão","status":review_status}] if review_status=="pending_review" else []})
		"qse_deck_review_detail":
			if params.p_deck!=PUBLISHED or review_status!="pending_review": return ServiceResult.success({"error":"deck_not_found"})
			var cards := []
			for i in 5:
				var id := "00000000-0000-4000-8000-"+str(i+1).pad_zeros(12)
				cards.append({"id":id,"name":"Carta de teste "+str(i+1),"preview_library_path":"%s/%s/%s_library.png" % [OTHER,PUBLISHED,id],"preview_duel_path":"%s/%s/%s_duel.png" % [OTHER,PUBLISHED,id]})
			if missing_preview: cards[0].preview_duel_path=null
			return ServiceResult.success({"deck":{"id":PUBLISHED,"name":"[TESTE] Deck em revisão","description":"Prévia local do fluxo de Storage; não é conteúdo publicado.","status":review_status,"creator":{"nickname":null if null_nickname else "Criador de teste"},"cover_path":cards[0].preview_library_path if cover_from_card else "%s/%s/deck_cover.png" % [OTHER,PUBLISHED]},"cards":cards})
		"qse_deck_review_decide":
			if fail_decision: return ServiceResult.failure("network")
			if review_status!="pending_review": return ServiceResult.success({"error":"invalid_status"})
			decisions+=1
			review_status="published" if params.p_approved else "rejected"
			review_note="" if params.p_approved else str(params.p_reason)
			return ServiceResult.success({"deck_id":params.p_deck,"status":review_status,"review_note":null if params.p_approved else review_note})
	return ServiceResult.failure("unknown_rpc")
