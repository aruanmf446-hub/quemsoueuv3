extends PlayerScreen

var _email: LineEdit
var _password: LineEdit
var _working := false


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha conta")
	ModernUI.style_header(self)
	body.add_theme_constant_override("separation", ModernUI.fs(18))
	services.session.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	ModernUI.follow_resize(self)


func render() -> void:
	PlayerUI.clear(body)
	ModernUI.update_scale(self)
	banner.show_state("success")
	# Cartão central e estreito: a tela de conta não precisa ocupar a largura inteira.
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var card := ModernUI.panel(center, 28)
	card.get_parent().custom_minimum_size.x = ModernUI.fs(560)
	if services.session.authenticated():
		card.add_child(ModernUI.eyebrow("Conta conectada"))
		card.add_child(ModernUI.title(str(services.session.user.get("email", "")), 30))
		card.add_child(ModernUI.muted("Sessão autenticada • Supabase Auth"))
		card.add_child(ModernUI.button("Sair da conta", _logout))
		return
	card.add_child(ModernUI.eyebrow("Conta"))
	card.add_child(ModernUI.title("Conecte sua aventura", 32))
	card.add_child(ModernUI.muted("Entre para acessar perfil, amizades, carteira e progresso confirmado."))
	if not services.client.configured():
		banner.show_state("offline", ServiceResult.message(ServiceResult.failure("not_configured")))
		card.add_child(ModernUI.muted("Os menus e as skins iniciais podem ser usados na demonstração local."))
		return
	_email = ModernUI.field("E-mail")
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	card.add_child(_email)
	_password = ModernUI.field("Senha", true)
	card.add_child(_password)
	_password.text_submitted.connect(func(_text: String) -> void: _authenticate(false))
	var buttons := PlayerUI.row(card)
	buttons.add_theme_constant_override("separation", ModernUI.fs(12))
	buttons.add_child(ModernUI.button("Entrar", _authenticate.bind(false), true))
	buttons.add_child(ModernUI.button("Criar conta", _authenticate.bind(true)))
	card.add_child(ModernUI.muted("A criação de conta pode exigir confirmação por e-mail. A sessão permanece somente em memória neste dispositivo.", 15))


func _authenticate(create_account: bool) -> void:
	if _working:
		return
	_working = true
	var email := _email.text
	var password := _password.text
	_password.clear()
	banner.show_state("loading")
	var result: Dictionary
	if create_account:
		result = await services.session.sign_up(email, password)
	else:
		result = await services.session.sign_in(email, password)
	password = ""
	_working = false
	if result.ok:
		render()
		banner.show_state("success", "Conta conectada." if services.session.authenticated() else "Confira seu e-mail para confirmar a conta antes de entrar.")
	else:
		status(result)


func _logout() -> void:
	var result := await services.session.sign_out()
	render()
	if result.code != "session_changed":
		status(result)
