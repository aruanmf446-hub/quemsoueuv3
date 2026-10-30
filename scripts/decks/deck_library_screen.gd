extends Control
## Biblioteca local, somente leitura. Integrar à navegação após validação visual.
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
const BACKGROUND = Color("#101925")
const ACCENT = Color("#efca83")
var _stack: VBoxContainer
var _query := ""
var _deck: Dictionary = {}
var _index := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render_library()

func _page(title: String) -> VBoxContainer:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 12)
	margin.add_child(_stack)
	_stack.add_child(_text(title, 28, ACCENT))
	return _stack

func _text(value: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _action(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	return button

func _content() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box

func _render_library() -> void:
	_deck = {}
	_index = -1
	_page("BIBLIOTECA DE DECKS")
	_stack.add_child(_text("Explore os decks oficiais e suas cartas."))
	var entry := LineEdit.new()
	entry.placeholder_text = "Pesquisar por deck ou criador"
	entry.text = _query
	entry.text_changed.connect(func(value: String) -> void:
		_query = value
		_update_results()
	)
	_stack.add_child(entry)
	var host := _content()
	host.name = "Results"
	_update_results()

func _update_results() -> void:
	var host := _stack.get_node_or_null("Results") as VBoxContainer
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	var count := 0
	for item in Catalog.decks():
		var haystack := ("%s %s" % [item.name, item.creator]).to_lower()
		if not _query.is_empty() and not haystack.contains(_query.to_lower()):
			continue
		count += 1
		var label := "%s%s   ·   %s cartas" % [item.name, "  ✓ OFICIAL" if item.official else "", item.count]
		host.add_child(_action(label, _render_deck.bind(item)))
	if count == 0:
		host.add_child(_text("Nenhum deck encontrado."))

func _render_deck(item: Dictionary) -> void:
	_deck = item
	_index = -1
	_page(str(item.name))
	_stack.add_child(_action("← Voltar à Biblioteca", _render_library))
	if item.official:
		_stack.add_child(_text("✓ OFICIAL  ·  Quem Sou Eu", 16, ACCENT))
	_stack.add_child(_text("%d cartas · A–Z" % item.count))
	var host := _content()
	var grid := GridContainer.new()
	grid.columns = 4
	host.add_child(grid)
	for i in range(item.cards.size()):
		var card: Dictionary = item.cards[i]
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 145
		grid.add_child(column)
		var preview := TextureButton.new()
		preview.custom_minimum_size = Vector2(140, 160)
		preview.ignore_texture_size = true
		preview.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_normal = load(str(card.image))
		preview.pressed.connect(_render_card.bind(i))
		column.add_child(preview)
		column.add_child(_text(str(card.name), 14))

func _render_card(index: int) -> void:
	var entries: Array = _deck.get("cards", [])
	if index < 0 or index >= entries.size():
		return
	_index = index
	var card: Dictionary = entries[index]
	_page(str(card.name))
	_stack.add_child(_action("← Todas as cartas", _render_deck.bind(_deck)))
	var texture := TextureRect.new()
	texture.texture = load(str(card.image))
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(texture)
	var description := str(card.description)
	if not description.is_empty():
		_stack.add_child(_text(description))
	var footer := HBoxContainer.new()
	_stack.add_child(footer)
	var previous := _action("← Anterior", _render_card.bind(index - 1))
	previous.disabled = index == 0
	footer.add_child(previous)
	footer.add_child(_text("  %d / %d  " % [index + 1, entries.size()]))
	var next := _action("Próxima →", _render_card.bind(index + 1))
	next.disabled = index == entries.size() - 1
	footer.add_child(next)
