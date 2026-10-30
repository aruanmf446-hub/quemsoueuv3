extends PlayerScreen
## Duelo (multiplayer), etapa 1: salas online. Três vistas na mesma tela:
## - "browse": salas públicas (no lobby), filtros e entrada por código de convite;
## - "form": criar sala ou (ADM) editar as configurações da sala;
## - "room": lobby com participantes, skins, ADM, bots, expulsar e iniciar.
## O servidor decide tudo (DuelService); esta tela só mostra e pede ações.

const SKIN_SIZE := 128
var duel: DuelService
var _view := "browse"
var _term := ""
var _only_open := true
var _rooms: Array = []
var _list_epoch := 0
var _busy := false
var _auto_refresh: Timer
var _form: Dictionary = {}
## Tela da partida: uma só instância, mantida entre atualizações (a seleção em andamento
## não se perde quando chega uma atualização do servidor).
var _match_view: Node


func _ready() -> void:
	super._ready()
	heading.text = tr("Duelo")
	duel = services.duel
	duel.changed.connect(func() -> void:
		if is_visible_in_tree() and not _busy: render())
	duel.removed.connect(func(reason: String) -> void:
		_view = "browse"
		if is_visible_in_tree():
			render()
			banner.show_state("error", DuelService.message("room_closed" if reason == "closed" else "not_member")))
	services.session.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	_auto_refresh = Timer.new()
	_auto_refresh.wait_time = 6.0
	_auto_refresh.timeout.connect(func() -> void:
		if is_visible_in_tree() and _view == "browse" and not duel.in_room(): _load_rooms(false))
	add_child(_auto_refresh)
	_auto_refresh.start()


func show_screen(params: Dictionary = {}) -> void:
	if duel.in_room(): _view = "room"
	elif _view == "room": _view = "browse"
	super.show_screen(params)
	if _view == "browse" and services.session.authenticated(): _load_rooms(false)


func render() -> void:
	heading.text = tr("Duelo")
	if is_instance_valid(_match_view) and _match_view.get_parent() == body: body.remove_child(_match_view)
	PlayerUI.clear(body)
	banner.show_state("success")
	if not services.session.authenticated():
		_signed_out()
		return
	if duel.in_room(): _view = "room" if _view != "form" else "form"
	match _view:
		"form": _render_form()
		"room": _render_room()
		_: _render_browse()


# --- Sem conta -----------------------------------------------------------------------------
func _signed_out() -> void:
	var center := MarginContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 230
	body.add_child(center)
	var card := PlayerUI.column(center)
	card.custom_minimum_size.x = 0
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := PlayerUI.label("Duelos online", 30, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(title)
	var text := PlayerUI.label("Entre na sua conta para criar ou entrar em salas.", 19, Color("#c9d6e6"))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(text)
	var enter := PlayerUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}))
	PlayerUI.style_button(enter, true)
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enter.custom_minimum_size.x = 240
	card.add_child(enter)


# --- Lista de salas ------------------------------------------------------------------------
func _render_browse() -> void:
	var actions := PlayerUI.row(body)
	actions.add_theme_constant_override("separation", 10)
	var create := PlayerUI.button("Criar sala", func() -> void: _open_form())
	PlayerUI.style_button(create, true)
	actions.add_child(create)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var code := LineEdit.new()
	code.name = "InviteCode"
	code.placeholder_text = tr("Código do convite")
	code.max_length = 9
	code.custom_minimum_size = Vector2(230, 52)
	code.add_theme_stylebox_override("normal", PlayerUI.button_plate())
	code.add_theme_stylebox_override("focus", PlayerUI.button_plate(false, Color(1.2, 1.2, 1.25)))
	code.text_submitted.connect(func(value: String) -> void: _join(value))
	actions.add_child(code)
	actions.add_child(PlayerUI.button("Entrar", func() -> void: _join(code.text)))
	var filters := PlayerUI.row(body)
	filters.add_theme_constant_override("separation", 10)
	var search := LineEdit.new()
	search.placeholder_text = tr("Buscar sala pelo nome")
	search.text = _term
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 52
	search.add_theme_stylebox_override("normal", PlayerUI.button_plate())
	search.add_theme_stylebox_override("focus", PlayerUI.button_plate(false, Color(1.2, 1.2, 1.25)))
	search.text_submitted.connect(func(value: String) -> void:
		_term = value
		_load_rooms(true))
	filters.add_child(search)
	var open := PlayerUI.button("Só com vaga", func() -> void: pass)
	open.toggle_mode = true
	open.button_pressed = _only_open
	open.toggled.connect(func(value: bool) -> void:
		_only_open = value
		_load_rooms(true))
	filters.add_child(open)
	filters.add_child(PlayerUI.button("↻", func() -> void:
		_term = search.text
		_load_rooms(true)))
	if _rooms.is_empty():
		var empty := PlayerUI.label("Nenhuma sala pública aberta agora. Crie a sua ou entre com um código.", 19, Color("#a8bad3"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 140
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.add_child(empty)
	for item: Dictionary in _rooms:
		_room_row(item)


func _room_row(item: Dictionary) -> void:
	var card := PlayerUI.card(body)
	var line := PlayerUI.row(card)
	var info := PlayerUI.column(line)
	info.add_theme_constant_override("separation", 2)
	info.add_child(PlayerUI.label(str(item.get("name", "")), 24, PlayerUI.GOLD))
	var decks := ", ".join((item.get("decks", []) as Array).map(func(d: Dictionary) -> String: return str(d.get("name", ""))))
	var details := "ADM %s  ·  %d cartas por jogador  ·  %ds por turno  ·  Decks: %s" % [str(item.get("admin", "")),
		int(item.get("cards_per_player", 0)), int(item.get("turn_seconds", 0)), decks]
	info.add_child(PlayerUI.label(details, 16, Color("#c9d6e6")))
	var seats := PlayerUI.label("%d/%d" % [int(item.get("players", 0)), int(item.get("max_players", 0))], 22, Color.WHITE)
	seats.autowrap_mode = TextServer.AUTOWRAP_OFF
	seats.size_flags_horizontal = Control.SIZE_SHRINK_END
	seats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(seats)
	var enter := PlayerUI.button("Entrar", func() -> void: _join(str(item.get("code", ""))))
	enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PlayerUI.style_button(enter, false)
	line.add_child(enter)


func _load_rooms(show_loading: bool) -> void:
	_list_epoch += 1
	var epoch := _list_epoch
	if show_loading: banner.show_state("loading")
	var result := await duel.list_rooms(_term, _only_open)
	if epoch != _list_epoch or _view != "browse" or duel.in_room(): return
	if result.ok and result.data is Dictionary:
		_rooms = result.data.get("rooms", [])
		render()
	elif show_loading:
		banner.show_state("error", DuelService.message(str(result.code)))


func _join(code: String) -> void:
	if code.strip_edges().is_empty(): return
	await _act(duel.join.bind(code))
	if duel.in_room():
		_view = "room"
		render()
		animate_in()


# --- Criar / editar sala -------------------------------------------------------------------
func _open_form() -> void:
	_busy = true
	banner.show_state("loading")
	var result := await duel.load_decks()
	_busy = false
	if not result.ok:
		banner.show_state("error", DuelService.message(str(result.code)))
		return
	_view = "form"
	render()
	animate_in()


func _render_form() -> void:
	var editing := duel.in_room()
	var base: Dictionary = duel.room.room.settings if editing else duel.defaults
	var panel := PlayerUI.panel(body, 36)
	panel.add_child(PlayerUI.label("Configurações da sala" if editing else "Criar sala", 28, Color.WHITE))
	_form = {}
	var top := PlayerUI.row(panel)
	var room_name := LineEdit.new()
	room_name.placeholder_text = tr("Nome da sala")
	room_name.text = str(duel.room.room.name) if editing else "Sala de %s" % str(services.profile.data.get("nickname", "Duelo"))
	room_name.max_length = 32
	room_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_name.custom_minimum_size.y = 52
	room_name.add_theme_stylebox_override("normal", PlayerUI.button_plate())
	room_name.add_theme_stylebox_override("focus", PlayerUI.button_plate(false, Color(1.2, 1.2, 1.25)))
	top.add_child(room_name)
	_form.name = room_name
	var public := PlayerUI.button("Sala pública", func() -> void: pass)
	public.toggle_mode = true
	public.button_pressed = bool(duel.room.room.is_public) if editing else true
	public.toggled.connect(func(value: bool) -> void: public.text = tr("Sala pública" if value else "Só por convite"))
	public.text = tr("Sala pública" if public.button_pressed else "Só por convite")
	top.add_child(public)
	_form.public = public
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(grid)
	for field: Array in [["max_players", "Jogadores (máximo)", 2, 20], ["cards_per_player", "Cartas por jogador", 1, 6],
			["turn_seconds", "Tempo por turno (s)", 15, 180], ["selection_seconds", "Tempo de seleção (s)", 10, 120],
			["tiebreak_base", "Desempate: cartas com 2 jogadores", 4, 12], ["tiebreak_per_player", "Desempate: cartas a mais por jogador", 1, 4]]:
		grid.add_child(PlayerUI.label(field[1], 19))
		var spin := SpinBox.new()
		spin.min_value = field[2]
		spin.max_value = field[3]
		spin.value = int(base.get(field[0], field[2]))
		spin.custom_minimum_size = Vector2(150, 44)
		spin.alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(spin)
		_form[field[0]] = spin
	var bots := PlayerUI.button("Bots permitidos", func() -> void: pass)
	bots.toggle_mode = true
	bots.button_pressed = bool(base.get("bots_allowed", true))
	bots.toggled.connect(func(value: bool) -> void: bots.text = tr("Bots permitidos" if value else "Sem bots"))
	bots.text = tr("Bots permitidos" if bots.button_pressed else "Sem bots")
	bots.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.add_child(bots)
	_form.bots_allowed = bots
	panel.add_child(PlayerUI.label("Decks de personagens", 19, PlayerUI.GOLD))
	var deck_row := PlayerUI.row(panel)
	var chosen: Array = base.get("deck_ids", ["comeco"])
	var deck_buttons := {}
	var deck_list: Array = duel.decks if not duel.decks.is_empty() else duel.room.get("room", {}).get("decks", [])
	for deck: Dictionary in deck_list:
		var toggle := PlayerUI.button("%s (%d)" % [str(deck.get("name", "")), int(deck.get("size", 0))], func() -> void: pass)
		toggle.toggle_mode = true
		toggle.button_pressed = chosen.has(deck.get("id"))
		deck_row.add_child(toggle)
		deck_buttons[str(deck.get("id"))] = toggle
	_form.decks = deck_buttons
	var actions := PlayerUI.row(panel)
	var save := PlayerUI.button("Salvar" if editing else "Criar sala", _submit_form)
	PlayerUI.style_button(save, true)
	actions.add_child(save)
	actions.add_child(PlayerUI.button("Cancelar", func() -> void:
		_view = "room" if duel.in_room() else "browse"
		render()))


func _submit_form() -> void:
	var settings := {"bots_allowed": (_form.bots_allowed as Button).button_pressed}
	for key in ["max_players", "cards_per_player", "turn_seconds", "selection_seconds", "tiebreak_base", "tiebreak_per_player"]:
		settings[key] = int((_form[key] as SpinBox).value)
	var decks: Array = []
	for id: String in _form.decks:
		if (_form.decks[id] as Button).button_pressed: decks.append(id)
	if decks.is_empty():
		banner.show_state("error", tr("Escolha pelo menos um deck."))
		return
	settings.deck_ids = decks
	var room_name: String = (_form.name as LineEdit).text
	var public: bool = (_form.public as Button).button_pressed
	var result := await _act(duel.configure.bind(room_name, public, settings) if duel.in_room() else duel.create.bind(room_name, public, settings))
	if result.ok:
		_view = "room"
		render()
		animate_in()


# --- Lobby da sala -------------------------------------------------------------------------
func _render_room() -> void:
	var data: Dictionary = duel.room.room
	var settings: Dictionary = data.settings
	var me := duel.me()
	var admin := duel.is_admin()
	var header := PlayerUI.row(body)
	header.add_theme_constant_override("separation", 12)
	var titles := PlayerUI.column(header)
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(PlayerUI.label(str(data.name), 30, Color.WHITE))
	var players := (duel.room.members as Array).filter(func(m: Dictionary) -> bool: return m.role == "player")
	var state := "No lobby  ·  %d/%d jogadores" % [players.size(), int(settings.max_players)]
	if str(data.status) == "in_match": state = "Partida em andamento"
	titles.add_child(PlayerUI.label(state + ("  ·  Sala pública" if data.is_public else "  ·  Só por convite"), 17, Color("#c9d6e6")))
	var code := PlayerUI.button("Código  %s" % str(data.code), func() -> void:
		DisplayServer.clipboard_set(str(data.code))
		banner.show_state("success", tr("Código copiado: %s") % str(data.code)))
	code.tooltip_text = tr("Copiar código de convite")
	code.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(code)
	if str(data.status) == "in_match" and not duel.match().is_empty():
		header.hide()
		heading.text = tr("Batalha")
		if not is_instance_valid(_match_view):
			_match_view = preload("res://scripts/ui/screens/duel_match_view.gd").new()
			_match_view.name = "Match"
			_match_view.setup(duel, services.inventory, self, _act)
		body.add_child(_match_view)
		_match_view.refresh()
		var leave_row := PlayerUI.row(body)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leave_row.add_child(gap)
		leave_row.add_child(PlayerUI.button("Sair da sala", _leave_room))
		return
	if is_instance_valid(_match_view):
		_match_view.queue_free()
		_match_view = null
	var grid := GridContainer.new()
	grid.name = "Members"
	grid.columns = clampi(int((size.x / PlayerUI.unit(self) - 28) / 202), 1, 5)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for member: Dictionary in duel.room.members:
		grid.add_child(_member_card(member, admin, str(data.status)))
	var summary := "%d cartas por jogador  ·  %ds por turno  ·  %ds de seleção  ·  Bots %s  ·  Decks: %s" % [int(settings.cards_per_player),
		int(settings.turn_seconds), int(settings.selection_seconds), "permitidos" if settings.bots_allowed else "desativados",
		", ".join((data.get("decks", []) as Array).map(func(d: Dictionary) -> String: return str(d.get("name", ""))))]
	body.add_child(PlayerUI.label(summary, 17, Color("#c9d6e6")))
	var actions := PlayerUI.flow(body)
	actions.add_theme_constant_override("separation", 10)
	if admin and str(data.status) == "lobby":
		var start := PlayerUI.button("Iniciar partida", func() -> void: _act(duel.start))
		PlayerUI.style_button(start, true)
		start.disabled = players.size() < 2
		start.tooltip_text = tr("São necessários pelo menos 2 participantes.") if start.disabled else ""
		actions.add_child(start)
		if settings.bots_allowed:
			var bot := PlayerUI.button("Adicionar bot", func() -> void: _act(duel.add_bot))
			bot.disabled = players.size() >= int(settings.max_players)
			actions.add_child(bot)
		actions.add_child(PlayerUI.button("Configurações", func() -> void: _open_form()))
	elif str(data.status) == "lobby":
		actions.add_child(PlayerUI.label("Aguardando o administrador iniciar a partida…", 18, PlayerUI.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	actions.add_child(PlayerUI.button("Sair da sala", _leave_room))


## Sair durante a partida elimina o jogador (regra do servidor); no lobby, só sai.
func _leave_room() -> void:
	await duel.leave()
	_view = "browse"
	_rooms = []
	render()
	_load_rooms(false)


## Cartão do participante: retrato da skin equipada, nome e selos (ADM, BOT, VOCÊ, espectador).
func _member_card(member: Dictionary, admin: bool, status: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 0)
	var plate := PlayerUI.plate(bool(member.get("is_you", false)))
	plate.content_margin_top = 14
	plate.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", plate)
	var column := PlayerUI.column(card)
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait := PlayerUI.portrait(str(member.get("character_id", "")), SKIN_SIZE)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not bool(member.get("online", true)) or member.get("role") == "spectator": portrait.modulate = Color(0.55, 0.58, 0.65)
	column.add_child(portrait)
	var nickname := PlayerUI.label(str(member.get("nickname", "")), 19, Color.WHITE)
	nickname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nickname.autowrap_mode = TextServer.AUTOWRAP_OFF
	nickname.clip_text = true
	column.add_child(nickname)
	var tags: Array[String] = []
	if member.get("is_admin", false): tags.append("ADM")
	if member.get("is_bot", false): tags.append("BOT")
	if member.get("is_you", false): tags.append("VOCÊ")
	if member.get("role") == "spectator": tags.append("ESPECTADOR")
	if not bool(member.get("online", true)): tags.append("SEM SINAL")
	var tag := PlayerUI.label("  ·  ".join(tags), 13, PlayerUI.GOLD)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)
	var can_kick: bool = admin and not member.get("is_you", false) and (status == "lobby" or member.get("role") == "spectator")
	if can_kick:
		var kick := PlayerUI.button("Remover", func() -> void: _act(duel.kick.bind(str(member.get("member_id", "")))))
		kick.custom_minimum_size = Vector2(0, 40)
		kick.add_theme_font_size_override("font_size", 16)
		column.add_child(kick)
	return card


## Ação no servidor (Callable do DuelService) com aviso de erro; devolve o resultado.
func _act(action: Callable) -> Dictionary:
	_busy = true
	banner.show_state("loading")
	var result: Dictionary = await action.call()
	_busy = false
	if result.ok:
		banner.show_state("success")
		render()
	else:
		banner.show_state("error", DuelService.message(str(result.code)))
	return result


func animate_in() -> void:
	PlayerUI.cascade(body)
	var members := body.get_node_or_null("Members")
	if members != null: PlayerUI.cascade(members, 0, 0.03)
