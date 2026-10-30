extends Control
## Compact lobby music player: cover, title, transport and playback progress.
## Usa a API do autoload MenuMusic (a mesma dos atalhos F6–F8); no celular é o único controle.
## Fica oculto quando nenhuma faixa está liberada no catálogo.
const FONT := preload("res://assets/desert/phase01/interface.ttf")
const GOLD := Color("#f2c76e")
const INK := Color(0.03, 0.05, 0.10, 0.92)
var _music: Node
var _cover: TextureRect
var _kicker: Label
var _title: Label
var _category: Label
var _buttons: Array[Button] = []
var _icons := ["prev", "toggle", "next"]
var _time := 0.0
var _compact := false
var _font: FontFile
var _shown_id := ""
var _suppressed := false

func _ready() -> void:
	name = "NowPlaying"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = FONT.duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	_cover = TextureRect.new()
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	_kicker = _make_label(GOLD)
	_kicker.text = "TOCANDO AGORA"
	_title = _make_label(Color.WHITE)
	_category = _make_label(Color("#9fb3cc"))
	for index in range(3):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = ["Faixa anterior", "Pausar ou tocar", "Próxima faixa"][index]
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(1, 1, 1, 0.08) if index != 1 else GOLD
			if state == "hover": style.bg_color = style.bg_color.lightened(0.15)
			if state == "pressed": style.bg_color = style.bg_color.darkened(0.2)
			style.set_corner_radius_all(999)
			style.anti_aliasing = true
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(_pressed.bind(index))
		button.draw.connect(_draw_icon.bind(button, index))
		add_child(button)
		_buttons.append(button)
	_music = get_node_or_null("/root/MenuMusic")
	if _music != null:
		_music.track_changed.connect(func(_track: Dictionary) -> void: _refresh())
		_music.state_changed.connect(_refresh)
	var menu := get_parent() as Control
	if menu != null: menu.resized.connect(_layout)
	_layout()
	_refresh()

func _make_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", _font)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _pressed(index: int) -> void:
	if not is_instance_valid(_music): return
	match index:
		0: _music.previous_track()
		1:
			if _music.paused: _music.resume()
			else: _music.pause()
		2: _music.next_track()

func set_suppressed(value: bool) -> void:
	_suppressed = value
	_refresh()

func _refresh() -> void:
	var available: bool = is_instance_valid(_music) and not _music.available_tracks().is_empty()
	visible = available and not _suppressed
	if not available: return
	var track: Dictionary = _music.current_track()
	_title.text = str(track.get("title", "Carregando música..."))
	var artist := str(track.get("artist", ""))
	var category := str(track.get("category", "")).to_upper()
	_category.text = category if artist.is_empty() else artist + "  •  " + category
	var cover := str(track.get("cover", ""))
	_cover.texture = load(cover) as Texture2D if not cover.is_empty() and ResourceLoader.exists(cover, "Texture2D") else null
	for button in _buttons: button.queue_redraw()
	# Troca de faixa entra deslizando, como o aviso de música dos jogos de futebol.
	var id := str(track.get("id", ""))
	if id != _shown_id and not id.is_empty():
		_shown_id = id
		modulate.a = 0.0
		pivot_offset = size * 0.5
		var slide := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		slide.tween_property(self, "modulate:a", 1.0, 0.35)
		var target := position
		position.x += 40.0
		slide.tween_property(self, "position:x", target.x, 0.35)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	_time += delta
	queue_redraw()

## Restrained surface and playback progress.
func _draw() -> void:
	var h := size.y
	draw_style_box(_music_surface(), Rect2(Vector2.ZERO, size))
	# Progresso da faixa.
	if is_instance_valid(_music):
		var length: float = _music.track_length()
		var share := clampf(_music.playback_position() / length, 0.0, 1.0) if length > 0.0 else 0.0
		var left := _title.position.x
		var right := _buttons[0].position.x - h * 0.12
		var y := h - h * 0.14
		draw_line(Vector2(left, y), Vector2(right, y), Color(1, 1, 1, 0.15), h * 0.03)
		draw_line(Vector2(left, y), Vector2(lerpf(left, right, share), y), GOLD, h * 0.03)

func _draw_icon(button: Button, index: int) -> void:
	var c := button.size * 0.5
	var r := button.size.y * 0.2
	var color := Color("#101828") if index == 1 else Color.WHITE
	match index:
		0, 2:
			var d := -1.0 if index == 0 else 1.0
			button.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6 * d, -r), c + Vector2(r * 0.6 * d, 0), c + Vector2(-r * 0.6 * d, r)]), color)
			button.draw_rect(Rect2(c + Vector2(r * 0.6 * d - (r * 0.25 if d > 0 else 0.0), -r), Vector2(r * 0.25, r * 2)), color)
		1:
			if is_instance_valid(_music) and _music.paused:
				button.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r), c + Vector2(r * 0.9, 0), c + Vector2(-r * 0.6, r)]), color)
			else:
				button.draw_rect(Rect2(c + Vector2(-r * 0.7, -r), Vector2(r * 0.5, r * 2)), color)
				button.draw_rect(Rect2(c + Vector2(r * 0.2, -r), Vector2(r * 0.5, r * 2)), color)

## Canto superior direito, abaixo das moedas e fora da área do personagem.
func _layout() -> void:
	var menu := get_parent() as Control
	if menu == null: return
	_compact = UIScale.is_compact(500.0)
	var unit := menu.size.y / maxf(float(menu.get_window().size.y) / UIScale.device_scale(), 1.0)
	var w := (280.0 if _compact else 330.0) * unit
	var h := 52.0 * unit
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(w, h)
	custom_minimum_size = size
	position = Vector2(menu.size.x - 24.0 * unit - w, menu.size.y - h - 16.0 * unit)
	var pad := h * 0.14
	var skew := h * 0.22
	_cover.position = Vector2(skew * 0.5 + h * 0.16, pad)
	_cover.size = Vector2(h - pad * 2, h - pad * 2)
	var text_x := _cover.position.x + _cover.size.x + h * 0.14
	var button_size := 44.0 * unit
	var buttons_x := w - skew * 0.5 - h * 0.1 - button_size * 3 - h * 0.08 * 2
	_kicker.position = Vector2(text_x, pad * 0.7)
	_kicker.add_theme_font_size_override("font_size", int(h * 0.13))
	_kicker.size = Vector2(buttons_x - text_x, h * 0.2)
	_title.position = Vector2(text_x, h * 0.30)
	_title.add_theme_font_size_override("font_size", int(h * 0.2))
	_title.size = Vector2(buttons_x - text_x - h * 0.08, h * 0.3)
	_category.position = Vector2(text_x, h * 0.58)
	_category.add_theme_font_size_override("font_size", int(h * 0.13))
	_category.size = Vector2(buttons_x - text_x - h * 0.08, h * 0.2)
	_kicker.hide()
	_category.hide()
	_title.position.y = h * 0.30
	_title.size.y = 22 * unit
	_title.add_theme_font_size_override("font_size", roundi(12 * unit))
	for index in range(3):
		var button := _buttons[index]
		var bigger := button_size
		button.size = Vector2(bigger, bigger)
		button.position = Vector2(buttons_x + index * (button_size + h * 0.08) - (bigger - button_size) * 0.5, (h - bigger) * 0.5)
	queue_redraw()

func _music_surface() -> StyleBoxFlat:
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(0.035, 0.05, 0.065, 0.9)
	surface.set_corner_radius_all(4)
	return surface
