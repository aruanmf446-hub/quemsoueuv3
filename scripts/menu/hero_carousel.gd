extends Control
## Three fullscreen artworks; one horizontal carousel, never stacked banners.
## Missing artworks are a safe fallback to the currently published lobby.
signal route_requested(route: String)
signal news_requested

const ART_SIZE := Vector2(1536.0, 864.0)
const SLIDE_SECONDS := 10.0
const TRANSITION_SECONDS := 0.46
const SWIPE_SHARE := 0.085
const SLIDES := [
	{"path": "res://assets/menu/hero/hero_historia.webp", "route": "story"},
	{"path": "res://assets/menu/hero/hero_mata_mata.webp", "route": "duel"},
	{"path": "res://assets/menu/hero/hero_biblioteca.webp", "route": "deck_library"}
]
var using_art := false
var _slide := 0
var _layers: Array[TextureRect] = []
var _transition: Tween
var _changing := false
var _elapsed := 0.0
var _pressing := false
var _press_origin := Vector2.ZERO
var _last_action_ms := 0

func _ready() -> void:
	name = "HeroCarousel"
	var artwork: Array[Texture2D] = []
	for spec: Dictionary in SLIDES:
		var path: String = str(spec["path"])
		if not ResourceLoader.exists(path, "Texture2D"):
			push_warning("HeroCarousel: arte ausente; menu original preservado: " + path)
			visible = false
			return
		var texture := load(path) as Texture2D
		if texture == null:
			push_warning("HeroCarousel: imagem invalida; menu original preservado: " + path)
			visible = false
			return
		artwork.append(texture)
	using_art = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(artwork.size()):
		var layer := TextureRect.new()
		layer.name = "HeroSlide%d" % index
		layer.texture = artwork[index]
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.visible = index == _slide
		add_child(layer)
		_layers.append(layer)
	resized.connect(_relayout)
	_relayout()
	_hide_original_lobby()
	var navigation := get_parent().get_node_or_null("Navigation")
	if navigation != null:
		navigation.connect("route_changed", _route_changed)

func _hide_original_lobby() -> void:
	var root := get_parent()
	for path: String in ["MenuButtons", "Logo", "LobbyArea", "FriendsPanel", "NewsButton"]:
		var item := root.get_node_or_null(path) as CanvasItem
		if item != null:
			item.hide()
	var composition := root.get_node_or_null("LobbyComposition")
	if composition != null:
		for name: String in ["brand", "brand_logo", "eyebrow", "footer", "chapter", "chapter_title"]:
			var item := composition.get(name) as CanvasItem
			if item != null:
				item.hide()
	# NowPlaying, Navigation and user services stay active.

func _route_changed(route: String) -> void:
	visible = using_art and route.is_empty()
	_elapsed = 0.0

func _relayout() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_changing = false
	for index in range(_layers.size()):
		var layer := _layers[index]
		layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		layer.position = Vector2.ZERO
		layer.size = size
		layer.visible = index == _slide

func _switch_slide(direction: int) -> void:
	if not using_art or _changing or _layers.size() < 2:
		return
	_animate_to(posmod(_slide + direction, _layers.size()), direction)

func _select_slide(index: int) -> void:
	if index == _slide:
		_elapsed = 0.0
		return
	if _changing:
		return
	_animate_to(index, 1 if index > _slide else -1)

func _animate_to(target: int, direction: int) -> void:
	_elapsed = 0.0
	var outgoing := _layers[_slide]
	var incoming := _layers[target]
	incoming.position = Vector2(float(direction) * size.x, 0.0)
	incoming.visible = true
	_slide = target
	_changing = true
	_transition = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(outgoing, "position:x", -float(direction) * size.x, TRANSITION_SECONDS)
	_transition.tween_property(incoming, "position:x", 0.0, TRANSITION_SECONDS)
	_transition.finished.connect(func() -> void:
		outgoing.hide()
		outgoing.position = Vector2.ZERO
		_changing = false)

func _process(delta: float) -> void:
	if not using_art or not visible or _pressing or _changing:
		return
	_elapsed += delta
	if _elapsed >= SLIDE_SECONDS:
		_switch_slide(1)

func _gui_input(event: InputEvent) -> void:
	if not using_art or _changing:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press_origin = touch.position
			_pressing = true
		else:
			_release(touch.position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_press_origin = mouse.position
			_pressing = true
		else:
			_release(mouse.position)

func _release(point: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	# Ignore emulated mouse release immediately following a real touch.
	var stamp := Time.get_ticks_msec()
	if _last_action_ms > 0 and stamp - _last_action_ms < 180:
		return
	_last_action_ms = stamp
	_elapsed = 0.0
	var delta := point.x - _press_origin.x
	if absf(delta) > size.x * SWIPE_SHARE:
		_switch_slide(-1 if delta > 0.0 else 1)
	else:
		_activate_hit(point)
	accept_event()

func _activate_hit(point: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Match covered source image, including the iPhone's landscape crop.
	var scale := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var painted_size := ART_SIZE * scale
	var offset := (size - painted_size) * 0.5
	var uv := (point - offset) / painted_size
	var x := uv.x
	var y := uv.y
	if y < 0.125:
		if x >= 0.17 and x < 0.32:
			_select_slide(0)
		elif x >= 0.32 and x < 0.455:
			_select_slide(1)
		elif x >= 0.455 and x < 0.615:
			route_requested.emit("skins")
		elif x >= 0.615 and x < 0.735:
			_select_slide(2)
		elif x >= 0.735 and x < 0.865:
			route_requested.emit("friends")
		elif x >= 0.865:
			route_requested.emit("settings")
		return
	if y >= 0.34 and y <= 0.72 and x < 0.06:
		_switch_slide(-1)
		return
	if y >= 0.34 and y <= 0.72 and x > 0.94:
		_switch_slide(1)
		return
	if y > 0.86:
		if x >= 0.685:
			return # Real NowPlaying controls overlay this region.
		if x < 0.19:
			news_requested.emit()
		elif x < 0.44:
			route_requested.emit("friends")
		return
	# The entire banner including its JOGAR art is a route target.
	if y > 0.125 and y < 0.86:
		route_requested.emit(str(SLIDES[_slide]["route"]))

func _unhandled_key_input(event: InputEvent) -> void:
	if not using_art or not visible or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT:
			_switch_slide(-1)
		KEY_RIGHT:
			_switch_slide(1)
		KEY_ENTER, KEY_KP_ENTER:
			route_requested.emit(str(SLIDES[_slide]["route"]))
		_:
			return
	get_viewport().set_input_as_handled()
