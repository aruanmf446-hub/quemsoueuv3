extends Node
## Rolagem por arraste em qualquer ScrollContainer dos menus (toque e mouse).
## Os botões dentro das listas capturavam o toque, então só a barrinha rolava.
## Aqui o toque é segurado até decidir: se o dedo anda mais que DEADZONE, rola a lista
## (com inércia); se solta parado, o toque é reenviado e vira um clique normal.
## Controles que precisam do arraste (sliders, campos de texto, palco 3D) não são afetados.
const DEADZONE := 10.0
const FRICTION := 5.0
var _scroll: ScrollContainer
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _press: InputEventMouseButton
var _dragging := false
var _replaying := false
var _velocity := Vector2.ZERO
var _coast: ScrollContainer
var _last_time := 0
## Toque começou num slider horizontal: arraste lateral ajusta o slider, vertical rola.
var _on_slider := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if _replaying: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_coast = null
			var target := _scroll_at(event.position)
			if target == null: return
			_on_slider = _slider_at(target, event.position)
			_scroll = target
			_start = event.position
			_last = event.position
			_last_time = Time.get_ticks_msec()
			_press = event.duplicate()
			_dragging = false
			_velocity = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif _scroll != null:
			get_viewport().set_input_as_handled()
			if _dragging:
				_coast = _scroll
			elif is_instance_valid(_scroll):
				_replay(_press, event)
			_scroll = null
			_press = null
	elif event is InputEventMouseMotion and _scroll != null:
		get_viewport().set_input_as_handled()
		if not is_instance_valid(_scroll):
			_scroll = null
			return
		if not _dragging and event.position.distance_to(_start) > DEADZONE:
			var moved: Vector2 = event.position - _start
			if _on_slider and absf(moved.x) > absf(moved.y):
				# Devolve o toque ao slider; o resto do gesto segue direto para ele.
				_replaying = true
				get_viewport().push_input(_press, true)
				get_viewport().push_input(event, true)
				_replaying = false
				_scroll = null
				_press = null
				return
			_dragging = true
		if _dragging:
			var delta: Vector2 = event.position - _last
			_apply(_scroll, -delta)
			var now := Time.get_ticks_msec()
			var dt := maxf(float(now - _last_time) / 1000.0, 0.001)
			_velocity = _velocity.lerp(-delta / dt, 0.5)
			_last_time = now
		_last = event.position

func _process(delta: float) -> void:
	if _coast == null or not is_instance_valid(_coast): return
	_apply(_coast, _velocity * delta)
	_velocity = _velocity.lerp(Vector2.ZERO, minf(FRICTION * delta, 1.0))
	if _velocity.length() < 20.0: _coast = null

## Converte o deslocamento da tela para o espaço da lista (telas podem estar escaladas).
func _apply(scroll: ScrollContainer, screen_delta: Vector2) -> void:
	var local := screen_delta / scroll.get_global_transform_with_canvas().get_scale()
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_vertical += roundi(local.y)
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_horizontal += roundi(local.x)

func _replay(press: InputEventMouseButton, release: InputEventMouseButton) -> void:
	_replaying = true
	get_viewport().push_input(press, true)
	get_viewport().push_input(release, true)
	_replaying = false

## Lista rolável mais interna sob o ponto, que tenha o que rolar, e sem um controle de
## arraste próprio por cima.
func _scroll_at(point: Vector2) -> ScrollContainer:
	var best: ScrollContainer
	for node in get_tree().root.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if not scroll.is_visible_in_tree() or not _scrollable(scroll): continue
		if not _hit(scroll, point): continue
		if best == null or best.is_ancestor_of(scroll): best = scroll
	if best == null: return null
	if _drag_control_at(best, point): return null
	return best

func _scrollable(scroll: ScrollContainer) -> bool:
	var vertical := scroll.get_v_scroll_bar()
	var horizontal := scroll.get_h_scroll_bar()
	var can_v := scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and vertical.max_value - vertical.page > 1.0
	var can_h := scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and horizontal.max_value - horizontal.page > 1.0
	return can_v or can_h

func _hit(control: Control, point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, control.size).has_point(control.get_global_transform_with_canvas().affine_inverse() * point)

func _drag_control_at(root: Control, point: Vector2) -> bool:
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree(): continue
		if not (control is ScrollBar or control is LineEdit or control is TextEdit or control is LobbyStage): continue
		if Rect2(Vector2.ZERO, control.size).has_point(control.get_global_transform_with_canvas().affine_inverse() * point): return true
	return false

func _slider_at(root: Control, point: Vector2) -> bool:
	for node in root.find_children("*", "Slider", true, false):
		var slider := node as Control
		if slider.is_visible_in_tree() and Rect2(Vector2.ZERO, slider.size).has_point(slider.get_global_transform_with_canvas().affine_inverse() * point): return true
	return false
