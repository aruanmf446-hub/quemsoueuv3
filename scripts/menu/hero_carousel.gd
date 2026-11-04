extends Control
## Art is presentation only. All actions, tabs and text are native controls.
signal route_requested(route: String)
signal news_requested
const SLIDE_SECONDS := 10.0
const TRANSITION_SECONDS := 0.45
const GOLD := Color("f5c45f")
const PAPER := Color("fff8e7")
const SLIDES := [
	{"path": "res://assets/menu/hero/hero_historia.webp", "route": "story", "eyebrow": "MODO HISTÓRIA", "title": "REINO DO\nDESERTO", "description": "Corra nessa aventura pelo deserto e seus mistérios. Está pronto para essa aventura?", "reward": "Recompensa: Skin do El Fuego.", "action": "JOGAR"},
	{"path": "res://assets/menu/hero/hero_mata_mata.webp", "route": "duel", "eyebrow": "MODO MATA-MATA", "title": "MATA-MATA", "description": "Escolha suas cartas, selecione suas skins e entre no duelo.", "reward": "Deck de cartas + skins dos jogadores.", "action": "JOGAR"},
	{"path": "res://assets/menu/hero/hero_biblioteca.webp", "route": "deck_library", "eyebrow": "BIBLIOTECA DE DECKS", "title": "DESCUBRA\nNOVOS DECKS", "description": "Explore coleções oficiais e da comunidade, favorite seus decks e crie as suas próprias coleções.", "reward": "", "action": "EXPLORAR DECKS"}
]
const TABS := ["HISTÓRIA", "MATA-MATA", "PERSONAGENS", "BIBLIOTECA", "AMIZADES", "AJUSTES"]
var using_art := false
var _slide := 0
var _layers: Array[Control] = []
var _tabs: Array[Button] = []
var _dots: Array[Button] = []
var _actions: Array[Button] = []
var _logo: TextureRect
var _previous: Button
var _next: Button
var _news: Button
var _friends: Button
var _transition: Tween
var _changing := false
var _elapsed := 0.0
var _pressing := false
var _press_origin := Vector2.ZERO
var _pointer := -2
var _dragged := false
var _route := ""
var _font: Font
var _focused := true

func _ready() -> void:
	name = "HeroCarousel"
	for spec: Dictionary in SLIDES:
		if not ResourceLoader.exists(str(spec.path), "Texture2D"):
			push_warning("HeroCarousel: arte ausente; lobby original preservado: " + str(spec.path))
			hide()
			return
	using_art = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	PlayerUI.apply_theme(self)
	_font = get_theme_default_font()
	for index in range(SLIDES.size()): _build_slide(index)
	_logo = TextureRect.new()
	_logo.name = "OfficialLogo"
	_logo.texture = preload("res://assets/processed/logos/logo_quem_sou_eu_retangular.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	for index in range(TABS.size()):
		var button := _button(TABS[index], "Tab%d" % index)
		button.pressed.connect(_tab_selected.bind(index))
		_tabs.append(button)
	_previous = _button("‹", "PreviousSlide")
	_previous.tooltip_text = "Slide anterior (seta esquerda)"
	_previous.pressed.connect(_switch_slide.bind(-1))
	_next = _button("›", "NextSlide")
	_next.tooltip_text = "Próximo slide (seta direita)"
	_next.pressed.connect(_switch_slide.bind(1))
	for index in range(SLIDES.size()):
		var dot := _button("●", "Indicator%d" % index)
		dot.tooltip_text = str(SLIDES[index].eyebrow)
		dot.pressed.connect(_select_slide.bind(index, 0))
		_dots.append(dot)
	_news = _button("NOVIDADES", "HeroNews")
	_news.pressed.connect(func() -> void: news_requested.emit())
	_friends = _button("VER AMIGOS  ›", "HeroFriends")
	_friends.pressed.connect(func() -> void: route_requested.emit("friends"))
	resized.connect(_relayout)
	get_parent().get_node("Navigation").route_changed.connect(_route_changed)
	_hide_original_lobby()
	_relayout()

func _button(text: String, node_name: String, parent: Node = null) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	(parent if parent != null else self).add_child(button)
	_style(button)
	button.button_down.connect(func() -> void: _elapsed = 0.0)
	return button

func _style(button: Button, primary := false, selected := false) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(8)
		box.anti_aliasing = true
		box.bg_color = GOLD if primary else Color(0.02, 0.025, 0.05, 0.12)
		if state == "hover": box.bg_color = Color("ffdb82") if primary else Color(1, 0.8, 0.4, 0.12)
		if state == "pressed": box.bg_color = Color("dba645") if primary else Color(1, 0.8, 0.4, 0.2)
		if selected or primary or state == "focus":
			box.set_border_width_all(2)
			box.border_color = PAPER if state == "focus" else GOLD
		if state == "focus": box.bg_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(state, box)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("1c160e") if primary else (GOLD if selected else PAPER))

func _label(parent: Node, text: String, node_name: String, color := PAPER) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _build_slide(index: int) -> void:
	var spec: Dictionary = SLIDES[index]
	var layer := Control.new()
	layer.name = "HeroSlide%d" % index
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = index == _slide
	add_child(layer)
	_layers.append(layer)
	var background := TextureRect.new()
	background.name = "Artwork"
	background.texture = load(str(spec.path))
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.name = "Readability"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float left=(1.0-smoothstep(0.18,0.54,UV.x))*0.68; float top=(1.0-smoothstep(0.0,0.18,UV.y))*0.75; float bottom=smoothstep(0.78,1.0,UV.y)*0.85; COLOR=vec4(0.02,0.025,0.045,max(left,max(top,bottom))); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label(layer, str(spec.eyebrow), "Eyebrow", GOLD)
	_label(layer, str(spec.title), "Title")
	var description := _label(layer, str(spec.description), "Description")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reward := _label(layer, str(spec.reward), "Reward", GOLD)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action := _button(str(spec.action), "Play", layer)
	_style(action, true)
	action.pressed.connect(_activate_slide.bind(index))
	_actions.append(action)

func _activate_slide(index: int) -> void:
	if visible and not _changing and not _dragged and index == _slide:
		route_requested.emit(str(SLIDES[index].route))

func _hide_original_lobby() -> void:
	var menu := get_parent()
	for path: String in ["MenuButtons", "Logo", "LobbyArea", "FriendsPanel", "NewsButton", "Background"]:
		menu.get_node(path).hide()
	var composition := menu.get_node("LobbyComposition")
	for property: String in ["brand", "brand_logo", "eyebrow", "footer", "chapter", "chapter_title"]:
		var item := composition.get(property) as CanvasItem
		if item != null: item.hide()
	menu.get_node("LobbyArea/Stage/Viewport").render_target_update_mode = SubViewport.UPDATE_DISABLED
	menu.get_node("LobbyArea/Stage/Viewport/World").process_mode = Node.PROCESS_MODE_DISABLED

func _route_changed(route: String) -> void:
	_route = route
	visible = using_art and route.is_empty()
	_cancel_pointer()
	_elapsed = 0.0
	if _changing: _relayout()

func _rect(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(w, h)

func _relayout() -> void:
	if not using_art: return
	if _transition != null and _transition.is_valid(): _transition.kill()
	_changing = false
	_dragged = false
	_cancel_pointer()
	var w := size.x
	var h := size.y
	var iphone := UIScale.is_iphone()
	var left := maxf(116.0, w * 0.055)
	var content_w := w * 0.30
	var title_font := 54 if iphone else 72
	var body_font := 23 if iphone else 28
	for index in range(_layers.size()):
		var layer := _layers[index]
		_rect(layer, 0, 0, w, h)
		layer.visible = index == _slide
		var eyebrow: Label = layer.get_node("Eyebrow")
		eyebrow.add_theme_font_size_override("font_size", 21 if iphone else 26)
		_rect(eyebrow, left, h * 0.17, content_w + 40, h * 0.05)
		var title: Label = layer.get_node("Title")
		title.add_theme_font_size_override("font_size", title_font)
		if index == 2: title.add_theme_font_size_override("font_size", 46 if iphone else 62)
		if index == 1: title.add_theme_font_size_override("font_size", 49 if iphone else 66)
		_rect(title, left, h * 0.225, content_w + 65, h * 0.19)
		var description: Label = layer.get_node("Description")
		description.add_theme_font_size_override("font_size", body_font)
		_rect(description, left, h * 0.43, content_w, h * 0.16)
		var reward: Label = layer.get_node("Reward")
		reward.add_theme_font_size_override("font_size", 20 if iphone else 24)
		_rect(reward, left, h * 0.60, content_w, h * 0.07)
		_actions[index].add_theme_font_size_override("font_size", 27 if iphone else 36)
		_rect(_actions[index], left, h * 0.70, content_w, maxf(84.0, h * 0.115))
	_rect(_logo, w * 0.025, h * 0.018, w * 0.145, h * 0.085)
	var tab_start := w * 0.185
	var available := w * 0.795
	var font_size := 20 if iphone else 27
	var widths: Array[float] = []
	var total := 0.0
	for text: String in TABS:
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 28.0
		widths.append(width)
		total += width
	for index in range(_tabs.size()):
		var width := available * widths[index] / total
		_tabs[index].add_theme_font_size_override("font_size", font_size)
		_rect(_tabs[index], tab_start, h * 0.023, width - 4, maxf(80 if iphone else 60, h * 0.065))
		tab_start += width
	_previous.add_theme_font_size_override("font_size", 48)
	_next.add_theme_font_size_override("font_size", 48)
	_rect(_previous, 4, h * 0.45, 104, 104)
	_rect(_next, w - 108, h * 0.45, 104, 104)
	for index in range(_dots.size()):
		_dots[index].add_theme_font_size_override("font_size", 24)
		_rect(_dots[index], w * 0.59 + (index - 1.5) * 80, h * 0.82, 80, 80)
	_news.add_theme_font_size_override("font_size", 22 if iphone else 29)
	_friends.add_theme_font_size_override("font_size", 22 if iphone else 29)
	_rect(_news, left, h * 0.91, w * 0.15, h * 0.07)
	_rect(_friends, left + w * 0.17, h * 0.91, w * 0.19, h * 0.07)
	_update_selection()

func _tab_selected(index: int) -> void:
	_elapsed = 0.0
	match index:
		0: _select_slide(0)
		1: _select_slide(1)
		2: route_requested.emit("skins")
		3: _select_slide(2)
		4: route_requested.emit("friends")
		5: route_requested.emit("settings")

func _update_selection() -> void:
	for index in range(_tabs.size()): _style(_tabs[index], false, index == [0, 1, 3][_slide])
	for index in range(_dots.size()):
		_dots[index].add_theme_color_override("font_color", GOLD if index == _slide else Color("87878c"))
	for index in range(_actions.size()): _actions[index].disabled = _changing or index != _slide

func _switch_slide(direction: int) -> void:
	_select_slide(posmod(_slide + direction, SLIDES.size()), direction)

func _select_slide(index: int, direction := 0) -> void:
	_elapsed = 0.0
	if not using_art or _changing or not visible or index == _slide: return
	if direction == 0: direction = 1 if index > _slide else -1
	var outgoing := _layers[_slide]
	var incoming := _layers[index]
	var transfer_focus := _actions[_slide].has_focus()
	incoming.position.x = direction * size.x
	incoming.show()
	_slide = index
	_changing = true
	_update_selection()
	_transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(outgoing, "position:x", -direction * size.x, TRANSITION_SECONDS)
	_transition.tween_property(incoming, "position:x", 0.0, TRANSITION_SECONDS)
	_transition.finished.connect(func() -> void:
		outgoing.hide()
		outgoing.position = Vector2.ZERO
		_changing = false
		_dragged = false
		_update_selection()
		if transfer_focus: _actions[_slide].grab_focus())

func _process(delta: float) -> void:
	if not using_art or not visible or not _focused or _pressing or _changing or not _route.is_empty(): return
	if is_instance_valid(get_parent().get("_nickname_modal")): return
	if get_parent().has_node("NewsOverlay"): return
	for button in _tabs + _dots + _actions + [_previous, _next, _news, _friends]:
		if button.is_pressed(): return
	_elapsed += delta
	if _elapsed >= SLIDE_SECONDS: _switch_slide(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_cancel_pointer()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		_elapsed = 0.0

func _cancel_pointer() -> void:
	_pressing = false
	_pointer = -2
	for button in _actions: button.set_pressed_no_signal(false)

func _input(event: InputEvent) -> void:
	if not using_art or not visible: return
	if get_parent().has_node("NewsOverlay") or is_instance_valid(get_parent().get("_nickname_modal")): return
	if event is InputEventKey:
		_handle_key(event)
		return
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var pointer := -2
	if event is InputEventScreenTouch:
		if event.canceled:
			_cancel_pointer()
			_elapsed = 0.0
			get_viewport().set_input_as_handled()
			return
		point = event.position
		pressed = event.pressed
		released = not event.pressed
		pointer = event.index
	elif event is InputEventScreenDrag:
		point = event.position
		pointer = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION: return
		point = event.position
		pressed = event.pressed
		released = not event.pressed
		pointer = -1
	elif event is InputEventMouseMotion:
		point = event.position
		pointer = -1
	else: return
	point = get_global_transform_with_canvas().affine_inverse() * point
	if pressed and not _pressing:
		_dragged = false
		var player := get_parent().get_node_or_null("NowPlaying") as Control
		if player != null and player.visible and player.get_global_rect().has_point(point + global_position): return
		if _changing or point.y < size.y * 0.13 or point.y > size.y * 0.88: return
		if not Rect2(Vector2.ZERO, size).has_point(point): return
		_press_origin = point
		_pressing = true
		_pointer = pointer
		_elapsed = 0.0
	if not _pressing or _pointer != pointer: return
	var delta := point - _press_origin
	if absf(delta.x) > maxf(40.0, size.x * 0.045) and absf(delta.x) > absf(delta.y) * 1.3:
		_dragged = true
	if released:
		var swipe := _dragged
		_pressing = false
		_pointer = -2
		_elapsed = 0.0
		if swipe:
			_cancel_pointer()
			get_viewport().set_input_as_handled()
			_switch_slide(-1 if delta.x > 0 else 1)
	elif _dragged: get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> void:
	if not using_art or not visible or not event is InputEventKey: return
	if get_parent().has_node("NewsOverlay") or is_instance_valid(get_parent().get("_nickname_modal")): return
	if not event.pressed or event.echo: return
	if event.keycode == KEY_LEFT: _switch_slide(-1)
	elif event.keycode == KEY_RIGHT: _switch_slide(1)
	else: return
	get_viewport().set_input_as_handled()
