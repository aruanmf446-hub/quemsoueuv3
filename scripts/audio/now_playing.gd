extends PanelContainer
## Mini player do lobby: capa, faixa atual e controles anterior / pausar / próxima.
## Usa a mesma API do autoload MenuMusic que os atalhos F6–F8; no celular é o único controle.
## Fica oculto quando nenhuma faixa está liberada no catálogo.
var _music: Node
var _cover: TextureRect
var _title: Label
var _category: Label
var _toggle: Button
var _buttons: Array[Button] = []

func _ready() -> void:
	name = "NowPlaying"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.11, 0.86)
	style.border_color = Color(0.95, 0.81, 0.49, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_cover = TextureRect.new()
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(_cover)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 60
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	_title = PlayerUI.label("", 18)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(_title)
	_category = PlayerUI.label("", 13, PlayerUI.GOLD)
	_category.autowrap_mode = TextServer.AUTOWRAP_OFF
	_category.clip_text = true
	text.add_child(_category)
	for spec: Array in [["⏮", "Faixa anterior", "previous_track"], ["⏸", "Pausar música", ""], ["⏭", "Próxima faixa", "next_track"]]:
		var button := Button.new()
		button.text = spec[0]
		button.tooltip_text = spec[1]
		button.focus_mode = Control.FOCUS_NONE
		var method: String = spec[2]
		if method.is_empty():
			_toggle = button
			button.pressed.connect(_toggle_pause)
		else:
			button.pressed.connect(func() -> void:
				if is_instance_valid(_music): _music.call(method))
		row.add_child(button)
		_buttons.append(button)
	_music = get_node_or_null("/root/MenuMusic")
	if _music != null:
		_music.track_changed.connect(func(_track: Dictionary) -> void: _refresh())
		_music.state_changed.connect(_refresh)
	var menu := get_parent() as Control
	if menu != null: menu.resized.connect(_layout)
	_layout()
	_refresh()

func _toggle_pause() -> void:
	if not is_instance_valid(_music): return
	if _music.paused: _music.resume()
	else: _music.pause()

func _refresh() -> void:
	var available: bool = is_instance_valid(_music) and not _music.available_tracks().is_empty()
	visible = available
	if not available: return
	var track: Dictionary = _music.current_track()
	_title.text = str(track.get("title", "Música do menu"))
	_category.text = str(track.get("category", "")).to_upper()
	var cover := str(track.get("cover", ""))
	_cover.texture = load(cover) as Texture2D if not cover.is_empty() and ResourceLoader.exists(cover, "Texture2D") else null
	_toggle.text = "▶" if _music.paused else "⏸"
	_toggle.tooltip_text = "Tocar música" if _music.paused else "Pausar música"

## Coluna direita, abaixo das moedas e acima do painel Social, fora da área do personagem.
## Em telas baixas tudo cresce em unidades de projeto, como o resto do lobby.
func _layout() -> void:
	var menu := get_parent() as Control
	if menu == null: return
	var compact := DisplayServer.window_get_size().y < 500
	var width := 600.0 if compact else 360.0
	var height := 124.0 if compact else 76.0
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(menu.size.x - 32.0 - width, 112.0)
	custom_minimum_size = Vector2(width, height)
	size = Vector2(width, height)
	var inner := height - 16.0
	_cover.custom_minimum_size = Vector2(inner, inner)
	_title.add_theme_font_size_override("font_size", 30 if compact else 17)
	_category.add_theme_font_size_override("font_size", 22 if compact else 12)
	for button in _buttons:
		# No celular os alvos ficam com ~36×45 px físicos.
		button.custom_minimum_size = Vector2(inner * (0.82 if compact else 0.62), inner)
		button.add_theme_font_size_override("font_size", 40 if compact else 22)
