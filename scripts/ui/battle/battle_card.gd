extends PanelContainer
## Landscape window on the original portrait illustration, with an undistorted focal crop.
signal activated
const Style = preload("res://scripts/ui/battle/battle_style.gd")
var id := ""
var selected := false
var removed := false
var interactive := false
var image: TextureRect
var caption: Label
var caption_area: Control
var _source: Texture2D
func setup(card_id: String, chosen: bool, out: bool, usable: bool) -> void:
	id = card_id
	selected = chosen
	removed = out
	interactive = usable
	name = card_id.get_file()
	_source = DuelService.card_texture(id)
	tooltip_text = DuelService.card_name(id)
	mouse_filter = Control.MOUSE_FILTER_STOP if usable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW
	focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
	clip_contents = true
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",0)
	add_child(column)
	image = TextureRect.new()
	image.name = "Art"
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(image)
	caption = Style.label(DuelService.card_name(id),12)
	caption.name = "Caption"
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.y = 20
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0.015,0.02,0.025,0.94)
	strip.set_content_margin_all(1)
	caption.add_theme_stylebox_override("normal",strip)
	caption_area = Control.new()
	caption_area.custom_minimum_size.y = 20
	caption_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_area)
	caption_area.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if out:
		image.modulate = Color(0.3,0.32,0.36)
		caption.add_theme_color_override("font_color", PlayerUI.MUTED)
		var eliminated := Style.label("ELIMINADA",10,Color("#de9e97"))
		eliminated.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eliminated.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(eliminated)
	image.resized.connect(_crop)
	mouse_entered.connect(func() -> void: _style(true))
	mouse_exited.connect(func() -> void: _style(false))
	focus_entered.connect(func() -> void: _style(true))
	focus_exited.connect(func() -> void: _style(false))
	gui_input.connect(_on_gui_input)
	_style(false)
func _style(hover: bool) -> void:
	var style := Style.panel(1,selected or (hover and interactive))
	style.border_color = PlayerUI.GOLD_BRIGHT if selected else (PlayerUI.GOLD if hover and interactive else Color("#98713c"))
	style.bg_color = Color("#070d14")
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel",style)
func _on_gui_input(event: InputEvent) -> void:
	if not interactive: return
	# Handle native touch as well as mouse/keyboard. Ignore the synthetic mouse
	# companion so a tap cannot select and immediately deselect the same card.
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		grab_focus()
		activated.emit()
		accept_event()
func _crop() -> void:
	if is_instance_valid(caption_area):
		var dense := size.x < 115
		caption_area.custom_minimum_size.y = 26 if dense else 20
		caption.add_theme_font_size_override("font_size",11 if dense else 12)
	if _source == null or image.size.y <= 0: return
	var source_size := _source.get_size()
	var ratio := image.size.x / maxf(image.size.y,1)
	var crop_height := minf(source_size.y,source_size.x / maxf(ratio,0.01))
	var atlas := AtlasTexture.new()
	atlas.atlas = _source
	atlas.region = Rect2(0,(source_size.y-crop_height)*0.18,source_size.x,crop_height)
	image.texture = atlas

func _ready() -> void:
	if selected:
		resized.connect(func() -> void: pivot_offset = size*0.5)
		scale = Vector2.ONE*0.98
		create_tween().tween_property(self,"scale",Vector2.ONE,0.12)
