@tool
class_name MenuCardButton
extends Button

signal activated(button_id: StringName)

@export var button_id: StringName = &""
@export var title: String = "":
	set(value):
		title = value
		_refresh()
@export var subtitle: String = "":
	set(value):
		subtitle = value
		_refresh()
@export var accent_color: Color = Color("#d4a017"):
	set(value):
		accent_color = value
		_refresh()
## Arte completa do botão (moldura, ícone e texto já desenhados). Quando definida,
## substitui o fundo procedural e oculta os rótulos de fallback.
@export var art_texture: Texture2D:
	set(value):
		art_texture = value
		_refresh()

@onready var _content: Control = $Padding
@onready var _title_label: Label = $Padding/Content/Text/Title
@onready var _subtitle_label: Label = $Padding/Content/Text/Subtitle


func _ready() -> void:
	pressed.connect(func() -> void: activated.emit(button_id))
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_title_label.text = title
	_subtitle_label.text = subtitle

	if art_texture != null:
		_content.visible = false
		_apply_art_styles()
	else:
		_content.visible = true
		_apply_fallback_styles()


func _apply_art_styles() -> void:
	var normal := _texture_style(Color.WHITE)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", _texture_style(Color(1.12, 1.12, 1.12)))
	add_theme_stylebox_override("pressed", _texture_style(Color(0.82, 0.82, 0.82)))
	add_theme_stylebox_override("focus", normal)


func _texture_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = art_texture
	style.modulate_color = tint
	return style


func _apply_fallback_styles() -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = accent_color.darkened(0.55)
	base.border_color = accent_color
	_set_border(base, 3)
	_set_radius(base, 14)
	add_theme_stylebox_override("normal", base)

	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = accent_color.darkened(0.35)
	add_theme_stylebox_override("hover", hover)

	var pressed_style := base.duplicate() as StyleBoxFlat
	pressed_style.bg_color = accent_color.darkened(0.7)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", base)


func _set_border(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width


func _set_radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
