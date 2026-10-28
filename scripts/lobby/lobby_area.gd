extends Control

## Área do lobby: palco 3D + setas de troca + nome do personagem.
## Só personagens desbloqueados podem ser equipados. Setas percorrem apenas os liberados.
## A última escolha válida é salva em user:// e restaurada na próxima abertura.

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
var _current_id: String = ""


func _ready() -> void:
	_entries = CharacterCatalog.load_entries()
	_prev_button.pressed.connect(step.bind(-1))
	_next_button.pressed.connect(step.bind(1))
	var unlocked := _unlocked_entries()
	if unlocked.is_empty():
		_name_label.text = "Sem personagens"
		_prev_button.disabled = true
		_next_button.disabled = true
		return
	var saved_id := _load_saved_id()
	var start := _position_of(unlocked, saved_id)
	show_index(maxi(start, 0))


func step(delta: int) -> void:
	var unlocked := _unlocked_entries()
	if unlocked.is_empty():
		return
	var current := _position_of(unlocked, _current_id)
	show_index(posmod(maxi(current, 0) + delta, unlocked.size()))


## Equipa o personagem se estiver desbloqueado. Retorna false em caso de bloqueio.
func select_character(character_id: String) -> bool:
	var entry := _find_entry(character_id)
	if entry.is_empty():
		return false
	if not PlayerProgress.is_unlocked(entry):
		push_warning("Personagem bloqueado, não pode ser equipado: %s" % character_id)
		return false
	show_index(_position_of(_unlocked_entries(), character_id))
	return true


## Chamado quando o progresso muda. Se o personagem equipado ficou bloqueado,
## volta ao primeiro personagem liberado.
func revalidate() -> void:
	var entry := _find_entry(_current_id)
	if entry.is_empty() or PlayerProgress.is_unlocked(entry):
		return
	var unlocked := _unlocked_entries()
	if unlocked.is_empty():
		return
	show_index(0)


func current_character_id() -> StringName:
	return StringName(_current_id)


func show_index(index: int) -> void:
	var unlocked := _unlocked_entries()
	if index < 0 or index >= unlocked.size():
		return
	_index = index
	var entry: Dictionary = unlocked[index]
	_current_id = entry["id"]
	_stage.show_character(entry)
	_name_label.text = entry["name"]
	_save_selected_id(_current_id)
	character_changed.emit(StringName(_current_id))


func _unlocked_entries() -> Array:
	var result: Array = []
	for entry: Dictionary in _entries:
		if PlayerProgress.is_unlocked(entry):
			result.append(entry)
	return result


func _find_entry(character_id: String) -> Dictionary:
	var index := CharacterCatalog.index_of(_entries, character_id)
	return _entries[index] if index >= 0 else {}


func _position_of(list: Array, character_id: String) -> int:
	for i in list.size():
		if list[i]["id"] == character_id:
			return i
	return 0


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
