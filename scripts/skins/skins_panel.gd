extends PlayerScreen

## Evolução do painel existente: mantém catálogo, ThumbnailCache e LobbyStage originais.
## Layout: galeria rolável à esquerda (duas colunas) e prévia 3D fixa à direita, fora da rolagem.
signal character_selected(character_id: StringName)
signal progress_changed
const PREVIEW_FILL_RATIO := 0.70
const COLLECTION_FILE := "res://data/collections/comeco.json"
var _collection_title := "Começo"
var _collection_count: Label
const CARD_BG := Color("#111d30")
const CARD_BG_SELECTED := Color("#25344e")
const CARD_BORDER := Color("#455269")
const BUTTON_BG := Color("#27364e")
const ACCENT := Color("#f2b66e")
const SMALL_SCREEN := 1100.0
const FAVORITES_PATH := "user://skins_favorites.cfg"
var _favorites: Dictionary = {}
var _favorite_only := false
var _search := ""
var _status_filter := 0
var _reverse_sort := false
var _toolbar: HBoxContainer
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


func _ready() -> void:
	super._ready()
	heading.text = tr("Personagens")
	$Tint.color = Color(0.025, 0.04, 0.09, 0.76)
	_load_collection()
	_thumbnails = ThumbnailCache.new(preload("res://scenes/lobby/lobby_stage.tscn"))
	# Moldura azul/dourada gigante removida desta tela; o fundo do lobby permanece.
	$CrestFrame.hide()
	_load_favorites()
	_split_layout()
	get_viewport().size_changed.connect(_responsive_layout)
	_responsive_layout()
	services.inventory.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


## Separa a galeria (rolável, à esquerda) da prévia (fixa, à direita).
func _split_layout() -> void:
	var column: VBoxContainer = $Margin/Column
	_scroll = $Margin/Column/Scroll
	_header = $Margin/Column/Header
	_back_button = $Margin/Column/Header/Back
	var tabs := HBoxContainer.new()
	tabs.name = "CatalogTabs"
	tabs.add_theme_constant_override("separation", 8)
	_header.add_child(tabs)
	# Só a aba Personagens tem função nesta versão; as demais aparecem marcadas como "em breve".
	for label: String in ["◆ Personagens", "♧ Skins", "⚔ Armas", "✦ Personalização"]:
		var active := label == "◆ Personagens"
		var tab := _button(label if active else label + " · em breve", func() -> void: pass, active)
		tab.custom_minimum_size = Vector2(0, 42)
		tab.add_theme_font_size_override("font_size", 15)
		tab.disabled = not active
		tabs.add_child(tab)
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
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	_gallery_section.add_child(_toolbar)
	_gallery_section.move_child(_toolbar, 0)
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Pesquisar personagem..."
	_search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_field.text_changed.connect(func(value: String) -> void:
		_search = value
		_rebuild_gallery())
	_toolbar.add_child(_search_field)
	_fav_button = _button("♡ Favoritos", _toggle_favorite_only)
	_fav_button.custom_minimum_size = Vector2(112, 42)
	_toolbar.add_child(_fav_button)
	_filter_button = OptionButton.new()
	for value in ["Todos", "Disponíveis", "Bloqueados"]:
		_filter_button.add_item(value)
	_filter_button.item_selected.connect(func(index: int) -> void:
		_status_filter = index
		_rebuild_gallery())
	_toolbar.add_child(_filter_button)
	_sort_button = OptionButton.new()
	_sort_button.add_item("A-Z")
	_sort_button.add_item("Z-A")
	_sort_button.item_selected.connect(func(index: int) -> void:
		_reverse_sort = index == 1
		_rebuild_gallery())
	_toolbar.add_child(_sort_button)
	_collection_sidebar = VBoxContainer.new()
	_collection_sidebar.name = "Collections"
	_collection_sidebar.custom_minimum_size.x = 216
	_collection_sidebar.add_theme_constant_override("separation", 14)
	_split.add_child(_collection_sidebar)
	_split.move_child(_collection_sidebar, 0)
	var collection_panel := PanelContainer.new()
	collection_panel.add_theme_stylebox_override("panel", _panel_style(false))
	_collection_sidebar.add_child(collection_panel)
	var categories := VBoxContainer.new()
	categories.add_theme_constant_override("separation", 10)
	collection_panel.add_child(categories)
	categories.add_child(PlayerUI.label("◈  COLEÇÕES", 20, ACCENT))
	var collection := _button("✦  " + _collection_title.to_upper(), func() -> void: _rebuild_gallery(), true)
	collection.custom_minimum_size.y = 52
	categories.add_child(collection)
	_collection_count = PlayerUI.label("", 15, Color("#a8b9d0"))
	categories.add_child(_collection_count)
	_scroll.get_parent().move_child(_scroll, 1)
	_side = PanelContainer.new()
	_side.name = "HeroPreview"
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.size_flags_stretch_ratio = 1.0
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var showcase_style := _panel_style(false)
	showcase_style.bg_color = Color(0.025, 0.07, 0.14, 0.89)
	showcase_style.border_color = Color(0.31, 0.40, 0.53, 0.8)
	_side.add_theme_stylebox_override("panel", showcase_style)
	_split.add_child(_side)
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 6)
	_side.add_child(_preview)


func _responsive_layout() -> void:
	var compact := size.x < SMALL_SCREEN
	var margin: MarginContainer = $Margin
	var inset := 12 if compact else 32
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, inset)
	_header.add_theme_constant_override("separation", 12 if compact else 22)
	var tabs: HBoxContainer = _header.get_node("CatalogTabs")
	tabs.visible = not compact
	_back_button.custom_minimum_size = Vector2(86 if compact else 130, 38 if compact else 50)
	_back_button.add_theme_font_size_override("font_size", 16 if compact else 21)
	heading.add_theme_font_size_override("font_size", 23 if compact else 37)
	$Margin/Column.add_theme_constant_override("separation", 6 if compact else 12)
	_split.add_theme_constant_override("separation", 8 if compact else 18)
	_scroll.size_flags_stretch_ratio = 1.0
	_gallery_section.size_flags_stretch_ratio = 1.45 if compact else 1.65
	_side.size_flags_stretch_ratio = 1.15 if compact else 1.0
	_collection_sidebar.visible = not compact
	_toolbar.add_theme_constant_override("separation", 4 if compact else 8)
	_fav_button.text = "♥" if compact else ("♥ Favoritos" if _favorite_only else "♡ Favoritos")
	_fav_button.custom_minimum_size.x = 34 if compact else 112
	_search_field.placeholder_text = "Pesquisar..." if compact else "Pesquisar personagem..."
	if _grid != null:
		_grid.columns = 2 if compact else 4
		for item in _grid.get_children():
			_style_card_height(item, compact)
	if _stage != null and is_instance_valid(_stage):
		_stage.custom_minimum_size = Vector2.ZERO
	if _description != null and is_instance_valid(_description):
		_description.visible = not compact


func open(equipped_id: String = "") -> void:
	_selected = equipped_id
	show_screen()


func close() -> void:
	back_requested.emit()


func render() -> void:
	if _selected.is_empty():
		_selected = services.inventory.equipped_id()
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
	_grid.columns = 2 if size.x < SMALL_SCREEN else 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(_grid)
	var entries: Array = services.inventory.entries.duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) > 0 if _reverse_sort else str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) < 0)
	var count := 0
	for entry: Dictionary in entries:
		var id: String = str(entry.id)
		var unlocked: bool = services.inventory.is_unlocked(id)
		if not _search.is_empty() and not str(entry.name).to_lower().contains(_search.to_lower()):
			continue
		if _favorite_only and not _favorites.has(id):
			continue
		if _status_filter == 1 and not unlocked:
			continue
		if _status_filter == 2 and unlocked:
			continue
		_grid.add_child(_gallery_card(entry))
		count += 1
	if count == 0:
		body.add_child(PlayerUI.label("Nenhum personagem encontrado.", 19))
	if _fav_button != null:
		_fav_button.text = "♥ Favoritos" if _favorite_only else "♡ Favoritos"
	if _collection_count != null:
		var obtained := 0
		for item: Dictionary in services.inventory.entries:
			if services.inventory.is_unlocked(str(item.id)):
				obtained += 1
		_collection_count.text = "%d / %d personagens obtidos" % [obtained, services.inventory.entries.size()]


func _gallery_card(entry: Dictionary) -> PanelContainer:
	var character_id: String = entry.id
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(character_id == _selected))
	_cards[character_id] = card
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	card.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var favorite := _button("♥" if _favorites.has(character_id) else "♡", _toggle_favorite.bind(character_id))
	favorite.custom_minimum_size = Vector2(30, 28)
	favorite.add_theme_font_size_override("font_size", 17)
	top.add_spacer(false)
	top.add_child(favorite)
	var thumbnail := TextureRect.new()
	thumbnail.name = "Portrait"
	thumbnail.custom_minimum_size = Vector2(0, 195)
	thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := str(_paths.get(character_id, ThumbnailCache.path_for(character_id)))
	if FileAccess.file_exists(path):
		thumbnail.texture = _portrait_texture(path)
	column.add_child(thumbnail)
	_images[character_id] = thumbnail
	var name_label := PlayerUI.label(entry.name, 21, Color("#faf2df"))
	name_label.clip_text = true
	column.add_child(name_label)
	var equipped: bool = services.inventory.equipped_id() == character_id
	var unlocked: bool = services.inventory.is_unlocked(character_id)
	var state := _button("EQUIPADO" if equipped else ("DISPONÍVEL" if unlocked else "BLOQUEADO"), _select.bind(character_id), equipped)
	state.custom_minimum_size.y = 30
	state.add_theme_font_size_override("font_size", 12)
	column.add_child(state)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select(character_id))
	_style_card_height(card, size.x < SMALL_SCREEN)
	return card


func _style_card_height(card: Control, compact: bool) -> void:
	card.custom_minimum_size.y = 0
	var portrait: TextureRect = card.get_node_or_null("VBoxContainer/Portrait")
	if portrait != null:
		portrait.custom_minimum_size.y = 70 if compact else 195


func _toggle_favorite(character_id: String) -> void:
	if _favorites.has(character_id):
		_favorites.erase(character_id)
	else:
		_favorites[character_id] = true
	_save_favorites()
	_rebuild_gallery()


func _toggle_favorite_only() -> void:
	_favorite_only = not _favorite_only
	_rebuild_gallery()


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


func _select(character_id: String) -> void:
	_selected = character_id
	for id: String in _cards:
		(_cards[id] as PanelContainer).add_theme_stylebox_override("panel", _panel_style(id == character_id))
	PlayerUI.clear(_preview)
	var entry := services.inventory.entry(character_id)
	if entry.is_empty():
		_preview.add_child(PlayerUI.label("Selecione uma skin."))
		return
	var compact := size.x < SMALL_SCREEN
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	_preview.add_child(heading_row)
	var name_label := PlayerUI.label(entry.name, 23 if compact else 34, Color("#fff0dc"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(name_label)
	var equipped := services.inventory.equipped_id() == character_id
	var unlocked := services.inventory.is_unlocked(character_id)
	heading_row.add_child(PlayerUI.label("EQUIPADO" if equipped else ("DISPONÍVEL" if unlocked else "BLOQUEADO"), 12 if compact else 16, ACCENT))
	var favorite := _button("♥" if _favorites.has(character_id) else "♡", _toggle_favorite.bind(character_id))
	favorite.custom_minimum_size = Vector2(36, 34)
	heading_row.add_child(favorite)
	var arrows := HBoxContainer.new()
	_preview.add_child(arrows)
	var left_arrow := _button("‹", _select_neighbor.bind(-1))
	left_arrow.custom_minimum_size = Vector2(44, 36)
	arrows.add_child(left_arrow)
	var hint := PlayerUI.label("Arraste para girar • Coleção Começo", 13, Color("#a8b9d0"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrows.add_child(hint)
	var right_arrow := _button("›", _select_neighbor.bind(1))
	right_arrow.custom_minimum_size = Vector2(44, 36)
	arrows.add_child(right_arrow)
	var details := PlayerUI.label(_collection_title + "  •  " + ("Equipado" if equipped else ("Disponível" if unlocked else "Bloqueado")), 15, ACCENT)
	_preview.add_child(details)
	_stage = preview(_preview, character_id)
	if _stage != null:
		_stage.custom_minimum_size = Vector2.ZERO
		_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stage.fill_ratio = PREVIEW_FILL_RATIO
		_stage.frame_character()
		_stage.set_zoom(ThumbnailCache.framing_zoom(character_id))
	_description = PlayerUI.label(str(entry.get("description", "")), 16)
	_description.custom_minimum_size.y = 36
	_description.visible = not compact
	_preview.add_child(_description)
	if not unlocked:
		var lock_label := PlayerUI.label(PlayerProgress.lock_label(entry), 14 if compact else 17, Color("#ffcf8a"))
		_preview.add_child(lock_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_preview.add_child(actions)
	var equip := _button("EQUIPADO" if equipped else ("EQUIPAR" if unlocked else "BLOQUEADO"), _equip.bind(character_id), true)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.custom_minimum_size.y = 36 if compact else 48
	equip.disabled = not unlocked or equipped
	actions.add_child(equip)
	var back := _button("VOLTAR", close)
	back.custom_minimum_size.y = 36 if compact else 48
	actions.add_child(back)


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


func _panel_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.17, 0.29, 0.88) if selected else Color(0.06, 0.11, 0.20, 0.80)
	style.border_color = ACCENT if selected else CARD_BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style


## Botão plano, sem a textura decorativa dos botões gerais do jogo.
func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 22)
	var base := BUTTON_BG if not primary else Color("#a75f3a")
	var states := {"normal": base, "hover": base.lightened(0.12), "pressed": base.darkened(0.2), "focus": base, "disabled": Color("#1a2333")}
	for state: String in states:
		var style := StyleBoxFlat.new()
		style.bg_color = states[state]
		style.set_corner_radius_all(12)
		style.set_border_width_all(2 if state == "focus" else 0)
		style.border_color = ACCENT
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f4f1e6"))
	button.add_theme_color_override("font_disabled_color", Color("#7d8796"))
	button.pressed.connect(action)
	return button


## Renderiza retratos do cache existente sem alterar os GLB ou a prévia 3D.
## A região superior da captura contém rosto/tronco, e o corte permanece dentro do canvas.
func _portrait_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	var source_width := image.get_width()
	var source_height := image.get_height()
	var crop_height := int(source_height * 0.56)
	var crop_width := int(min(source_width, crop_height * 0.90))
	var crop_x := maxi(0, (source_width - crop_width) / 2)
	var crop_y := int(source_height * 0.04)
	var cropped := image.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))
	cropped.resize(384, 450, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cropped)


func _load_collection() -> void:
	if not FileAccess.file_exists(COLLECTION_FILE):
		return
	var file := FileAccess.open(COLLECTION_FILE, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_collection_title = str(parsed.get("name", "Começo"))
