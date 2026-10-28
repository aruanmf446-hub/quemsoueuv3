class_name InventoryService
extends Node

signal changed
var progression: ProgressionService
var session: SessionService
var entries: Array = []
var demo_equipped := "cowboy"
const DEMO_PATH := "user://player_demo_v2.cfg"


func initialize() -> void:
	entries = CharacterCatalog.load_entries()
	var config := ConfigFile.new()
	var loaded := config.load(DEMO_PATH)
	if loaded != OK:
		# Somente seleção inicial é legível do arquivo antigo; flags nunca são importadas.
		config.load("user://lobby.cfg")
	var candidate := str(config.get_value("demo" if loaded == OK else "lobby", "character_id", "cowboy"))
	if candidate in PlayerContracts.initial_ids():
		demo_equipped = candidate
	progression.changed.connect(func() -> void: changed.emit())


func is_unlocked(character_id: String) -> bool:
	if session.authenticated():
		return progression.state == "success" and character_id in progression.data.get("unlocked_character_ids", [])
	return character_id in PlayerContracts.initial_ids()


func equipped_id() -> String:
	if session.authenticated():
		return str(progression.data.get("equipped_character_id", "")) if progression.state == "success" else ""
	return demo_equipped


func equip(character_id: String) -> Dictionary:
	if not is_unlocked(character_id):
		return ServiceResult.failure("locked_character", "unauthorized")
	if session.authenticated():
		return await progression.equip(character_id)
	var config := ConfigFile.new()
	config.set_value("demo", "character_id", character_id)
	if config.save(DEMO_PATH) != OK:
		return ServiceResult.failure("local_save_failed")
	demo_equipped = character_id
	changed.emit()
	return ServiceResult.success({"mode": "local_demo", "equipped_character_id": character_id})


func entry(character_id: String) -> Dictionary:
	var index := CharacterCatalog.index_of(entries, character_id)
	return entries[index] if index >= 0 else {}
