class_name NewsOverlay
extends CanvasLayer
## T30 — Centro de presentes sobre a home, usando apenas ofertas recebidas do GAME.
## UI reativa: RLS/posse e recibo continuam 100% no servidor, sem valores locais.
const DeckCatalog = preload("res://scripts/decks/deck_library_catalog.gd")
const NAVY := Color("#0a101c")
const PANEL := Color("#111b2b")
const CARD := Color("#111a27")
const SURFACE := Color("#1d2937")
const GOLD := Color("#f4bd4e")
const GOLD_SOFT := Color("#eac47c")
const WHITE := Color("#f7f8fa")
const MUTED := Color("#b3bdc9")
const BORDER := Color("#685941")
const ICON_GIFT := preload("res://assets/icons/vector/icon_reward_gift.svg")
const ICON_DECK := preload("res://assets/icons/vector/icon_reward_deck.svg")
const ICON_SKIN := preload("res://assets/icons/vector/icon_reward_skin.svg")

var _services: PlayerServices
var _shade: ColorRect
var _modal: Panel
var _margin: MarginContainer
var _stack: VBoxContainer
var _tab := "deck"
var _history := false
var _sort_mode := "recent"
var _notice := ""
var _working := false
var _compact := false
var _modal_width := 0.0
var _content_width := 0.0


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_services = PlayerServices.current
	_shade = ColorRect.new()
	_shade.name = "NewsInputShield"
	_shade.color = Color(0.008, 0.017, 0.035, 0.67)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_modal = Panel.new()
	_modal.name = "RewardWindow"
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.clip_contents = true
	_modal.add_theme_stylebox_override("panel", _style(PANEL, Color(GOLD_SOFT, 0.54), 16, 1))
	_shade.add_child(_modal)
	PlayerUI.apply_theme(_modal)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(_margin)
	_stack = VBoxContainer.new()
	_stack.name = "RewardContent"
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(_stack)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if _services != null:
		_services.rewards.changed.connect(_render)
		if _services.editor_content != null: _services.editor_content.changed.connect(_render)
	_render()
	_load.call_deferred()


var _iphone := false


func _layout() -> void:
	if not is_instance_valid(_modal): return
	var viewport := Vector2(get_viewport().get_visible_rect().size)
	_compact = viewport.y < 600
	var fraction_x := 0.965 if _compact else 0.94
	var fraction_y := 0.88 if _compact else 0.82
	# iPhone (perfil próprio, já dentro da área segura): a janela ocupa quase tudo para que
	# banner, abas, cartões inteiros (arte, nome, descrição e botão) e rodapé caibam sem corte.
	_iphone = UIScale.is_iphone()
	if _iphone:
		fraction_x = 0.985
		fraction_y = 0.975
	_modal_width = floorf(viewport.x * fraction_x)
	var modal_height := floorf(viewport.y * fraction_y)
	_modal.position = (viewport - Vector2(_modal_width, modal_height)) * 0.5
	_modal.size = Vector2(_modal_width, modal_height)
	var inset := 9 if _compact else 22
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_content_width = _modal_width - inset * 2
	_stack.add_theme_constant_override("separation", 7 if _compact else 12)
	_render()


func _load() -> void:
	if _services == null or not _services.session.authenticated(): return
	if _services.editor_content != null:
		await _services.editor_content.refresh()
	if not is_inside_tree(): return
	if _services.rewards.state != "success":
		await _services.rewards.refresh()
	if not is_inside_tree(): return
	_render()
	var rewards: OfficialRewardsService = _services.rewards
	if rewards.state == "success" and not rewards.seen:
		# Sem as artes publicadas, não registrar o lançamento como já visto.
		if _campaign_waits_for_art(): return
		rewards.mark_seen.call_deferred()


func _campaign_waits_for_art() -> bool:
	if _services == null: return false
	return str(_services.rewards.campaign.get("id", "")) == "diva_pop_2026" and DeckCatalog.find_deck("diva_pop").is_empty()


func _render() -> void:
	if not is_instance_valid(_stack) or _content_width <= 0.0: return
	for child in _stack.get_children():
		_stack.remove_child(child)
		child.queue_free()
	_header()
	if _services == null or not _services.session.authenticated():
		_message("Entre na sua conta para consultar seus presentes oficiais.", true)
		_footer()
		return
	var rewards: OfficialRewardsService = _services.rewards
	if rewards.state == "loading" or rewards.state == "empty":
		_message("Consultando presentes da sua conta…", false)
		_footer()
		return
	if rewards.state != "success":
		_message("Não foi possível consultar as recompensas. Nenhum resgate foi alterado.", true)
		var retry := _button("TENTAR NOVAMENTE", true)
		retry.name = "RetryNews"
		retry.pressed.connect(func() -> void: rewards.refresh())
		_stack.add_child(retry)
		_footer()
		return
	var shown := _visible_offers(rewards)
	if shown.is_empty():
		var message := "Você ainda não resgatou presentes." if _history else "Nenhuma novidade no momento. Seus presentes resgatados estão no histórico."
		if _history and rewards.inventory_state == "error": message = "Não foi possível consultar seu histórico. Tente novamente."
		_message(message, _history and rewards.inventory_state == "error")
		if _history and rewards.inventory_state == "error":
			var retry := _button("TENTAR NOVAMENTE", true)
			retry.pressed.connect(func() -> void: rewards.refresh())
			_stack.add_child(retry)
		_footer()
		return
	if not _history and _campaign_waits_for_art():
		_message("Diva Pop está em preparação. As cartas aparecerão quando as dez imagens estiverem publicadas.", false)
		_footer()
		return
	if not shown.any(func(o: Dictionary) -> bool: return str(o.get("kind", "")) == _tab):
		_tab = "skin" if _tab == "deck" else "deck"
	if not _history and not rewards.campaign.is_empty(): _banner(rewards)
	_categories(rewards)
	if rewards.inventory_state == "error":
		var history_warning := _label("Presentes anteriores temporariamente indisponíveis. Tente reabrir Novidades.", 11 if _compact else 14, MUTED)
		history_warning.name = "InventoryWarning"
		_stack.add_child(history_warning)
	if not _notice.is_empty():
		var status := _label(_notice, 12 if _compact else 16, GOLD_SOFT)
		status.name = "NewsStatus"
		status.custom_minimum_size.y = 18 if _compact else 24
		_stack.add_child(status)
	_rewards_grid(rewards)
	_footer(rewards)


func _header() -> void:
	var header := HBoxContainer.new()
	header.name = "RewardHeader"
	header.custom_minimum_size.y = 42 if _compact else (54 if _iphone else 64)
	header.add_theme_constant_override("separation", 11 if _compact else 18)
	_stack.add_child(header)
	var gift := _icon(ICON_GIFT, 27 if _compact else 40)
	header.add_child(gift)
	var title := _label("Histórico de resgates" if _history else "Resgatar Presentes", 19 if _compact else (36 if _iphone else 32), WHITE)
	title.name = "HeaderTitle"
	title.custom_minimum_size.x = 190 if _compact else 310
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var line := ColorRect.new()
	line.color = Color(GOLD_SOFT, 0.42)
	line.custom_minimum_size = Vector2(1, 25 if _compact else 35)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(line)
	var eyebrow := _label("NOVIDADES DO JOGO", 9 if _compact else (20 if _iphone else 17), Color("#e0e5ee"))
	eyebrow.name = "HeaderEyebrow"
	eyebrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(eyebrow)
	var close := _button("×", false)
	close.name = "CloseNews"
	close.tooltip_text = "Fechar presentes"
	close.custom_minimum_size = Vector2(43 if _compact else 54, 40 if _compact else 52)
	close.add_theme_font_size_override("font_size", 28 if _compact else 36)
	close.pressed.connect(queue_free)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(close)


func _banner(rewards: OfficialRewardsService) -> void:
	var banner := Panel.new()
	banner.name = "RewardBanner"
	banner.custom_minimum_size.y = 84 if _compact else (92 if _iphone else 142)
	banner.clip_contents = true
	banner.add_theme_stylebox_override("panel", _style(Color("#172331"), Color("#6b6255"), 12, 1))
	_stack.add_child(banner)
	var picture := TextureRect.new()
	picture.name = "CampaignArt"
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = _feature_cover(rewards)
	var live: Dictionary = _services.editor_content.news_item(str(rewards.campaign.get("id", ""))) if _services.editor_content != null else {}
	if _services.editor_content != null:
		_services.editor_content.attach_cover(picture, str(live.get("cover_path", "")))
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.anchor_left = 0.63
	picture.anchor_right = 1.0
	picture.anchor_top = 0
	picture.anchor_bottom = 1
	banner.add_child(picture)
	var gradient := Gradient.new()
	gradient.set_colors(PackedColorArray([Color("#172331"), Color("#172331"), Color(0.09, 0.13, 0.18, 0.05)]))
	gradient.set_offsets(PackedFloat32Array([0.0, 0.55, 1.0]))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.width = 512
	fade.height = 2
	fade.fill_from = Vector2(0.0, 0.5)
	fade.fill_to = Vector2(1.0, 0.5)
	var shade := TextureRect.new()
	shade.name = "CampaignGradient"
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.add_child(shade)
	var accent := ColorRect.new()
	accent.color = GOLD
	accent.position = Vector2(16 if _compact else 24, 17 if _compact else (14 if _iphone else 28))
	accent.size = Vector2(4 if _compact else 6, 50 if _compact else (72 if _iphone else 79))
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(accent)
	var copy := VBoxContainer.new()
	copy.name = "CampaignCopy"
	copy.position = Vector2(29 if _compact else 49, 13 if _compact else (10 if _iphone else 23))
	copy.size = Vector2(_content_width * 0.66 - 40, 66 if _compact else (80 if _iphone else 104))
	copy.add_theme_constant_override("separation", 2 if _compact else (3 if _iphone else 10))
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(copy)
	var title_text := str(live.get("title", "")) if not str(live.get("title", "")).is_empty() else ("Você tem recompensas para conhecer!" if not rewards.revealed else "Seus presentes estão na sua conta!")
	var manual := rewards.offers.any(func(item: Dictionary)->bool:return item.has("auto_grant") and not bool(item.auto_grant) and not bool(item.get("claimed", false)))
	if manual: title_text = str(rewards.campaign.get("title", title_text))
	var title := _label(title_text, 16 if _compact else (31 if _iphone else 27), WHITE)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.name = "CampaignHeadline"
	title.max_lines_visible = 1
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var desc_text := str(live.get("description", "")) if not str(live.get("description", "")).is_empty() else ("Confira os presentes oficiais da equipe Quem Sou Eu." if not rewards.revealed else "Tudo salvo no seu perfil. Aproveite suas recompensas!")
	if manual: desc_text = str(rewards.campaign.get("description", desc_text))
	var description := _label(desc_text, 11 if _compact else (21 if _iphone else 17), MUTED)
	description.name = "CampaignSubtitle"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 1 if _iphone else 2
	copy.add_child(description)
	var context := _label(str(rewards.campaign.get("title", "")), 10 if _compact else (16 if _iphone else 15), GOLD_SOFT)
	context.max_lines_visible = 1
	context.visible = not _iphone
	context.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(context)


func _categories(rewards: OfficialRewardsService) -> void:
	var bar := HBoxContainer.new()
	bar.name = "RewardCategories"
	bar.custom_minimum_size.y = 36 if _compact else 50
	bar.add_theme_constant_override("separation", 10)
	_stack.add_child(bar)
	for info in [["deck", "Decks" if _history else "Decks Grátis", ICON_DECK], ["skin", "Skins", ICON_SKIN]]:
		var kind := str(info[0])
		var count := 0
		for offer: Dictionary in _visible_offers(rewards):
			if str(offer.get("kind", "")) == kind: count += 1
		if count == 0: continue
		var tab := _button("%s (%d)" % [str(info[1]), count], _tab == kind)
		tab.name = "Tab" + kind.capitalize()
		tab.icon = info[2]
		tab.expand_icon = true
		tab.add_theme_constant_override("icon_max_width", 18 if _compact else 23)
		tab.custom_minimum_size = Vector2(148 if _compact else (250 if _iphone else 220), 36 if _compact else 48)
		tab.pressed.connect(_switch.bind(kind))
		bar.add_child(tab)
	# A leitura histórica do GAME inclui a data real da oferta.
	var can_sort := not _visible_offers(rewards).is_empty()
	for offer: Dictionary in _visible_offers(rewards):
		if _offer_date(offer).is_empty(): can_sort = false
	if can_sort:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(gap)
		var sort := OptionButton.new()
		sort.name = "RewardSort"
		sort.add_item("Mais recentes")
		sort.add_item("Mais antigos")
		sort.selected = 0 if _sort_mode == "recent" else 1
		sort.custom_minimum_size = Vector2(129 if _compact else 190, 36 if _compact else 48)
		sort.add_theme_font_size_override("font_size", 10 if _compact else 15)
		sort.add_theme_color_override("font_color", WHITE)
		for mode in ["normal", "hover", "pressed"]:
			sort.add_theme_stylebox_override(mode, _style(SURFACE, Color("#516070"), 9, 1))
		PlayerUI.transparent_button_fill(sort)
		sort.item_selected.connect(_set_sort)
		bar.add_child(sort)


## Ainda para receber: não resgatado, ou incluso num pacote que ainda não foi aberto.
func _pending(offer: Dictionary, rewards: OfficialRewardsService) -> bool:
	return rewards.is_offer_pending(offer)


## Somente recibos confirmados pela conta; campanhas antigas não precisam estar ativas.
func _visible_offers(rewards: OfficialRewardsService) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offer: Dictionary in rewards.offers:
		var included := bool(offer.get("claimed", false)) and not _pending(offer, rewards) if _history else _pending(offer, rewards)
		if included: result.append(offer)
	return result


func _offer_date(offer: Dictionary) -> String:
	var value: Variant = offer.get("claimed_at") if _history else offer.get("created_at")
	return str(value) if value is String else ""


func _rewards_grid(rewards: OfficialRewardsService) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "RewardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_stack.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "RewardRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.custom_minimum_size.x = _content_width - 2
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	var list: Array[Dictionary] = []
	for offer: Dictionary in _visible_offers(rewards):
		if str(offer.get("kind", "")) == _tab:
			list.append(offer)
	if list.size() > 1 and list.all(func(o: Dictionary) -> bool: return not _offer_date(o).is_empty()):
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left := _offer_date(a)
			var right := _offer_date(b)
			return (left > right if _sort_mode == "recent" else left < right) if left != right else str(a.get("id", "")) < str(b.get("id", "")))
	if list.is_empty():
		var empty := _label("Nenhuma oferta de skins nesta campanha." if _tab == "skin" else "Nenhum deck disponível nesta campanha.", 16 if _compact else 20, MUTED)
		empty.name = "EmptyOffers"
		rows.add_child(empty)
	var grid := GridContainer.new()
	grid.name = "RewardOffers"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.columns = 4 if _content_width >= 1420 else (3 if _content_width >= 1000 else (2 if _content_width >= 690 else 1))
	# iPhone: 2 cartões por linha (capa inteira + texto + botão), sem estourar a largura.
	if _iphone: grid.columns = 2
	rows.add_child(grid)
	var card_width := floorf((_content_width - (grid.columns - 1) * 12 - 4) / grid.columns)
	for offer: Dictionary in list:
		_add_offer(grid, offer, rewards, card_width)


func _add_offer(grid: GridContainer, offer: Dictionary, rewards: OfficialRewardsService, card_width: float) -> void:
	var claimed := bool(offer.get("claimed", false))
	var kind := str(offer.get("kind", ""))
	var id := str(offer.get("item_id", ""))
	var card := PanelContainer.new()
	card.name = "Offer_" + str(offer.get("id", ""))
	card.custom_minimum_size = Vector2(card_width, 255 if _compact else (232 if _iphone else 322))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(CARD, Color(GOLD_SOFT, 0.54) if claimed else Color("#4d5967"), 12, 1))
	grid.add_child(card)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 7 if _compact else 10)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5 if _compact else 9)
	var art_slot := Panel.new()
	art_slot.name = "RewardArtSlot"
	art_slot.custom_minimum_size.y = 180 if _compact else (164 if _iphone else 280)
	art_slot.clip_contents = true
	art_slot.add_theme_stylebox_override("panel", _style(Color("#263449"), Color("#334356"), 7, 0))
	if _iphone:
		# iPhone: capa INTEIRA em pé à esquerda (sem corte) e texto + botão à direita.
		var side := HBoxContainer.new()
		side.add_theme_constant_override("separation", 12)
		margin.add_child(side)
		art_slot.custom_minimum_size = Vector2(floorf(card_width * 0.34), 0)
		art_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.add_child(art_slot)
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_child(content)
	else:
		margin.add_child(content)
		content.add_child(art_slot)
	var art := TextureRect.new()
	art.name = "RewardCover" if kind == "deck" else "RewardSkinPreview"
	art.texture = _cover(id) if kind == "deck" else PlayerUI.portrait_texture(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_slot.add_child(art)
	if kind == "deck" and _services.editor_content != null:
		var live_cover: Dictionary = _services.editor_content.deck(id)
		_services.editor_content.attach_cover(art, str(live_cover.get("cover_path", "")))
	var tag := PanelContainer.new()
	tag.name = "RewardTypeBadge"
	tag.position = Vector2(8, 8)
	tag.add_theme_stylebox_override("panel", _style(Color("#f2c85d") if kind == "deck" else Color("#d4a8e3"), Color(0, 0, 0, 0), 6, 0))
	art_slot.add_child(tag)
	var label := _label("DECK" if kind == "deck" else "SKIN", 11 if _compact else (18 if _iphone else 13), NAVY)
	label.add_theme_constant_override("outline_size", 0)
	tag.add_child(label)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	content.add_child(name_row)
	var name := _label(str(offer.get("title", "Recompensa")), 17 if _compact else (30 if _iphone else 22), WHITE)
	name.name = "RewardTitle"
	name.max_lines_visible = 1
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name)
	if kind == "deck":
		var found: Dictionary = DeckCatalog.find_deck(id)
		var count := int(found.get("count", 0))
		if count > 0:
			var count_label := _label(str(TranslationServer.translate("%d cartas")) % count, 10 if _compact else (20 if _iphone else 13), MUTED)
			count_label.name = "CardCount"
			count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
			name_row.add_child(count_label)
	var desc := _label(str(offer.get("description", "")), 11 if _compact else (21 if _iphone else 14), MUTED)
	desc.name = "RewardDescription"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 2
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(desc)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(filler)
	if _history:
		var receipt := _label("✓  RESGATADO", 12 if _compact else 16, GOLD_SOFT)
		receipt.name = "ClaimedReceipt"
		content.add_child(receipt)
		var when := str(offer.get("claimed_at", ""))
		if when != "" and when != "<null>":
			var timestamp := Time.get_datetime_dict_from_datetime_string(when.left(19), false)
			if not timestamp.is_empty():
				var date := _label("%02d/%02d/%04d" % [timestamp.day, timestamp.month, timestamp.year], 11 if _compact else 14, MUTED)
				date.name = "ClaimedDate"
				content.add_child(date)
		return
	var claim_allowed := bool(offer.get("claim_enabled", kind == "deck"))
	var current_campaign := str(rewards.campaign.get("id", ""))
	var historical := offer.has("campaign_id") and str(offer.get("campaign_id", "")) != current_campaign
	var confirmed := bool(offer.get("revealed", rewards.revealed)) or historical
	var caption := ("RESGATADO" if confirmed else "INCLUSO NO PACOTE") if claimed else ("RESGATAR GRÁTIS" if claim_allowed else "EM BREVE")
	var action := _button(caption, not claimed and claim_allowed)
	action.name = "Claim_" + str(offer.get("id", ""))
	action.custom_minimum_size.y = 40 if _compact else 50
	action.disabled = claimed or _working or not claim_allowed
	action.tooltip_text = "Este item já pertence à sua conta" if claimed else ("Resgatar grátis no GAME" if claim_allowed else "Ainda não disponível")
	if claimed:
		var disabled_style := _style(Color("#3b3221"), Color(GOLD_SOFT, 0.7), 8, 1)
		action.add_theme_stylebox_override("disabled", disabled_style)
		action.add_theme_color_override("font_disabled_color", GOLD_SOFT)
	action.pressed.connect(_claim.bind(str(offer.get("id", ""))))
	content.add_child(action)


func _footer(rewards: OfficialRewardsService = null) -> void:
	var footer := HBoxContainer.new()
	footer.name = "RewardFooter"
	footer.custom_minimum_size.y = 40 if _compact else 55
	footer.add_theme_constant_override("separation", 8)
	_stack.add_child(footer)
	var news := _button("Ver presentes disponíveis" if _history else "Histórico de resgates", false)
	news.name = "MoreNews"
	news.tooltip_text = news.text
	news.custom_minimum_size = Vector2(142 if _compact else (300 if _iphone else 242), 38 if _compact else 49)
	news.pressed.connect(_legacy_news)
	footer.add_child(news)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	if rewards == null or _history: return
	if not rewards.revealed and rewards.offers.any(func(item: Dictionary)->bool: return bool(item.get("auto_grant", true)) and rewards.is_offer_pending(item)):
		var redeem := _button("RESGATAR PRESENTES", true)
		redeem.name = "RedeemGiftBundle"
		redeem.custom_minimum_size = Vector2(158 if _compact else (320 if _iphone else 270), 39 if _compact else 49)
		redeem.disabled = _working or rewards.offers.is_empty() or rewards.offers.all(func(o: Dictionary) -> bool: return not bool(o.get("claimed", false)))
		redeem.pressed.connect(_reveal_gifts)
		footer.add_child(redeem)
	elif rewards.revealed:
		var received := _label("✓  PRESENTES RECEBIDOS", 11 if _compact else (20 if _iphone else 16), GOLD_SOFT)
		received.name = "GiftsReceived"
		received.size_flags_horizontal = Control.SIZE_SHRINK_END
		received.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		footer.add_child(received)


func _message(message: String, warn: bool) -> void:
	var box := PanelContainer.new()
	box.name = "NewsMessage"
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _style(Color("#192534"), Color(GOLD_SOFT, 0.24), 12, 1))
	var label := _label(message, 14 if _compact else (26 if _iphone else 20), GOLD_SOFT if warn else MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(10, 0)
	box.add_child(label)
	_stack.add_child(box)


func _reveal_gifts() -> void:
	if _working or _services == null or _services.rewards.revealed: return
	_working = true
	_notice = "Confirmando presentes na sua conta…"
	_render()
	var result: Dictionary = await _services.rewards.reveal()
	_working = false
	if not is_inside_tree(): return
	if result.ok and result.data is Dictionary and result.data.get("ok", false) == true:
		_notice = "Presentes recebidos! Seus itens estão salvos na conta."
	else:
		_notice = "Não foi possível confirmar agora. Nenhum item foi perdido."
	_render()


func _claim(offer_id: String) -> void:
	if _working or _services == null: return
	_working = true
	_notice = "Registrando resgate no GAME…"
	_render()
	var result: Dictionary = await _services.rewards.claim(offer_id)
	_working = false
	if not is_inside_tree(): return
	if result.ok and result.data is Dictionary and result.data.get("ok", false) == true:
		_notice = "Resgate confirmado! Item salvo na sua conta."
	else:
		_notice = "O resgate não foi confirmado. Confira sua conexão e tente novamente."
	_render()


func _set_sort(selected: int) -> void:
	_sort_mode = "recent" if selected == 0 else "old"
	_render()


func _switch(kind: String) -> void:
	_tab = kind
	_notice = ""
	_render()


func _legacy_news() -> void:
	_history = not _history
	_notice = ""
	_tab = "deck"
	_render()


func _feature_cover(rewards: OfficialRewardsService) -> Texture2D:
	for offer: Dictionary in rewards.offers:
		if str(offer.get("kind", "")) == "deck":
			var texture := _cover(str(offer.get("item_id", "")))
			if texture != null: return texture
	return preload("res://assets/processed/backgrounds/bg_lobby_fantasia.png")


func _cover(deck_id: String) -> Texture2D:
	var deck := DeckCatalog.find_deck(deck_id)
	var path := DeckCover.resolve_item(deck)
	return DeckCover.load_texture(path) if not path.is_empty() else null


func _style(background: Color, outline: Color, corner: int, stroke: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = outline
	box.set_border_width_all(stroke)
	box.set_corner_radius_all(corner)
	box.set_content_margin_all(7)
	return box


func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(116, 40)
	button.add_theme_font_size_override("font_size", 12 if _compact else (24 if _iphone else 17))
	button.add_theme_color_override("font_color", NAVY if primary else WHITE)
	button.add_theme_color_override("font_hover_color", NAVY if primary else WHITE)
	button.add_theme_color_override("font_pressed_color", NAVY if primary else WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var base := GOLD if primary else Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", _style(base, GOLD_SOFT if primary else Color("#516070"), 10, 1))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.10) if primary else Color.TRANSPARENT, GOLD_SOFT, 10, 1))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.12) if primary else Color.TRANSPARENT, GOLD_SOFT, 10, 1))
	button.add_theme_stylebox_override("disabled", _style(Color.TRANSPARENT, Color("#485260"), 10, 1))
	var focused := _style(Color.TRANSPARENT, GOLD, 10, 2)
	focused.draw_center = false
	button.add_theme_stylebox_override("focus", focused)
	if not primary: PlayerUI.transparent_button_fill(button)
	return button


func _icon(texture: Texture2D, pixels: int) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.custom_minimum_size = Vector2(pixels, pixels)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _label(caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Label com clip_text=true + ellipsis pode declarar largura/altura mínima zero
	# nos Containers do Godot 4.7.2 e simplesmente desaparecer.
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false
	label.custom_minimum_size.y = font_size + 6
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_top()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close_top()


func _close_top() -> void:
	if not is_instance_valid(_shade): return
	var other := _shade.get_node_or_null("OtherNews")
	if other != null: other.queue_free()
	else: queue_free()
