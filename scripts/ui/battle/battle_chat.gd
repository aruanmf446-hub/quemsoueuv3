extends PanelContainer
## Chat da SALA do Duelo (DUEL_ROOM_CHAT_API_V1): participantes autorizados da sala, validados
## pelo GAME a cada chamada. Diferente do chat privado de Amigos. Na partida local não há chat
## (bots não conversam); o painel continua no lugar, com o estado indisponível.
const Style = preload("res://scripts/ui/battle/battle_style.gd")
var services: PlayerServices
var _selector: OptionButton
var _messages: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _input: LineEdit
var _send: Button
var _body: VBoxContainer
var _header: Button
var _badge: Label
var _friends: Array = []
var _rendered := {}
var _owned := false
var _collapsed := false
var _unread := 0
var _chat: ChatService
func setup(value: PlayerServices) -> void:
	services = value
	_chat = services.room_chat
func _ready() -> void:
	add_theme_stylebox_override("panel",Style.panel(6))
	var column := PlayerUI.column(self)
	column.add_theme_constant_override("separation",5)
	_header = Style.action("Chat da sala",_toggle,"chat")
	_header.name = "ChatToggle"
	Style.strong(_header)
	_header.add_theme_font_size_override("font_size",14)
	var title_style := Style.panel(2)
	title_style.bg_color = Color(0,0,0,0)
	title_style.set_border_width_all(0)
	title_style.shadow_size = 0
	_header.add_theme_stylebox_override("normal",title_style)
	_header.tooltip_text = "Recolher histórico; a conversa da sala continua aberta"
	_header.custom_minimum_size.y = 26
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_header)
	_badge = Style.label("",11)
	_badge.name = "UnreadBadge"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#e3354f")
	badge_style.set_corner_radius_all(9)
	badge_style.set_content_margin_all(2)
	_badge.add_theme_stylebox_override("normal",badge_style)
	_header.add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.position = Vector2(-23,4)
	_badge.size = Vector2(19,18)
	_badge.hide()
	_body = PlayerUI.column(column)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",4)
	_selector = OptionButton.new()
	_selector.name = "ChatFriend"
	_selector.fit_to_longest_item = false
	_selector.clip_text = true
	_selector.custom_minimum_size = Vector2(0,26)
	_selector.add_theme_font_size_override("font_size",12)
	_body.add_child(_selector)
	_scroll = ScrollContainer.new()
	_scroll.name = "Messages"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	_messages = PlayerUI.column(_scroll)
	_messages.add_theme_constant_override("separation",5)
	_status = Style.label("",12,PlayerUI.MUTED)
	_status.name = "ChatStatus"
	_messages.add_child(_status)
	var composer := PlayerUI.row(_body)
	composer.add_theme_constant_override("separation",4)
	_input = LineEdit.new()
	_input.name = "ChatInput"
	_input.placeholder_text = "Mensagem…"
	_input.tooltip_text = "Mensagem para todos da sala"
	_input.max_length = ChatService.MAX_LENGTH
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0,28)
	_input.add_theme_font_size_override("font_size",12)
	PlayerUI.style_field(_input)
	_input.text_submitted.connect(func(_text: String) -> void: _send_text())
	composer.add_child(_input)
	_send = Style.action("",_send_text,"send")
	_send.name = "ChatSend"
	_send.tooltip_text = "Enviar para a sala"
	_send.custom_minimum_size.x = 28
	composer.add_child(_send)
	_chat.changed.connect(_state)
	_chat.messages_changed.connect(_append)
	services.session.changed.connect(refresh_availability)
	services.duel.changed.connect(refresh_availability)
	visibility_changed.connect(_visibility)
	refresh_availability()
func refresh_availability() -> void:
	if not is_inside_tree(): return
	var duel := services.duel
	# A visibilidade acompanha o modo, inclusive se a sala mudar enquanto a UI existe.
	# Alterar visible só quando necessário evita recursão do visibility_changed.
	if duel.is_local() and visible:
		hide()
	elif not duel.is_local() and not visible:
		show()
	_selector.hide()
	var room := "" if duel.is_local() or not duel.in_room() else duel.room_id()
	var allowed: bool = services.session.authenticated() and not room.is_empty() and str(duel.room.get("room",{}).get("status","")) in ["lobby","in_match"]
	if not allowed:
		_stop()
		_clear_messages()
	elif not _owned or _chat.room_id != room:
		_stop()
		_clear_messages()
		_owned = true
		await _chat.open_room(room)
		_append(_chat.conversation_id)
	_state()
func _state() -> void:
	if not is_inside_tree(): return
	var chat := _chat
	# Acesso à sala recusado (saiu, expulso, sala fechada): nada da conversa fica na tela.
	if _owned and chat.conversation_id.is_empty() and chat.error_code == "room_access_denied" and not _rendered.is_empty():
		_clear_messages()
	if _owned and chat.state == "closed":
		_owned = false
		_clear_messages()
		_input.clear()
	var text := ""
	if services.duel.is_local(): text = "Chat da sala só em salas online. Na partida local não há conversa."
	elif not services.session.authenticated(): text = "Entre na conta para conversar na sala."
	elif not _owned: text = "Chat da sala indisponível."
	elif chat.state == "loading": text = "Abrindo conversa…"
	elif not chat.error_code.is_empty(): text = ChatService.message_for(chat.error_code)
	elif chat.state in ["unavailable","error"]: text = ChatService.message_for("chat_unavailable")
	elif chat.messages().is_empty(): text = "Nenhuma mensagem ainda."
	_status.text = text
	_status.visible = not text.is_empty()
	_input.editable = _owned and chat.is_open()
	_send.disabled = not _input.editable or chat.sending
func _append(id: String) -> void:
	if not _owned or not is_inside_tree() or id != _chat.conversation_id: return
	var chat := _chat
	var messages := chat.messages()
	var live := {}
	for message: Dictionary in messages: live[str(message.id)] = true
	for key: String in _rendered.keys():
		if not live.has(key):
			_rendered[key].queue_free()
			_rendered.erase(key)
	var bar := _scroll.get_v_scroll_bar()
	var bottom := bar.value + bar.page >= bar.max_value - 20
	var added := 0
	for message: Dictionary in messages:
		if _rendered.has(str(message.id)): continue
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override("panel",Style.panel(5,chat.is_mine(message)))
		var column := PlayerUI.column(bubble)
		column.add_theme_constant_override("separation",2)
		var when := Time.get_datetime_dict_from_unix_time(int(message.get("created_at",0))+int(Time.get_time_zone_from_system().bias)*60)
		column.add_child(Style.label("%s · %02d:%02d" % ["Você" if chat.is_mine(message) else str(message.get("sender_name","Participante")),when.hour,when.minute],10,PlayerUI.GOLD))
		var text := Style.label(str(message.text),12)
		text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		column.add_child(text)
		_messages.add_child(bubble)
		_rendered[str(message.id)] = bubble
		added += 1
	if _collapsed: _unread += added
	_badge.text = str(_unread)
	_badge.visible = _unread > 0
	_state()
	if added > 0 and bottom:
		await get_tree().process_frame
		if is_instance_valid(_scroll): _scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
func _send_text() -> void:
	if not _owned or _input.text.strip_edges().is_empty(): return
	var result := await _chat.send(_input.text)
	if is_instance_valid(_input) and result.ok: _input.clear()
func _toggle() -> void:
	_collapsed = not _collapsed
	_body.visible = not _collapsed
	if not _collapsed: _unread = 0
	_badge.text = str(_unread)
	_badge.visible = _unread > 0
func _stop() -> void:
	if _owned: _chat.close()
	_owned = false
func _visibility() -> void:
	if is_visible_in_tree():
		refresh_availability()
		return
	if not is_visible_in_tree():
		_stop()
		_clear_messages()
		pass
func _exit_tree() -> void: _stop()

func _clear_messages() -> void:
	_unread = 0
	if is_instance_valid(_badge): _badge.hide()
	_rendered.clear()
	for child in _messages.get_children():
		if child != _status:
			_messages.remove_child(child)
			child.queue_free()
