extends PlayerScreen

var _waiting_action := ""
var _binding_button: Button


func _ready() -> void:
	super._ready()
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _waiting_action = "")
	services.session.changed.connect(func() -> void:
		_waiting_action = ""
		if is_visible_in_tree(): render())


func render() -> void:
	_waiting_action = ""
	PlayerUI.clear(body)
	heading.text = tr("Configurações")
	banner.show_state("success")
	var row := PlayerUI.row(body)
	var sound := PlayerUI.card(row)
	sound.add_child(PlayerUI.label("Áudio e imagem", 28, PlayerUI.GOLD))
	_slider(sound, "Volume geral", "master", 0, 1)
	_slider(sound, "Música", "music", 0, 1)
	_slider(sound, "Efeitos sonoros", "sfx", 0, 1)
	var quality := OptionButton.new()
	quality.custom_minimum_size.y = 52
	var qualities := ["baixo", "medio", "alto"]
	for text: String in ["Baixa", "Média", "Alta"]:
		quality.add_item(tr(text))
	quality.select(qualities.find(services.preferences.values.quality))
	quality.item_selected.connect(func(index: int) -> void: _save("quality", qualities[index]))
	sound.add_child(PlayerUI.label("Qualidade gráfica"))
	sound.add_child(quality)
	if OS.has_feature("web"):
		sound.add_child(PlayerUI.button("Alternar tela cheia", func() -> void:
			var mode := DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(mode)))
	var controls := PlayerUI.card(row)
	controls.add_child(PlayerUI.label("Controles dos menus", 28, PlayerUI.GOLD))
	controls.add_child(PlayerUI.label("Mouse, toque ou teclado. Use Tab e as setas para navegar."))
	for item: Array in [["Confirmar", "accept_key"], ["Voltar", "back_key"]]:
		var line := PlayerUI.row(controls)
		line.add_child(PlayerUI.label(item[0]))
		var key_button := PlayerUI.button(OS.get_keycode_string(int(services.preferences.values[item[1]])), func() -> void: pass)
		key_button.pressed.connect(_wait_for_key.bind(item[1], key_button))
		line.add_child(key_button)
	controls.add_child(PlayerUI.label("Os comandos do protótipo de combate são preservados: A/D ou setas, Espaço e J/K."))
	var account := PlayerUI.card(body)
	account.add_child(PlayerUI.label("Idioma e conta", 28, PlayerUI.GOLD))
	var locale := OptionButton.new()
	locale.add_item("Português (Brasil)")
	locale.add_item("English (partial)")
	locale.select(0 if services.preferences.values.locale == "pt_BR" else 1)
	locale.item_selected.connect(func(index: int) -> void:
		_save("locale", "pt_BR" if index == 0 else "en")
		render())
	account.add_child(locale)
	account.add_child(PlayerUI.label(str(services.session.user.get("email", "Demonstração local • sem conta conectada"))))
	if services.session.authenticated():
		var discoverable := CheckButton.new()
		discoverable.text = tr("Permitir busca do meu perfil público")
		discoverable.button_pressed = services.profile.data.get("discoverable", false)
		discoverable.disabled = services.profile.state != "success"
		discoverable.custom_minimum_size.y = 52
		discoverable.toggled.connect(func(value: bool) -> void: status(await services.profile.set_discoverable(value)))
		account.add_child(discoverable)
	account_button(account)
	if services.session.authenticated():
		account.add_child(PlayerUI.button("Sair da conta", func() -> void:
			await services.session.sign_out()
			render()))


func _slider(parent: Node, text: String, key: String, minimum: float, maximum: float) -> void:
	parent.add_child(PlayerUI.label(text))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = services.preferences.values[key]
	slider.custom_minimum_size = Vector2(280, 48)
	slider.value_changed.connect(func(value: float) -> void: _save(key, value))
	parent.add_child(slider)


func _save(key: String, value: Variant) -> void:
	if not services.preferences.set_preference(key, value):
		banner.show_state("error", "Não foi possível salvar a preferência neste dispositivo.")


func _wait_for_key(action: String, button: Button) -> void:
	_waiting_action = action
	_binding_button = button
	button.text = tr("Pressione uma tecla…")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _waiting_action.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var other := "back_key" if _waiting_action == "accept_key" else "accept_key"
	if event.physical_keycode == int(services.preferences.values[other]):
		banner.show_state("error", "Escolha uma tecla diferente para confirmar e voltar.")
		return
	_save(_waiting_action, int(event.physical_keycode))
	_binding_button.text = OS.get_keycode_string(event.physical_keycode)
	_waiting_action = ""
	get_viewport().set_input_as_handled()
