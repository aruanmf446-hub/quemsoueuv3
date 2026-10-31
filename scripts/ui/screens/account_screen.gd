extends PlayerScreen
## T18A: ilustracao e controles independentes. Nao renderiza Cowboy 3D na tela de login.
## A camada ilustrada e um arquivo de alta resolucao gerado da referencia aprovada;
## veja assets/auth/README.md. Sem arquivo, o castelo do jogo fica como fallback.
const ART_FALLBACK := preload("res://assets/auth/login_cinematic_bg.webp")
const LOGO := preload("res://assets/auth/login_logo.webp")
const GOLD := Color("#eebc64")
const WHITE := Color("#fff8ef")
const MUTED := Color("#d7bfa4")
const PROVIDERS := [
	{"id":"google","name":"Google","bg":Color("#f8f9fa"),"ink":Color("#22252c"),"icon":"res://assets/auth/google.svg"},
	{"id":"discord","name":"Discord","bg":Color("#4f48e8"),"ink":Color.WHITE,"icon":"res://assets/auth/discord.svg"}
]
var _mode := "choose"
var _root: Control
var _logo: TextureRect
var _scroll: ScrollContainer
var _feedback: Label
var _email: LineEdit
var _password: LineEdit
var _confirm: LineEdit
var _remember_email := ""
var _notice := ""
var _notice_error := false
var _working := false
var _buttons: Array[Button] = []


func _ready() -> void:
	manages_own_scale = true
	super._ready()
	$Margin.hide()
	$Backdrop.texture = ART_FALLBACK
	$Backdrop.show()
	$Tint.color = Color(0.012, 0.016, 0.04, 0.12)
	_root = Control.new()
	_root.name = "CinematicAuthOverlay"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var back := Button.new()
	back.name = "AuthBack"
	back.text = "‹ Voltar"
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(func() -> void: back_requested.emit())
	PlayerUI.style_button(back, false)
	_root.add_child(back)
	back.set_meta("auth_back", true)

	_logo = TextureRect.new()
	_logo.name = "OfficialLogo"
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_root.add_child(_logo)

	services.session.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	services.session.providers_changed.connect(func() -> void:
		if is_visible_in_tree() and _mode == "choose": render())
	resized.connect(_layout_auth)
	_layout_auth.call_deferred()


func show_screen(params: Dictionary = {}) -> void:
	parameters = params.duplicate(true)
	var back_button := _root.get_node_or_null("AuthBack") as Button
	if back_button != null:
		back_button.text = "Jogar sem conta" if bool(params.get("startup", false)) else "‹ Voltar"
	show()
	if services.session.needs_password_reset:
		_mode = "reset"
	elif _mode == "reset":
		_mode = "choose"
	render()
	_layout_auth.call_deferred()


func render() -> void:
	if _root == null: return
	if services.session.needs_password_reset:
		_mode = "reset"
	elif services.session.authenticated():
		_mode = "connected"
	var old_scroll := _root.get_node_or_null("AuthScroll")
	if old_scroll != null:
		_root.remove_child(old_scroll)
		old_scroll.queue_free()
	_buttons.clear()
	_email = null
	_password = null
	_confirm = null
	_scroll = ScrollContainer.new()
	_scroll.name = "AuthScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_scroll)
	_root.move_child(_logo, _root.get_child_count() - 1)
	var panel := PanelContainer.new()
	panel.name = "LoginPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _wood_frame())
	_scroll.add_child(panel)
	var column := VBoxContainer.new()
	column.name = "LoginContent"
	column.add_theme_constant_override("separation", 5 if UIScale.is_compact() else 12)
	panel.add_child(column)
	if _mode != "choose":
		var titles := {
			"login":"ENTRAR COM E-MAIL","signup":"CRIAR CONTA",
			"recover":"RECUPERAR SENHA","reset":"NOVA SENHA",
			"pending":"CONFIRME SEU E-MAIL","connected":"CONTA CONECTADA"
		}
		var label := PlayerUI.label(titles.get(_mode, "SUA CONTA"), 15 if UIScale.is_compact() else 21, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	match _mode:
		"choose":
			_build_social(column)
			_add_divider(column)
			_add_button(column, "✉  Entrar com e-mail", _switch.bind("login"), Color("#603019"), WHITE, true)
		"login", "signup", "recover", "reset":
			_build_email_form(column)
		"pending":
			column.add_child(PlayerUI.label("Confira sua caixa de entrada e spam. Confirme o e-mail antes de entrar.", 14, MUTED))
			_add_button(column, "Reenviar confirmação", _resend, Color("#945120"), WHITE, true)
			_add_button(column, "Já confirmei — entrar", _switch.bind("login"), Color("#34313a"), WHITE)
		"connected":
			column.add_child(PlayerUI.label(str(services.session.user.get("email", "Conta verificada")), 15, MUTED))
			_add_button(column, "Voltar ao jogo", func() -> void: back_requested.emit(), Color("#945120"), WHITE, true)
	_feedback = PlayerUI.label(_notice, 11 if UIScale.is_compact() else 14, Color("#ffc2b0") if _notice_error else Color("#f8dea8"))
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.visible = not _notice.is_empty()
	column.add_child(_feedback)
	_layout_auth()


func _wood_frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#24150ff0")
	box.border_color = Color("#b67a43")
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	box.shadow_color = Color(0,0,0,0.7)
	box.shadow_size = 20
	var edge := 16 if UIScale.is_compact() else 27
	box.content_margin_left = edge
	box.content_margin_right = edge
	box.content_margin_top = 14 if UIScale.is_compact() else 20
	box.content_margin_bottom = 16 if UIScale.is_compact() else 24
	return box


func _build_social(column: VBoxContainer) -> void:
	for entry: Dictionary in PROVIDERS:
		var provider := str(entry.id)
		var available := services.session.social_available(provider)
		var button := _add_button(column, "Continuar com " + str(entry.name), _social.bind(provider), entry.bg, entry.ink)
		button.name = "Provider_" + provider
		button.disabled = not available
		button.tooltip_text = "" if available else "Em breve: precisa de configuração oficial no Supabase GAME"
		var icon_path := str(entry.icon)
		var icon_asset := load(icon_path) as Texture2D
		if icon_asset != null:
			var icon := TextureRect.new()
			icon.name = "ProviderIcon"
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.texture = icon_asset
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			button.add_child(icon)
			icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
			icon.offset_left = 12
			icon.offset_top = -12
			icon.offset_right = 36
			icon.offset_bottom = 12
	var available_count := 0
	for name: String in ["google", "discord"]:
		if services.session.social_available(name):
			available_count += 1
	if available_count < 2:
		var notice := PlayerUI.label("Aguardando conexão GAME..." if available_count == 0 else "Um provedor está indisponível.", 10 if UIScale.is_compact() else 12, MUTED)
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(notice)


func _add_divider(column: VBoxContainer) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	column.add_child(line)
	for i in range(3):
		if i == 1:
			var gem := PlayerUI.label("◆", 14, GOLD)
			gem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			line.add_child(gem)
		else:
			var rule := HSeparator.new()
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.modulate = GOLD
			line.add_child(rule)


func _build_email_form(column: VBoxContainer) -> void:
	if _mode != "reset":
		_email = _field(column, "Seu e-mail", false)
		_email.text = _remember_email
	if _mode in ["login","signup","reset"]:
		_password = _field(column, "Senha (mínimo 6 caracteres)" if _mode != "login" else "Sua senha", true)
	if _mode in ["signup","reset"]:
		_confirm = _field(column, "Confirmar senha", true)
	if _mode == "login":
		_add_button(column,"Entrar",_authenticate.bind(false),Color("#93521f"),WHITE,true)
		_add_button(column,"Criar conta",_switch.bind("signup"),Color("#403128"),WHITE)
		_add_button(column,"Esqueci minha senha",_switch.bind("recover"),Color("#342720"),MUTED)
	elif _mode == "signup":
		_add_button(column,"Criar minha conta",_authenticate.bind(true),Color("#93521f"),WHITE,true)
		_add_button(column,"Já tenho conta",_switch.bind("login"),Color("#342720"),MUTED)
	elif _mode == "recover":
		column.add_child(PlayerUI.label("Enviaremos um link para definir uma nova senha.", 13, MUTED))
		_add_button(column,"Enviar link de recuperação",_recover,Color("#93521f"),WHITE,true)
		_add_button(column,"Voltar ao login",_switch.bind("login"),Color("#342720"),MUTED)
	elif _mode == "reset":
		_add_button(column,"Salvar nova senha",_reset_password,Color("#93521f"),WHITE,true)
	if _mode != "reset":
		_add_button(column,"‹ Outros métodos",_switch.bind("choose"),Color("#211914"),MUTED)


func _field(parent: VBoxContainer, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	field.custom_minimum_size.y = 38 if UIScale.is_compact() else 51
	field.add_theme_font_size_override("font_size", 15 if UIScale.is_compact() else 18)
	PlayerUI.style_field(field)
	parent.add_child(field)
	return field


func _add_button(parent: VBoxContainer, title: String, action: Callable, bg: Color, ink: Color, primary := false) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 35 if UIScale.is_compact() else 55
	button.add_theme_font_size_override("font_size", 12 if UIScale.is_compact() else 17)
	for state in ["normal","hover","pressed","disabled","hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = bg.lightened(0.08) if state == "hover" else (bg.darkened(0.15) if state == "pressed" else bg)
		if state == "disabled": style.bg_color = bg.darkened(0.10)
		style.border_color = Color("#e4b46d") if primary else Color(0,0,0,0.35)
		style.set_border_width_all(2 if primary else 1)
		style.set_corner_radius_all(7)
		style.shadow_color = Color(0,0,0,0.38)
		style.shadow_size = 5
		button.add_theme_stylebox_override(state, style)
	for name in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(name, ink)
	button.add_theme_color_override("font_disabled_color", ink * Color(0.8,0.8,0.8,1.0))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(7)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons.append(button)
	return button


func _layout_auth() -> void:
	if _root == null or _scroll == null:
		return
	var factor := PlayerUI.unit(self)
	var logical := size / maxf(factor,0.01)
	var compact := logical.y < 600.0
	var very_small := logical.x < 760.0
	var panel_width := minf(logical.x * (0.39 if very_small else 0.26), 375 if not compact else 280)
	panel_width = maxf(panel_width, 202.0 if very_small else 260.0)
	var mid_x := logical.x * (0.72 if very_small else 0.68)
	var panel_x := clampf(mid_x - panel_width * 0.5, 8.0, logical.x - panel_width - 8.0)
	var logo_h := 98.0 if very_small else (113.0 if compact else 260.0)
	var logo_y := 0.0 if very_small else (0.0 if compact else logical.y * 0.24)
	var logo_w := panel_width * (1.04 if very_small else 1.2)
	_logo.position = Vector2(panel_x - (logo_w - panel_width)*0.5, logo_y) * factor
	_logo.size = Vector2(logo_w, logo_h) * factor
	var panel_y := logo_y + logo_h - (20.0 if very_small else (16.0 if compact else 18.0))
	var panel_h := minf(logical.y - panel_y - 9.0, 550.0 if not compact else 360.0)
	_scroll.position = Vector2(panel_x,panel_y) * factor
	_scroll.size = Vector2(panel_width,panel_h)
	_scroll.scale = Vector2.ONE * factor
	var panel := _scroll.get_node_or_null("LoginPanel") as PanelContainer
	if panel != null: panel.custom_minimum_size.x = panel_width - 6.0
	var back := _root.get_node_or_null("AuthBack") as Button
	if back != null:
		back.position = Vector2(12,8) * factor
		back.scale = Vector2.ONE * factor
		back.custom_minimum_size = Vector2(112 if compact else 162, 34 if compact else 45)
		back.add_theme_font_size_override("font_size", 12 if compact else 17)


func _switch(mode: String) -> void:
	if _working:
		return
	if _email != null:
		_remember_email = _email.text.strip_edges()
	_mode = mode
	_notice = ""
	_notice_error = false
	render()


func _busy(value: bool) -> void:
	_working = value
	for button: Button in _buttons:
		if is_instance_valid(button): button.disabled = value
	if value and _feedback != null:
		_feedback.visible = true
		_feedback.text = "Conectando ao GAME..."


func _authenticate(create_account: bool) -> void:
	if _working or _email == null or _password == null:
		return
	_remember_email = _email.text.strip_edges()
	var password := _password.text
	if create_account and (_confirm == null or password != _confirm.text):
		_notice = "As senhas devem ser iguais."
		_notice_error = true
		render()
		return
	var error := SessionService.validate_email_password(_remember_email, password, create_account)
	if not error.is_empty():
		_notice = ServiceResult.message(ServiceResult.failure(error))
		_notice_error = true
		render()
		return
	_password.clear()
	if _confirm != null: _confirm.clear()
	_busy(true)
	var result: Dictionary
	if create_account:
		result = await services.session.sign_up(_remember_email, password)
	else:
		result = await services.session.sign_in(_remember_email, password)
	password = ""
	_busy(false)
	if result.ok:
		if services.session.authenticated():
			_notice = "Conta conectada."
			_mode = "connected"
		else:
			_notice = "Verifique a caixa de entrada e o spam."
			_mode = "pending"
		_notice_error = false
	else:
		_notice = ServiceResult.message(result)
		_notice_error = true
	render()


func _recover() -> void:
	if _working or _email == null:
		return
	_remember_email = _email.text.strip_edges()
	_busy(true)
	var result := await services.session.send_recovery(_remember_email)
	_busy(false)
	_notice = "Se o e-mail existir, enviaremos as instruções de recuperação." if result.ok else ServiceResult.message(result)
	_notice_error = not result.ok
	render()


func _resend() -> void:
	if _working:
		return
	_busy(true)
	var result := await services.session.resend_confirmation(_remember_email)
	_busy(false)
	_notice = "Se aplicável, enviamos um novo e-mail de confirmação." if result.ok else ServiceResult.message(result)
	_notice_error = not result.ok
	render()


func _reset_password() -> void:
	if _working or _password == null or _confirm == null:
		return
	var password := _password.text
	if password != _confirm.text:
		_notice = "As senhas devem ser iguais."
		_notice_error = true
		render()
		return
	_password.clear()
	_confirm.clear()
	_busy(true)
	var result := await services.session.update_password(password)
	password = ""
	_busy(false)
	_notice = "Senha alterada. Sua conta está conectada." if result.ok else ServiceResult.message(result)
	_notice_error = not result.ok
	_mode = "connected" if result.ok else "reset"
	render()


func _social(provider: String) -> void:
	if _working:
		return
	var result := services.session.social_authorize(provider)
	if not result.ok:
		_notice = ServiceResult.message(result)
		_notice_error = true
		render()
