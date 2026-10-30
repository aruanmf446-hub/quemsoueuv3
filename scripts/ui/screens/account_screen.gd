extends PlayerScreen

var _email: LineEdit
var _password: LineEdit
var _working := false


func _ready() -> void:
	super._ready()
	heading.text = tr("Minha conta")
	services.session.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


func render() -> void:
	PlayerUI.clear(body)
	banner.show_state("success")
	var card := PlayerUI.column(body)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size.x = minf(620, size.x / PlayerUI.unit(self) - 64)
	if services.session.authenticated():
		card.add_child(PlayerUI.label(str(services.session.user.get("email", "")), 26, PlayerUI.GOLD))
		card.add_child(PlayerUI.label("Conta conectada."))
		card.add_child(PlayerUI.button("Sair da conta", _logout))
		return
	card.add_child(PlayerUI.label("Conecte sua aventura", 30, PlayerUI.TEXT))
	card.add_child(PlayerUI.label("Entre para acessar perfil, amizades, carteira e progresso confirmado."))
	if not services.client.configured():
		banner.show_state("offline", tr("A conexão com sua conta está indisponível no momento."))
		card.add_child(PlayerUI.label("Os menus e as skins iniciais podem ser usados na demonstração local."))
		return
	_email = LineEdit.new()
	_email.placeholder_text = tr("E-mail")
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_email.custom_minimum_size.y = 56
	PlayerUI.style_field(_email)
	card.add_child(_email)
	_password = LineEdit.new()
	_password.placeholder_text = tr("Senha")
	_password.secret = true
	_password.custom_minimum_size.y = 56
	PlayerUI.style_field(_password)
	card.add_child(_password)
	_password.text_submitted.connect(func(_text: String) -> void: _authenticate(false))
	var buttons := PlayerUI.row(card)
	var enter := PlayerUI.button("Entrar", _authenticate.bind(false))
	PlayerUI.style_button(enter, true)
	buttons.add_child(enter)
	buttons.add_child(PlayerUI.button("Criar conta", _authenticate.bind(true)))
	card.add_child(PlayerUI.label("A criação de conta pode exigir confirmação por e-mail. A sessão permanece somente em memória neste dispositivo."))


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
