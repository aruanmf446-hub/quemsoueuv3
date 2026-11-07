extends PlayerScreen

## Evolução do painel existente: mantém catálogo, ThumbnailCache e LobbyStage originais.
## Layout: galeria rolável à esquerda (duas colunas) e prévia 3D fixa à direita, fora da rolagem.
signal character_selected(character_id: StringName)
signal progress_changed
const PREVIEW_FILL_RATIO := 0.80
## Cada arquivo .json desta pasta vira uma categoria (coleção) na barra lateral.
const COLLECTIONS_DIR := "res://data/collections/"
var _collection_title := "Começo"
var _collections: Array[Dictionary] = []
var _collection := 0
var _collection_list: VBoxContainer
static var _atmosphere: GradientTexture2D
var _collection_count: Label
## Cores do modelo (PlayerUI, a partir de docs/referencias/personagens/REFERENCIA_APROVADA.png).
const ACCENT := PlayerUI.TITLE_GOLD
const SMALL_SCREEN := 1100.0
const FAVORITES_PATH := "user://skins_favorites.cfg"
var _favorites: Dictionary = {}
var _favorite_only := false
var _search := ""
var _status_filter := 0
var _reverse_sort := false
var _toolbar: BoxContainer
var _collection_sidebar: VBoxContainer
var _gallery_section: VBoxContainer
var _gallery_scroll: ScrollContainer
var _search_field: LineEdit
var _filter_button: OptionButton
var _sort_button: OptionButton
var _fav_button: Button
var _thumbnails: ThumbnailCache
var _paths: Dictionary = {}
var _selected := ""
var _generating := false
var _gallery_page := 0
var _grid: GridContainer
var _preview: VBoxContainer
var _side: PanelContainer
var _split: HBoxContainer
var _scroll: ScrollContainer
var _header: HBoxContainer
var _stage: LobbyStage
var _description: Label
var _back_button: Button
var _images: Dictionary = {}
var _cards: Dictionary = {}
var _was_compact := false
var _cosmetic_mode := "skins"
var _cosmetic_tabs: Dictionary = {}
var _emote_previews := preload("res://scripts/skins/emote_preview_cache.gd").new()
var _context_title: Label
var _context_hint: Label
var _buy_dialog: Control
const DANCE_PREVIEW = preload("res://scripts/skins/dance_preview.gd")
const VARIATIONS = preload("res://scripts/skins/skin_variations.gd")
var _selected_styles: Dictionary={}


func _ready() -> void:
	manages_own_scale = true
	super._ready()
	heading.text = tr("Personagens")
	heading.add_theme_color_override("font_color", PlayerUI.TITLE_GOLD)
	_load_collections()
	_thumbnails = ThumbnailCache.new(preload("res://scenes/lobby/lobby_stage.tscn"))
	_load_favorites()
	_split_layout()
	_build_cosmetic_tabs()
	get_viewport().size_changed.connect(_responsive_layout)
	_responsive_layout()
	services.inventory.changed.connect(func() -> void:
		if is_visible_in_tree(): render())
	services.session.changed.connect(_close_purchase)
	visibility_changed.connect(func()->void:
		if not is_visible_in_tree(): _close_purchase())


## Separa a galeria (rolável, à esquerda) da prévia (fixa, à direita).
func _split_layout() -> void:
	var column: VBoxContainer = $Margin/Column
	_scroll = $Margin/Column/Scroll
	_header = $Margin/Column/Header
	_back_button = $Margin/Column/Header/Back
	_split = HBoxContainer.new()
	_split.name = "SkinsShowcase"
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 18)
	column.add_child(_split)
	column.move_child(_split, _scroll.get_index())
	_scroll.reparent(_split)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 1.5
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gallery_section = VBoxContainer.new()
	_gallery_section.name = "Catalog"
	_gallery_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gallery_section.size_flags_stretch_ratio = 1.65
	_gallery_section.add_theme_constant_override("separation", 12)
	_split.add_child(_gallery_section)
	_scroll.reparent(_gallery_section)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toolbar = VBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	_gallery_section.add_child(_toolbar)
	_gallery_section.move_child(_toolbar, 0)
	var search_row := HBoxContainer.new()
	_toolbar.add_child(search_row)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	_toolbar.add_child(filter_row)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Pesquisar personagem..."
	_search_field.custom_minimum_size.y = 52
	PlayerUI.style_field(_search_field)
	_search_field.add_theme_font_size_override("font_size", 22)
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_field.text_changed.connect(func(value: String) -> void:
		_search = value
		_rebuild_gallery()
		PlayerUI.cascade(_grid, 0, 0.02))
	search_row.add_child(_search_field)
	_fav_button = _button("♡ Favoritos", _toggle_favorite_only)
	_fav_button.custom_minimum_size = Vector2(144, PlayerUI.CONTROL_HEIGHT)
	filter_row.add_child(_fav_button)
	_filter_button = OptionButton.new()
	for value in ["Todos", "Disponíveis", "Bloqueados"]:
		_filter_button.add_item(value)
	_filter_button.item_selected.connect(func(index: int) -> void:
		_status_filter = index
		_rebuild_gallery()
		PlayerUI.cascade(_grid))
	filter_row.add_child(_filter_button)
	_sort_button = OptionButton.new()
	_sort_button.add_item("A-Z")
	_sort_button.add_item("Z-A")
	_sort_button.item_selected.connect(func(index: int) -> void:
		_reverse_sort = index == 1
		_rebuild_gallery()
		PlayerUI.cascade(_grid))
	filter_row.add_child(_sort_button)
	for option: OptionButton in [_filter_button, _sort_button]:
		option.custom_minimum_size = Vector2(130, PlayerUI.CONTROL_HEIGHT)
		option.add_theme_font_size_override("font_size", 22)
		PlayerUI.style_field(option)
	_collection_sidebar = VBoxContainer.new()
	_collection_sidebar.name = "Collections"
	_collection_sidebar.custom_minimum_size.x = 220
	_collection_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_collection_sidebar.mouse_filter = Control.MOUSE_FILTER_PASS
	_collection_sidebar.add_theme_constant_override("separation", 14)
	_split.add_child(_collection_sidebar)
	_split.move_child(_collection_sidebar, 0)
	var collection_panel := PanelContainer.new()
	collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_panel.add_theme_stylebox_override("panel", PlayerUI.frame_panel(14))
	_collection_sidebar.add_child(collection_panel)
	var categories := VBoxContainer.new()
	categories.add_theme_constant_override("separation", 12)
	collection_panel.add_child(categories)
	var collections_title := PlayerUI.label("Coleções", 21, PlayerUI.TITLE_GOLD)
	collections_title.custom_minimum_size.y = 40
	categories.add_child(collections_title)
	_collection_list = VBoxContainer.new()
	_collection_list.name = "CollectionList"
	_collection_list.add_theme_constant_override("separation", 8)
	categories.add_child(_collection_list)
	_collection_count = PlayerUI.label("", 17, ACCENT)
	_collection_count.size_flags_horizontal = Control.SIZE_SHRINK_END
	_collection_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_collection_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header.add_child(_collection_count)
	_scroll.get_parent().move_child(_scroll, 1)
	_side = PanelContainer.new()
	_side.name = "HeroPreview"
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.size_flags_stretch_ratio = 1.0
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Como na referência, o palco do personagem fica direto sobre o cenário, sem caixa.
	_side.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_split.add_child(_side)
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 6)
	_side.add_child(_preview)


func _responsive_layout() -> void:
	var compact := UIScale.is_compact()
	if compact != _was_compact and _stage != null and is_instance_valid(_stage):
		_was_compact = compact
		_select(_selected)
	var margin: MarginContainer = $Margin
	var factor := PlayerUI.unit(self)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = get_viewport().get_visible_rect().size / factor
	margin.set_deferred("size", get_viewport().get_visible_rect().size / factor)
	var inset := 12 if compact else 26
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, inset)
	_header.add_theme_constant_override("separation", 12 if compact else 22)
	PlayerUI.standard_back(_back_button)
	heading.add_theme_font_size_override("font_size", 23 if compact else 40)
	$Margin/Column.add_theme_constant_override("separation", 6 if compact else 12)
	_split.add_theme_constant_override("separation", 8 if compact else 18)
	_scroll.size_flags_stretch_ratio = 1.0
	_gallery_section.size_flags_stretch_ratio = 1.25 if compact else 1.4
	_side.size_flags_stretch_ratio = 1.0
	# Barra de coleções só quando sobra largura; em telas estreitas a coleção atual
	# continua no topo ("COMEÇO · 7/8") e a prévia não é empurrada para fora.
	_collection_sidebar.visible = _cosmetic_mode=="skins" and not compact and get_viewport().get_visible_rect().size.x >= 1200.0
	_toolbar.add_theme_constant_override("separation", 4 if compact else 8)
	_fav_button.text = "Favoritos" if not compact else "FAV"
	_fav_button.add_theme_color_override("font_color", ACCENT if _favorite_only else PlayerUI.TEXT)
	_fav_button.custom_minimum_size.x = 34 if compact else 144
	_search_field.placeholder_text = "Pesquisar..." if compact else "Pesquisar personagem..."
	_search_field.custom_minimum_size.x = 116 if compact else 0
	_search_field.custom_minimum_size.y = 44 if compact else PlayerUI.CONTROL_HEIGHT
	_filter_button.custom_minimum_size.y = 44 if compact else PlayerUI.CONTROL_HEIGHT
	_sort_button.custom_minimum_size.y = 44 if compact else PlayerUI.CONTROL_HEIGHT
	_sort_button.custom_minimum_size.x = 68 if compact else 130
	if _grid != null:
		_grid.columns = _columns() if _cosmetic_mode=="skins" else (1 if _cosmetic_mode=="shop" else 3)
		if _cosmetic_mode=="skins":
			for item in _grid.get_children():
				_style_card_height(item, compact)
	if _stage != null and is_instance_valid(_stage):
		_stage.custom_minimum_size = Vector2.ZERO
	if _description != null and is_instance_valid(_description):
		_description.hide()


func open(equipped_id: String = "") -> void:
	_selected = equipped_id
	show_screen()


func close() -> void:
	back_requested.emit()


func render() -> void:
	if _selected.is_empty():
		_selected = services.inventory.equipped_id()
	_build_collections()
	_rebuild_gallery()
	# Sem texto de demonstração: o banner só aparece para erros e estados de carregamento.
	banner.show_state("success")
	# A galeria é reconstruída de forma independente dos serviços de inventário.

	_select(_selected)
	_responsive_layout()
	if not _generating:
		_generate_thumbnails()


func _rebuild_gallery() -> void:
	PlayerUI.clear(body)
	_images.clear()
	_cards.clear()
	_grid = GridContainer.new()
	_grid.columns = _columns()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(_grid)
	if _cosmetic_mode in ["emotes","shop"]:
		_build_emote_gallery(services.inventory.entry(_selected))
		return
	if _cosmetic_mode=="variations":
		_build_variation_gallery(services.inventory.entry(_selected))
		return
	var entries: Array = services.inventory.entries.duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) > 0 if _reverse_sort else str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) < 0)
	var count := 0
	var matching: Array = []
	var in_collection := _collection_ids(_collections[_collection])
	for entry: Dictionary in entries:
		var id: String = str(entry.id)
		if not in_collection.has(id): continue
		var unlocked: bool = services.inventory.is_unlocked(id)
		if not _search.is_empty() and not str(entry.name).to_lower().contains(_search.to_lower()):
			continue
		if _favorite_only and not _favorites.has(id):
			continue
		if _status_filter == 1 and not unlocked:
			continue
		if _status_filter == 2 and unlocked:
			continue
		matching.append(entry)
	count = matching.size()
	if UIScale.is_iphone():
		var pages := maxi(1, ceili(count / 3.0))
		_gallery_page = clampi(_gallery_page, 0, pages - 1)
		matching = matching.slice(_gallery_page * 3, (_gallery_page + 1) * 3)
		if pages > 1:
			var pager := HBoxContainer.new()
			pager.name = "GalleryPager"
			pager.add_theme_constant_override("separation", 12)
			body.add_child(pager)
			for direction: int in [-1, 1]:
				var button := PlayerUI.button("Anterior" if direction < 0 else "Próxima", func() -> void:
					_gallery_page += direction
					_rebuild_gallery())
				button.custom_minimum_size = Vector2(128, 48)
				button.disabled = _gallery_page + direction < 0 or _gallery_page + direction >= pages
				pager.add_child(button)
			var page := PlayerUI.label("%d / %d" % [_gallery_page + 1, pages], 20)
			page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pager.add_child(page)
			pager.move_child(page, 1)
	for entry: Dictionary in matching: _grid.add_child(_gallery_card(entry))
	if count == 0:
		body.add_child(PlayerUI.label("Nenhum personagem encontrado.", 19))
	if _fav_button != null:
		_fav_button.text = "FAV" if UIScale.is_compact() else "Favoritos"
		_fav_button.add_theme_color_override("font_color", ACCENT if _favorite_only else PlayerUI.TEXT)
	if _collection_count != null:
		var obtained := in_collection.filter(func(item: String) -> bool: return services.inventory.is_unlocked(item)).size()
		_collection_count.text = "%s  ·  %d/%d" % [_collection_title.to_upper(), obtained, in_collection.size()]


func _gallery_card(entry: Dictionary) -> PanelContainer:
	var character_id: String = entry.id
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(character_id == _selected))
	_cards[character_id] = card
	# Fundo discreto aprovado: brilho radial suave atrás do personagem.
	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = _atmosphere_texture()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(backdrop)
	var pad := MarginContainer.new()
	pad.name = "Pad"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	card.add_child(pad)
	var column := VBoxContainer.new()
	column.name = "Content"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	pad.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var favorite := _favorite_button(character_id)
	favorite.custom_minimum_size = Vector2(30, 28)
	favorite.add_theme_font_size_override("font_size", 22)
	favorite.add_theme_color_override("font_color", PlayerUI.GOLD_BRIGHT if _favorites.has(character_id) else PlayerUI.TEXT)
	top.add_spacer(false)
	top.add_child(favorite)
	var thumbnail := TextureRect.new()
	thumbnail.name = "Portrait"
	thumbnail.custom_minimum_size = Vector2(0, 225)
	thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(_paths.get(character_id, ThumbnailCache.path_for(character_id)))
	if FileAccess.file_exists(path):
		thumbnail.texture = _portrait_texture(path)
	column.add_child(thumbnail)
	_images[character_id] = thumbnail
	var name_label := PlayerUI.label(entry.name, 21, PlayerUI.TEXT)
	name_label.custom_minimum_size.y = 30
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	column.add_child(name_label)
	var equipped: bool = services.inventory.equipped_id() == character_id
	var unlocked: bool = services.inventory.is_unlocked(character_id)
	# Nome e, embaixo, o selo de estado em largura total (modelo da referência).
	name_label.custom_minimum_size.y = 28
	column.add_child(PlayerUI.pill("EQUIPADO" if equipped else ("DISPONÍVEL" if unlocked else "BLOQUEADO"), "equipped" if equipped else ("available" if unlocked else "locked")))
	if not unlocked:
		thumbnail.modulate = Color(0.45, 0.48, 0.55)
		backdrop.modulate = Color(0.55, 0.57, 0.62)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	card.mouse_entered.connect(func() -> void:
		var hover := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		hover.tween_property(card, "modulate", Color(1.16, 1.12, 1.02), 0.16)
		hover.tween_property(card, "scale", Vector2.ONE * 1.025, 0.16))
	card.mouse_exited.connect(func() -> void:
		var rest := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		rest.tween_property(card, "modulate", Color.WHITE, 0.18)
		rest.tween_property(card, "scale", Vector2.ONE, 0.18))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and character_id != _selected:
			_select(character_id)
			PlayerUI.reveal(_preview, 0.0, 0.2))
	_style_card_height(card, UIScale.is_compact())
	return card


func _columns() -> int:
	return 3 if UIScale.is_iphone() else (2 if UIScale.is_compact() or size.x < 1250 else 3)


func _style_card_height(card: Control, compact: bool) -> void:
	card.custom_minimum_size.y = 0
	var portrait: TextureRect = card.get_node_or_null("Pad/Content/Portrait")
	if portrait != null:
		portrait.custom_minimum_size.y = 180 if compact else clampf((size.y - 260) / 2.0 - 90, 170, 250)


func _toggle_favorite(character_id: String) -> void:
	if _favorites.has(character_id):
		_favorites.erase(character_id)
	else:
		_favorites[character_id] = true
	_save_favorites()
	_rebuild_gallery()
	_select(_selected)


func _toggle_favorite_only() -> void:
	_favorite_only = not _favorite_only
	_rebuild_gallery()
	PlayerUI.cascade(_grid)


func animate_in() -> void:
	PlayerUI.cascade(_grid, 0, 0.03)
	PlayerUI.reveal(_side, 0.06, 0.28)


func _load_favorites() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FAVORITES_PATH) == OK:
		for id in cfg.get_value("catalog", "favorite_ids", []):
			_favorites[str(id)] = true


func _save_favorites() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("catalog", "favorite_ids", _favorites.keys())
	cfg.save(FAVORITES_PATH)


func _select_neighbor(direction: int) -> void:
	var ids: Array[String] = []
	if _cosmetic_mode=="variations":
		for entry: Dictionary in services.inventory.entries: ids.append(str(entry.id))
	else:
		for child in _grid.get_children():
			for id: String in _cards:
				if _cards[id] == child:
					ids.append(id)
	if ids.is_empty():
		return
	var index := ids.find(_selected)
	if index < 0:
		index = 0
	_select(ids[posmod(index + direction, ids.size())])
	PlayerUI.reveal(_preview, 0.0, 0.2)


func _select(character_id: String) -> void:
	_selected = character_id
	for id: String in _cards:
		(_cards[id] as PanelContainer).add_theme_stylebox_override("panel", _card_style(id == character_id))
	var kept: LobbyStage = _stage if is_instance_valid(_stage) and _stage.get_parent() == _preview else null
	if kept != null: _preview.remove_child(kept)
	PlayerUI.clear(_preview)
	var entry := services.inventory.entry(character_id)
	if entry.is_empty():
		_preview.add_child(PlayerUI.label("Selecione uma skin."))
		return
	var compact := UIScale.is_compact()
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	_preview.add_child(heading_row)
	var name_label := PlayerUI.label(entry.name, 23 if compact else 34, Color("#fff0dc"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(name_label)
	var equipped := services.inventory.equipped_id() == character_id
	var unlocked := services.inventory.is_unlocked(character_id)
	if equipped or not unlocked:
		var tag := PlayerUI.pill("EQUIPADO" if equipped else "BLOQUEADO", "equipped" if equipped else "locked")
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heading_row.add_child(tag)
	var favorite := _favorite_button(character_id)
	favorite.custom_minimum_size = Vector2(36, 34)
	heading_row.add_child(favorite)
	_context_title=PlayerUI.label("",24,PlayerUI.GOLD)
	_context_title.name="ReactionPreviewTitle"
	_context_hint=PlayerUI.label("",20,PlayerUI.MUTED)
	_preview.add_child(_context_title)
	_preview.add_child(_context_hint)
	_context_title.visible=_cosmetic_mode!="skins"
	_context_hint.visible=_cosmetic_mode!="skins"
	var arrows := HBoxContainer.new()
	arrows.name="CharacterArrows"
	arrows.visible=_cosmetic_mode in ["skins","variations"]
	_preview.add_child(arrows)
	var left_arrow := _button("‹", _select_neighbor.bind(-1))
	left_arrow.name="PreviousSkinCharacter"
	left_arrow.custom_minimum_size = Vector2(56, 56)
	arrows.add_child(left_arrow)
	var hint := Control.new()
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrows.add_child(hint)
	var right_arrow := _button("›", _select_neighbor.bind(1))
	right_arrow.name="NextSkinCharacter"
	right_arrow.custom_minimum_size = Vector2(56, 56)
	arrows.add_child(right_arrow)
	var details := PlayerUI.label(_collection_title + "  •  " + ("Equipado" if equipped else ("Disponível" if unlocked else "Bloqueado")), 15, ACCENT)
	details.hide()
	_preview.add_child(details)
	if kept != null:
		_preview.add_child(kept)
		kept.show_character(entry)
		_stage = kept
	else:
		_stage = _showcase(_preview, character_id)
	if _stage != null:
		_stage.custom_minimum_size = Vector2.ZERO
		_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stage.fill_ratio = PREVIEW_FILL_RATIO
		_stage.frame_character()
		_stage.set_zoom(ThumbnailCache.framing_zoom(character_id))
		_stage.frame_character.call_deferred()
	_description = PlayerUI.label(str(entry.get("description", "")), 16)
	_description.custom_minimum_size.y = 0
	_description.hide()
	_preview.add_child(_description)
	if not unlocked:
		var lock_label := PlayerUI.label(PlayerProgress.lock_label(entry), 14 if compact else 17, Color("#ffcf8a"))
		_preview.add_child(lock_label)
	var actions := HBoxContainer.new()
	actions.name="SkinEquipActions"
	actions.visible=_cosmetic_mode in ["skins","emotes"]
	actions.add_theme_constant_override("separation", 10)
	_preview.add_child(actions)
	var equip := _button("EQUIPADO" if equipped else ("EQUIPAR" if unlocked else "BLOQUEADO"), _equip.bind(character_id), true)
	equip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	equip.custom_minimum_size.x = 300
	equip.custom_minimum_size.y = 36 if compact else PlayerUI.CONTROL_HEIGHT
	equip.disabled = not unlocked or equipped
	actions.add_child(equip)
	var back := _button("VOLTAR", close)
	back.custom_minimum_size.y = 36 if compact else PlayerUI.CONTROL_HEIGHT
	actions.add_child(back)
	var shop_actions := PlayerUI.row(_preview)
	shop_actions.name="EmoteShopActions"
	shop_actions.visible=_cosmetic_mode=="shop"
	var preview := _button("VER DANÇA",_preview_dance)
	preview.name="PreviewDanceMovement"
	preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preview.clip_text=true
	shop_actions.add_child(preview)
	var buy := _button("COMPRAR",_preview_purchase,true)
	buy.name="BuyEmotePreview"
	buy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	buy.clip_text=true
	shop_actions.add_child(buy)
	if _cosmetic_mode in ["emotes","shop"]: _rebuild_gallery()
	if _cosmetic_mode=="variations":
		_rebuild_gallery()
		_stage.static_preview=true
		VARIATIONS.apply(_stage.character,str(_selected_styles.get(_selected,"original")))
		_stage.get_node("Viewport").render_target_update_mode=SubViewport.UPDATE_ONCE
		_context_title.text=str(entry.name)+" · Variações"
		_context_hint.text=tr("Prévia visual")


func _build_cosmetic_tabs() -> void:
	var tabs := PlayerUI.row(_gallery_section)
	_gallery_section.move_child(tabs,0)
	for mode: String in ["skins","variations","emotes","shop"]:
		var button := _button({"skins":"SKINS","variations":"VARIAÇÕES","emotes":"REAÇÕES","shop":"EMOTES"}[mode],_choose_cosmetic_mode.bind(mode),mode==_cosmetic_mode)
		button.name="CosmeticTab_"+mode
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
		_cosmetic_tabs[mode]=button


func _choose_cosmetic_mode(mode: String) -> void:
	_cosmetic_mode=mode
	_stage.static_preview=mode=="variations"
	_stage.get_node("Viewport").render_target_update_mode=SubViewport.UPDATE_ONCE if mode=="variations" else SubViewport.UPDATE_ALWAYS
	_toolbar.visible=mode=="skins"
	_context_title.visible=mode!="skins"
	_context_hint.visible=mode!="skins"
	_preview.get_node("SkinEquipActions").visible=mode in ["skins","emotes"]
	_preview.get_node("EmoteShopActions").visible=mode=="shop"
	_context_title.text=tr("Exemplos de reações") if mode=="emotes" else tr("Loja de emotes · prévia")
	_context_hint.text=tr("Lobby, vitória e derrota") if mode=="emotes" else tr("Dancinha demonstrativa · compra separada")
	VARIATIONS.apply(_stage.character,str(_selected_styles.get(_selected,"original")) if mode=="variations" else "original")
	if mode=="variations": _stage.get_node("Viewport").render_target_update_mode=SubViewport.UPDATE_ONCE
	if mode=="variations":
		_context_title.text=tr("Variações de ")+str(services.inventory.entry(_selected).name)
		_context_hint.text=tr("Prévia visual")
	if _stage.character.has_animation(&"base"): _stage.character.set_pose(&"base",0.0)
	var arrows := _preview.get_node_or_null("CharacterArrows") as Control
	if arrows!=null: arrows.visible=mode in ["skins","variations"]
	for key: String in _cosmetic_tabs: PlayerUI.style_button(_cosmetic_tabs[key],key==mode)
	_rebuild_gallery()
	_responsive_layout()
	if mode=="shop": _refresh_emote_shop()


func _build_variation_gallery(entry: Dictionary) -> void:
	if entry.is_empty(): return
	_collection_count.text="VARIAÇÕES · PRÉVIA"
	_grid.columns=3
	var images := {}
	var group := ButtonGroup.new()
	for style: Dictionary in VARIATIONS.entries(str(entry.id)):
		var select := func()->void:
			if _selected!=str(entry.id) or not is_instance_valid(_stage): return
			_selected_styles[_selected]=style.id
			VARIATIONS.apply(_stage.character,str(style.id))
			_stage.get_node("Viewport").render_target_update_mode=SubViewport.UPDATE_ONCE
			_context_title.text=str(entry.name)+" · "+str(style.name)
			_context_hint.text=tr("Prévia visual")
		var button := _button("",select)
		button.name="SkinVariation_"+str(style.id)
		button.toggle_mode=true
		button.button_group=group
		button.button_pressed=str(_selected_styles.get(_selected,"original"))==str(style.id)
		button.custom_minimum_size=Vector2(0,260)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		_grid.add_child(button)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=8;content.offset_right=-8;content.offset_top=8;content.offset_bottom=-8
		content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var image := TextureRect.new()
		image.name="VariationThumbnail_"+str(style.id)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical=Control.SIZE_EXPAND_FILL
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(image)
		images[style.id]=image
		var label := PlayerUI.label(str(style.name),20)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
	_load_variation_previews(entry,_grid,images)


func _load_variation_previews(entry: Dictionary,watch: Control,images: Dictionary) -> void:
	var textures: Dictionary=await _emote_previews.capture(self,entry,watch,false,true)
	if not is_instance_valid(watch) or watch.is_queued_for_deletion(): return
	for id: String in images:
		if is_instance_valid(images[id]) and textures.has(id): images[id].texture=textures[id]


func _build_emote_gallery(entry: Dictionary) -> void:
	var shop := _cosmetic_mode=="shop"
	var owned: bool=services.emote_shop.product("dance_01").get("owned",false)
	var emotes: Array=[{"id":"dance","name":"Dancinha","context":"ADQUIRIDO" if owned else "100 moedas","animation":"dance_preview"}] if shop else CharacterCatalog.emotes_for(entry)
	var buy := _preview.find_child("BuyEmotePreview",true,false) as Button
	if shop and buy!=null:
		buy.text=tr("ADQUIRIDO" if owned else "COMPRAR")
		buy.disabled=owned
	_collection_count.text="LOJA · PRÉVIA" if shop else "REAÇÕES · %d" % emotes.size()
	var hint := PlayerUI.label("Emotes de dança · prévia da loja" if shop else "Exemplos de lobby, vitória e derrota",20,PlayerUI.MUTED)
	body.add_child(hint)
	body.move_child(hint,0)
	if emotes.is_empty():
		body.add_child(PlayerUI.label("Este personagem ainda não possui emotes."))
		return
	_grid.columns=1 if shop else 3
	var images := {}
	var group := ButtonGroup.new()
	for emote: Dictionary in emotes:
		var button := _button("",func()->void:
			if shop: _preview_dance()
			elif is_instance_valid(_stage):
				_context_title.text={"Lobby":"No lobby","Vitória":"Você venceu!","Derrota":"Fim de partida"}.get(str(emote.context),str(emote.context))
				_context_hint.text=tr("Exemplo da reação de ")+str(emote.context).to_lower()
				_stage.character.play_emote(StringName(emote.animation)))
		button.name="EmotePreview_"+str(emote.id)
		button.tooltip_text=tr(str(emote.name))+" · "+tr("Toque para visualizar")
		button.toggle_mode=true
		button.button_group=group
		button.custom_minimum_size=Vector2(0,260)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		_grid.add_child(button)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=10;content.offset_right=-10
		content.offset_top=10;content.offset_bottom=-10
		content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var image := TextureRect.new()
		image.name="EmoteThumbnail_"+str(emote.id)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical=Control.SIZE_EXPAND_FILL
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(image)
		images[emote.id]=image
		var label := PlayerUI.label(str(emote.name),20,PlayerUI.TEXT)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		var context := PlayerUI.label(str(emote.context),20,PlayerUI.GOLD)
		context.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		context.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(context)
	_load_emote_previews(entry,_grid,images,shop)


func _load_emote_previews(entry: Dictionary,watch: Control,images: Dictionary,dance := false) -> void:
	var textures: Dictionary=await _emote_previews.capture(self,entry,watch,dance)
	if not is_instance_valid(watch) or watch.is_queued_for_deletion(): return
	for id: String in images:
		if is_instance_valid(images[id]) and textures.has(id): images[id].texture=textures[id]


func _preview_dance() -> void:
	if not is_instance_valid(_stage): return
	if _stage.character.has_animation(&"emote_dance_01"):
		_context_title.text=tr("Dancinha · prévia do movimento")
		_context_hint.text=tr("Emote da loja")
		_stage.character.play_emote(&"emote_dance_01")
		return
	if not DANCE_PREVIEW.install(_stage.character): return
	_context_title.text=tr("Dancinha · prévia do movimento")
	_context_hint.text=tr("Movimento demonstrativo original")
	_stage.character.play_emote(DANCE_PREVIEW.ALIAS)


func _preview_purchase() -> void:
	if is_instance_valid(_buy_dialog): return
	_buy_dialog=Control.new()
	_buy_dialog.name="EmotePurchasePreview"
	var panel := PlayerUI.deck_modal(self,_buy_dialog)
	panel.add_child(PlayerUI.label("Comprar emote",30,PlayerUI.TEXT))
	var details := PlayerUI.label("Dancinha · 100 moedas",22,PlayerUI.GOLD)
	details.name="EmotePurchasePrice"
	panel.add_child(details)
	var feedback := PlayerUI.label("Consultando saldo e disponibilidade…",20,PlayerUI.MUTED)
	feedback.name="EmotePurchaseFeedback"
	panel.add_child(feedback)
	var confirm := PlayerUI.button("COMPRAR POR 100 MOEDAS",func()->void:
		if is_instance_valid(_buy_dialog):
			await _buy_emote(_buy_dialog,_buy_dialog.find_child("ConfirmEmotePurchase",true,false) as Button,feedback))
	confirm.name="ConfirmEmotePurchase"
	confirm.disabled=true
	PlayerUI.editor_control(confirm,true)
	panel.add_child(confirm)
	var coins := PlayerUI.button("COMPRAR MOEDAS",func()->void:
		_close_purchase()
		navigate_requested.emit("wallet",{"tab":"coins"}))
	coins.name="BuyCoinsFromEmote"
	PlayerUI.editor_control(coins)
	panel.add_child(coins)
	var close := PlayerUI.button("Cancelar",_close_purchase)
	close.name="CloseEmotePurchase"
	PlayerUI.editor_control(close)
	panel.add_child(close)
	close.grab_focus.call_deferred()
	var dialog := _buy_dialog
	if not services.session.authenticated():
		feedback.text=tr("Entre na conta para comprar emotes com moedas.")
		return
	var result := await services.emote_shop.refresh()
	if not is_instance_valid(dialog) or dialog!=_buy_dialog: return
	if not result.ok:
		feedback.text=EmoteShopService.message(str(result.code))
		return
	var item := services.emote_shop.product("dance_01")
	if item.is_empty():
		feedback.text=EmoteShopService.message("emote_not_found")
		return
	dialog.set_meta("price",str(item.price_coins).to_int())
	details.text=tr("Dancinha · %s moedas") % str(item.price_coins)
	confirm.text=tr("COMPRAR POR %s MOEDAS") % str(item.price_coins)
	var balance_coins := str(services.emote_shop.data.coins).to_int()
	if item.owned:
		feedback.text=tr("Este emote já está na sua conta.")
		confirm.text=tr("ADQUIRIDO")
	elif not item.available:
		feedback.text=tr("100 moedas. Venda aguardando o movimento real; a prévia continua disponível.")
	elif not _stage.character.has_animation(StringName(item.animation_key)):
		feedback.text=tr("O movimento real ainda não está disponível nesta versão.")
	elif balance_coins<str(item.price_coins).to_int():
		feedback.text=tr("Saldo: %s moedas. Você não tem moedas suficientes.") % str(balance_coins)
	else:
		feedback.text=tr("Saldo: %s moedas. Confirme para adquirir este emote na sua conta.") % str(balance_coins)
		confirm.disabled=false


func _refresh_emote_shop() -> void:
	if not services.session.authenticated(): return
	var result := await services.emote_shop.refresh()
	if is_inside_tree() and is_visible_in_tree() and _cosmetic_mode=="shop" and result.ok: _rebuild_gallery()


func _buy_emote(dialog: Control,confirm: Button,feedback: Label) -> void:
	if dialog!=_buy_dialog or confirm.disabled: return
	confirm.disabled=true
	feedback.text=tr("Processando compra…")
	var close := dialog.find_child("CloseEmotePurchase",true,false) as Button
	if close!=null: close.text=tr("Fechar")
	var owner := str(services.session.user.get("id",""))
	var result := await services.emote_shop.buy("dance_01",int(dialog.get_meta("price",100)))
	if owner!=str(services.session.user.get("id","")): return
	if result.ok: await services.wallet.refresh()
	if not is_instance_valid(dialog) or dialog!=_buy_dialog or owner!=str(services.session.user.get("id","")): return
	if result.ok:
		feedback.text=tr("Compra confirmada. O emote foi salvo na sua conta.")
		confirm.text=tr("ADQUIRIDO")
		_rebuild_gallery()
	else:
		feedback.text=EmoteShopService.message(str(result.code))
		confirm.disabled=false


func _close_purchase() -> void:
	if is_instance_valid(_buy_dialog):
		_buy_dialog.hide()
		_buy_dialog.queue_free()
	_buy_dialog=null


func handle_back() -> bool:
	if not is_instance_valid(_buy_dialog): return false
	_close_purchase()
	return true


func _equip(character_id: String) -> void:
	banner.show_state("loading")
	var result := await services.inventory.equip(character_id)
	if result.ok:
		character_selected.emit(StringName(character_id))
		progress_changed.emit()
		render()
	status(result)


func _generate_thumbnails() -> void:
	_generating = true
	_paths = await _thumbnails.ensure(self, services.inventory.entries)
	_generating = false
	# Captura sequencial; as listas de amigos só leem PNGs existentes.
	for character_id: String in _paths:
		if _images.has(character_id) and is_instance_valid(_images[character_id]):
			_images[character_id].texture = _portrait_texture(_paths[character_id])


## Cartão da galeria: superfície escura com filete frio; o selecionado ganha filete
## dourado e brilho suave, como na referência aprovada.
func _card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PlayerUI.SURFACE
	style.border_color = PlayerUI.GOLD_BRIGHT if selected else PlayerUI.FIELD_BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(10)
	style.anti_aliasing = true
	style.shadow_color = Color(PlayerUI.GOLD, 0.35) if selected else Color(0, 0, 0, 0.3)
	style.shadow_size = 10 if selected else 4
	style.set_content_margin_all(6)
	return style


## Botões do modelo (PlayerUI): o principal é dourado; os demais, escuros com filete.
func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = PlayerUI.CONTROL_HEIGHT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", PlayerUI.CONTROL_FONT)
	PlayerUI.style_button(button, primary)
	button.pressed.connect(action)
	PlayerUI.fluid(button)
	return button


## Retratos das cartas: busto recortado e em cache (PlayerUI.bust).
func _portrait_texture(path: String) -> Texture2D:
	return PlayerUI.bust(path)


func _load_collections() -> void:
	_collections.clear()
	for file in DirAccess.get_files_at(COLLECTIONS_DIR):
		if not file.ends_with(".json"): continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COLLECTIONS_DIR + file))
		if parsed is Dictionary and parsed.has("id"): _collections.append(parsed)
	_collections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("order", 99)) != int(b.get("order", 99)): return int(a.get("order", 99)) < int(b.get("order", 99))
		return str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) < 0)
	if _collections.is_empty():
		_collections.append({"id": "comeco", "name": "Começo", "source": "inventory", "color": "azul"})
	_collection = clampi(_collection, 0, _collections.size() - 1)
	_collection_title = str(_collections[_collection].get("name", "Começo"))


## "inventory" (ou lista vazia) = todos os personagens cadastrados; senão, os IDs listados.
func _collection_ids(collection: Dictionary) -> Array[String]:
	var all: Array[String] = []
	for entry: Dictionary in services.inventory.entries: all.append(str(entry.id))
	var listed: Array = collection.get("character_ids", [])
	if str(collection.get("source", "")) == "inventory" or listed.is_empty(): return all
	var ids: Array[String] = []
	for id in listed:
		if all.has(str(id)): ids.append(str(id))
	return ids


func _choose_collection(index: int) -> void:
	_collection = index
	_collection_title = str(_collections[index].get("name", ""))
	_build_collections()
	_rebuild_gallery()
	PlayerUI.cascade(_grid)


## Barra lateral: uma placa por coleção com a cor dela, nome e quantos já estão liberados.
func _build_collections() -> void:
	if _collection_list == null: return
	PlayerUI.clear(_collection_list)
	for index in range(_collections.size()):
		var collection: Dictionary = _collections[index]
		var chosen := index == _collection
		var ids := _collection_ids(collection)
		var owned := ids.filter(func(id: String) -> bool: return services.inventory.is_unlocked(id)).size()
		var button := Button.new()
		button.name = "Collection_" + str(collection.id)
		button.toggle_mode = true
		button.button_pressed = chosen
		button.custom_minimum_size = Vector2(0, 52)
		button.focus_mode = Control.FOCUS_ALL
		PlayerUI.style_row(button)
		button.pressed.connect(_choose_collection.bind(index))
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 10)
		button.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 14
		line.offset_right = -14
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Marcador pequeno com a cor da coleção (sem textura decorativa).
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = PlayerUI.swatch(str(collection.get("color", "azul")))
		chip_style.set_corner_radius_all(5)
		chip.custom_minimum_size = Vector2(14, 14)
		chip.add_theme_stylebox_override("panel", chip_style)
		line.add_child(chip)
		var ink := Color("#f4f1e6")
		var title := PlayerUI.label(str(collection.get("name", "")), 17, ink)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.clip_text = true
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(title)
		var count := PlayerUI.label("%d/%d" % [owned, ids.size()], 15, ink if chosen else PlayerUI.MUTED)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(count)
		_collection_list.add_child(button)


## Fundo das cartas da versão aprovada: brilho radial cinza-azulado atrás do busto.
func _atmosphere_texture() -> Texture2D:
	if _atmosphere == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color("#3a342e"), Color("#18202c"), Color("#0d131d")])
		gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		_atmosphere = GradientTexture2D.new()
		_atmosphere.gradient = gradient
		_atmosphere.fill = GradientTexture2D.FILL_RADIAL
		_atmosphere.fill_from = Vector2(0.5, 0.35)
		_atmosphere.fill_to = Vector2(1.0, 1.0)
	return _atmosphere


func _showcase(parent: Control, character_id: String) -> LobbyStage:
	var stage := preload("res://scenes/lobby/lobby_stage.tscn").instantiate() as LobbyStage
	stage.set_script(preload("res://scripts/skins/showcase_stage.gd"))
	stage.interactive = true
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(stage)
	stage.show_character(services.inventory.entry(character_id))
	stage.call("prepare_showcase")
	return stage


func _favorite_button(character_id: String) -> Button:
	var button := _button("", _toggle_favorite.bind(character_id))
	button.set_script(preload("res://scripts/skins/favorite_button.gd"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.set("active", _favorites.has(character_id))
	button.tooltip_text = "Remover dos favoritos" if _favorites.has(character_id) else "Adicionar aos favoritos"
	return button
