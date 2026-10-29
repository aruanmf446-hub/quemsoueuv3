extends PlayerScreen

## Evolução do painel existente: mantém catálogo, ThumbnailCache e LobbyStage originais.
## Layout: galeria rolável à esquerda (duas colunas) e prévia 3D fixa à direita, fora da rolagem.
signal character_selected(character_id: StringName)
signal progress_changed
const GALLERY_COLUMNS := 2
const PREVIEW_WIDTH := 560.0
const PREVIEW_FILL_RATIO := 0.86
const CARD_BG := Color("#142640")
const CARD_BG_SELECTED := Color("#22395e")
const CARD_BORDER := Color("#2d4a70")
const BUTTON_BG := Color("#1d3558")
var _thumbnails: ThumbnailCache
var _paths: Dictionary = {}
var _selected := ""
var _generating := false
var _grid: GridContainer
var _preview: VBoxContainer
var _side: PanelContainer
var _images: Dictionary = {}
var _cards: Dictionary = {}


func _ready() -> void:
	super._ready()
	heading.text = tr("Skins")
	_thumbnails = ThumbnailCache.new(preload("res://scenes/lobby/lobby_stage.tscn"))
	# Moldura azul/dourada gigante removida desta tela; o fundo do lobby permanece.
	$CrestFrame.hide()
	_split_layout()
	services.inventory.changed.connect(func() -> void:
		if is_visible_in_tree(): render())


## Separa a galeria (rolável, à esquerda) da prévia (fixa, à direita).
func _split_layout() -> void:
	var column: VBoxContainer = $Margin/Column
	var scroll: ScrollContainer = $Margin/Column/Scroll
	var split := HBoxContainer.new()
	split.name = "Split"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 24)
	column.add_child(split)
	column.move_child(split, scroll.get_index())
	scroll.reparent(split)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	_side = PanelContainer.new()
	_side.name = "Preview"
	_side.custom_minimum_size.x = PREVIEW_WIDTH
	_side.size_flags_horizontal = Control.SIZE_SHRINK_END
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_theme_stylebox_override("panel", _panel_style(false))
	split.add_child(_side)
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 12)
	_side.add_child(_preview)


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
	_grid.columns = GALLERY_COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	body.add_child(_grid)
	for entry: Dictionary in services.inventory.entries:
		_grid.add_child(_gallery_card(entry))
	_select(_selected)
	if not _generating:
		_generate_thumbnails()


func _gallery_card(entry: Dictionary) -> PanelContainer:
	var character_id: String = entry.id
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(character_id == _selected))
	_cards[character_id] = card
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)
	var thumbnail := TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(0, 380)
	thumbnail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := str(_paths.get(character_id, ThumbnailCache.path_for(character_id)))
	if FileAccess.file_exists(path):
		thumbnail.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	content.add_child(thumbnail)
	_images[character_id] = thumbnail
	content.add_child(PlayerUI.label(entry.name, 26, PlayerUI.GOLD))
	var unlocked := services.inventory.is_unlocked(character_id)
	var equipped: bool = services.inventory.equipped_id() == character_id
	content.add_child(PlayerUI.label("Equipado" if equipped else ("Desbloqueado" if unlocked else "Bloqueado"), 19))
	content.add_child(_button("Visualizar", _select.bind(character_id)))
	return card


func _select(character_id: String) -> void:
	_selected = character_id
	for id: String in _cards:
		(_cards[id] as PanelContainer).add_theme_stylebox_override("panel", _panel_style(id == character_id))
	PlayerUI.clear(_preview)
	var entry := services.inventory.entry(character_id)
	if entry.is_empty():
		_preview.add_child(PlayerUI.label("Selecione uma skin."))
		return
	_preview.add_child(PlayerUI.label(entry.name, 32, PlayerUI.GOLD))
	var stage := preview(_preview, character_id)
	if stage != null:
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Prévia maior que o padrão do lobby; o corpo continua inteiro dentro do painel.
		stage.fill_ratio = PREVIEW_FILL_RATIO
		stage.frame_character()
		stage.set_zoom(ThumbnailCache.framing_zoom(character_id))
	_preview.add_child(PlayerUI.label(str(entry.get("description", "Herói disponível no catálogo do lobby.")), 19))
	if not services.inventory.is_unlocked(character_id):
		_preview.add_child(PlayerUI.label(PlayerProgress.lock_label(entry), 19))
	var equipped := services.inventory.equipped_id() == character_id
	var equip := _button("Equipado" if equipped else "Equipar", _equip.bind(character_id), true)
	equip.disabled = not services.inventory.is_unlocked(character_id) or equipped
	_preview.add_child(equip)
	_preview.add_child(_button("Voltar ao lobby", close))


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
	style.border_color = PlayerUI.GOLD if selected else CARD_BORDER
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_top = 16
	style.content_margin_right = 18
	style.content_margin_bottom = 16
	return style


## Botão plano, sem a textura decorativa dos botões gerais do jogo.
func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 22)
	var base := BUTTON_BG if not primary else PlayerUI.GOLD.darkened(0.25)
	var states := {"normal": base, "hover": base.lightened(0.12), "pressed": base.darkened(0.2), "focus": base, "disabled": Color("#1a2333")}
	for state: String in states:
		var style := StyleBoxFlat.new()
		style.bg_color = states[state]
		style.set_corner_radius_all(12)
		style.set_border_width_all(2 if state == "focus" else 0)
		style.border_color = PlayerUI.GOLD
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("#f4f1e6"))
	button.add_theme_color_override("font_disabled_color", Color("#7d8796"))
	button.pressed.connect(action)
	return button
