extends "res://tests/decks_t21/fake_game.gd"
## FIXTURE DE TESTE (T27): RPCs da Comunidade no formato validado com contas reais (E2E).
## Um deck [DEMO] de outro jogador já publicado; denúncias, publicação e retirada simuladas.
const OTHER := "00000000-0000-4000-8000-0000000000ee"
const PUBLISHED := "11111111-2222-4333-8444-555555555555"
var reports := {}
var rpc_calls: Array = []


func _ready() -> void:
	var image := Image.create(100, 140, false, Image.FORMAT_RGB8)
	image.fill(Color.DARK_SLATE_BLUE)
	for i in 5: files["%s/%s/c%d_library.png" % [OTHER, PUBLISHED, i]] = image.save_png_to_buffer()
	files["%s/%s/deck_cover.png" % [OTHER, PUBLISHED]] = image.save_png_to_buffer()


func send(path: String, method: HTTPClient.Method, body: Variant = null, headers := PackedStringArray(), raw := PackedByteArray(), type := "", timeout := 30.0) -> Dictionary:
	# Prévias/capa publicadas: legíveis por qualquer conta autenticada; o original, não.
	var prefix := "/storage/v1/object/authenticated/qse-deck-originals/%s/" % OTHER
	if path.begins_with(prefix) and method == HTTPClient.METHOD_GET:
		await get_tree().process_frame
		var key := path.trim_prefix("/storage/v1/object/authenticated/qse-deck-originals/")
		if key.ends_with("_original.png") or not files.has(key): return ServiceResult.failure("not_found")
		return ServiceResult.success({"status": 200, "data": null, "bytes": files[key]})
	if path.begins_with("/rest/v1/qse_creator_decks?select=id,status,review_note"):
		await get_tree().process_frame
		var rows: Array = db.qse_creator_decks.filter(func(r: Dictionary) -> bool: return str(r.owner_id) == user).map(func(r: Dictionary) -> Dictionary: return {"id": r.id, "status": r.get("status", "draft"), "review_note": r.get("review_note")})
		return _ok(rows)
	return await super.send(path, method, body, headers, raw, type, timeout)


func call_rpc(name: String, params: Dictionary = {}) -> Dictionary:
	await get_tree().process_frame
	rpc_calls.append([name, params.duplicate()])
	var creator := {"public_id": "QSE-DEMO", "nickname": "[DEMO] Criadora", "equipped_character_id": "cowboy", "level": 3}
	match name:
		"qse_community_decks":
			return ServiceResult.success({"items": [{"id": PUBLISHED, "name": "[DEMO] Deck da Comunidade", "description": "Fixture", "category": "Folclore",
				"card_count": 5, "cover_path": "%s/%s/deck_cover.png" % [OTHER, PUBLISHED], "creator": creator, "published_at": "2026-11-01T10:00:00Z", "score": 4}], "next_cursor": null})
		"qse_community_deck":
			if params.p_deck != PUBLISHED: return ServiceResult.success({"error": "deck_not_found"})
			var cards := []
			for i in 5: cards.append({"name": "[DEMO] Carta %d" % i, "description": "", "preview_library_path": "%s/%s/c%d_library.png" % [OTHER, PUBLISHED, i],
				"preview_duel_path": "%s/%s/c%d_duel.png" % [OTHER, PUBLISHED, i], "crops": {"library": {"center_x": 0.5, "center_y": 0.5, "zoom": 1}}})
			return ServiceResult.success({"deck": {"id": PUBLISHED, "name": "[DEMO] Deck da Comunidade", "description": "Fixture", "category": "Folclore", "card_count": 5, "published_at": "2026-11-01T10:00:00Z", "creator": creator}, "cards": cards})
		"qse_deck_report":
			if reports.has(user): return ServiceResult.success({"error": "already_reported"})
			reports[user] = true
			return ServiceResult.success({"reported": true, "deck_id": params.p_deck, "status": "published", "report_count": reports.size()})
		"qse_deck_publish_request":
			for row: Dictionary in db.qse_creator_decks:
				if row.id == params.p_deck and row.owner_id == user:
					if db.qse_creator_cards.filter(func(c: Dictionary) -> bool: return c.deck_id == row.id).size() < 5: return ServiceResult.success({"error": "min_cards", "minimum": 5})
					row.status = "pending_review"
					return ServiceResult.success({"deck_id": row.id, "status": "pending_review"})
			return ServiceResult.success({"error": "deck_not_found"})
		"qse_deck_unpublish":
			for row: Dictionary in db.qse_creator_decks:
				if row.id == params.p_deck and row.owner_id == user:
					row.status = "draft"
					return ServiceResult.success({"deck_id": row.id, "status": "draft"})
			return ServiceResult.success({"error": "deck_not_found"})
	return ServiceResult.failure("unknown_rpc")
