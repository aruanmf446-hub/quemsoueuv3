extends PlayerScreen
## T18 — Login visual funcional. A arte e o logo sao recursos independentes;
## todos os controles sao botoes/campos reais do Godot, nao hotspots na imagem.
const ART := preload("res://assets/processed/backgrounds/bg_lobby_fantasia.png")
const LOGO := preload("res://assets/processed/logos/logo_menu_principal.png")
const CREAM := Color("#fff8ec")
const GOLD := Color("#e9b975")
const MUTE := Color("#d7c4b2")
const PROVIDERS := [
	{"id": "google", "name": "Google", "bg": Color("#f8f8fa"), "ink": Color("#26292f")},
	{"id": "apple", "name": "Apple", "bg": Color("#161719"), "ink": Color.WHITE},
	{"id": "steam", "name": "Steam", "bg": Color("#145180"), "ink": Color.WHITE},
	{"id": "discord", "name": "Discord", "bg": Color("#4f59e6"), "ink": Color.WHITE},
]
var _mode := "choose"
var _root: Control
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
	$Backdrop.texture = ART
	$Backdrop.show()
	$Tint.color = Color(0.012, 0.016, 0.04, 0.25)
	_root = Control.new()
	_root.name = "AuthOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var back := Button.new()
	back.name = "AuthBack"
	back.text = "‹ Voltar ao jogo"
	back.focus_mode = Control.FOCUS_ALL
	back.pressed.connect(func() -> void: back_requested.emit())
	PlayerUI.style_button(back, false)
	_root.add_child(back)
	back.position = Vector2(22, 18)
	back.set_meta("auth_back", true)
	services.session.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	services.session.providers_changed.connect(func() -> void:
		if is_visible_in_tree() and _mode == "choose": render())
	resized.connect(_layout_auth)
	_layout_auth.call_deferred()


func show_screen(params: Dictionary = {}) -> void:
	parameters = params.duplicate(true)
	show()
	if services.session.needs_password_reset:
		_mode = "reset"
	elif _mode == "reset":
		_mode = "choose"
	render()
	_layout_auth.call_deferred()


func render() -> void:
	if _root == null:
		return
	if services.session.needs_password_reset:
		_mode = "reset"
	elif services.session.authenticated():
		_mode = "connected"
	for child in _root.get_children():
		if not child.has_meta("auth_back"):
			_root.remove_child(child)
			child.queue_free()
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
	var panel := PanelContainer.new()
	panel.name = "AuthPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.075, 0.046, 0.039, 0.92)
	frame.border_color = Color(0.66, 0.40, 0.20, 0.86)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(15)
	frame.content_margin_left = 19
	frame.content_margin_right = 19
	frame.content_margin_top = 12
	frame.content_margin_bottom = 17
	frame.shadow_color = Color(0, 0, 0, 0.66)
	frame.shadow_size = 16
	panel.add_theme_stylebox_override("panel", frame)
	_scroll.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var logo := TextureRect.new()
	logo.name = "OfficialLogo"
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(logo)
	logo.custom_minimum_size.y = 95 if UIScale.is_compact() else 150
	var heading_text := "Sua aventura começa aqui"
	match _mode:
		"login": heading_text = "Entre na sua conta"
		"signup": heading_text = "Crie sua conta"
		"recover": heading_text = "Recuperar senha"
		"reset": heading_text = "Escolha uma nova senha"
		"pending": heading_text = "Confirme seu e-mail"
		"connected": heading_text = "Você está conectado"
	var title := PlayerUI.label(heading_text, 17 if UIScale.is_compact() else 22, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	match _mode:
		"choose":
			_build_social(column)
			_add_button(column, "Entrar com e-mail", _switch.bind("login"), Color("#9a5a25"), CREAM, true)
		"login", "signup", "recover", "reset":
			_build_email_form(column)
		"pending":
			column.add_child(PlayerUI.label("Enviamos instruções para o seu e-mail. Confirme a conta antes de entrar.", 14, MUTE))
			_add_button(column, "Reenviar confirmação", _resend, Color("#a76b2f"), CREAM, true)
			_add_button(column, "Já confirmei — entrar", _switch.bind("login"), Color("#34363e"), CREAM)
		"connected":
			column.add_child(PlayerUI.label(str(services.session.user.get("email", "Conta verificada")), 15, MUTE))
			_add_button(column, "Voltar ao jogo", func() -> void: back_requested.emit(), Color("#a76b2f"), CREAM, true)
			_add_button(column, "Sair da conta", _logout, Color("#242832"), CREAM)
	_feedback = PlayerUI.label(_notice, 12 if UIScale.is_compact() else 15, Color("#ffc5b6") if _notice_error else Color("#fce0ab"))
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.visible = not _notice.is_empty()
	column.add_child(_feedback)
	var copyright := PlayerUI.label("QUEM SOU EU  •  GAME", 10, Color(1, 0.85, 0.66, 0.65))
	copyright.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(copyright)
	_layout_auth()


func _build_social(column: VBoxContainer) -> void:
	for provider: Dictionary in PROVIDERS:
		var pid := str(provider.id)
		var ready := pid != "steam" and services.session.social_available(pid)
		var label := "Continuar com " + str(provider.name) if ready else str(provider.name) + " · indisponível"
		var btn := _add_button(column, label, _social.bind(pid), provider.bg, provider.ink)
		btn.disabled = not ready
		btn.tooltip_text = "Requer configuração oficial no Supabase GAME" if pid != "steam" else "Steam exige integração de identidade específica"
	var hint := PlayerUI.label("Login social depende da ativação oficial dos provedores.", 11, MUTE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _build_email_form(column: VBoxContainer) -> void:
	if _mode != "reset":
		_email = _field(column, "Seu e-mail", false)
		_email.text = _remember_email
	if _mode in ["login", "signup", "reset"]:
		_password = _field(column, "Senha (mínimo 6 caracteres)" if _mode != "login" else "Sua senha", true)
	if _mode in ["signup", "reset"]:
		_confirm = _field(column, "Confirmar senha", true)
	if _mode == "login":
		_add_button(column, "Entrar", _authenticate.bind(false), Color("#b2702e"), CREAM, true)
		_add_button(column, "Criar conta", _switch.bind("signup"), Color("#34313a"), CREAM)
		_add_button(column, "Esqueci minha senha", _switch.bind("recover"), Color("#292c34"), MUTE)
	elif _mode == "signup":
		_add_button(column, "Criar minha conta", _authenticate.bind(true), Color("#b2702e"), CREAM, true)
		_add_button(column, "Já tenho conta", _switch.bind("login"), Color("#292c34"), MUTE)
	elif _mode == "recover":
		column.add_child(PlayerUI.label("Enviaremos um link para definir uma nova senha.", 12, MUTE))
		_add_button(column, "Enviar link de recuperação", _recover, Color("#b2702e"), CREAM, true)
		_add_button(column, "Voltar ao login", _switch.bind("login"), Color("#292c34"), MUTE)
	elif _mode == "reset":
		_add_button(column, "Salvar nova senha", _reset_password, Color("#b2702e"), CREAM, true)
	if _mode != "reset":
		_add_button(column, "‹ Outros métodos", _switch.bind("choose"), Color("#232127"), MUTE)


func _field(parent: VBoxContainer, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	field.custom_minimum_size.y = 35 if UIScale.is_compact() else 47
	field.add_theme_font_size_override("font_size", 13 if UIScale.is_compact() else 18)
	field.add_theme_color_override("font_color", CREAM)
	PlayerUI.style_field(field)
	parent.add_child(field)
	return field


func _add_button(parent: VBoxContainer, label: String, action: Callable, bg: Color, ink: Color, primary := false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size.y = 31 if UIScale.is_compact() else 49
	btn.add_theme_font_size_override("font_size", 13 if UIScale.is_compact() else 17)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var plate := StyleBoxFlat.new()
		plate.bg_color = (bg.lightened(0.13) if state == "hover" else (bg.darkened(0.12) if state == "pressed" else bg))
		if state == "disabled": plate.bg_color = Color(0.13, 0.13, 0.17, 0.84)
		plate.set_corner_radius_all(8)
		if primary:
			plate.border_color = GOLD
			plate.set_border_width_all(1)
		btn.add_theme_stylebox_override(state, plate)
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(name, ink)
	btn.add_theme_color_override("font_disabled_color", Color("#9a9299"))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("focus", focus)
	btn.pressed.connect(action)
	parent.add_child(btn)
	_buttons.append(btn)
	return btn


func _layout_auth() -> void:
	if _root == null or _scroll == null:
		return
	var scale_factor := PlayerUI.unit(self)
	var logical := size / scale_factor
	var compact := logical.y < 600
	var width := minf(385.0 if not compact else (305.0 if logical.x < 760 else 340.0), logical.x * 0.65)
	var height := minf(logical.y - (24.0 if compact else 65.0), 740.0)
	_scroll.scale = Vector2.ONE * scale_factor
	_scroll.size = Vector2(width, height)
	_scroll.position = Vector2(size.x - (width + (12.0 if compact else 66.0)) * scale_factor, (size.y - height * scale_factor) * 0.5)
	var panel := _scroll.get_node_or_null("AuthPanel") as PanelContainer
	if panel != null: panel.custom_minimum_size.x = width - 6.0
	var back := _root.get_node_or_null("AuthBack") as Button
	if back != null:
		back.position = Vector2(12, 10) * scale_factor
		back.scale = Vector2.ONE * scale_factor
		back.add_theme_font_size_override("font_size", 12 if compact else 17)
		back.custom_minimum_size = Vector2(145, 33) if compact else Vector2(200, 45)


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


func _logout() -> void:
	if _working:
		return
	_busy(true)
	var result := await services.session.sign_out()
	_busy(false)
	_mode = "choose"
	_notice = "" if result.ok else ServiceResult.message(result)
	_notice_error = not result.ok
	render()
