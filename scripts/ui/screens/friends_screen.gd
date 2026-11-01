extends PlayerScreen
## Amizades (referências T22): barra lateral com Amigos/Recebidas/Enviadas/Buscar e a lista
## do momento; à direita o jogador selecionado, ações reais e painéis de contexto.
## Só dados reais do GAME (contrato em docs/contracts/T22_GAME_BACKEND.md); fixtures só nos testes.

const MIN_LOGICAL_WIDTH := 900.0
const TABS := [["Amigos", "friends", "friends"], ["Recebidas", "incoming", "inbox"], ["Enviadas", "outgoing", "outbox"], ["Buscar", "search", "search"]]
var _tab := "friends"
var _term := ""
var _results: Array = []
var _search_epoch := 0
var _selected := {}
var _searched := false
## Conversa aberta (amigo) ou {} na lista. O chat só consulta o servidor com ela aberta.
var _chat_friend: Dictionary = {}
var _chat_list: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_input: LineEdit
var _chat_status: Label
var _chat_send: Button
var _rendered_ids: Dictionary = {}
var _backdrop: ColorRect
var _brand: HBoxContainer
var _title_icon: TextureRect
## Consultas por jogador (amigos em comum, convites, estatísticas...): uma vez por seleção.
var _remote := {}
var _request_message := ""


func _ready() -> void:
	manages_own_scale = true
	super._ready()
	heading.text = tr("Amizades")
	_build_header()
	resized.connect(_fit)
	services.session.changed.connect(func() -> void:
		_search_epoch += 1
		_results.clear()
		_selected.clear()
		_remote.clear()
		_searched = false
		_term = "")
	services.friends.changed.connect(func() -> void:
		if not services.session.authenticated():
			_results.clear()
		if is_visible_in_tree() and _chat_friend.is_empty(): render())
	services.chat.changed.connect(_chat_state_changed)
	services.chat.messages_changed.connect(func(_id: String) -> void: _append_messages())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree() and not _chat_friend.is_empty(): _close_chat(false))


func _build_header() -> void:
	_backdrop = PremiumUI.backdrop()
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if has_node("Tint"): $Tint.hide()
	var header: HBoxContainer = $Margin/Column/Header
	var back: Button = $Margin/Column/Header/Back
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.16)
	divider.custom_minimum_size = Vector2(1, 36)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(divider)
	header.move_child(divider, back.get_index() + 1)
	_brand = HBoxContainer.new()
	_brand.name = "Brand"
	_brand.add_theme_constant_override("separation", 8)
	_brand.add_child(PremiumUI.icon_rect("crown", PremiumUI.GOLD, 30))
	_brand.add_child(PremiumUI.plain("Quem Sou Eu V3", 24, Color.WHITE, false))
	header.add_child(_brand)
	header.move_child(_brand, divider.get_index() + 1)
	var divider2 := divider.duplicate() as ColorRect
	header.add_child(divider2)
	header.move_child(divider2, _brand.get_index() + 1)
	_title_icon = PremiumUI.icon_rect("friends", PremiumUI.GOLD, 36)
	header.add_child(_title_icon)
	header.move_child(_title_icon, divider2.get_index() + 1)
	$Margin/Column/Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _compact() -> bool:
	return size.y / _factor() < 600.0


func _factor() -> float:
	return minf(PlayerUI.unit(self), size.x / MIN_LOGICAL_WIDTH) if size.x > 0 else 1.0


## Escala própria: em janelas estreitas o layout inteiro reduz junto (nada cortado).
func _fit() -> void:
	if not is_inside_tree(): return
	var factor := _factor()
	var compact := _compact()
	var margin: MarginContainer = $Margin
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = size / factor
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 16 if compact else 28)
	margin.add_theme_constant_override("margin_top", 8 if compact else 16)
	margin.add_theme_constant_override("margin_bottom", 10 if compact else 22)
	$Margin/Column.add_theme_constant_override("separation", 8 if compact else 18)
	var back: Button = $Margin/Column/Header/Back
	back.custom_minimum_size = Vector2(96 if compact else 126, 38 if compact else 50)
	back.add_theme_font_size_override("font_size", 15 if compact else 20)
	heading.add_theme_font_size_override("font_size", 24 if compact else 38)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_icon.custom_minimum_size = Vector2.ONE * (26 if compact else 36)
	_brand.visible = size.x / factor >= 760.0


func _adapt_scale() -> void:
	_fit()


func render() -> void:
	PlayerUI.clear(body)
	heading.text = tr("Amizades")
	banner.show_state(services.friends.state)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fit()
	if not services.session.authenticated():
		_signed_out()
		return
	if not _chat_friend.is_empty():
		_render_chat()
		return
	var compact := _compact()
	var layout := HBoxContainer.new()
	layout.name = "FriendsLayout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12 if compact else 22)
	body.add_child(layout)
	layout.add_child(_sidebar())
	var main := PremiumUI.panel("MainPanel", 14 if compact else 26)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 2.3
	layout.add_child(main)
	var scroll := ScrollContainer.new()
	scroll.name = "MainScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "MainContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12 if compact else 20)
	scroll.add_child(content)
	if _tab == "search":
		_render_search(content)
		return
	var players: Array = services.friends.data.get(_tab, [])
	var player := _current(players)
	if player.is_empty():
		_empty_state(content)
		return
	_detail(content, player, _tab)
	_context_panels(content, player)


# --- Barra lateral --------------------------------------------------------------------

func _sidebar() -> Control:
	var compact := _compact()
	var side := PremiumUI.panel("Sidebar", 10 if compact else 16)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6 if compact else 10)
	side.add_child(column)
	for item: Array in TABS:
		var count: int = services.friends.data.get(item[1], []).size() if item[1] != "search" else -1
		var tab := Button.new()
		tab.name = "Tab_" + item[1]
		tab.text = tr(item[0])
		tab.icon = PremiumUI.icon(item[2], PremiumUI.GOLD if item[1] != _tab else Color.WHITE, 40)
		tab.expand_icon = false
		tab.add_theme_constant_override("icon_max_width", 18 if compact else 28)
		tab.add_theme_constant_override("h_separation", 14)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.toggle_mode = true
		tab.button_pressed = item[1] == _tab
		tab.custom_minimum_size.y = 36 if compact else 56
		tab.add_theme_font_size_override("font_size", 15 if compact else 22)
		PremiumUI.style_tab(tab)
		tab.pressed.connect(_change_tab.bind(item[1]))
		if count >= 0:
			var badge := PremiumUI.plain(str(count), 13 if compact else 18, Color.WHITE, false)
			badge.name = "Count"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.add_theme_stylebox_override("normal", PremiumUI.flat(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 12, 0, 4))
			badge.custom_minimum_size = Vector2(28 if compact else 40, 0)
			tab.add_child(badge)
			badge.anchor_left = 1.0
			badge.anchor_right = 1.0
			badge.anchor_top = 0.5
			badge.anchor_bottom = 0.5
			badge.offset_left = -(40 if compact else 56)
			badge.offset_right = -10
			badge.offset_top = -(11 if compact else 15)
			badge.offset_bottom = 11 if compact else 15
		column.add_child(tab)
	# Em Buscar, os resultados ficam no painel principal; a lateral mostra seus amigos.
	var titles := {"friends": "Seus amigos", "incoming": "Solicitações recebidas", "outgoing": "Solicitações enviadas", "search": "Seus amigos"}
	var list_key := "friends" if _tab == "search" else _tab
	var list_items: Array = services.friends.data.get(list_key, [])
	var section := HBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	var title := PremiumUI.plain("%s (%d)" % [tr(titles[_tab]), list_items.size()], 15 if compact else 22, Color.WHITE, false)
	title.name = "SectionTitle"
	section.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(spacer)
	var refresh := Button.new()
	refresh.name = "Refresh"
	refresh.tooltip_text = tr("Atualizar")
	refresh.icon = PremiumUI.icon("refresh", PremiumUI.GOLD, 32)
	refresh.expand_icon = false
	refresh.flat = true
	refresh.pressed.connect(func() -> void: services.friends.refresh())
	section.add_child(refresh)
	column.add_child(section)
	var scroll := ScrollContainer.new()
	scroll.name = "PlayerListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "PlayerList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var current := _current(list_items) if _tab != "search" else {}
	for player: Dictionary in list_items:
		var row := _list_row(player, str(player.user_id) == str(current.get("user_id", "")))
		if _tab == "search":
			row.pressed.disconnect(_select.bind(player))
			row.pressed.connect(func() -> void:
				_selected["friends"] = str(player.user_id)
				_change_tab("friends"))
		list.add_child(row)
	if list_items.is_empty():
		var note := PlayerUI.label({"friends": "Nenhum amigo ainda. Use Buscar para encontrar jogadores.", "incoming": "Nenhuma solicitação recebida.", "outgoing": "Nenhuma solicitação enviada.", "search": "Nenhum amigo ainda."}[_tab], 13 if compact else 16, PremiumUI.MUTED)
		note.name = "EmptyList"
		list.add_child(note)
	return side


func _list_row(player: Dictionary, selected: bool) -> Button:
	var compact := _compact()
	var row := Button.new()
	row.name = "Player_" + str(player.public_id)
	row.toggle_mode = true
	row.button_pressed = selected
	row.custom_minimum_size.y = 50 if compact else 78
	row.focus_mode = Control.FOCUS_ALL
	PremiumUI.style_tab(row)
	var flat := StyleBoxEmpty.new()
	row.add_theme_stylebox_override("normal", flat)
	row.pressed.connect(_select.bind(player))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10 if compact else 14)
	row.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 8
	line.offset_right = -8
	line.add_child(PremiumUI.avatar(PlayerUI.portrait_texture(str(player.get("equipped_character_id", ""))), 36 if compact else 58, 2))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	var name := PremiumUI.plain(_nickname(player), 14 if compact else 20, Color.WHITE, false)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	text.add_child(name)
	text.add_child(_status_line(player, 11 if compact else 15))
	return row


func _current(players: Array) -> Dictionary:
	var wanted := str(_selected.get(_tab, ""))
	for player: Dictionary in players:
		if str(player.user_id) == wanted: return player
	return players[0] if not players.is_empty() else {}


func _select(player: Dictionary) -> void:
	_selected[_tab] = str(player.user_id)
	render()


func _change_tab(tab: String) -> void:
	_tab = tab
	render()
	PlayerUI.cascade(body, 1)


func show_screen(params: Dictionary = {}) -> void:
	if params.get("tab") in ["friends", "incoming", "outgoing", "search"]:
		_tab = params.tab
	super.show_screen(params)


# --- Jogador selecionado ---------------------------------------------------------------

func _nickname(player: Dictionary) -> String:
	var nickname: Variant = player.get("nickname")
	return str(nickname) if nickname is String and not str(nickname).is_empty() else tr("Sem nickname")


## Presença real: online / em partida / offline (com "há X min"). Sem dado: nível.
func _status_line(player: Dictionary, font: int) -> Control:
	var id := str(player.get("user_id", ""))
	if _relation(id) == "outgoing" and _tab == "outgoing":
		var waiting := HBoxContainer.new()
		waiting.add_theme_constant_override("separation", 6)
		waiting.add_child(PremiumUI.icon_rect("clock", PremiumUI.GOLD, font + 2))
		waiting.add_child(PremiumUI.plain("Aguardando resposta", font, PremiumUI.GOLD_LIGHT))
		return waiting
	match services.friends.presence_status(id):
		"online": return PremiumUI.presence(tr("Online"), true, font)
		"in_match":
			var row := PremiumUI.presence(tr("Em partida"), true, font)
			(row.get_child(0) as Panel).add_theme_stylebox_override("panel", PremiumUI.flat(Color("#f0b429"), Color.TRANSPARENT, font, 0, 0))
			(row.get_child(1) as Label).add_theme_color_override("font_color", Color("#f0b429"))
			return row
		"offline":
			var ago := PlayerContracts.ago(services.friends.last_seen(id))
			return PremiumUI.presence(tr("Offline") + (" (%s)" % ago if not ago.is_empty() else ""), false, font)
	var level: Variant = player.get("level")
	return PremiumUI.plain(tr("Nível ") + str(level) if level != null else tr("Presença indisponível"), font, PremiumUI.MUTED, false)


## Consulta com cache por chave; re-renderiza ao chegar se a tela ainda estiver aberta.
func _fetch(key: String, rpc_name: String, params: Dictionary) -> Dictionary:
	if _remote.has(key): return _remote[key]
	_remote[key] = {"state": "loading"}
	_run_fetch(key, rpc_name, params)
	return _remote[key]


func _run_fetch(key: String, rpc_name: String, params: Dictionary) -> void:
	var result: Dictionary = await services.friends.call_game(rpc_name, params)
	if not _remote.has(key): return
	_remote[key] = {"state": "ok", "data": result.data} if result.ok and not (result.data is Dictionary and result.data.has("error")) else {"state": "error", "code": str(result.get("code", result.data.get("error", "erro") if result.data is Dictionary else "erro"))}
	if is_visible_in_tree() and _chat_friend.is_empty(): render()


## Mostra carregando/erro; devolve os dados quando prontos (ou null).
func _remote_data(parent: Control, key: String, rpc_name: String, params: Dictionary) -> Variant:
	var entry := _fetch(key, rpc_name, params)
	if entry.state == "loading":
		_unavailable(parent, "Carregando…")
		return null
	if entry.state == "error":
		_unavailable(parent, tr("Não foi possível carregar (%s).") % str(entry.get("code", "")))
		var retry := Button.new()
		retry.name = "Retry"
		retry.text = tr("Tentar novamente")
		retry.flat = true
		retry.add_theme_color_override("font_color", PremiumUI.GOLD)
		retry.pressed.connect(func() -> void:
			_remote.erase(key)
			render())
		parent.add_child(retry)
		return null
	return entry.data


func _relation(user_id: String) -> String:
	for key: String in ["friends", "incoming", "outgoing"]:
		for player: Dictionary in services.friends.data.get(key, []):
			if str(player.user_id) == user_id: return key
	return "none"


func _detail(parent: Control, player: Dictionary, kind: String) -> void:
	var compact := _compact()
	var top := HBoxContainer.new()
	top.name = "PlayerHeader"
	top.add_theme_constant_override("separation", 16 if compact else 34)
	parent.add_child(top)
	var character_id := str(player.get("equipped_character_id", ""))
	top.add_child(PremiumUI.avatar(PlayerUI.portrait_texture(character_id), (72 if kind == "search" else 100) if compact else (170 if kind == "search" else 220), 4))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4 if compact else 8)
	top.add_child(info)
	var name := PremiumUI.plain(_nickname(player), 22 if compact else 46, Color.WHITE, false)
	name.name = "PlayerName"
	info.add_child(name)
	var id_line := HBoxContainer.new()
	id_line.add_theme_constant_override("separation", 10)
	var public_id := str(player.get("public_id", ""))
	id_line.add_child(PremiumUI.plain(tr("ID Público: ") + public_id, 13 if compact else 22, PremiumUI.MUTED, false))
	var copy := Button.new()
	copy.name = "CopyPublicId"
	copy.tooltip_text = tr("Copiar ID público")
	copy.icon = PremiumUI.icon("copy", Color.WHITE, 32)
	copy.expand_icon = false
	copy.flat = true
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(public_id)
		banner.show_state("success", tr("ID público copiado.")))
	id_line.add_child(copy)
	info.add_child(id_line)
	info.add_child(_status_line(player, 14 if compact else 22))
	var equipped := PanelContainer.new()
	equipped.name = "EquippedCharacter"
	var box := PremiumUI.flat(Color(0.07, 0.09, 0.13), Color(1, 1, 1, 0.14), 12, 1, 12 if compact else 16)
	equipped.add_theme_stylebox_override("panel", box)
	equipped.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	equipped.custom_minimum_size.x = 220 if compact else 460
	info.add_child(equipped)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	equipped.add_child(line)
	line.add_child(PremiumUI.icon_rect("star", PremiumUI.GOLD, 22 if compact else 34))
	var labels := VBoxContainer.new()
	labels.add_theme_constant_override("separation", 0)
	line.add_child(labels)
	labels.add_child(PremiumUI.plain("Personagem equipado", 11 if compact else 16, PremiumUI.MUTED))
	labels.add_child(PremiumUI.plain(str(services.inventory.entry(character_id).get("name", "—")), 16 if compact else 28, Color.WHITE, false))
	if kind == "search" and _relation(str(player.user_id)) == "none":
		var message := LineEdit.new()
		message.name = "RequestMessage"
		message.placeholder_text = tr("Mensagem do pedido (opcional, até 140)")
		message.max_length = 140
		message.text = _request_message
		message.custom_minimum_size.y = 36 if compact else 48
		message.text_changed.connect(func(value: String) -> void: _request_message = value)
		PlayerUI.style_field(message)
		parent.add_child(message)
	elif kind == "search" and _relation(str(player.user_id)) == "friends":
		pass
	_actions(parent, player, kind)
	if kind == "search" and _relation(str(player.user_id)) == "none":
		_mutual_line(parent, str(player.user_id))
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	parent.add_child(rule)


func _actions(parent: Control, player: Dictionary, kind: String) -> void:
	var compact := _compact()
	var row := HBoxContainer.new()
	row.name = "PlayerActions"
	row.add_theme_constant_override("separation", 10 if compact else 22)
	parent.add_child(row)
	var id := str(player.user_id)
	var relation := _relation(id)
	var buttons: Array = []
	match relation if kind == "search" else kind:
		"friends":
			buttons = [["Convidar", "gamepad", true, _invite.bind(player), "Invite"], ["Enviar mensagem", "chat", false, _open_chat.bind(player), "Talk"], ["Remover amizade", "user_minus", false, _confirm_remove.bind(player), "Remove"]]
		"incoming":
			buttons = [["Aceitar", "user_plus", true, _act.bind("accept", id), "Accept"], ["Recusar", "x", false, _act.bind("decline", id), "Decline"], ["Ver perfil", "user", false, _view.bind(player), "ViewProfile"]]
		"outgoing":
			buttons = [["Cancelar solicitação", "x", true, _act.bind("cancel", id), "CancelRequest"], ["Ver perfil", "user", false, _view.bind(player), "ViewProfile"], ["Enviar mensagem", "chat", false, func() -> void: pass, "Talk"]]
		_:
			buttons = [["Adicionar amigo", "user_plus", true, func() -> void:
				await _act("send", id, _request_message)
				_request_message = "", "AddFriend"], ["Ver perfil", "user", false, _view.bind(player), "ViewProfile"], ["Enviar mensagem", "chat", false, func() -> void: pass, "Talk"]]
	# Telas baixas: rótulos curtos para as três ações caberem lado a lado.
	var short := {"Enviar mensagem": "Mensagem", "Remover amizade": "Remover", "Cancelar solicitação": "Cancelar", "Adicionar amigo": "Adicionar"}
	for item: Array in buttons:
		var label: String = short.get(item[0], item[0]) if compact else item[0]
		var button := PremiumUI.action(label, item[1], item[2], item[3], compact)
		button.name = item[4]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Conversa privada só entre amigos (regra do gateway de chat).
		if item[4] == "Talk" and relation != "friends":
			button.disabled = true
			button.tooltip_text = tr("A conversa abre quando vocês forem amigos.")
		row.add_child(button)


func _mutual_line(parent: Control, id: String) -> void:
	var entry := _fetch("mutual:" + id, "qse_mutual_friends", {"p_target": id})
	if entry.state == "ok" and entry.data is Dictionary and int(entry.data.get("count", 0)) > 0:
		var line := HBoxContainer.new()
		line.name = "MutualCount"
		line.add_theme_constant_override("separation", 8)
		line.add_child(PremiumUI.icon_rect("friends", PremiumUI.GOLD, 18 if _compact() else 26))
		line.add_child(PremiumUI.plain(tr("Amigos em comum: %d") % int(entry.data.count), 13 if _compact() else 19, Color.WHITE, false))
		parent.add_child(line)


func _view(player: Dictionary) -> void:
	navigate_requested.emit("public_profile", {"public_id": player.public_id})


# --- Painéis de contexto (inferiores) --------------------------------------------------

func _context_panels(parent: Control, player: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "ContextPanels"
	row.add_theme_constant_override("separation", 12 if _compact() else 22)
	parent.add_child(row)
	var id := str(player.user_id)
	var request := services.friends.request_info(id)
	match _tab:
		"friends":
			var shared := _sub_panel(row, "bolt", "Ações em comum", "")
			_link_row(shared, "gamepad", "Convidar para uma partida", _invite.bind(player), "InviteRow")
			_link_row(shared, "chat", "Abrir conversa", _open_chat.bind(player), "ChatRow")
			var stats: Variant = _remote_data(shared, "stats:" + id, "qse_friend_stats", {"p_friend": id})
			if stats is Dictionary:
				var last := PlayerContracts.ago(PlayerContracts.iso_seconds(str(stats.get("last_played_at", ""))))
				_info_row(shared, "stats", tr("Partidas juntos: %d") % int(stats.get("matches_together", 0)) + ("  ·  " + tr("última ") + last if not last.is_empty() else ""))
			var invites := _sub_panel(row, "mail", "Convites pendentes", tr("Convites de jogo que você ou %s enviaram.") % _nickname(player))
			var list: Variant = _remote_data(invites, "invites:" + id, "qse_duel_invites_between", {"p_friend": id})
			if list is Array:
				for invite: Dictionary in list: _invite_row(invites, invite, player)
				if list.is_empty(): _unavailable(invites, "Nenhum convite pendente.")
		"incoming":
			var mutual := _sub_panel(row, "friends", "Amigos em comum", "")
			_mutual(mutual, id)
			var right := VBoxContainer.new()
			right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			right.add_theme_constant_override("separation", 12)
			row.add_child(right)
			var message: Variant = request.get("message")
			if message is String and not str(message).is_empty():
				var note := _sub_panel(right, "chat", "Mensagem do pedido", "")
				_info_row(note, "chat", "“%s”" % message)
			var others := _sub_panel(right, "inbox", tr("Outras solicitações (%d)") % maxi(services.friends.data.get("incoming", []).size() - 1, 0), "")
			for other: Dictionary in services.friends.data.get("incoming", []):
				if str(other.user_id) == id: continue
				_request_row(others, other)
			if others.get_child_count() <= 1: _unavailable(others, "Nenhuma outra solicitação.")
		"outgoing":
			var details := _sub_panel(row, "info", "Detalhes do envio", "")
			var sent := PlayerContracts.ago(PlayerContracts.iso_seconds(str(request.get("requested_at", ""))))
			_info_row(details, "send", tr("Solicitação enviada ") + (sent if not sent.is_empty() else tr("para %s") % _nickname(player)))
			var message: Variant = request.get("message")
			if message is String and not str(message).is_empty(): _info_row(details, "chat", tr("Mensagem enviada: ") + "“%s”" % message)
			_info_row(details, "clock", "Aguardando resposta do jogador")
			var mutual := _sub_panel(row, "friends", "Amigos em comum", "")
			_mutual(mutual, id)


func _mutual(parent: Control, id: String) -> void:
	var data: Variant = _remote_data(parent, "mutual:" + id, "qse_mutual_friends", {"p_target": id})
	if not data is Dictionary: return
	var players: Array = data.get("players", []) if data.get("players") is Array else []
	(parent.get_child(0).get_child(1) as Label).text = tr("Amigos em comum (%d)") % int(data.get("count", players.size()))
	for friend: Dictionary in players:
		_link_row(parent, "user", _nickname(friend), func() -> void:
			_selected["friends"] = str(friend.user_id)
			_change_tab("friends"), "Mutual_" + str(friend.public_id))
	if players.is_empty(): _unavailable(parent, "Nenhum amigo em comum.")


## Convite entre amigos: o destinatário recebe o token e pode entrar direto.
func _invite_row(parent: Control, invite: Dictionary, friend: Dictionary) -> void:
	var compact := _compact()
	var card := PanelContainer.new()
	card.name = "Invite_" + str(invite.get("room_id", ""))
	card.add_theme_stylebox_override("panel", PremiumUI.row_box(compact))
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	card.add_child(line)
	line.add_child(PremiumUI.icon_rect("gamepad", PremiumUI.GOLD, 20 if compact else 30))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	text.add_child(PremiumUI.plain(str(invite.get("room_name", "Sala")), 13 if compact else 18, Color.WHITE, false))
	var mine := str(invite.get("sent_by", "")) == str(services.session.user.get("id", ""))
	var when := PlayerContracts.ago(PlayerContracts.iso_seconds(str(invite.get("created_at", ""))))
	text.add_child(PremiumUI.plain(("Enviado por você" if mine else tr("Enviado por %s") % _nickname(friend)) + ("  ·  " + when if not when.is_empty() else ""), 11 if compact else 14, PremiumUI.MUTED, false))
	var token := str(invite.get("token", ""))
	if not token.is_empty():
		var enter := PremiumUI.action("Entrar", "check", false, func() -> void:
			banner.show_state("loading")
			var result: Dictionary = await services.duel.join_invite(token)
			if result.ok: navigate_requested.emit("duel", {})
			else: status(result), compact)
		enter.name = "JoinInvite"
		enter.custom_minimum_size.x = 90 if compact else 130
		line.add_child(enter)


func _sub_panel(parent: Control, icon: String, title: String, subtitle: String) -> VBoxContainer:
	var compact := _compact()
	var panel := PanelContainer.new()
	panel.name = "Panel_" + title.get_slice(" ", 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", PremiumUI.flat(Color(0.05, 0.07, 0.11), PremiumUI.EDGE, 14, 1, 10 if compact else 18))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6 if compact else 10)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(PremiumUI.icon_rect(icon, PremiumUI.GOLD, 20 if compact else 30))
	head.add_child(PremiumUI.plain(title, 15 if compact else 24, Color.WHITE, false))
	column.add_child(head)
	if not subtitle.is_empty() and not compact: column.add_child(PlayerUI.label(subtitle, 15, PremiumUI.MUTED))
	return column


func _link_row(parent: Control, icon: String, text: String, callback: Callable, node_name: String) -> void:
	var compact := _compact()
	var button := Button.new()
	button.name = node_name
	button.text = tr(text)
	button.icon = PremiumUI.icon(icon, PremiumUI.GOLD, 36)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 18 if compact else 26)
	button.add_theme_constant_override("h_separation", 14)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 36 if compact else 54
	button.add_theme_font_size_override("font_size", 13 if compact else 19)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := PremiumUI.row_box(compact)
		if state != "normal": box.border_color = Color(PremiumUI.GOLD, 0.55)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", Color.WHITE)
	var chevron := PremiumUI.icon_rect("chevron", PremiumUI.MUTED, 18)
	button.add_child(chevron)
	chevron.anchor_left = 1.0
	chevron.anchor_right = 1.0
	chevron.anchor_top = 0.5
	chevron.anchor_bottom = 0.5
	chevron.offset_left = -34
	chevron.offset_right = -14
	chevron.offset_top = -9
	chevron.offset_bottom = 9
	button.pressed.connect(callback)
	parent.add_child(button)


func _info_row(parent: Control, icon: String, text: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", PremiumUI.row_box(_compact()))
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	card.add_child(line)
	line.add_child(PremiumUI.icon_rect(icon, PremiumUI.GOLD, 18 if _compact() else 26))
	var label := PlayerUI.label(text, 13 if _compact() else 18, Color.WHITE)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.add_child(label)


func _request_row(parent: Control, player: Dictionary) -> void:
	var compact := _compact()
	var card := PanelContainer.new()
	card.name = "Request_" + str(player.public_id)
	card.add_theme_stylebox_override("panel", PremiumUI.row_box(compact))
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	line.add_child(PremiumUI.avatar(PlayerUI.portrait_texture(str(player.get("equipped_character_id", ""))), 30 if compact else 48, 2))
	var name := PremiumUI.plain(_nickname(player), 13 if compact else 19, Color.WHITE, false)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	var id := str(player.user_id)
	for item: Array in [["check", true, "accept", "AcceptOther"], ["x", false, "decline", "DeclineOther"]]:
		var button := Button.new()
		button.name = item[3]
		button.icon = PremiumUI.icon(item[0], PremiumUI.INK if item[1] else Color.WHITE, 32)
		button.expand_icon = false
		button.custom_minimum_size = Vector2(40, 32) if compact else Vector2(60, 44)
		if item[1]: PremiumUI.style_gold(button)
		else: PremiumUI.style_outline(button)
		# A pessoa selecionada continua selecionada após responder a outra solicitação.
		button.pressed.connect(_act.bind(item[2], id))
		line.add_child(button)


func _suggestion_row(parent: Control, player: Dictionary, mutual: int) -> void:
	var compact := _compact()
	var card := PanelContainer.new()
	card.name = "Suggestion_" + str(player.public_id)
	card.add_theme_stylebox_override("panel", PremiumUI.row_box(compact))
	parent.add_child(card)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	card.add_child(line)
	line.add_child(PremiumUI.avatar(PlayerUI.portrait_texture(str(player.get("equipped_character_id", ""))), 30 if compact else 46, 2))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	text.add_child(PremiumUI.plain(_nickname(player), 13 if compact else 18, Color.WHITE, false))
	text.add_child(PremiumUI.plain(tr("%d amigo(s) em comum") % mutual, 11 if compact else 14, PremiumUI.MUTED, false))
	var add := PremiumUI.action("Adicionar", "user_plus", false, func() -> void:
		await _act("send", str(player.user_id))
		_remote.erase("suggestions")
		render(), compact)
	add.name = "AddSuggestion"
	add.custom_minimum_size.x = 100 if compact else 150
	line.add_child(add)


func _unavailable(parent: Control, text: String) -> void:
	var note := PlayerUI.label(text, 12 if _compact() else 16, PremiumUI.MUTED)
	note.name = "Unavailable"
	parent.add_child(note)


# --- Buscar ----------------------------------------------------------------------------

func _render_search(parent: Control) -> void:
	var compact := _compact()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	parent.add_child(head)
	head.add_child(PremiumUI.icon_rect("search", PremiumUI.GOLD, 30 if compact else 52))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	titles.add_child(PremiumUI.plain("Buscar jogadores", 20 if compact else 40, Color.WHITE))
	titles.add_child(PremiumUI.plain("Encontre amigos por nickname ou ID público.", 12 if compact else 20, PremiumUI.MUTED))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	parent.add_child(line)
	var query := LineEdit.new()
	query.name = "SearchField"
	query.text = _term
	query.placeholder_text = tr("Nickname ou ID público")
	query.right_icon = PremiumUI.icon("search", PremiumUI.MUTED, 32)
	query.custom_minimum_size.y = 40 if compact else 56
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query.add_theme_font_size_override("font_size", 15 if compact else 22)
	query.text_changed.connect(func(value: String) -> void: _term = value)
	query.text_submitted.connect(_search)
	PlayerUI.style_field(query)
	line.add_child(query)
	var go := PremiumUI.action("Buscar", "search", true, func() -> void: _search(query.text), compact)
	go.name = "SearchButton"
	go.custom_minimum_size.x = 110 if compact else 180
	line.add_child(go)
	var split := HBoxContainer.new()
	split.name = "SearchResults"
	split.add_theme_constant_override("separation", 12 if compact else 20)
	parent.add_child(split)
	var results := _sub_panel(split, "friends", tr("Resultados (%d)") % _results.size(), "")
	results.get_parent().size_flags_stretch_ratio = 0.8
	var current := _current(_results)
	for player: Dictionary in _results:
		results.add_child(_list_row(player, str(player.user_id) == str(current.get("user_id", ""))))
	if _results.is_empty():
		_unavailable(results, "Nenhum jogador encontrado." if _searched else "Digite pelo menos 2 caracteres e toque em Buscar.")
	var detail := PanelContainer.new()
	detail.name = "SearchDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 1.4
	detail.add_theme_stylebox_override("panel", PremiumUI.flat(Color(0.05, 0.07, 0.11), PremiumUI.EDGE, 14, 1, 12 if compact else 20))
	split.add_child(detail)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 10)
	detail.add_child(detail_column)
	if current.is_empty():
		_unavailable(detail_column, "Selecione um jogador para ver os detalhes.")
	else:
		_detail(detail_column, current, "search")
	var bottom := HBoxContainer.new()
	bottom.name = "SearchContext"
	bottom.add_theme_constant_override("separation", 12 if compact else 20)
	parent.add_child(bottom)
	var recent := _sub_panel(bottom, "bolt", "Jogaram recentemente", "")
	if current.is_empty():
		_unavailable(recent, "Selecione um jogador.")
	else:
		var history: Variant = _remote_data(recent, "recent:" + str(current.user_id), "qse_recent_matches_with", {"p_player": str(current.user_id), "p_limit": 5})
		if history is Dictionary:
			for match: Dictionary in (history.get("matches", []) if history.get("matches") is Array else []):
				_info_row(recent, "gamepad", tr("Mata-Mata · ") + PlayerContracts.ago(PlayerContracts.iso_seconds(str(match.get("played_at", "")))))
			if int(history.get("count", 0)) == 0: _unavailable(recent, tr("Vocês ainda não jogaram juntos."))
	var similar := _sub_panel(bottom, "friends", "Jogadores parecidos", "")
	var suggestions: Variant = _remote_data(similar, "suggestions", "qse_player_suggestions", {"p_limit": 5})
	if suggestions is Dictionary:
		var counts: Dictionary = suggestions.get("mutual_counts", {}) if suggestions.get("mutual_counts") is Dictionary else {}
		for suggestion: Dictionary in (suggestions.get("players", []) if suggestions.get("players") is Array else []):
			_suggestion_row(similar, suggestion, int(counts.get(str(suggestion.user_id), 0)))
		if similar.get_child_count() <= 1: _unavailable(similar, "Sem sugestões por enquanto.")


# --- Estados e ações reais -------------------------------------------------------------

## Sem conta: um cartão central com convite para entrar.
func _signed_out() -> void:
	var center := MarginContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 230
	body.add_child(center)
	var card := PlayerUI.column(center)
	card.custom_minimum_size.x = 0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(PremiumUI.icon_rect("friends", PremiumUI.GOLD, 64))
	var title := PlayerUI.label("Jogue com seus amigos", 28, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var enter := PremiumUI.action("Entrar na conta", "user", true, func() -> void: navigate_requested.emit("account", {}))
	enter.name = "EnterAccount"
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter.custom_minimum_size.x = 260
	card.add_child(enter)


func _empty_state(parent: Control) -> void:
	var box := VBoxContainer.new()
	box.name = "EmptyState"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.y = 220 if _compact() else 420
	box.add_theme_constant_override("separation", 14)
	parent.add_child(box)
	var icon := PremiumUI.icon_rect({"friends": "friends", "incoming": "inbox", "outgoing": "outbox"}[_tab], PremiumUI.GOLD, 56 if _compact() else 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var title := PlayerUI.label({"friends": "Você ainda não tem amigos aqui", "incoming": "Nenhuma solicitação recebida", "outgoing": "Nenhuma solicitação enviada"}[_tab], 20 if _compact() else 32, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := PlayerUI.label("Encontre jogadores pelo nickname ou ID público e envie um pedido de amizade.", 13 if _compact() else 18, PremiumUI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var go := PremiumUI.action("Buscar jogadores", "search", true, _change_tab.bind("search"), _compact())
	go.name = "GoSearch"
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.custom_minimum_size.x = 240 if _compact() else 320
	box.add_child(go)


func _search(term: String) -> void:
	_search_epoch += 1
	var epoch := _search_epoch
	banner.show_state("loading")
	var result := await services.friends.search(term)
	if epoch != _search_epoch:
		return
	_searched = true
	if result.ok and result.data is Dictionary:
		_results = result.data.get("players", [])
		_selected.erase("search")
		render()
		if _results.is_empty():
			banner.show_state("empty", "Nenhum jogador encontrado.")
	else:
		status(result)


func _act(action: String, player_id: String, message := "") -> void:
	banner.show_state("loading")
	_remote.erase("mutual:" + player_id)
	status(await services.friends.act(action, player_id, "", message))


func _confirm_remove(player: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "ConfirmRemove"
	dialog.title = tr("Remover amizade")
	dialog.dialog_text = tr("Remover %s dos seus amigos?") % _nickname(player)
	dialog.ok_button_text = tr("Remover")
	dialog.cancel_button_text = tr("Cancelar")
	add_child(dialog)
	dialog.confirmed.connect(_act.bind("remove", str(player.user_id)))
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	dialog.popup_centered()


## Convidar (T22): convite privado da sua sala online para este amigo (qse_duel_invite_send).
## Sem sala sua, leva ao Duelo para criar uma.
func _invite(player: Dictionary) -> void:
	var duel := services.duel
	if duel.is_local() or not duel.in_room() or not duel.is_admin():
		banner.show_state("empty", tr("Crie uma sala online em Mata-Mata para convidar %s.") % _nickname(player))
		navigate_requested.emit("duel", {})
		return
	banner.show_state("loading")
	var result: Dictionary = await services.friends.call_game("qse_duel_invite_send", {"p_room": duel.room_id(), "p_friend": str(player.user_id)})
	if result.ok and result.data is Dictionary and result.data.get("status") == "sent":
		banner.show_state("success", tr("Convite enviado para %s.") % _nickname(player))
		_remote.erase("invites:" + str(player.user_id))
		render()
	else:
		status(result if not result.ok else ServiceResult.failure(str(result.data.get("error", "invalid_contract")) if result.data is Dictionary else "invalid_contract"))


# --- Chat privado --------------------------------------------------------------------------
func _open_chat(player: Dictionary) -> void:
	_chat_friend = player
	_rendered_ids.clear()
	render()
	PlayerUI.reveal(body)
	await services.chat.open(player)


## Fechar para a lista (ou ao sair da tela): as consultas param.
func _close_chat(redraw := true) -> void:
	_chat_friend = {}
	services.chat.close()
	if redraw and is_visible_in_tree():
		render()
		PlayerUI.cascade(body, 1)


func _render_chat() -> void:
	heading.text = tr("Conversa")
	var compact := UIScale.is_compact()
	var layout := PlayerUI.row(body)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12 if compact else 18)
	# Amigos à esquerda: troca de conversa sem voltar à lista.
	if not compact:
		var side := PanelContainer.new()
		side.custom_minimum_size.x = 300
		side.add_theme_stylebox_override("panel", PlayerUI.frame_panel(14))
		layout.add_child(side)
		var friends := PlayerUI.column(side)
		friends.add_theme_constant_override("separation", 6)
		friends.add_child(PlayerUI.label("Amigos", 20, PlayerUI.TITLE_GOLD))
		for item: Dictionary in services.friends.data.get("friends", []):
			var pick := PlayerUI.button(str(item.get("nickname", "Sem nickname")), _open_chat.bind(item))
			PlayerUI.style_row(pick)
			pick.toggle_mode = true
			pick.button_pressed = str(item.user_id) == str(_chat_friend.get("user_id", ""))
			pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
			pick.icon = PlayerUI.portrait_texture(str(item.get("equipped_character_id", "")))
			pick.expand_icon = false
			pick.add_theme_constant_override("icon_max_width", 36)
			friends.add_child(pick)
	var panel := PanelContainer.new()
	panel.name = "ChatPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", PlayerUI.frame_panel(12 if compact else 20))
	layout.add_child(panel)
	var column := PlayerUI.column(panel)
	column.add_theme_constant_override("separation", 10)
	var header := PlayerUI.row(column)
	var back := PlayerUI.button("‹", _close_chat)
	back.name = "CloseChat"
	back.tooltip_text = tr("Voltar aos amigos")
	back.custom_minimum_size = Vector2(52, 52)
	header.add_child(back)
	var avatar := PlayerUI.portrait(str(_chat_friend.get("equipped_character_id", "")), 48 if compact else 64)
	header.add_child(avatar)
	var who := PlayerUI.column(header)
	who.add_theme_constant_override("separation", 0)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(PlayerUI.label(str(_chat_friend.get("nickname", "Sem nickname")), 22 if compact else 26, Color.WHITE))
	var presence := services.friends.presence_label(str(_chat_friend.get("user_id", "")))
	who.add_child(PlayerUI.label(("● " if presence == "Online" else "") + presence + "  ·  mensagens somem em 24 h", 14, Color("#7fe0a0") if presence == "Online" else PlayerUI.MUTED))
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.name = "Messages"
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A conversa ocupa a altura disponível (o corpo da tela rola, não estica sozinho).
	var free_height := get_viewport_rect().size.y / PlayerUI.unit(self) - (230.0 if compact else 330.0)
	_chat_scroll.custom_minimum_size.y = maxf(free_height, 120.0)
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_chat_scroll)
	_chat_list = VBoxContainer.new()
	_chat_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_list.add_theme_constant_override("separation", 8)
	_chat_scroll.add_child(_chat_list)
	_chat_status = PlayerUI.label("", 18, PlayerUI.MUTED)
	_chat_status.name = "ChatStatus"
	_chat_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_status.custom_minimum_size.y = 80
	_chat_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chat_list.add_child(_chat_status)
	var composer := PlayerUI.row(column)
	composer.add_theme_constant_override("separation", 10)
	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.placeholder_text = tr("Escreva uma mensagem")
	_chat_input.max_length = ChatService.MAX_LENGTH
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.custom_minimum_size.y = 52
	PlayerUI.style_field(_chat_input)
	_chat_input.text_submitted.connect(func(_value: String) -> void: _send_chat())
	composer.add_child(_chat_input)
	_chat_send = PlayerUI.button("Enviar", _send_chat)
	_chat_send.name = "ChatSend"
	PlayerUI.style_button(_chat_send, true)
	_chat_send.custom_minimum_size.x = 120
	composer.add_child(_chat_send)
	_rendered_ids.clear()
	_append_messages()
	_chat_state_changed()


## Estado do chat (carregando, vazio, indisponível, erro) e botão de enviar.
func _chat_state_changed() -> void:
	if _chat_friend.is_empty() or not _chat_alive(): return
	var chat := services.chat
	var text := ""
	match chat.state:
		"loading": text = "Abrindo conversa…"
		"unavailable", "error": text = ChatService.message_for(chat.error_code if not chat.error_code.is_empty() else "chat_unavailable")
		"ready":
			if not chat.error_code.is_empty(): text = ChatService.message_for(chat.error_code)
			elif chat.messages().is_empty(): text = "Nenhuma mensagem ainda. Diga oi!"
	_chat_status.text = text
	_chat_status.visible = not text.is_empty()
	_chat_status.add_theme_color_override("font_color", Color("#ffb8a6") if chat.state in ["error", "unavailable"] or not chat.error_code.is_empty() else PlayerUI.MUTED)
	var usable: bool = chat.is_open()
	_chat_input.editable = usable
	_chat_send.disabled = not usable or chat.sending
	_chat_send.text = tr("Enviando…") if chat.sending else tr("Enviar")


## Acrescenta só as mensagens novas (não redesenha a conversa) e remove as vencidas.
func _append_messages() -> void:
	if _chat_friend.is_empty() or not _chat_alive(): return
	var current := services.chat.messages()
	var alive := {}
	for message: Dictionary in current: alive[str(message.id)] = true
	for id: String in _rendered_ids.keys():
		if not alive.has(id):
			(_rendered_ids[id] as Node).queue_free()
			_rendered_ids.erase(id)
	var bar := _chat_scroll.get_v_scroll_bar()
	var at_bottom := bar.value + bar.page >= bar.max_value - 40
	var added := false
	for message: Dictionary in current:
		if _rendered_ids.has(str(message.id)): continue
		var bubble := _bubble(message)
		_chat_list.add_child(bubble)
		_rendered_ids[str(message.id)] = bubble
		added = true
	_chat_state_changed()
	# Só desce sozinho se o jogador já estava no fim (lendo antigas, a rolagem fica).
	if added and at_bottom:
		await get_tree().process_frame
		if is_instance_valid(_chat_scroll): _chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _bubble(message: Dictionary) -> Control:
	var mine := services.chat.is_mine(message)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var bubble := PanelContainer.new()
	bubble.name = "Mine" if mine else "Theirs"
	var style := PlayerUI.plate(mine)
	style.set_corner_radius_all(14)
	style.corner_radius_bottom_right = 4 if mine else 14
	style.corner_radius_bottom_left = 14 if mine else 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", style)
	bubble.custom_minimum_size.x = 0
	line.add_child(bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	bubble.add_child(box)
	var text := PlayerUI.label(str(message.text), 18, Color.WHITE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = clampf(str(message.text).length() * 10.0, 60.0, 460.0)
	box.add_child(text)
	var when := Time.get_datetime_dict_from_unix_time(int(message.get("created_at", 0)) + int(Time.get_time_zone_from_system().bias) * 60)
	var stamp := PlayerUI.label("%02d:%02d" % [when.hour, when.minute], 12, PlayerUI.GOLD if mine else PlayerUI.MUTED)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(stamp)
	return line


func _send_chat() -> void:
	if not is_instance_valid(_chat_input): return
	var text := _chat_input.text
	if text.strip_edges().is_empty():
		_chat_status.text = ChatService.message_for("empty_message")
		_chat_status.visible = true
		return
	var result: Dictionary = await services.chat.send(text)
	if result.ok and is_instance_valid(_chat_input):
		_chat_input.text = ""
		_chat_input.grab_focus()
	elif not result.ok and is_instance_valid(_chat_status):
		_chat_status.text = ChatService.message_for(str(result.code))
		_chat_status.visible = true


## Nós da conversa ainda vivos (a tela é redesenhada ao trocar de amigo ou de vista).
func _chat_alive() -> bool:
	for node: Node in [_chat_status, _chat_list, _chat_scroll, _chat_input, _chat_send]:
		if not is_instance_valid(node) or node.is_queued_for_deletion(): return false
	return true
