extends PlayerScreen
## Descoberta pública dos decks, favoritos e rascunhos do dono atual (neste aparelho).
## Publicar depende do backend: o fluxo existe até a revisão e avisa quando não há servidor.
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
var _draft: Dictionary = {}
var _drafts: DeckDrafts
var _picker: ImagePicker
var _pending_card := -1
var _editor_overlay: CardFrameEditor
const SURFACE_SHADER := """shader_type canvas_item;
// Textura muito sutil e uma linha orgânica discreta: só estética, sem contraste extra.
uniform float seed = 0.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }
void fragment() {
	float grain = noise(UV * vec2(90.0, 40.0)) * 0.5 + noise(UV * vec2(9.0, 4.0)) * 0.5;
	float curve = 0.62 + 0.18 * sin(UV.x * 3.4 + seed) + 0.06 * sin(UV.x * 9.0 + seed * 2.0);
	float line = smoothstep(0.006, 0.0, abs(UV.y - curve)) * smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.55, UV.x);
	float tone = mix(-0.012, 0.022, UV.x) + (grain - 0.5) * 0.035;
	COLOR = vec4(vec3(0.85, 0.74, 0.52), clamp(tone, 0.0, 0.04) + line * 0.07);
}"""

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
	_picker = ImagePicker.new()
	_picker.name = "ImagePicker"
	add_child(_picker)
	_picker.picked.connect(_image_picked)
	_picker.failed.connect(func(message: String) -> void: banner.show_state("error", message))
	if services != null: services.session.changed.connect(func() -> void:
		# Trocar de conta troca também os rascunhos e favoritos visíveis.
		_drafts = null
		if is_visible_in_tree() and _view in ["library", "editor", "review"]:
			_draft = {}
			_render_library())

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
	if _tab == "Favoritos":
		_render_favorites()
		return
	if _tab == "Meus Decks":
		_render_my_decks()
		return
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
		for title: String in ["Populares", "Recentes"]:
			var section := PlayerUI.column(sections)
			section.add_child(HSeparator.new())
			_empty(section, title, _empty_message(title), 18)

func _empty_message(section: String) -> String:
	return {
		"Populares": "Ainda não há dados de popularidade disponíveis.",
		"Recentes": "As datas de publicação ainda não estão disponíveis.",
		"Favoritos": "Toque no coração de um deck para guardá-lo aqui.",
		"Meus Decks": "Crie um deck: os rascunhos ficam salvos neste aparelho."
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
	var actions := PlayerUI.row(info)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 18)
	var explore := _text("EXPLORAR COLEÇÃO  →", 14, PlayerUI.GOLD)
	explore.autowrap_mode = TextServer.AUTOWRAP_OFF
	explore.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	explore.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.add_child(explore)
	actions.add_child(_heart(str(item.id)))
	_surface(card, str(item.id).hash() % 97)
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
	metadata.add_child(_heart(str(item.id)))
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
	if is_instance_valid(_editor_overlay):
		_close_framer()
		return true
	if _view == "review":
		_render_editor()
		return true
	if _view == "editor":
		_draft = {}
		_tab = "Meus Decks"
		_render_library()
		return true
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
	# Animate the new content, so rapid card changes never accumulate body scale.
	for child: Control in body.get_children(): PlayerUI.reveal(child, 0.0, 0.18)

func animate_in() -> void:
	if _view == "library": PlayerUI.cascade(body)

func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree(): control.grab_focus()


# --- Favoritos, Meus Decks, editor e revisão (T21) --------------------------------------

func _store() -> DeckDrafts:
	if _drafts == null: _drafts = DeckDrafts.for_current()
	return _drafts


func _surface(card: Control, seed: int) -> void:
	var surface := ColorRect.new()
	surface.name = "Surface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = false
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SURFACE_SHADER
	material.shader = shader
	material.set_shader_parameter("seed", float(seed))
	surface.material = material
	card.add_child(surface)
	card.move_child(surface, 0)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Hover suave: só um leve clareamento, sem brilho forte.
	card.mouse_entered.connect(func() -> void: card.create_tween().tween_property(card, "self_modulate", Color(1.06, 1.05, 1.02), 0.16))
	card.mouse_exited.connect(func() -> void: card.create_tween().tween_property(card, "self_modulate", Color.WHITE, 0.2))


func _heart(deck_id: String) -> Button:
	var heart := Button.new()
	heart.name = "Favorite"
	heart.toggle_mode = true
	heart.focus_mode = Control.FOCUS_ALL
	heart.custom_minimum_size = Vector2(44, 40)
	heart.button_pressed = _store().is_favorite(deck_id)
	heart.text = "♥" if heart.button_pressed else "♡"
	heart.tooltip_text = tr("Remover dos favoritos" if heart.button_pressed else "Adicionar aos favoritos")
	heart.add_theme_font_size_override("font_size", 22)
	heart.add_theme_color_override("font_color", PlayerUI.MUTED)
	heart.add_theme_color_override("font_pressed_color", Color("#e8817a"))
	heart.add_theme_color_override("font_hover_pressed_color", Color("#f09891"))
	heart.add_theme_color_override("font_hover_color", PlayerUI.TEXT)
	var flat := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]: heart.add_theme_stylebox_override(state, flat)
	heart.toggled.connect(func(value: bool) -> void:
		if not _store().set_favorite(deck_id, value):
			heart.set_pressed_no_signal(not value)
			banner.show_state("error", "Não foi possível salvar o favorito neste aparelho.")
			return
		heart.text = "♥" if value else "♡"
		heart.tooltip_text = tr("Remover dos favoritos" if value else "Adicionar aos favoritos")
		if _view == "library" and _tab == "Favoritos": _update_results.call_deferred())
	return heart


func _render_favorites() -> void:
	var ids := _store().favorites()
	var shown := 0
	_results.add_child(_text("FAVORITOS", 12, PlayerUI.GOLD))
	for item in _catalog:
		if ids.has(str(item.id)):
			_results.add_child(_deck_card(item))
			shown += 1
	if shown == 0:
		_empty(_results, "Nenhum favorito ainda", _empty_message("Favoritos"))
	_results.add_child(_text("Favoritos ficam salvos neste aparelho, na sua conta ou como visitante.", 14, PlayerUI.MUTED))


func _render_my_decks() -> void:
	var create := _action("+  Criar deck", func() -> void:
		_draft = _store().new_draft()
		_render_editor())
	create.name = "CreateDeck"
	PlayerUI.style_button(create, true)
	create.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	create.custom_minimum_size.x = 200
	_results.add_child(create)
	var drafts := _store().list()
	_results.add_child(_text("RASCUNHOS", 12, PlayerUI.GOLD))
	if drafts.is_empty():
		_empty(_results, "Nenhum rascunho", _empty_message("Meus Decks"), 20)
	for draft: Dictionary in drafts:
		var row := PlayerUI.row(_results)
		row.name = "Draft_" + str(draft.id)
		var label := _data_text("%s  ·  %d cartas" % [str(draft.name) if not str(draft.name).is_empty() else tr("Sem nome"), draft.cards.size()], 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(PlayerUI.pill("RASCUNHO", "available"))
		var edit := _action("Editar", func() -> void:
			_draft = draft
			_render_editor())
		edit.name = "EditDraft"
		row.add_child(edit)
		var remove := _action("Excluir", _confirm_delete.bind(draft))
		remove.name = "DeleteDraft"
		row.add_child(remove)
	_results.add_child(_text("PUBLICADOS", 12, PlayerUI.GOLD))
	_results.add_child(_text("Publicar e sincronizar decks depende do servidor, que ainda está em preparação.", 15, PlayerUI.MUTED))


func _confirm_delete(draft: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "ConfirmDeleteDraft"
	dialog.title = tr("Excluir rascunho")
	dialog.dialog_text = tr("Excluir \"%s\" deste aparelho? Não dá para desfazer.") % (str(draft.name) if not str(draft.name).is_empty() else tr("Sem nome"))
	dialog.ok_button_text = tr("Excluir")
	dialog.cancel_button_text = tr("Cancelar")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		# Só o dono atual enxerga (e apaga) a própria pasta de rascunhos.
		_store().delete(str(draft.id))
		_update_results())
	dialog.visibility_changed.connect(func() -> void: if not dialog.visible: dialog.queue_free())
	dialog.popup_centered()


func _render_editor() -> void:
	if _draft.is_empty(): _draft = _store().new_draft()
	_page("Criar deck" if str(_draft.name).is_empty() else str(_draft.name), "editor")
	var back: Button = $Margin/Column/Header/Back
	back.text = tr("‹ Meus Decks")
	var form := PlayerUI.split(body)
	form.name = "DeckForm"
	var left := PlayerUI.column(form)
	left.add_child(_text("NOME", 12, PlayerUI.GOLD))
	var name_field := _field(str(_draft.name), "Nome do deck", DeckDrafts.NAME_MAX)
	name_field.name = "DeckName"
	name_field.text_changed.connect(func(value: String) -> void: _draft.name = value)
	left.add_child(name_field)
	left.add_child(_text("DESCRIÇÃO", 12, PlayerUI.GOLD))
	var description := TextEdit.new()
	description.name = "DeckDescription"
	description.text = str(_draft.description)
	description.placeholder_text = tr("Do que trata este deck?")
	description.custom_minimum_size.y = 90
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	PlayerUI.style_field(description)
	description.text_changed.connect(func() -> void: _draft.description = description.text.left(DeckDrafts.DESCRIPTION_MAX))
	left.add_child(description)
	var right := PlayerUI.column(form)
	right.add_child(_text("CATEGORIA", 12, PlayerUI.GOLD))
	right.add_child(_options("DeckCategory", DeckDrafts.CATEGORIES, DeckDrafts.CATEGORIES, "category"))
	right.add_child(_text("VISIBILIDADE", 12, PlayerUI.GOLD))
	right.add_child(_options("DeckVisibility", ["Privado", "Não listado", "Público"], DeckDrafts.VISIBILITY, "visibility"))
	body.add_child(_text("CARTAS  ·  %d (mínimo %d, máximo %d)" % [_draft.cards.size(), Catalog.MIN_CARDS, Catalog.MAX_CARDS], 12, PlayerUI.GOLD))
	var list := PlayerUI.column(body)
	list.name = "DraftCards"
	for i in range(_draft.cards.size()): list.add_child(_card_row(i))
	var add := _action("+  Adicionar carta", func() -> void:
		if _draft.cards.size() >= Catalog.MAX_CARDS:
			banner.show_state("error", "O deck já tem o máximo de %d cartas." % Catalog.MAX_CARDS)
			return
		_pending_card = -1
		_picker.pick())
	add.name = "AddCard"
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.custom_minimum_size.x = 220
	body.add_child(add)
	var actions := PlayerUI.row(body)
	var save := _action("Salvar rascunho", _save_draft)
	save.name = "SaveDraft"
	actions.add_child(save)
	var review := _action("Revisar e publicar  →", func() -> void:
		await _save_draft()
		_render_review())
	review.name = "ReviewDeck"
	PlayerUI.style_button(review, true)
	actions.add_child(review)
	_reveal()


func _field(value: String, placeholder: String, limit: int) -> LineEdit:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = tr(placeholder)
	field.max_length = limit
	field.custom_minimum_size.y = 44
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PlayerUI.style_field(field)
	return field


func _options(node_name: String, labels: Array, values: Array, key: String) -> OptionButton:
	var options := OptionButton.new()
	options.name = node_name
	options.custom_minimum_size.y = 44
	if key == "category": options.add_item(tr("Escolha…"))
	for label: String in labels: options.add_item(tr(label))
	var offset := 1 if key == "category" else 0
	options.select(values.find(str(_draft.get(key, ""))) + offset if values.has(str(_draft.get(key, ""))) else 0)
	options.item_selected.connect(func(index: int) -> void: _draft[key] = values[index - offset] if index - offset >= 0 else "")
	PlayerUI.style_row(options)
	return options


func _card_row(index: int) -> Control:
	var card: Dictionary = _draft.cards[index]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.name = "DraftCard_%d" % index
	row.add_theme_constant_override("separation", 10)
	var thumb := TextureRect.new()
	thumb.name = "Thumb"
	thumb.custom_minimum_size = Vector2(50, 70)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var preview := _store().preview_path(str(_draft.id), card)
	if FileAccess.file_exists(preview):
		var image := Image.load_from_file(preview)
		if image != null: thumb.texture = ImageTexture.create_from_image(image)
	row.add_child(thumb)
	var fields := PlayerUI.column(row)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_field := _field(str(card.get("name", "")), "Nome da carta", DeckDrafts.CARD_NAME_MAX)
	name_field.name = "CardName"
	name_field.text_changed.connect(func(value: String) -> void: card.name = value)
	fields.add_child(name_field)
	var description := _field(str(card.get("description", "")), "Descrição (opcional)", DeckDrafts.CARD_DESCRIPTION_MAX)
	description.name = "CardDescription"
	description.text_changed.connect(func(value: String) -> void: card.description = value)
	fields.add_child(description)
	var tools := PlayerUI.column(row)
	tools.size_flags_horizontal = Control.SIZE_SHRINK_END
	tools.custom_minimum_size.x = 170
	tools.add_theme_constant_override("separation", 6)
	var arrows := PlayerUI.row(tools)
	var up := _action("↑", _move_card.bind(index, -1))
	up.name = "MoveUp"
	up.custom_minimum_size.x = 44
	up.disabled = index == 0
	arrows.add_child(up)
	var down := _action("↓", _move_card.bind(index, 1))
	down.name = "MoveDown"
	down.custom_minimum_size.x = 44
	down.disabled = index == _draft.cards.size() - 1
	arrows.add_child(down)
	var frame := _action("Enquadrar", _open_framer.bind(index))
	frame.name = "FrameCard"
	frame.disabled = str(card.get("image_file", "")).is_empty()
	tools.add_child(frame)
	var replace := _action("Trocar imagem", func() -> void:
		_pending_card = index
		_picker.pick())
	replace.name = "ReplaceImage"
	tools.add_child(replace)
	var remove := _action("Remover", func() -> void:
		_draft.cards.remove_at(index)
		_render_editor())
	remove.name = "RemoveCard"
	tools.add_child(remove)
	return row


func _move_card(index: int, direction: int) -> void:
	var target := index + direction
	if target < 0 or target >= _draft.cards.size(): return
	var card: Variant = _draft.cards[index]
	_draft.cards[index] = _draft.cards[target]
	_draft.cards[target] = card
	_render_editor()


func _image_picked(image: Image, bytes: PackedByteArray, extension: String) -> void:
	if _view != "editor": return
	var index := _pending_card
	if index < 0:
		if _draft.cards.size() >= Catalog.MAX_CARDS: return
		_draft.cards.append({"id": "card_%d_%d" % [Time.get_ticks_msec(), randi() % 1000], "name": "", "description": "", "image_file": "", "crops": {}})
		index = _draft.cards.size() - 1
	var card: Dictionary = _draft.cards[index]
	var file := _store().store_original(str(_draft.id), str(card.id), bytes, extension)
	if file.is_empty():
		banner.show_state("error", "Não foi possível guardar a imagem neste aparelho.")
		return
	card.image_file = file
	card.image_size = [image.get_width(), image.get_height()]
	card.crops = {}
	_open_framer(index, image)


func _open_framer(index: int, image: Image = null) -> void:
	var card: Dictionary = _draft.cards[index]
	if image == null: image = _store().original_image(str(_draft.id), card)
	if image == null:
		banner.show_state("error", "Imagem original não encontrada.")
		return
	_close_framer()
	_editor_overlay = CardFrameEditor.new()
	add_child(_editor_overlay)
	_editor_overlay.open(image, card.get("crops", {}))
	_editor_overlay.confirmed.connect(func(crops: Dictionary) -> void:
		card.crops = crops
		_store().store_previews(str(_draft.id), card, image)
		_close_framer()
		await _save_draft()
		_render_editor())
	_editor_overlay.cancelled.connect(func() -> void:
		_close_framer()
		_render_editor())


func _close_framer() -> void:
	if is_instance_valid(_editor_overlay): _editor_overlay.queue_free()
	_editor_overlay = null


func _save_draft() -> void:
	var result := _store().save(_draft)
	if not result.ok: status(result)
	else: banner.show_state("success", "Rascunho salvo neste aparelho.")


func _render_review() -> void:
	_page("Revisar deck", "review")
	$Margin/Column/Header/Back.text = tr("‹ Editar")
	var problems := DeckDrafts.problems(_draft)
	body.add_child(_data_text(str(_draft.name) if not str(_draft.name).is_empty() else tr("Sem nome"), 30))
	body.add_child(_data_text("%s  ·  %s  ·  %d cartas" % [str(_draft.category), {"private": "Privado", "unlisted": "Não listado", "public": "Público"}.get(str(_draft.visibility), "—"), _draft.cards.size()], 16, PlayerUI.MUTED))
	if not problems.is_empty():
		body.add_child(_text("ANTES DE PUBLICAR", 12, PlayerUI.GOLD))
		for problem: String in problems: body.add_child(_data_text("•  " + problem, 16, Color("#ff9797")))
	_grid = GridContainer.new()
	_grid.name = "ReviewGallery"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	body.add_child(_grid)
	_grid.columns = clampi(floori((_physical_size().x - 96) / 150), 2, 8)
	for card: Dictionary in _draft.cards:
		var column := PlayerUI.column(_grid)
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(130, 182)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var preview := _store().preview_path(str(_draft.id), card)
		if FileAccess.file_exists(preview): image.texture = ImageTexture.create_from_image(Image.load_from_file(preview))
		column.add_child(image)
		column.add_child(_data_text(str(card.get("name", "")), 14))
	var publish := _action("Publicar", func() -> void: status(_store().publish(_draft)))
	publish.name = "PublishDeck"
	publish.disabled = not problems.is_empty()
	PlayerUI.style_button(publish, true)
	publish.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	publish.custom_minimum_size.x = 200
	body.add_child(publish)
	body.add_child(_text("Publicar depende do servidor, que ainda está em preparação. O rascunho fica salvo neste aparelho.", 14, PlayerUI.MUTED))
	_reveal()
