class_name DeckDrafts
extends RefCounted
## Rascunhos de deck e favoritos do dono atual, salvos NESTE aparelho (user://players/<dono>/).
## Publicar, sincronizar e favoritar no servidor dependem do backend (docs/contracts/T21_DECKS.md):
## enquanto ele não existir, publish() responde "backend_pending" e nada finge estar online.
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
const NAME_MIN := 3
const NAME_MAX := 60
const DESCRIPTION_MAX := 400
const CARD_NAME_MAX := 40
const CARD_DESCRIPTION_MAX := 300
const VISIBILITY := ["private", "unlisted", "public"]
const CATEGORIES := ["Lendas e terror", "Personagens", "Animais", "Lugares", "Objetos", "Outros"]

var owner := ""


static func for_current() -> DeckDrafts:
	var store := DeckDrafts.new()
	store.owner = OwnerStorage.owner_id()
	return store


func _dir(relative := "") -> String:
	return OwnerStorage.path(owner, "deck_drafts/" + relative)


func new_draft() -> Dictionary:
	var id := "draft_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	return {"id": id, "name": "", "description": "", "category": "", "visibility": "private",
		"cards": [], "status": "draft", "updated_at": 0}


func list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var root := OwnerStorage.folder(owner) + "/deck_drafts"
	if not DirAccess.dir_exists_absolute(root): return result
	for folder in DirAccess.get_directories_at(root):
		var draft := load_draft(folder)
		if not draft.is_empty(): result.append(draft)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.updated_at) > int(b.updated_at))
	return result


func load_draft(id: String) -> Dictionary:
	if not id.is_valid_filename(): return {}
	var path := OwnerStorage.folder(owner) + "/deck_drafts/" + id + "/draft.json"
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or str(parsed.get("id", "")) != id: return {}
	return parsed


## Copia o original sem alterá-lo (para reeditar depois) e devolve o nome do arquivo.
func store_original(draft_id: String, card_id: String, bytes: PackedByteArray, extension: String) -> String:
	if not draft_id.is_valid_filename() or not card_id.is_valid_filename(): return ""
	var file_name := card_id + "_original." + extension
	var file := FileAccess.open(_dir(draft_id + "/" + file_name), FileAccess.WRITE)
	if file == null: return ""
	file.store_buffer(bytes)
	return file_name


func original_image(draft_id: String, card: Dictionary) -> Image:
	var path := OwnerStorage.folder(owner) + "/deck_drafts/" + draft_id + "/" + str(card.get("image_file", ""))
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	return image if image != null and not image.is_empty() else null


## Prévias pequenas (Biblioteca e Duelo) para listas leves em Web/Android.
func store_previews(draft_id: String, card: Dictionary, image: Image) -> void:
	var crops: Dictionary = card.get("crops", {})
	for format: String in ["library", "duel"]:
		var aspect := CardFramer.LIBRARY_ASPECT if format == "library" else CardFramer.DUEL_ASPECT
		var preview := CardFramer.preview(image, aspect, crops.get(format, {}), 360 if format == "library" else 480)
		preview.save_png(_dir(draft_id + "/" + str(card.id) + "_" + format + ".png"))


func preview_path(draft_id: String, card: Dictionary, format := "library") -> String:
	return OwnerStorage.folder(owner) + "/deck_drafts/" + draft_id + "/" + str(card.get("id", "")) + "_" + format + ".png"


func save(draft: Dictionary) -> Dictionary:
	var id := str(draft.get("id", ""))
	if not id.is_valid_filename(): return ServiceResult.failure("invalid_draft")
	draft.updated_at = int(Time.get_unix_time_from_system())
	draft.status = "draft"
	var file := FileAccess.open(_dir(id + "/draft.json"), FileAccess.WRITE)
	if file == null: return ServiceResult.failure("save_failed")
	file.store_string(JSON.stringify(draft, "\t"))
	return ServiceResult.success(draft)


func delete(id: String) -> bool:
	if not id.is_valid_filename(): return false
	var folder := OwnerStorage.folder(owner) + "/deck_drafts/" + id
	if not DirAccess.dir_exists_absolute(folder): return false
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder + "/" + file)
	return DirAccess.remove_absolute(folder) == OK


## Problemas que impedem revisar/publicar. Lista vazia = pronto.
static func problems(draft: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var name := str(draft.get("name", "")).strip_edges()
	if name.length() < NAME_MIN or name.length() > NAME_MAX: result.append("Nome do deck: de %d a %d caracteres." % [NAME_MIN, NAME_MAX])
	if str(draft.get("description", "")).length() > DESCRIPTION_MAX: result.append("Descrição: até %d caracteres." % DESCRIPTION_MAX)
	if not str(draft.get("category", "")) in CATEGORIES: result.append("Escolha uma categoria.")
	if not str(draft.get("visibility", "")) in VISIBILITY: result.append("Escolha a visibilidade.")
	var cards: Array = draft.get("cards", [])
	if cards.size() < Catalog.MIN_CARDS or cards.size() > Catalog.MAX_CARDS:
		result.append("O deck precisa de %d a %d cartas (agora: %d)." % [Catalog.MIN_CARDS, Catalog.MAX_CARDS, cards.size()])
	var names := {}
	for card: Dictionary in cards:
		var card_name := str(card.get("name", "")).strip_edges()
		if card_name.is_empty() or card_name.length() > CARD_NAME_MAX: result.append("Toda carta precisa de nome (até %d caracteres)." % CARD_NAME_MAX)
		elif names.has(Catalog.search_key(card_name)): result.append("Nome de carta repetido: " + card_name)
		names[Catalog.search_key(card_name)] = true
		if str(card.get("description", "")).length() > CARD_DESCRIPTION_MAX: result.append("Descrição de \"%s\": até %d caracteres." % [card_name, CARD_DESCRIPTION_MAX])
		if str(card.get("image_file", "")).is_empty(): result.append("A carta \"%s\" ainda não tem imagem." % card_name)
	var unique: Array[String] = []
	for item in result: if not unique.has(item): unique.append(item)
	return unique


## Publicação real depende do backend (contrato em docs/contracts/T21_DECKS.md).
func publish(_draft: Dictionary) -> Dictionary:
	return ServiceResult.failure("backend_pending")


# --- Favoritos (por dono, neste aparelho) -------------------------------------------

func favorites() -> Array[String]:
	var result: Array[String] = []
	var config := ConfigFile.new()
	if config.load(OwnerStorage.folder(owner) + "/deck_favorites.cfg") == OK:
		for id: Variant in config.get_value("favorites", "deck_ids", []): result.append(str(id))
	return result


func is_favorite(deck_id: String) -> bool:
	return favorites().has(deck_id)


func set_favorite(deck_id: String, value: bool) -> bool:
	var ids := favorites()
	if value and not ids.has(deck_id): ids.append(deck_id)
	if not value: ids.erase(deck_id)
	var config := ConfigFile.new()
	config.set_value("favorites", "deck_ids", ids)
	return config.save(OwnerStorage.path(owner, "deck_favorites.cfg")) == OK
