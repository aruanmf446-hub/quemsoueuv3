@tool
class_name FriendRow
extends HBoxContainer

@export var friend_name: String = "":
	set(value):
		friend_name = value
		_refresh()
@export var status_text: String = "":
	set(value):
		status_text = value
		_refresh()
@export var status_color: Color = Color("#3ddc5c"):
	set(value):
		status_color = value
		_refresh()
@export var badge_color: Color = Color("#4a8fd8"):
	set(value):
		badge_color = value
		_refresh()

@onready var _name_label: Label = $Info/Name
@onready var _status_label: Label = $Info/StatusRow/Status
@onready var _status_dot: ColorRect = $Info/StatusRow/Dot
@onready var _badge: Panel = $Badge


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	_name_label.text = friend_name
	_status_label.text = status_text
	_status_label.add_theme_color_override("font_color", status_color)
	_status_dot.color = status_color
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = badge_color.darkened(0.5)
	badge_style.border_color = badge_color
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(8)
	_badge.add_theme_stylebox_override("panel", badge_style)
