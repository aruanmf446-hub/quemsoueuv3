extends PlayerScreen
## Public, read-only deck discovery. Account features remain explicitly unavailable.
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
const TABS := ["Descobrir", "Populares", "Recentes", "Favoritos", "Meus Decks"]
var _query := ""
var _tab := "Descobrir"
var _category := ""
var _deck: Dictionary = {}
var _index := -1
var _view := "library"
var _catalog: Array[Dictionary] = []
var _search: LineEdit
var _results: VBoxContainer
var _tabs: Array[Button] = []
var _grid: GridContainer
var _reader_image: TextureRect
var _reader_previous: Button
var _reader_next: Button
var _reader_gallery: Button
var _refresh_width := -1.0
var _gallery_scroll := 0

func _ready() -> void:
	super._ready()
	_catalog = Catalog.decks()
	_search = LineEdit.new()
	_search.name = "DeckSearch"
	_search.placeholder_text = tr("Pesquisar deck ou criador")
	_search.tooltip_text = tr("Pesquisar pelo nome do deck ou do criador")
	_search.custom_minimum_size = Vector2(360, 44)
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.add_theme_font_size_override("font_size", 16)
	PlayerUI.style_field(_search)
	_search.text_changed.connect(func(value: String) -> void:
		_query = value
		_update_results())
	$Margin/Column/Header.add_child(_search)
	resized.connect(_layout_changed)

func render() -> void:
	var requested := str(parameters.get("deck_id", ""))
	if not requested.is_empty():
		var item := Catalog.find_deck(requested)
		if item.is_empty():
			_render_library()
			PlayerUI.clear(_results)
			_empty(_results, "Coleção indisponível", "Este deck não está disponível para consulta.")
			return
		_render_deck(item)
		var card_id := str(parameters.get("card_id", ""))
		if not card_id.is_empty():
			for i in range(item.cards.size()):
				if item.cards[i].id == card_id:
					_render_card(i)
					return
		return
	_render_library()

func _physical_size() -> Vector2:
	return size / PlayerUI.unit(self)

func _compact() -> bool:
	return _physical_size().y < 600

func _adapt_scale() -> void:
	super._adapt_scale()
	_layout_changed()

func _layout_changed() -> void:
	if not is_instance_valid(_search): return
	var width := _physical_size().x
	_search.custom_minimum_size.x = 360 if width >= 1100 else (240 if width >= 800 else 190)
	heading.add_theme_font_size_override("font_size", 24 if width < 900 else 34)
	$Margin/Column/Header.add_theme_constant_override("separation", 16 if width < 900 else 28)
	if not is_equal_approx(_refresh_width, width):
		_refresh_width = width
		if is_instance_valid(_grid): _fit_grid()

func _page(title: String, view: String) -> void:
	_view = view
	_grid = null
	PlayerUI.clear(body)
	banner.hide()
	heading.text = title
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT if view == "library" else Node.AUTO_TRANSLATE_MODE_DISABLED
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12 if _compact() else 20)
	$Margin/Column/Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if view == "reader" else ScrollContainer.SCROLL_MODE_AUTO
	_search.visible = view == "library"
	var back: Button = $Margin/Column/Header/Back
	back.text = tr("‹ Voltar" if view == "library" else ("‹ Biblioteca" if view == "deck" else "‹ Galeria"))
	back.custom_minimum_size.x = 100 if view == "library" else 120
	_layout_changed()
	_refit_margin.call_deferred()

func _render_library() -> void:
	_deck = {}
	_index = -1
	_page("BIBLIOTECA DE DECKS", "library")
	_search.text = _query
	var tabs := PlayerUI.flow(body)
	tabs.name = "LibraryTabs"
	_tabs.clear()
	for text: String in TABS:
		var button := _action(text, _select_tab.bind(text))
		button.name = "Tab" + text.replace(" ", "")
		PlayerUI.style_row(button)
		button.custom_minimum_size.x = 0
		button.add_theme_font_size_override("font_size", 14 if _compact() else 16)
		button.toggle_mode = true
		button.button_pressed = _tab == text
		tabs.add_child(button)
		_tabs.append(button)
	_results = PlayerUI.column(body)
	_results.name = "DeckResults"
	_update_results()

func _select_tab(tab: String) -> void:
	_tab = tab
	_query = ""
	_search.clear()
	_search.editable = not tab in ["Favoritos", "Meus Decks"]
	for i in range(_tabs.size()): _tabs[i].button_pressed = TABS[i] == tab
	_update_results()
	PlayerUI.cascade(_results)

func _update_results() -> void:
	if not is_instance_valid(_results): return
	PlayerUI.clear(_results)
	if _tab != "Descobrir":
		_empty(_results, _tab, _empty_message(_tab))
		return
	var matches: Array[Dictionary] = []
	var term := Catalog.search_key(_query)
	for item in _catalog:
		if (_category.is_empty() or item.category == _category) and (term.is_empty() or Catalog.search_key("%s %s" % [item.name, item.creator]).contains(term)):
			matches.append(item)
	if matches.is_empty():
		_empty(_results, "Nenhum deck encontrado", "Experimente outro nome de deck ou criador.")
		_results.add_child(_action("Limpar busca", func() -> void:
			_query = ""
			_category = ""
			_search.clear()
			_update_results()))
		return
	var all_official := matches.all(func(item: Dictionary) -> bool: return item.official)
	_results.add_child(_text(("DESTAQUES OFICIAIS" if all_official else "COLEÇÕES") if term.is_empty() else "RESULTADOS DA BUSCA", 12, PlayerUI.GOLD))
	for item in matches: _results.add_child(_deck_card(item))
	_results.add_child(_text("CATEGORIAS", 12, PlayerUI.GOLD))
	var categories: Array[String] = []
	for item in _catalog:
		if not str(item.category).is_empty() and not categories.has(item.category): categories.append(item.category)
	if categories.is_empty():
		_results.add_child(_text("Os decks deste catálogo ainda não têm categorias informadas.", 15, PlayerUI.MUTED))
	else:
		var topics := PlayerUI.flow(_results)
		for category: String in ["Todos"] + categories:
			var target := "" if category == "Todos" else category
			var chip := _action(category, func() -> void:
				_category = target
				_update_results())
			PlayerUI.style_row(chip)
			chip.toggle_mode = true
			chip.button_pressed = _category == target
			topics.add_child(chip)
	if term.is_empty():
		var sections := PlayerUI.split(_results)
		for title: String in ["Populares", "Recentes", "Favoritos"]:
			var section := PlayerUI.column(sections)
			section.add_child(HSeparator.new())
			_empty(section, title, _empty_message(title), 18)

func _empty_message(section: String) -> String:
	return {
		"Populares": "Ainda não há dados de popularidade disponíveis.",
		"Recentes": "As datas de publicação ainda não estão disponíveis.",
		"Favoritos": "Salvar decks como favoritos ainda não está disponível nesta versão.",
		"Meus Decks": "A criação e a publicação de decks ainda não estão disponíveis nesta versão."
	}.get(section, "")

func _empty(parent: Node, title: String, message: String, font_size := 26) -> void:
	parent.add_child(_text(title, font_size))
	parent.add_child(_text(message, 16, PlayerUI.MUTED))

func _deck_card(item: Dictionary) -> Button:
	var card := _action("", _render_deck.bind(item))
	card.name = "Deck_" + str(item.id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 176 if _compact() else 260
	card.clip_contents = true
	card.tooltip_text = tr("Explorar coleção") + ": " + str(item.name)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16 if _compact() else 28)
	var row := PlayerUI.row(margin)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := PlayerUI.column(row)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_stretch_ratio = 1.2
	if item.official:
		var seal := PlayerUI.pill("OFICIAL", "equipped")
		seal.name = "OfficialSeal"
		seal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		info.add_child(seal)
	info.add_child(_data_text(item.name, 28 if _compact() else 44))
	info.add_child(_data_text("%s  ·  %d cartas" % [item.creator if not str(item.creator).is_empty() else "Autoria não informada", item.count], 15, PlayerUI.MUTED))
	info.add_child(_text("EXPLORAR COLEÇÃO  →", 14, PlayerUI.GOLD))
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size.x = 160 if _physical_size().x < 760 else (230 if _compact() else 360)
	row.add_child(art)
	for index in range(mini(3, item.cards.size())):
		var image := _image(item.cards[index].image)
		art.add_child(image)
		image.z_index = 2 if index == 1 else 1
	var fit := func() -> void:
		var height := maxf(art.size.y - 16, 1)
		var width := height * 5.0 / 7.0
		for index in range(art.get_child_count()):
			var image: Control = art.get_child(index)
			image.size = Vector2(width, height)
			image.position = Vector2((art.size.x - width) * 0.5 + (index - 1) * width * 0.58, 8)
			image.pivot_offset = image.size * 0.5
			image.rotation = (index - 1) * 0.09
	art.resized.connect(fit)
	fit.call_deferred()
	return card

func _render_deck(item: Dictionary) -> void:
	if _deck.get("id", "") != item.id: _gallery_scroll = 0
	_deck = item
	_index = -1
	_page(str(item.name), "deck")
	var metadata := PlayerUI.flow(body)
	metadata.name = "DeckMetadata"
	if item.official: metadata.add_child(PlayerUI.pill("OFICIAL", "equipped"))
	metadata.add_child(_data_text(str(item.creator) if not str(item.creator).is_empty() else "Autoria não informada", 16, PlayerUI.MUTED))
	metadata.add_child(_text("%d cartas  ·  A–Z" % item.count, 16, PlayerUI.MUTED))
	if not str(item.category).is_empty(): metadata.add_child(_data_text(item.category, 16))
	for tag: String in item.tags: metadata.add_child(PlayerUI.pill(tag, "available"))
	if not str(item.age_rating).is_empty(): metadata.add_child(_text("Classificação: " + str(item.age_rating), 16))
	if not str(item.description).is_empty(): body.add_child(_data_text(item.description, 18, PlayerUI.MUTED))
	for warning: String in item.content_warnings: body.add_child(_data_text(warning, 16, PlayerUI.GOLD))
	_grid = GridContainer.new()
	_grid.name = "CardGallery"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	body.add_child(_grid)
	for i in range(item.cards.size()):
		var entry: Dictionary = item.cards[i]
		var button := _action("", _render_card.bind(i))
		button.name = "Card_" + str(entry.id).get_file()
		button.tooltip_text = str(entry.name)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 8)
		var column := PlayerUI.column(margin)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 4)
		var image := _image(entry.image)
		image.name = "CardImage"
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(image)
		var name_label := _data_text(entry.name, 16 if _compact() else 18)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.custom_minimum_size.y = 42
		name_label.max_lines_visible = 2
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		_grid.add_child(button)
	_fit_grid()
	if _grid.get_child_count() > 0: _focus.call_deferred(_grid.get_child(0))
	$Margin/Column/Scroll.set_deferred("scroll_vertical", _gallery_scroll)
	_reveal()

func _fit_grid() -> void:
	if not is_instance_valid(_grid): return
	var available := _physical_size().x - (56 if _compact() else 96)
	_grid.columns = clampi(floori((available + 16) / (148 if _compact() else 236)), 1, 6)
	var width := floorf((available - (_grid.columns - 1) * 16) / _grid.columns)
	var image_height := clampf(_physical_size().y - 240, 120, 210) if _compact() else width * 1.35
	for button: Control in _grid.get_children():
		button.custom_minimum_size = Vector2(width, image_height + 62)
	_refit_margin.call_deferred()

func _render_card(index: int) -> void:
	var entries: Array = _deck.get("cards", [])
	if index < 0 or index >= entries.size(): return
	if _view == "deck": _gallery_scroll = $Margin/Column/Scroll.scroll_vertical
	_index = index
	var entry: Dictionary = entries[index]
	_page(str(entry.name), "reader")
	var row := PlayerUI.row(body)
	row.name = "CardReader"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24 if not _compact() else 16)
	_reader_image = _image(entry.image)
	_reader_image.name = "FullCardImage"
	_reader_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader_image.size_flags_stretch_ratio = 1.4
	row.add_child(_reader_image)
	var info := PlayerUI.column(row)
	info.custom_minimum_size.x = 240 if _compact() else 340
	info.size_flags_stretch_ratio = 1.0
	info.add_child(_text("CARTA %02d / %02d" % [index + 1, entries.size()], 12, PlayerUI.GOLD))
	info.add_child(_data_text(str(_deck.name), 18, PlayerUI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info.add_child(scroll)
	var description := _data_text(str(entry.description) if not str(entry.description).is_empty() else "Descrição ainda não disponível.", 18, PlayerUI.TEXT if not str(entry.description).is_empty() else PlayerUI.MUTED)
	scroll.add_child(description)
	var controls := PlayerUI.row(info)
	controls.add_theme_constant_override("separation", 10)
	_reader_previous = _action("‹ Anterior", _render_card.bind(index - 1))
	_reader_previous.name = "PreviousCard"
	_reader_previous.disabled = index == 0
	controls.add_child(_reader_previous)
	_reader_next = _action("Próxima ›", _render_card.bind(index + 1))
	_reader_next.name = "NextCard"
	_reader_next.disabled = index == entries.size() - 1
	controls.add_child(_reader_next)
	_reader_gallery = _action("Voltar à galeria", func() -> void: handle_back())
	_reader_gallery.name = "ReturnToGallery"
	PlayerUI.style_back(_reader_gallery)
	info.add_child(_reader_gallery)
	_focus.call_deferred(_reader_gallery)
	_reveal()

func handle_back() -> bool:
	if _view == "reader":
		var previous := _index
		_render_deck(_deck)
		if is_instance_valid(_grid) and previous < _grid.get_child_count():
			_focus.call_deferred(_grid.get_child(previous))
		return true
	if _view == "deck":
		var id := str(_deck.id)
		_render_library()
		var card := _results.get_node_or_null("Deck_" + id) as Control
		if card != null: _focus.call_deferred(card)
		_reveal()
		return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _view != "reader" or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		_render_card(_index + (-1 if event.keycode == KEY_LEFT else 1))
		get_viewport().set_input_as_handled()

func _action(text: String, callback: Callable) -> Button:
	var button := PlayerUI.button(text, callback)
	button.custom_minimum_size = Vector2(100, 44)
	button.add_theme_font_size_override("font_size", 16)
	return button

func _text(value: String, font_size := 20, color := PlayerUI.TEXT) -> Label:
	return PlayerUI.label(value, font_size, color)

func _data_text(value: String, font_size := 20, color := PlayerUI.TEXT) -> Label:
	var label := _text(value, font_size, color)
	label.text = value
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _image(path: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return image

func _reveal() -> void:
	PlayerUI.reveal(body, 0.0, 0.18)

func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree(): control.grab_focus()
