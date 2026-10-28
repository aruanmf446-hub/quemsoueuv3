extends Control

## Seleção de personagens pelo botão Skins. Cada cartão vem do catálogo local,
## então novos personagens aparecem sem alterar esta cena.

signal character_selected(character_id: StringName)

const CARD_MIN_SIZE := Vector2(236, 132)
const CARD_TEXTURE := preload("res://assets/processed/textures/textura_azul.png")

@onready var _grid: GridContainer = $Frame/Grid
@onready var _close_button: Button = $Frame/CloseButton
@onready var _dim: ColorRect = $Dim


func _ready() -> void:
	_close_button.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)
	for entry: Dictionary in CharacterCatalog.load_entries():
		_grid.add_child(_make_card(entry))
	close()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _make_card(entry: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.text = entry["name"]
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _card_style(Color.WHITE))
	card.add_theme_stylebox_override("hover", _card_style(Color(1.15, 1.15, 1.15)))
	card.add_theme_stylebox_override("pressed", _card_style(Color(0.8, 0.8, 0.8)))
	card.add_theme_stylebox_override("focus", _card_style(Color.WHITE))
	card.add_theme_font_size_override("font_size", 26)
	card.add_theme_color_override("font_color", Color("#ffffff"))
	card.add_theme_color_override("font_outline_color", Color("#0a1630"))
	card.add_theme_constant_override("outline_size", 6)
	card.pressed.connect(_on_card_pressed.bind(StringName(entry["id"])))
	return card


func _card_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = CARD_TEXTURE
	style.modulate_color = tint
	return style


func _on_card_pressed(character_id: StringName) -> void:
	character_selected.emit(character_id)
	close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()
