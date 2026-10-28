class_name CharacterCatalog
extends RefCounted

## Lê o catálogo local de personagens. Cada entrada descreve o modelo rigado,
## altura alvo, animações (nome -> arquivo FBX) e a pose ou idle usados no lobby.
## Para migrar para Supabase/R2, substitua apenas esta função por uma fonte remota
## que devolva o mesmo formato de Dictionary.

const CATALOG_PATH := "res://data/characters.json"


static func load_entries() -> Array:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Catálogo de personagens ausente: %s" % CATALOG_PATH)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Catálogo de personagens inválido: %s" % CATALOG_PATH)
		return []
	return parsed.get("characters", [])


static func index_of(entries: Array, character_id: String) -> int:
	for i in entries.size():
		if entries[i]["id"] == character_id:
			return i
	return -1
