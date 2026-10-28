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
	var tabs := PlayerUI.row(body)
	for item: Array in [["Amigos", "friends"], ["Recebidas", "incoming"], ["Enviadas", "outgoing"], ["Buscar jogadores", "search"]]:
		tabs.add_child(PlayerUI.button(item[0], _change_tab.bind(item[1])))
	tabs.add_child(PlayerUI.button("Atualizar", func() -> void: services.friends.refresh()))
	if not services.session.authenticated():
		account_button(body)
		return
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
		line.add_child(PlayerUI.button("Buscar", func() -> void: _search(query.text)))
		for player: Dictionary in _results:
			_player_row(player, "send")
		if _results.is_empty():
			body.add_child(PlayerUI.label("Busque um nickname ou identificador público com pelo menos 2 caracteres."))
	else:
		var players: Array = services.friends.data.get(_tab, [])
		if players.is_empty():
			body.add_child(PlayerUI.label("Nenhum jogador nesta lista."))
		for player: Dictionary in players:
			_player_row(player, {"friends": "remove", "incoming": "accept", "outgoing": "cancel"}[_tab])


func _change_tab(tab: String) -> void:
	_tab = tab
	render()


func show_screen(params: Dictionary = {}) -> void:
	if params.get("tab") in ["friends", "incoming", "outgoing", "search"]:
		_tab = params.tab
	super.show_screen(params)


func _player_row(player: Dictionary, action: String) -> void:
	var card := PlayerUI.card(body)
	var row := PlayerUI.row(card)
	var info := PlayerUI.column(row)
	info.add_child(PlayerUI.label(str(player.get("nickname", "Sem nickname")), 26, PlayerUI.GOLD))
	var entry := services.inventory.entry(str(player.get("equipped_character_id", "")))
	info.add_child(PlayerUI.label("%s · %s" % [entry.get("name", "Skin indisponível"), services.friends.presence_label(str(player.user_id))], 18))
	# Somente PNGs já em cache. Modelos são carregados ao abrir um único perfil.
	var path := ThumbnailCache.path_for(str(player.get("equipped_character_id", "")))
	if FileAccess.file_exists(path):
		var thumbnail := TextureRect.new()
		thumbnail.custom_minimum_size = Vector2(60, 72)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture = ImageTexture.create_from_image(Image.load_from_file(path))
		row.add_child(thumbnail)
	row.add_child(PlayerUI.button("Ver perfil", func() -> void: navigate_requested.emit("public_profile", {"public_id": player.public_id})))
	var actions := {"send": "Adicionar", "accept": "Aceitar", "decline": "Recusar", "cancel": "Cancelar", "remove": "Remover"}
	row.add_child(PlayerUI.button(actions[action], _act.bind(action, str(player.user_id))))
	if action == "accept":
		row.add_child(PlayerUI.button("Recusar", _act.bind("decline", str(player.user_id))))


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
