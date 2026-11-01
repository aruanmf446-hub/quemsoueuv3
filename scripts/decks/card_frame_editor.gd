class_name CardFrameEditor
extends PanelContainer
## Uma única ferramenta para os dois formatos: a mesma imagem original guarda dois
## enquadramentos independentes (Biblioteca em retrato e Duelo na horizontal).
signal confirmed(crops: Dictionary)
signal cancelled

const FORMATS := {
	"library": {"title": "Biblioteca · retrato", "aspect": CardFramer.LIBRARY_ASPECT},
	"duel": {"title": "Mata-Mata · horizontal", "aspect": CardFramer.DUEL_ASPECT},
}
var framer: CardFramer
var _image: Image
var _texture: Texture2D
var _crops := {}
var _format := "library"
var _tabs := {}
var _previews := {}


func open(image: Image, crops: Dictionary = {}) -> void:
	_image = image
	_texture = ImageTexture.create_from_image(image)
	for key: String in FORMATS:
		_crops[key] = CardFramer.normalized(crops.get(key, {}) if crops.get(key) is Dictionary else {})
	_build()
	_select("library")


func _build() -> void:
	name = "CardFrameEditor"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.bg_color = PlayerUI.INTERIOR_BG
	box.set_content_margin_all(18)
	add_theme_stylebox_override("panel", box)
	for child in get_children(): child.queue_free()
	var column := PlayerUI.column(self)
	column.add_theme_constant_override("separation", 12)
	var header := PlayerUI.row(column)
	var title := PlayerUI.label("Ajustar enquadramento", 26, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for key: String in FORMATS:
		var tab := PlayerUI.button(FORMATS[key].title, _select.bind(key))
		tab.name = "Format_" + key
		tab.toggle_mode = true
		PlayerUI.style_row(tab)
		tab.clip_text = false
		tab.custom_minimum_size.x = 0
		header.add_child(tab)
		_tabs[key] = tab
	var stage := PlayerUI.row(column)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	framer = CardFramer.new()
	framer.name = "Framer"
	framer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	framer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	framer.size_flags_stretch_ratio = 2.4
	framer.changed.connect(_framer_changed)
	stage.add_child(framer)
	var side := PlayerUI.column(stage)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(PlayerUI.label("PRÉVIA", 13, PlayerUI.GOLD))
	for key: String in FORMATS:
		side.add_child(PlayerUI.label(FORMATS[key].title, 14, PlayerUI.MUTED))
		var preview := TextureRect.new()
		preview.name = "Preview_" + key
		preview.custom_minimum_size = Vector2(120, 120 / FORMATS[key].aspect) if key == "library" else Vector2(200, 200 / FORMATS[key].aspect)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		side.add_child(preview)
		_previews[key] = preview
	side.add_child(PlayerUI.label("Arraste para posicionar. Roda do mouse, pinça ou +/− para ampliar.", 13, PlayerUI.MUTED))
	var actions := PlayerUI.row(column)
	var zoom_out := PlayerUI.button("−", func() -> void: framer.zoom_by(1.0 / 1.15))
	zoom_out.name = "ZoomOut"
	actions.add_child(zoom_out)
	var zoom_in := PlayerUI.button("+", func() -> void: framer.zoom_by(1.15))
	zoom_in.name = "ZoomIn"
	actions.add_child(zoom_in)
	var reset := PlayerUI.button("Restaurar", func() -> void: framer.reset())
	reset.name = "ResetFrame"
	actions.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var cancel := PlayerUI.button("Cancelar", func() -> void: cancelled.emit())
	cancel.name = "CancelFrame"
	PlayerUI.style_back(cancel)
	actions.add_child(cancel)
	var confirm := PlayerUI.button("Confirmar", func() -> void: confirmed.emit(crops()))
	confirm.name = "ConfirmFrame"
	PlayerUI.style_button(confirm, true)
	actions.add_child(confirm)


func crops() -> Dictionary:
	var result := {}
	for key: String in _crops: result[key] = (_crops[key] as Dictionary).duplicate()
	return result


func _select(key: String) -> void:
	_format = key
	for other: String in _tabs: (_tabs[other] as Button).set_pressed_no_signal(other == key)
	framer.setup(_texture, FORMATS[key].aspect, _crops[key])
	_crops[key] = framer.crop.duplicate()
	for format: String in FORMATS: _refresh_preview(format)


func _framer_changed(crop: Dictionary) -> void:
	_crops[_format] = crop
	_refresh_preview(_format)


func _refresh_preview(key: String) -> void:
	var image := CardFramer.preview(_image, FORMATS[key].aspect, _crops[key], 320)
	(_previews[key] as TextureRect).texture = ImageTexture.create_from_image(image)
