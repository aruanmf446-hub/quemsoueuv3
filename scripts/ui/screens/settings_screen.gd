extends PlayerScreen

const ACCENT := Color("#f2c76e")
const MUTED := Color("#a8bad3")
const GLASS := Color(0.035, 0.06, 0.11, 0.92)
const INK := Color("#141006")
var _grabber: ImageTexture
var _toggle_on: ImageTexture
var _toggle_off: ImageTexture
var _category := 0
var _waiting_action := ""
var _binding_button: Button
var _content: VBoxContainer
var _feedback: Label
var _tabs: Array[Button] = []
var _layout: HBoxContainer
var _scroll: ScrollContainer
var _rail: VBoxContainer

func _ready() -> void:
	manages_own_scale = true
	super._ready()
	$CrestFrame.hide()
	$Tint.color = Color(0.02, 0.035, 0.07, 0.86)
	_make_icons()
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _waiting_action = "")
	resized.connect(_adapt)
	services.session.changed.connect(func() -> void:
		_waiting_action = ""
		if is_visible_in_tree(): render())

func render() -> void:
	_waiting_action = ""
	PlayerUI.clear(body)
	heading.text = tr("Configurações")
	heading.add_theme_color_override("font_color", Color.WHITE)
	banner.hide()
	$Margin/Column/Header/Back.text = tr("‹ Voltar")
	_style_button($Margin/Column/Header/Back)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout = PlayerUI.row(body)
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 28)
	_rail = PlayerUI.column(_layout)
	_rail.size_flags_horizontal = Control.SIZE_FILL
	_rail.add_child(PlayerUI.label("AJUSTES", 16, ACCENT))
	_rail.add_child(PlayerUI.label("Sua experiência", 26))
	_tabs.clear()
	var names := ["Áudio", "Gráficos", "Controles", "Idioma"]
	for i in range(names.size()):
		var tab := _button("0%d   %s" % [i + 1, tr(names[i])], _select.bind(i))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.toggle_mode = true
		_style_tab(tab)
		tab.button_pressed = i == _category
		_rail.add_child(tab)
		_tabs.append(tab)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass(24))
	_layout.add_child(panel)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_content = PlayerUI.column(scroll)
	_content.add_theme_constant_override("separation", 20)
	_feedback = PlayerUI.label("Preferências salvas neste dispositivo.", 18, MUTED)
	body.add_child(_feedback)
	_show_category()
	_adapt()

func _adapt() -> void:
	if not is_instance_valid(_rail): return
	var compact := UIScale.is_compact()
	var factor := maxf(1.0, UIScale.unit_for(get_viewport())) if compact else 1.0
	var margin: MarginContainer = $Margin
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = size / factor
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16 if compact else 48)
	_rail.custom_minimum_size.x = 170 if compact else 280
	_rail.add_theme_constant_override("separation", 8 if compact else 14)
	_layout.add_theme_constant_override("separation", 20 if compact else 28)
	$Margin/Column.add_theme_constant_override("separation", 12 if compact else 18)
	_feedback.add_theme_font_size_override("font_size", 16 if compact else 18)
	var panel: PanelContainer = _layout.get_child(1)
	panel.add_theme_stylebox_override("panel", _glass(16 if compact else 24))
	_rail.get_child(0).visible = not compact
	_rail.get_child(1).visible = not compact
	for tab in _tabs:
		tab.custom_minimum_size = Vector2(150, 48 if compact else 56)
		tab.add_theme_font_size_override("font_size", 19 if compact else 21)
	$Margin/Column/Header/Back.custom_minimum_size = Vector2(110 if compact else 170, 48 if compact else 56)
	heading.add_theme_font_size_override("font_size", 28 if compact else 38)

func _select(index: int) -> void:
	_waiting_action = ""
	_category = index
	for i in range(_tabs.size()): _tabs[i].button_pressed = i == index
	_show_category()

func _show_category() -> void:
	_scroll.scroll_vertical = 0
	PlayerUI.clear(_content)
	match _category:
		0: _audio()
		1: _graphics()
		2: _controls()
		3: _language()

func _title(title: String, subtitle: String) -> void:
	var head := PlayerUI.label(title.to_upper(), 30, Color.WHITE)
	_content.add_child(head)
	var line := ColorRect.new()
	line.color = ACCENT
	line.custom_minimum_size = Vector2(56, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(line)
	_content.add_child(PlayerUI.label(subtitle, 19, MUTED))

func _audio() -> void:
	_title("Áudio", "Ajuste o som da sua aventura.")
	_slider("Volume geral", "master")
	_slider("Música", "music")
	_slider("Efeitos sonoros", "sfx")
	var mute := CheckButton.new()
	mute.text = tr("Silenciar todo o áudio")
	mute.button_pressed = services.preferences.values.muted
	mute.custom_minimum_size.y = 52
	_style_toggle(mute)
	mute.toggled.connect(func(value: bool) -> void:
		if not _save("muted", value): mute.set_pressed_no_signal(not value))
	_content.add_child(mute)
	_content.add_child(PlayerUI.label("A música toca exclusivamente no menu. Seus volumes são mantidos ao silenciar.", 18, MUTED))
	var manage := _button("Gerenciar músicas", func() -> void: navigate_requested.emit("music", {}))
	manage.name = "ManageMusic"
	_content.add_child(manage)

func _slider(text: String, key: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _row_box())
	_content.add_child(card)
	var stack := PlayerUI.column(card)
	stack.add_theme_constant_override("separation", 4)
	var line := PlayerUI.row(stack)
	line.add_child(PlayerUI.label(text, 22))
	var percent := PlayerUI.label("%d%%" % roundi(float(services.preferences.values[key]) * 100), 22, ACCENT)
	percent.size_flags_horizontal = Control.SIZE_FILL
	percent.custom_minimum_size.x = 64
	line.add_child(percent)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = services.preferences.values[key]
	slider.custom_minimum_size = Vector2(180, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := _box(Color(1, 1, 1, 0.12), 0)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(state, _grabber)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.value_changed.connect(func(value: float) -> void:
		if _save(key, value): percent.text = "%d%%" % roundi(value * 100)
		else: slider.set_value_no_signal(float(services.preferences.values[key])))
	stack.add_child(slider)

func _graphics() -> void:
	_title("Gráficos", "Qualidade da prévia 3D dos personagens.")
	var quality := OptionButton.new()
	quality.custom_minimum_size.y = 56
	_style_button(quality)
	var keys := ["baixo", "medio", "alto"]
	for text: String in ["Baixa", "Média", "Alta"]: quality.add_item(tr(text))
	quality.select(keys.find(services.preferences.values.quality))
	quality.item_selected.connect(func(index: int) -> void:
		if not _save("quality", keys[index]): quality.select(keys.find(services.preferences.values.quality)))
	_content.add_child(quality)
	for text: String in ["Baixa: meia resolução, sem sombras e sem antisserrilhamento.", "Média: resolução integral, sombras e MSAA 2×.", "Alta: resolução integral, sombras e MSAA 4×."]:
		_content.add_child(PlayerUI.label(text, 20, MUTED))
	_content.add_child(PlayerUI.label("Aplicado à prévia 3D. As configurações de combate são preservadas.", 18, ACCENT))

func _controls() -> void:
	_title("Controles", "Personalize as teclas de navegação dos menus.")
	for item: Array in [["Confirmar", "accept_key"], ["Voltar", "back_key"]]:
		var line := PlayerUI.row(_content)
		line.add_child(PlayerUI.label(item[0]))
		var key_button := _button(OS.get_keycode_string(int(services.preferences.values[item[1]])), func() -> void: pass)
		key_button.pressed.connect(_wait_for_key.bind(item[1], key_button))
		line.add_child(key_button)
	for text: String in ["Teclado: Tab e setas para navegar; teclas acima para confirmar e voltar.", "Mouse: clique para selecionar; arraste os controles de volume.", "Toque: toque para selecionar; deslize para rolar e ajustar o volume.", "Combate: A/D ou setas, Espaço e J/K. Comandos do gameplay preservados."]:
		_content.add_child(PlayerUI.label(text, 19, MUTED))

func _language() -> void:
	_title("Idioma", "Escolha o idioma da interface.")
	for item: Array in [["Português (Brasil)", "pt_BR"], ["English", "en"]]:
		var locale_button := _button(item[0], func() -> void:
			if _save("locale", item[1]): render())
		locale_button.toggle_mode = true
		locale_button.button_pressed = services.preferences.values.locale == item[1]
		_content.add_child(locale_button)
	_content.add_child(PlayerUI.label("O inglês está disponível parcialmente. Textos sem tradução permanecem em português.", 18, MUTED))
	var account := PlayerUI.column(_content)
	account.add_child(PlayerUI.label("Conta", 24, ACCENT))
	account.add_child(PlayerUI.label(str(services.session.user.get("email", "Demonstração local • sem conta conectada"))))
	if services.session.authenticated():
		var discoverable := CheckButton.new()
		discoverable.text = tr("Permitir busca do meu perfil público")
		discoverable.button_pressed = services.profile.data.get("discoverable", false)
		discoverable.disabled = services.profile.state != "success"
		discoverable.custom_minimum_size.y = 52
		_style_toggle(discoverable)
		discoverable.toggled.connect(func(value: bool) -> void: status(await services.profile.set_discoverable(value)))
		account.add_child(discoverable)
	account.add_child(_button("Entrar na conta", func() -> void: navigate_requested.emit("account", {})))
	if services.session.authenticated():
		account.add_child(_button("Sair da conta", func() -> void:
			await services.session.sign_out()
			render()))

func _save(key: String, value: Variant) -> bool:
	var saved := services.preferences.set_preference(key, value)
	_feedback.text = tr("Preferências salvas neste dispositivo." if saved else "Não foi possível salvar a preferência neste dispositivo.")
	_feedback.add_theme_color_override("font_color", MUTED if saved else Color("#ff9797"))
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
		return
	if _save(_waiting_action, code):
		_binding_button.text = OS.get_keycode_string(code)
		_waiting_action = ""

func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = tr(text)
	node.custom_minimum_size = Vector2(150, 56)
	_style_button(node)
	node.pressed.connect(action)
	return node

## Botões inclinados no estilo dos menus de jogos esportivos: vidro escuro com borda
## dourada; pressionado/selecionado fica dourado com texto escuro.
func _style_button(node: Button) -> void:
	node.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var style := _box(Color(0.07, 0.11, 0.18, 0.95), 14)
		style.skew = Vector2(0.18, 0)
		style.set_corner_radius_all(3)
		style.border_color = Color(ACCENT, 0.45)
		style.set_border_width_all(1)
		if state == "hover": style.bg_color = Color(0.11, 0.17, 0.26, 0.95)
		if state in ["pressed", "hover_pressed"]:
			style.bg_color = ACCENT
		if state == "focus":
			style.draw_center = false
			style.border_color = ACCENT
			style.set_border_width_all(2)
		node.add_theme_stylebox_override(state, style)
	for color in ["font_color", "font_hover_color", "font_focus_color"]:
		node.add_theme_color_override(color, Color.WHITE)
	for color in ["font_pressed_color", "font_hover_pressed_color"]:
		node.add_theme_color_override(color, INK)

func _style_tab(node: Button) -> void:
	_style_button(node)
	var normal := node.get_theme_stylebox("normal") as StyleBoxFlat
	normal.border_color = Color(1, 1, 1, 0.08)

func _style_toggle(node: CheckButton) -> void:
	node.add_theme_icon_override("checked", _toggle_on)
	node.add_theme_icon_override("unchecked", _toggle_off)
	node.add_theme_icon_override("checked_disabled", _toggle_on)
	node.add_theme_icon_override("unchecked_disabled", _toggle_off)
	node.add_theme_font_size_override("font_size", 21)
	var card := _row_box()
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		node.add_theme_stylebox_override(state, card)
	var focus := _row_box()
	focus.draw_center = false
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)

func _glass(padding: int) -> StyleBoxFlat:
	var box := _box(GLASS, padding)
	box.set_corner_radius_all(14)
	box.border_color = Color(ACCENT, 0.25)
	box.border_width_top = 2
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 18
	return box

func _row_box() -> StyleBoxFlat:
	var box := _box(Color(1, 1, 1, 0.04), 16)
	box.set_corner_radius_all(10)
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

## Ícones desenhados em código, em alta resolução, para o deslizador e o interruptor.
func _make_icons() -> void:
	if _grabber != null: return
	var size := 64
	var dot := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length()
			var a := clampf(size * 0.5 - 1.0 - d, 0.0, 1.0)
			var ring := clampf(size * 0.5 - 7.0 - d, 0.0, 1.0)
			dot.set_pixel(x, y, Color(ACCENT.lerp(Color.WHITE, 0.0), a) if ring <= 0.0 else Color(1, 1, 1, a))
	dot.resize(30, 30, Image.INTERPOLATE_LANCZOS)
	_grabber = ImageTexture.create_from_image(dot)
	_toggle_on = ImageTexture.create_from_image(_pill(true))
	_toggle_off = ImageTexture.create_from_image(_pill(false))

func _pill(on: bool) -> Image:
	var w := 128
	var h := 68
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var knob := Vector2(w - r, r) if on else Vector2(r, r)
	for y in range(h):
		for x in range(w):
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var dist := p.distance_to(Vector2(cx, r))
			var a := clampf(r - 1.0 - dist, 0.0, 1.0)
			var color := ACCENT if on else Color(1, 1, 1, 0.18)
			color.a *= a
			var kd := p.distance_to(knob)
			var ka := clampf(r - 7.0 - kd, 0.0, 1.0)
			image.set_pixel(x, y, color.lerp(Color(INK if on else Color.WHITE, 1.0), ka) if ka > 0.0 else color)
	image.resize(56, 30, Image.INTERPOLATE_LANCZOS)
	return image

func _box(color: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(12)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
