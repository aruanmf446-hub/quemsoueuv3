class_name CharacterCatalog
extends RefCounted

## Lê o catálogo local em data/characters.json, separado em três grupos:
## - playable: personagens jogáveis, sempre disponíveis.
## - unlockable: personagens equipáveis somente após o desbloqueio em `unlock`.
## - story_villains: vilões e chefes do Modo História. Nunca são equipáveis.
## Para migrar para Supabase/R2, substitua apenas estas funções por uma fonte remota
## que devolva o mesmo formato de Dictionary.

const CATALOG_PATH := "res://data/characters.json"


## Retorna todos os grupos do catálogo: {"playable", "unlockable", "story_villains"}.
static func load_all() -> Dictionary:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de personagens ausente: %s" % CATALOG_PATH)
		return {"playable": [], "unlockable": [], "story_villains": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Catálogo de personagens inválido: %s" % CATALOG_PATH)
		return {"playable": [], "unlockable": [], "story_villains": []}
	return {
		"playable": parsed.get("playable", []),
		"unlockable": parsed.get("unlockable", []),
		"story_villains": parsed.get("story_villains", []),
	}


## Personagens que podem aparecer no lobby e nas Skins (jogáveis + desbloqueáveis).
static func load_entries() -> Array:
	var groups := load_all()
	var equippable: Array = []
	equippable.append_array(groups["playable"])
	equippable.append_array(groups["unlockable"])
	return equippable


static func index_of(entries: Array, character_id: String) -> int:
	for i in entries.size():
		if entries[i]["id"] == character_id:
			return i
	return -1
