extends PlayerScreen
## Descoberta pública dos decks, favoritos e rascunhos do dono atual (neste aparelho).
## Publicar depende do backend: o fluxo existe até a revisão e avisa quando não há servidor.
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
const TABS := ["Descobrir", "Populares", "Recentes", "Favoritos", "Meus Decks"]
var _query := ""
var _tab := "Descobrir"
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
## Uma busca no servidor por visita à aba (evita repetir a cada redesenho).
var _pulled_decks := false
var _pulled_favorites := false
var _remote_busy := false
## Filtros e ordenação (T23). _demo_entries só é preenchido por testes/capturas.
var _types := {}
var _themes := {}
var _sort := ""
var _featured := 0
var _covers := {}
var _filter_panel: Control
var _demo_entries: Array[Dictionary] = []
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
		_pulled_decks = false
		_pulled_favorites = false
		_remote_error.clear()
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
		if _view == "library": _fit_tiles()
		elif is_instance_valid(_grid): _fit_grid()

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
	_search.editable = true
	var compact := _compact()
	var tabs := HBoxContainer.new()
	tabs.name = "LibraryTabs"
	tabs.add_theme_constant_override("separation", 6 if compact else 12)
	body.add_child(tabs)
	_tabs.clear()
	for text: String in TABS:
		var button := Button.new()
		button.name = "Tab" + text.replace(" ", "")
		button.text = tr(text)
		button.toggle_mode = true
		button.button_pressed = _tab == text
		button.custom_minimum_size = Vector2(0, 34 if compact else 46)
		button.add_theme_font_size_override("font_size", 14 if compact else 18)
		PremiumUI.style_tab(button)
		for state in ["normal", "disabled"]: button.add_theme_stylebox_override(state, PremiumUI.flat(Color.TRANSPARENT, Color.TRANSPARENT, 10, 0, 14 if compact else 22))
		for state in ["pressed", "hover_pressed"]:
			var box := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			box.set_content_margin_all(14 if compact else 22)
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, box)
		button.pressed.connect(_select_tab.bind(text))
		tabs.add_child(button)
		_tabs.append(button)
	var rule := ColorRect.new()
	rule.color = Color(PremiumUI.GOLD, 0.25)
	rule.custom_minimum_size.y = 1
	body.add_child(rule)
	var layout := HBoxContainer.new()
	layout.name = "LibraryLayout"
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12 if compact else 24)
	body.add_child(layout)
	_results = VBoxContainer.new()
	_results.name = "DeckResults"
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results.add_theme_constant_override("separation", 10 if compact else 18)
	layout.add_child(_results)
	_filter_panel = _filters()
	layout.add_child(_filter_panel)
	_update_results()


func _select_tab(tab: String) -> void:
	_tab = tab
	# "Meus Decks" mostra os próprios; nas outras abas o filtro de tipo continua o do jogador.
	if tab == "Meus Decks": _types = {"mine": true}
	elif _types.size() == 1 and _types.has("mine"): _types = {}
	for i in range(_tabs.size()): _tabs[i].button_pressed = TABS[i] == tab
	_sort = ""
	_render_library()
	PlayerUI.cascade(_results)


# --- Modelo único das abas: oficiais, comunidade e meus rascunhos ---------------------

## Entradas reais. Decks de demonstração só existem quando um TESTE preenche _demo_entries.
func _entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _catalog:
		result.append({"id": str(item.id), "name": str(item.name), "origin": "official" if item.official else "community",
			"creator": str(item.creator), "category": str(item.category), "count": int(item.count),
			"cover": str(item.cards[0].image) if not item.cards.is_empty() else "", "item": item})
	for draft: Dictionary in _store().list():
		var cards: Array = draft.get("cards", [])
		result.append({"id": "draft:" + str(draft.id), "name": str(draft.name) if not str(draft.name).is_empty() else tr("Sem nome"),
			"origin": "mine", "creator": tr("Você"), "category": str(draft.get("category", "")), "count": cards.size(),
			"cover": _store().preview_path(str(draft.id), cards[0]) if not cards.is_empty() else "",
			"edited": float(draft.get("updated_at", 0)), "draft": draft})
	for demo: Dictionary in _demo_entries: result.append(demo)
	return result


func _matches(entry: Dictionary) -> bool:
	if not _types.is_empty() and not _types.has(str(entry.origin)): return false
	if not _themes.is_empty() and not _themes.has(str(entry.category)): return false
	var term := Catalog.search_key(_query)
	return term.is_empty() or Catalog.search_key("%s %s" % [entry.name, entry.creator]).contains(term)


## Ordenações sustentadas pelos dados atuais (sem popularidade nem datas inventadas).
func _sort_options() -> Array:
	match _tab:
		"Favoritos": return [["recent_favorite", "Adicionados recentemente"], ["name", "Nome A–Z"]]
		"Meus Decks": return [["edited", "Última edição"], ["name", "Nome A–Z"]]
	return [["name", "Nome A–Z"]]


func _sorted(list: Array[Dictionary]) -> Array[Dictionary]:
	var mode := _sort if not _sort.is_empty() else str(_sort_options()[0][0])
	if mode == "edited":
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("edited", 0)) > float(b.get("edited", 0)))
	elif mode == "recent_favorite":
		var order := _store().favorites()
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order.find(str(a.id)) > order.find(str(b.id)))
	else:
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Catalog.search_key(a.name).naturalnocasecmp_to(Catalog.search_key(b.name)) < 0)
	return list


func _update_results() -> void:
	if not is_instance_valid(_results): return
	PlayerUI.clear(_results)
	var all := _entries()
	var shown: Array[Dictionary] = []
	for entry in all:
		if _tab == "Favoritos" and not _store().is_favorite(str(entry.id)): continue
		if _tab == "Meus Decks" and entry.origin != "mine": continue
		if _matches(entry): shown.append(entry)
	shown = _sorted(shown)
	if _tab == "Descobrir": _discover_top(all)
	var titles := {"Descobrir": ["layers", "Resultados"], "Populares": ["bolt", "Decks populares"], "Recentes": ["clock", "Decks recentes"], "Favoritos": ["star", "Meus favoritos"], "Meus Decks": ["layers", "Meus decks"]}
	_results_header(titles[_tab][0], "%s (%d)" % [tr(titles[_tab][1]), shown.size()])
	if _tab == "Populares": _notice("A popularidade ainda não é medida pelo servidor. Mostrando todos os decks de A a Z.")
	if _tab == "Recentes": _notice("As datas de publicação ainda não estão disponíveis. Mostrando todos os decks de A a Z.")
	if _tab == "Meus Decks": _remote_section.call_deferred("decks")
	if _tab == "Favoritos": _remote_section.call_deferred("favorites")
	if shown.is_empty():
		_empty_results()
		return
	_grid = GridContainer.new()
	_grid.name = "DeckGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10 if _compact() else 18)
	_grid.add_theme_constant_override("v_separation", 10 if _compact() else 18)
	_results.add_child(_grid)
	for entry in shown: _grid.add_child(_deck_tile(entry))
	if _tab == "Meus Decks": _grid.add_child(_create_tile())
	_fit_tiles()


func _results_header(icon: String, title: String) -> void:
	var compact := _compact()
	var row := HBoxContainer.new()
	row.name = "ResultsHeader"
	row.add_theme_constant_override("separation", 10)
	_results.add_child(row)
	row.add_child(PremiumUI.icon_rect(icon, PremiumUI.GOLD, 22 if compact else 32))
	var label := PremiumUI.plain(title, 17 if compact else 26, Color.WHITE, false)
	label.name = "ResultsTitle"
	row.add_child(label)
	if _tab == "Meus Decks":
		var create := PremiumUI.action("Criar novo deck", "user_plus", true, _create_deck, compact)
		create.name = "CreateDeck"
		create.icon = null
		create.text = "+  " + tr("Criar novo deck")
		row.add_child(create)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(PremiumUI.plain("Ordenar por:", 12 if compact else 16, PremiumUI.MUTED))
	var options := OptionButton.new()
	options.name = "SortBy"
	var modes := _sort_options()
	for mode: Array in modes: options.add_item(tr(mode[1]))
	var current := _sort if not _sort.is_empty() else str(modes[0][0])
	for i in range(modes.size()): if modes[i][0] == current: options.select(i)
	options.custom_minimum_size = Vector2(140 if compact else 220, 32 if compact else 44)
	options.add_theme_font_size_override("font_size", 13 if compact else 17)
	PremiumUI.style_outline(options)
	options.item_selected.connect(func(index: int) -> void:
		_sort = str(modes[index][0])
		_update_results())
	row.add_child(options)


func _notice(text: String) -> void:
	var note := PlayerUI.label(text, 12 if _compact() else 15, PremiumUI.MUTED)
	note.name = "DataNotice"
	_results.add_child(note)


func _empty_results() -> void:
	var box := VBoxContainer.new()
	box.name = "EmptyResults"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size.y = 160 if _compact() else 280
	box.add_theme_constant_override("separation", 12)
	_results.add_child(box)
	var filtered := not _query.strip_edges().is_empty() or not _themes.is_empty() or (not _types.is_empty() and _tab != "Meus Decks")
	var title: String = "Nenhum deck encontrado" if filtered else {"Favoritos": "Você ainda não tem decks favoritos.", "Meus Decks": "Você ainda não criou decks."}.get(_tab, "Nenhum deck disponível")
	var heading_label := PlayerUI.label(title, 18 if _compact() else 26, Color.WHITE)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading_label)
	var button: Button
	if filtered:
		button = PremiumUI.action("Limpar filtros", "refresh", false, _clear_filters, _compact())
		button.name = "ClearSearch"
	elif _tab == "Meus Decks":
		button = PremiumUI.action("Criar novo deck", "user_plus", true, _create_deck, _compact())
		button.name = "CreateDeckEmpty"
	else:
		button = PremiumUI.action("Explorar decks", "search", true, _select_tab.bind("Descobrir"), _compact())
		button.name = "ExploreDecks"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 220 if _compact() else 300
	box.add_child(button)


func _clear_filters() -> void:
	_query = ""
	_search.clear()
	_themes.clear()
	_types = {"mine": true} if _tab == "Meus Decks" else {}
	_render_library()


func _create_deck() -> void:
	_draft = _store().new_draft()
	_render_editor()


## Descobrir: destaque oficial e coleções (contagens calculadas dos dados reais).
func _discover_top(all: Array[Dictionary]) -> void:
	var compact := _compact()
	var featured: Array[Dictionary] = []
	for entry in all:
		if entry.origin == "official": featured.append(entry)
	if not featured.is_empty() and _query.strip_edges().is_empty():
		_featured = clampi(_featured, 0, featured.size() - 1)
		_results.add_child(_banner(featured[_featured], featured.size()))
	var counts := {"official": 0, "themed": 0, "community": 0, "mine": 0}
	for entry in all:
		counts[entry.origin] = int(counts.get(entry.origin, 0)) + 1
		if not str(entry.category).is_empty(): counts.themed += 1
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(PremiumUI.icon_rect("layers", PremiumUI.GOLD, 22 if compact else 30))
	head.add_child(PremiumUI.plain("Coleções em destaque", 16 if compact else 24, Color.WHITE))
	_results.add_child(head)
	var row := HBoxContainer.new()
	row.name = "Collections"
	row.add_theme_constant_override("separation", 8 if compact else 16)
	_results.add_child(row)
	for item: Array in [["Oficiais", "crown", "official", counts.official], ["Temáticos", "tag", "themed", counts.themed], ["Comunidade", "friends", "community", counts.community], ["Meus Decks", "cards", "mine", counts.mine]]:
		var card := Button.new()
		card.name = "Collection_" + str(item[2])
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 52 if compact else 86
		PremiumUI.style_tab(card)
		card.pressed.connect(_open_collection.bind(str(item[2])))
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 10 if compact else 18)
		card.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left = 12 if compact else 24
		line.add_child(PremiumUI.icon_rect(item[1], PremiumUI.GOLD, 22 if compact else 40))
		var text := VBoxContainer.new()
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_theme_constant_override("separation", 0)
		line.add_child(text)
		text.add_child(PremiumUI.plain(item[0], 13 if compact else 21, Color.WHITE))
		text.add_child(PremiumUI.plain(tr("%d decks") % int(item[3]) if int(item[3]) != 1 else tr("1 deck"), 11 if compact else 17, PremiumUI.MUTED, false))
		row.add_child(card)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	_results.add_child(rule)


func _open_collection(kind: String) -> void:
	_themes.clear()
	if kind == "mine":
		_select_tab("Meus Decks")
		return
	if kind == "themed":
		_types = {}
		for entry in _entries():
			if not str(entry.category).is_empty(): _themes[str(entry.category)] = true
	else:
		_types = {kind: true}
	_render_library()


func _banner(entry: Dictionary, total: int) -> Control:
	var compact := _compact()
	var banner_panel := PanelContainer.new()
	banner_panel.name = "FeaturedBanner"
	banner_panel.custom_minimum_size.y = 150 if compact else 250
	var frame := PremiumUI.flat(Color(0.03, 0.04, 0.07), Color(PremiumUI.GOLD, 0.45), 16, 1, 0)
	banner_panel.add_theme_stylebox_override("panel", frame)
	banner_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var art := TextureRect.new()
	art.texture = _cover(str(entry.cover))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.add_child(art)
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float a = 1.0 - smoothstep(0.18, 0.62, UV.x); COLOR = vec4(0.02, 0.03, 0.06, 0.25 + a * 0.7); }"
	material.shader = shader
	shade.material = material
	banner_panel.add_child(shade)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16 if compact else 44)
	banner_panel.add_child(margin)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 4 if compact else 10)
	margin.add_child(text)
	if entry.origin == "official":
		var seal := PlayerUI.pill("OFICIAL", "equipped")
		seal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text.add_child(seal)
	text.add_child(PremiumUI.plain(str(entry.name), 22 if compact else 44, Color.WHITE, false))
	text.add_child(PremiumUI.plain("%s  •  %s" % [entry.creator, tr("%d cartas") % int(entry.count)], 13 if compact else 20, Color("#d6dbe4"), false))
	var explore := PremiumUI.action("Explorar coleção  →", "layers", true, _open_entry.bind(entry), compact)
	explore.name = "ExploreFeatured"
	explore.icon = null
	explore.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	text.add_child(explore)
	# Pontos só quando há mais de um destaque real.
	if total > 1:
		var dots := HBoxContainer.new()
		dots.name = "BannerDots"
		dots.add_theme_constant_override("separation", 8)
		for i in total:
			var dot := Button.new()
			dot.custom_minimum_size = Vector2(14, 14)
			dot.add_theme_stylebox_override("normal", PremiumUI.flat(PremiumUI.GOLD if i == _featured else Color(1, 1, 1, 0.35), Color.TRANSPARENT, 7, 0, 0))
			dot.pressed.connect(func() -> void:
				_featured = i
				_update_results())
			dots.add_child(dot)
		text.add_child(dots)
	return banner_panel


func _open_entry(entry: Dictionary) -> void:
	if entry.has("item") and not entry.item.is_empty(): _render_deck(entry.item)
	elif entry.has("draft"):
		_draft = entry.draft
		_render_editor()


## Cartão de deck: capa horizontal enquadrada, selo, nome, cartas e coração (ou menu ⋯).
func _empty(parent: Node, title: String, message: String, font_size := 26) -> void:
	parent.add_child(_text(title, font_size))
	parent.add_child(_text(message, 16, PlayerUI.MUTED))


func _deck_tile(entry: Dictionary) -> Control:
	var compact := _compact()
	var tile := Button.new()
	tile.name = "Deck_" + str(entry.id).replace(":", "_")
	tile.tooltip_text = str(entry.name)
	tile.focus_mode = Control.FOCUS_ALL
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := PremiumUI.flat(Color(0.05, 0.07, 0.11), PremiumUI.EDGE if state == "normal" else Color(PremiumUI.GOLD, 0.7), 14, 1 if state == "normal" else 2, 0)
		if state == "focus": box.draw_center = false
		tile.add_theme_stylebox_override(state, box)
	tile.clip_contents = true
	tile.pressed.connect(_open_entry.bind(entry))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	tile.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cover := TextureRect.new()
	cover.name = "Cover"
	cover.texture = _cover(str(entry.cover))
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.size_flags_stretch_ratio = 1.5
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.clip_contents = true
	column.add_child(cover)
	if entry.origin == "official":
		var seal := PlayerUI.pill("OFICIAL", "equipped")
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(seal)
		seal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		seal.position += Vector2(10, -32)
	var info := MarginContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: info.add_theme_constant_override("margin_" + side, 10 if compact else 14)
	for side in ["top", "bottom"]: info.add_theme_constant_override("margin_" + side, 4 if compact else 8)
	column.add_child(info)
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 2)
	info.add_child(lines)
	var title := PremiumUI.plain(str(entry.name), 14 if compact else 21, Color.WHITE, false)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(title)
	var meta := HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override("separation", 6)
	lines.add_child(meta)
	if entry.origin == "mine":
		var edited := PlayerContracts.ago(float(entry.get("edited", 0)))
		if not edited.is_empty():
			meta.add_child(PremiumUI.icon_rect("pencil", PremiumUI.MUTED, 12 if compact else 16))
			meta.add_child(PremiumUI.plain(tr("Editado ") + edited, 11 if compact else 14, PremiumUI.MUTED, false))
	meta.add_child(PremiumUI.icon_rect("cards", PremiumUI.MUTED, 12 if compact else 16))
	meta.add_child(PremiumUI.plain(tr("%d cartas") % int(entry.count), 11 if compact else 14, PremiumUI.MUTED, false))
	if entry.origin == "mine":
		var state := str(entry.draft.get("sync_state", "local"))
		var pill_text: String = {"synced": "NA CONTA", "pending": "ENVIANDO", "error": "ERRO AO ENVIAR"}.get(state, "RASCUNHO")
		var pill := PlayerUI.pill(pill_text, "equipped" if state == "synced" else "available")
		pill.name = "SyncState"
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.add_child(pill)
	var corner := _deck_menu(entry) if entry.origin == "mine" else _heart(str(entry.id))
	tile.add_child(corner)
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.anchor_top = 1.0
	corner.anchor_bottom = 1.0
	corner.offset_left = -50
	corner.offset_right = -6
	corner.offset_top = -46
	corner.offset_bottom = -6
	return tile


func _create_tile() -> Control:
	var tile := Button.new()
	tile.name = "CreateDeckTile"
	tile.text = "+\n" + tr("Criar novo deck")
	tile.add_theme_font_size_override("font_size", 14 if _compact() else 20)
	var dashed := PremiumUI.flat(Color(0.04, 0.06, 0.1), Color(1, 1, 1, 0.22), 14, 1, 0)
	for state in ["normal", "hover", "pressed", "focus"]: tile.add_theme_stylebox_override(state, dashed)
	tile.add_theme_color_override("font_color", Color.WHITE)
	tile.pressed.connect(_create_deck)
	return tile


## Menu ⋯ dos decks próprios: só ações que existem de verdade.
func _deck_menu(entry: Dictionary) -> Control:
	var menu := MenuButton.new()
	menu.name = "DeckMenu"
	menu.text = "⋯"
	menu.flat = true
	menu.add_theme_font_size_override("font_size", 22)
	menu.add_theme_color_override("font_color", Color.WHITE)
	var popup := menu.get_popup()
	popup.add_item(tr("Abrir / Editar"), 0)
	popup.add_item(tr("Duplicar"), 1)
	popup.add_item(tr("Revisar e publicar"), 2)
	popup.add_separator()
	popup.add_item(tr("Excluir"), 3)
	popup.id_pressed.connect(_menu_action.bind(entry))
	return menu


func _menu_action(id: int, entry: Dictionary) -> void:
	var draft: Dictionary = entry.draft
	match id:
		0: _open_entry(entry)
		1: _duplicate_draft(draft)
		2:
			_draft = draft
			_render_review()
		3: _confirm_delete(draft)


func _duplicate_draft(draft: Dictionary) -> void:
	var copy := _store().new_draft()
	copy.name = (str(draft.name) + " " + tr("(cópia)")).left(DeckDrafts.NAME_MAX)
	for key in ["description", "category", "visibility"]: copy[key] = draft.get(key, copy[key])
	for card: Dictionary in draft.get("cards", []):
		var clone := {"id": "card_%d_%d" % [Time.get_ticks_msec(), randi() % 100000], "name": card.get("name", ""), "description": card.get("description", ""), "crops": card.get("crops", {}).duplicate(true), "image_file": ""}
		var bytes := _store().file_bytes(str(draft.id), str(card.get("image_file", "")))
		if not bytes.is_empty():
			clone.image_file = _store().store_original(str(copy.id), str(clone.id), bytes, str(card.image_file).get_extension())
			var image := _store().original_image(str(copy.id), clone)
			if image != null: _store().store_previews(str(copy.id), clone, image)
		copy.cards.append(clone)
	_store().save(copy)
	banner.show_state("success", "Cópia criada neste aparelho.")
	_update_results()


## Capas: texturas importadas (res://) ou prévias locais em cache (sem reler o disco a cada filtro).
func _cover(path: String) -> Texture2D:
	if path.is_empty(): return null
	if path.begins_with("res://"): return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if not FileAccess.file_exists(path): return null
	var key := "%s@%d" % [path, FileAccess.get_modified_time(path)]
	if not _covers.has(key):
		var image := Image.load_from_file(path)
		_covers[key] = ImageTexture.create_from_image(image) if image != null else null
	return _covers[key]


func _fit_tiles() -> void:
	if not is_instance_valid(_grid) or _grid.name != "DeckGrid": return
	var width := _physical_size().x - (_filter_panel.custom_minimum_size.x if is_instance_valid(_filter_panel) and _filter_panel.visible else 0.0) - (60 if _compact() else 130)
	_grid.columns = clampi(floori(width / (190 if _compact() else 300)), 2, 4)
	var tile_width := (width - (_grid.columns - 1) * 18) / _grid.columns
	for tile: Control in _grid.get_children(): tile.custom_minimum_size = Vector2(tile_width, tile_width * (0.62 if _compact() else 0.6))


# --- Painel "Filtrar decks" --------------------------------------------------------------

func _filters() -> Control:
	var compact := _compact()
	var panel := PremiumUI.panel("FilterPanel", 10 if compact else 20)
	panel.custom_minimum_size.x = 170 if compact else 300
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4 if compact else 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(PremiumUI.icon_rect("filter", PremiumUI.GOLD, 18 if compact else 28))
	head.add_child(PremiumUI.plain("Filtrar decks", 15 if compact else 24, Color.WHITE))
	column.add_child(head)
	column.add_child(_filter_group("Tipo", [["Oficiais", "official"], ["Comunidade", "community"], ["Meus decks", "mine"]], _types, "Type_"))
	var themes: Array = []
	for entry in _entries():
		var category := str(entry.category)
		if not category.is_empty() and not themes.has([category, category]): themes.append([category, category])
	themes.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	var theme_group := _filter_group("Temática", themes, _themes, "Theme_")
	if themes.is_empty(): theme_group.add_child(PlayerUI.label("Os decks ainda não informam temática.", 11 if compact else 14, PremiumUI.MUTED))
	column.add_child(theme_group)
	var clear := PremiumUI.action("Limpar filtros", "refresh", false, _clear_filters, compact)
	clear.name = "ClearFilters"
	column.add_child(clear)
	return panel


func _filter_group(title: String, options: Array, selected: Dictionary, prefix: String) -> VBoxContainer:
	var compact := _compact()
	var group := VBoxContainer.new()
	group.name = "Group_" + title
	group.add_theme_constant_override("separation", 0 if compact else 4)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.08)
	rule.custom_minimum_size.y = 1
	group.add_child(rule)
	group.add_child(PremiumUI.plain(title, 13 if compact else 20, Color.WHITE))
	for option: Array in options:
		var box := CheckBox.new()
		box.name = prefix + str(option[1]).replace(" ", "_")
		box.text = tr(str(option[0]))
		box.button_pressed = selected.has(str(option[1]))
		box.add_theme_font_size_override("font_size", 12 if compact else 17)
		box.add_theme_color_override("font_color", Color("#e8edf5"))
		box.add_theme_color_override("font_pressed_color", Color.WHITE)
		box.add_theme_icon_override("checked", _check_icon(true))
		box.add_theme_icon_override("unchecked", _check_icon(false))
		box.toggled.connect(func(value: bool) -> void:
			if value: selected[str(option[1])] = true
			else: selected.erase(str(option[1]))
			_update_results())
		group.add_child(box)
	return group


func _check_icon(on: bool) -> Texture2D:
	var key := "check_%s" % on
	if _covers.has(key): return _covers[key]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24">' + ('<rect x="2" y="2" width="20" height="20" rx="5" fill="#e8b860"/><path d="M6.5 12.5l3.5 3.5 7.5-8" fill="none" stroke="#141006" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>' if on else '<rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="#a8bad3" stroke-width="1.6"/>') + '</svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	image.resize(22, 22, Image.INTERPOLATE_LANCZOS)
	_covers[key] = ImageTexture.create_from_image(image)
	return _covers[key]


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
		if _view == "library" and _tab == "Favoritos": _update_results.call_deferred()
		var sync := _sync()
		if sync.available():
			var result: Dictionary = await sync.set_remote_favorite(deck_id, value)
			if result.ok and not value: _store().clear_pending_favorite(deck_id)
			if not result.ok and is_inside_tree():
				banner.show_state("error", "Favorito salvo neste aparelho; a conta será atualizada na próxima conexão."))
	return heart


func _sync() -> CreatorSync:
	return CreatorSync.for_current(_store())


## Busca no servidor uma vez por visita; mostra carregando, erro e "Tentar novamente".
## Falha não repete sozinha: só pelo botão, para não martelar o servidor.
var _remote_error := {}
func _remote_section(kind: String) -> void:
	if not is_instance_valid(_results): return
	var sync := _sync()
	if not sync.available():
		_results.add_child(_text("Entre na conta para guardar também no servidor. Aqui tudo fica salvo neste aparelho.", 14, PlayerUI.MUTED))
		return
	if _remote_busy:
		var loading := _text("Sincronizando com a sua conta…", 14, PlayerUI.MUTED)
		loading.name = "RemoteLoading"
		_results.add_child(loading)
		return
	if _remote_error.has(kind):
		_results.add_child(_text("Não foi possível falar com o servidor (%s). Seus dados continuam salvos neste aparelho." % str(_remote_error[kind]), 14, Color("#ff9797")))
		var retry := _action("Tentar novamente", func() -> void:
			_remote_error.erase(kind)
			if kind == "decks": _pulled_decks = false
			else: _pulled_favorites = false
			_update_results())
		retry.name = "RetrySync"
		_results.add_child(retry)
		return
	if (_pulled_decks if kind == "decks" else _pulled_favorites): return
	_remote_busy = true
	var loading := _text("Sincronizando com a sua conta…", 14, PlayerUI.MUTED)
	loading.name = "RemoteLoading"
	_results.add_child(loading)
	var result: Dictionary
	if kind == "decks": result = await sync.pull()
	else: result = await sync.sync_favorites()
	_remote_busy = false
	if kind == "decks": _pulled_decks = true
	else: _pulled_favorites = true
	if not result.ok: _remote_error[kind] = str(result.get("code", "erro"))
	if is_inside_tree() and _view == "library": _update_results()


func _confirm_delete(draft: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "ConfirmDeleteDraft"
	dialog.title = tr("Excluir rascunho")
	dialog.dialog_text = tr("Excluir \"%s\" deste aparelho e da sua conta? Não dá para desfazer.") % (str(draft.name) if not str(draft.name).is_empty() else tr("Sem nome"))
	dialog.ok_button_text = tr("Excluir")
	dialog.cancel_button_text = tr("Cancelar")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		# Só o dono atual enxerga (e apaga) a própria pasta de rascunhos.
		# Servidor primeiro; a cópia local só sai depois que ele confirmar.
		var result: Dictionary = await _sync().remove(draft)
		if not result.ok: banner.show_state("error", "Não foi possível excluir na conta. O rascunho continua salvo; tente novamente.")
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
	if not result.ok:
		status(result)
		return
	var sync := _sync()
	if not sync.available():
		banner.show_state("success", "Rascunho salvo neste aparelho.")
		return
	banner.show_state("loading")
	_report(await sync.push(_draft))


func _report(result: Dictionary) -> void:
	if not is_inside_tree(): return
	if result.ok: banner.show_state("success", "Rascunho salvo neste aparelho e na sua conta.")
	elif result.code == "deck_incomplete": banner.show_state("success", "Salvo neste aparelho. " + CreatorSync.deck_ready(_draft if not _draft.is_empty() else {}))
	else: banner.show_state("error", "Salvo neste aparelho, mas não na conta (%s). Use \"Tentar novamente\" em Meus Decks." % str(result.code))


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
	body.add_child(_text("A publicação para a comunidade ainda não está habilitada no servidor. O rascunho fica salvo neste aparelho e na sua conta.", 14, PlayerUI.MUTED))
	_reveal()
