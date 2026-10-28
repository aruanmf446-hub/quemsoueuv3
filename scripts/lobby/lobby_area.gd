extends Control

## Área do lobby: palco 3D + setas de troca + nome do personagem.
## Mantém a última escolha em user:// para restaurar na próxima abertura.

signal character_changed(character_id: StringName)

const SAVE_PATH := "user://lobby.cfg"
const SAVE_SECTION := "lobby"
const SAVE_KEY := "character_id"

@onready var _stage: LobbyStage = $Stage
@onready var _prev_button: Button = $Overlay/PrevButton
@onready var _next_button: Button = $Overlay/NextButton
@onready var _name_label: Label = $Overlay/NameLabel

var _entries: Array = []
var _index: int = 0


func _ready() -> void:
	_entries = CharacterCatalog.load_entries()
	_prev_button.pressed.connect(step.bind(-1))
	_next_button.pressed.connect(step.bind(1))
	if _entries.is_empty():
		_name_label.text = "Sem personagens"
		_prev_button.disabled = true
		_next_button.disabled = true
		return
	var saved_index := CharacterCatalog.index_of(_entries, _load_saved_id())
	show_index(maxi(saved_index, 0))


func step(delta: int) -> void:
	if _entries.is_empty():
		return
	show_index(posmod(_index + delta, _entries.size()))


func select_character(character_id: String) -> void:
	var index := CharacterCatalog.index_of(_entries, character_id)
	if index >= 0:
		show_index(index)


func current_character_id() -> StringName:
	return StringName(_entries[_index]["id"])


func show_index(index: int) -> void:
	_index = index
	var entry: Dictionary = _entries[index]
	_stage.show_character(entry)
	_name_label.text = entry["name"]
	_save_selected_id(entry["id"])
	character_changed.emit(StringName(entry["id"]))


func _save_selected_id(character_id: String) -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, SAVE_KEY, character_id)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Não foi possível salvar a seleção do lobby (erro %d)." % err)


func _load_saved_id() -> String:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return ""
	return config.get_value(SAVE_SECTION, SAVE_KEY, "")
