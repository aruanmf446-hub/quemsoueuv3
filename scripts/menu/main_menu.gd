extends Control

signal option_selected(option_id: StringName)

@onready var _menu_buttons: VBoxContainer = $MenuButtons
@onready var _lobby_area: Control = $LobbyArea
@onready var _skins_panel: Control = $SkinsPanel


func _ready() -> void:
	for child in _menu_buttons.get_children():
		if child is MenuCardButton:
			child.activated.connect(_on_menu_button_activated)
	_skins_panel.character_selected.connect(_on_skin_selected)
	_skins_panel.progress_changed.connect(_lobby_area.revalidate)


func _on_menu_button_activated(button_id: StringName) -> void:
	option_selected.emit(button_id)
	if button_id == &"skins":
		_skins_panel.open(String(_lobby_area.current_character_id()))


func _on_skin_selected(character_id: StringName) -> void:
	_lobby_area.select_character(String(character_id))
