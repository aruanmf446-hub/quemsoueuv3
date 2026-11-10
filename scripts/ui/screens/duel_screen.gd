extends PlayerScreen
var _iphone_room_actions: Control
var _room_stage: LobbyStage
var _room_stage_skin := ""
## Duelo (multiplayer), etapa 1: salas online. Três vistas na mesma tela:
## - "browse": salas públicas (no lobby), filtros e entrada por código de convite;
## - "form": criar sala ou (ADM) editar as configurações da sala;
## - "room": lobby com participantes, skins, ADM, bots, expulsar e iniciar.
## O servidor decide tudo (DuelService); esta tela só mostra e pede ações.
## Partida local: sem conta, o jogador cria uma sala neste aparelho com bots (LocalDuelServer,
## mesmas regras e contratos). Ela é sempre identificada como local e nunca é pública.

const SKIN_SIZE := 128
var duel: DuelService
var _view := "browse"
var _term := ""
var _rooms: Array = []
var _list_epoch := 0
var _busy := false
var _auto_refresh: Timer
var _form: Dictionary = {}
## Tela da partida: uma só instância, mantida entre atualizações (a seleção em andamento
## não se perde quando chega uma atualização do servidor).
var _match_view: Node
var _battle_layout := false


func _ready() -> void:
	super._ready()
	heading.text = tr("Mata-Mata")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	_auto_refresh.wait_time = 15.0
	_auto_refresh.timeout.connect(func() -> void:
		if is_visible_in_tree() and _view == "browse" and not duel.in_room() and _online(): _load_rooms(false))
	add_child(_auto_refresh)
	_auto_refresh.start()


func show_screen(params: Dictionary = {}) -> void:
	if duel.in_room(): _view = "room"
	elif _view == "room": _view = "browse"
	super.show_screen(params)
	if _battle_layout and is_instance_valid(_match_view):
		_match_view.find_child("BattleBack",true,false).grab_focus()
	# Consome o token apenas após autenticação. Não deixa tentativa pendente no URL.
	if _online() and not duel.in_room() and not _web_invite_used:
		var raw_invite := str(params.get("invite", _web_invite()))
		if not raw_invite.is_empty():
			_web_invite_used = true
			var invite := DuelService.invite_token(raw_invite)
			if invite.is_empty():
				banner.show_state("error", DuelService.message("invalid_invite"))
			else:
				_join(invite)
			return
	if _view == "browse" and _online(): _load_rooms(false)


static var _web_invite_used := false
static func _web_invite() -> String:
	if _web_invite_used or not OS.has_feature("web"): return ""
	# Remove o segredo da barra de endereços/histórico atual ao consumi-lo.
	var value: Variant = JavaScriptBridge.eval("(() => { const u = new URL(window.location.href); const token = u.searchParams.get('invite') || ''; if (u.searchParams.has('invite')) { u.searchParams.delete('invite'); window.history.replaceState(window.history.state, '', u.pathname + u.search + u.hash); } return token; })()")
	return str(value) if value != null else ""


## Lista e convites online: só com conta e fora da partida local.
func _online() -> bool:
	return services.session.authenticated() and not duel.is_local()


func render() -> void:
	if is_instance_valid(_match_view) and _match_view.holding_results(): return
	if is_instance_valid(_iphone_room_actions):
		_iphone_room_actions.get_parent().remove_child(_iphone_room_actions)
		_iphone_room_actions.queue_free()
		_iphone_room_actions = null
	var in_battle := duel.in_room() and str(duel.room.get("room",{}).get("status","")) in ["in_match","closed"] and not duel.match().is_empty()
	_set_battle_layout(in_battle)
	if in_battle and is_instance_valid(_match_view) and _match_view.get_parent() == body:
		_match_view.refresh()
		return
	heading.text = tr("Mata-Mata · Partida local") if duel.is_local() else tr("Mata-Mata")
	if is_instance_valid(_match_view) and _match_view.get_parent() == body: body.remove_child(_match_view)
	# Mantém a mesma instância animada entre heartbeats do lobby.
	if is_instance_valid(_room_stage):
		if _room_stage.get_parent()!=null: _room_stage.get_parent().remove_child(_room_stage)
		if in_battle or not duel.in_room() or _view=="form":
			_room_stage.queue_free()
			_room_stage=null
			_room_stage_skin=""
	PlayerUI.clear(body)
	banner.show_state("success")
	if duel.room.has("asset_error"): banner.show_state("error",CommunityService.message(str(duel.room.asset_error)))
	_header_extras(_view == "browse" and _online() and not duel.in_room())
	# A partida local permanece acessível ao sair da sala, sem exigir login.
	if (not services.session.authenticated() and not duel.is_local()) or (duel.is_local() and not duel.in_room() and _view != "form"):
		_signed_out()
		return
	if duel.in_room(): _view = "room" if _view != "form" else "form"
	elif _view == "room": _view = "browse"
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
	var title := PlayerUI.label("Partida local", 30, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(title)
	var text := PlayerUI.label("Jogue agora contra bots neste aparelho, sem conta e sem internet.", 19, Color("#c9d6e6"))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(text)
	var local := PlayerUI.button("Criar partida local", _start_local)
	local.name = "LocalMatch"
	PlayerUI.style_button(local, true)
	local.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	local.custom_minimum_size.x = 280
	card.add_child(local)
	var online := PlayerUI.label("Partidas Mata-Mata online (salas públicas e convites) pedem uma conta.", 17, Color("#a8bad3"))
	online.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.add_child(online)
	var enter := PlayerUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}))
	PlayerUI.style_button(enter, false)
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enter.custom_minimum_size.x = 240
	card.add_child(enter)


func _start_local() -> void:
	await duel.use_local()
	_open_form()


# --- Lista de salas (navegador de servidores, T25) -----------------------------------------
## Linhas horizontais: CÓDIGO | JOGADORES | DECK | STATUS | AÇÃO. A identificação é o código
## real da sala (o nome técnico do contrato não aparece). A descoberta mostra só salas no lobby
## com vaga: o servidor já filtra status 'lobby' e p_only_open; o cliente confere de novo.
const BG := Color("#081323")
const SURFACE := Color("#101d2d")
const ROW_BG := Color("#0f1b2b")
const ROW_SELECTED := Color("#152438")
const LINE := Color(0.62, 0.7, 0.82, 0.22)
const SECONDARY := Color("#b8c2d1")
var _selected_code := ""
var _list_state := "loading"
var _list_error := ""
var _compact_layout := false


func _compact() -> bool:
	return size.x / maxf(PlayerUI.unit(self), 0.01) < 1000.0


## Código para comparação: só letras e números, maiúsculo (como o servidor normaliza).
static func code_key(value: String) -> String:
	return RegEx.create_from_string("[^A-Za-z0-9]").sub(value, "", true).to_upper()


## Salas exibidas: com vaga, no lobby e cujo código contém o termo buscado.
func _visible_rooms() -> Array:
	var term := code_key(_term)
	return _rooms.filter(func(item: Dictionary) -> bool:
		var open := int(item.get("players", 0)) < int(item.get("max_players", 0))
		var lobby := str(item.get("status", "lobby")) == "lobby"
		return open and lobby and (term.is_empty() or code_key(str(item.get("code", ""))).contains(term)))


## "CRIAR SALA" → "C R I A R   S A L A" (espaçamento entre letras do subtítulo do cabeçalho).
static func spaced(text: String) -> String:
	return "   ".join(Array(text.split(" ", false)).map(func(word: String) -> String: return " ".join(Array(word.split("")))))


func _header_extras(show: bool, tag_text := "Servidores online") -> void:
	var header: HBoxContainer = $Margin/Column/Header
	var icon := header.get_node_or_null("ModeIcon") as TextureRect
	if icon == null:
		icon = PremiumUI.icon_rect("swords", PremiumUI.GOLD, 40)
		icon.name = "ModeIcon"
		header.add_child(icon)
		header.move_child(icon, heading.get_index())
		var divider := ColorRect.new()
		divider.name = "ModeDivider"
		divider.color = LINE
		divider.custom_minimum_size = Vector2(1, 30)
		divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(divider)
		header.move_child(divider, heading.get_index() + 1)
		var tag := PremiumUI.plain("S E R V I D O R E S   O N L I N E", 14, SECONDARY, false)
		tag.name = "ModeTag"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(tag)
		header.move_child(tag, heading.get_index() + 2)
		var line := StyleBoxFlat.new()
		line.draw_center = false
		line.border_color = Color(PremiumUI.GOLD, 0.7)
		line.border_width_bottom = 2
		line.content_margin_bottom = 4
		heading.set_meta("underline", line)
	var compact := _compact()
	icon.custom_minimum_size = Vector2.ONE * (28 if compact else 40)
	icon.visible = show
	header.get_node("ModeDivider").visible = show and not compact
	header.get_node("ModeTag").visible = show and not compact
	(header.get_node("ModeTag") as Label).text = spaced(tr(tag_text)) if TranslationServer.get_locale().begins_with("pt") else tr(tag_text)
	heading.add_theme_font_size_override("font_size", 26 if compact else 40)
	# Sublinhado só sob o título (como na referência); fora da lista o título volta a ocupar a linha.
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	if show:
		heading.add_theme_stylebox_override("normal", heading.get_meta("underline"))
	else:
		heading.remove_theme_stylebox_override("normal")


func _secondary(button: Button) -> void:
	var box := PremiumUI.flat(SURFACE, LINE, 12, 1)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#16263a")
	var focus := PremiumUI.flat(Color.TRANSPARENT, PremiumUI.GOLD_LIGHT, 12, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", PremiumUI.flat(SURFACE, Color(LINE, 0.4), 12, 1))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: button.add_theme_color_override(state, Color("#f5f6fa"))


func _tool(text: String, icon_name: String, primary: bool, callback: Callable) -> Button:
	var compact := _compact()
	var button := Button.new()
	# Ícone colado ao texto e o par centralizado (o Button nativo põe o ícone na borda).
	button.tooltip_text = tr(text)
	button.set_meta("label", tr(text))
	var content := HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 10 if compact else 16)
	button.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glyph := PremiumUI.icon_rect(icon_name, PremiumUI.INK if primary else Color.WHITE, 16 if compact else 24)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(glyph)
	var caption := PremiumUI.plain(text, 15 if compact else 24, PremiumUI.INK if primary else Color("#f5f6fa"))
	caption.name = "Caption"
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(caption)
	button.custom_minimum_size = Vector2(0, 44 if compact else 64)
	button.focus_mode = Control.FOCUS_ALL
	if primary: PremiumUI.style_gold(button)
	else: _secondary(button)
	button.pressed.connect(callback)
	return button


func _render_browse() -> void:
	var compact := _compact()
	_compact_layout = compact
	var gap := 10 if compact else 18
	body.add_theme_constant_override("separation", gap)
	# Ações: Criar sala e Partida local (sem o antigo campo "Código do convite").
	var actions := HBoxContainer.new()
	actions.name = "BrowseActions"
	actions.add_theme_constant_override("separation", gap)
	body.add_child(actions)
	var create := _tool("Criar sala", "plus", true, func() -> void: _open_form())
	create.name = "CreateRoom"
	create.custom_minimum_size.x = 200 if compact else 380
	actions.add_child(create)
	var local := _tool("Partida local", "gamepad", false, _start_local)
	local.name = "LocalMatch"
	local.tooltip_text = tr("Contra bots, neste aparelho")
	local.custom_minimum_size.x = 200 if compact else 420
	actions.add_child(local)
	# Busca pelo código, "Só com vaga" e atualizar.
	var filters := HBoxContainer.new()
	filters.name = "BrowseFilters"
	filters.add_theme_constant_override("separation", gap)
	body.add_child(filters)
	var field := PanelContainer.new()
	field.name = "SearchField"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 3.0
	var field_box := PremiumUI.flat(Color("#0a1626"), LINE, 12, 1)
	field_box.content_margin_left = 12 if compact else 22
	field_box.content_margin_top = 0
	field_box.content_margin_bottom = 0
	field.add_theme_stylebox_override("panel", field_box)
	filters.add_child(field)
	var field_row := HBoxContainer.new()
	field_row.add_theme_constant_override("separation", 10 if compact else 18)
	field.add_child(field_row)
	var lens := PremiumUI.icon_rect("search", Color.WHITE, 20 if compact else 28)
	lens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field_row.add_child(lens)
	var search := LineEdit.new()
	search.name = "RoomSearch"
	search.placeholder_text = tr("Buscar pelo código (ex.: QSE482)")
	search.text = _term
	search.max_length = 200
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 44 if compact else 64
	search.add_theme_font_size_override("font_size", 15 if compact else 22)
	search.add_theme_color_override("font_placeholder_color", Color(SECONDARY, 0.8))
	var empty_box := StyleBoxEmpty.new()
	for state in ["normal", "focus", "read_only"]: search.add_theme_stylebox_override(state, empty_box)
	# Filtra a lista já carregada (sem consulta nova por tecla); Enter tenta entrar pelo código/convite.
	search.text_changed.connect(func(value: String) -> void:
		_term = value
		_refresh_list())
	search.text_submitted.connect(func(value: String) -> void:
		_term = value
		var matches := _visible_rooms()
		if matches.size() == 1: _join(str(matches[0].code))
		elif _direct_entry(value) != "": _join(value))
	field_row.add_child(search)
	if not compact:
		var bar := ColorRect.new()
		bar.color = LINE
		bar.custom_minimum_size = Vector2(1, 40)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		filters.add_child(bar)
	# A descoberta pública nunca mostra salas cheias ou em partida; o filtro fica ligado e
	# explica a regra em vez de prometer salas que não podem receber jogadores.
	var open := CheckButton.new()
	open.name = "OnlyOpen"
	open.text = tr("Só com vaga")
	open.button_pressed = true
	# Desligar não traz salas cheias de volta: o controle explica e permanece ligado.
	open.toggled.connect(func(value: bool) -> void:
		if not value:
			open.set_pressed_no_signal(true)
			banner.show_state("success", tr("Salas cheias ou com partida em andamento não aparecem na lista.")))
	open.tooltip_text = tr("Salas cheias ou com partida em andamento não aparecem na lista.")
	open.add_theme_font_size_override("font_size", 15 if compact else 22)
	open.add_theme_color_override("font_disabled_color", Color("#f5f6fa"))
	open.add_theme_color_override("font_color", Color("#f5f6fa"))
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	filters.add_child(open)
	var refresh := Button.new()
	refresh.name = "RefreshRooms"
	refresh.tooltip_text = tr("Atualizar salas")
	refresh.icon = PremiumUI.icon("refresh", Color.WHITE, 40)
	refresh.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh.add_theme_constant_override("icon_max_width", 20 if compact else 28)
	refresh.custom_minimum_size = Vector2(48, 44) if compact else Vector2(110, 64)
	_secondary(refresh)
	refresh.pressed.connect(func() -> void: _load_rooms(true))
	filters.add_child(refresh)
	# Painel de servidores.
	var panel := PanelContainer.new()
	panel.name = "ServerList"
	var panel_box := PremiumUI.flat(Color(SURFACE, 0.55), Color(LINE, 0.5), 14, 1)
	panel_box.set_content_margin_all(8 if compact else 14)
	panel.add_theme_stylebox_override("panel", panel_box)
	body.add_child(panel)
	var list := VBoxContainer.new()
	list.name = "Rows"
	list.add_theme_constant_override("separation", 8 if compact else 12)
	panel.add_child(list)
	_refresh_list()


## Reconstrói só as linhas (busca e atualização não refazem a tela inteira).
func _refresh_list() -> void:
	var list := body.find_child("Rows", true, false) as VBoxContainer
	if list == null: return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list.add_child(_columns())
	if _list_state == "loading" and _rooms.is_empty():
		list.add_child(_list_message("Carregando servidores…", ""))
		return
	if _list_state == "error" and _rooms.is_empty():
		var box := _list_message("Não foi possível atualizar as salas.", _list_error)
		var retry := _tool("Tentar novamente", "refresh", false, func() -> void: _load_rooms(true))
		retry.name = "RetryRooms"
		retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(retry)
		list.add_child(box)
		return
	var shown := _visible_rooms()
	if shown.is_empty():
		if code_key(_term).is_empty():
			list.add_child(_list_message("Nenhuma sala disponível no momento.", "Crie uma sala para começar uma partida."))
		else:
			var none := _list_message("Nenhuma sala pública com esse código.", "Salas privadas também podem ser abertas pelo código ou convite.")
			var target := _direct_entry(_term)
			if not target.is_empty():
				var direct := _tool("Entrar com " + target, "play", true, func() -> void: _join(_term))
				direct.name = "DirectJoin"
				direct.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				none.add_child(direct)
			list.add_child(none)
		return
	if not shown.any(func(item: Dictionary) -> bool: return str(item.code) == _selected_code): _selected_code = str(shown[0].get("code", ""))
	for item: Dictionary in shown: list.add_child(_room_row(item))


## Texto da entrada direta: código curto (salas privadas) ou convite (token/link).
func _direct_entry(value: String) -> String:
	if not DuelService.invite_token(value).is_empty(): return tr("o convite")
	var key := code_key(value)
	return key if key.length() >= 4 and key.length() <= 12 else ""


func _list_message(title: String, detail: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "ListMessage"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.y = 150 if _compact() else 260
	box.add_theme_constant_override("separation", 10)
	var head := PremiumUI.plain(title, 18 if _compact() else 26, Color("#f5f6fa"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(head)
	if not detail.is_empty():
		var text := PremiumUI.plain(detail, 13 if _compact() else 18, SECONDARY)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(text)
	return box


## Larguras compartilhadas entre o cabeçalho das colunas e as linhas.
func _widths() -> Array:
	return [104, 70, 0, 124, 104] if _compact() else [300, 190, 0, 250, 250]


func _columns() -> Control:
	var compact := _compact()
	var row := HBoxContainer.new()
	row.name = "ServerColumns"
	row.add_theme_constant_override("separation", 10 if compact else 24)
	var widths := _widths()
	var titles := ["CÓDIGO", "JOGADORES", "DECK", "STATUS", "AÇÃO"]
	for i in titles.size():
		var label := PremiumUI.plain(titles[i], 11 if compact else 15, Color(SECONDARY, 0.9))
		label.custom_minimum_size.x = widths[i]
		if i == 0: label.custom_minimum_size.x -= 0 if compact else 0
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if widths[i] == 0 else Control.SIZE_FILL
		if i == 4: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(label)
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_left", 16 if compact else 30)
	holder.add_theme_constant_override("margin_right", 10 if compact else 18)
	holder.add_child(row)
	return holder


func _room_row(item: Dictionary) -> Control:
	var compact := _compact()
	var code := str(item.get("code", ""))
	var selected := code == _selected_code
	var row := PanelContainer.new()
	row.name = "Room_" + code_key(code)
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size.y = 58 if compact else 92
	row.set_meta("code", code)
	var box := PremiumUI.flat(ROW_SELECTED if selected else ROW_BG, Color(PremiumUI.GOLD, 0.95) if selected else LINE, 14, 2 if selected else 1)
	box.content_margin_left = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.content_margin_right = 10 if compact else 18
	if selected:
		box.shadow_color = Color(PremiumUI.GOLD, 0.22)
		box.shadow_size = 10
	row.add_theme_stylebox_override("panel", box)
	row.clip_contents = true
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10 if compact else 24)
	row.add_child(line)
	var widths := _widths()
	# 1. Código com recorte diagonal.
	var code_cell := _CodeCell.new()
	code_cell.selected = selected
	code_cell.custom_minimum_size.x = widths[0] + (16 if compact else 30)
	code_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var code_label := PremiumUI.plain(code, 20 if compact else 38, Color.WHITE, false)
	code_label.name = "Code"
	code_label.add_theme_constant_override("outline_size", 0)
	code_label.position = Vector2(16 if compact else 30, 0)
	code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	code_label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	code_label.offset_left = 16 if compact else 30
	code_cell.add_child(code_label)
	line.add_child(code_cell)
	line.add_child(_divider())
	# 2. Jogadores.
	line.add_child(_fact("friends", "%d/%d" % [int(item.get("players", 0)), int(item.get("max_players", 0))], widths[1], "Players"))
	# 3. Deck(s) reais da sala.
	var decks: Array = (item.get("decks", []) as Array).map(func(d: Variant) -> String: return LibraryCatalog.display_name(str(d.get("id", "")), str(d.get("name", ""))) if d is Dictionary else str(d))
	var deck_text := tr("Sem deck") if decks.is_empty() else str(decks[0]) + ("  +%d" % (decks.size() - 1) if decks.size() > 1 else "")
	var deck := _fact("cards", deck_text, 0, "Deck")
	deck.tooltip_text = ", ".join(decks)
	deck.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(deck)
	line.add_child(_divider())
	# 4. Status (neutro).
	line.add_child(_fact("hourglass", tr("Aguardando"), widths[3], "Status"))
	# 5. Entrar.
	var enter := _tool("Entrar", "play", true, func() -> void: _join(code))
	enter.name = "JoinRoom"
	enter.disabled = _busy
	enter.custom_minimum_size = Vector2(widths[4], 40 if compact else 60)
	enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(enter)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _select_room(code)
		elif event.is_action_pressed("ui_accept"): _join(code))
	row.focus_entered.connect(_select_room.bind(code))
	row.mouse_entered.connect(func() -> void: if code != _selected_code: (row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("#13223a"))
	row.mouse_exited.connect(func() -> void: if code != _selected_code: (row.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = ROW_BG)
	return row


func _select_room(code: String) -> void:
	if code == _selected_code: return
	_selected_code = code
	var focused := code
	_refresh_list()
	var list := body.find_child("Rows", true, false)
	if list != null:
		var row := list.find_child("Room_" + code_key(focused), false, false) as Control
		if row != null: row.grab_focus.call_deferred()


func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size = Vector2(1, 30 if _compact() else 46)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _fact(icon_name: String, text: String, width: int, node_name: String) -> HBoxContainer:
	var compact := _compact()
	var fact := HBoxContainer.new()
	fact.name = node_name
	fact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fact.add_theme_constant_override("separation", 6 if compact else 14)
	fact.custom_minimum_size.x = width
	fact.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0 else Control.SIZE_FILL
	var icon := PremiumUI.icon_rect(icon_name, Color.WHITE, 18 if compact else 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fact.add_child(icon)
	var label := PremiumUI.plain(text, 14 if compact else 24, Color("#f5f6fa"), false)
	label.name = "Value"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fact.add_child(label)
	return fact


## Primeira coluna: faixa grafite com corte diagonal; selecionada, o corte fica dourado.
class _CodeCell extends Control:
	var selected := false

	func _draw() -> void:
		var cut := minf(size.y * 0.55, 46.0)
		var points := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x - cut, size.y), Vector2(0, size.y)])
		draw_colored_polygon(points, Color("#1a2a3e") if selected else Color("#162436"))
		if selected:
			draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x * 0.75, 0), Vector2(size.x * 0.75 - cut, size.y), Vector2(0, size.y)]),
				PackedColorArray([Color(PlayerUI.GOLD, 0.28), Color(PlayerUI.GOLD, 0.0), Color(PlayerUI.GOLD, 0.0), Color(PlayerUI.GOLD, 0.18)]))
			draw_line(Vector2(size.x, 0), Vector2(size.x - cut, size.y), Color(PlayerUI.GOLD, 0.95), 2.0, true)
			draw_rect(Rect2(0, 0, 3, size.y), PlayerUI.GOLD)
		else:
			draw_line(Vector2(size.x, 0), Vector2(size.x - cut, size.y), Color(1, 1, 1, 0.08), 1.5, true)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: queue_redraw()


func _load_rooms(show_loading: bool) -> void:
	_list_epoch += 1
	var epoch := _list_epoch
	if show_loading:
		_list_state = "loading"
		_refresh_list()
	# Termo vazio: o servidor só procura o código exato; a busca parcial pelo código é local.
	var result := await duel.list_rooms("", true)
	if epoch != _list_epoch or _view != "browse" or duel.in_room(): return
	if result.ok and result.data is Dictionary:
		_rooms = result.data.get("rooms", [])
		_list_state = "ok"
		if body.find_child("Rows", true, false) != null and _compact() == _compact_layout: _refresh_list()
		else: render()
	else:
		_list_state = "error"
		_list_error = DuelService.message(str(result.code))
		_refresh_list()
		if show_loading: banner.show_state("error", _list_error)


func _join(code: String) -> void:
	if _busy or code.strip_edges().is_empty(): return
	# Convite (token de 48 hex, sozinho ou num link ?invite=) ou código curto da sala.
	var token := DuelService.invite_token(code)
	_refresh_list()
	var result := await _act(duel.join_invite.bind(token) if not token.is_empty() else duel.join.bind(code))
	if duel.in_room():
		_view = "room"
		render()
		animate_in()
	elif not result.ok and _view == "browse":
		# Sala cheia/fechada entre a lista e o clique: o erro aparece e a lista se atualiza.
		_load_rooms(false)


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


## Valores oferecidos nas listas (dentro dos limites do servidor: qse_duel_create /
## LocalDuelServer — jogadores 2–20, cartas 1–6, turno 15–180, seleção 10–120, desempate 4–12 e 1–4).
const FORM_FIELDS := [
	["max_players", "Jogadores máximos", [2, 4, 6, 8, 10, 12, 16, 20], "", "friends"],
	["cards_per_player", "Cartas por jogador", [1, 2, 3, 4, 5, 6], "", "cards"],
	["turn_seconds", "Tempo por turno (s)", [15, 30, 45, 60, 90, 120, 180], " s", "clock"],
	["selection_seconds", "Tempo de seleção (s)", [10, 15, 20, 30, 45, 60, 90, 120], " s", "hourglass"],
	["tiebreak_base", "Desempate: cartas com 2 jogadores", [4, 5, 6, 7, 8, 9, 10, 11, 12], " cartas", "swords"],
	["tiebreak_per_player", "Desempate: cartas a mais por jogador", [1, 2, 3, 4], " cartas", "layers"],
]
const MAX_DECKS := 5
const LibraryCatalog := preload("res://scripts/decks/deck_library_catalog.gd")
const DECK_TABS := ["Todos", "Favoritos", "Bombando", "Meus decks", "Comprados"]
var _deck_tab := "Todos"
var _deck_query := ""
var _iphone_deck_page := 0
var _deck_stats := {}


## Valores da lista; um valor atual válido que não esteja nela (sala antiga) é preservado.
static func field_options(values: Array, current: int) -> Array:
	var result := values.duplicate()
	if current > 0 and not result.has(current):
		result.append(current)
		result.sort()
	return result


## Define um valor do formulário (usado pela lista e pelos testes); sempre um inteiro da lista.
func set_form_value(key: String, value: int) -> void:
	var picker := _form.get("pickers", {}).get(key) as OptionButton
	if picker == null: return
	for i in picker.item_count:
		if picker.get_item_id(i) == value:
			picker.select(i)
			_form.values[key] = value
			_update_summary()
			return


func _panel_box(selected := false) -> StyleBoxFlat:
	var box := PremiumUI.flat(Color("#0f1b2b"), Color(PremiumUI.GOLD, 0.9) if selected else LINE, 14, 2 if selected else 1)
	box.set_content_margin_all(14)
	return box


func _section_head(icon_name: String, title: String, subtitle: String) -> HBoxContainer:
	if UIScale.is_iphone():
		title = {"Configuração da partida": "Regras", "Decks de personagens": "Decks", "Resumo da sala": "Resumo"}.get(title, title)
		subtitle = ""
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var icon := PremiumUI.icon_rect(icon_name, PremiumUI.GOLD, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	head.add_child(text)
	text.add_child(PremiumUI.plain(title, 20, Color("#f5f6fa")))
	if not subtitle.is_empty(): text.add_child(PremiumUI.plain(subtitle, 12, SECONDARY))
	if UIScale.is_iphone():
		# iPhone: o subtítulo quebra linha em vez de alargar a coluna.
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for line: Label in text.get_children():
			line.autowrap_mode = TextServer.AUTOWRAP_OFF
	return head


## Lista suspensa fechada: sem digitação e sem setas de incremento.
func _dropdown(key: String, values: Array, suffix: String, current: int) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = "Pick_" + key
	picker.fit_to_longest_item = false
	picker.custom_minimum_size = Vector2(112, 36)
	picker.alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker.add_theme_font_size_override("font_size", 16)
	for value: int in field_options(values, current):
		picker.add_item(str(value) + suffix, value)
		if value == current: picker.select(picker.item_count - 1)
	var box := PremiumUI.flat(Color("#152234"), LINE, 10, 1)
	box.content_margin_left = 16
	box.content_margin_right = 30
	var focus := PremiumUI.flat(Color("#152234"), PremiumUI.GOLD, 10, 2)
	focus.content_margin_left = 16
	focus.content_margin_right = 30
	for state in ["normal", "disabled"]: picker.add_theme_stylebox_override(state, box)
	for state in ["hover", "pressed", "focus", "hover_pressed"]: picker.add_theme_stylebox_override(state, focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		picker.add_theme_color_override(state, Color("#f5f6fa"))
	picker.add_theme_icon_override("arrow", PremiumUI.icon("chevron_down", Color.WHITE, 28))
	var popup := picker.get_popup()
	var list_box := PremiumUI.flat(Color("#0c1726"), Color(PremiumUI.GOLD, 0.6), 10, 1)
	list_box.set_content_margin_all(6)
	popup.add_theme_stylebox_override("panel", list_box)
	var hover := PremiumUI.flat(Color(PremiumUI.GOLD, 0.22), Color.TRANSPARENT, 6, 0)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override("font_color", Color("#f5f6fa"))
	popup.add_theme_color_override("font_hover_color", PremiumUI.GOLD_LIGHT)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_icon_override("radio_checked", PremiumUI.icon("check", PremiumUI.GOLD, 24))
	popup.add_theme_icon_override("radio_unchecked", ImageTexture.create_from_image(Image.create(24, 24, false, Image.FORMAT_RGBA8)))
	picker.item_selected.connect(func(index: int) -> void:
		_form.values[key] = picker.get_item_id(index)
		_update_summary())
	if UIScale.is_iphone(): PlayerUI.style_phone_picker(picker)
	return picker


func _iphone_rule_label(text: String) -> String:
	return {"Jogadores máximos": "Jogadores", "Cartas por jogador": "Cartas/jogador", "Tempo por turno (s)": "Turno (s)", "Tempo de seleção (s)": "Escolha (s)", "Tempo por turno": "Turno", "Tempo de seleção": "Escolha", "Desempate: cartas com 2 jogadores": "Desempate", "Desempate: cartas a mais por jogador": "Extra/jogador", "Desempate (2 jogadores)": "Desempate", "Desempate (a mais por jogador)": "Extra/jogador", "Bots permitidos": "Bots"}.get(text, text)

func _form_row(label_text: String, control: Control, note := "") -> VBoxContainer:
	if UIScale.is_iphone():
		label_text = _iphone_rule_label(label_text)
		note = ""
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	if UIScale.is_iphone(): wrap.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	wrap.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(texts)
	texts.add_child(PremiumUI.plain(label_text, 14, Color("#f5f6fa")))
	if not note.is_empty(): texts.add_child(PremiumUI.plain(note, 12, SECONDARY))
	# iPhone: nomes curtos em uma linha; não reduzir o piso de fonte.
	if UIScale.is_iphone():
		for text_label: Label in texts.get_children():
			text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	var rule := ColorRect.new()
	rule.color = Color(LINE, 0.6)
	rule.custom_minimum_size.y = 1
	wrap.add_child(rule)
	return wrap


func _render_form() -> void:
	var editing := duel.in_room()
	var base: Dictionary = duel.room.room.settings if editing else duel.defaults
	var local := duel.is_local()
	_header_extras(true, "CONFIGURAÇÕES DA SALA" if editing else ("PARTIDA LOCAL" if local else "CRIAR SALA"))
	_form = {"name": str(duel.room.room.name) if editing else ("Partida local" if local else "Mata-Mata"), "values": {}, "pickers": {},
		"public": bool(duel.room.room.is_public) if editing else not local, "bots_allowed": bool(base.get("bots_allowed", true)), "decks": []}
	for field: Array in FORM_FIELDS: _form.values[field[0]] = int(base.get(field[0], field[2][0]))
	var chosen: Array = base.get("deck_ids", []) if editing else []
	var available := _deck_entries()
	for deck: Dictionary in available: if chosen.has(deck.id): _form.decks.append(deck.id)
	body.add_theme_constant_override("separation", 12)
	if UIScale.is_iphone(): body.add_theme_constant_override("separation", 10)
	# Título da página.
	var intro := PanelContainer.new()
	intro.name = "FormIntro"
	var intro_box := _panel_box()
	intro_box.set_content_margin_all(12)
	intro.add_theme_stylebox_override("panel", intro_box)
	body.add_child(intro)
	if UIScale.is_iphone(): intro.hide() # O header já identifica Criar sala.
	var intro_row := HBoxContainer.new()
	intro_row.add_theme_constant_override("separation", 18)
	intro.add_child(intro_row)
	var slash := PremiumUI.icon_rect("pencil", PremiumUI.GOLD, 26)
	slash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro_row.add_child(slash)
	var intro_text := VBoxContainer.new()
	intro_text.add_theme_constant_override("separation", 0)
	intro_row.add_child(intro_text)
	var title := ("Configurações da sala" if editing else "Criar sala") if not local else ("Configurações da partida local" if editing else "Criar partida local")
	intro_text.add_child(PremiumUI.plain(title, 26, Color.WHITE))
	intro_text.add_child(PremiumUI.plain("Só neste aparelho, contra bots. Não aparece na lista online." if local else "Configure as regras e escolha o deck de personagens.", 18, SECONDARY))
	# Três áreas: configuração | decks | resumo.
	var columns := HBoxContainer.new()
	columns.name = "FormColumns"
	columns.add_theme_constant_override("separation", 18)
	body.add_child(columns)
	var main := PanelContainer.new()
	main.name = "FormMain"
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 2.6
	main.add_theme_stylebox_override("panel", _panel_box())
	columns.add_child(main)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 18)
	main.add_child(split)
	# Esquerda: configuração da partida.
	var config := VBoxContainer.new()
	config.name = "ConfigPanel"
	config.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config.add_theme_constant_override("separation", 8)
	if UIScale.is_iphone(): config.add_theme_constant_override("separation", 4)
	split.add_child(config)
	config.add_child(_section_head("filter", "Configuração da partida", ""))
	for field: Array in FORM_FIELDS:
		var picker := _dropdown(field[0], field[2], "", int(_form.values[field[0]]))
		_form.pickers[field[0]] = picker
		config.add_child(_form_row(field[1], picker))
	if not local:
		var visibility := OptionButton.new()
		visibility = _dropdown("public", [], "", 0)
		visibility.clear()
		visibility.add_item(tr("Pública"), 1)
		visibility.add_item(tr("Só por convite"), 0)
		visibility.select(0 if _form.public else 1)
		visibility.item_selected.connect(func(index: int) -> void:
			_form.public = visibility.get_item_id(index) == 1
			_form.values.erase("public")
			_update_summary(), CONNECT_DEFERRED)
		_form.pickers.public = visibility
		config.add_child(_form_row("Visibilidade", visibility))
	var bots := CheckButton.new()
	bots.name = "BotsToggle"
	if UIScale.is_iphone(): bots.custom_minimum_size = Vector2(64, 36)
	bots.button_pressed = bool(_form.bots_allowed)
	bots.toggled.connect(func(value: bool) -> void:
		_form.bots_allowed = value
		_update_summary())
	config.add_child(_form_row("Bots permitidos", bots, "Permite o preenchimento da sala com bots."))
	var rule := ColorRect.new()
	rule.color = Color(LINE, 0.6)
	rule.custom_minimum_size.x = 1
	split.add_child(rule)
	# Centro: decks de personagens.
	var decks := VBoxContainer.new()
	decks.name = "DeckPanel"
	decks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decks.size_flags_stretch_ratio = 1.35
	decks.add_theme_constant_override("separation", 14)
	if UIScale.is_iphone(): decks.add_theme_constant_override("separation", 6)
	split.add_child(decks)
	var deck_heading := _section_head("cards", "Decks de personagens", str(TranslationServer.translate("Escolha o conjunto de personagens da sala (até %d).")) % MAX_DECKS)
	decks.add_child(deck_heading)
	if UIScale.is_iphone(): deck_heading.hide() # Busca e filtros já identificam a galeria.
	var search_box := PanelContainer.new()
	var field_box := PremiumUI.flat(Color("#0a1626"), LINE, 12, 1)
	field_box.content_margin_left = 18
	search_box.add_theme_stylebox_override("panel", field_box)
	decks.add_child(search_box)
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 12)
	search_box.add_child(search_row)
	var lens := PremiumUI.icon_rect("search", Color.WHITE, 24)
	lens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search_row.add_child(lens)
	var search := LineEdit.new()
	search.name = "DeckSearch"
	search.placeholder_text = tr("Buscar deck...")
	search.text = _deck_query
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 38
	search.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "focus", "read_only"]: search.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	search.text_changed.connect(func(value: String) -> void:
		_deck_query = value
		_refresh_deck_grid())
	search_row.add_child(search)
	# Quebra de linha só quando não cabe (no PC fica igual; no iPhone as abas descem).
	var tabs := HFlowContainer.new()
	tabs.name = "DeckTabs"
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	decks.add_child(tabs)
	for tab: String in DECK_TABS:
		if tab == "Comprados" and not ReleaseFeatures.COMMERCE_ENABLED: continue
		var icon_name: String = {"Todos": "layers", "Favoritos": "star", "Bombando": "bolt", "Meus decks": "user", "Comprados": "crown"}[tab]
		var chip := Button.new()
		chip.name = "DeckTab_" + tab.replace(" ", "_")
		chip.text = tr(tab)
		chip.toggle_mode = true
		chip.button_pressed = tab == _deck_tab
		chip.icon = PremiumUI.icon(icon_name, PremiumUI.INK if tab == _deck_tab else PremiumUI.GOLD, 32)
		chip.add_theme_constant_override("icon_max_width", 14)
		chip.add_theme_font_size_override("font_size", 12)
		chip.custom_minimum_size.y = 32
		if tab == _deck_tab: PremiumUI.style_gold(chip)
		else: _secondary(chip)
		chip.pressed.connect(func() -> void:
			_deck_tab = tab
			for other in tabs.get_children():
				var active: bool = other.name == "DeckTab_" + tab.replace(" ", "_")
				(other as Button).set_pressed_no_signal(active)
				var other_name := str(other.name).trim_prefix("DeckTab_").replace("_", " ")
				(other as Button).icon = PremiumUI.icon({"Todos": "layers", "Favoritos": "star", "Bombando": "bolt", "Meus decks": "user", "Comprados": "crown"}[other_name], PremiumUI.INK if active else PremiumUI.GOLD, 32)
				if active: PremiumUI.style_gold(other)
				else: _secondary(other)
			_refresh_deck_grid()
			if tab == "Bombando": _load_deck_stats())
		tabs.add_child(chip)
	var grid := GridContainer.new()
	grid.name = "DeckChoices"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	if UIScale.is_iphone():
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
	decks.add_child(grid)
	# Direita: resumo.
	var summary := PanelContainer.new()
	summary.name = "FormSummary"
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.custom_minimum_size.x = 270 if UIScale.is_iphone() else 360
	summary.clip_contents = true
	summary.add_theme_stylebox_override("panel", _panel_box())
	columns.add_child(summary)
	# Ações.
	var actions := HBoxContainer.new()
	actions.name = "FormActions"
	actions.custom_minimum_size.y = 76
	actions.add_theme_constant_override("separation", 18)
	# Footer outside the scroll: buttons stay fully visible without changing scale.
	$Margin/Column.add_child(actions)
	_iphone_room_actions = actions
	var save := Button.new()
	save.name = "SubmitRoom"
	save.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save.text = tr("Salvar" if editing else "Criar sala")
	save.icon = PremiumUI.icon("play", PremiumUI.INK, 32)
	save.add_theme_constant_override("icon_max_width", 22)
	save.add_theme_font_size_override("font_size", 17)
	save.custom_minimum_size = Vector2(240, 50)
	PremiumUI.style_gold(save)
	save.pressed.connect(_submit_form)
	actions.add_child(save)
	var cancel := Button.new()
	cancel.name = "CancelForm"
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel.text = tr("Cancelar")
	cancel.add_theme_font_size_override("font_size", 17)
	cancel.custom_minimum_size = Vector2(170, 50)
	_secondary(cancel)
	cancel.pressed.connect(func() -> void:
		_view = "room" if duel.in_room() else "browse"
		if not duel.in_room(): await duel.use_online()
		render())
	actions.add_child(cancel)
	_refresh_deck_grid()
	_update_summary()


## Decks jogáveis no Mata-Mata (lista do servidor), com capa, favorito e popularidade reais.
func _deck_entries() -> Array:
	var list: Array = duel.decks if not duel.decks.is_empty() else duel.room.get("room", {}).get("decks", [])
	var result: Array = []
	var store := DeckDrafts.for_current()
	for deck: Dictionary in list:
		var id := str(deck.get("id", ""))
		if not LibraryCatalog.can_access(id): continue
		var item := LibraryCatalog.find_deck(id)
		var cover := services.community_decks.cover_image(id) if CommunityDecksService.is_ref(id) else str(deck.get("cover",""))
		result.append({"id": id, "name": LibraryCatalog.display_name(id, str(deck.get("name", id))), "size": int(deck.get("size", 0)),
			"cover": DeckCover.resolve_item(item) if not item.is_empty() else cover, "favorite": store.is_favorite(id),
			"ref": ("creator:"+services.community_decks.source_deck_id(id)) if CommunityDecksService.is_ref(id) else "official:"+id, "community":CommunityDecksService.is_ref(id)})
	return result


func _deck_visible(entry: Dictionary) -> bool:
	var term := LibraryCatalog.search_key(_deck_query)
	if not term.is_empty() and not LibraryCatalog.search_key(str(entry.name)).contains(term): return false
	match _deck_tab:
		"Favoritos": return bool(entry.favorite)
		"Bombando": return float(_deck_stats.get(str(entry.ref), {}).get("score", 0.0)) > 0.0
		"Meus decks": return bool(entry.get("community",false))
		"Comprados": return false
	return true


func _refresh_deck_grid() -> void:
	var grid := body.find_child("DeckChoices", true, false) as GridContainer
	if grid == null: return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var entries := _deck_entries()
	var shown := entries.filter(_deck_visible)
	var holder := grid.get_parent()
	var old := holder.get_node_or_null("DeckEmpty")
	if old != null:
		holder.remove_child(old)
		old.queue_free()
	var pager := holder.get_node_or_null("DeckPager")
	if pager != null:
		holder.remove_child(pager)
		pager.queue_free()
	if shown.is_empty():
		var reasons := {"Favoritos": "Nenhum deck favorito disponível para o Mata-Mata.", "Bombando": "Ainda não há partidas registradas para medir os decks em alta.",
			"Meus decks": "Seus decks ainda não podem ser usados no Mata-Mata.", "Comprados": "A loja de decks ainda não está disponível."}
		var empty := PremiumUI.plain(reasons.get(_deck_tab, "Nenhum deck encontrado."), 13, SECONDARY)
		empty.name = "DeckEmpty"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(260, 120)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(empty)
		return
	if not shown.is_empty():
		var pages := maxi(1, ceili(shown.size() / 2.0))
		_iphone_deck_page = clampi(_iphone_deck_page, 0, pages - 1)
		shown = shown.slice(_iphone_deck_page * 2, (_iphone_deck_page + 1) * 2)
		if pages > 1:
			var navigation := HBoxContainer.new()
			navigation.name = "DeckPager"
			navigation.add_theme_constant_override("separation", 8)
			holder.add_child(navigation)
			for direction: int in [-1, 1]:
				var button := PlayerUI.button("‹" if direction < 0 else "›", func() -> void:
					_iphone_deck_page += direction
					_refresh_deck_grid())
				button.custom_minimum_size = Vector2(64, 44)
				button.disabled = _iphone_deck_page + direction < 0 or _iphone_deck_page + direction >= pages
				navigation.add_child(button)
			var page := PlayerUI.label("%d / %d" % [_iphone_deck_page + 1, pages], 20)
			page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			navigation.add_child(page)
			navigation.move_child(page, 1)
	for entry: Dictionary in shown: grid.add_child(_deck_choice(entry))


var _deck_decision: Control
func _deck_choice(entry: Dictionary) -> Control:
	var selected: bool = (_form.decks as Array).has(entry.id)
	var card := Button.new()
	card.name = "DeckChoice_" + str(entry.id)
	card.toggle_mode = true
	card.button_pressed = selected
	# T24 iOS: capa mais alta e arte inteira (antes, uma faixa panorâmica cortava os personagens).
	card.custom_minimum_size = Vector2(190, 280)
	if UIScale.is_iphone(): card.custom_minimum_size = Vector2(160, 216)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.tooltip_text = "%s (%d)" % [entry.name, entry.size]
	var normal := PremiumUI.flat(Color("#101d2d"), LINE, 12, 1, 0)
	var chosen := PremiumUI.flat(Color("#152438"), PremiumUI.GOLD, 12, 3, 0)
	chosen.shadow_color = Color(PremiumUI.GOLD, 0.35)
	chosen.shadow_size = 10
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var box: StyleBoxFlat = chosen if selected else normal
		if state == "focus":
			box = PremiumUI.flat(Color.TRANSPARENT, PremiumUI.GOLD_LIGHT, 12, 2, 0)
			box.draw_center = false
		card.add_theme_stylebox_override(state, box)
	# Capa INTEIRA sobre o fundo escuro do card, sem distorção nem corte.
	var has_cover := DeckCover.exists(str(entry.cover))
	var cover := TextureRect.new()
	cover.name = "Cover"
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover.texture = DeckCover.load_texture(str(entry.cover)) if has_cover else null
	card.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.offset_left = 6
	cover.offset_top = 6
	cover.offset_right = -6
	cover.offset_bottom = -36
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.02, 0.03, 0.06, 0.62)
	card.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -34
	var label := PremiumUI.plain("%s (%d)" % [entry.name, entry.size], 13, Color.WHITE, false)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	shade.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var star := Button.new()
	star.name = "Favorite"
	star.toggle_mode = true
	star.button_pressed = bool(entry.favorite)
	star.flat = true
	star.icon = PremiumUI.icon("star" if entry.favorite else "star_outline", PremiumUI.GOLD if entry.favorite else Color.WHITE, 32)
	star.tooltip_text = tr("Remover dos favoritos" if entry.favorite else "Adicionar aos favoritos")
	star.add_theme_constant_override("icon_max_width", 20)
	card.add_child(star)
	star.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	star.position += Vector2(-38, 4)
	star.toggled.connect(func(value: bool) -> void:
		var store := DeckDrafts.for_current()
		if store.set_favorite(str(entry.id), value):
			var sync := CreatorSync.for_current(store)
			if sync.available(): sync.set_remote_favorite(str(entry.id), value)
		_refresh_deck_grid())
	card.toggled.connect(func(value: bool) -> void:
		card.set_pressed_no_signal(selected)
		if is_instance_valid(_deck_decision): _deck_decision.queue_free()
		var commit := func() -> void:
			if is_instance_valid(_deck_decision): _deck_decision.queue_free()
			var picked: Array = _form.decks
			if value and not picked.has(entry.id):
				if picked.size() >= MAX_DECKS:
					card.set_pressed_no_signal(false)
					banner.show_state("error", tr("Escolha no máximo %d decks.") % MAX_DECKS)
					return
				picked.append(entry.id)
			elif not value:
				picked.erase(entry.id)
			_refresh_deck_grid()
			_update_summary()
		_deck_decision=PlayerUI.decision_controls(card,commit,func() -> void:
			if is_instance_valid(_deck_decision): _deck_decision.queue_free(),"deck"))
	return card


func _load_deck_stats() -> void:
	if not _deck_stats.is_empty() or not services.session.authenticated(): return
	var refs: Array = _deck_entries().map(func(e: Dictionary) -> String: return str(e.ref))
	var result: Dictionary = await services.client.call_rpc("qse_deck_stats", {"p_refs": refs})
	if result.ok and result.data is Array:
		for row: Variant in result.data:
			if row is Dictionary: _deck_stats[str(row.get("deck_ref", ""))] = row
		if _view == "form": _refresh_deck_grid()


## Resumo: exatamente os valores que vão para o DuelService.
func _update_summary() -> void:
	var panel := body.find_child("FormSummary", true, false) as PanelContainer
	if panel == null: return
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	column.name = "SummaryColumn"
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_section_head("inbox", "Resumo da sala", "Confira as configurações antes de criar."))
	var entries := _deck_entries().filter(func(e: Dictionary) -> bool: return (_form.decks as Array).has(e.id))
	var picked := PanelContainer.new()
	picked.name = "SummaryDecks"
	var picked_box := _panel_box(true)
	picked_box.set_content_margin_all(8)
	picked.add_theme_stylebox_override("panel", picked_box)
	column.add_child(picked)
	var picked_row := HBoxContainer.new()
	picked_row.add_theme_constant_override("separation", 14)
	picked.add_child(picked_row)
	if not entries.is_empty():
		var thumb := TextureRect.new()
		thumb.custom_minimum_size = Vector2(84, 58)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		thumb.texture = DeckCover.framed(str(entries[0].cover), 110.0 / 76.0, DeckCover.PORTRAIT_FOCUS) if DeckCover.exists(str(entries[0].cover)) else null
		picked_row.add_child(thumb)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 2)
	picked_row.add_child(names)
	var total := 0
	for entry: Dictionary in entries: total += int(entry.size)
	var head_text := "%s (%d)" % [entries[0].name, entries[0].size] if entries.size() == 1 else (tr("%d decks · %d cartas") % [entries.size(), total] if not entries.is_empty() else tr("Nenhum deck"))
	var head := PremiumUI.plain("★  " + head_text, 16, Color.WHITE, false)
	head.name = "SummaryDeckName"
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.custom_minimum_size.x = 120
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(head)
	var detail := ", ".join(entries.map(func(e: Dictionary) -> String: return str(e.name))) if entries.size() > 1 else tr("Deck selecionado")
	var sub := PremiumUI.plain(detail, 12, SECONDARY, false)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.custom_minimum_size.x = 120
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(sub)
	var values: Dictionary = _form.values
	var rows := [["friends", "Jogadores máximos", str(values.max_players)], ["cards", "Cartas por jogador", str(values.cards_per_player)],
		["clock", "Tempo por turno", "%d s" % int(values.turn_seconds)], ["hourglass", "Tempo de seleção", "%d s" % int(values.selection_seconds)],
		["swords", "Desempate (2 jogadores)", "%d cartas" % int(values.tiebreak_base)], ["layers", "Desempate (a mais por jogador)", "%d cartas" % int(values.tiebreak_per_player)]]
	if not duel.is_local(): rows.append(["friends", "Visibilidade", tr("Pública") if _form.public else tr("Só por convite")])
	rows.append(["user", "Bots permitidos", tr("Sim") if _form.bots_allowed else tr("Não")])
	for item: Array in rows:
		var line := HBoxContainer.new()
		line.name = "Summary_" + str(item[1]).replace(" ", "_")
		line.add_theme_constant_override("separation", 14)
		var icon := PremiumUI.icon_rect(item[0], Color.WHITE, 20)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(icon)
		var label := PremiumUI.plain(_iphone_rule_label(item[1]) if UIScale.is_iphone() else str(item[1]), 14, Color("#e6ebf2"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(label)
		var value := PremiumUI.plain(item[2], 14, PremiumUI.GOLD if item[1] == "Bots permitidos" else Color.WHITE, false)
		value.name = "Value"
		line.add_child(value)
		column.add_child(line)
		var rule := ColorRect.new()
		rule.color = Color(LINE, 0.5)
		rule.custom_minimum_size.y = 1
		column.add_child(rule)


func _submit_form() -> void:
	var settings := {"bots_allowed": bool(_form.bots_allowed)}
	for field: Array in FORM_FIELDS: settings[field[0]] = int(_form.values[field[0]])
	var decks: Array = (_form.decks as Array).duplicate()
	if decks.is_empty():
		banner.show_state("error", tr("Escolha pelo menos um deck."))
		return
	settings.deck_ids = decks
	var room_name := str(_form.name)
	var public: bool = bool(_form.public) and not duel.is_local()
	var result := await _act(duel.configure.bind(room_name, public, settings) if duel.in_room() else duel.create.bind(room_name, public, settings))
	if result.ok:
		_view = "room"
		render()
		animate_in()


# --- Lobby da sala -------------------------------------------------------------------------
func _render_room() -> void:
	var data: Dictionary = duel.room.room
	var settings: Dictionary = data.settings
	if UIScale.is_iphone(): body.add_theme_constant_override("separation", 10)
	var me := duel.me()
	var admin := duel.is_admin()
	var header := PlayerUI.row(body)
	header.add_theme_constant_override("separation", 12)
	var titles := PlayerUI.column(header)
	titles.add_theme_constant_override("separation", 0)
	var room_title := tr("Partida local") if duel.is_local() else tr("Sala %s") % str(data.get("code", data.name))
	titles.add_child(PlayerUI.label(room_title, 30, Color.WHITE))
	var players := (duel.room.members as Array).filter(func(m: Dictionary) -> bool: return m.role == "player")
	var state := "No lobby  ·  %d/%d jogadores" % [players.size(), int(settings.max_players)]
	if str(data.status) == "in_match": state = "Partida em andamento"
	if duel.is_local():
		titles.add_child(PlayerUI.label(state + "  ·  Partida local, só neste aparelho", 17, Color("#c9d6e6")))
		var tag := PlayerUI.pill("PARTIDA LOCAL", "equipped")
		tag.name = "LocalBadge"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(tag)
	else:
		titles.add_child(PlayerUI.label(state + ("  ·  Sala pública" if data.is_public else "  ·  Só por convite"), 17, Color("#c9d6e6")))
		var code := PlayerUI.button(str(TranslationServer.translate("Código  %s")) % str(data.code), func() -> void:
			DisplayServer.clipboard_set(str(data.code))
			banner.show_state("success", tr("Código copiado: %s") % str(data.code)))
		code.tooltip_text = tr("Copiar código de convite")
		code.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(code)
	# Lobby audio is opt-in; reuse the same service when transitioning to battle.
	if not duel.is_local() and str(data.status) == "lobby":
		var lobby_voice := preload("res://scripts/ui/battle/battle_voice.gd").new()
		lobby_voice.name = "LobbyVoice"
		lobby_voice.setup(services)
		body.add_child(lobby_voice)
	if str(data.status) == "closed" and duel.match().is_empty():
		_render_closed()
		return
	if str(data.status) in ["in_match","closed"] and not duel.match().is_empty():
		header.hide()
		heading.text = tr("Batalha · Partida local") if duel.is_local() else tr("Batalha")
		if not is_instance_valid(_match_view):
			_match_view = preload("res://scripts/ui/screens/duel_match_view.gd").new()
			_match_view.name = "Match"
			_match_view.setup(duel, services.inventory, self, _act)
		body.add_child(_match_view)
		_match_view.refresh()
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
	var summary := str(TranslationServer.translate("%d cartas por jogador  ·  %ds por turno  ·  %ds de seleção  ·  Bots %s  ·  Decks: %s")) % [int(settings.cards_per_player),
		int(settings.turn_seconds), int(settings.selection_seconds), "permitidos" if settings.bots_allowed else "desativados",
		", ".join((data.get("decks", []) as Array).map(func(d: Dictionary) -> String: return LibraryCatalog.display_name(str(d.get("id", "")), str(d.get("name", "")))))]
	body.add_child(PlayerUI.label(summary, 17, Color("#c9d6e6")))
	var actions := PlayerUI.flow(body)
	if UIScale.is_iphone():
		actions.reparent($Margin/Column)
		actions.name = "RoomActions"
		_iphone_room_actions = actions
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


## Sala encerrada com você ainda nela: nenhum jogador real ficou vivo (regra do servidor:
## nunca há bot campeão).
func _render_closed() -> void:
	var notice := PlayerUI.label("Partida encerrada: nenhum jogador real continuou vivo, então não há campeão.", 20, PlayerUI.GOLD)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.custom_minimum_size.y = 140
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_child(notice)
	var row := PlayerUI.row(body)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var back := PlayerUI.button("Voltar", _leave_room)
	PlayerUI.style_button(back, true)
	row.add_child(back)


## Sair durante a partida elimina o jogador (regra do servidor); no lobby, só sai.
func _leave_room() -> void:
	await duel.leave()
	await duel.use_online()
	_view = "browse"
	_rooms = []
	render()
	if _online(): _load_rooms(false)


## Cartão do participante: retrato da skin equipada, nome e selos (ADM, BOT, VOCÊ, espectador).
func _member_card(member: Dictionary, admin: bool, status: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(190, 0)
	var plate := PlayerUI.plate(bool(member.get("is_you", false)))
	plate.content_margin_top = 14
	plate.content_margin_bottom = 18
	if UIScale.is_iphone():
		plate.content_margin_top = 8
		plate.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", plate)
	var column := PlayerUI.column(card)
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait := PlayerUI.portrait(str(member.get("character_id", "")), 112 if UIScale.is_iphone() else SKIN_SIZE)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not bool(member.get("online", true)) or member.get("role") == "spectator": portrait.modulate = Color(0.55, 0.58, 0.65)
	column.add_child(portrait)
	# Um único avatar 3D em repouso na sala; os demais são apresentados um a um
	# antes da partida. Não multiplica viewports pelo número de participantes.
	if member.get("is_you",false) and status=="lobby":
		var skin := str(member.get("character_id",""))
		var entries := CharacterCatalog.load_entries().filter(func(e: Dictionary)->bool:return str(e.id)==skin)
		if not entries.is_empty() and entries[0].get("animations",{}).has("anim_2"):
			if not is_instance_valid(_room_stage):
				_room_stage=preload("res://scenes/lobby/lobby_stage.tscn").instantiate()
				_room_stage.name="LobbyAvatarCurrent"
			_room_stage.custom_minimum_size=portrait.custom_minimum_size
			_room_stage.modulate=portrait.modulate
			_room_stage.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
			column.add_child(_room_stage)
			portrait.hide()
			if _room_stage_skin!=skin:
				_room_stage_skin=skin
				CharacterSlot.prepare_participants([{"skin_id":skin}])
				_animate_room_avatar(entries[0])
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


func _animate_room_avatar(source: Dictionary) -> void:
	var entry := source.duplicate(true)
	entry.animations={"base":source.animations.base,"anim_2":source.animations.anim_2}
	while CharacterSlot.entry_pending(entry):
		await get_tree().process_frame
		if not is_inside_tree() or not is_instance_valid(_room_stage): return
	if not is_instance_valid(_room_stage) or not _room_stage.is_inside_tree() or _room_stage_skin!=str(entry.id): return
	entry.idle="anim_2"
	_room_stage.show_character(entry)


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
	if _battle_layout: return
	PlayerUI.cascade(body)
	var members := body.get_node_or_null("Members")
	if members != null: PlayerUI.cascade(members, 0, 0.03)


func _exit_tree() -> void:
	if is_instance_valid(_room_stage) and _room_stage.get_parent()==null: _room_stage.free()
	# The match is detached while another room view is rendered.
	if is_instance_valid(_match_view) and _match_view.get_parent() == null: _match_view.free()


func _set_battle_layout(enabled: bool) -> void:
	_battle_layout = enabled
	$Margin/Column/Header.visible = not enabled
	$Margin/Column/Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if enabled else ScrollContainer.SCROLL_MODE_AUTO
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL if enabled else Control.SIZE_FILL
	if enabled:
		banner.hide()
		$Margin/Column.add_theme_constant_override("separation",0)
		var safe := DisplayServer.get_display_safe_area()
		var window := get_window()
		var mobile := OS.has_feature("mobile")
		# Safe-area coordinates are physical; margin coordinates are UI points.
		var density := maxf(UIScale.device_scale(),0.01)
		var left := maxf(float(safe.position.x-window.position.x),0) / density if mobile else 0.0
		var right := maxf(float(window.position.x+window.size.x-safe.end.x),0) / density if mobile else 0.0
		$Margin.add_theme_constant_override("margin_left",12+ceili(left))
		$Margin.add_theme_constant_override("margin_right",12+ceili(right))
		var top := maxf(float(safe.position.y-window.position.y),0) / density if mobile else 0.0
		var bottom := maxf(float(window.position.y+window.size.y-safe.end.y),0) / density if mobile else 0.0
		$Margin.add_theme_constant_override("margin_top",8+ceili(top))
		$Margin.add_theme_constant_override("margin_bottom",8+ceili(bottom))
	else:
		super._adapt_scale()
	_refit_margin.call_deferred()


func _adapt_scale() -> void:
	super._adapt_scale()
	if is_visible_in_tree() and _view == "browse" and not _battle_layout and _compact() != _compact_layout: render.call_deferred()
	if _battle_layout: _set_battle_layout(true)
