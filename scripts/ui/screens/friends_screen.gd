extends PlayerScreen

const TABS := [["Amigos", "friends"], ["Recebidas", "incoming"], ["Enviadas", "outgoing"], ["Buscar jogadores", "search"]]

var _tab := "friends"
var _term := ""
var _results: Array = []
var _search_epoch := 0


func _ready() -> void:
	super._ready()
	heading.text = tr("Amizades")
	ModernUI.style_header(self)
	body.add_theme_constant_override("separation", ModernUI.fs(18))
	services.session.changed.connect(func() -> void:
		_search_epoch += 1
		_results.clear()
		_term = "")
	services.friends.changed.connect(func() -> void:
		if not services.session.authenticated():
			_results.clear()
		if is_visible_in_tree(): render())
	ModernUI.follow_resize(self)


func render() -> void:
	PlayerUI.clear(body)
	ModernUI.update_scale(self)
	banner.show_state(services.friends.state)
	var layout := _layout()
	var nav := ModernUI.panel(layout, 14)
	nav.get_parent().custom_minimum_size.x = 0 if ModernUI.compact() else ModernUI.fs(300)
	nav.get_parent().size_flags_horizontal = Control.SIZE_FILL if ModernUI.compact() else Control.SIZE_SHRINK_BEGIN
	nav.add_child(ModernUI.eyebrow("Social"))
	# Em coluna na lateral; em telas estreitas as abas quebram em linhas e não empurram a lista.
	var tabs: Container = HFlowContainer.new() if ModernUI.compact() else VBoxContainer.new()
	tabs.add_theme_constant_override("separation", ModernUI.fs(8))
	tabs.add_theme_constant_override("h_separation", ModernUI.fs(8))
	tabs.add_theme_constant_override("v_separation", ModernUI.fs(8))
	nav.add_child(tabs)
	for item: Array in TABS:
		tabs.add_child(ModernUI.button(item[0], _change_tab.bind(item[1]), item[1] == _tab))
	tabs.add_child(ModernUI.button("Atualizar", func() -> void: services.friends.refresh()))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", ModernUI.fs(14))
	layout.add_child(content)
	if not services.session.authenticated():
		var prompt := ModernUI.panel(content, 26)
		prompt.add_child(ModernUI.eyebrow("Amizades"))
		prompt.add_child(ModernUI.title("Entre para ver seus amigos", 28))
		prompt.add_child(ModernUI.muted("Pedidos, amigos e buscas de jogadores precisam de conexão."))
		prompt.add_child(ModernUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}), true))
		return
	if _tab == "search":
		_search_section(content)
		return
	var players: Array = services.friends.data.get(_tab, [])
	content.add_child(ModernUI.eyebrow("%s · %d" % [_tab_label(_tab), players.size()]))
	if players.is_empty():
		var empty := ModernUI.panel(content, 22)
		empty.add_child(ModernUI.muted("Nenhum jogador nesta lista."))
	for player: Dictionary in players:
		_player_row(content, player, {"friends": "remove", "incoming": "accept", "outgoing": "cancel"}[_tab])


func _search_section(content: VBoxContainer) -> void:
	var search := ModernUI.panel(content, 18)
	search.add_child(ModernUI.eyebrow("Buscar jogadores"))
	var line := PlayerUI.row(search)
	line.add_theme_constant_override("separation", ModernUI.fs(10))
	var query := ModernUI.field("Nickname ou ID público")
	query.text = _term
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query.text_changed.connect(func(value: String) -> void: _term = value)
	query.text_submitted.connect(_search)
	line.add_child(query)
	line.add_child(ModernUI.button("Buscar", func() -> void: _search(query.text), true))
	if _results.is_empty():
		content.add_child(ModernUI.muted("Busque um nickname ou identificador público com pelo menos 2 caracteres."))
	for player: Dictionary in _results:
		_player_row(content, player, "send")


## Barra lateral em telas largas; em telas estreitas a navegação fica no topo, em coluna.
func _layout() -> BoxContainer:
	var layout: BoxContainer = VBoxContainer.new() if ModernUI.compact() else HBoxContainer.new()
	layout.add_theme_constant_override("separation", ModernUI.fs(18))
	body.add_child(layout)
	return layout


func _tab_label(tab: String) -> String:
	for item: Array in TABS:
		if item[1] == tab:
			return item[0]
	return tab


func _change_tab(tab: String) -> void:
	_tab = tab
	render()


func show_screen(params: Dictionary = {}) -> void:
	if params.get("tab") in ["friends", "incoming", "outgoing", "search"]:
		_tab = params.tab
	super.show_screen(params)


func _player_row(parent: Node, player: Dictionary, action: String) -> void:
	var card := ModernUI.panel(parent, 16)
	var row := PlayerUI.row(card)
	row.add_theme_constant_override("separation", ModernUI.fs(14))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	# Somente PNGs já em cache. Modelos são carregados ao abrir um único perfil.
	var path := ThumbnailCache.path_for(str(player.get("equipped_character_id", "")))
	if FileAccess.file_exists(path):
		var thumbnail := TextureRect.new()
		thumbnail.custom_minimum_size = Vector2(ModernUI.fs(64), ModernUI.fs(76))
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.texture = ImageTexture.create_from_image(Image.load_from_file(path))
		row.add_child(thumbnail)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", ModernUI.fs(4))
	row.add_child(info)
	info.add_child(ModernUI.title(str(player.get("nickname", "Sem nickname")), 22))
	var entry := services.inventory.entry(str(player.get("equipped_character_id", "")))
	info.add_child(ModernUI.muted("%s · %s" % [entry.get("name", "Skin indisponível"), services.friends.presence_label(str(player.user_id))], 16))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", ModernUI.fs(8))
	row.add_child(actions)
	actions.add_child(ModernUI.button("Ver perfil", func() -> void: navigate_requested.emit("public_profile", {"public_id": player.public_id})))
	var labels := {"send": "Adicionar", "accept": "Aceitar", "decline": "Recusar", "cancel": "Cancelar", "remove": "Remover"}
	actions.add_child(ModernUI.button(labels[action], _act.bind(action, str(player.user_id)), action in ["send", "accept"]))
	if action == "accept":
		actions.add_child(ModernUI.button("Recusar", _act.bind("decline", str(player.user_id))))


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
