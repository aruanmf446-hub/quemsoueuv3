extends Control
## Mini player do lobby no estilo dos menus de jogos esportivos: cartão inclinado com faixa
## dourada, capa, "TOCANDO AGORA" com equalizador, barra de progresso e botões redondos.
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

## Cartão em paralelogramo com faixa dourada à esquerda, equalizador e progresso.
func _draw() -> void:
	var w := size.x
	var h := size.y
	var skew := h * 0.22
	draw_colored_polygon(PackedVector2Array([Vector2(skew, 0), Vector2(w, 0), Vector2(w - skew, h), Vector2(0, h)]), INK)
	draw_polyline(PackedVector2Array([Vector2(skew, 0), Vector2(w, 0), Vector2(w - skew, h), Vector2(0, h), Vector2(skew, 0)]), Color(GOLD, 0.35), 1.5, true)
	var stripe := h * 0.09
	draw_colored_polygon(PackedVector2Array([Vector2(skew, 0), Vector2(skew + stripe, 0), Vector2(stripe, h), Vector2(0, h)]), GOLD)
	# Moldura da capa.
	var cover := Rect2(_cover.position - Vector2.ONE * 2, _cover.size + Vector2.ONE * 4)
	draw_rect(cover, Color(GOLD, 0.8), false, 2.0)
	# Equalizador: barras vivas tocando, baixas e paradas na pausa.
	var playing: bool = is_instance_valid(_music) and not _music.paused
	var bar_w := h * 0.045
	var kicker_width := _font.get_string_size(_kicker.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _kicker.get_theme_font_size("font_size")).x
	var base := Vector2(_kicker.position.x + kicker_width + h * 0.1, _kicker.position.y + _kicker.size.y * 0.78)
	for index in range(4):
		var level := 0.25
		if playing: level = 0.35 + 0.65 * absf(sin(_time * (5.0 + index * 1.7) + index * 1.3))
		var bar_h := _kicker.size.y * 0.62 * level
		draw_rect(Rect2(base + Vector2(index * bar_w * 1.8, -bar_h), Vector2(bar_w, bar_h)), GOLD)
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
	var w := 740.0 if _compact else 500.0
	var h := 150.0 if _compact else 100.0
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(w, h)
	custom_minimum_size = size
	position = Vector2(menu.size.x - 32.0 - w, 108.0)
	var pad := h * 0.14
	var skew := h * 0.22
	_cover.position = Vector2(skew * 0.5 + h * 0.16, pad)
	_cover.size = Vector2(h - pad * 2, h - pad * 2)
	var text_x := _cover.position.x + _cover.size.x + h * 0.14
	var button_size := h * 0.40
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
	for index in range(3):
		var button := _buttons[index]
		var bigger := button_size * (1.15 if index == 1 else 1.0)
		button.size = Vector2(bigger, bigger)
		button.position = Vector2(buttons_x + index * (button_size + h * 0.08) - (bigger - button_size) * 0.5, (h - bigger) * 0.5)
	queue_redraw()
