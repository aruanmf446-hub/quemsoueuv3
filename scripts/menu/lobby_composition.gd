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

func _ready() -> void:
	menu = get_parent()
	menu.get_node("Logo").hide()
	brand = _label("QUEM SOU EU", 30, PAPER)
	eyebrow = _label("QUATRO REINOS. UMA JORNADA.", 16, PAPER)
	footer = _label("LOBBY  /  ESCOLHA SEU CAMINHO", 16, PAPER)
	var shade := ColorRect.new()
	shade.name = "ReadabilityGradient"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { float left = (1.0-smoothstep(0.0,0.36,UV.x))*0.65; float top = (1.0-smoothstep(0.0,0.22,UV.y))*0.58; float bottom = smoothstep(0.76,1.0,UV.y)*0.48; COLOR = vec4(0.035,0.055,0.07,max(left,max(top,bottom))); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	menu.add_child(shade)
	menu.move_child(shade, menu.get_node("Background").get_index() + 1)
	for button: MenuCardButton in menu.get_node("MenuButtons").get_children():
		button.art_texture = null
		button.get_node("Padding").hide()
		button.text = {"story": "História  ›", "duel": "Duelo", "skins": "Personagens", "friends": "Amizades", "settings": "Configurações"}[String(button.button_id)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_action_content(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button, button.button_id == &"story")
		button.add_theme_constant_override("outline_size", 0)
		button.focus_mode = Control.FOCUS_ALL
		_nudge_on_hover(button)
	for path: String in ["TopBar/CoinPill", "TopBar/GemPill", "ProfileCard"]:
		var pill := _box(Color(0.035, 0.06, 0.11, 0.88), 3)
		pill.skew = Vector2(0.16, 0)
		pill.border_color = Color(ACCENT, 0.45)
		pill.border_width_bottom = 2
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

## Mesmo visual das outras telas: cartões inclinados, o principal dourado e os demais
## em vidro escuro com filete dourado à esquerda.
func _style_button(button: Button, primary: bool) -> void:
	var states := {
		"normal": ACCENT if primary else Color(0.035, 0.06, 0.11, 0.90),
		"hover": Color("f6d08f") if primary else Color(0.08, 0.13, 0.21, 0.94),
		"pressed": Color("c99a59") if primary else Color(0.02, 0.04, 0.07, 0.95),
		"disabled": Color(0.05, 0.07, 0.10, 0.70),
	}
	for state: String in states:
		var style := _box(states[state], 3)
		style.skew = Vector2(0.16, 0)
		style.anti_aliasing = true
		style.border_color = ACCENT if not primary else Color(1, 1, 1, 0.35)
		style.border_width_left = 0 if primary else 5
		style.border_width_top = 1 if primary else 0
		button.add_theme_stylebox_override(state, style)
	var focus := _box(Color.TRANSPARENT, 3)
	focus.skew = Vector2(0.16, 0)
	focus.set_border_width_all(2)
	focus.border_color = PAPER
	button.add_theme_stylebox_override("focus", focus)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK if primary else PAPER)
	button.add_theme_color_override("font_disabled_color", Color("9ea9ad"))

func _rect(control: Control, position: Vector2, dimensions: Vector2) -> void:
	control.custom_minimum_size = Vector2.ZERO
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.position = position
	control.size = dimensions

func _layout() -> void:
	var w := menu.size.x
	var h := menu.size.y
	var compact := UIScale.is_compact(500.0)
	# Em 844x390 a viewport é desenhada com escala ~0,41; o texto precisa de mais unidades de projeto.
	var type_scale := 1.8 if compact else 1.0
	var left_width := 530.0 if compact else 400.0
	_rect(brand, Vector2(32, 24), Vector2(350, 40))
	_rect(brand_logo, Vector2(24, 12), Vector2(400, 133))
	_rect(eyebrow, Vector2(34, 68), Vector2(380, 35))
	_rect(footer, Vector2(34, h - 44), Vector2(500, 32))
	_rect(menu.get_node("ProfileCard"), Vector2(w * 0.36, 24), Vector2(370, 80))
	_rect(menu.get_node("TopBar"), Vector2(w - 358, 24), Vector2(326, 64))
	for currency: String in ["CoinPill", "GemPill"]:
		menu.get_node("TopBar/" + currency).custom_minimum_size = Vector2(156, 64)
	menu.get_node("ProfileCard/Content/Info").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var profile_name: Label = menu.get_node("ProfileCard/Content/Info/Name")
	profile_name.clip_text = true
	profile_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	profile_name.add_theme_font_size_override("font_size", 32 if compact else 20)
	menu.get_node("ProfileCard/Content/Info/Level").visible = not compact
	for currency: String in ["CoinPill", "GemPill"]:
		menu.get_node("TopBar/" + currency + "/Content/Value").add_theme_font_size_override("font_size", 32 if compact else 22)
	var mode: Label = menu.get("_mode_label")
	# Compacto: uma linha só, para não invadir o rodapé. Largura limitada antes do nome do personagem.
	_rect(mode, Vector2(34, h - 90), Vector2(760 if compact else 650, 36))
	mode.add_theme_color_override("font_color", Color("e5e6dc"))
	mode.add_theme_font_size_override("font_size", int(18 * (1.3 if compact else 1.0)))
	var buttons: VBoxContainer = menu.get_node("MenuButtons")
	_rect(buttons, Vector2(32, h * (0.25 if compact else 0.29)), Vector2(left_width, 0))
	buttons.add_theme_constant_override("separation", 10)
	for button: Button in buttons.get_children():
		button.custom_minimum_size = Vector2(left_width, 130 if compact else 88)
		button.add_theme_font_size_override("font_size", int(26 * type_scale))
		var content: HBoxContainer = button.get_node_or_null("ActionBody")
		if content != null:
			content.offset_left = BODY_LEFT
			content.offset_right = BODY_RIGHT
			content.offset_top = 12
			content.offset_bottom = -12
			content.get_node("Icon").custom_minimum_size.x = 60 if compact else 46
			content.get_node("Text/Title").add_theme_font_size_override("font_size", 38 if compact else 26)
			content.get_node("Text/Subtitle").add_theme_font_size_override("font_size", 23 if compact else 15)
	buttons.size.x = left_width
	var area: Control = menu.get_node("LobbyArea")
	_rect(area, Vector2(w * 0.53 - h * 0.43, h * 0.035), Vector2(h * 0.86, h * 0.93))
	area.get_node("Stage").custom_minimum_size = Vector2.ZERO
	area.get_node("Stage").set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_label: Label = area.get_node("Overlay/NameLabel")
	_rect(name_label, Vector2(area.size.x * 0.25, area.size.y - 62), Vector2(area.size.x * 0.5, 50))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_font_size_override("font_size", int(26 * type_scale))
	_rect(area.get_node("Overlay/PrevButton"), Vector2(area.size.x * 0.25 - 58, area.size.y - 64), Vector2(54, 54))
	_rect(area.get_node("Overlay/NextButton"), Vector2(area.size.x * 0.75 + 4, area.size.y - 64), Vector2(54, 54))
	var friends: Control = menu.get_node("FriendsPanel")
	_rect(friends, Vector2(w - 350, h * 0.66), Vector2(318, 0))
	menu.get_node("FriendsPanel/Margin/Content/ViewAllButton").add_theme_font_size_override("font_size", 28 if compact else 18)
	for child in menu.get_node("FriendsPanel/Margin/Content/FriendList").get_children():
		if child is Label:
			child.add_theme_font_size_override("font_size", 28 if compact else 18)
	friends.size.y = menu.get_node("FriendsPanel/Margin").get_combined_minimum_size().y
	menu.get_node("FriendsPanel/Margin/Content/Header/Title").add_theme_font_size_override("font_size", int(22 * type_scale))
	# Captions grow on small landscape screens while the hero stays proportional.
	eyebrow.add_theme_font_size_override("font_size", int(16 * type_scale))
	menu.get_node("FriendsPanel/Margin/Content/ViewAllButton").custom_minimum_size.y = 52 if compact else 42
	# Re-evaluate social height when asynchronous friend data changes the container.
	if not menu.get_node("FriendsPanel/Margin").minimum_size_changed.is_connected(_social_size):
		menu.get_node("FriendsPanel/Margin").minimum_size_changed.connect(_social_size)

func _social_size() -> void:
	menu.get_node("FriendsPanel").size.y = menu.get_node("FriendsPanel/Margin").get_combined_minimum_size().y

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
	if body == null: return
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
	var titles := {"story": ["JOGAR", "Modo História · Reino do Deserto"], "duel": ["DUELO", "Multiplayer · Salas online"], "skins": ["PERSONAGENS", "Coleção Começo"], "friends": ["AMIZADES", "Sua equipe de aventura"], "settings": ["AJUSTES", "Sua experiência"]}
	var paths := {"story": '<path d="M12 3 21 8v8l-9 5-9-5V8zM12 3v18M3 8l9 5 9-5"/>', "duel": '<path d="M3 3l10 10M3 3h4M3 3v4M21 3 11 13M21 3h-4M21 3v4"/><path d="M8 16l-4 4M16 16l4 4M6.5 14.5l3 3M17.5 14.5l-3 3"/>', "skins": '<circle cx="12" cy="7" r="4"/><path d="M4 22v-4a8 8 0 0 1 16 0v4M4 18h16"/>', "friends": '<circle cx="8" cy="8" r="3"/><circle cx="18" cy="9" r="3"/><path d="M1 22v-4a7 7 0 0 1 14 0v4M16 15a6 6 0 0 1 7 6"/>', "settings": '<path d="M3 6h18M3 12h18M3 18h18"/><circle cx="8" cy="6" r="2"/><circle cx="16" cy="12" r="2"/><circle cx="9" cy="18" r="2"/>'}
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
