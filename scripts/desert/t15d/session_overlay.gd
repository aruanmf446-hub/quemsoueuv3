extends CanvasLayer
## Navegação local da Fase 01; a pausa não altera dados de campanha.
signal resume_requested
signal checkpoint_requested
signal restart_requested
signal next_requested
signal return_requested
var _veil: ColorRect
var _panel: PanelContainer
var _column: VBoxContainer
var _font: FontFile
var opened := false
var _completion := false
func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	_veil = ColorRect.new()
	_veil.color = Color(0.015,0.035,0.065,0.75)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_panel = PanelContainer.new()
	_panel.theme = Theme.new()
	_panel.theme.default_font = _font
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102436")
	style.border_color = Color("#c9a66a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel",style)
	add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation",8)
	_panel.add_child(_column)
	get_viewport().size_changed.connect(_layout)
	hide()
func _title(text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	_column.add_child(label)
func _button(text: String, action: Callable, primary := false) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320,40)
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_color_override("font_color",Color("#172436") if primary else Color("#f4e5ca"))
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("#172436") if primary else Color("#ffffff"))
	for state in ["normal","hover","pressed","focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#dbba79") if primary else Color("#1b3549")
		if state in ["hover","focus"]: box.bg_color = box.bg_color.lightened(0.12)
		if state == "pressed": box.bg_color = box.bg_color.darkened(0.12)
		box.set_corner_radius_all(5)
		box.set_border_width_all(1)
		box.border_color = Color("#d1b278") if state == "focus" else Color(0.7,0.7,0.7,0.12)
		button.add_theme_stylebox_override(state,box)
	button.pressed.connect(action)
	_column.add_child(button)
func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
func show_pause() -> void:
	_completion = false
	_clear()
	_title("ENTRADA DO DESERTO",12,Color("#d9b778"))
	_title("Pausa",28,Color.WHITE)
	_button("Continuar",resume_requested.emit,true)
	_button("Retomar do checkpoint",checkpoint_requested.emit)
	_button("Recomeçar fase",restart_requested.emit)
	_button("Voltar aos reinos",return_requested.emit)
	_open()
func show_completion(defeated: int, seconds: float) -> void:
	_completion = true
	_clear()
	_title("FASE 01  /  CONCLUÍDA",12,Color("#d9b778"))
	_title("Travessia concluída",27,Color.WHITE)
	_title("Cactus derrotados  %d / 3    •    %02d:%02d" % [defeated,int(seconds)/60,int(seconds)%60],14,Color("#dccdb3"))
	_button("Próxima fase",next_requested.emit,true)
	_button("Jogar novamente",restart_requested.emit)
	_button("Voltar aos reinos",return_requested.emit)
	_open()
func _open() -> void:
	opened = true
	show()
	_layout()
	# Containers recalculam o mínimo no próximo frame.
	call_deferred("_layout")
	for child in _column.get_children():
		if child is Button:
			child.grab_focus()
			break
func close() -> void:
	opened = false
	hide()
func _unhandled_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		if _completion: return_requested.emit()
		else: resume_requested.emit()
		get_viewport().set_input_as_handled()
func _layout() -> void:
	if not is_instance_valid(_panel): return
	var viewport_size := get_viewport().get_visible_rect().size
	var unit := viewport_size.y/maxf(get_window().size.y,1) if get_window().size.y < 600 else 1.0
	_panel.scale = Vector2.ONE*unit
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = (viewport_size-_panel.size*unit)*0.5
	_veil.size = viewport_size
