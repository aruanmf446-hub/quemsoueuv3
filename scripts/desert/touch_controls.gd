class_name TouchControls
extends Control

## Controles de toque para Android e Web. Cada botão aciona a mesma ação de entrada do
## teclado (move_left, move_right, jump, attack), então a lógica de jogo não muda.
## Visível somente quando há toque disponível ou em Android/Web.

const BUTTON_SIZE := Vector2(96, 96)
const MARGIN := 24.0

const BUTTONS := [
	{"action": "move_left", "label": "<", "anchor": "left", "column": 0},
	{"action": "move_right", "label": ">", "anchor": "left", "column": 1},
	{"action": "attack", "label": "J", "anchor": "right", "column": 1},
	{"action": "jump", "label": "^", "anchor": "right", "column": 0},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _should_show()
	for spec: Dictionary in BUTTONS:
		var button := Button.new()
		button.text = spec["label"]
		button.custom_minimum_size = BUTTON_SIZE
		button.size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 36)
		button.button_down.connect(Input.action_press.bind(spec["action"]))
		button.button_up.connect(Input.action_release.bind(spec["action"]))
		add_child(button)
		_place(button, spec)
	get_viewport().size_changed.connect(_relayout)


func _should_show() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("web")


func _place(button: Button, spec: Dictionary) -> void:
	var size := get_viewport_rect().size
	var x: float = MARGIN + spec["column"] * (BUTTON_SIZE.x + MARGIN)
	if spec["anchor"] == "right":
		x = size.x - MARGIN - BUTTON_SIZE.x - spec["column"] * (BUTTON_SIZE.x + MARGIN)
	button.position = Vector2(x, size.y - BUTTON_SIZE.y - MARGIN)


func _relayout() -> void:
	var buttons := get_children()
	for i in buttons.size():
		_place(buttons[i], BUTTONS[i])
