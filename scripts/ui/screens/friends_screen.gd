extends PlayerScreen

var _tab := "friends"
var _term := ""
var _results: Array = []
var _search_epoch := 0
## Conversa aberta (amigo) ou {} na lista. O chat só consulta o servidor com ela aberta.
var _chat_friend: Dictionary = {}
var _chat_list: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_input: LineEdit
var _chat_status: Label
var _chat_send: Button
var _rendered_ids: Dictionary = {}


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
		if is_visible_in_tree() and _chat_friend.is_empty(): render())
	services.chat.changed.connect(_chat_state_changed)
	services.chat.messages_changed.connect(func(_id: String) -> void: _append_messages())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree() and not _chat_friend.is_empty(): _close_chat(false))


func render() -> void:
	PlayerUI.clear(body)
	banner.show_state(services.friends.state)
	if not services.session.authenticated():
		_signed_out()
		return
	if not _chat_friend.is_empty():
		_render_chat()
		return
	var tabs := PlayerUI.row(body)
	tabs.add_theme_constant_override("separation", 8)
	for item: Array in [["Amigos", "friends"], ["Recebidas", "incoming"], ["Enviadas", "outgoing"], ["Buscar", "search"]]:
		var count: int = services.friends.data.get(item[1], []).size() if item[1] != "search" else 0
		var tab := PlayerUI.button(item[0] + ("  %d" % count if count > 0 else ""), _change_tab.bind(item[1]))
		PlayerUI.style_row(tab)
		tab.toggle_mode = true
		tab.button_pressed = item[1] == _tab
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
		PlayerUI.style_field(query)
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
	var center := MarginContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 230
	body.add_child(center)
	var card := PlayerUI.column(center)
	card.custom_minimum_size.x = 0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/icons/vector/icon_friends.svg")
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = PlayerUI.GOLD
	card.add_child(icon)
	var title := PlayerUI.label("Jogue com seus amigos", 28, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(title)
	var enter := PlayerUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}))
	PlayerUI.style_button(enter, true)
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enter.custom_minimum_size.x = 240
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
	var nickname := PlayerUI.label(str(player.get("nickname", "Sem nickname")), 24, PlayerUI.GOLD)
	nickname.autowrap_mode = TextServer.AUTOWRAP_OFF
	nickname.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nickname.clip_text = true
	info.add_child(nickname)
	info.custom_minimum_size.x = 120
	var presence := services.friends.presence_label(str(player.user_id))
	var entry := services.inventory.entry(character_id)
	var online := presence == "Online"
	var details := PlayerUI.label("%s%s  ·  %s" % ["● " if online else "", presence, entry.get("name", "Skin indisponível")], 16, Color("#7fe0a0") if online else Color("#a8bad3"))
	# Em telas estreitas uma linha só, com reticências, em vez de quebrar letra a letra.
	details.autowrap_mode = TextServer.AUTOWRAP_OFF
	details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details.clip_text = true
	details.custom_minimum_size.x = 0
	details.tooltip_text = details.text
	info.add_child(details)
	var view := PlayerUI.button("Ver perfil", func() -> void: navigate_requested.emit("public_profile", {"public_id": player.public_id}))
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(view)
	if action == "remove":
		var talk := PlayerUI.button("Conversar", _open_chat.bind(player))
		talk.name = "Talk"
		PlayerUI.style_button(talk, true)
		talk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(talk)
	var actions := {"send": "Adicionar", "accept": "Aceitar", "decline": "Recusar", "cancel": "Cancelar", "remove": "Remover"}
	var main := PlayerUI.button(actions[action], _act.bind(action, str(player.user_id)))
	PlayerUI.style_button(main, action in ["send", "accept"])
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(main)
	if action == "accept":
		var decline := PlayerUI.button("Recusar", _act.bind("decline", str(player.user_id)))
		decline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(decline)
	# Telas estreitas (celular deitado): botões menores para todos caberem na linha.
	if UIScale.is_compact():
		row.add_theme_constant_override("separation", 8)
		avatar.custom_minimum_size = Vector2(44, 44)
		info.custom_minimum_size.x = 80
		for button: Button in row.find_children("*", "Button", false, false):
			button.add_theme_font_size_override("font_size", 16)
			button.custom_minimum_size = Vector2(0, 44)
			for side in ["left", "right"]:
				for style in ["normal", "hover", "pressed", "focus", "disabled"]:
					var box := button.get_theme_stylebox(style)
					if box != null:
						box = box.duplicate()
						box.set("content_margin_" + side, 10)
						button.add_theme_stylebox_override(style, box)


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
