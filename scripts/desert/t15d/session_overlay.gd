extends CanvasLayer
## Navegação local da Fase 01; a pausa não altera dados de campanha.
signal resume_requested
signal restart_requested
signal next_requested
signal return_requested
signal checkpoint_requested
var _veil: ColorRect
var _panel: PanelContainer
var _column: VBoxContainer
var _font: FontFile
var opened := false
var _completion := false
var _death := false
var order := 1
var phase_name := "Entrada do Deserto"
var total_enemies := 0
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
	style.bg_color = Color(0.035,0.06,0.11,0.96)
	style.border_color = Color("#f2c76e")
	style.border_width_top = 3
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0,0,0,0.55)
	style.shadow_size = 24
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 22
	style.content_margin_bottom = 24
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
	button.custom_minimum_size = Vector2(340,50)
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_color_override("font_color",Color("#141006") if primary else Color("#f4e5ca"))
	for state in ["font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Color("#141006") if primary else Color("#ffffff"))
	for state in ["normal","hover","pressed","focus"]:
		var box := StyleBoxFlat.new()
		box.skew = Vector2(0.16,0)
		box.anti_aliasing = true
		box.bg_color = Color("#f2c76e") if primary else Color(0.07,0.11,0.18,0.95)
		if state in ["hover","focus"]: box.bg_color = box.bg_color.lightened(0.12)
		if state == "pressed": box.bg_color = box.bg_color.darkened(0.15)
		box.set_corner_radius_all(3)
		box.border_color = Color("#fff3d0") if state == "focus" else Color("#f2c76e",0.0 if primary else 0.45)
		box.set_border_width_all(2 if state == "focus" else 1)
		button.add_theme_stylebox_override(state,box)
	button.pressed.connect(action)
	_column.add_child(button)
func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
func show_pause() -> void:
	_completion = false
	_death = false
	_clear()
	_title(phase_name.to_upper(),12,Color("#d9b778"))
	_title("Pausa",28,Color.WHITE)
	_button("Continuar",resume_requested.emit,true)
	_button("Recomeçar fase",restart_requested.emit)
	_button("Voltar aos reinos",return_requested.emit)
	_open()
## Tela de derrota: a fase fica pausada até o jogador escolher para onde voltar.
func show_death(fell: bool, checkpoint_label: String) -> void:
	_completion = false
	_death = true
	_clear()
	_title(phase_name.to_upper(),12,Color("#d9b778"))
	_title("Você caiu" if fell else "Você foi derrotado",28,Color("#f3b4a2"))
	var has_checkpoint := not checkpoint_label.is_empty()
	_title("Continue do %s com a vida cheia." % checkpoint_label if has_checkpoint else "Recomece a fase com a vida cheia.",14,Color("#dccdb3"))
	_button("Voltar ao checkpoint" if has_checkpoint else "Recomeçar do início",checkpoint_requested.emit,true)
	if has_checkpoint: _button("Recomeçar fase",restart_requested.emit)
	_button("Voltar ao menu",return_requested.emit)
	_open()
func show_completion(defeated: int, seconds: float, saved := true) -> void:
	_completion = true
	_death = false
	_clear()
	_title("FASE %02d  /  CONCLUÍDA" % order,12,Color("#d9b778"))
	_title("Travessia concluída",27,Color.WHITE)
	_title("Cactus  %d / %d    •    %02d:%02d" % [defeated,total_enemies,int(seconds)/60,int(seconds)%60],14,Color("#dccdb3"))
	_title("Próxima fase liberada neste aparelho" if saved else "Não foi possível salvar o progresso",14,Color("#9dc9dc"))
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
		elif _death: checkpoint_requested.emit()
		else: resume_requested.emit()
		get_viewport().set_input_as_handled()
func _layout() -> void:
	if not is_instance_valid(_panel): return
	var viewport_size := get_viewport().get_visible_rect().size
	var unit := UIScale.unit_for(get_viewport()) if UIScale.is_compact() else 1.0
	_panel.scale = Vector2.ONE*unit
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = (viewport_size-_panel.size*unit)*0.5
	_veil.size = viewport_size
