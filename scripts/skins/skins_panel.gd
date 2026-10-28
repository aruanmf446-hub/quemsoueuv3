extends Control

## Tela Skins: cartões com miniatura, estado de bloqueio e indicador de equipado.
## "Visualizar" abre o CharacterViewer (mesmo palco do lobby). "Equipar" só funciona
## para personagens desbloqueados. Vilões e chefes do Modo História nunca aparecem aqui.

signal character_selected(character_id: StringName)
signal progress_changed

const CARD_SIZE := Vector2(240, 330)
const CARD_TEXTURE := preload("res://assets/processed/textures/textura_azul.png")
const CARD_TEXTURE_LOCKED := preload("res://assets/processed/textures/textura_roxa.png")
const STAGE_SCENE := preload("res://scenes/lobby/lobby_stage.tscn")
const DEV_FLAG := "desert_stage_completed"

@onready var _dim: ColorRect = $Dim
@onready var _frame: NinePatchRect = $Frame
@onready var _grid: GridContainer = $Frame/Grid
@onready var _close_button: Button = $Frame/CloseButton

var _viewer: CharacterViewer
var _thumbnails: ThumbnailCache
var _thumb_paths: Dictionary = {}
var _equipped_id: String = ""
var _cards: Dictionary = {}
var _entries: Array = []


func _ready() -> void:
	_entries = CharacterCatalog.load_entries()
	_thumbnails = ThumbnailCache.new(STAGE_SCENE)
	_close_button.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)
	_wrap_grid_in_scroll()

	_viewer = CharacterViewer.new()
	add_child(_viewer)
	_viewer.equip_requested.connect(_on_equip_requested)

	if OS.is_debug_build():
		_add_dev_buttons()
	visible = false


func open(equipped_id: String = "") -> void:
	_equipped_id = equipped_id
	visible = true
	_rebuild_cards()
	_load_thumbnails()


func close() -> void:
	visible = false


## Gera miniaturas ausentes (na primeira abertura) e atualiza os cartões quando prontas.
func _load_thumbnails() -> void:
	_thumb_paths = await _thumbnails.ensure(self, _entries)
	for character_id: String in _cards:
		_apply_thumbnail(character_id)


func _rebuild_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cards.clear()
	for entry: Dictionary in _entries:
		var card := _make_card(entry)
		_grid.add_child(card)
		_cards[entry["id"]] = card
		_apply_thumbnail(entry["id"])


func _make_card(entry: Dictionary) -> PanelContainer:
	var unlocked := PlayerProgress.is_unlocked(entry)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", _card_style(unlocked))
	card.set_meta("character_id", entry["id"])

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var tag := Label.new()
	tag.text = "EQUIPADO" if entry["id"] == _equipped_id else " "
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", Color("#7fe38a"))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tag)

	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = Vector2(190, 200)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(preview)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("#ffffff"))
	name_label.add_theme_color_override("font_outline_color", Color("#0a1630"))
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var status := Label.new()
	status.text = "Desbloqueado" if unlocked else "Bloqueado"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("#cfe6ff") if unlocked else Color("#ffb3b3"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var view := Button.new()
	view.text = "Visualizar"
	view.focus_mode = Control.FOCUS_NONE
	view.add_theme_font_size_override("font_size", 16)
	view.custom_minimum_size = Vector2(104, 40)
	view.pressed.connect(_on_view_pressed.bind(entry))
	row.add_child(view)

	var equip := Button.new()
	equip.text = "Equipar" if unlocked else "Bloqueado"
	equip.disabled = not unlocked
	equip.focus_mode = Control.FOCUS_NONE
	equip.add_theme_font_size_override("font_size", 16)
	equip.custom_minimum_size = Vector2(104, 40)
	equip.pressed.connect(_on_equip_requested.bind(StringName(entry["id"])))
	row.add_child(equip)
	return card


func _card_style(unlocked: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = CARD_TEXTURE if unlocked else CARD_TEXTURE_LOCKED
	style.modulate_color = Color.WHITE if unlocked else Color(0.75, 0.75, 0.8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	return style


func _apply_thumbnail(character_id: String) -> void:
	if not _cards.has(character_id) or not _thumb_paths.has(character_id):
		return
	var preview := _cards[character_id].find_child("Preview", true, false) as TextureRect
	if preview == null:
		return
	var image := Image.load_from_file(_thumb_paths[character_id])
	if image:
		preview.texture = ImageTexture.create_from_image(image)


func _on_view_pressed(entry: Dictionary) -> void:
	_viewer.open(entry)


func _on_equip_requested(character_id: StringName) -> void:
	var index := CharacterCatalog.index_of(_entries, String(character_id))
	if index < 0 or not PlayerProgress.is_unlocked(_entries[index]):
		push_warning("Equipar bloqueado recusado: %s" % character_id)
		return
	character_selected.emit(character_id)
	close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


## Coloca o grid dentro de um ScrollContainer, pois oito cartões não cabem no quadro.
func _wrap_grid_in_scroll() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = _grid.position
	scroll.size = _grid.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(scroll)
	_grid.reparent(scroll)
	_grid.position = Vector2.ZERO
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Botões de desenvolvimento, visíveis só em builds de depuração. Não são autorização:
## apenas simulam o progresso local para testar o desbloqueio.
func _add_dev_buttons() -> void:
	var unlock := Button.new()
	unlock.text = "DEV: concluir Reino do Deserto"
	unlock.position = Vector2(40, 650)
	unlock.size = Vector2(330, 44)
	unlock.focus_mode = Control.FOCUS_NONE
	unlock.add_theme_font_size_override("font_size", 14)
	unlock.pressed.connect(_dev_set_flag.bind(true))
	_frame.add_child(unlock)

	var reset := Button.new()
	reset.text = "DEV: resetar progresso"
	reset.position = Vector2(790, 650)
	reset.size = Vector2(300, 44)
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_font_size_override("font_size", 14)
	reset.pressed.connect(_dev_set_flag.bind(false))
	_frame.add_child(reset)


func _dev_set_flag(value: bool) -> void:
	PlayerProgress.set_flag(DEV_FLAG, value)
	progress_changed.emit()
	_rebuild_cards()
	_load_thumbnails()
