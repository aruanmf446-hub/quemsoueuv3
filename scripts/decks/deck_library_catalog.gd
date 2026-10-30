extends RefCounted
## Catálogo somente leitura. Não consulta Supabase e não altera decks.
## Um deck é uma pasta em res://assets/duel/decks com deck.json e PNGs.
const ROOT := "res://assets/duel/decks"
const OFFICIAL_IDS := ["lendas_urbanas"]

static func decks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for folder in DirAccess.get_directories_at(ROOT):
		var info := _read_json("%s/%s/deck.json" % [ROOT, folder])
		if info.is_empty() or not info.get("cards") is Dictionary:
			continue
		var entries := cards(folder, info)
		if entries.is_empty():
			continue
		result.append({
			"id": folder,
			"name": str(info.get("name", folder.replace("_", " ").capitalize())),
			"official": OFFICIAL_IDS.has(folder),
			"creator": "Quem Sou Eu" if OFFICIAL_IDS.has(folder) else str(info.get("creator", "")),
			"category": str(info.get("category", "")),
			"description": str(info.get("description", "")),
			"tags": info.get("tags", []),
			"cards": entries,
			"count": entries.size(),
			"origin": "local"
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return result

static func cards(folder: String, info: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var definitions: Dictionary = info.get("cards", {})
	for card_id in definitions:
		var card_name := str(definitions[card_id])
		var path := "%s/%s/%s.png" % [ROOT, folder, str(card_id)]
		if not ResourceLoader.exists(path):
			continue
		entries.append({
			"id": "%s/%s" % [folder, card_id],
			"name": card_name,
			"image": path,
			"description": _description(info, str(card_id))
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
	return entries

static func _description(info: Dictionary, card_id: String) -> String:
	var descriptions: Variant = info.get("descriptions", {})
	if descriptions is Dictionary:
		return str(descriptions.get(card_id, ""))
	return ""

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
