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
var _presentation: Control
var _order_shown := ""
var _result_shown := ""
var _submitting := false
var _reveal_playing := false
var _prepared_match := ""
var _chosen: Array = []
var _canvas: Control
var _main: VBoxContainer
var _side: VBoxContainer
var _roster_frame: ScrollContainer
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
var _public_before_reveal: Array = []
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
	# Mesmo que os Containers mantenham o tamanho mínimo anterior ao resize,
	# reavaliar o tabuleiro quando o viewport real mudar (Web/Android).
	get_viewport().size_changed.connect(func() -> void: _layout.call_deferred())
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
	# This canvas already scales against the iPhone's virtual height (480).
	# Applying the global font floor here would enlarge those fonts a second time.
	if UIScale.is_iphone(): _canvas.set_meta("qse_no_font_floor", true)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_main = VBoxContainer.new()
	_main.name = "PublicArea"
	_main.add_theme_constant_override("separation",3)
	_canvas.add_child(_main)
	var header := PlayerUI.row(_main)
	header.name = "BattleHeader"
	header.custom_minimum_size.y = 40
	header.add_theme_constant_override("separation",12)
	var back := Style.action("Voltar",func() -> void: _back(),"back")
	back.name = "BattleBack"
	# Mesmo "Voltar" das outras telas (cor, seta, estilo); tamanho no espaço da batalha.
	PlayerUI.standard_back(back, "Voltar")
	back.custom_minimum_size = Vector2(108,40)
	back.add_theme_font_size_override("font_size",17)
	header.add_child(back)
	var title := Style.label("Batalha · Partida local" if duel.is_local() else "Batalha",22)
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
	_roster_frame = ScrollContainer.new()
	_roster_frame.name = "PlayersScroll"
	_roster_frame.custom_minimum_size.y = 92
	_roster_frame.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roster_frame.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_main.add_child(_roster_frame)
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_frame.add_child(_roster)
	_board = Surface.new()
	_board.name = "BattleBoard"
	_board.variant = "board"
	_board.padding = 7
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_PASS
	_main.add_child(_board)
	_board_content = PlayerUI.column(_board)
	_board_content.add_theme_constant_override("separation",5)
	var instruction_row := PlayerUI.row(_board_content)
	instruction_row.add_theme_constant_override("separation",5)
	var message := PlayerUI.column(instruction_row)
	message.add_theme_constant_override("separation",0)
	_instruction = Style.label("",20,PlayerUI.GOLD)
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
	if UIScale.is_iphone():
		_confirm.add_theme_font_size_override("font_size", 16)
		_confirm.custom_minimum_size.y = 36
	actions.add_child(_confirm)
	_cancel = Style.action("Cancelar",_close_overlay)
	_cancel.name = "CancelPick"
	actions.add_child(_cancel)
	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",5)
	_grid.add_theme_constant_override("v_separation",5)
	_grid.resized.connect(_fit_cards)
	if UIScale.is_iphone():
		# iPhone: cartas em retrato e grandes (arte quase inteira, nome legível); o tabuleiro
		# rola na vertical em vez de espremer todas as cartas numa tela de ~350 pt.
		_board_scroll = ScrollContainer.new()
		_board_scroll.name = "BoardScroll"
		_board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_board_content.add_child(_board_scroll)
		_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_board_scroll.add_child(_grid)
		_board_scroll.resized.connect(_fit_cards)
	else:
		_board_content.add_child(_grid)
	_side = VBoxContainer.new()
	_side.name = "UtilityRail"
	_side.add_theme_constant_override("separation",5)
	if UIScale.is_iphone():
		# iPhone: a coluna da direita rola (tela baixa); nada fica escondido embaixo.
		_side_scroll = ScrollContainer.new()
		_side_scroll.name = "UtilityRailScroll"
		_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		_canvas.add_child(_side_scroll)
		_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_side_scroll.add_child(_side)
	else:
		_canvas.add_child(_side)
	_build_sidebar()
func _build_sidebar() -> void:
	var controls := PlayerUI.row(_side)
	controls.name = "RoomControls"
	controls.add_theme_constant_override("separation",4)
	var timer_box := PanelContainer.new()
	timer_box.add_theme_stylebox_override("panel",Style.panel(4))
	timer_box.custom_minimum_size = Vector2(68,40)
	timer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(timer_box)
	var timer_row := PlayerUI.row(timer_box)
	timer_row.add_theme_constant_override("separation",4)
	var hourglass := TextureRect.new()
	hourglass.texture = load("res://assets/ui/battle/time.svg")
	hourglass.modulate = PlayerUI.GOLD
	hourglass.custom_minimum_size = Vector2(24,24)
	hourglass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hourglass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	timer_row.add_child(hourglass)
	_timer = Style.label("",19)
	_timer.name = "RoundTimer"
	Style.strong(_timer)
	_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_row.add_child(_timer)
	var settings := Style.action("",func() -> void: overlay_parent.emit_signal("navigate_requested","settings",{}))
	settings.name = "BattleSettings"
	settings.icon = load("res://assets/ui/battle/settings.svg")
	settings.tooltip_text = "Configurações · a rodada continua"
	settings.custom_minimum_size = Vector2(40,40)
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
		room_text.add_child(Style.label("Código da sala",13,PlayerUI.MUTED))
		var code_label := Style.label(code,20)
		Style.strong(code_label)
		code_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		room_text.add_child(code_label)
		var copy := Style.action("",func() -> void:
			DisplayServer.clipboard_set(code)
			_notice.text = "Código copiado"
			_notice_ttl = 3.5,"copy")
		copy.name = "CopyRoomCode"
		copy.tooltip_text = "Copiar código da sala"
		copy.custom_minimum_size = Vector2(40,40)
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		room_row.add_child(copy)
		# Convite por link: só o ADM gera (o servidor recusa os outros).
		if duel.is_admin():
			var share := Style.action("",_share_invite,"share")
			share.name = "ShareInvite"
			share.tooltip_text = "Compartilhar convite"
			share.custom_minimum_size = Vector2(40,40)
			share.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			room_row.add_child(share)
	else:
		room_text.add_child(Style.label("Partida local",16,PlayerUI.GOLD))
		room_text.add_child(Style.label("Só neste aparelho · sem convite",12,PlayerUI.MUTED))
	var voice := preload("res://scripts/ui/battle/battle_voice.gd").new()
	voice.name = "BattleVoice"
	voice.setup(overlay_parent.get("services") as PlayerServices)
	voice.visible = not duel.is_local()
	_side.add_child(voice)
	var chat := ChatPanel.new()
	chat.name = "BattleChat"
	chat.setup(overlay_parent.get("services") as PlayerServices)
	chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(chat)
	# Decisão do dono: o chat aparece também na partida local.
	chat.visible = true
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
	var hand_title := Style.label("Suas cartas",17,PlayerUI.TITLE_GOLD)
	Style.strong(hand_title)
	hand_header.add_child(hand_title)
	var private_body := GridContainer.new()
	private_body.name = "PrivateCards"
	private_body.custom_minimum_size.y = 40
	private_body.add_theme_constant_override("h_separation",3)
	private_body.add_theme_constant_override("v_separation",3)
	var private_scroll := ScrollContainer.new()
	private_scroll.name = "PrivateCardsScroll"
	private_scroll.custom_minimum_size.y = 100
	private_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	private_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hand.add_child(private_scroll)
	private_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	private_scroll.add_child(private_body)
	_hand_toggle = Style.action("Mostrar",func() -> void:
		_private_shown = not _private_shown
		_private_signature = ""
		_render_hand(),"eye")
	_hand_toggle.name = "TogglePrivateCards"
	_hand_toggle.custom_minimum_size.y = 40
	_hand_toggle.add_theme_font_size_override("font_size",16)
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
	leave.custom_minimum_size.y = 38
	leave.add_theme_font_size_override("font_size",15)
	if UIScale.is_iphone():
		# iPhone: a coluna é baixa; "Sair" vai para a linha do tempo/ajustes e libera espaço
		# para voz, chat e "Suas cartas" caberem inteiros.
		leave.text = "Sair"
		leave.custom_minimum_size = Vector2(0, 40)
		_side.get_node("RoomControls").add_child(leave)
	else:
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
	if _prepared_match != str(_data.get("id","")):
		_prepared_match=str(_data.get("id",""))
		_last_event=""
		_reveal_playing=false
		_public_before_reveal.clear()
		_hand_before_reveal.clear()
		_last_player_states.clear()
		_last_lives.clear()
		_players_signature = ""
		_public_signature = ""
		_turn_pulse = ""
		CharacterSlot.prepare_participants(_data.get("players",[]))
	var available_ids: Array = _data.pool.map(func(card: Dictionary) -> String: return str(card.card_id))
	_chosen = _chosen.filter(func(id: String) -> bool: return available_ids.has(id))
	var me := _me(_data)
	if _data.phase != "selection": _chosen.clear()
	if _data.phase != "turns" or not _is_my_turn(): _pending_pick = ""
	var events: Array=_data.get("events",[])
	var pending_reveal: bool=not events.is_empty() and events.back().get("kind","")=="pick" and events.back().get("revealed",false) and _last_event!=str(events.back().seq)
	if pending_reveal: _reveal_playing=true
	_render_players()
	_render_instruction(me)
	if pending_reveal and _data.phase != "reveal": _render_event()
	_render_public(me)
	_render_hand()
	_maybe_present()
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
		_instruction.text = str(TranslationServer.translate("Começa em %d")) % maxi(seconds,1)
	CharacterSlot.collect_prepared()
	_poll_reveal(_delta)
var _reveal_wait := 0.0
var _reveal_seq := ""
var _reveal_polling := false


## Durante o suspense a carta ainda não foi revelada nos dados guardados; ninguém avisa quando
## o servidor revela. Depois de ~2,5 s (e a cada 0,5 s) pede os dados de novo para a revelação
## animada (carta + atingidos + sons) disparar na hora certa.
func _poll_reveal(delta: float) -> void:
	if not _suspense():
		_reveal_seq = ""
		return
	var events: Array = _data.get("events",[])
	var seq := str(events.back().get("seq",""))
	if seq != _reveal_seq:
		_reveal_seq = seq
		_reveal_wait = 0.0
	_reveal_wait += delta
	if _reveal_wait < 2.3 or _reveal_polling: return
	_reveal_wait = 1.8
	_reveal_polling = true
	await duel.refresh()
	_reveal_polling = false
	if is_inside_tree(): refresh()


func _play_sequence(rows: Array,clip: String,duration: float,numbered := false) -> void:
	if is_instance_valid(_presentation): _presentation.queue_free()
	_presentation=preload("res://scripts/ui/battle/avatar_sequence.gd").new()
	add_child(_presentation)
	_presentation.set_meta("phase",str(_data.get("phase","")))
	_presentation.set_meta("match_id",str(_data.get("id","")))
	var current := _presentation
	var match_id := str(_data.get("id",""))
	var sequence_phase := str(_data.get("phase",""))
	_presentation.finished.connect(func() -> void:
		if _presentation==current: _presentation=null
		if duel.is_local(): duel.local_server.finish_presentation(match_id,sequence_phase)
		if is_instance_valid(overlay_parent): overlay_parent.render.call_deferred())
	# Online a contagem é do servidor: reparte o tempo que existe entre todos os jogadores.
	if not duel.is_local() and sequence_phase == "countdown":
		_presentation.time_budget = maxf(duel.seconds_left() - 0.3, 1.0)
	_presentation.present(rows,clip,duration,numbered)
func _maybe_present() -> void:
	if is_instance_valid(_presentation):
		var sequence_phase := str(_presentation.get_meta("phase",""))
		var obsolete := str(_presentation.get_meta("match_id","")) != str(_data.get("id",""))
		if obsolete or (sequence_phase in ["countdown","finished"] and _data.get("phase","") != sequence_phase):
			_presentation.queue_free()
			_presentation=null
	var key := str(_data.get("id",""))
	if _data.get("phase","")=="countdown" and _order_shown!=key:
		var order: Array=_data.get("turn_order",[])
		if order.is_empty(): return # Não inventar uma ordem diferente da autoridade online.
		_order_shown=key
		var rows: Array=[]
		for id in order:
			var row := _player(_data,str(id))
			if not row.is_empty(): rows.append(row)
		_play_sequence(rows,"anim_2",6.0,true)
	if _data.get("phase","")=="finished" and not _reveal_playing and not is_instance_valid(_presentation) and _result_shown!=key:
		_result_shown=key
		var rows: Array=[]
		var result: Dictionary=_data.get("result",{}) if _data.get("result") is Dictionary else {}
		var winners: Array = result.get("winners",[])
		for player: Dictionary in _data.get("players",[]):
			var row := player.duplicate(true)
			# Only authoritative winners receive victory; everyone else gets defeat.
			row.presentation_clip = "anim_4" if winners.has(player.member_id) else "anim_3"
			rows.append(row)
		if not rows.is_empty(): _play_sequence(rows,"anim_3",6.0)

func holding_results() -> bool:
	if not is_instance_valid(_presentation) or _presentation.get_meta("phase","") != "finished": return false
	var live := duel.match()
	# Preserve the final stage across the server's return to lobby, never a new match.
	return live.is_empty() or (str(live.get("id","")) == _prepared_match and live.get("phase","") == "finished")

## Texto do turno entra com um fade curto em vez de trocar de repente.
func _render_instruction(me: Dictionary) -> void:
	var before := _instruction.text
	_write_instruction(me)
	if _instruction.text != before and str(_data.get("phase","")) != "countdown":
		for label: Label in [_instruction,_detail]:
			label.modulate.a = 0.0
			label.create_tween().tween_property(label,"modulate:a",1.0,0.3)
func _write_instruction(me: Dictionary) -> void:
	_confirm.hide()
	_cancel.hide()
	if _submitting: return
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
			_detail.text = str(TranslationServer.translate("%d de %d selecionadas · escolha em segredo")) % [_chosen.size(),needed]
			_confirm.text = "Confirmar cartas"
			_confirm.visible = not me.is_empty() and not me.confirmed and not me.eliminated
			_confirm.disabled = _chosen.size() != needed
			if me.get("confirmed",false): _detail.text = "PRONTO! Aguardando os outros jogadores."
		"countdown":
			_instruction.text = "A partida vai começar!"
			_detail.text = "Suas cartas permanecem privadas."
		"turns":
			_instruction.text = "É a sua vez!" if _is_my_turn() else str(TranslationServer.translate("Vez de %s")) % str(turn.get("nickname","…"))
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
			if _reveal_playing:
				_instruction.text="Revelando resultado…"
				return
			var winners: Array = (_data.result if _data.get("result") is Dictionary else {}).get("winners",[])
			_instruction.text = str(TranslationServer.translate("Vitória de %s!")) % str(_player(_data,str(winners[0])).get("nickname","")) if winners.size() == 1 else "Empate!"
			_detail.text = "Voltando ao lobby da sala…"
		_:
			_instruction.text = "Batalha"
			_detail.text = ""
	if me.get("eliminated",false) and not (_suspense() or _reveal_playing): _detail.text = "Você foi eliminado · acompanhando como espectador."
	elif me.is_empty(): _detail.text = "Espectador · aguarde a próxima partida."
func _render_event() -> void:
	var events: Array = _data.get("events",[])
	if events.is_empty(): return
	var event: Dictionary = events.back()
	if event.kind == "pick":
		_instruction.text = "Carta eliminada!" if event.revealed and not _reveal_playing else "Revelando…"
		_detail.text = ("%s escolheu %s" % [_player(_data,str(event.actor)).get("nickname","Jogador"),_name(str(event.card_id))]) if event.revealed and not _reveal_playing else "%s está revelando uma carta…" % _player(_data,str(event.actor)).get("nickname","Jogador")
		if event.revealed:
			var hits: Array = event.hits if event.hits is Array else []
			if _last_event != str(event.seq):
				_last_event = str(event.seq)
				_show_reveal(str(event.card_id), hits)
	elif event.kind in ["timeout","eliminated"]:
		_instruction.text = "Tempo esgotado" if event.kind == "timeout" else "Jogador eliminado"
		_detail.text = str(_player(_data,str(event.actor)).get("nickname","Jogador"))
		if _last_event!=str(event.seq):
			_last_event=str(event.seq)
			# Defeat is presented at match end, keeping the next live turn unobstructed.
## Revelação animada no meio da tela: carta escolhida + jogadores atingidos (✕ / caveira).
func _show_reveal(card_id: String, hits: Array) -> void:
	var old := get_node_or_null("RevealOverlay")
	if old != null: old.queue_free()
	var rows: Array = []
	var hit_ids := {}
	for hit: Dictionary in hits:
		var member := str(hit.get("member_id",""))
		hit_ids[member] = true
		var player := _player(_data,member)
		rows.append({"name": str(player.get("nickname","Jogador")), "skin": str(player.get("skin_id","")), "eliminated": bool(hit.get("eliminated",false))})
	# Não atingidos: participantes ainda na partida que não foram atingidos (dados reais).
	var spared: Array = []
	for player: Dictionary in _data.get("players",[]):
		if not hit_ids.has(str(player.member_id)) and not bool(player.get("eliminated",false)):
			spared.append(str(player.get("nickname","Jogador")))
	var events: Array = _data.get("events",[])
	var actor := str(_player(_data,str(events.back().get("actor","")) if not events.is_empty() else "").get("nickname","Jogador"))
	# Camada própria sobre a tela inteira (fora do tabuleiro escalado): o painel mede a tela real.
	var layer := CanvasLayer.new()
	layer.name = "RevealOverlay"
	layer.layer = 50
	add_child(layer)
	var overlay := RevealOverlay.new()
	var local := duel.is_local()
	var match_id := str(_data.get("id",""))
	var seq := str(events.back().get("seq","")) if not events.is_empty() else ""
	# Local: o resultado fica mais tempo na tela e o próximo turno só começa depois dele.
	if local: overlay.pace = 1.3
	layer.add_child(overlay)
	overlay.tree_exited.connect(func() -> void:
		if local and is_instance_valid(duel) and is_instance_valid(duel.local_server): duel.local_server.finish_reveal(match_id,seq)
		_reveal_playing=false
		if is_instance_valid(layer): layer.queue_free()
		if is_inside_tree(): refresh.call_deferred())
	overlay.present(card_id, _name(card_id), actor, rows, spared)


var _players_signature := ""
var _public_signature := ""
var _turn_pulse := ""
func _render_players() -> void:
	var players: Array = _data.get("players",[]).duplicate()
	# Só reconstrói a faixa quando algo visível mudou: sem piscar a cada sinal do servidor.
	var players_signature := JSON.stringify([players,_data.get("turn_member",""),_data.get("phase",""),_data.get("result"),_closed(),_suspense() or _reveal_playing])
	if players_signature == _players_signature and _roster.get_child_count() > 0: return
	_players_signature = players_signature
	PlayerUI.clear(_roster)
	var mine := players.find_custom(func(player: Dictionary) -> bool: return player.get("is_you",false))
	if mine >= 0:
		var local: Dictionary = players.pop_at(mine)
		players.insert(floori(players.size()/2.0),local)
	_roster.columns = maxi(players.size(),1) if players.size() <= 5 else ceili(players.size()/(2.0 if players.size() <= 12 else 3.0))
	# iPhone: no máximo 4 jogadores por linha (5 acima de 12) para os nomes caberem inteiros;
	# o tabuleiro rola, então as linhas extras não espremem as cartas.
	if UIScale.is_iphone() and players.size() > 3:
		_roster.columns = 3
	_roster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if players.size() <= 3 else Control.SIZE_EXPAND_FILL
	# T24 iOS: linhas um pouco mais altas para retrato/nome/vidas legíveis (largura já sobrava).
	_roster.custom_minimum_size.y = 57 if players.size() <= 5 else (80 if players.size() <= 12 else 99)
	var winners: Array = (_data.result if _data.get("result") is Dictionary else {}).get("winners",[])
	for source: Dictionary in players:
		var player := source.duplicate(true)
		var uncertain := false
		if _suspense() or _reveal_playing:
			if _last_player_states.has(player.member_id):
				for key in ["lives","faults","eliminated","reason"]: player[key] = _last_player_states[player.member_id].get(key,player.get(key))
			else: uncertain = true
		else: _last_player_states[player.member_id] = player.duplicate(true)
		var turn: bool = str(player.member_id) == str(_data.get("turn_member","")) and _data.phase in ["turns","reveal"] and not _closed() and not player.eliminated
		var winner: bool = winners.has(player.member_id) and _data.phase == "finished" and not _reveal_playing
		var panel := Surface.new()
		panel.padding = 3 if players.size() <= 5 else 1
		panel.variant = "player"
		panel.active = (turn or winner) and not player.eliminated
		panel.name = "Player_" + str(player.member_id)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if turn and _turn_pulse != str(player.member_id):
			# A vez passa com um acender suave do novo jogador.
			_turn_pulse = str(player.member_id)
			panel.modulate = Color(1,1,1,0.4)
			panel.create_tween().tween_property(panel,"modulate",Color.WHITE,0.4)
		if players.size() <= 3:
			# Grupo centralizado; o jogador da vez fica mais alto que os demais.
			panel.size_flags_horizontal = Control.SIZE_FILL
			panel.custom_minimum_size = Vector2(minf(_main.size.x/maxf(players.size(),3)-8,230), 76)
			panel.size_flags_vertical = Control.SIZE_FILL
		_roster.add_child(panel)
		var row := PlayerUI.row(panel)
		row.add_theme_constant_override("separation",3)
		var portrait := PlayerUI.portrait(str(player.skin_id),46 if players.size() <= 3 else (32 if players.size() <= 5 else (36 if players.size() <= 12 else 28)))
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
		elif portrait.texture != null:
			# T24 iOS: 6–20 jogadores — recorte do busto (rosto maior) no mesmo espaço da linha.
			var bust := AtlasTexture.new()
			var full: Texture2D = portrait.texture
			bust.atlas = full
			bust.region = Rect2(full.get_width()*0.14,0,full.get_width()*0.72,full.get_height()*0.58)
			portrait.texture = bust
			var side := 36.0 if players.size() <= 12 else 28.0
			portrait.custom_minimum_size = Vector2(side*1.15,side)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			portrait.clip_contents = true
		var grading := ShaderMaterial.new()
		grading.shader = preload("res://scripts/ui/battle/battle_illustration.gdshader")
		grading.set_shader_parameter("saturation",0.0 if player.eliminated else 1.04)
		portrait.material = grading
		portrait.name = "Portrait"
		row.add_child(portrait)
		var info := PlayerUI.column(row)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_constant_override("separation",0)
		var nickname := Style.label(str(player.nickname),19 if players.size() <= 3 else (17 if players.size() <= 5 else (15 if players.size() <= 12 else 13)),PlayerUI.GOLD if turn else PlayerUI.TEXT)
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
			heart.custom_minimum_size = Vector2(18,18) if players.size() <= 3 else (Vector2(15,15) if players.size() <= 5 else (Vector2(16,16) if players.size() <= 12 else Vector2(14,14)))
			heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hearts.add_child(heart)
		if players.size() > 3 and not uncertain:
			var count := Style.label(str(player.lives),15 if players.size() <= 5 else (16 if players.size() <= 12 else 14),Color("#ff9a8f") if int(player.lives) <= 1 else PlayerUI.TEXT)
			count.name = "Lives"
			Style.strong(count)
			hearts.add_child(count)
		if uncertain: info.add_child(Style.label("REVELANDO…",9,PlayerUI.MUTED))
		elif player.eliminated:
			nickname.add_theme_color_override("font_color",PlayerUI.MUTED)
			portrait.modulate = Color("#555967")
			info.add_child(Style.label("ELIMINADO",9 if players.size() <= 5 else 11,PlayerUI.MUTED))
		elif winner: info.add_child(Style.label("VITÓRIA",10,PlayerUI.GOLD))
		elif turn and players.size() <= 5:
			var badge := PlayerUI.pill("NA VEZ","equipped")
			badge.name = "TurnBadge"
			badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			info.add_child(badge)
		elif _data.phase == "selection" and player.confirmed: info.add_child(Style.label("PRONTO",9 if players.size() <= 5 else 11,PlayerUI.GOLD))
		# Reserve the same status line for ready/turn/eliminated states.
		info.custom_minimum_size.y = 64 if players.size() <= 3 else 50
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
	var focus_action := ""
	if focus != null and str(focus.name) in ["AcceptSelection","RejectSelection"]:
		var owner_card := focus.get_parent().get_parent().get_parent()
		if owner_card.get_parent()==_grid:
			focus_id=str(owner_card.get("id"))
			focus_action=str(focus.name)
	var phase := str(_data.phase)
	var choosing: bool = not _closed() and phase == "selection" and not me.is_empty() and not me.get("confirmed",false) and not me.get("eliminated",false)
	var masking := _suspense() or _reveal_playing
	if not masking: _public_before_reveal=_data.pool.filter(func(c: Dictionary)->bool:return not c.removed).map(func(c: Dictionary)->String:return str(c.card_id))
	# Mesmas cartas e mesmo estado: mantém a mesa como está (sem redesenhar/piscar).
	var public_signature := JSON.stringify([phase,_data.pool,_public_before_reveal,_chosen,_pending_pick,choosing,_is_my_turn(),masking,_submitting,_data.get("cards_per_player",1)])
	if public_signature == _public_signature and _grid.get_child_count() > 0:
		_confirm.hide()
		_cancel.hide()
		return
	_public_signature = public_signature
	PlayerUI.clear(_grid)
	for item: Dictionary in _data.pool:
		var id := str(item.card_id)
		var out := bool(item.removed)
		if out and (not masking or not _public_before_reveal.has(id)): continue
		if out: out=false
		var card := Card.new()
		card.setup(id,(_data.phase == "selection" and _chosen.has(id)) or id == _pending_pick,out,choosing or (_is_my_turn() and not out))
		card.activated.connect(func() -> void: _activate(id))
		_grid.add_child(card)
		var selection: bool = choosing and not _chosen.is_empty() and _chosen.back()==id
		if not _submitting and (id==_pending_pick or selection):
			var cancel := _close_overlay if not selection else _activate.bind(id)
			var decision := PlayerUI.decision_controls(card,_commit_selection,cancel,"cartas" if selection else "eliminação")
			decision.find_child("AcceptSelection",true,false).disabled=selection and _chosen.size()!=int(_data.cards_per_player)
		if id == focus_id:
			var target: Control=card.find_child(focus_action,true,false) if not focus_action.is_empty() else card
			if target!=null: _focus_card.call_deferred(target)
	_confirm.hide()
	_cancel.hide()
	_fit_cards.call_deferred()
func _activate(id: String) -> void:
	if _submitting: return
	var me := _me(_data)
	if _data.phase == "selection" and not me.is_empty() and not me.confirmed and not me.eliminated:
		if _chosen.has(id): _chosen.erase(id)
		elif _chosen.size() < int(_data.cards_per_player): _chosen.append(id)
		_render_instruction(me)
		_render_public(me)
	elif _is_my_turn(): _confirm_pick(id)
func _commit_selection() -> void:
	if _submitting: return
	_submitting=true
	for button: Button in _grid.find_children("*Selection","Button",true,false): button.disabled=true
	if not _pending_pick.is_empty():
		var id := _pending_pick
		_pending_pick = ""
		_confirm.disabled = true
		await act.call(duel.pick.bind(id))
		_submitting=false
		refresh()
		return
	var picked := _chosen.duplicate()
	_confirm.disabled = true
	await act.call(duel.select_cards.bind(picked))
	_submitting=false
	_chosen.clear()
	refresh()
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
	if _suspense() or _reveal_playing: entries = _hand_before_reveal
	else: _hand_before_reveal = entries.duplicate(true)
	var signature := JSON.stringify(entries)+str(_private_shown)
	if signature == _private_signature: return
	_private_signature = signature
	var grid: GridContainer = _hand.get_node("PrivateCardsScroll/PrivateCards")
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
			# T24 iOS: altura pela largura real da coluna (proporção da carta), não um valor fixo.
			var column_width := (_hand.size.x - 12.0 - (grid.columns - 1) * 4.0) / maxf(grid.columns, 1)
			image.custom_minimum_size.y = clampf(column_width * 1.42, 44.0, 96.0) if entries.size() <= 3 else 34.0
			if entry.get("lost",false): image.modulate = Color("#555967")
			# Toque/clique amplia temporariamente (só nesta tela; ninguém mais vê).
			image.mouse_filter = Control.MOUSE_FILTER_STOP
			image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			image.set_meta("card_id",str(entry.card_id))
			image.tooltip_text = _name(str(entry.card_id)) + " — toque para ampliar"
			image.gui_input.connect(func(event: InputEvent) -> void:
				if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
					_preview_private(str(entry.card_id)))
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
func _utility_width(width: float) -> float:
	# iPhone: coluna lateral mais larga para as cartas escolhidas e o chat ficarem legíveis.
	if UIScale.is_iphone(): return 210.0
	if duel.is_local():
		return 176.0 if width >= 760 else 160.0
	return 200.0 if width >= 760 else 176.0

var _top_inset := -1.0
var _top_offset := 0.0
var _bottom_inset := 0.0


func _usable_height() -> float:
	return maxf(1.0,_canvas.size.y-_top_offset-_bottom_inset)


func _touch_bottom_inset() -> float:
	var top := _touch_top_inset()
	return top * 14.0 / 22.0


## Altura (px do viewport) da faixa de toque reservada pelo iOS no topo; 0 fora do iPhone Web.
func _touch_top_inset() -> float:
	if _top_inset >= 0.0: return _top_inset
	_top_inset = 0.0
	# Teste/captura: simula a faixa do iPhone fora do navegador (px do viewport).
	if OS.has_environment("QSE_TEST_TOP_INSET"):
		_top_inset = float(OS.get_environment("QSE_TEST_TOP_INSET"))
		return _top_inset
	# No iPhone a página (web/shell.html) já coloca o jogo dentro da área segura, com faixas
	# pretas no notch, no topo e na barrinha: a batalha não precisa de recuo próprio.
	return _top_inset


func _layout() -> void:
	if not _built or size.x <= 0 or size.y <= 0: return
	## Escalar a interface contra uma altura virtual maior deixa mais área para a arte.
	## Antes, em tela alta, roster/sidebar consumiam espaço ampliados 1.8×.
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var global_position := get_global_rect().position
	var global_scale := get_global_transform().get_scale()
	# Não permitir que o mínimo antigo do GridContainer desenhe além da tela
	# depois de um resize. Preservar 12px laterais e 8px inferiores.
	var allowed_width := maxf(1.0,(viewport_size.x-maxf(global_position.x,0.0)-12.0)/maxf(global_scale.x,0.01))
	var allowed_height := maxf(1.0,(viewport_size.y-maxf(global_position.y,0.0)-8.0)/maxf(global_scale.y,0.01))
	var available := Vector2(minf(size.x,allowed_width),minf(size.y,allowed_height))
	var factor := clampf(available.y/555.0,1.0,1.55)
	# iPhone: altura virtual 480 — botões e textos maiores para o dedo, sem estourar a tela
	# (370 deixava nomes, cartas e o painel lateral cortados).
	if UIScale.is_iphone(): factor = maxf(available.y / 480.0, 1.0)
	_canvas.scale = Vector2.ONE * factor
	_canvas.size = available/factor
	var width := _canvas.size.x
	var side_width := _utility_width(width)
	# iPhone: a faixa de cima da tela é do sistema (barra de status do app instalado / barra do
	# Safari em paisagem) e engole o toque; o topo da batalha começa logo abaixo dela.
	var unit := factor * maxf(global_scale.y,0.01)
	var inset := _touch_top_inset() / unit
	# Embaixo, a barrinha de início do iPhone cobre o conteúdo: mesma folga.
	_bottom_inset = _touch_bottom_inset() / unit
	_top_offset = inset
	_main.position = Vector2(0,inset)
	var target_main_width := width-side_width-20
	# Reduzir mínimos dos avatares ANTES de definir o novo tamanho do painel.
	# Caso contrário o próprio Container impede a janela de encolher.
	var player_count := _roster.get_child_count()
	if player_count > 0 and player_count <= 3:
		var roster_gap := float(_roster.get_theme_constant("h_separation"))
		var slot_width := maxf(48.0,floorf((target_main_width-(player_count-1)*roster_gap)/player_count)-2.0)
		for panel: Control in _roster.get_children():
			panel.custom_minimum_size.x = slot_width
	_main.size = Vector2(target_main_width,_usable_height())
	var rail: Control = _side_scroll if is_instance_valid(_side_scroll) else _side
	rail.position = Vector2(width-side_width,inset)
	rail.size = Vector2(side_width,_usable_height())
	if is_instance_valid(_notice):
		_notice.reset_size()
		_notice.position = Vector2(_main.size.x-_notice.size.x-14,_canvas.size.y-_bottom_inset-_notice.size.y-10)
	_fit_cards.call_deferred()
## Pick portrait slots against the original pool. Eliminations leave room rather than
## changing every remaining illustration's shape, size and location.
func _best_grid_columns(count: int, usable_width: float, usable_height: float, gap: float) -> int:
	var best := 1
	var best_height := 0.0
	for columns in range(1, mini(count, 12) + 1):
		var rows := ceili(float(count) / columns)
		var height := minf((usable_height - (rows - 1) * gap) / rows,
			((usable_width - (columns - 1) * gap) / columns) * 16.0 / 9.0)
		if height > best_height:
			best_height = height
			best = columns
	return best


var _board_scroll: ScrollContainer
var _side_scroll: ScrollContainer


## iPhone: colunas pela largura (cartas ~150 px de design), altura em retrato.
func _fit_cards_iphone() -> void:
	var width := _board_scroll.size.x - 10.0
	if width <= 0: return
	var gap := float(_grid.get_theme_constant("h_separation"))
	var columns := clampi(floori((width + gap) / (130.0 + gap)), 2, 8)
	_grid.columns = columns
	var cell_width := floorf((width - (columns - 1) * gap) / columns)
	for card: Control in _grid.get_children():
		card.custom_minimum_size = Vector2(cell_width, floorf(cell_width * 16.0 / 9.0))
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _fit_cards() -> void:
	if is_instance_valid(_board_scroll):
		_fit_cards_iphone()
		return
	if not is_instance_valid(_grid) or _grid.size.x <= 0 or _grid.size.y <= 0: return
	var count: int = _data.get("pool", []).size()
	if count == 0: return
	var side_width := _utility_width(_canvas.size.x)
	var main_width := _canvas.size.x-side_width-20
	var instruction_row := _board_content.get_child(0) as Control
	var gap := float(_grid.get_theme_constant("h_separation"))
	var frame := float(_board.padding*2)
	var header := _main.get_node("BattleHeader") as Control
	var header_height := maxf(header.custom_minimum_size.y,header.get_combined_minimum_size().y)
	var roster_height := _roster_frame.custom_minimum_size.y
	var available_height := maxf(1.0,_usable_height()-header_height-roster_height-6-frame-instruction_row.get_combined_minimum_size().y-5)
	var available_width := maxf(1.0,main_width-frame)
	_grid.columns = _best_grid_columns(count,available_width,available_height,gap)
	var rows := ceili(float(count)/_grid.columns)
	var slot_width := (available_width-(_grid.columns-1)*gap)/_grid.columns
	var slot_height := (available_height-(rows-1)*gap)/rows
	var cell_height := floorf(minf(slot_height, slot_width * 16.0 / 9.0))
	var cell_width := floorf(cell_height * 9.0 / 16.0)
	for card: Control in _grid.get_children():
		card.custom_minimum_size = Vector2(maxf(cell_width,1),maxf(cell_height,1))
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_main.set_deferred("size",Vector2(main_width,_usable_height()))
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

## Ampliação temporária das cartas privadas: sobreposição local, fecha com toque, Esc ou Voltar.
## Não muda o turno, não envia nada ao servidor e some se a janela perder o foco.
func _preview_private(card_id: String) -> void:
	_close_private_preview()
	var entries: Array = _data.get("my_cards",[])
	if entries.is_empty(): return
	var layer := Control.new()
	layer.name = "PrivatePreview"
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.01,0.02,0.04,0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation",10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Style.label("SUAS CARTAS · só você vê",16,PlayerUI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation",18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var height := clampf(size.y*0.58,140.0,560.0)
	for entry: Dictionary in entries:
		var card := VBoxContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		var image := TextureRect.new()
		image.name = "PreviewCard"
		image.texture = DuelService.card_texture(str(entry.card_id))
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.custom_minimum_size = Vector2(height/1.42,height)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(entry.card_id) != card_id: image.modulate = Color(0.78,0.78,0.82)
		if entry.get("lost",false): image.modulate = Color("#555967")
		card.add_child(image)
		var name_label := Style.label(_name(str(entry.card_id)),15,PlayerUI.GOLD if str(entry.card_id) == card_id else PlayerUI.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size.x = height/1.42
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(name_label)
	var close := Style.label("Toque em qualquer lugar para fechar",12,PlayerUI.MUTED)
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(close)
	layer.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_close_private_preview())


func _close_private_preview() -> void:
	var layer := get_node_or_null("PrivatePreview")
	if layer != null:
		remove_child(layer)
		layer.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if get_node_or_null("PrivatePreview") != null and event.is_action_pressed("ui_cancel"):
		_close_private_preview()
		get_viewport().set_input_as_handled()


func _conceal_hand() -> void:
	_close_private_preview()
	_private_shown = false
	_private_signature = ""
	if _built and is_inside_tree() and not _data.is_empty(): _render_hand()
