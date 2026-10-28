extends Control

## O palco original é preservado. Inventário é a única fonte de equipamento.
signal character_changed(character_id: StringName)
@onready var _stage: LobbyStage = $Stage
@onready var _prev_button: Button = $Overlay/PrevButton
@onready var _next_button: Button = $Overlay/NextButton
@onready var _name_label: Label = $Overlay/NameLabel
var _inventory: InventoryService
var _current_id := ""
var _busy := false


func _ready() -> void:
	_inventory = PlayerServices.current.inventory
	_inventory.changed.connect(revalidate)
	_prev_button.pressed.connect(step.bind(-1))
	_next_button.pressed.connect(step.bind(1))
	revalidate()


func revalidate() -> void:
	var character_id := _inventory.equipped_id()
	var entry := _inventory.entry(character_id)
	_prev_button.disabled = entry.is_empty() or _busy
	_next_button.disabled = entry.is_empty() or _busy
	if entry.is_empty():
		_name_label.text = "Equipamento online indisponível"
		return
	_name_label.text = entry.name
	if character_id != _current_id:
		_current_id = character_id
		_stage.show_character(entry)
		character_changed.emit(StringName(_current_id))


func step(delta: int) -> void:
	if _busy:
		return
	var ids: Array = []
	for entry: Dictionary in _inventory.entries:
		if _inventory.is_unlocked(entry.id):
			ids.append(entry.id)
	if ids.is_empty():
		return
	var index := ids.find(_inventory.equipped_id())
	select_character(ids[posmod(maxi(index, 0) + delta, ids.size())])


func select_character(character_id: String) -> bool:
	if _busy:
		return false
	_busy = true
	var result := await _inventory.equip(character_id)
	_busy = false
	revalidate()
	if not result.ok:
		_name_label.text = ServiceResult.message(result)
	return result.ok


func current_character_id() -> StringName:
	return StringName(_inventory.equipped_id())
