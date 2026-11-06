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
## Capa do deck (T24): um único formato 16:10, independente dos enquadramentos da carta.
const COVER_FORMATS := {"cover": {"title": "Capa do deck · 16:10", "aspect": 16.0 / 10.0}}
var formats: Dictionary = FORMATS
var framer: CardFramer
var _image: Image
var _texture: Texture2D
var _crops := {}
var _format := "library"
var _tabs := {}
var _previews := {}
var _preview_labels := {}
var _slider: HSlider
var _zoom_label: Label
var _syncing := false


func open(image: Image, crops: Dictionary = {}, use_formats: Dictionary = FORMATS) -> void:
	add_to_group("qse_web_input_modal")
	formats = use_formats
	_image = image
	_texture = ImageTexture.create_from_image(image)
	for key: String in formats:
		_crops[key] = CardFramer.normalized(crops.get(key, {}) if crops.get(key) is Dictionary else {})
	_build()
	_select(formats.keys()[0])


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
	for key: String in formats:
		var tab := PlayerUI.button(formats[key].title, _select.bind(key))
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
	for key: String in formats:
		var label := PlayerUI.label(formats[key].title,14,PlayerUI.MUTED)
		side.add_child(label)
		_preview_labels[key]=label
		var preview := TextureRect.new()
		preview.name = "Preview_" + key
		preview.custom_minimum_size = Vector2(120, 120 / formats[key].aspect) if formats[key].aspect < 1.0 else Vector2(200, 200 / formats[key].aspect)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		side.add_child(preview)
		_previews[key] = preview
	var hint := PlayerUI.label("Arraste para posicionar. Use a pinça ou +/− para ampliar." if UIScale.is_iphone() else "Arraste para posicionar. Roda do mouse, pinça ou +/− para ampliar. Reduza o zoom para mover a imagem inteira dentro da carta.",13,PlayerUI.MUTED)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hint)
	# Direções acessíveis (toque) — movem a imagem, não a moldura.
	var pad := GridContainer.new()
	pad.name = "NudgePad"
	pad.visible=not UIScale.is_iphone()
	pad.columns = 3
	pad.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for cell: Array in [["", Vector2.ZERO], ["↑", Vector2.UP], ["", Vector2.ZERO], ["←", Vector2.LEFT], ["◎", Vector2.INF], ["→", Vector2.RIGHT], ["", Vector2.ZERO], ["↓", Vector2.DOWN], ["", Vector2.ZERO]]:
		if str(cell[0]).is_empty():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(44, 44)
			pad.add_child(gap)
			continue
		var direction: Vector2 = cell[1]
		var key: String = {"↑": "Up", "↓": "Down", "←": "Left", "→": "Right", "◎": "Center"}[cell[0]]
		var arrow := PlayerUI.button(str(cell[0]), func() -> void:
			if direction == Vector2.INF: framer.center_crop()
			else: framer.nudge(direction))
		arrow.name = "Nudge" + key
		arrow.custom_minimum_size = Vector2(44, 44)
		arrow.clip_text = false
		PlayerUI.style_row(arrow)
		pad.add_child(arrow)
	side.add_child(pad)
	var actions := PlayerUI.row(column)
	var zoom_out := PlayerUI.button("−", func() -> void: framer.zoom_by(1.0 / 1.15))
	zoom_out.name = "ZoomOut"
	actions.add_child(zoom_out)
	_slider = HSlider.new()
	_slider.name = "ZoomSlider"
	_slider.step = 0.01
	_slider.custom_minimum_size = Vector2(220, 40)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.16)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	_slider.add_theme_stylebox_override("slider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color(PlayerUI.GOLD, 0.85)
	_slider.add_theme_stylebox_override("grabber_area", fill)
	_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(func(value: float) -> void: if not _syncing: framer.set_zoom(value))
	actions.add_child(_slider)
	var zoom_in := PlayerUI.button("+", func() -> void: framer.zoom_by(1.15))
	zoom_in.name = "ZoomIn"
	actions.add_child(zoom_in)
	_zoom_label = PlayerUI.label("100%", 15, PlayerUI.MUTED)
	_zoom_label.name = "ZoomValue"
	_zoom_label.custom_minimum_size.x = 60
	actions.add_child(_zoom_label)
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
	for other: String in _previews:
		_previews[other].visible=not UIScale.is_iphone() or other==key
		_preview_labels[other].visible=not UIScale.is_iphone() or other==key
	for other: String in _tabs: (_tabs[other] as Button).set_pressed_no_signal(other == key)
	framer.setup(_texture, formats[key].aspect, _crops[key])
	_crops[key] = framer.crop.duplicate()
	_sync_zoom()
	for format: String in formats: _refresh_preview(format)


func _framer_changed(crop: Dictionary) -> void:
	_crops[_format] = crop
	_sync_zoom()
	_refresh_preview(_format)


func _sync_zoom() -> void:
	if _slider == null: return
	_syncing = true
	_slider.max_value = CardFramer.MAX_ZOOM
	_slider.min_value = framer.minimum_zoom()
	_slider.set_value_no_signal(float(framer.crop.zoom))
	_syncing = false
	_zoom_label.text = "%d%%" % roundi(float(framer.crop.zoom) * 100.0)


func _refresh_preview(key: String) -> void:
	var image := CardFramer.preview(_image, formats[key].aspect, _crops[key], 320)
	(_previews[key] as TextureRect).texture = ImageTexture.create_from_image(image)
