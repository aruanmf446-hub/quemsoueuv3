extends Control

signal option_selected(option_id: StringName)

@onready var _menu_buttons: VBoxContainer = $MenuButtons


func _ready() -> void:
	for child in _menu_buttons.get_children():
		if child is MenuCardButton:
			child.activated.connect(_on_menu_button_activated)


func _on_menu_button_activated(button_id: StringName) -> void:
	option_selected.emit(button_id)
