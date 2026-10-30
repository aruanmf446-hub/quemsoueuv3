extends PlayerScreen

const ACCENT := PlayerUI.GOLD
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
	_tabs.clear()
	var names := ["Áudio", "Gráficos", "Controles", "Idioma"]
	for i in range(names.size()):
		var tab := _button(tr(names[i]), _select.bind(i))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.toggle_mode = true
		tab.icon = _tab_icon(i)
		_style_tab(tab)
		tab.button_pressed = i == _category
		_rail.add_child(tab)
		_tabs.append(tab)
	var panel := PanelContainer.new()
	panel.name = "ContentPanel"
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
	# Só aparece quando algo dá errado; salvar com sucesso não precisa de aviso.
	_feedback = PlayerUI.label("", 18, Color("#ff9797"))
	_feedback.hide()
	body.add_child(_feedback)
	_show_category()
	_adapt()

func _adapt() -> void:
	if not is_instance_valid(_rail): return
	var compact := UIScale.is_compact()
	var factor := PlayerUI.unit(self)
	var margin: MarginContainer = $Margin
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = size / factor
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16 if compact else 48)
	_rail.custom_minimum_size.x = 150 if compact else 240
	_rail.add_theme_constant_override("separation", 8 if compact else 14)
	_layout.add_theme_constant_override("separation", 12 if compact else 28)
	$Margin/Column.add_theme_constant_override("separation", 12 if compact else 18)
	_feedback.add_theme_font_size_override("font_size", 16 if compact else 18)
	var panel: PanelContainer = _layout.get_child(1)
	panel.add_theme_stylebox_override("panel", _glass(12 if compact else 24))
	for tab in _tabs:
		tab.custom_minimum_size = Vector2(150, 48 if compact else 56)
		tab.add_theme_font_size_override("font_size", 19 if compact else 21)
	$Margin/Column/Header/Back.custom_minimum_size = Vector2(110 if compact else 170, 48 if compact else 56)
	heading.add_theme_font_size_override("font_size", 28 if compact else 34)
	_fit_panel.call_deferred()

func _select(index: int) -> void:
	_waiting_action = ""
	_category = index
	for i in range(_tabs.size()): _tabs[i].button_pressed = i == index
	_show_category()
	PlayerUI.cascade(_content)


func animate_in() -> void:
	PlayerUI.cascade(_rail)
	PlayerUI.cascade(_content)

func _show_category() -> void:
	_scroll.scroll_vertical = 0
	PlayerUI.clear(_content)
	match _category:
		0: _audio()
		1: _graphics()
		2: _controls()
		3: _language()
	_fit_panel.call_deferred()


## O painel cresce só até o conteúdo (sem o vazio enorme embaixo); se não couber, rola.
func _fit_panel() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_layout): return
	var panel := _scroll.get_parent() as PanelContainer
	var chrome := panel.get_theme_stylebox("panel").get_minimum_size().y
	var room := maxf(_layout.size.y - chrome, 120.0)
	_scroll.custom_minimum_size.y = minf(_content.get_combined_minimum_size().y, room)


const TAB_ICONS := [
	'<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11"/>',
	'<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4"/>',
	'<path d="M7 8h10a4 4 0 0 1 4 4v2a3 3 0 0 1-5.4 1.8L14 14h-4l-1.6 1.8A3 3 0 0 1 3 14v-2a4 4 0 0 1 4-4z"/><path d="M7 11v3M5.5 12.5h3"/><circle cx="16" cy="11.5" r="0.6"/><circle cx="18" cy="13.5" r="0.6"/>',
	'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
]


func _tab_icon(index: int) -> Texture2D:
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' + TAB_ICONS[index] + '</g></svg>'
	var image := Image.new()
	image.load_svg_from_string(svg, 1.25)
	return ImageTexture.create_from_image(image)

func _title(title: String) -> void:
	var head := PlayerUI.label(title.to_upper(), 30, Color.WHITE)
	_content.add_child(head)
	var line := ColorRect.new()
	line.color = ACCENT
	line.custom_minimum_size = Vector2(56, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(line)

func _audio() -> void:
	_title("Áudio")
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
	_title("Gráficos")
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _row_box())
	_content.add_child(card)
	var stack := PlayerUI.column(card)
	stack.add_child(PlayerUI.label("Qualidade", 22))
	var choices := PlayerUI.row(stack)
	choices.add_theme_constant_override("separation", 10)
	var keys := ["baixo", "medio", "alto"]
	var names := ["Baixa", "Média", "Alta"]
	for i in range(keys.size()):
		var choice := _button(names[i], func() -> void:
			if _save("quality", keys[i]): _show_category())
		choice.custom_minimum_size.x = 100
		choice.toggle_mode = true
		choice.button_pressed = services.preferences.values.quality == keys[i]
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(choice)

func _controls() -> void:
	_title("Controles")
	for item: Array in [["Confirmar", "accept_key"], ["Voltar", "back_key"]]:
		var row_card := PanelContainer.new()
		row_card.add_theme_stylebox_override("panel", _row_box())
		_content.add_child(row_card)
		var line := PlayerUI.row(row_card)
		var key_label := PlayerUI.label(item[0], 22)
		key_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(key_label)
		var key_button := _button(OS.get_keycode_string(int(services.preferences.values[item[1]])), func() -> void: pass)
		key_button.pressed.connect(_wait_for_key.bind(item[1], key_button))
		line.add_child(key_button)

func _language() -> void:
	_title("Idioma")
	for item: Array in [["Português (Brasil)", "pt_BR"], ["English", "en"]]:
		var locale_button := _button(item[0], func() -> void:
			if _save("locale", item[1]): render())
		locale_button.toggle_mode = true
		locale_button.button_pressed = services.preferences.values.locale == item[1]
		_content.add_child(locale_button)
	var account := PlayerUI.column(_content)
	account.add_child(PlayerUI.label("Conta", 24, ACCENT))
	account.add_child(PlayerUI.label(str(services.session.user.get("email", "Demonstração local • sem conta conectada"))))
	if services.session.authenticated():
		var discoverable := CheckButton.new()
		discoverable.text = tr("Permitir busca do perfil")
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

func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = tr(text)
	node.custom_minimum_size = Vector2(150, 56)
	_style_button(node)
	PlayerUI.fluid(node)
	node.pressed.connect(action)
	return node

## Botões e abas no modelo das telas do jogador (PlayerUI, a partir da referência aprovada):
## superfície escura com filete; a aba/opção selecionada fica âmbar escuro com filete dourado.
func _style_button(node: Button) -> void:
	node.add_theme_font_size_override("font_size", 21)
	PlayerUI.style_button(node, false)

func _style_tab(node: Button) -> void:
	_style_button(node)
	node.add_theme_constant_override("h_separation", 12)
	node.add_theme_color_override("icon_normal_color", Color.WHITE)
	node.add_theme_color_override("icon_hover_color", Color.WHITE)
	node.add_theme_color_override("icon_focus_color", Color.WHITE)
	node.add_theme_color_override("icon_pressed_color", Color.WHITE)
	node.add_theme_color_override("icon_hover_pressed_color", Color.WHITE)

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

## Painel do conteúdo no modelo (PlayerUI.frame_panel).
func _glass(padding: int) -> StyleBoxFlat:
	return PlayerUI.frame_panel(padding)

func _row_box() -> StyleBoxFlat:
	var box := _box(Color(1, 1, 1, 0.04), 16)
	box.set_corner_radius_all(4)
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
