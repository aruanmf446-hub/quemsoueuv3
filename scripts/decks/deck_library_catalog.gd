extends RefCounted
## Read-only local catalog. Discovery lists public decks only; private content is never exposed.
const ROOT := "res://assets/duel/decks"
const OFFICIAL_IDS := ["lendas_urbanas"]
const MIN_CARDS := 5
const MAX_CARDS := 30

static func search_key(value: String) -> String:
	var result := value.strip_edges().to_lower()
	var accents := {"a": "áàâãä", "e": "éèêë", "i": "íìîï", "o": "óòôõö", "u": "úùûü", "c": "ç"}
	for plain: String in accents:
		for letter: String in str(accents[plain]): result = result.replace(letter, plain)
	return result

static func decks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for folder in DirAccess.get_directories_at(ROOT):
		var deck := find_deck(folder)
		if not deck.is_empty() and deck.visibility == "public": result.append(deck)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return search_key(a.name).naturalnocasecmp_to(search_key(b.name)) < 0)
	return result

static func find_deck(id: String) -> Dictionary:
	if not DirAccess.get_directories_at(ROOT).has(id): return {}
	return _parse_deck(id, _read_json("%s/%s/deck.json" % [ROOT, id]))

static func _parse_deck(id: String, info: Dictionary) -> Dictionary:
	if info.is_empty() or not info.get("cards") is Dictionary: return {}
	var official := OFFICIAL_IDS.has(id)
	var visibility := str(info.get("visibility", "public" if official else "private"))
	if not visibility in ["public", "unlisted"]: return {}
	var entries := cards(id, info)
	# A broken image must not silently turn a nine-card collection into eight cards.
	if entries.size() != info.cards.size() or entries.size() < MIN_CARDS or entries.size() > MAX_CARDS: return {}
	var age := str(info.get("age_rating", ""))
	if not age in ["L", "10", "12", "14", "16", "18"]: age = ""
	# Nome/descrição do CATALOG remoto, quando houver; as cartas continuam sendo os assets locais.
	var remote: Dictionary = PlayerServices.current.catalog.deck(id) if PlayerServices.current != null and PlayerServices.current.catalog != null else {}
	return {
		"id": id, "name": _string(remote.get("name", info.get("name", "")), id.replace("_", " ").capitalize()),
		"official": official, "creator": "Quem Sou Eu" if official else _string(info.get("creator", "")),
		"category": _string(info.get("category", "")), "description": _string(remote.get("description", info.get("description", ""))),
		"tags": _strings(info.get("tags", []), 3), "age_rating": age,
		"content_warnings": _strings(info.get("content_warnings", [])),
		"cards": entries, "count": entries.size(), "origin": "local", "visibility": visibility,
		"original_language": _string(info.get("original_language", ""))
	}

static func cards(folder: String, info: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var definitions: Dictionary = info.get("cards", {})
	for card_id in definitions:
		if not card_id is String or not str(card_id).is_valid_filename(): continue
		var definition: Variant = definitions[card_id]
		var name := _string(definition.get("name", "")) if definition is Dictionary else _string(definition)
		var path := "%s/%s/%s.png" % [ROOT, folder, card_id]
		if name.is_empty() or not ResourceLoader.exists(path, "Texture2D"): continue
		entries.append({"id": "%s/%s" % [folder, card_id], "name": name, "image": path,
			"description": _string(definition.get("description", "")) if definition is Dictionary else _description(info, card_id)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var comparison := search_key(a.name).naturalnocasecmp_to(search_key(b.name))
		return str(a.id) < str(b.id) if comparison == 0 else comparison < 0)
	return entries

static func _description(info: Dictionary, card_id: String) -> String:
	var descriptions: Variant = info.get("descriptions", {})
	return _string(descriptions.get(card_id, "")) if descriptions is Dictionary else ""

static func _string(value: Variant, fallback := "") -> String:
	return value.strip_edges() if value is String and not value.strip_edges().is_empty() else fallback

static func _strings(value: Variant, limit := 30) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			var text := _string(entry)
			if not text.is_empty() and not result.has(text) and result.size() < limit: result.append(text)
	return result

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
