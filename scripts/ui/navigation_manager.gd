class_name NavigationManager
extends Control

signal route_changed(route: String)
var _routes: Dictionary = {}
var _screens: Dictionary = {}
var _history: Array[Dictionary] = []
var _active: PlayerScreen
var _transition: Tween
var _previous_focus: WeakRef
var _busy := false
var _error_dialog: AcceptDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_routes = PlayerContracts.read_json("res://data/ui/routes.json").get("routes", {})
	_error_dialog = AcceptDialog.new()
	_error_dialog.dialog_text = "Esta tela não pôde ser carregada. Tente novamente."
	add_child(_error_dialog)


func register_screen(route: String, screen: PlayerScreen) -> void:
	if _screens.has(route):
		return
	_screens[route] = screen
	screen.hide()
	screen.back_requested.connect(back)
	screen.navigate_requested.connect(open)


func open(route: String, params: Dictionary = {}) -> void:
	if _busy or not _routes.has(route):
		return
	if not _history.is_empty() and _history.back() == {"route": route, "params": params}:
		return
	if _history.is_empty():
		_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	if not _screens.has(route):
		var scene := load(_routes[route]) as PackedScene
		if scene == null:
			push_warning("Tela indisponível: %s" % route)
			_error_dialog.popup_centered()
			return
		var screen := scene.instantiate() as PlayerScreen
		if screen == null:
			return
		add_child(screen)
		register_screen(route, screen)
	_history.append({"route": route, "params": params.duplicate(true)})
	_display(route, params)


func back() -> void:
	if _busy or _history.is_empty():
		return
	_history.pop_back()
	if _active != null:
		_active.hide()
	if _history.is_empty():
		_active = null
		if _previous_focus != null and is_instance_valid(_previous_focus.get_ref()):
			_previous_focus.get_ref().grab_focus()
		route_changed.emit("")
	else:
		_display(_history.back().route, _history.back().params)


func _display(route: String, params: Dictionary) -> void:
	_busy = true
	if _transition != null:
		_transition.kill()
	if _active != null:
		_active.hide()
	_active = _screens[route]
	_active.show_screen(params)
	_active.modulate.a = 0.0
	_transition = create_tween()
	_transition.tween_property(_active, "modulate:a", 1.0, 0.18)
	_transition.finished.connect(func() -> void: _busy = false)
	route_changed.emit(route)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not _history.is_empty():
		back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _history.is_empty():
		back()
