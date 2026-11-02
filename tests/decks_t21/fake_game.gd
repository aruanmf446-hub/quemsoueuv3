extends SupabaseClient
## FIXTURE DE TESTE: imita a Data API + Storage do GAME com a regra de dono das políticas RLS
## (cada token só lê/escreve linhas e arquivos do próprio usuário). Nenhuma rede.
var db := {"qse_creator_decks": [], "qse_creator_cards": [], "qse_deck_favorites": [], "qse_user_music_selection": []}
var files := {}
var user := ""
var fail_after := -1
var calls := 0
var log: Array[String] = []


func configured() -> bool:
	return true


func send(path: String, method: HTTPClient.Method, body: Variant = null, _headers := PackedStringArray(), raw := PackedByteArray(), _type := "", _timeout := 30.0) -> Dictionary:
	await get_tree().process_frame
	calls += 1
	log.append("%d %s" % [method, path])
	if fail_after >= 0 and calls > fail_after: return ServiceResult.failure("network", "offline")
	if user.is_empty(): return ServiceResult.failure("not_authenticated", "unauthorized")
	if path.begins_with("/storage/v1/object/"):
		return _storage(path, method, body, raw)
	var table := path.trim_prefix("/rest/v1/").get_slice("?", 0)
	var query := path.get_slice("?", 1)
	match method:
		HTTPClient.METHOD_GET:
			return _ok(_visible(table).filter(func(row: Dictionary) -> bool: return _matches(row, query)))
		HTTPClient.METHOD_POST:
			for row: Dictionary in body:
				if not _owns_new(table, row): return ServiceResult.failure("42501", "error")
				var key := _key(table, row)
				var existing := -1
				for i in range(db[table].size()):
					if _key(table, db[table][i]) == key: existing = i
				if existing >= 0:
					if not _owns(table, db[table][existing]): return ServiceResult.failure("42501", "error")
					(db[table][existing] as Dictionary).merge(row, true)
				else:
					db[table].append(row.duplicate(true))
			return _ok([])
		HTTPClient.METHOD_PATCH:
			# FK + trigger do GAME (T24): a carta da capa precisa existir e ser deste deck.
			if body is Dictionary and body.get("cover_card_id") != null:
				var card_ok := false
				for card: Dictionary in db.qse_creator_cards:
					if str(card.id) == str(body.cover_card_id) and query.contains(str(card.get("deck_id"))): card_ok = true
				if not card_ok: return ServiceResult.failure("23503", "error")
			for row: Dictionary in db[table]:
				if _owns(table, row) and _matches(row, query): row.merge(body, true)
			return _ok([])
		HTTPClient.METHOD_DELETE:
			db[table] = db[table].filter(func(row: Dictionary) -> bool: return not (_owns(table, row) and _matches(row, query)))
			return _ok([])
	return ServiceResult.failure("unsupported")


func _storage(path: String, method: HTTPClient.Method, body: Variant, raw: PackedByteArray) -> Dictionary:
	if method == HTTPClient.METHOD_DELETE:
		for item: String in body.prefixes:
			if item.begins_with(user + "/"): files.erase(item)
		return _ok([])
	var key := path.trim_prefix("/storage/v1/object/authenticated/").trim_prefix("/storage/v1/object/").trim_prefix("qse-deck-originals/")
	if not key.begins_with(user + "/"): return ServiceResult.failure("forbidden", "unauthorized")
	if method == HTTPClient.METHOD_GET:
		return ServiceResult.success({"status": 200, "data": null, "bytes": files[key]}) if files.has(key) else ServiceResult.failure("not_found")
	files[key] = raw
	return _ok({})


func _ok(data: Variant) -> Dictionary:
	return ServiceResult.success({"status": 200, "data": data, "bytes": PackedByteArray()})


func _key(table: String, row: Dictionary) -> String:
	match table:
		"qse_deck_favorites": return "%s|%s" % [row.get("user_id"), row.get("deck_ref")]
		"qse_user_music_selection": return str(row.get("user_id"))
	return str(row.get("id"))


func _owns(table: String, row: Dictionary) -> bool:
	match table:
		"qse_creator_decks": return str(row.get("owner_id")) == user
		"qse_creator_cards":
			for deck: Dictionary in db.qse_creator_decks:
				if deck.id == row.get("deck_id"): return str(deck.owner_id) == user
			return false
	return str(row.get("user_id")) == user


func _owns_new(table: String, row: Dictionary) -> bool:
	return _owns(table, row)


func _visible(table: String) -> Array:
	return db[table].filter(func(row: Dictionary) -> bool: return _owns(table, row))


func _matches(row: Dictionary, query: String) -> bool:
	for part in query.split("&"):
		if not part.contains("=") or part.begins_with("select=") or part.begins_with("order=") or part.begins_with("on_conflict="): continue
		var column := part.get_slice("=", 0)
		var rule := part.substr(column.length() + 1).uri_decode()
		if rule.begins_with("eq.") and str(row.get(column)) != rule.substr(3): return false
		if rule.begins_with("not.in.("):
			var ids := rule.trim_prefix("not.in.(").trim_suffix(")").split(",")
			if ids.has(str(row.get(column))): return false
	return true
