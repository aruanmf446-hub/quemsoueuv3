extends PlayerScreen

var _tab := "friends"
var _term := ""
var _results: Array = []
var _search_epoch := 0


func _ready() -> void:
	super._ready()
	heading.text = tr("Amizades")
	services.session.changed.connect(func() -> void:
		_search_epoch += 1
		_results.clear()
		_term = "")
	services.friends.changed.connect(func() -> void:
		if not services.session.authenticated():
			_results.clear()
		if is_visible_in_tree(): render())


func render() -> void:
	PlayerUI.clear(body)
	banner.show_state(services.friends.state)
	if not services.session.authenticated():
		_signed_out()
		return
	var tabs := PlayerUI.row(body)
	tabs.add_theme_constant_override("separation", 8)
	for item: Array in [["Amigos", "friends"], ["Recebidas", "incoming"], ["Enviadas", "outgoing"], ["Buscar", "search"]]:
		var count: int = services.friends.data.get(item[1], []).size() if item[1] != "search" else 0
		var tab := PlayerUI.button(item[0] + ("  %d" % count if count > 0 else ""), _change_tab.bind(item[1]))
		PlayerUI.style_button(tab, item[1] == _tab)
		tabs.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var refresh := PlayerUI.button("↻", func() -> void: services.friends.refresh())
	refresh.tooltip_text = tr("Atualizar")
	refresh.custom_minimum_size = Vector2(56, 52)
	tabs.add_child(refresh)
	if _tab == "search":
		var line := PlayerUI.row(body)
		var query := LineEdit.new()
		query.text = _term
		query.placeholder_text = tr("Nickname ou ID público")
		query.custom_minimum_size = Vector2(420, 52)
		query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		query.text_changed.connect(func(value: String) -> void: _term = value)
		query.text_submitted.connect(_search)
		line.add_child(query)
		var go := PlayerUI.button("Buscar", func() -> void: _search(query.text))
		PlayerUI.style_button(go, true)
		line.add_child(go)
		for player: Dictionary in _results:
			_player_row(player, "send")
	else:
		var players: Array = services.friends.data.get(_tab, [])
		if players.is_empty():
			_empty({"friends": "Você ainda não tem amigos aqui.", "incoming": "Nenhum convite recebido.", "outgoing": "Nenhum convite enviado."}[_tab])
		for player: Dictionary in players:
			_player_row(player, {"friends": "remove", "incoming": "accept", "outgoing": "cancel"}[_tab])


## Sem conta: um cartão central com convite para entrar, no lugar da barra solta.
func _signed_out() -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 420
	body.add_child(center)
	var card := PlayerUI.panel(center, 42)
	card.get_parent().custom_minimum_size.x = 480
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/icons/vector/icon_friends.svg")
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = PlayerUI.GOLD
	card.add_child(icon)
	var title := PlayerUI.label("Jogue com seus amigos", 28, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var enter := PlayerUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}))
	PlayerUI.style_button(enter, true)
	card.add_child(enter)


func _empty(text: String) -> void:
	var note := PlayerUI.label(text, 20, Color("#a8bad3"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.y = 120
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(note)


func _change_tab(tab: String) -> void:
	_tab = tab
	render()
	PlayerUI.cascade(body, 1)


func show_screen(params: Dictionary = {}) -> void:
	if params.get("tab") in ["friends", "incoming", "outgoing", "search"]:
		_tab = params.tab
	super.show_screen(params)


func _player_row(player: Dictionary, action: String) -> void:
	var card := PlayerUI.card(body)
	var row := PlayerUI.row(card)
	var character_id := str(player.get("equipped_character_id", ""))
	# Somente PNGs já em cache. Modelos são carregados ao abrir um único perfil.
	var avatar := PlayerUI.portrait(character_id, 64)
	row.add_child(avatar)
	var info := PlayerUI.column(row)
	info.add_theme_constant_override("separation", 2)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(PlayerUI.label(str(player.get("nickname", "Sem nickname")), 24, PlayerUI.GOLD))
	var presence := services.friends.presence_label(str(player.user_id))
	var entry := services.inventory.entry(character_id)
	var online := presence == "Online"
	info.add_child(PlayerUI.label("%s%s  ·  %s" % ["● " if online else "", presence, entry.get("name", "Skin indisponível")], 16, Color("#7fe0a0") if online else Color("#a8bad3")))
	var view := PlayerUI.button("Ver perfil", func() -> void: navigate_requested.emit("public_profile", {"public_id": player.public_id}))
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(view)
	var actions := {"send": "Adicionar", "accept": "Aceitar", "decline": "Recusar", "cancel": "Cancelar", "remove": "Remover"}
	var main := PlayerUI.button(actions[action], _act.bind(action, str(player.user_id)))
	PlayerUI.style_button(main, action in ["send", "accept"])
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(main)
	if action == "accept":
		var decline := PlayerUI.button("Recusar", _act.bind("decline", str(player.user_id)))
		decline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(decline)


func _search(term: String) -> void:
	_search_epoch += 1
	var epoch := _search_epoch
	banner.show_state("loading")
	var result := await services.friends.search(term)
	if epoch != _search_epoch:
		return
	if result.ok and result.data is Dictionary:
		_results = result.data.get("players", [])
		render()
		if _results.is_empty():
			banner.show_state("empty", "Nenhum jogador encontrado.")
	else:
		status(result)


func _act(action: String, player_id: String) -> void:
	banner.show_state("loading")
	status(await services.friends.act(action, player_id))
