extends PlayerScreen

## Evolução do painel existente: mantém catálogo, ThumbnailCache e LobbyStage originais.
## Layout: galeria rolável à esquerda (duas colunas) e prévia 3D fixa à direita, fora da rolagem.
signal character_selected(character_id: StringName)
signal progress_changed
const PREVIEW_FILL_RATIO := 0.76
const CARD_BG := Color("#111d30")
const CARD_BG_SELECTED := Color("#25344e")
const CARD_BORDER := Color("#455269")
const BUTTON_BG := Color("#27364e")
const ACCENT := Color("#f2b66e")
const SMALL_SCREEN := 1100.0
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
	heading.text = tr("Skins")
	_thumbnails = ThumbnailCache.new(preload("res://scenes/lobby/lobby_stage.tscn"))
	# Moldura azul/dourada gigante removida desta tela; o fundo do lobby permanece.
	$CrestFrame.hide()
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
	_split = HBoxContainer.new()
	_split.name = "SkinsShowcase"
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 18)
	column.add_child(_split)
	column.move_child(_split, _scroll.get_index())
	_scroll.reparent(_split)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_stretch_ratio = 0.8
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side = PanelContainer.new()
	_side.name = "HeroPreview"
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.size_flags_stretch_ratio = 1.2
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_theme_stylebox_override("panel", _panel_style(false))
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
	_back_button.custom_minimum_size = Vector2(86 if compact else 130, 38 if compact else 50)
	_back_button.add_theme_font_size_override("font_size", 16 if compact else 21)
	heading.add_theme_font_size_override("font_size", 23 if compact else 37)
	$Margin/Column.add_theme_constant_override("separation", 6 if compact else 12)
	_split.add_theme_constant_override("separation", 8 if compact else 18)
	_scroll.size_flags_stretch_ratio = 0.75 if compact else 0.85
	_side.size_flags_stretch_ratio = 1.4 if compact else 1.15
	if _grid != null:
		_grid.columns = 1 if compact else 2
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
	PlayerUI.clear(body)
	_images.clear()
	_cards.clear()
	# Sem texto de demonstração: o banner só aparece para erros e estados de carregamento.
	banner.show_state("success")
	_grid = GridContainer.new()
	_grid.columns = 1 if size.x < SMALL_SCREEN else 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	body.add_child(_grid)
	for entry: Dictionary in services.inventory.entries:
		_grid.add_child(_gallery_card(entry))
	_select(_selected)
	_responsive_layout()
	if not _generating:
		_generate_thumbnails()


func _gallery_card(entry: Dictionary) -> PanelContainer:
	var character_id: String = entry.id
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(character_id == _selected))
	_cards[character_id] = card
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var thumbnail := TextureRect.new()
	thumbnail.name = "Portrait"
	thumbnail.custom_minimum_size = Vector2(110, 130)
	thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := str(_paths.get(character_id, ThumbnailCache.path_for(character_id)))
	if FileAccess.file_exists(path):
		thumbnail.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	row.add_child(thumbnail)
	_images[character_id] = thumbnail
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var name_label := PlayerUI.label(entry.name, 19, Color("#faf2df"))
	name_label.clip_text = true
	info.add_child(name_label)
	var unlocked := services.inventory.is_unlocked(character_id)
	var equipped: bool = services.inventory.equipped_id() == character_id
	var state := PlayerUI.label("EQUIPADO" if equipped else ("DISPONÍVEL" if unlocked else "BLOQUEADO"), 12, ACCENT if unlocked else Color("#a8b3c4"))
	info.add_child(state)
	var view := _button("VISUALIZAR", _select.bind(character_id))
	view.custom_minimum_size.y = 34
	view.add_theme_font_size_override("font_size", 14)
	info.add_child(view)
	_style_card_height(card, size.x < SMALL_SCREEN)
	return card


func _style_card_height(card: Control, compact: bool) -> void:
	card.custom_minimum_size.y = 100 if compact else 168
	var portrait: TextureRect = card.get_node_or_null("HBoxContainer/Portrait")
	if portrait != null:
		portrait.custom_minimum_size = Vector2(65, 76) if compact else Vector2(110, 130)


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
	_stage = preview(_preview, character_id)
	if _stage != null:
		_stage.custom_minimum_size = Vector2.ZERO
		_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_stage.fill_ratio = PREVIEW_FILL_RATIO
		_stage.frame_character()
		_stage.set_zoom(ThumbnailCache.framing_zoom(character_id))
	_description = PlayerUI.label(str(entry.get("description", "")), 16)
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
			_images[character_id].texture = ImageTexture.create_from_image(Image.load_from_file(_paths[character_id]))


func _panel_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG_SELECTED if selected else CARD_BG
	style.border_color = ACCENT if selected else CARD_BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
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
