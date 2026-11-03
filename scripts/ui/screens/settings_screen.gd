extends PlayerScreen
## Configurações (referência aprovada T22): cabeçalho fixo, navegação horizontal com as
## cinco categorias e, em cada uma, um painel principal (~65%) e um lateral (~35%).
## Tudo é ligado a serviços reais; o que o jogo não tem aparece como indisponível.

const ACCENT := PlayerUI.GOLD
const GOLD_LIGHT := Color("#f4cf7a")
const GOLD_DARK := Color("#8a6226")
const MUTED := Color("#a8bad3")
const PANEL := Color(0.055, 0.08, 0.125, 0.94)
const ROW := Color(0.035, 0.05, 0.085, 0.92)
const EDGE := Color(0.42, 0.52, 0.68, 0.28)
const INK := Color("#141006")
const CATEGORIES := [
	["Meu Perfil", "user"], ["Áudio", "speaker"], ["Gráficos", "monitor"], ["Controles", "gamepad"], ["Idioma", "globe"],
]
const SUBTITLES := [
	"Suas informações de conta e personalização.",
	"Ajuste os volumes, efeitos e preferências sonoras do jogo.",
	"Ajuste a qualidade visual para equilibrar aparência e desempenho.",
	"Veja como controlar o jogo no teclado e no toque.",
	"Defina o idioma do jogo (textos, menus e mensagens).",
]
const ICONS := {
	"user": '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a8 8 0 0 1 16 0v1"/>',
	"speaker": '<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11"/>',
	"mute": '<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16 9l5 6M21 9l-5 6"/>',
	"monitor": '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
	"gamepad": '<path d="M7 8h10a4 4 0 0 1 4 4v2a3 3 0 0 1-5.4 1.8L14 14h-4l-1.6 1.8A3 3 0 0 1 3 14v-2a4 4 0 0 1 4-4z"/><path d="M7 11v3M5.5 12.5h3"/><circle cx="16" cy="11.5" r="0.6"/><circle cx="18" cy="13.5" r="0.6"/>',
	"globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
	"gear": '<circle cx="12" cy="12" r="3.2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/><circle cx="12" cy="12" r="7"/>',
	"crown": '<path d="M3 18h18l-1.5-10-4.5 4-3-6-3 6-4.5-4z"/><path d="M4 21h16"/>',
	"back": '<path d="M19 12H5M11 6l-6 6 6 6"/>',
	"refresh": '<path d="M20 12a8 8 0 0 1-14 5.3M4 12a8 8 0 0 1 14-5.3"/><path d="M18 3v4h-4M6 21v-4h4"/>',
	"pencil": '<path d="M4 20l1-4L16 5l3 3L8 19z"/><path d="M14 7l3 3"/>',
	"mail": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
	"login": '<path d="M10 17l5-5-5-5M15 12H3M14 3h5a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-5"/>',
	"id": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="11" r="2.5"/><path d="M5.5 17a3.5 3.5 0 0 1 7 0M15 9h3M15 13h3"/>',
	"copy": '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>',
	"shield": '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
	"lock": '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
	"logout": '<path d="M14 7l5 5-5 5M19 12H9M10 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h5"/>',
	"search": '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
	"chevron": '<path d="M9 5l7 7-7 7"/>',
	"note": '<path d="M9 18V5l11-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
	"spark": '<path d="M12 2v5M12 17v5M2 12h5M17 12h5M5 5l3.5 3.5M15.5 15.5 19 19M5 19l3.5-3.5M15.5 8.5 19 5"/>',
	"headphones": '<path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3" y="14" width="4" height="7" rx="1.5"/><rect x="17" y="14" width="4" height="7" rx="1.5"/>',
	"music_list": '<path d="M3 6h11M3 11h11M3 16h7"/><path d="M17 17V7l4-1v9"/><circle cx="15.5" cy="17.5" r="1.8"/>',
	"play": '<path d="M8 5l11 7-11 7z"/>',
	"pause": '<path d="M8 5v14M16 5v14"/>',
	"info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
	"layers": '<path d="M12 3l9 5-9 5-9-5z"/><path d="M3 13l9 5 9-5"/>',
	"expand": '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
	"gauge": '<path d="M4 17a8 8 0 1 1 16 0"/><path d="M12 17l4-6"/><circle cx="12" cy="17" r="1.2"/>',
	"chip": '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/>',
	"memory": '<rect x="3" y="7" width="18" height="10" rx="1.5"/><path d="M7 7v10M11 7v10M15 7v10M5 20v-3M19 20v-3"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
	"keyboard": '<rect x="2.5" y="6" width="19" height="12" rx="2"/><path d="M6 10h1M10 10h1M14 10h1M18 10h0.5M6 14h12"/>',
	"touch": '<path d="M9 11V5a1.5 1.5 0 0 1 3 0v6M12 10.5a1.5 1.5 0 0 1 3 0V12M15 11.5a1.5 1.5 0 0 1 3 0V15a6 6 0 0 1-6 6h-1a5 5 0 0 1-4.2-2.3L4 14.5a1.5 1.5 0 0 1 2.5-1.6L9 15"/>',
	"bulb": '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
	"enter": '<path d="M20 5v7a3 3 0 0 1-3 3H5M9 11l-4 4 4 4"/>',
	"translate": '<path d="M4 5h9M8.5 3v2M6 5c.5 3 2.5 5.5 5 7M11 5c-.5 3-3 6-6 8"/><path d="M13 21l4-9 4 9M14.5 18h5"/>',
	"book": '<path d="M3 5c3-1 6-1 9 1 3-2 6-2 9-1v14c-3-1-6-1-9 1-3-2-6-2-9-1z"/><path d="M12 6v14"/>',
}

const MIN_LOGICAL_WIDTH := 900.0
var _category := 0
var _waiting_action := ""
var _binding_button: Button
var _content: VBoxContainer
var _side: VBoxContainer
var _feedback: Label
var _tabs: Array[Button] = []
var _layout: HBoxContainer
var _scroll: ScrollContainer
var _main_panel: PanelContainer
var _side_panel: PanelContainer
var _panel_title: Label
var _panel_subtitle: Label
var _nav: HBoxContainer
var _grabber: ImageTexture
var _toggle_on: ImageTexture
var _toggle_off: ImageTexture
var _icon_cache := {}
var _decor: ColorRect
var _brand: HBoxContainer
var _gear: TextureRect
var _divider: ColorRect
var _graphics_pending := {}
var _perf_labels := {}
var _perf_timer: Timer
var _sfx: Node


func _ready() -> void:
	manages_own_scale = true
	super._ready()
	_make_icons()
	_build_frame()
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _waiting_action = "")
	resized.connect(_adapt)
	services.session.changed.connect(func() -> void:
		_waiting_action = ""
		if is_visible_in_tree(): render())
	services.profile.changed.connect(func() -> void:
		if is_visible_in_tree() and _category == 0: _show_category())
	_perf_timer = Timer.new()
	_perf_timer.wait_time = 1.0
	_perf_timer.timeout.connect(_refresh_performance)
	add_child(_perf_timer)


# --- Moldura: fundo, cabeçalho e navegação ---------------------------------------------

func _build_frame() -> void:
	# Fundo: azul-marinho sólido (telas internas) com gradiente e curvas douradas discretas.
	_decor = ColorRect.new()
	_decor.name = "SettingsBackdrop"
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 base : source_color = vec4(0.024, 0.043, 0.078, 1.0);
uniform vec4 gold : source_color = vec4(0.91, 0.72, 0.38, 1.0);
void fragment() {
	vec2 uv = UV;
	vec3 color = base.rgb + vec3(0.02, 0.04, 0.07) * (1.0 - uv.y) * (1.0 - uv.x * 0.6);
	color += vec3(0.01, 0.02, 0.04) * smoothstep(0.6, 0.0, distance(uv, vec2(0.15, 0.1)));
	float top = uv.x * 0.08 + 0.16 - pow(max(uv.x - 0.82, 0.0) * 4.2, 2.0) * 0.1;
	float curve_top = smoothstep(0.004, 0.0, abs(uv.y - (0.115 - pow(max(uv.x - 0.78, 0.0) * 4.4, 2.0) * 0.06)));
	float curve_low = smoothstep(0.004, 0.0, abs(uv.y - (1.0 - pow(max(uv.x - 0.8, 0.0) * 5.0, 1.6) * 0.12)));
	float fade_top = smoothstep(0.7, 1.0, uv.x);
	float fade_low = smoothstep(0.84, 1.0, uv.x);
	color = mix(color, gold.rgb, curve_top * fade_top * 0.65 + curve_low * fade_low * 0.75);
	COLOR = vec4(color, 1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_decor.material = material
	add_child(_decor)
	move_child(_decor, 0)
	_decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if has_node("Tint"): $Tint.hide()
	var header: HBoxContainer = $Margin/Column/Header
	var back: Button = $Margin/Column/Header/Back
	_divider = ColorRect.new()
	_divider.color = Color(1, 1, 1, 0.16)
	_divider.custom_minimum_size = Vector2(1, 44)
	_divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_divider)
	header.move_child(_divider, back.get_index() + 1)
	_gear = TextureRect.new()
	_gear.texture = _icon("gear", ACCENT, 64)
	_gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_gear)
	header.move_child(_gear, _divider.get_index() + 1)
	_brand = HBoxContainer.new()
	_brand.name = "Brand"
	_brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brand.alignment = BoxContainer.ALIGNMENT_END
	_brand.add_theme_constant_override("separation", 10)
	var crown := TextureRect.new()
	crown.name = "Crown"
	crown.texture = _icon("crown", ACCENT, 64)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_brand.add_child(crown)
	var brand := _plain("Quem Sou Eu", 28, Color.WHITE)
	brand.name = "BrandName"
	brand.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_brand.add_child(brand)
	var version := _plain("V3", 28, ACCENT)
	version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_brand.add_child(version)
	header.add_child(_brand)
	$Margin/Column/Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func render() -> void:
	var perf_started := Time.get_ticks_usec()
	_waiting_action = ""
	PlayerUI.clear(body)
	heading.text = tr("Configurações")
	heading.add_theme_color_override("font_color", Color.WHITE)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	banner.hide()
	var back: Button = $Margin/Column/Header/Back
	PlayerUI.standard_back(back, "Voltar")
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nav = HBoxContainer.new()
	_nav.name = "CategoryNav"
	_nav.add_theme_constant_override("separation", 14)
	body.add_child(_nav)
	_tabs.clear()
	for i in range(CATEGORIES.size()):
		var tab := Button.new()
		tab.name = "Tab_%d" % i
		tab.text = tr(CATEGORIES[i][0])
		tab.icon = _icon(CATEGORIES[i][1], Color.WHITE, 30)
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_ALL
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_constant_override("h_separation", 12)
		tab.pressed.connect(_select.bind(i))
		_style_tab(tab)
		tab.button_pressed = i == _category
		_nav.add_child(tab)
		_tabs.append(tab)
	_layout = HBoxContainer.new()
	_layout.name = "Panels"
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 24)
	body.add_child(_layout)
	_main_panel = _panel("MainPanel")
	_main_panel.size_flags_stretch_ratio = 1.85
	_layout.add_child(_main_panel)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 0)
	_main_panel.add_child(main)
	var head := _panel_head(main)
	_panel_title = head[0]
	_panel_subtitle = head[1]
	_scroll = ScrollContainer.new()
	_scroll.name = "ContentScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_scroll)
	var inner := MarginContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: inner.add_theme_constant_override("margin_" + side, 20)
	_scroll.add_child(inner)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	inner.add_child(_content)
	_side_panel = _panel("SidePanel")
	_side_panel.size_flags_stretch_ratio = 1.0
	_layout.add_child(_side_panel)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_panel.add_child(side_scroll)
	_side = VBoxContainer.new()
	_side.name = "Side"
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 12)
	side_scroll.add_child(_side)
	# Só aparece quando algo dá errado; salvar com sucesso não precisa de aviso.
	_feedback = PlayerUI.label("", 18, Color("#ff9797"))
	_feedback.name = "Feedback"
	_feedback.hide()
	body.add_child(_feedback)
	_show_category()
	_adapt()
	WebPerf.measure("render", perf_started)


func _adapt() -> void:
	var perf_started := Time.get_ticks_usec()
	if not is_instance_valid(_layout): return
	# Largura lógica mínima: em janelas muito estreitas o layout inteiro reduz junto
	# (nada é cortado nem quebra letra por letra).
	var factor := minf(PlayerUI.unit(self), size.x / MIN_LOGICAL_WIDTH)
	var logical := size / factor
	var compact := logical.y < 600.0
	var narrow := logical.x < 1100.0
	var margin: MarginContainer = $Margin
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = logical
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 18 if compact else 48)
	margin.add_theme_constant_override("margin_top", 10 if compact else 26)
	margin.add_theme_constant_override("margin_bottom", 10 if compact else 30)
	$Margin/Column.add_theme_constant_override("separation", 8 if compact else 22)
	PlayerUI.standard_back($Margin/Column/Header/Back)
	heading.add_theme_font_size_override("font_size", 26 if compact else 46)
	_gear.custom_minimum_size = Vector2.ONE * (28 if compact else 48)
	_divider.custom_minimum_size.y = 28 if compact else 52
	_brand.get_node("Crown").custom_minimum_size = Vector2.ONE * (24 if compact else 46)
	for label: Label in _brand.get_children().filter(func(n: Node) -> bool: return n is Label):
		label.add_theme_font_size_override("font_size", 18 if compact else 34)
	_brand.visible = logical.x >= 760.0
	_nav.add_theme_constant_override("separation", 6 if compact else 14)
	for tab in _tabs:
		tab.custom_minimum_size = Vector2(0, 40 if compact else 76)
		tab.add_theme_font_size_override("font_size", 14 if compact else (20 if narrow else 28))
		tab.expand_icon = false
		tab.add_theme_constant_override("icon_max_width", 18 if compact else 30)
		tab.icon = null if compact and narrow else _icon(CATEGORIES[_tabs.find(tab)][1], Color.WHITE, 30)
	_layout.add_theme_constant_override("separation", 10 if compact else 24)
	_side_panel.size_flags_stretch_ratio = 1.0
	_main_panel.size_flags_stretch_ratio = 1.5 if compact else 1.85
	# iPhone: o painel principal ganha espaço para os valores (nickname, e-mail) não cortarem.
	if UIScale.is_iphone(): _main_panel.size_flags_stretch_ratio = 2.6
	_panel_title.add_theme_font_size_override("font_size", 20 if compact else 34)
	_panel_subtitle.add_theme_font_size_override("font_size", 12 if compact else 17)
	_panel_subtitle.visible = not (compact and narrow)
	WebPerf.measure("_adapt", perf_started)


func _select(index: int) -> void:
	_waiting_action = ""
	_category = index
	for i in range(_tabs.size()): _tabs[i].button_pressed = i == index
	_show_category()
	PlayerUI.cascade(_content)
	PlayerUI.cascade(_side)


func animate_in() -> void:
	PlayerUI.cascade(_nav)
	PlayerUI.cascade(_content)
	PlayerUI.cascade(_side)


func _show_category() -> void:
	var perf_started := Time.get_ticks_usec()
	if not is_instance_valid(_content): return
	_scroll.scroll_vertical = 0
	PlayerUI.clear(_content)
	PlayerUI.clear(_side)
	_perf_timer.stop()
	_panel_title.text = tr(CATEGORIES[_category][0])
	_panel_subtitle.text = tr(SUBTITLES[_category])
	match _category:
		0: _my_profile()
		1: _audio()
		2: _graphics()
		3: _controls()
		4: _language()
	WebPerf.measure("_show_category", perf_started)


func _compact() -> bool:
	return size.y / minf(PlayerUI.unit(self), size.x / MIN_LOGICAL_WIDTH) < 600.0


# --- 01 Meu Perfil ---------------------------------------------------------------------

func _my_profile() -> void:
	var compact := _compact()
	var data := services.profile.data
	var signed := services.session.authenticated()
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 14 if compact else 26)
	_content.add_child(split)
	# Coluna do personagem: retrato real do personagem equipado.
	var hero := VBoxContainer.new()
	hero.name = "HeroColumn"
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 6)
	split.add_child(hero)
	var equipped := services.inventory.equipped_id()
	var skin := services.inventory.entry(equipped)
	var frame := PanelContainer.new()
	frame.name = "PortraitFrame"
	var frame_box := _flat(Color(0.12, 0.09, 0.05), GOLD_LIGHT, 14, 3)
	frame_box.shadow_color = Color(ACCENT, 0.35)
	frame_box.shadow_size = 10
	frame.add_theme_stylebox_override("panel", frame_box)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.add_child(frame)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	var side := 96 if compact else 190
	portrait.custom_minimum_size = Vector2(side, side)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var portrait_path := "res://assets/portraits/%s.png" % equipped
	if ResourceLoader.exists(portrait_path): portrait.texture = load(portrait_path)
	frame.add_child(portrait)
	var caption := PlayerUI.label(tr("PERSONAGEM ATUAL"), 12 if compact else 15, ACCENT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(caption)
	var hero_name := PlayerUI.label(str(skin.get("name", "—")), 18 if compact else 30, Color.WHITE)
	hero_name.name = "HeroName"
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hero.add_child(hero_name)
	if signed and services.profile.state == "success":
		var level := PlayerUI.label(tr("Nível ") + DevicePreferences.number(data.get("level"), services.preferences.values.locale) + "  ·  " + DevicePreferences.number(data.get("experience"), services.preferences.values.locale) + " XP", 11 if compact else 14, MUTED)
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero.add_child(level)
	var swap := _action_button("Trocar Personagem", "refresh", false, func() -> void: navigate_requested.emit("skins", {}))
	swap.name = "OpenSkins"
	hero.add_child(swap)
	var line := ColorRect.new()
	line.color = Color(ACCENT, 0.25)
	line.custom_minimum_size.x = 1
	split.add_child(line)
	# Coluna de informações.
	var info := VBoxContainer.new()
	info.name = "InfoRows"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8 if compact else 14)
	split.add_child(info)
	var nickname: Variant = data.get("nickname")
	var shown := str(nickname) if nickname != null and not str(nickname).is_empty() else tr("Sem nickname")
	if not signed: shown = tr("Visitante")
	var nick_row := _info_row(info, "user", "Nickname", shown)
	nick_row.name = "NicknameRow"
	if signed:
		var edit := _icon_button("pencil", "Alterar nickname", func() -> void: _edit_nickname(info, nick_row))
		edit.name = "EditNickname"
		nick_row.get_child(0).add_child(edit)
	var user: Dictionary = services.session.user if signed else {}
	var email := str(user.get("email", "")) if signed else ""
	_info_row(info, "mail", "E-mail", email if not email.is_empty() else "—").name = "EmailRow"
	_info_row(info, "login", "Login por", _provider_name() if signed else tr("Sem conta conectada")).name = "ProviderRow"
	var public_id := str(data.get("public_id", "")) if signed else ""
	var id_row := _info_row(info, "id", "ID público", public_id if not public_id.is_empty() else "—")
	id_row.name = "PublicIdRow"
	if not public_id.is_empty():
		var copy := _icon_button("copy", "Copiar ID público", func() -> void:
			DisplayServer.clipboard_set(public_id)
			banner.show_state("success", tr("ID público copiado.")))
		copy.name = "CopyPublicId"
		id_row.get_child(0).add_child(copy)
	if signed and services.profile.state != "success":
		var reload := _action_button("Carregar perfil", "refresh", false, func() -> void:
			await services.profile.refresh()
			if is_visible_in_tree() and _category == 0: _show_category())
		info.add_child(reload)
	# Painel lateral: Conta e Segurança (só recursos reais).
	_side_head("shield", "Conta e Segurança", "Gerencie o acesso e a segurança da sua conta.")
	if not signed:
		var enter := _action_button("Entrar na conta", "login", true, func() -> void: navigate_requested.emit("account", {}))
		enter.name = "EnterAccount"
		enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_side.add_child(enter)
		return
	var provider := _provider()
	var password := _side_row("lock", "Alterar senha", "" if provider in ["", "email"] else tr("Gerenciada pelo ") + _provider_name(), func() -> void: _change_password())
	password.name = "ChangePassword"
	password.disabled = not provider in ["", "email"]
	var two_factor := _side_row("shield", "Verificação em duas etapas", tr("Indisponível nesta versão"), func() -> void: pass)
	two_factor.name = "TwoFactor"
	two_factor.disabled = true
	var discoverable := CheckButton.new()
	discoverable.name = "Discoverable"
	discoverable.text = tr("Permitir busca do perfil")
	discoverable.button_pressed = data.get("discoverable", false)
	discoverable.disabled = services.profile.state != "success"
	_style_toggle(discoverable)
	discoverable.toggled.connect(func(value: bool) -> void: status(await services.profile.set_discoverable(value)))
	_side.add_child(discoverable)
	var logout := _side_row("logout", "Sair da conta", "", disconnect_account)
	logout.name = "DisconnectAccount"


func _edit_nickname(info: VBoxContainer, row: Control) -> void:
	if info.has_node("NicknameEditor"): return
	var editor := HBoxContainer.new()
	editor.name = "NicknameEditor"
	editor.add_theme_constant_override("separation", 10)
	info.add_child(editor)
	info.move_child(editor, row.get_index() + 1)
	var field := LineEdit.new()
	field.name = "NicknameField"
	field.placeholder_text = tr("Novo nickname (3 a 24)")
	field.max_length = 24
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.custom_minimum_size.y = 44
	PlayerUI.style_field(field)
	editor.add_child(field)
	PremiumUI.reveal_toggle(field)
	var save := _action_button("Salvar", "check", true, func() -> void:
		banner.show_state("loading")
		var result: Dictionary = await services.profile.update_nickname(field.text)
		status(result)
		if result.ok and is_visible_in_tree() and _category == 0: _show_category())
	save.name = "SaveNickname"
	editor.add_child(save)
	field.grab_focus.call_deferred()


func _change_password() -> void:
	if _side.has_node("PasswordEditor"): return
	var editor := VBoxContainer.new()
	editor.name = "PasswordEditor"
	_side.add_child(editor)
	_side.move_child(editor, _side.get_node("ChangePassword").get_index() + 1)
	var field := LineEdit.new()
	field.secret = true
	field.set_meta("qse_autocomplete", "new-password")
	field.placeholder_text = tr("Nova senha")
	field.custom_minimum_size.y = 44
	PlayerUI.style_field(field)
	editor.add_child(field)
	PremiumUI.reveal_toggle(field)
	var save := _action_button("Salvar senha", "check", true, func() -> void:
		banner.show_state("loading")
		status(await services.session.update_password(field.text)))
	editor.add_child(save)


func _provider() -> String:
	var meta: Variant = services.session.user.get("app_metadata", {})
	return str(meta.get("provider", "")) if meta is Dictionary else ""


func _provider_name() -> String:
	var provider := _provider()
	return {"google": "Google", "discord": "Discord", "email": "E-mail e senha", "": "E-mail e senha"}.get(provider, provider.capitalize())


## E-mail e provedor numa linha (usado também em testes antigos).
func _account_identity() -> String:
	var email := str(services.session.user.get("email", ""))
	return (email + " · " if not email.is_empty() else "") + _provider_name()


# --- 02 Áudio -------------------------------------------------------------------------

func _audio() -> void:
	_slider("speaker", "Volume geral", "master")
	_slider("note", "Música", "music")
	_slider("spark", "Efeitos sonoros", "sfx")
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 12)
	_content.add_child(pair)
	var mute := _toggle_row(pair, "mute", "Mutar áudio", bool(services.preferences.values.muted), func(value: bool) -> bool: return _save("muted", value))
	mute.name = "Mute"
	var menu_music := _toggle_row(pair, "note", "Música nos menus", bool(services.preferences.values.get("menu_music", true)), func(value: bool) -> bool:
		if not _save("menu_music", value): return false
		var player := _menu_music()
		if player != null:
			if value: player.resume()
			else: player.pause()
		return true)
	menu_music.name = "MenuMusicToggle"
	var manage := _action_button("Gerenciar músicas", "music_list", true, func() -> void: navigate_requested.emit("music", {}))
	manage.name = "ManageMusic"
	manage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(manage)
	# Prévia: só sons que existem de verdade (música do menu e efeitos sintetizados).
	_side_head("headphones", "Prévia de som", "Teste os principais áudios do jogo e ajuste conforme a sua preferência.")
	var player := _menu_music()
	var music_row := _side_row("note", "Música de fundo", str(player.current_track().get("title", "")) if player != null and not player.current_track().is_empty() else "", func() -> void:
		var music := _menu_music()
		if music == null: return
		if music.paused: music.resume()
		else: music.pause()
		_show_category())
	music_row.name = "PreviewMusic"
	music_row.icon = _icon("pause" if player != null and not player.paused else "play", ACCENT, 26)
	var effect := _side_row("spark", "Efeito sonoro", "", _play_effect)
	effect.name = "PreviewEffect"
	effect.icon = _icon("play", ACCENT, 26)
	_tip("Dica: você pode mutar todo o áudio rapidamente ou manter a música só nos menus.")


func _menu_music() -> MenuMusicPlayer:
	return get_node_or_null("/root/MenuMusic") as MenuMusicPlayer


func _play_effect() -> void:
	if _sfx == null:
		_sfx = (load("res://scripts/desert/t15d/combat_sfx.gd") as GDScript).new()
		add_child(_sfx)
	_sfx.play("checkpoint")


func _slider(icon: String, text: String, key: String) -> void:
	var compact := _compact()
	var card := PanelContainer.new()
	card.name = "Slider_" + key
	card.add_theme_stylebox_override("panel", _row_box())
	_content.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	card.add_child(line)
	line.add_child(_icon_rect(icon, ACCENT, 22 if compact else 30))
	var name_label := _plain(text, 16 if compact else 22, Color.WHITE)
	name_label.custom_minimum_size.x = 120 if compact else 210
	line.add_child(name_label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = services.preferences.values[key]
	slider.custom_minimum_size = Vector2(120, 32 if compact else 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := _flat(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 6, 0)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider", track)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]: slider.add_theme_icon_override(state, _grabber)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	line.add_child(slider)
	var percent := PlayerUI.label("%d%%" % roundi(float(services.preferences.values[key]) * 100), 16 if compact else 22, ACCENT)
	percent.custom_minimum_size.x = 52 if compact else 72
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(percent)
	slider.value_changed.connect(func(value: float) -> void:
		if _save(key, value): percent.text = "%d%%" % roundi(value * 100)
		else: slider.set_value_no_signal(float(services.preferences.values[key])))


# --- 03 Gráficos ----------------------------------------------------------------------

func _graphics() -> void:
	var values := services.preferences.values
	if _graphics_pending.is_empty(): _graphics_pending = {"quality": values.quality, "shadows": values.get("shadows", true), "window": values.get("window", "")}
	var compact := _compact()
	# Qualidade.
	var quality := _setting_row("monitor", "Qualidade gráfica", "Define o nível de detalhes visuais do jogo.")
	var segment := HBoxContainer.new()
	segment.name = "QualitySegment"
	segment.add_theme_constant_override("separation", 6)
	quality.add_child(segment)
	var keys := ["baixo", "medio", "alto"]
	var names := ["Baixa", "Média", "Alta"]
	for i in range(keys.size()):
		var choice := Button.new()
		choice.name = "Quality_" + keys[i]
		choice.text = tr(names[i])
		choice.toggle_mode = true
		choice.button_pressed = _graphics_pending.quality == keys[i]
		choice.custom_minimum_size = Vector2(64 if compact else 110, 36 if compact else 52)
		choice.add_theme_font_size_override("font_size", 14 if compact else 24)
		_style_tab(choice)
		choice.pressed.connect(func() -> void:
			_graphics_pending.quality = keys[i]
			_show_category())
		segment.add_child(choice)
	# Sombras (real: luz principal do palco dos personagens).
	var shadows := _setting_row("layers", "Sombras", "Sombras nos personagens do menu (o perfil Baixa já as desliga).")
	var shadow_toggle := _switch(bool(_graphics_pending.shadows) and _graphics_pending.quality != "baixo")
	shadow_toggle.name = "ShadowsToggle"
	shadow_toggle.disabled = _graphics_pending.quality == "baixo"
	shadow_toggle.toggled.connect(func(value: bool) -> void: _graphics_pending.shadows = value)
	shadows.add_child(shadow_toggle)
	# Resolução: janela no desktop; no navegador e no celular é a do aparelho.
	var resolution := _setting_row("expand", "Resolução", "Tamanho da janela do jogo." if DevicePreferences.window_supported() else "Definida pelo navegador ou pelo aparelho.")
	if DevicePreferences.window_supported():
		var options := OptionButton.new()
		options.name = "WindowSize"
		var labels := {"": tr("Padrão do sistema"), "1280x720": "1280 × 720 (HD)", "1600x900": "1600 × 900 (HD+)", "1920x1080": "1920 × 1080 (Full HD)", "fullscreen": tr("Tela cheia")}
		for value: String in DevicePreferences.WINDOW_SIZES: options.add_item(labels[value])
		options.select(DevicePreferences.WINDOW_SIZES.find(str(_graphics_pending.window)))
		options.custom_minimum_size = Vector2(200 if compact else 300, 36 if compact else 50)
		_style_option(options)
		options.item_selected.connect(func(index: int) -> void: _graphics_pending.window = DevicePreferences.WINDOW_SIZES[index])
		resolution.add_child(options)
	else:
		var current := get_viewport().get_visible_rect().size * get_viewport().get_final_transform().get_scale()
		resolution.add_child(_value_label("%d × %d" % [roundi(current.x), roundi(current.y)]))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(actions)
	var reset := _action_button("Restaurar padrão", "refresh", false, func() -> void:
		_graphics_pending = {"quality": GraphicsProfile.default_for_platform(), "shadows": true, "window": ""}
		_show_category())
	reset.name = "RestoreGraphics"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(reset)
	var apply := _action_button("Aplicar alterações", "check", true, func() -> void:
		var ok := _save("quality", _graphics_pending.quality) and _save("shadows", bool(_graphics_pending.shadows)) and _save("window", str(_graphics_pending.window))
		if ok: banner.show_state("success", tr("Configurações gráficas aplicadas."))
		_graphics_pending = {}
		_show_category())
	apply.name = "ApplyGraphics"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(apply)
	# Desempenho: só o que o motor mede de verdade.
	_side_head("gauge", "Desempenho", "Medição real deste aparelho, atualizada a cada segundo.")
	_perf_labels.clear()
	_meter("fps", "monitor", "FPS atual")
	_meter("memory", "memory", "Memória do jogo")
	_meter("video", "chip", "Memória de vídeo")
	_refresh_performance()
	_perf_timer.start()


func _meter(key: String, icon: String, title: String) -> void:
	var card := PanelContainer.new()
	card.name = "Meter_" + key
	card.add_theme_stylebox_override("panel", _row_box())
	_side.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	column.add_child(line)
	line.add_child(_icon_rect(icon, ACCENT, 22 if _compact() else 28))
	var name_label := PlayerUI.label(title, 15 if _compact() else 20, Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var value := _plain("—", 15 if _compact() else 20, ACCENT)
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.add_child(value)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", _flat(Color(1, 1, 1, 0.1), Color.TRANSPARENT, 4, 0))
	bar.add_theme_stylebox_override("fill", _flat(ACCENT, Color.TRANSPARENT, 4, 0))
	column.add_child(bar)
	_perf_labels[key] = [value, bar]


func _refresh_performance() -> void:
	if _perf_labels.is_empty() or not is_visible_in_tree():
		_perf_timer.stop()
		return
	var fps := Engine.get_frames_per_second()
	var target := float(maxi(Engine.max_fps, 60)) if Engine.max_fps > 0 else 60.0
	_perf_labels.fps[0].text = "%d FPS" % roundi(fps)
	_perf_labels.fps[1].value = clampf(fps / target, 0.0, 1.0) * 100.0
	var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
	var memory_peak := maxf(Performance.get_monitor(Performance.MEMORY_STATIC_MAX), memory)
	_perf_labels.memory[0].text = _bytes(memory)
	_perf_labels.memory[1].value = memory / memory_peak * 100.0 if memory_peak > 0 else 0.0
	var video := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	_perf_labels.video[0].text = _bytes(video) if video > 0 else tr("Não informado")
	_perf_labels.video[1].value = clampf(video / (1024.0 * 1024.0 * 1024.0), 0.0, 1.0) * 100.0


static func _bytes(value: float) -> String:
	if value >= 1024.0 * 1024.0 * 1024.0: return "%.1f GB" % (value / (1024.0 * 1024.0 * 1024.0))
	return "%d MB" % roundi(value / (1024.0 * 1024.0))


# --- 04 Controles ---------------------------------------------------------------------

func _controls() -> void:
	var compact := _compact()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	_content.add_child(top)
	var keyboard := VBoxContainer.new()
	keyboard.name = "KeyboardColumn"
	keyboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(keyboard)
	keyboard.add_child(_section_title("keyboard", "Controles do teclado"))
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 18)
	keyboard.add_child(keys)
	var wasd := VBoxContainer.new()
	wasd.add_theme_constant_override("separation", 6)
	keys.add_child(wasd)
	var upper := HBoxContainer.new()
	upper.alignment = BoxContainer.ALIGNMENT_CENTER
	upper.add_child(_keycap("W"))
	wasd.add_child(upper)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 6)
	for letter in ["A", "S", "D"]: lower.add_child(_keycap(letter))
	wasd.add_child(lower)
	var binds := VBoxContainer.new()
	binds.alignment = BoxContainer.ALIGNMENT_CENTER
	binds.add_theme_constant_override("separation", 10)
	keys.add_child(binds)
	for item: Array in [["accept_key", "Confirmar"], ["back_key", "Voltar"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var cap := _keycap(OS.get_keycode_string(int(services.preferences.values[item[0]])), true)
		cap.name = "Key_" + item[0]
		line.add_child(cap)
		line.add_child(_plain(item[1], 15 if compact else 20, Color.WHITE))
		binds.add_child(line)
	var separator := ColorRect.new()
	separator.color = Color(1, 1, 1, 0.1)
	separator.custom_minimum_size.x = 1
	top.add_child(separator)
	var touch := VBoxContainer.new()
	touch.name = "TouchColumn"
	touch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(touch)
	touch.add_child(_section_title("touch", "Controles por toque"))
	touch.add_child(_phone_preview())
	# Remapeamento real: as teclas de confirmar e voltar dos menus.
	var remap := PanelContainer.new()
	remap.name = "RemapPanel"
	remap.add_theme_stylebox_override("panel", _row_box())
	_content.add_child(remap)
	var remap_rows := VBoxContainer.new()
	remap_rows.add_theme_constant_override("separation", 8)
	remap.add_child(remap_rows)
	remap_rows.add_child(PlayerUI.label(tr("Remapear controles"), 16 if compact else 22, Color.WHITE))
	var remap_hint := PlayerUI.label(tr("Toque numa ação e pressione a nova tecla. Confirmar e Voltar precisam ser diferentes."), 12 if compact else 15, MUTED)
	remap_rows.add_child(remap_hint)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	remap_rows.add_child(buttons)
	for item: Array in [["Confirmar", "accept_key"], ["Voltar", "back_key"]]:
		var key_button := _action_button("%s: %s" % [tr(item[0]), OS.get_keycode_string(int(services.preferences.values[item[1]]))], "refresh", true, func() -> void: pass)
		key_button.name = "Remap_" + item[1]
		key_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_button.pressed.connect(_wait_for_key.bind(item[1], key_button))
		buttons.add_child(key_button)
	# Dicas: os comandos que o jogo realmente usa (fases do Deserto e menus).
	_side_head("bulb", "Dica de Controles", "Resumo rápido para jogar com mais conforto.")
	var pad := TextureRect.new()
	pad.texture = _icon("gamepad", ACCENT, 160)
	pad.custom_minimum_size = Vector2(0, 60 if compact else 120)
	pad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_side.add_child(pad)
	_hint_row("keyboard", "A, D / ← →", "Andar")
	_hint_row("keyboard", "W / Espaço", "Pular · S agacha")
	_hint_row("keyboard", "J, K · L, Shift", "Atacar · Defender")
	_hint_row("enter", OS.get_keycode_string(int(services.preferences.values.accept_key)), "Confirmar / Selecionar")
	_hint_row("logout", OS.get_keycode_string(int(services.preferences.values.back_key)), "Voltar / Cancelar")
	_hint_row("touch", "Toque", "Joystick à esquerda; pular, atacar e defender à direita.")


func _phone_preview() -> Control:
	var phone := PanelContainer.new()
	phone.name = "PhonePreview"
	var box := _flat(Color(0.03, 0.04, 0.07), GOLD_LIGHT, 18, 3)
	box.set_content_margin_all(8)
	phone.add_theme_stylebox_override("panel", box)
	var screen := Control.new()
	screen.custom_minimum_size = Vector2(200, 84) if _compact() else Vector2(300, 140)
	screen.clip_contents = true
	phone.add_child(screen)
	screen.draw.connect(func() -> void:
		var area := Rect2(Vector2.ZERO, screen.size)
		screen.draw_rect(area, Color(0.12, 0.16, 0.28))
		screen.draw_rect(Rect2(0, area.size.y * 0.72, area.size.x, area.size.y * 0.28), Color(0.2, 0.15, 0.1))
		var r := area.size.y * 0.24
		var stick := Vector2(r * 1.4, area.size.y - r * 1.3)
		screen.draw_circle(stick, r, Color(0, 0, 0, 0.45))
		screen.draw_arc(stick, r, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
		screen.draw_circle(stick, r * 0.4, ACCENT)
		for i in 3:
			var center := Vector2(area.size.x - r * (1.2 + i * 1.5), area.size.y - r * (1.0 + float(i % 2) * 1.1))
			screen.draw_circle(center, r * 0.55, Color(0, 0, 0, 0.45))
			screen.draw_arc(center, r * 0.55, 0, TAU, 24, ACCENT, 2.0))
	return phone


func _keycap(text: String, wide := false) -> Control:
	var compact := _compact()
	var cap := Label.new()
	cap.text = text
	cap.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.custom_minimum_size = Vector2((64 if wide else 38) if compact else (86 if wide else 54), 34 if compact else 50)
	cap.add_theme_font_size_override("font_size", 14 if compact else 24)
	cap.add_theme_color_override("font_color", Color.WHITE)
	var box := _flat(Color(0.06, 0.06, 0.07), ACCENT, 8, 2)
	box.shadow_color = Color(ACCENT, 0.25)
	box.shadow_size = 4
	cap.add_theme_stylebox_override("normal", box)
	return cap


func _hint_row(icon: String, key: String, text: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _row_box())
	_side.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	card.add_child(line)
	line.add_child(_icon_rect(icon, ACCENT, 20 if _compact() else 26))
	var key_label := PlayerUI.label(key, 13 if _compact() else 17, Color.WHITE)
	key_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	key_label.custom_minimum_size.x = 86 if _compact() else 140
	line.add_child(key_label)
	var detail := PlayerUI.label(text, 12 if _compact() else 15, MUTED)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(detail)


# --- 05 Idioma ------------------------------------------------------------------------

var _language_choice := ""

func _language() -> void:
	var compact := _compact()
	if _language_choice.is_empty(): _language_choice = str(services.preferences.values.locale)
	_content.add_child(_section_title("translate", "Idioma do texto"))
	var options := HBoxContainer.new()
	options.name = "LanguageOptions"
	options.add_theme_constant_override("separation", 16)
	_content.add_child(options)
	for item: Array in [["Português (Brasil)", "pt_BR", "br"], ["English", "en", "gb"]]:
		var selected: bool = _language_choice == item[1]
		var option := Button.new()
		option.name = "Locale_" + item[1]
		option.text = item[0]
		option.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		option.toggle_mode = true
		option.button_pressed = selected
		option.icon = _flag(item[2])
		option.expand_icon = false
		option.add_theme_constant_override("icon_max_width", 40 if compact else 70)
		option.add_theme_constant_override("h_separation", 14)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.custom_minimum_size.y = 56 if compact else 110
		option.add_theme_font_size_override("font_size", 16 if compact else 26)
		_style_tab(option)
		# Marca de seleção (✓ dourado) ou círculo vazio, como na referência.
		var mark := TextureRect.new()
		mark.name = "SelectionMark"
		var mark_svg := '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24">' + ('<circle cx="12" cy="12" r="10" fill="#f4cf7a"/><path d="M7 12.5l3.5 3.5L17 9" fill="none" stroke="#141006" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>' if selected else '<circle cx="12" cy="12" r="9.5" fill="none" stroke="#a8bad3" stroke-width="1.8"/>') + '</svg>'
		var mark_image := Image.new()
		mark_image.load_svg_from_string(mark_svg)
		mark.texture = ImageTexture.create_from_image(mark_image)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		option.add_child(mark)
		var mark_side := 24.0 if compact else 38.0
		mark.anchor_left = 1.0
		mark.anchor_right = 1.0
		mark.anchor_top = 0.5
		mark.anchor_bottom = 0.5
		mark.offset_left = -mark_side - 20
		mark.offset_right = -20
		mark.offset_top = -mark_side / 2
		mark.offset_bottom = mark_side / 2
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			var style := option.get_theme_stylebox(state).duplicate() as StyleBox
			style.content_margin_right = mark_side + 34
			option.add_theme_stylebox_override(state, style)
		option.pressed.connect(func() -> void:
			_language_choice = item[1]
			_show_category())
		options.add_child(option)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.1)
	rule.custom_minimum_size.y = 1
	_content.add_child(rule)
	var confirm := _action_button("Confirmar", "check", true, func() -> void:
		if _save("locale", _language_choice):
			_language_choice = ""
			render())
	confirm.name = "ConfirmLanguage"
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.custom_minimum_size.x = 200 if compact else 330
	_content.add_child(confirm)
	_side_head("book", "Pré-visualização", "Veja como o jogo será exibido no idioma selecionado.")
	var bubble := PanelContainer.new()
	bubble.name = "LanguageBubble"
	var bubble_box := _flat(Color(0.1, 0.07, 0.03), GOLD_LIGHT, 24, 3)
	bubble_box.shadow_color = Color(ACCENT, 0.35)
	bubble_box.shadow_size = 12
	bubble_box.set_content_margin_all(14 if compact else 22)
	bubble.add_theme_stylebox_override("panel", bubble_box)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sample := _plain("Jogar · Voltar\nConfigurações" if _language_choice == "pt_BR" else "Play · Back\nSettings", 15 if compact else 26, GOLD_LIGHT)
	sample.name = "LanguageSample"
	sample.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sample.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(sample)
	_side.add_child(bubble)
	var rule2 := ColorRect.new()
	rule2.color = Color(1, 1, 1, 0.1)
	rule2.custom_minimum_size.y = 1
	_side.add_child(rule2)
	_tip("Sobre o idioma: altera os textos do jogo, incluindo menus, mensagens e instruções. Nomes de cartas e decks continuam no idioma original.")


func _flag(code: String) -> Texture2D:
	var svg := ""
	if code == "br":
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="70" height="48" viewBox="0 0 70 48"><rect width="70" height="48" rx="6" fill="#1f9d48"/><path d="M35 6 63 24 35 42 7 24z" fill="#f6d33c"/><circle cx="35" cy="24" r="10" fill="#203a8f"/><path d="M25.5 22c6-2 13-1.5 19 2" stroke="#fff" stroke-width="1.6" fill="none"/></svg>'
	else:
		svg = '<svg xmlns="http://www.w3.org/2000/svg" width="70" height="48" viewBox="0 0 70 48"><rect width="70" height="48" rx="6" fill="#1f3a8a"/><path d="M0 0 70 48M70 0 0 48" stroke="#fff" stroke-width="9"/><path d="M0 0 70 48M70 0 0 48" stroke="#c8263a" stroke-width="3.5"/><path d="M35 0v48M0 24h70" stroke="#fff" stroke-width="13"/><path d="M35 0v48M0 24h70" stroke="#c8263a" stroke-width="7"/></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)


# --- Persistência e remapeamento ------------------------------------------------------

func _save(key: String, value: Variant) -> bool:
	var saved := services.preferences.set_preference(key, value)
	if is_instance_valid(_feedback):
		_feedback.text = tr("Não foi possível salvar a preferência neste dispositivo.")
		_feedback.visible = not saved
	return saved


func _wait_for_key(action: String, button: Button) -> void:
	if is_instance_valid(_binding_button) and not _waiting_action.is_empty():
		_binding_button.text = OS.get_keycode_string(int(services.preferences.values[_waiting_action]))
	_waiting_action = action
	_binding_button = button
	button.text = tr("Pressione uma tecla…")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _waiting_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var other := "back_key" if _waiting_action == "accept_key" else "accept_key"
	if code == int(services.preferences.values[other]):
		_feedback.text = tr("Escolha uma tecla diferente para confirmar e voltar.")
		_feedback.show()
		return
	if _save(_waiting_action, code):
		_binding_button.text = OS.get_keycode_string(code)
		_waiting_action = ""
		if _category == 3: _show_category.call_deferred()


# --- Componentes visuais --------------------------------------------------------------

func _panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := _flat(PANEL, EDGE, 18, 1)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 6)
	box.set_content_margin_all(0)
	if node_name == "SidePanel": box.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Cabeçalho do painel principal: filete dourado vertical, título e subtítulo.
func _panel_head(parent: Control) -> Array:
	var head := PanelContainer.new()
	head.name = "PanelHead"
	var box := _flat(Color(1, 1, 1, 0.02), Color.TRANSPARENT, 18, 0)
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	box.border_width_bottom = 1
	box.border_color = EDGE
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 18
	box.content_margin_bottom = 16
	head.add_theme_stylebox_override("panel", box)
	parent.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	head.add_child(row)
	var bar := ColorRect.new()
	bar.color = ACCENT
	bar.custom_minimum_size = Vector2(6, 0)
	row.add_child(bar)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var title := PlayerUI.label("", 34, Color.WHITE)
	title.name = "PanelTitle"
	text.add_child(title)
	var subtitle := PlayerUI.label("", 17, MUTED)
	subtitle.name = "PanelSubtitle"
	text.add_child(subtitle)
	return [title, subtitle]


func _side_head(icon: String, title: String, subtitle: String) -> void:
	var compact := _compact()
	var row := HBoxContainer.new()
	row.name = "SideHead"
	row.add_theme_constant_override("separation", 14)
	_side.add_child(row)
	var icon_rect := _icon_rect(icon, ACCENT, 34 if compact else 54)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon_rect)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	text.add_child(PlayerUI.label(title, 18 if compact else 30, Color.WHITE))
	if not compact: text.add_child(PlayerUI.label(subtitle, 15, MUTED))
	var rule := ColorRect.new()
	rule.color = EDGE
	rule.custom_minimum_size.y = 1
	_side.add_child(rule)


func _section_title(icon: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_icon_rect(icon, Color.WHITE, 24 if _compact() else 34))
	row.add_child(_plain(text, 16 if _compact() else 24, Color.WHITE))
	return row


## Linha de informação do perfil: ícone, rótulo, valor e espaço para uma ação.
func _info_row(parent: Control, icon: String, title: String, value: String) -> PanelContainer:
	var compact := _compact()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _row_box())
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14 if compact else 24)
	card.add_child(line)
	line.add_child(_icon_rect(icon, MUTED, 20 if compact else 30))
	var label := _plain(title, 13 if compact else 18, MUTED)
	label.custom_minimum_size.x = 70 if compact else (104 if UIScale.is_iphone() else 130)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	var shown := PlayerUI.label(value, 14 if compact else 22, Color.WHITE)
	shown.name = "Value"
	shown.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shown.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shown.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(shown)
	return card


## Linha clicável do painel lateral (ação com seta).
func _side_row(icon: String, title: String, detail: String, action: Callable) -> Button:
	var compact := _compact()
	var button := Button.new()
	button.text = tr(title) + ("\n" + detail if not detail.is_empty() else "")
	button.icon = _icon(icon, ACCENT, 30)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 22 if compact else 30)
	button.add_theme_constant_override("h_separation", 16)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 44 if compact else (74 if not detail.is_empty() else 64)
	button.add_theme_font_size_override("font_size", 14 if compact else 24)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := _row_box()
		if state == "hover" or state == "focus": box.border_color = Color(ACCENT, 0.6)
		if state == "focus": box.draw_center = true
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.75))
	var chevron := TextureRect.new()
	chevron.texture = _icon("chevron", MUTED, 24)
	chevron.custom_minimum_size = Vector2.ONE * 20
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(chevron)
	chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chevron.position.x -= 16
	button.pressed.connect(action)
	_side.add_child(button)
	return button


func _setting_row(icon: String, title: String, detail: String) -> HBoxContainer:
	var compact := _compact()
	var card := PanelContainer.new()
	card.name = "Setting_" + title.replace(" ", "")
	card.add_theme_stylebox_override("panel", _row_box())
	_content.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	card.add_child(line)
	var icon_rect := _icon_rect(icon, ACCENT, 26 if compact else 40)
	line.add_child(icon_rect)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	text.add_child(PlayerUI.label(title, PlayerUI.CONTROL_FONT, Color.WHITE))
	text.add_child(PlayerUI.label(detail, 11 if compact else 15, MUTED))
	return line


func _toggle_row(parent: Control, icon: String, title: String, value: bool, on_change: Callable) -> CheckButton:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _row_box())
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	card.add_child(line)
	line.add_child(_icon_rect(icon, ACCENT, 22 if _compact() else 30))
	var label := PlayerUI.label(title, 15 if _compact() else 21, Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	var toggle := _switch(value)
	toggle.toggled.connect(func(state: bool) -> void:
		if not on_change.call(state): toggle.set_pressed_no_signal(not state))
	line.add_child(toggle)
	return toggle


func _switch(value: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["checked", "checked_disabled"]: toggle.add_theme_icon_override(state, _toggle_on)
	for state in ["unchecked", "unchecked_disabled"]: toggle.add_theme_icon_override(state, _toggle_off)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: toggle.add_theme_stylebox_override(state, empty)
	var focus := _flat(Color.TRANSPARENT, ACCENT, 14, 2)
	focus.draw_center = false
	toggle.add_theme_stylebox_override("focus", focus)
	return toggle


## Rótulo de uma linha só, do tamanho do texto (sem quebra nem expansão).
func _plain(text: String, font_size: int, color: Color) -> Label:
	var label := PlayerUI.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _value_label(text: String) -> Label:
	var label := PlayerUI.label(text, 15 if _compact() else 20, ACCENT)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _tip(text: String) -> void:
	var card := PanelContainer.new()
	card.name = "Tip"
	var box := _flat(Color(0.12, 0.09, 0.04, 0.85), Color(ACCENT, 0.55), 12, 1)
	box.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", box)
	_side.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	card.add_child(line)
	var icon := _icon_rect("info", ACCENT, 22 if _compact() else 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(icon)
	var label := PlayerUI.label(text, 12 if _compact() else 16, Color("#e8dcc4"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)


func _action_button(text: String, icon: String, primary: bool, action: Callable) -> Button:
	var compact := _compact()
	var button := Button.new()
	button.text = tr(text)
	button.icon = _icon(icon, INK if primary else ACCENT, 30)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 20 if compact else 28)
	button.add_theme_constant_override("h_separation", 12)
	button.custom_minimum_size = Vector2(220, 72)
	button.add_theme_font_size_override("font_size", PlayerUI.CONTROL_FONT)
	if primary: _style_gold(button)
	else: _style_outline(button)
	button.pressed.connect(action)
	return button


func _icon_button(icon: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.tooltip_text = tr(tooltip)
	button.icon = _icon(icon, ACCENT, 28)
	button.expand_icon = false
	button.custom_minimum_size = Vector2.ONE * (36 if _compact() else 48)
	_style_outline(button)
	button.pressed.connect(action)
	return button


func _icon_rect(icon: String, color: Color, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _icon(icon, color, maxi(side * 2, 48))
	rect.custom_minimum_size = Vector2.ONE * side
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _icon(name: String, color: Color, pixels: int) -> Texture2D:
	var key := "%s|%s|%d" % [name, color.to_html(), pixels]
	if _icon_cache.has(key): return _icon_cache[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [pixels, pixels, color.to_html(false), ICONS.get(name, "")]
	var image := Image.new()
	image.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(image)
	_icon_cache[key] = texture
	return texture


## Aba (e opções segmentadas): grafite; selecionada em dourado com contorno iluminado.
func _style_tab(node: Button) -> void:
	var normal := _flat(Color(0.06, 0.085, 0.13), EDGE, 12, 1)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(ACCENT, 0.55)
	var selected := _flat(Color("#b6872f"), GOLD_LIGHT, 12, 2)
	selected.shadow_color = Color(ACCENT, 0.4)
	selected.shadow_size = 12
	var focus := _flat(Color.TRANSPARENT, GOLD_LIGHT, 12, 2)
	focus.draw_center = false
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", selected)
	node.add_theme_stylebox_override("hover_pressed", selected)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_stylebox_override("disabled", normal)
	for state in ["font_color", "font_hover_color", "font_focus_color"]: node.add_theme_color_override(state, Color("#e8edf5"))
	for state in ["font_pressed_color", "font_hover_pressed_color"]: node.add_theme_color_override(state, Color.WHITE)
	for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]: node.add_theme_color_override(state, Color.WHITE)


func _style_gold(node: Button) -> void:
	var box := _flat(Color("#c3923a"), GOLD_LIGHT, 12, 2)
	box.shadow_color = Color(ACCENT, 0.35)
	box.shadow_size = 10
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#d4a347")
	var focus := _flat(Color.TRANSPARENT, Color.WHITE, 12, 2)
	focus.draw_center = false
	node.add_theme_stylebox_override("normal", box)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_stylebox_override("disabled", _flat(Color(0.25, 0.22, 0.16), Color.TRANSPARENT, 12, 0))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: node.add_theme_color_override(state, INK)


func _style_outline(node: Button) -> void:
	var box := _flat(Color(0.05, 0.07, 0.11), Color(ACCENT, 0.85), 12, 2)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.1, 0.1, 0.1)
	var focus := _flat(Color.TRANSPARENT, GOLD_LIGHT, 12, 2)
	focus.draw_center = false
	node.add_theme_stylebox_override("normal", box)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_stylebox_override("disabled", box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: node.add_theme_color_override(state, Color("#f1e6d0"))


func _style_option(node: OptionButton) -> void:
	_style_outline(node)
	node.add_theme_font_size_override("font_size", 14 if _compact() else 24)


func _style_toggle(node: CheckButton) -> void:
	node.add_theme_icon_override("checked", _toggle_on)
	node.add_theme_icon_override("unchecked", _toggle_off)
	node.add_theme_icon_override("checked_disabled", _toggle_on)
	node.add_theme_icon_override("unchecked_disabled", _toggle_off)
	node.add_theme_font_size_override("font_size", 14 if _compact() else 24)
	var card := _row_box()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: node.add_theme_stylebox_override(state, card)
	var focus := _row_box()
	focus.draw_center = false
	focus.border_color = ACCENT
	node.add_theme_stylebox_override("focus", focus)


func _row_box() -> StyleBoxFlat:
	var box := _flat(ROW, Color(1, 1, 1, 0.06), 12, 1)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10 if _compact() else 14
	box.content_margin_bottom = 10 if _compact() else 14
	return box


func _flat(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(10)
	box.anti_aliasing = true
	return box


func _make_icons() -> void:
	var grabber := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var distance := Vector2(x - 13.5, y - 13.5).length()
			grabber.set_pixel(x, y, Color(1, 1, 1, clampf(13.5 - distance, 0.0, 1.0)) if distance < 12.0 else Color(ACCENT, clampf(13.5 - distance, 0.0, 1.0)))
	_grabber = ImageTexture.create_from_image(grabber)
	_toggle_on = ImageTexture.create_from_image(_pill(true))
	_toggle_off = ImageTexture.create_from_image(_pill(false))


func _pill(on: bool) -> Image:
	var image := Image.create(64, 34, false, Image.FORMAT_RGBA8)
	for y in 34:
		for x in 64:
			var inside := Vector2(clampf(x, 17, 47) - x, 17 - y).length() <= 16.5
			if inside: image.set_pixel(x, y, ACCENT if on else Color(0.2, 0.24, 0.3))
	var knob := Vector2(47 if on else 17, 17)
	for y in 34:
		for x in 64:
			if Vector2(x, y).distance_to(knob) <= 12.5: image.set_pixel(x, y, Color.WHITE if on else Color("#c8cfda"))
	return image
