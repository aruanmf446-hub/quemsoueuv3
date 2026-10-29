extends Control
## Multitoque real e alvos em pixels físicos; não depende da emulação de mouse.
const ACTIONS := ["move_left", "move_right", "crouch", "defend", "attack", "jump"]
const LABELS := ["‹", "›", "↓", "DEF", "ATQ", "↑"]
var _areas: Array[Rect2] = []
var _held := {}
var actor: Node
var _font: FontFile
var _last_pixels := Vector2i.ZERO
func _ready() -> void:
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("android") or get_window().size.y < 600 or "--touch-controls" in OS.get_cmdline_user_args()
func _draw() -> void:
	if not visible: return
	_areas.clear()
	var screen := get_viewport_rect().size
	var unit := screen.y / maxf(get_window().size.y,1)
	var radius := 26.0*unit
	var space := 62.0*unit
	var bottom := screen.y - 42*unit
	var points := [Vector2(42*unit,bottom),Vector2(42*unit+space,bottom),Vector2(screen.x-42*unit-space,bottom-space),Vector2(screen.x-42*unit,bottom-space),Vector2(screen.x-42*unit-space,bottom),Vector2(screen.x-42*unit,bottom)]
	for index in range(ACTIONS.size()):
		var point: Vector2 = points[index]
		_areas.append(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2))
		var down := _held.values().has(ACTIONS[index])
		var empty: bool = is_instance_valid(actor) and ((index == 4 and actor.attack_charges == 0) or (index == 3 and actor.defense_charges == 0))
		draw_circle(point,radius,Color(0.04,0.09,0.15,0.74) if not down else Color(0.48,0.32,0.11,0.8))
		draw_arc(point,radius,0,TAU,40,Color(0.95,0.80,0.48,0.7),1.5*unit,true)
		var font := _font
		var font_size := int((14 if index in [3,4] else 27)*unit)
		var label: String = LABELS[index]
		if empty: label += " 0"
		var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,point+Vector2(-width*.5,font_size*.35),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#a4a8ad") if empty else Color("#f5e4bd"))
func _process(_delta: float) -> void:
	var pixels := get_window().size
	if pixels != _last_pixels:
		_last_pixels = pixels
		visible = DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("web") or pixels.y < 600 or "--touch-controls" in OS.get_cmdline_user_args()
		if not visible:
			for index in _held.keys(): _release(index)
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventScreenTouch:
		if event.pressed: _press(event.index,event.position)
		else: _release(event.index)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _press(-1,event.position)
		else: _release(-1)
	elif event is InputEventScreenDrag:
		var action := _action_at(event.position)
		if _held.get(event.index,"") != action:
			_release(event.index)
			_press(event.index,event.position)
func _action_at(point: Vector2) -> String:
	for index in range(_areas.size()):
		if _areas[index].has_point(point): return ACTIONS[index]
	return ""
func _press(index: int, point: Vector2) -> void:
	var action := _action_at(point)
	if action.is_empty(): return
	_held[index] = action
	Input.action_press(action)
	get_viewport().set_input_as_handled()
func _release(index: int) -> void:
	if not _held.has(index): return
	var action: String = _held[index]
	_held.erase(index)
	if not _held.values().has(action): Input.action_release(action)
func _exit_tree() -> void:
	release_all()
func release_all() -> void:
	for index in _held.keys(): _release(index)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_all()
