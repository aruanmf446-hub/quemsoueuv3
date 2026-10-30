class_name CatalogService
extends Node
## Leitura pública do CATALOG (public.qse_catalog_characters, qse_catalog_decks,
## qse_catalog_cards) pela conexão "catalog", sem sessão: o JWT do GAME nunca vai para lá.
## Os assets continuam locais. O remoto só complementa o que existe no jogo (nome e
## descrição de decks); sem rede, sem chave ou com resposta inválida, vale o catálogo local.

signal changed

const TABLES := {"characters": "qse_catalog_characters", "decks": "qse_catalog_decks", "cards": "qse_catalog_cards"}
const DECKS_ROOT := "res://assets/duel/decks"
## Cache em disco: o catálogo muda raramente; dentro deste prazo nenhuma consulta é feita.
const CACHE_PATH := "user://catalog_cache.json"
const CACHE_TTL := 6 * 3600.0
var client: SupabaseClient
## "local" (só assets), "loading" ou "remote" (catálogo remoto aplicado).
var state := "local"
var characters: Dictionary = {}
var decks: Dictionary = {}
## deck_id -> ids de carta "<deck>/<carta>" do remoto.
var deck_cards: Dictionary = {}


## Usa o cache se tiver menos de CACHE_TTL (ou se force for falso e a rede falhar).
func refresh(force := false) -> Dictionary:
	var cached := _read_cache()
	if not force and not cached.is_empty() and now() - float(cached.get("saved_at", 0.0)) < CACHE_TTL:
		apply(cached.characters, cached.decks, cached.cards)
		return ServiceResult.success({"cache": true})
	if client == null or not client.configured():
		_clear()
		return ServiceResult.failure("not_configured", "offline")
	state = "loading"
	var rows := {}
	for key: String in TABLES:
		var result := await client.request("/rest/v1/%s?select=*" % TABLES[key], HTTPClient.METHOD_GET, {}, false)
		if not result.ok or not result.data is Array:
			# Sem rede: o último cache (mesmo vencido) é melhor que nada; senão, o local.
			if not cached.is_empty(): apply(cached.characters, cached.decks, cached.cards)
			else: _clear()
			return result if not result.ok else ServiceResult.failure("invalid_contract")
		rows[key] = result.data
	apply(rows.characters, rows.decks, rows.cards)
	_write_cache(rows)
	return ServiceResult.success({"characters": characters.size(), "decks": decks.size()})


## Valida e guarda as linhas. Linha sem id texto é descartada; nada substitui asset local.
func apply(character_rows: Array, deck_rows: Array, card_rows: Array) -> void:
	_clear()
	for row: Variant in character_rows:
		var id := _id(row, ["id", "slug", "character_id"])
		if not id.is_empty(): characters[id] = _meta(row)
	for row: Variant in deck_rows:
		var id := _id(row, ["id", "slug", "deck_id"])
		if not id.is_empty():
			decks[id] = _meta(row)
			deck_cards[id] = []
	for row: Variant in card_rows:
		var card := card_id(row)
		if card.is_empty(): continue
		var deck := card.get_slice("/", 0)
		if deck_cards.has(deck) and not (deck_cards[deck] as Array).has(card): (deck_cards[deck] as Array).append(card)
	for id: String in deck_cards: (deck_cards[id] as Array).sort()
	state = "remote" if not (characters.is_empty() and decks.is_empty()) else "local"
	changed.emit()


## Metadados remotos de um deck que existe no jogo ({} se não houver).
func deck(id: String) -> Dictionary:
	return decks.get(id, {}) if state == "remote" else {}


## Compara cada deck remoto com as cartas locais (assets/duel/decks). Os RPCs do Duelo ainda
## usam qse_v3.duel_decks no GAME; um deck só é compatível se as cartas forem as mesmas.
func compatibility() -> Dictionary:
	var report := {}
	for id: String in deck_cards:
		var local := local_cards(id)
		var remote: Array = deck_cards[id]
		report[id] = {"compatible": not local.is_empty() and local == remote,
			"missing_locally": remote.filter(func(c: String) -> bool: return not local.has(c)),
			"missing_remotely": local.filter(func(c: String) -> bool: return not remote.has(c))}
	return report


static func local_cards(deck: String) -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute("%s/%s" % [DECKS_ROOT, deck]): return result
	for file: String in DirAccess.get_files_at("%s/%s" % [DECKS_ROOT, deck]):
		var stem := file.trim_suffix(".import").trim_suffix(".remap")
		if stem.ends_with(".png") and not result.has("%s/%s" % [deck, stem.trim_suffix(".png")]):
			result.append("%s/%s" % [deck, stem.trim_suffix(".png")])
	result.sort()
	return result


## Carta como "<deck>/<carta>": aceita o id já composto ou deck_id + id/slug.
static func card_id(row: Variant) -> String:
	var id := _id(row, ["card_id", "id", "slug"])
	if id.is_empty(): return ""
	if id.contains("/"): return id
	var deck := _id(row, ["deck_id", "deck"])
	return "" if deck.is_empty() else "%s/%s" % [deck, id]


static func _id(row: Variant, keys: Array) -> String:
	if not row is Dictionary: return ""
	for key: String in keys:
		var value: Variant = (row as Dictionary).get(key)
		if value is String and not (value as String).strip_edges().is_empty(): return (value as String).strip_edges()
	return ""


static func _meta(row: Dictionary) -> Dictionary:
	var result := {}
	for key in ["name", "description"]:
		if row.get(key) is String and not (row[key] as String).strip_edges().is_empty(): result[key] = (row[key] as String).strip_edges()
	return result


func now() -> float:
	return Time.get_unix_time_from_system()


func _read_cache() -> Dictionary:
	if not FileAccess.file_exists(CACHE_PATH): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if not parsed is Dictionary: return {}
	for key in ["characters", "decks", "cards"]:
		if not (parsed as Dictionary).get(key) is Array: return {}
	return parsed


func _write_cache(rows: Dictionary) -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"saved_at": now(), "characters": rows.characters, "decks": rows.decks, "cards": rows.cards}))


func _clear() -> void:
	state = "local"
	characters = {}
	decks = {}
	deck_cards = {}
