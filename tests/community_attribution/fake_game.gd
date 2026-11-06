extends "res://tests/community_t27/fake_game.gd"
## Published-only, cursor-paginated public catalogue. No HTTP or database.
var rows: Array=[]
var fail_page := false
var repeat_cursor := false
var page_calls: Array=[]
func _ready() -> void:
	super._ready()
	for i in 60:
		rows.append({"id":PUBLISHED if i==59 else "00000000-0000-4000-8000-"+str(2000+i).pad_zeros(12),"name":"[TESTE] Rappers" if i==59 else "Deck público "+str(i),"description":"Fixture","category":"Personagens","card_count":5,"status":"pending_review" if i==59 else "published","visibility":"private" if i==59 else "public","creator":{"nickname":"Usuário X" if i==59 else "Outro criador"},"cover_path":"%s/%s/deck_cover.png" % [OTHER,PUBLISHED] if i==59 else null})
	var texture := load("res://assets/duel/decks/oficial/lendas_urbanas/momo.png") as Texture2D
	files["%s/%s/deck_cover.png" % [OTHER,PUBLISHED]]=texture.get_image().save_png_to_buffer()
func call_rpc(name: String, params: Dictionary={}) -> Dictionary:
	if name=="qse_community_decks":
		await get_tree().process_frame
		page_calls.append(params.duplicate(true))
		if params.p_cursor!=null and fail_page: return ServiceResult.failure("network")
		var visible := rows.filter(func(r:Dictionary)->bool:return r.status=="published" and r.visibility=="public")
		var offset := 0 if params.p_cursor==null else 48
		var next: Variant="next-page" if visible.size()>offset+48 or (repeat_cursor and params.p_cursor!=null) else null
		return ServiceResult.success({"items":visible.slice(offset,offset+48),"next_cursor":next})
	var result: Dictionary=await super.call_rpc(name,params)
	if name=="qse_community_deck" and result.ok and not result.data.has("error"):
		if rows.back().status!="published": return ServiceResult.success({"error":"deck_not_found"})
		result.data.deck.name=rows.back().name
		result.data.deck.creator.nickname=rows.back().creator.nickname
	return result
