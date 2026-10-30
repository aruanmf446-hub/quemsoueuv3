extends VBoxContainer
## Partida do Duelo (etapa 2): seleção secreta, contagem regressiva, turnos, revelação com
## suspense e fim. Tudo vem do servidor (DuelService.match()); aqui só se mostra e se pede.
## O cronômetro anda localmente entre uma atualização e outra (relógio do servidor).

const Icons = preload("res://scripts/desert/t15d/resource_icons.gd")
const MUTED := Color("#c9d6e6")

var duel: DuelService
var inventory: InventoryService
## Executa uma ação do servidor com aviso de erro (a tela de Duelo fornece).
var act: Callable
## Camada por cima da tela para confirmações, revelação e campeão.
var overlay_parent: Control
var _chosen: Array = []
var _timer: Label
var _countdown: Label
var _overlay: Control
var _overlay_key := ""


func setup(p_duel: DuelService, p_inventory: InventoryService, p_overlay_parent: Control, p_act: Callable) -> void:
	duel = p_duel
	inventory = p_inventory
	overlay_parent = p_overlay_parent
	act = p_act
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8 if UIScale.is_compact() else 14)


func _exit_tree() -> void:
	_close_overlay()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_timer = null
	_countdown = null
	var data := duel.match()
	if data.is_empty():
		_close_overlay()
		return
	var me := _me(data)
	if not me.is_empty() and me.eliminated:
		var text := "Você foi eliminado por falta de interação." if me.reason in ["disconnect", "left"] else \
			("Você foi eliminado por faltas." if me.reason == "faults" else "Você foi eliminado.")
		add_child(_notice(text + " Acompanhe a partida como espectador.", Color("#ffb8a6")))
	elif me.is_empty():
		add_child(_notice("Você está assistindo como espectador e jogará na próxima partida.", PlayerUI.GOLD))
	match str(data.phase):
		"selection": _render_selection(data, me)
		"countdown": _render_countdown()
		_: _render_board(data, me)
	_update_overlay(data)


func _process(_delta: float) -> void:
	if not is_visible_in_tree(): return
	var left := duel.seconds_left()
	if is_instance_valid(_timer): _timer.text = "%d s" % ceili(left)
	if is_instance_valid(_countdown): _countdown.text = str(maxi(ceili(left), 1))


# --- Seleção secreta -----------------------------------------------------------------------
func _render_selection(data: Dictionary, me: Dictionary) -> void:
	var needed := int(data.get("cards_per_player", 1))
	var header := PlayerUI.row(self)
	var title := PlayerUI.label("Escolha %d %s em segredo" % [needed, "carta" if needed == 1 else "cartas"], 20 if UIScale.is_compact() else 28, Color.WHITE)
	header.add_child(title)
	_timer = _timer_label()
	header.add_child(_timer)
	add_child(_players_strip(data, true))
	if me.is_empty() or me.eliminated:
		add_child(_notice("Os jogadores estão escolhendo suas cartas…", MUTED))
		return
	if me.confirmed:
		add_child(_notice("PRONTO! Aguardando os outros jogadores.", PlayerUI.GOLD))
		add_child(PlayerUI.label("Suas cartas", 19, PlayerUI.GOLD))
		add_child(_card_row(data.my_cards.map(func(c: Dictionary) -> String: return str(c.card_id)), 150, []))
		return
	var grid := _card_grid()
	for item: Dictionary in data.pool:
		var id := str(item.card_id)
		var chosen := _chosen.has(id)
		var card := _card(id, 150, chosen, false, true)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if _chosen.has(id): _chosen.erase(id)
				elif _chosen.size() < needed: _chosen.append(id)
				refresh())
		grid.add_child(card)
	var footer := PlayerUI.row(self)
	footer.add_child(PlayerUI.label("Selecionados: %d/%d" % [_chosen.size(), needed], 16 if UIScale.is_compact() else 20, MUTED))
	var confirm := PlayerUI.button("Confirmar cartas", func() -> void:
		var picked := _chosen.duplicate()
		await act.call(duel.select_cards.bind(picked))
		_chosen.clear())
	PlayerUI.style_button(confirm, true)
	confirm.custom_minimum_size.y = 44 if UIScale.is_compact() else 52
	confirm.disabled = _chosen.size() != needed
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_END
	footer.add_child(confirm)
	add_child(grid)


# --- Contagem regressiva -------------------------------------------------------------------
func _render_countdown() -> void:
	_chosen.clear()
	var center := CenterContainer.new()
	center.custom_minimum_size.y = 180 if UIScale.is_compact() else 360
	add_child(center)
	var column := PlayerUI.column(center)
	column.custom_minimum_size.x = minf(520, get_viewport_rect().size.x / PlayerUI.unit(self) - 80)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := PlayerUI.label("A partida vai começar!", 22 if UIScale.is_compact() else 30, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_countdown = PlayerUI.label("5", 96 if UIScale.is_compact() else 160, PlayerUI.GOLD)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_countdown)


# --- Turnos ----------------------------------------------------------------------------------
func _render_board(data: Dictionary, me: Dictionary) -> void:
	add_child(_players_strip(data, false))
	var turn := _player(data, str(data.get("turn_member", "")))
	var my_turn: bool = not me.is_empty() and str(data.get("turn_member", "")) == str(me.member_id) and data.phase == "turns"
	var banner := PlayerUI.row(self)
	var text := "É a sua vez! Escolha uma carta para eliminar." if my_turn else ("É a vez de %s" % str(turn.get("nickname", "…")))
	if data.phase == "reveal" and not my_turn and bool(turn.get("is_you", false)):
		text = "Sua jogada"
	if data.phase == "finished": text = "Fim da partida"
	banner.add_child(PlayerUI.label(text, 26, PlayerUI.GOLD if my_turn else Color.WHITE))
	if data.phase == "turns":
		_timer = _timer_label()
		banner.add_child(_timer)
	add_child(PlayerUI.label("Cartas em jogo", 18, MUTED))
	var grid := _card_grid()
	for item: Dictionary in data.pool:
		var id := str(item.card_id)
		var removed: bool = item.removed
		var card := _card(id, 132, false, removed, true)
		if my_turn and not removed:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			card.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_confirm_pick(id))
		grid.add_child(card)
	add_child(grid)
	if not me.is_empty() and not (data.my_cards as Array).is_empty():
		add_child(PlayerUI.label("Suas cartas (só você vê)", 18, PlayerUI.GOLD))
		var lost := (data.my_cards as Array).filter(func(c: Dictionary) -> bool: return c.lost).map(func(c: Dictionary) -> String: return str(c.card_id))
		add_child(_card_row((data.my_cards as Array).map(func(c: Dictionary) -> String: return str(c.card_id)), 104, lost))


func _confirm_pick(id: String) -> void:
	_close_overlay()
	var layer := _overlay_layer(0.6)
	var panel := PlayerUI.panel(_centered(layer), 20 if UIScale.is_compact() else 40)
	panel.get_parent().custom_minimum_size.x = minf(460, get_viewport_rect().size.x / PlayerUI.unit(self) - 40)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	var card := _card(id, 110 if UIScale.is_compact() else 170, true, false)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(card)
	var question := PlayerUI.label("Eliminar %s?" % _name(id), 26, Color.WHITE)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(question)
	var row := PlayerUI.row(panel)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := PlayerUI.button("Eliminar", func() -> void:
		_close_overlay()
		act.call(duel.pick.bind(id)))
	PlayerUI.style_button(yes, true)
	row.add_child(yes)
	row.add_child(PlayerUI.button("Cancelar", _close_overlay))
	_overlay_key = "confirm"


# --- Revelação e fim -------------------------------------------------------------------------
## Revelação: a carta escolhida aparece em destaque, com suspense, e só depois quem foi
## atingido (o servidor só manda os atingidos depois do tempo de suspense).
func _update_overlay(data: Dictionary) -> void:
	if _overlay_key == "confirm" and data.phase == "turns": return
	var events: Array = data.events
	var last: Dictionary = events.back() if not events.is_empty() else {}
	var key := ""
	if data.phase == "reveal" and not last.is_empty(): key = "%s:%s" % [last.seq, last.revealed]
	elif data.phase == "finished": key = "finished"
	if key == _overlay_key: return
	var first_time := not _overlay_key.begins_with("%s:" % str(last.get("seq", ""))) or key == "finished"
	_close_overlay()
	_overlay_key = key
	if key.is_empty(): return
	var layer := _overlay_layer(0.72)
	var column := PlayerUI.column(_centered(layer))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = minf(560, get_viewport_rect().size.x / PlayerUI.unit(self) - 40)
	if key == "finished":
		_render_champion(column, data)
	elif last.kind == "pick":
		_render_pick(column, data, last, first_time)
	else:
		_render_timeout(column, data, last)
	if first_time:
		PlayerUI.reveal(column, 0.0, 0.35)


func _render_pick(column: VBoxContainer, data: Dictionary, event: Dictionary, first_time: bool) -> void:
	var actor := _player(data, str(event.get("actor", "")))
	var kicker := PlayerUI.label("%s escolheu eliminar" % str(actor.get("nickname", "…")), 22, MUTED)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var card := _card(str(event.card_id), 130 if UIScale.is_compact() else 220, true, false)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(card)
	if not event.revealed:
		var wait := PlayerUI.label("Revelando…", 30, PlayerUI.GOLD)
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(wait)
		if first_time:
			card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
			var pulse := card.create_tween().set_loops()
			pulse.tween_property(card, "scale", Vector2.ONE * 1.06, 0.45).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		return
	var hits: Array = event.hits if event.hits is Array else []
	if hits.is_empty():
		var nobody := PlayerUI.label("NINGUÉM FOI ATINGIDO!", 34, Color.WHITE)
		nobody.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(nobody)
		return
	var title := PlayerUI.label("%s %s!" % ["ATINGIDO" if hits.size() == 1 else "ATINGIDOS", "" if hits.size() == 1 else "(%d)" % hits.size()], 30, Color("#ff8f86"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 10)
	column.add_child(row)
	for hit: Dictionary in hits:
		row.add_child(_hit_badge(data, hit))


func _render_timeout(column: VBoxContainer, data: Dictionary, event: Dictionary) -> void:
	var actor := _player(data, str(event.get("actor", "")))
	var hit: Dictionary = (event.hits as Array)[0] if event.hits is Array and not (event.hits as Array).is_empty() else {}
	var text := "%s não votou a tempo" % str(actor.get("nickname", "…"))
	if event.kind == "eliminated": text = "%s saiu da partida" % str(actor.get("nickname", "…"))
	var title := PlayerUI.label(text, 30, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := "Eliminado!" if hit.get("eliminated", false) else "Perdeu 1 vida (falta %d de 2)" % int(hit.get("faults", 1))
	var line := PlayerUI.label(detail, 24, Color("#ff8f86"))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)


func _render_champion(column: VBoxContainer, data: Dictionary) -> void:
	var result: Dictionary = data.get("result", {}) if data.get("result") is Dictionary else {}
	var winners: Array = result.get("winners", [])
	if winners.size() == 1:
		var champion := _player(data, str(winners[0]))
		var kicker := PlayerUI.label("CAMPEÃO", 26, PlayerUI.GOLD)
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(kicker)
		var portrait := PlayerUI.portrait(str(champion.get("skin_id", "")), 140 if UIScale.is_compact() else 220)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(portrait)
		var name_label := PlayerUI.label(str(champion.get("nickname", "")), 44, Color.WHITE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
	else:
		var draw := PlayerUI.label("Empate!", 44, Color.WHITE)
		draw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(draw)
	var back := PlayerUI.label("Voltando ao lobby da sala…", 20, MUTED)
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(back)


func _hit_badge(data: Dictionary, hit: Dictionary) -> Control:
	var player := _player(data, str(hit.get("member_id", "")))
	var box := PanelContainer.new()
	box.custom_minimum_size.x = 180
	var style := _plate(bool(player.get("is_you", false)))
	if UIScale.is_compact():
		style.content_margin_top = 8
		style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)
	var column := PlayerUI.column(box)
	column.add_theme_constant_override("separation", 2)
	var portrait := PlayerUI.portrait(str(player.get("skin_id", "")), 84)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if hit.get("eliminated", false): portrait.modulate = Color(0.55, 0.45, 0.45)
	column.add_child(portrait)
	if UIScale.is_compact(): portrait.hide()
	var nickname := PlayerUI.label(str(player.get("nickname", "")), 18, Color.WHITE)
	nickname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname.autowrap_mode = TextServer.AUTOWRAP_OFF
	nickname.clip_text = true
	nickname.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(nickname)
	var state := PlayerUI.label("ELIMINADO" if hit.get("eliminated", false) else "%d %s" % [int(hit.get("lives", 0)), "vida" if int(hit.get("lives", 0)) == 1 else "vidas"], 15, Color("#ff8f86"))
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(state)
	return box


# --- Peças visuais ---------------------------------------------------------------------------
## Faixa dos participantes: busto, nome, vidas (corações) e situação. O da vez fica dourado.
func _players_strip(data: Dictionary, selection: bool) -> Control:
	var compact := UIScale.is_compact()
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 72 if compact else 128
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)
	for player: Dictionary in data.players:
		var turn: bool = str(player.member_id) == str(data.get("turn_member", "")) and data.phase in ["turns", "reveal"]
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(170 if compact else 150, 0)
		var style := _plate(turn)
		if compact:
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			style.content_margin_left = 10
			style.content_margin_right = 10
		box.add_theme_stylebox_override("panel", style)
		var content: BoxContainer = PlayerUI.row(box) if compact else PlayerUI.column(box)
		content.add_theme_constant_override("separation", 8 if compact else 2)
		var portrait := PlayerUI.portrait(str(player.skin_id), 36 if compact else 56)
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if player.eliminated: portrait.modulate = Color(0.45, 0.45, 0.5)
		content.add_child(portrait)
		var column: VBoxContainer = PlayerUI.column(content) if compact else content as VBoxContainer
		column.add_theme_constant_override("separation", 2)
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nickname := PlayerUI.label(str(player.nickname), 14 if compact else 16, Color.WHITE)
		nickname.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
		nickname.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nickname.autowrap_mode = TextServer.AUTOWRAP_OFF
		nickname.clip_text = true
		column.add_child(nickname)
		if selection or player.eliminated:
			var status := "ELIMINADO" if player.eliminated else ("PRONTO" if player.confirmed else "escolhendo…")
			var ready := PlayerUI.label(status, 12 if compact else 14, PlayerUI.GOLD if player.confirmed else MUTED)
			ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(ready)
		else:
			column.add_child(_hearts(int(player.lives), int(player.faults)))
		row.add_child(box)
	return scroll


func _hearts(lives: int, faults: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	for index in range(lives):
		var heart := TextureRect.new()
		heart.texture = Icons.heart(20, true)
		heart.custom_minimum_size = Vector2(18, 18)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(heart)
	if faults > 0:
		row.add_child(PlayerUI.label("  falta" if faults == 1 else "  2 faltas", 12, Color("#ffb8a6")))
	return row


## Placa com folga interna: o texto não encosta no filete dourado.
func _plate(gold: bool) -> StyleBoxFlat:
	var box := PlayerUI.plate(gold)
	box.content_margin_top = 14
	box.content_margin_bottom = 18
	return box


func _card_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = clampi(int((get_viewport_rect().size.x / PlayerUI.unit(self) - 40) / 100), 1, 8)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


func _card_row(ids: Array, width: float, lost: Array) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for id in ids:
		row.add_child(_card(str(id), width, false, lost.has(id)))
	return row


## Carta do deck: a imagem PNG da carta (assets/duel/decks/<deck>/<carta>.png). Escolhida:
## contorno dourado; eliminada: apagada e marcada. Sem imagem, mostra só o nome.
func _card(id: String, width: float, gold: bool, out: bool, fit_grid := false) -> PanelContainer:
	if fit_grid:
		var available := get_viewport_rect().size.x / PlayerUI.unit(self) - 80
		var columns := clampi(int((available + 40) / 100), 1, 8)
		width = minf(width, (available - (columns - 1) * 12) / columns)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, width * 1.4)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.12, 0.85)
	style.set_corner_radius_all(maxi(6, int(width * 0.05)))
	style.border_color = PlayerUI.GOLD if gold else Color(1, 1, 1, 0.12)
	style.set_border_width_all(2 if gold else 0)
	style.set_content_margin_all(3)
	if gold:
		style.shadow_color = Color(PlayerUI.GOLD, 0.55)
		style.shadow_size = 0
	card.add_theme_stylebox_override("panel", style)
	var texture := DuelService.card_texture(id)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		var caption_layout := VBoxContainer.new()
		caption_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption_layout)
		var space := Control.new()
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		caption_layout.add_child(space)
		var caption := PlayerUI.label(_name(id), 12, PlayerUI.TEXT)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var caption_style := StyleBoxFlat.new()
		caption_style.bg_color = Color(0.02, 0.03, 0.04, 0.92)
		caption_style.set_content_margin_all(5)
		caption.add_theme_stylebox_override("normal", caption_style)
		caption_layout.add_child(caption)
	else:
		var label := PlayerUI.label(_name(id), maxi(13, int(width * 0.12)), Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
	if out:
		card.modulate = Color(0.42, 0.42, 0.48)
		var mark := PlayerUI.label("ELIMINADA", maxi(12, int(width * 0.1)), Color("#ff8f86"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(mark)
	return card


func _timer_label() -> Label:
	var label := PlayerUI.label("", 18 if UIScale.is_compact() else 26, Color.WHITE)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _notice(text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PlayerUI.plate())
	var label := PlayerUI.label(text, 19, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _overlay_layer(dim: float) -> Control:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.01, 0.02, 0.05, dim)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 5
	overlay_parent.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _overlay


func _centered(layer: Control) -> CenterContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var layout := func() -> void:
		var unit := PlayerUI.unit(layer)
		scroll.scale = Vector2.ONE * unit
		scroll.size = layer.size / unit
		center.custom_minimum_size.y = scroll.size.y
	layer.resized.connect(layout)
	layout.call()
	return center


func _close_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.queue_free()
	_overlay = null
	_overlay_key = ""


func _me(data: Dictionary) -> Dictionary:
	for player: Dictionary in data.players:
		if player.is_you: return player
	return {}


func _player(data: Dictionary, member_id: String) -> Dictionary:
	for player: Dictionary in data.players:
		if str(player.member_id) == member_id: return player
	return {}


func _name(id: String) -> String:
	return DuelService.card_name(id)
