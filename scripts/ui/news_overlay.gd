class_name NewsOverlay
extends CanvasLayer
## Central de novidades e resgates gratuitos. A campanha é lida do GAME e a
## leitura é registrada por conta; nunca apresenta o mesmo anúncio a cada login.
const BLUE := Color("#0b1022")
const PANEL := Color("#151c32")
const CYAN := Color("#5feaf5")
const LIME := Color("#dbff72")
const MUTED := Color("#9daecb")
var _services: PlayerServices
var _backdrop: ColorRect
var _content: VBoxContainer
var _tab := "deck"
var _notice := ""
var _working := false


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_services = PlayerServices.current
	_backdrop = ColorRect.new()
	_backdrop.color = BLUE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	var margin := MarginContainer.new()
	margin.name = "RewardSafeArea"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var compact := get_viewport().get_visible_rect().size.y < 600
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if compact else 32)
	_backdrop.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.name = "RewardScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "RewardContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14 if compact else 22)
	scroll.add_child(_content)
	if _services != null:
		_services.rewards.changed.connect(_render)
	_render()
	_load.call_deferred()


func _load() -> void:
	if _services == null or not _services.session.authenticated(): return
	if _services.rewards.state != "success":
		await _services.rewards.refresh()
	if not is_inside_tree(): return
	_render()
	if _services.rewards.state == "success" and not _services.rewards.seen:
		_services.rewards.mark_seen.call_deferred()


func _render() -> void:
	if not is_instance_valid(_content): return
	for child in _content.get_children(): child.queue_free()
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	var compact := view_size.y < 600
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_content.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	header.add_child(title_box)
	title_box.add_child(_label("QUEM SOU EU  /  CENTRAL DE NOVIDADES", 13 if compact else 17, CYAN))
	title_box.add_child(_label("NOVIDADES & RESGATES", 27 if compact else 42, Color.WHITE))
	var close := _button("✕  FECHAR", false)
	close.name = "CloseNews"
	close.custom_minimum_size = Vector2(110, 42)
	close.pressed.connect(queue_free)
	header.add_child(close)
	var divider := ColorRect.new()
	divider.color = Color(CYAN, 0.38)
	divider.custom_minimum_size.y = 2
	_content.add_child(divider)
	if _services == null or not _services.session.authenticated():
		_content.add_child(_label("Entre em sua conta para receber os presentes oficiais e guardar seus resgates.", 20, MUTED))
		var login := _button("ENTRAR NA CONTA", true)
		login.pressed.connect(_open_account)
		_content.add_child(login)
		return
	var rewards: OfficialRewardsService = _services.rewards
	if rewards.state == "loading" or rewards.state == "empty":
		_content.add_child(_label("Buscando novidades oficiais…", 19, MUTED))
		return
	if rewards.state != "success":
		_content.add_child(_label("Não foi possível consultar seus presentes. Nenhum resgate foi alterado.", 18, MUTED))
		var retry := _button("TENTAR NOVAMENTE", true)
		retry.pressed.connect(func() -> void: rewards.refresh())
		_content.add_child(retry)
		return
	if rewards.campaign.is_empty():
		_content.add_child(_label("Nenhuma campanha ativa por enquanto. Quando houver novidades, elas aparecerão aqui.", 20, MUTED))
		_add_other_news()
		return
	var hero := HBoxContainer.new()
	hero.name = "OfficialDropHero"
	hero.add_theme_constant_override("separation", 22)
	_content.add_child(hero)
	var story := VBoxContainer.new()
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.add_theme_constant_override("separation", 8 if compact else 12)
	hero.add_child(story)
	story.add_child(_label("PRESENTE DA EQUIPE · POR TEMPO INDETERMINADO", 13 if compact else 17, LIME))
	story.add_child(_label(str(rewards.campaign.get("title", "NOVOS DECKS OFICIAIS")), 25 if compact else 36, Color.WHITE))
	story.add_child(_label("NOVOS DECKS ADICIONADOS À COMUNIDADE OFICIAL", 15 if compact else 21, CYAN))
	var description := _label(str(rewards.campaign.get("description", "")), 13 if compact else 17, MUTED)
	description.max_lines_visible = 3
	story.add_child(description)
	story.add_child(_label(str(rewards.campaign.get("subtitle", "")), 15 if compact else 20, LIME))
	if view_size.x > 960 and view_size.y > 450:
		var image := TextureRect.new()
		image.name = "CampaignImage"
		image.custom_minimum_size = Vector2(minf(view_size.x * 0.27, 400.0), 170)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture = _cover("nostalgia_web")
		hero.add_child(image)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	_content.add_child(tabs)
	for option in [["deck", "DECKS GRÁTIS"], ["skin", "SKINS"]]:
		var btn := _button(str(option[1]), _tab == option[0])
		btn.name = "Tab" + str(option[0]).capitalize()
		btn.pressed.connect(_switch.bind(str(option[0])))
		tabs.add_child(btn)
	if not _notice.is_empty():
		_content.add_child(_label(_notice, 17, LIME))
	var grid := GridContainer.new()
	grid.name = "RewardOffers"
	grid.columns = 4 if view_size.x > 1450 else (3 if view_size.x > 1080 else 2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	var found := false
	for offer: Dictionary in rewards.offers:
		if str(offer.get("kind", "")) != _tab: continue
		found = true
		_add_offer(grid, offer, view_size, compact)
	if not found:
		_content.add_child(_label("Novas skins resgatáveis aparecerão aqui quando forem lançadas. As skins da História continuam com seus desbloqueios próprios." if _tab == "skin" else "Nenhum deck disponível nesta campanha.", 17, MUTED))
	_add_other_news()


func _add_offer(grid: GridContainer, offer: Dictionary, viewport: Vector2, compact: bool) -> void:
	var panel := PanelContainer.new()
	panel.name = "Offer_" + str(offer.get("id", ""))
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color(CYAN, 0.22), 12))
	var width := maxf(160.0, (viewport.x - (52 if compact else 100)) / float(grid.columns) - 16)
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	var item_id := str(offer.get("item_id", ""))
	if _tab == "deck":
		var art := TextureRect.new()
		art.name = "RewardCover"
		art.texture = _cover(item_id)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.custom_minimum_size.y = 78 if compact else 160
		col.add_child(art)
	col.add_child(_label("GRÁTIS   ·   OFICIAL", 12 if compact else 14, LIME))
	var name := _label(str(offer.get("title", "Coleção")), 16 if compact else 22, Color.WHITE)
	name.max_lines_visible = 2
	col.add_child(name)
	var info := _label(str(offer.get("description", "")), 12 if compact else 15, MUTED)
	info.max_lines_visible = 2 if compact else 3
	col.add_child(info)
	var claimed := bool(offer.get("claimed", false))
	var action := _button("✓  RESGATADO" if claimed else "RESGATAR GRÁTIS", not claimed)
	action.name = "Claim_" + str(offer.get("id", ""))
	action.disabled = claimed or _working
	action.custom_minimum_size.y = 40 if compact else 49
	action.pressed.connect(_claim.bind(str(offer.get("id", ""))))
	col.add_child(action)


func _claim(offer_id: String) -> void:
	if _working or _services == null: return
	_working = true
	_notice = "Registrando o presente na sua conta…"
	_render()
	var result: Dictionary = await _services.rewards.claim(offer_id)
	_working = false
	if not is_inside_tree(): return
	if result.ok and result.data is Dictionary and result.data.get("ok", false) == true:
		_notice = "PRESENTE RESGATADO! Este deck agora está na sua coleção."
	else:
		_notice = "Não foi possível resgatar. Verifique sua conexão ou tente novamente."
	_render()


func _switch(value: String) -> void:
	_tab = value
	_notice = ""
	_render()


func _open_account() -> void:
	queue_free()
	var menu := get_parent()
	var navigator: Node = menu.get_node_or_null("Navigation") if menu != null else null
	if navigator != null: navigator.call("open", "account", {})


func _add_other_news() -> void:
	var more := _button("VER OUTRAS NOTÍCIAS DO JOGO", false)
	more.name = "MoreNews"
	more.pressed.connect(_legacy_news)
	_content.add_child(more)


func _legacy_news() -> void:
	var carousel := PresentationCarousel.new()
	carousel.name = "OtherNews"
	carousel.set_cards("news")
	carousel.show_close = true
	carousel.allow_skip = false
	carousel.dwell_seconds = 5.0
	carousel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	carousel.close_requested.connect(carousel.queue_free)
	_backdrop.add_child(carousel)
	carousel.focus_close()


func _cover(deck_id: String) -> Texture2D:
	var file := ""
	match deck_id:
		"nostalgia_web": file = "carta_05"
		"sol_nascente": file = "carta_01"
		"pinturas": file = "carta_03"
		"lendas_urbanas": file = "loira_do_banheiro"
	if file.is_empty(): return null
	var path := "res://assets/duel/decks/oficial/%s/%s.png" % [deck_id, file]
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


func _style(background: Color, outline: Color, inset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(inset)
	return style


func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(110, 42)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", BLUE if primary else Color.WHITE)
	var base := LIME if primary else Color("#222d48")
	button.add_theme_stylebox_override("normal", _style(base, CYAN if primary else Color("#4c6389"), 10))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.12), CYAN, 10))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.1), CYAN, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("#2a3450"), Color("#37435f"), 10))
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var other := _backdrop.get_node_or_null("OtherNews")
		if other != null: other.queue_free()
		else: queue_free()
		get_viewport().set_input_as_handled()
