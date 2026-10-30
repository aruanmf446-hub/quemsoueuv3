extends Control
## Presentation only. DuelService remains the sole source of rules, timing and private data.
const Style = preload("res://scripts/ui/battle/battle_style.gd")
const Surface = preload("res://scripts/ui/battle/battle_surface.gd")
const Card = preload("res://scripts/ui/battle/battle_card.gd")
const ChatPanel = preload("res://scripts/ui/battle/battle_chat.gd")
const Icons = preload("res://scripts/desert/t15d/resource_icons.gd")
var duel: DuelService
var inventory: InventoryService
var act: Callable
var overlay_parent: Control
var _chosen: Array = []
var _canvas: Control
var _main: VBoxContainer
var _side: VBoxContainer
var _roster: GridContainer
var _board: PanelContainer
var _board_content: VBoxContainer
var _grid: GridContainer
var _instruction: Label
var _detail: Label
var _timer: Label
var _confirm: Button
var _cancel: Button
var _hand: VBoxContainer
var _hand_toggle: Button
var _private_shown := false
var _private_signature := ""
var _last_lives := {}
var _last_player_states := {}
var _hand_before_reveal: Array = []
var _notice_ttl := 0.0
var _last_event := ""
var _pending_pick := ""
var _notice: Label
var _data: Dictionary = {}
var _built := false
var _countdown: Label
func setup(p_duel: DuelService, p_inventory: InventoryService, p_parent: Control, p_act: Callable) -> void:
	duel = p_duel
	inventory = p_inventory
	overlay_parent = p_parent
	act = p_act
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
func _ready() -> void:
	_build()
	resized.connect(_layout)
	get_window().focus_exited.connect(_conceal_hand)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_conceal_hand()
			_pending_pick = "")
	_layout.call_deferred()
func _build() -> void:
	if _built: return
	_built = true
	PlayerUI.apply_theme(self)
	var background := Surface.new()
	background.name = "BattleAtmosphere"
	background.atmosphere = true
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.name = "Composition"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_main = VBoxContainer.new()
	_main.name = "PublicArea"
	_main.add_theme_constant_override("separation",3)
	_canvas.add_child(_main)
	var header := PlayerUI.row(_main)
	header.name = "BattleHeader"
	header.custom_minimum_size.y = 30
	header.add_theme_constant_override("separation",10)
	var back := Style.action("Voltar",func() -> void: _back(),"back")
	back.name = "BattleBack"
	back.custom_minimum_size.x = 72
	header.add_child(back)
	var title := Style.label("Batalha · Partida local" if duel.is_local() else "Batalha",18)
	title.name = "BattleTitle"
	Style.strong(title)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	_roster = GridContainer.new()
	_roster.name = "Players"
	_roster.add_theme_constant_override("h_separation",5)
	_roster.add_theme_constant_override("v_separation",3)
	_main.add_child(_roster)
	_board = Surface.new()
	_board.name = "BattleBoard"
	_board.variant = "board"
	_board.padding = 10
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_PASS
	_main.add_child(_board)
	_board_content = PlayerUI.column(_board)
	_board_content.add_theme_constant_override("separation",5)
	var instruction_row := PlayerUI.row(_board_content)
	instruction_row.add_theme_constant_override("separation",5)
	var message := PlayerUI.column(instruction_row)
	message.add_theme_constant_override("separation",0)
	_instruction = Style.label("",22,PlayerUI.GOLD)
	Style.strong(_instruction)
	_instruction.add_theme_constant_override("shadow_offset_y",1)
	_instruction.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	_instruction.name = "RoundInstruction"
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction.autowrap_mode = TextServer.AUTOWRAP_OFF
	_instruction.clip_text = true
	_detail = Style.label("",12,Color("#b7c0cc"))
	_detail.name = "RoundDetail"
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.clip_text = true
	message.add_child(_instruction)
	# Filete curto entre "quem joga" e "o que fazer".
	var divider := ColorRect.new()
	divider.name = "TurnDivider"
	divider.color = Color(PlayerUI.GOLD,0.55)
	divider.custom_minimum_size = Vector2(72,1)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_child(divider)
	message.add_child(_detail)
	var actions := PlayerUI.row(instruction_row)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_END
	actions.add_theme_constant_override("separation",2)
	_confirm = Style.action("Confirmar cartas",_commit_selection,"",true)
	_confirm.name = "ConfirmSelection"
	actions.add_child(_confirm)
	_cancel = Style.action("Cancelar",_close_overlay)
	_cancel.name = "CancelPick"
	actions.add_child(_cancel)
	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",8)
	_grid.add_theme_constant_override("v_separation",8)
	_grid.resized.connect(_fit_cards)
	_board_content.add_child(_grid)
	_side = VBoxContainer.new()
	_side.name = "UtilityRail"
	_side.add_theme_constant_override("separation",5)
	_canvas.add_child(_side)
	_build_sidebar()
func _build_sidebar() -> void:
	var controls := PlayerUI.row(_side)
	controls.name = "RoomControls"
	controls.add_theme_constant_override("separation",4)
	var timer_box := PanelContainer.new()
	timer_box.add_theme_stylebox_override("panel",Style.panel(4))
	timer_box.custom_minimum_size = Vector2(68,30)
	timer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(timer_box)
	var timer_row := PlayerUI.row(timer_box)
	timer_row.add_theme_constant_override("separation",4)
	var hourglass := TextureRect.new()
	hourglass.texture = load("res://assets/ui/battle/time.svg")
	hourglass.modulate = PlayerUI.GOLD
	hourglass.custom_minimum_size = Vector2(20,20)
	hourglass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hourglass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	timer_row.add_child(hourglass)
	_timer = Style.label("",15)
	_timer.name = "RoundTimer"
	Style.strong(_timer)
	_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_row.add_child(_timer)
	var settings := Style.action("",func() -> void: overlay_parent.emit_signal("navigate_requested","settings",{}))
	settings.name = "BattleSettings"
	settings.icon = load("res://assets/ui/battle/settings.svg")
	settings.tooltip_text = "Configurações · a rodada continua"
	settings.custom_minimum_size = Vector2(30,30)
	controls.add_child(settings)
	# Sala e convite agrupados num painel próprio (antes disputavam espaço com tempo/ajustes).
	var room_panel := PanelContainer.new()
	room_panel.name = "RoomInvite"
	room_panel.add_theme_stylebox_override("panel",Style.panel(5))
	_side.add_child(room_panel)
	var room_row := PlayerUI.row(room_panel)
	room_row.add_theme_constant_override("separation",4)
	var room_text := PlayerUI.column(room_row)
	room_text.add_theme_constant_override("separation",0)
	room_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var code := str(duel.room.get("room",{}).get("code",""))
	if not duel.is_local() and not code.is_empty():
		room_text.add_child(Style.label("Código da sala",10,PlayerUI.MUTED))
		var code_label := Style.label(code,16)
		Style.strong(code_label)
		code_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		room_text.add_child(code_label)
		var copy := Style.action("",func() -> void:
			DisplayServer.clipboard_set(code)
			_notice.text = "Código copiado"
			_notice_ttl = 3.5,"copy")
		copy.name = "CopyRoomCode"
		copy.tooltip_text = "Copiar código da sala"
		copy.custom_minimum_size = Vector2(30,30)
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		room_row.add_child(copy)
		# Convite por link: só o ADM gera (o servidor recusa os outros).
		if duel.is_admin():
			var share := Style.action("",_share_invite,"share")
			share.name = "ShareInvite"
			share.tooltip_text = "Compartilhar convite"
			share.custom_minimum_size = Vector2(30,30)
			share.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			room_row.add_child(share)
	else:
		room_text.add_child(Style.label("Partida local",13,PlayerUI.GOLD))
		room_text.add_child(Style.label("Só neste aparelho · sem convite",10,PlayerUI.MUTED))
	var voice := PanelContainer.new()
	voice.name = "VoiceUnavailable"
	voice.add_theme_stylebox_override("panel",Style.panel(5))
	_side.add_child(voice)
	var voice_row := PlayerUI.row(voice)
	voice_row.add_theme_constant_override("separation",6)
	var mic := TextureRect.new()
	mic.texture = load("res://assets/ui/battle/voice_off.svg")
	mic.modulate = PlayerUI.MUTED
	mic.custom_minimum_size = Vector2(26,26)
	mic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	voice_row.add_child(mic)
	var voice_text := PlayerUI.column(voice_row)
	voice_text.add_theme_constant_override("separation",0)
	var voice_title := Style.label("Chat de voz",13)
	Style.strong(voice_title)
	voice_text.add_child(voice_title)
	var unavailable := PlayerUI.pill("INDISPONÍVEL","locked")
	unavailable.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	unavailable.modulate = Color(1,1,1,0.85)
	voice_text.add_child(unavailable)
	var chat := ChatPanel.new()
	chat.name = "BattleChat"
	chat.setup(overlay_parent.get("services") as PlayerServices)
	chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(chat)
	var private_panel := PanelContainer.new()
	private_panel.name = "PrivatePanel"
	private_panel.add_theme_stylebox_override("panel",Style.panel(6))
	_side.add_child(private_panel)
	_hand = PlayerUI.column(private_panel)
	_hand.add_theme_constant_override("separation",3)
	var hand_header := PlayerUI.row(_hand)
	var lock := TextureRect.new()
	lock.texture = load("res://assets/ui/battle/lock.svg")
	lock.custom_minimum_size = Vector2(16,16)
	lock.modulate = PlayerUI.GOLD
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand_header.add_child(lock)
	var hand_title := Style.label("Suas cartas",14,PlayerUI.TITLE_GOLD)
	Style.strong(hand_title)
	hand_header.add_child(hand_title)
	var private_body := GridContainer.new()
	private_body.name = "PrivateCards"
	private_body.custom_minimum_size.y = 40
	private_body.add_theme_constant_override("h_separation",3)
	private_body.add_theme_constant_override("v_separation",3)
	_hand.add_child(private_body)
	_hand_toggle = Style.action("Mostrar",func() -> void:
		_private_shown = not _private_shown
		_private_signature = ""
		_render_hand(),"eye")
	_hand_toggle.name = "TogglePrivateCards"
	_hand.add_child(_hand_toggle)
	_notice = Style.label("",11,PlayerUI.GOLD)
	_notice.name = "BattleNotice"
	_notice.max_lines_visible = 2
	_notice.add_theme_stylebox_override("normal",Style.panel(4,true))
	_notice.hide()
	# Aviso flutuante no canto inferior esquerdo, sobre o fundo e fora do tabuleiro.
	_notice.z_index = 4
	_notice.custom_minimum_size = Vector2(190,0)
	_canvas.add_child(_notice)
	var leave := Style.action("Sair da sala",func() -> void: overlay_parent.call("_leave_room"))
	leave.name = "LeaveBattle"
	leave.custom_minimum_size.y = 24
	leave.add_theme_font_size_override("font_size",11)
	_side.add_child(leave)
## Gera um convite (60 min) e copia. Sem rota oficial de link configurada, copia o
## convite para colar em Duelo → Código do convite; nunca inclui o UUID da sala.
func _share_invite() -> void:
	_notice.text = "Gerando convite…"
	_notice_ttl = 3.5
	var result := await duel.create_invite(60)
	if not result.ok or not result.data is Dictionary or str(result.data.get("token","")).is_empty():
		_notice.text = DuelService.message(str(result.code)) if not result.ok else "Não foi possível gerar o convite."
		_notice_ttl = 3.5
		return
	var link := DuelService.invite_link(str(result.data.token))
	DisplayServer.clipboard_set(link)
	_notice.text = "Convite copiado · vale 60 min"
	_notice_ttl = 3.5
func refresh() -> void:
	if not _built: _build()
	_data = duel.match()
	if _data.is_empty(): return
	var available_ids: Array = _data.pool.map(func(card: Dictionary) -> String: return str(card.card_id))
	_chosen = _chosen.filter(func(id: String) -> bool: return available_ids.has(id))
	var me := _me(_data)
	if _data.phase != "selection": _chosen.clear()
	if _data.phase != "turns" or not _is_my_turn(): _pending_pick = ""
	_render_players()
	_render_instruction(me)
	_render_public(me)
	_render_hand()
	_layout.call_deferred()
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_timer): return
	if _notice_ttl > 0:
		_notice_ttl -= _delta
		if _notice_ttl <= 0: _notice.text = ""
	var showing := not _notice.text.is_empty()
	if showing and not _notice.visible:
		# Entrada curta (escala; a posição é do container) em vez de surgir de repente.
		_notice.pivot_offset = _notice.size*0.5
		_notice.scale = Vector2(0.92,0.92)
		_notice.create_tween().tween_property(_notice,"scale",Vector2.ONE,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_notice.visible = showing
	_notice.modulate.a = minf(_notice_ttl/0.3,1.0) if _notice_ttl > 0 else 1.0
	var seconds := maxi(ceili(duel.seconds_left()),0)
	_timer.text = "FIM" if _closed() else "%d s" % seconds
	_timer.add_theme_color_override("font_color",Color("#ff8f86") if seconds <= 10 else PlayerUI.TEXT)
	if _data.get("phase","") == "countdown":
		_instruction.text = "Começa em %d" % maxi(seconds,1)
func _render_instruction(me: Dictionary) -> void:
	_confirm.hide()
	_cancel.hide()
	var phase := str(_data.phase)
	if _closed():
		_instruction.text = "Partida encerrada"
		_detail.text = "Nenhum jogador real continuou vivo. Não há campeão."
		return
	var turn := _player(_data,str(_data.get("turn_member","")))
	match phase:
		"selection":
			var needed := int(_data.get("cards_per_player",1))
			_instruction.text = "Escolha suas cartas"
			_detail.text = "%d de %d selecionadas · escolha em segredo" % [_chosen.size(),needed]
			_confirm.text = "Confirmar cartas"
			_confirm.visible = not me.is_empty() and not me.confirmed and not me.eliminated
			_confirm.disabled = _chosen.size() != needed
			if me.get("confirmed",false): _detail.text = "PRONTO! Aguardando os outros jogadores."
		"countdown":
			_instruction.text = "A partida vai começar!"
			_detail.text = "Suas cartas permanecem privadas."
		"turns":
			_instruction.text = "É a sua vez!" if _is_my_turn() else "Vez de %s" % str(turn.get("nickname","…"))
			_detail.text = "Escolha uma carta para eliminar." if _is_my_turn() else "Aguarde a escolha do jogador."
			if not _pending_pick.is_empty():
				_detail.text = "Eliminar %s?" % _name(_pending_pick)
				_confirm.text = "Eliminar"
				_confirm.show()
				_confirm.disabled = false
				_cancel.show()
		"reveal":
			_render_event()
			# Identifica a própria jogada sem refazer o layout da batalha.
			if bool(turn.get("is_you", false)):
				_instruction.text = "Sua jogada"
		"finished":
			var winners: Array = (_data.result if _data.get("result") is Dictionary else {}).get("winners",[])
			_instruction.text = "Vitória de %s!" % str(_player(_data,str(winners[0])).get("nickname","")) if winners.size() == 1 else "Empate!"
			_detail.text = "Voltando ao lobby da sala…"
		_:
			_instruction.text = "Batalha"
			_detail.text = ""
	if me.get("eliminated",false) and not _suspense(): _detail.text = "Você foi eliminado · acompanhando como espectador."
	elif me.is_empty(): _detail.text = "Espectador · aguarde a próxima partida."
func _render_event() -> void:
	var events: Array = _data.get("events",[])
	if events.is_empty(): return
	var event: Dictionary = events.back()
	if event.kind == "pick":
		_instruction.text = "Carta eliminada!" if event.revealed else "Revelando…"
		_detail.text = "%s escolheu %s" % [_player(_data,str(event.actor)).get("nickname","Jogador"),_name(str(event.card_id))]
		if event.revealed:
			var hits: Array = event.hits if event.hits is Array else []
			if _last_event != str(event.seq):
				_notice.text = "Ninguém foi atingido." if hits.is_empty() else "%d jogador(es) atingido(s)." % hits.size()
				_notice_ttl = 3.5
				_last_event = str(event.seq)
	else:
		_instruction.text = "Tempo esgotado" if event.kind == "timeout" else "Jogador eliminado"
		_detail.text = str(_player(_data,str(event.actor)).get("nickname","Jogador"))
func _render_players() -> void:
	PlayerUI.clear(_roster)
	var players: Array = _data.get("players",[]).duplicate()
	var mine := players.find_custom(func(player: Dictionary) -> bool: return player.get("is_you",false))
	if mine >= 0:
		var local: Dictionary = players.pop_at(mine)
		players.insert(floori(players.size()/2.0),local)
	_roster.columns = maxi(players.size(),1) if players.size() <= 5 else ceili(players.size()/(2.0 if players.size() <= 12 else 3.0))
	_roster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if players.size() <= 3 else Control.SIZE_EXPAND_FILL
	_roster.custom_minimum_size.y = 64 if players.size() <= 5 else (76 if players.size() <= 12 else 114)
	var winners: Array = (_data.result if _data.get("result") is Dictionary else {}).get("winners",[])
	for source: Dictionary in players:
		var player := source.duplicate(true)
		var uncertain := false
		if _suspense():
			if _last_player_states.has(player.member_id):
				for key in ["lives","faults","eliminated","reason"]: player[key] = _last_player_states[player.member_id].get(key,player.get(key))
			else: uncertain = true
		else: _last_player_states[player.member_id] = player.duplicate(true)
		var turn: bool = str(player.member_id) == str(_data.get("turn_member","")) and _data.phase in ["turns","reveal"] and not _closed() and not player.eliminated
		var winner: bool = winners.has(player.member_id) and _data.phase == "finished"
		var panel := Surface.new()
		panel.padding = 3
		panel.variant = "player"
		panel.active = (turn or winner) and not player.eliminated
		panel.name = "Player_" + str(player.member_id)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if players.size() <= 3:
			# Grupo centralizado; o jogador da vez fica mais alto que os demais.
			panel.size_flags_horizontal = Control.SIZE_FILL
			panel.custom_minimum_size = Vector2(minf(_main.size.x/maxf(players.size(),3)-8,230), 64 if panel.active else 54)
			panel.size_flags_vertical = Control.SIZE_SHRINK_END
		_roster.add_child(panel)
		var row := PlayerUI.row(panel)
		row.add_theme_constant_override("separation",3)
		var portrait := PlayerUI.portrait(str(player.skin_id),46 if players.size() <= 3 else (32 if players.size() <= 5 else 20))
		if players.size() <= 5:
			# Wider upper-bust crop from the packaged 720px portrait, preserving aspect.
			# This increases the face size inside the same top strip, without a new layout.
			var portrait_source: Texture2D = portrait.texture
			var width := 84.0 if players.size() <= 3 else 50.0
			var height := 56.0 if players.size() <= 3 else 40.0
			var crop := AtlasTexture.new()
			crop.atlas = portrait_source
			crop.region = Rect2(0,0,portrait_source.get_width(),portrait_source.get_height()*0.88)
			portrait.texture = crop
			portrait.custom_minimum_size = Vector2(width,height)
			portrait.pivot_offset = Vector2(width*0.5,height)
			# O retrato "sai" do cartão; o jogador da vez se destaca mais.
			portrait.scale = Vector2.ONE*(1.24 if turn or winner else 1.1)
		var grading := ShaderMaterial.new()
		grading.shader = preload("res://scripts/ui/battle/battle_illustration.gdshader")
		grading.set_shader_parameter("saturation",0.0 if player.eliminated else 1.04)
		portrait.material = grading
		portrait.name = "Portrait"
		row.add_child(portrait)
		var info := PlayerUI.column(row)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_constant_override("separation",0)
		var nickname := Style.label(str(player.nickname),16 if players.size() <= 3 else (14 if players.size() <= 5 else 10),PlayerUI.GOLD if turn else PlayerUI.TEXT)
		Style.strong(nickname)
		nickname.text = str(player.nickname)
		nickname.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		nickname.autowrap_mode = TextServer.AUTOWRAP_OFF
		nickname.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nickname.clip_text = true
		nickname.tooltip_text = str(player.nickname)
		info.add_child(nickname)
		var hearts := PlayerUI.row(info)
		hearts.add_theme_constant_override("separation",2)
		for index in range(0 if uncertain else (int(player.lives) if players.size() <= 3 else 1)):
			var heart := TextureRect.new()
			heart.texture = Icons.heart(18,true)
			heart.custom_minimum_size = Vector2(16,16) if players.size() <= 3 else Vector2(10,10)
			heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hearts.add_child(heart)
		if players.size() > 3 and not uncertain: hearts.add_child(Style.label(str(player.lives),10))
		if uncertain: info.add_child(Style.label("REVELANDO…",9,PlayerUI.MUTED))
		elif player.eliminated:
			nickname.add_theme_color_override("font_color",PlayerUI.MUTED)
			portrait.modulate = Color("#555967")
			info.add_child(Style.label("ELIMINADO",9,PlayerUI.MUTED))
		elif winner: info.add_child(Style.label("VITÓRIA",10,PlayerUI.GOLD))
		elif turn and players.size() <= 5:
			var badge := PlayerUI.pill("NA VEZ","equipped")
			badge.name = "TurnBadge"
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			info.add_child(badge)
		elif _data.phase == "selection" and player.confirmed: info.add_child(Style.label("PRONTO",9,PlayerUI.GOLD))
		var previous := int(_last_lives.get(player.member_id,player.lives))
		if int(player.lives) < previous:
			portrait.modulate = Color("#ff766b")
			portrait.pivot_offset = portrait.custom_minimum_size*0.5
			var resting_scale := portrait.scale
			portrait.scale = resting_scale*1.06
			portrait.create_tween().tween_property(portrait,"scale",resting_scale,0.2)
			var reaction := portrait.create_tween()
			reaction.tween_property(portrait,"modulate",Color("#555967") if player.eliminated else Color.WHITE,0.45)
		if not uncertain: _last_lives[player.member_id] = int(player.lives)
func _render_public(me: Dictionary) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var focus_id := str(focus.get("id")) if focus != null and focus.get_parent() == _grid else ""
	PlayerUI.clear(_grid)
	var phase := str(_data.phase)
	var choosing: bool = not _closed() and phase == "selection" and not me.is_empty() and not me.get("confirmed",false) and not me.get("eliminated",false)
	for item: Dictionary in _data.pool:
		var id := str(item.card_id)
		var out := bool(item.removed)
		var card := Card.new()
		card.setup(id,(_data.phase == "selection" and _chosen.has(id)) or id == _pending_pick,out,choosing or (_is_my_turn() and not out))
		card.activated.connect(func() -> void: _activate(id))
		_grid.add_child(card)
		if id == focus_id: _focus_card.call_deferred(card)
	_fit_cards.call_deferred()
func _activate(id: String) -> void:
	var me := _me(_data)
	if _data.phase == "selection" and not me.is_empty() and not me.confirmed and not me.eliminated:
		if _chosen.has(id): _chosen.erase(id)
		elif _chosen.size() < int(_data.cards_per_player): _chosen.append(id)
		_render_instruction(me)
		_render_public(me)
	elif _is_my_turn(): _confirm_pick(id)
func _commit_selection() -> void:
	if not _pending_pick.is_empty():
		var id := _pending_pick
		_pending_pick = ""
		_confirm.disabled = true
		await act.call(duel.pick.bind(id))
		return
	var picked := _chosen.duplicate()
	_confirm.disabled = true
	await act.call(duel.select_cards.bind(picked))
	_chosen.clear()
func _confirm_pick(id: String) -> void:
	if not _is_my_turn(): return
	var item: Array = _data.pool.filter(func(card: Dictionary) -> bool: return str(card.card_id) == id and not card.removed)
	if item.is_empty(): return
	_pending_pick = id
	_render_instruction(_me(_data))
	_render_public(_me(_data))
func _close_overlay() -> void:
	_pending_pick = ""
	if _built and not _data.is_empty():
		_render_instruction(_me(_data))
		_render_public(_me(_data))
func _render_hand() -> void:
	var entries: Array = _data.get("my_cards",[])
	if _suspense(): entries = _hand_before_reveal
	else: _hand_before_reveal = entries.duplicate(true)
	var signature := JSON.stringify(entries)+str(_private_shown)
	if signature == _private_signature: return
	_private_signature = signature
	var grid: GridContainer = _hand.get_node("PrivateCards")
	PlayerUI.clear(grid)
	grid.columns = mini(maxi(entries.size(),1),3) if _private_shown else 1
	_hand_toggle.icon = load("res://assets/ui/battle/eye_off.svg" if _private_shown else "res://assets/ui/battle/eye.svg")
	_hand_toggle.text = ("Ocultar cartas" if _private_shown else "Mostrar cartas") + " · %d" % entries.size()
	_hand_toggle.disabled = entries.is_empty()
	if _private_shown:
		for entry: Dictionary in entries:
			var image := TextureRect.new()
			image.name = "Private_" + str(entry.card_id).get_file()
			image.texture = DuelService.card_texture(str(entry.card_id))
			image.tooltip_text = _name(str(entry.card_id))
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			image.custom_minimum_size.y = (60 if _canvas.size.y >= 360 else 44) if entries.size() <= 3 else 25
			if entry.get("lost",false): image.modulate = Color("#555967")
			grid.add_child(image)
	else:
		if entries.is_empty():
			var hidden := Style.label("Seleção em andamento",11,PlayerUI.MUTED)
			hidden.name = "HiddenHand"
			hidden.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hidden.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			grid.add_child(hidden)
		else:
			# Leque com uma carta virada por carta na mão (não parece mais uma só).
			var hidden := HBoxContainer.new()
			hidden.name = "HiddenHand"
			hidden.alignment = BoxContainer.ALIGNMENT_CENTER
			hidden.add_theme_constant_override("separation",-10 if entries.size() > 3 else -4)
			hidden.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hidden.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for index in range(entries.size()):
				var back := TextureRect.new()
				back.texture = preload("res://assets/ui/battle/private_back.svg")
				back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				back.custom_minimum_size = Vector2(30 if entries.size() > 3 else 36,44)
				back.pivot_offset = Vector2(15,44)
				back.rotation_degrees = (index-(entries.size()-1)*0.5)*6.0
				back.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if entries[index].get("lost",false): back.modulate = Color("#555967")
				hidden.add_child(back)
			grid.add_child(hidden)
func _layout() -> void:
	if not _built or size.x <= 0 or size.y <= 0: return
	var factor := clampf(size.y/440.0,1,1.8)
	_canvas.scale = Vector2.ONE * factor
	_canvas.size = size/factor
	var width := _canvas.size.x
	var side_width := 186.0 if width >= 760 else 166.0
	_main.position = Vector2.ZERO
	_main.size = Vector2(width-side_width-10,_canvas.size.y)
	_side.position = Vector2(width-side_width,0)
	_side.size = Vector2(side_width,_canvas.size.y)
	if is_instance_valid(_notice):
		_notice.reset_size()
		_notice.position = Vector2(_main.size.x-_notice.size.x-14,_canvas.size.y-_notice.size.y-10)
	_fit_cards.call_deferred()
func _fit_cards() -> void:
	if not is_instance_valid(_grid) or _grid.size.x <= 0 or _grid.size.y <= 0: return
	var count := _grid.get_child_count()
	if count == 0: return
	var columns := 3 if count <= 9 else ceili(sqrt(count*1.2))
	_grid.columns = mini(columns,count)
	var rows := ceili(float(count)/_grid.columns)
	var side_width := 186.0 if _canvas.size.x >= 760 else 166.0
	var main_width := _canvas.size.x-side_width-10
	var instruction_row := _board_content.get_child(0) as Control
	# Folgas reais do tabuleiro (padding da moldura e espaço entre cartas), não constantes soltas.
	var gap := float(_grid.get_theme_constant("h_separation"))
	var frame := float(_board.padding*2)
	var available_height := _canvas.size.y - 30 - _roster.get_combined_minimum_size().y - 6 - frame - instruction_row.get_combined_minimum_size().y - 5
	var width := floorf((main_width-frame-(_grid.columns-1)*gap)/_grid.columns)
	var height := floorf((available_height-(rows-1)*gap)/rows)
	for card: Control in _grid.get_children():
		card.custom_minimum_size = Vector2(maxf(width,1),maxf(height,1))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.set_deferred("size",Vector2(main_width,_canvas.size.y))
func _is_my_turn() -> bool:
	var me := _me(_data)
	return not _closed() and _data.get("phase","") == "turns" and not me.is_empty() and not me.get("eliminated",false) and str(_data.get("turn_member","")) == str(me.member_id)
func _me(data: Dictionary) -> Dictionary:
	for player: Dictionary in data.get("players",[]):
		if player.get("is_you",false): return player
	return {}
func _player(data: Dictionary, id: String) -> Dictionary:
	for player: Dictionary in data.get("players",[]):
		if str(player.member_id) == id: return player
	return {}
func _name(id: String) -> String: return DuelService.card_name(id)

func _suspense() -> bool:
	var events: Array = _data.get("events",[])
	return _data.get("phase","") == "reveal" and not events.is_empty() and not bool(events.back().get("revealed",true))

func _closed() -> bool:
	return str(duel.room.get("room",{}).get("status","")) == "closed"

func _back() -> void:
	if _closed(): overlay_parent.call("_leave_room")
	else: overlay_parent.emit_signal("back_requested")

func _focus_card(card: Control) -> void:
	if is_instance_valid(card) and card.is_inside_tree() and card.is_visible_in_tree() and card.focus_mode != Control.FOCUS_NONE: card.grab_focus()

func _conceal_hand() -> void:
	_private_shown = false
	_private_signature = ""
	if _built and is_inside_tree() and not _data.is_empty(): _render_hand()
