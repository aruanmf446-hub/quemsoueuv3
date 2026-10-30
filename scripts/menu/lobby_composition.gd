extends Node
## Presentation only. Keeps the existing scene nodes, routes and service bindings.
const INK := Color("151e25")
const PAPER := Color("f6f3e9")
const ACCENT := Color("e9b975")
## Margens do conteúdo (ícone + textos) dentro de cada botão do menu; no hover ele avança.
const BODY_LEFT := 22.0
const BODY_RIGHT := -18.0
const NUDGE := 10.0
var menu: Control
var brand: Label
var eyebrow: Label
var footer: Label
var social_bg: Panel
var brand_logo: TextureRect
var chapter: Label
var chapter_title: Label

func _ready() -> void:
	menu = get_parent()
	# The project default is Nearest Mipmap: it also reaches the glyph atlas.
	# Use interpolation for the UI while keeping mipmaps for downscaled artwork.
	menu.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var font := preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	font.multichannel_signed_distance_field = true
	var theme := Theme.new()
	theme.default_font = font
	menu.theme = theme
	# Reuse the existing buttons and their signals in a freely composed navigation layer.
	var old_menu := menu.get_node("MenuButtons")
	var navigation := Control.new()
	navigation.name = "MenuButtons"
	navigation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var order := old_menu.get_index()
	menu.remove_child(old_menu)
	menu.add_child(navigation)
	menu.move_child(navigation, order)
	for child in old_menu.get_children(): child.reparent(navigation)
	menu.set("_menu_buttons", navigation)
	old_menu.queue_free()
	var library := preload("res://scenes/menu/components/menu_card_button.tscn").instantiate() as MenuCardButton
	library.name = "BtnLibrary"
	library.button_id = &"deck_library"
	navigation.add_child(library)
	library.activated.connect(menu._on_menu_button_activated)
	chapter = _label("MODO HISTÓRIA", 14, ACCENT)
	chapter_title = _label("REINO DO\nDESERTO", 56, PAPER)
	menu.get_node("Logo").hide()
	brand = _label("QUEM SOU EU", 30, PAPER)
	eyebrow = _label("QUATRO REINOS. UMA JORNADA.", 16, PAPER)
	footer = _label("LOBBY  /  ESCOLHA SEU CAMINHO", 16, PAPER)
	var shade := ColorRect.new()
	shade.name = "ReadabilityGradient"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { float left = (1.0-smoothstep(0.12,0.78,UV.x))*0.94; float top = (1.0-smoothstep(0.0,0.23,UV.y))*0.74; float bottom = smoothstep(0.68,1.0,UV.y)*0.86; COLOR = vec4(0.025,0.035,0.045,max(left,max(top,bottom))); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	menu.add_child(shade)
	menu.move_child(shade, menu.get_node("Background").get_index() + 1)
	for button: MenuCardButton in menu.get_node("MenuButtons").get_children():
		button.art_texture = null
		button.get_node("Padding").hide()
		button.text = {"story": "História  ›", "duel": "Duelo", "skins": "Personagens", "friends": "Amizades", "settings": "Configurações", "deck_library": "Biblioteca"}[String(button.button_id)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_action_content(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button, button.button_id == &"story")
		button.add_theme_constant_override("outline_size", 0)
		button.focus_mode = Control.FOCUS_ALL
		_nudge_on_hover(button)
	for path: String in ["TopBar/CoinPill", "TopBar/GemPill", "ProfileCard"]:
		var pill := _box(Color(0.035, 0.06, 0.11, 0.88), 3)
		pill.skew = Vector2.ZERO
		pill.border_color = Color(ACCENT, 0.45)
		pill.border_width_bottom = 0
		menu.get_node(path).add_theme_stylebox_override("panel", pill)
	for path: String in ["TopBar/MailButton", "TopBar/FriendsButton", "TopBar/SettingsButton"]:
		menu.get_node(path).hide()
	menu.get_node("ProfileCard/Content/Avatar/Ring").hide()
	menu.get_node("ProfileCard/Content/Avatar").add_theme_stylebox_override("panel", _box(INK))
	for currency: String in ["CoinPill", "GemPill"]:
		var value: Label = menu.get_node("TopBar/" + currency + "/Content/Value")
		value.add_theme_constant_override("outline_size", 0)
		value.add_theme_color_override("font_color", PAPER)
		var icon: Panel = menu.get_node("TopBar/" + currency + "/Content/Icon")
		icon.add_theme_stylebox_override("panel", _box(Color.TRANSPARENT, 10))
		var symbol := TextureRect.new()
		symbol.texture = load("res://assets/icons/vector/icon_coin.svg" if currency == "CoinPill" else "res://assets/icons/vector/icon_gem.svg")
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_child(symbol)
		symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		menu.get_node("TopBar/" + currency).tooltip_text = "Moedas" if currency == "CoinPill" else "Gemas"
	menu.get_node("FriendsPanel/Frame").hide()
	social_bg = Panel.new()
	social_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	social_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var social_style := _box(Color(0.035, 0.06, 0.11, 0.90), 12)
	social_style.border_width_top = 2
	social_style.border_color = ACCENT
	social_bg.add_theme_stylebox_override("panel", social_style)
	menu.get_node("FriendsPanel/Margin/Content/Header/Title").text = "SOCIAL"
	menu.get_node("FriendsPanel").add_child(social_bg)
	menu.get_node("FriendsPanel").move_child(social_bg, 0)
	var margin: MarginContainer = menu.get_node("FriendsPanel/Margin")
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_style_button(menu.get_node("FriendsPanel/Margin/Content/ViewAllButton"), false)
	var stage: LobbyStage = menu.get_node("LobbyArea/Stage")
	stage.fill_ratio = 0.76
	stage.pedestal_lift = 0.025
	stage.frame_character()
	var rim: OmniLight3D = stage.get_node("Viewport/World/RimLight")
	rim.light_color = Color("fff1db")
	rim.light_energy = 1.1
	stage.get_node("Viewport/World/KeyLight").light_energy = 1.0
	for path: String in ["PrevButton", "NextButton"]:
		var button: Button = menu.get_node("LobbyArea/Overlay/" + path)
		_style_button(button, false)
		button.add_theme_constant_override("outline_size", 0)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 28)
	var music := AudioStreamPlayer.new()
	music.name = "MenuMusic"
	music.bus = "Music"
	# Reserved for the approved soundtrack; deliberately no stream or autoplay.
	menu.add_child(music)
	# Limpeza final: textos e cartão de conta saem da composição. Os nós continuam existindo
	# para preservar sinais, serviços e rotas; a seleção de personagem fica nas Skins.
	eyebrow.hide()
	footer.hide()
	# Logo oficial (retangular) substitui o título textual, na mesma posição.
	brand.hide()
	brand_logo = TextureRect.new()
	brand_logo.name = "BrandLogo"
	brand_logo.texture = preload("res://assets/processed/logos/logo_quem_sou_eu_retangular.png")
	brand_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(brand_logo)
	menu.move_child(brand_logo, menu.get_node("SkinsPanel").get_index())
	menu.get("_mode_label").hide()
	menu.get_node("ProfileCard").hide()
	for path: String in ["NameLabel", "PrevButton", "NextButton"]:
		menu.get_node("LobbyArea/Overlay/" + path).hide()
	_language()
	menu.get_node("Services").preferences.changed.connect(_language)
	menu.resized.connect(_layout)
	_layout()
	# Os botões entram em cascata ao abrir o lobby e sempre que uma tela interna fecha.
	menu.get_node("Navigation").route_changed.connect(func(route: String) -> void:
		if route.is_empty(): intro())
	intro.call_deferred()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	menu.add_child(label)
	menu.move_child(label, menu.get_node("SkinsPanel").get_index())
	return label

func _box(color: Color, radius: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.shadow_color = Color(0,0,0,0.28)
	box.shadow_size = 10
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

## A single primary action; secondary navigation uses quiet text tabs.
func _style_button(button: Button, primary: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var background := ACCENT if primary else Color.TRANSPARENT
		if state == "hover": background = Color("f5d5a0") if primary else Color(1, 1, 1, 0.08)
		if state == "pressed": background = Color("c99a59") if primary else Color(1, 1, 1, 0.13)
		if state == "disabled": background = Color(1, 1, 1, 0.04)
		var style := _box(background, 4)
		style.shadow_size = 0
		style.anti_aliasing = true
		button.add_theme_stylebox_override(state, style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = PAPER
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("focus", focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK if primary else PAPER)


func _rect(control: Control, position: Vector2, dimensions: Vector2) -> void:
	control.custom_minimum_size = Vector2.ZERO
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = position
	control.size = dimensions

func _layout() -> void:
	var unit := menu.size.y / maxf(float(menu.get_window().size.y) / UIScale.device_scale(), 1.0)
	var w := menu.size.x / unit
	var h := menu.size.y / unit
	var compact := h < 600.0
	var pad := 24.0 if compact else 40.0
	_rect(brand_logo, Vector2(pad, 12) * unit, Vector2(150, 58) * unit)
	_rect(menu.get_node("TopBar"), Vector2(w - pad - 200, 20) * unit, Vector2(200, 42) * unit)
	for currency: String in ["CoinPill", "GemPill"]:
		menu.get_node("TopBar/" + currency).custom_minimum_size = Vector2(94, 42) * unit
		menu.get_node("TopBar/" + currency + "/Content/Value").add_theme_font_size_override("font_size", roundi(16 * unit))
	var buttons: Control = menu.get_node("MenuButtons")
	_rect(buttons, Vector2.ZERO, menu.size)
	var x := pad if compact else 225.0
	var y := 72.0 if compact else 22.0
	for id: String in ["duel", "skins", "deck_library", "friends", "settings"]:
		var button: Button = buttons.get_node({"duel":"BtnDuel", "skins":"BtnSkins", "friends":"BtnFriends", "settings":"BtnSettings", "deck_library":"BtnLibrary"}[id])
		var width: float = {"duel": 88.0, "skins": 150.0, "friends": 126.0, "settings": 100.0, "deck_library": 134.0}[id]
		if w < 760: width = {"duel": 74.0, "skins": 136.0, "friends": 100.0, "settings": 88.0, "deck_library": 116.0}[id]
		_rect(button, Vector2(x, y) * unit, Vector2(width, 44) * unit)
		var body: Control = button.get_node("ActionBody")
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.offset_left = 12 * unit
		body.offset_right = -12 * unit
		body.get_node("Icon").hide()
		body.get_node("Text/Subtitle").hide()
		body.get_node("Text/Title").add_theme_font_size_override("font_size", roundi(15 * unit))
		x += width + (4 if w < 760 else 8)
	var title_y := h * 0.35 if compact else h * 0.40
	_rect(chapter, Vector2(pad, title_y) * unit, Vector2(340, 24) * unit)
	chapter.add_theme_font_size_override("font_size", roundi(12 * unit))
	_rect(chapter_title, Vector2(pad - 2, title_y + 30) * unit, Vector2(400, 150) * unit)
	chapter_title.add_theme_font_size_override("font_size", roundi((36 if compact else 60) * unit))
	var play: Button = buttons.get_node("BtnStory")
	_rect(play, Vector2(pad, h - (118 if compact else 150)) * unit, Vector2(260 if compact else 320, 56 if compact else 64) * unit)
	var action: Control = play.get_node("ActionBody")
	action.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action.offset_left = 20 * unit
	action.offset_right = -20 * unit
	action.get_node("Icon").custom_minimum_size.x = 26 * unit
	action.get_node("Text/Title").add_theme_font_size_override("font_size", roundi(22 * unit))
	action.get_node("Text/Subtitle").hide()
	var area: Control = menu.get_node("LobbyArea")
	var stage_height := h * (0.86 if compact else 0.92)
	_rect(area, Vector2(w * 0.68 - stage_height * 0.39, h - stage_height - 15) * unit, Vector2(stage_height * 0.78, stage_height) * unit)
	area.get_node("Stage").custom_minimum_size = Vector2.ZERO
	area.get_node("Stage").set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var friends: Control = menu.get_node("FriendsPanel")
	_rect(friends, Vector2(pad + 155, h - 54) * unit, Vector2(140, 38) * unit)
	social_bg.hide()
	var margin: MarginContainer = friends.get_node("Margin")
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 0)
	friends.get_node("Margin/Content/Header").hide()
	friends.get_node("Margin/Content/FriendList").hide()
	var view_all: Button = friends.get_node("Margin/Content/ViewAllButton")
	view_all.text = "VER AMIGOS  ›"
	view_all.custom_minimum_size = Vector2(140, 38) * unit
	view_all.add_theme_font_size_override("font_size", roundi(12 * unit))

func _social_size() -> void:
	pass # The lobby shows a compact social shortcut; the full list remains in Friends.

func _language() -> void:
	# Source strings are Portuguese; avoid English fallback on untranslated pt_BR keys.
	var mode := Node.AUTO_TRANSLATE_MODE_INHERIT if TranslationServer.get_locale().begins_with("en") else Node.AUTO_TRANSLATE_MODE_DISABLED
	for path: String in ["MenuButtons", "ProfileCard", "FriendsPanel", "TopBar", "LobbyArea"]:
		menu.get_node(path).auto_translate_mode = mode


## Hover/foco: o conteúdo do botão avança alguns pixels; ao sair, volta suave.
func _nudge_on_hover(button: Button) -> void:
	var state := {"hover": false}
	var update := func() -> void:
		_nudge(button, NUDGE if (state.hover or button.has_focus()) and not button.disabled else 0.0, 0.18)
	button.mouse_entered.connect(func() -> void:
		state.hover = true
		update.call())
	button.mouse_exited.connect(func() -> void:
		state.hover = false
		update.call())
	button.focus_entered.connect(update)
	button.focus_exited.connect(update)


func _nudge(button: Button, shift: float, time: float, from := NAN, delay := 0.0) -> void:
	var body := button.get_node_or_null("ActionBody") as Control
	if body == null or button.get("button_id") != &"story": return
	var old: Variant = button.get_meta("nudge") if button.has_meta("nudge") else null
	if old is Tween and (old as Tween).is_valid(): (old as Tween).kill()
	var tween := button.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var left := tween.tween_property(body, "offset_left", BODY_LEFT + shift, time).set_delay(delay)
	var right := tween.tween_property(body, "offset_right", BODY_RIGHT + shift, time).set_delay(delay)
	if not is_nan(from):
		left.from(BODY_LEFT + from)
		right.from(BODY_RIGHT + from)
	button.set_meta("nudge", tween)


## Entrada do menu: cada botão surge da esquerda, um pouco depois do anterior.
func intro() -> void:
	var index := 0
	for button: Button in menu.get_node("MenuButtons").get_children():
		if not button.visible: continue
		var delay := 0.05 * index
		button.modulate.a = 0.0
		var fade := button.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(delay)
		_nudge(button, NUDGE if button.has_focus() else 0.0, 0.36, -28.0, delay)
		index += 1


func _action_content(button: MenuCardButton) -> void:
	button.text = ""
	var titles := {"story": ["JOGAR", "Modo História · Reino do Deserto"], "duel": ["DUELO", "Partida local ou salas online"], "skins": ["PERSONAGENS", "Coleção Começo"], "friends": ["AMIZADES", "Sua equipe de aventura"], "settings": ["AJUSTES", "Sua experiência"], "deck_library": ["BIBLIOTECA", "Decks e cartas"]}
	var paths := {"deck_library": '<rect x="4" y="5" width="13" height="16" rx="2"/><path d="M8 2h12v16M8 9h5M8 13h5"/>', "story": '<path d="M12 3 21 8v8l-9 5-9-5V8zM12 3v18M3 8l9 5 9-5"/>', "duel": '<path d="M3 3l10 10M3 3h4M3 3v4M21 3 11 13M21 3h-4M21 3v4"/><path d="M8 16l-4 4M16 16l4 4M6.5 14.5l3 3M17.5 14.5l-3 3"/>', "skins": '<circle cx="12" cy="7" r="4"/><path d="M4 22v-4a8 8 0 0 1 16 0v4M4 18h16"/>', "friends": '<circle cx="8" cy="8" r="3"/><circle cx="18" cy="9" r="3"/><path d="M1 22v-4a7 7 0 0 1 14 0v4M16 15a6 6 0 0 1 7 6"/>', "settings": '<path d="M3 6h18M3 12h18M3 18h18"/><circle cx="8" cy="6" r="2"/><circle cx="16" cy="12" r="2"/><circle cx="9" cy="18" r="2"/>'}
	var row := HBoxContainer.new()
	row.name = "ActionBody"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := TextureRect.new()
	icon.name = "Icon"
	var ink := "#152437" if button.button_id == &"story" else "#e9c995"
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 24 24"><g fill="none" stroke="' + ink + '" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">' + paths[String(button.button_id)] + '</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	icon.texture = ImageTexture.create_from_image(image)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var values: Array = titles[String(button.button_id)]
	for index in range(2):
		var label := Label.new()
		label.name = "Title" if index == 0 else "Subtitle"
		label.text = values[index]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", INK if button.button_id == &"story" else (PAPER if index == 0 else Color("#a8bdd1")))
		text.add_child(label)
