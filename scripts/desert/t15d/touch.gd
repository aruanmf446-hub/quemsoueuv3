extends Control
## Controles de toque: joystick à esquerda (andar e agachar) e botões de pulo, ataque e
## defesa à direita. Multitoque real e alvos em pixels físicos; não depende da emulação de mouse.
const Icons = preload("res://scripts/desert/t15d/resource_icons.gd")
const ACTIONS := ["move_left", "move_right", "crouch", "defend", "attack", "jump"]
## _areas segue ACTIONS: as três primeiras são zonas do joystick (esquerda, direita, baixo).
var _areas: Array[Rect2] = []
var _held := {}
var actor: Node
var _last_pixels := Vector2i.ZERO
var _base := Vector2.ZERO
var _radius := 1.0
var _buttons := {}
## Dedo que controla o joystick (-1 = mouse; null = nenhum), origem e vetor (-1..1).
var _stick_finger: Variant = null
var _stick_origin := Vector2.ZERO
var _stick := Vector2.ZERO
var _stick_actions := {}
## Posições desenhadas: seguem o dedo com amortecimento e voltam ao centro ao soltar.
var _knob := Vector2.ZERO
var _drawn_origin := Vector2.ZERO
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _wanted()
func _wanted() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("web") or UIScale.is_compact() or "--touch-controls" in OS.get_cmdline_user_args()
func _layout() -> void:
	var screen := get_viewport_rect().size
	var unit := UIScale.unit_for(get_viewport())
	_radius = 60.0*unit
	_base = Vector2(_radius+34*unit, screen.y-_radius-28*unit)
	var jump := Vector2(screen.x-70*unit, screen.y-68*unit)
	_buttons = {"jump": [jump, 40.0*unit], "attack": [jump+Vector2(-90*unit, 14*unit), 32.0*unit], "defend": [jump+Vector2(-26*unit, -86*unit), 32.0*unit]}
	var half := _radius*0.55
	_areas = [Rect2(_base+Vector2(-_radius, -half), Vector2(_radius, half*2)), Rect2(_base+Vector2(0, -half), Vector2(_radius, half*2)), Rect2(_base+Vector2(-half, _radius*0.15), Vector2(half*2, _radius*0.85))]
	for action in ["defend", "attack", "jump"]:
		var spec: Array = _buttons[action]
		_areas.append(Rect2(spec[0]-Vector2.ONE*spec[1], Vector2.ONE*spec[1]*2))
func _draw() -> void:
	if not visible or _buttons.is_empty(): return
	var unit := UIScale.unit_for(get_viewport())
	# Joystick: base translúcida com setas e manopla dourada que segue o dedo.
	var origin := _drawn_origin
	draw_circle(origin, _radius, Color(0.03, 0.07, 0.12, 0.55))
	draw_arc(origin, _radius, 0, TAU, 48, Color(0.95, 0.80, 0.48, 0.55), 1.5*unit, true)
	for angle in [0.0, PI*0.5, PI, PI*1.5]:
		var dir := Vector2.from_angle(angle)
		var tip := origin+dir*_radius*0.78
		var side := dir.orthogonal()*7*unit
		draw_colored_polygon(PackedVector2Array([tip, tip-dir*9*unit+side, tip-dir*9*unit-side]), Color(0.96, 0.89, 0.74, 0.5))
	var knob := origin+_knob*_radius*0.62
	draw_circle(knob, _radius*0.44, Color(0.48, 0.32, 0.11, 0.85) if _stick_finger != null else Color(0.10, 0.16, 0.24, 0.85))
	draw_arc(knob, _radius*0.44, 0, TAU, 36, Color("#f2c76e"), 2.0*unit, true)
	# Botões: pulo com seta; ataque e defesa com os ícones do HUD.
	for action in ["jump", "attack", "defend"]:
		var spec: Array = _buttons[action]
		var point: Vector2 = spec[0]
		var radius: float = spec[1]
		var down := _held.values().has(action)
		if action == "jump":
			draw_circle(point, radius, Color(0.48, 0.32, 0.11, 0.85) if down else Color(0.03, 0.07, 0.12, 0.74))
			draw_arc(point, radius, 0, TAU, 40, Color(0.95, 0.80, 0.48, 0.75), 1.8*unit, true)
			var s := radius*0.42
			draw_colored_polygon(PackedVector2Array([point+Vector2(0, -s*1.05), point+Vector2(s, s*0.15), point+Vector2(s*0.38, s*0.15), point+Vector2(s*0.38, s*0.9), point+Vector2(-s*0.38, s*0.9), point+Vector2(-s*0.38, s*0.15), point+Vector2(-s, s*0.15)]), Color("#f5e4bd"))
		else:
			var full: bool = not is_instance_valid(actor) or (actor.attack_charges > 0 if action == "attack" else actor.defense_charges > 0)
			var size := radius*2.0*(0.9 if down else 1.0)
			draw_texture_rect(Icons.medallion("attack" if action == "attack" else "defense", roundi(radius*2.0), full), Rect2(point-Vector2.ONE*size*0.5, Vector2.ONE*size), false)
func _process(delta: float) -> void:
	var pixels := get_window().size
	if pixels != _last_pixels:
		_last_pixels = pixels
		visible = _wanted()
		if not visible: release_all()
		_layout()
		_drawn_origin = _base
	var follow := 1.0-exp(-delta*22.0)
	_knob = _knob.lerp(_stick, follow)
	_drawn_origin = _drawn_origin.lerp(_stick_origin if _stick_finger != null else _base, 1.0-exp(-delta*14.0))
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventScreenTouch:
		if event.pressed: _press(event.index, event.position)
		else: _release(event.index)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _press(-1, event.position)
		else: _release(-1)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _stick_finger == -1:
		_drag(-1, event.position)
func _button_at(point: Vector2) -> String:
	for action in ["jump", "attack", "defend"]:
		var spec: Array = _buttons[action]
		if point.distance_to(spec[0]) <= float(spec[1])*1.15: return action
	return ""
## Metade esquerda da tela (fora dos botões) pertence ao joystick. Tocar perto da base usa a
## base fixa; tocar longe dela cria o joystick onde o dedo encostou.
func _in_stick_zone(point: Vector2) -> bool:
	return point.x < get_viewport_rect().size.x*0.45 and point.y > get_viewport_rect().size.y*0.35
func _press(index: int, point: Vector2) -> void:
	var action := _button_at(point)
	if not action.is_empty():
		_held[index] = action
		Input.action_press(action)
		get_viewport().set_input_as_handled()
		return
	if _stick_finger == null and _in_stick_zone(point):
		_stick_finger = index
		_stick_origin = _base if point.distance_to(_base) <= _radius*1.3 else point
		_drag(index, point)
		get_viewport().set_input_as_handled()
func _drag(index: int, point: Vector2) -> void:
	if _stick_finger == null or _stick_finger != index:
		# Dedo que escorregou para outro botão troca de ação, como antes.
		if _held.has(index):
			var action := _button_at(point)
			if action != _held[index]:
				_release(index)
				if not action.is_empty(): _press(index, point)
		return
	_stick = ((point-_stick_origin)/(_radius*0.62)).limit_length(1.0)
	var wanted := {}
	var x := _stick.x
	# Puxar para baixo agacha; o resto do curso é andar, com força analógica.
	if _stick.y > 0.6 and absf(x) < 0.55: wanted["crouch"] = 1.0
	elif absf(x) > 0.22: wanted["move_right" if x > 0.0 else "move_left"] = clampf((absf(x)-0.22)/0.55, 0.45, 1.0)
	for action in _stick_actions.keys():
		if not wanted.has(action):
			_stick_actions.erase(action)
			if not _held.values().has(action): Input.action_release(action)
	for action in wanted:
		_stick_actions[action] = wanted[action]
		Input.action_press(action, wanted[action])
func _release(index: int) -> void:
	if _stick_finger != null and _stick_finger == index:
		_stick_finger = null
		_stick = Vector2.ZERO
		for action in _stick_actions.keys():
			if not _held.values().has(action): Input.action_release(action)
		_stick_actions.clear()
		return
	if not _held.has(index): return
	var action: String = _held[index]
	_held.erase(index)
	if not _held.values().has(action) and not _stick_actions.has(action): Input.action_release(action)
func _exit_tree() -> void:
	release_all()
func release_all() -> void:
	for index in _held.keys(): _release(index)
	if _stick_finger != null: _release(_stick_finger)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_all()
