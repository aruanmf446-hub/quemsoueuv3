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
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_refresh()

@onready var _icon_rect: TextureRect = $Padding/Content/Icon
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
	_icon_rect.texture = icon_texture
	_icon_rect.visible = icon_texture != null

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
