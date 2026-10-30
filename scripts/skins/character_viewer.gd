class_name CharacterViewer
extends Control

## Visualização ampliada de um personagem da tela Skins. Usa o mesmo LobbyStage do lobby
## (mesma renderização e iluminação), com rotação e zoom. Nunca altera o personagem equipado:
## o botão Equipar só fica ativo se o personagem estiver desbloqueado.

signal equip_requested(character_id: StringName)
signal closed

const STAGE_SCENE := preload("res://scenes/lobby/lobby_stage.tscn")

var _entry: Dictionary = {}
var _stage: LobbyStage
var _name_label: Label
var _status_label: Label
var _equip_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open(entry: Dictionary) -> void:
	_entry = entry
	_stage.show_character(entry)
	_name_label.text = entry["name"]
	var unlocked := PlayerProgress.is_unlocked(entry)
	_status_label.text = "Desbloqueado" if unlocked else "Bloqueado: %s" % PlayerProgress.lock_label(entry)
	_equip_button.disabled = not unlocked
	_equip_button.text = "Equipar" if unlocked else "Bloqueado"
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", PlayerUI.frame_panel(24))
	panel.custom_minimum_size = Vector2(900, 790)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28
	column.offset_top = 28
	column.offset_right = -28
	column.offset_bottom = -28
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	_name_label = _make_label(34, Color("#ffd34d"))
	column.add_child(_name_label)

	_stage = STAGE_SCENE.instantiate() as LobbyStage
	_stage.interactive = true
	_stage.custom_minimum_size = Vector2(560, 380)
	column.add_child(_stage)

	_status_label = _make_label(18, Color("#e8f4ff"))
	column.add_child(_status_label)

	var hint := _make_label(15, Color("#b8d4f0"))
	hint.text = "Arraste para girar · roda do mouse ou pinça para aproximar"
	column.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)

	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(200, 52)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	row.add_child(back)

	_equip_button = Button.new()
	_equip_button.custom_minimum_size = Vector2(200, 52)
	_equip_button.focus_mode = Control.FOCUS_NONE
	_equip_button.pressed.connect(_on_equip_pressed)
	row.add_child(_equip_button)


func _on_equip_pressed() -> void:
	if _entry.is_empty() or not PlayerProgress.is_unlocked(_entry):
		return
	equip_requested.emit(StringName(_entry["id"]))
	close()


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#0a1630"))
	label.add_theme_constant_override("outline_size", 6)
	return label
