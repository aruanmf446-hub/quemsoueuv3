extends PanelContainer
## Carta com o mesmo enquadramento em retrato da Biblioteca.
signal activated
const Style = preload("res://scripts/ui/battle/battle_style.gd")
var id := ""
var selected := false
var removed := false
var interactive := false
var image: TextureRect
var caption: Label
var caption_area: Control

## O GridContainer define as dimensões de cada carta conforme o viewport.
## Não permitir que o nome completo ou a imagem imponham largura mínima própria:
## era isso que congelava a antiga largura ao mudar de 844 para 640 px.
func _get_minimum_size() -> Vector2:
	return Vector2.ZERO
func setup(card_id: String, chosen: bool, out: bool, usable: bool) -> void:
	id = card_id
	selected = chosen
	removed = out
	interactive = usable
	name = card_id.get_file()
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
	image.texture = DeckCover.framed_texture(DuelService.card_texture(id), CardFramer.LIBRARY_ASPECT)
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.clip_contents = true
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grading := ShaderMaterial.new()
	grading.shader = preload("res://scripts/ui/battle/battle_illustration.gdshader")
	grading.set_shader_parameter("saturation",0.0 if out else 1.04)
	image.material = grading
	column.add_child(image)
	caption = Style.label(DuelService.card_name(id),12,Color("#f3ead8"))
	caption.name = "Caption"
	Style.strong(caption)
	caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.y = 20
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0.02,0.03,0.05,0.78)
	strip.set_content_margin_all(1)
	strip.content_margin_left = 6
	strip.content_margin_right = 6
	strip.border_width_top = 1
	strip.border_color = Color(0.84,0.65,0.33,0.45)
	strip.shadow_color = Color(0,0,0,0.6)
	strip.shadow_size = 6
	strip.shadow_offset = Vector2(0,-3)
	caption.add_theme_constant_override("outline_size",1)
	caption.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	caption.add_theme_stylebox_override("normal",strip)
	caption_area = Control.new()
	# iPhone: espaço para o nome em duas linhas inteiras (sem cortar a segunda linha).
	caption_area.custom_minimum_size.y = 52 if UIScale.is_iphone() else 20
	caption_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Caption has its own strip: no letters obscure the bottom of the source art.
	column.add_child(caption_area)
	caption_area.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if out:
		image.modulate = Color(0.42,0.42,0.46)
		caption.add_theme_color_override("font_color", PlayerUI.MUTED)
		# Selo centralizado em vez de texto solto sobre a arte.
		var holder := CenterContainer.new()
		holder.name = "Eliminated"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var seal := PanelContainer.new()
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var seal_style := StyleBoxFlat.new()
		seal_style.bg_color = Color(0.09,0.03,0.04,0.86)
		seal_style.border_color = Color("#c4655c")
		seal_style.set_border_width_all(1)
		seal_style.set_corner_radius_all(4)
		seal_style.content_margin_left = 10
		seal_style.content_margin_right = 10
		seal_style.content_margin_top = 3
		seal_style.content_margin_bottom = 3
		seal_style.shadow_color = Color(0,0,0,0.55)
		seal_style.shadow_size = 4
		seal.add_theme_stylebox_override("panel",seal_style)
		holder.add_child(seal)
		var eliminated := Style.label("ELIMINADA",11,Color("#f0b3ab"))
		Style.strong(eliminated)
		eliminated.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Uma linha só: sem isto o rótulo quebrava letra a letra e esticava a carta.
		eliminated.autowrap_mode = TextServer.AUTOWRAP_OFF
		holder.clip_contents = true
		seal.add_child(eliminated)
	var finish := preload("res://scripts/ui/battle/battle_card_finish.gd").new()
	finish.selected = selected
	finish.removed = removed
	add_child(finish)
	resized.connect(_resize_caption)
	_resize_caption()
	mouse_entered.connect(func() -> void: _style(true); _lift(true))
	mouse_exited.connect(func() -> void: _style(false); _lift(false))
	focus_entered.connect(func() -> void: _style(true); _lift(true))
	focus_exited.connect(func() -> void: _style(false); _lift(false))
	gui_input.connect(_on_gui_input)
	_style(false)
func _style(hover: bool) -> void:
	var style := Style.panel(1,selected or (hover and interactive))
	style.border_color = Color("#596273") if removed else (PlayerUI.GOLD_BRIGHT if selected else (PlayerUI.GOLD if hover and interactive else Color("#c39352")))
	style.set_border_width_all(2)
	style.shadow_color = Color(1,0.62,0.19,0.25) if selected else Color(0,0,0,0.65)
	style.shadow_size = 4 if selected else 3
	style.shadow_offset = Vector2(0,2)
	style.bg_color = Color("#070d14")
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel",style)
## Carta "tocável": acende um pouco ao passar o mouse/foco (só se puder ser escolhida).
## Sem mudar escala: a carta nunca sai da área do tabuleiro.
var _lift_tween: Tween
func _lift(on: bool) -> void:
	if not interactive or removed: return
	pivot_offset = size*0.5
	if _lift_tween != null and _lift_tween.is_valid(): _lift_tween.kill()
	_lift_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(self,"modulate",Color(1.12,1.1,1.05) if on else Color.WHITE,0.12)


func _on_gui_input(event: InputEvent) -> void:
	if not interactive: return
	# Handle native touch as well as mouse/keyboard. Ignore the synthetic mouse
	# companion so a tap cannot select and immediately deselect the same card.
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
		grab_focus()
		pivot_offset = size*0.5
		scale = Vector2.ONE*0.97
		create_tween().tween_property(self,"scale",Vector2.ONE,0.1)
		activated.emit()
		accept_event()
func _resize_caption() -> void:
	if is_instance_valid(caption_area):
		var dense := size.x < 112
		var short_row := size.y < 68
		# Em grade 7x3, permitir duas linhas de nome legíveis; em 640x360
		# preservar a imagem usando legenda compacta, sem esconder opções.
		caption.add_theme_font_size_override("font_size",10 if short_row else (11 if dense else (13 if size.x < 165 else 16)))
		caption_area.custom_minimum_size.y = 20 if short_row else (34 if dense else (38 if size.x < 165 else 32))
		if UIScale.is_iphone():
			# This canvas is exempt from the global floor because it has its own
			# scale. Keep card names legible and reserve both complete lines.
			caption.add_theme_font_size_override("font_size", 16)
			caption_area.custom_minimum_size.y = 52

func _ready() -> void:
	if selected:
		resized.connect(func() -> void: pivot_offset = size*0.5)
		scale = Vector2.ONE*0.98
		create_tween().tween_property(self,"scale",Vector2.ONE,0.12)
