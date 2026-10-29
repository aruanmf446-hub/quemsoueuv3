extends CanvasLayer
## HUD em pixels físicos: recursos, distrito e avanço têm hierarquias diferentes.
signal pause_requested
var _root: Control
var _identity: PanelContainer
var _status: PanelContainer
var _title: Label
var _district: Label
var _progress: Label
var _health: Label
var _attack: Label
var _defense: Label
var _bar: ProgressBar
var _pause: Button
var _toast: Label
var _hint: Label
var _font: FontFile
var _kicker: Label
var _toast_left := 0.0
var _flash: ColorRect
var _flash_time := 0.0
var _flash_length := 1.0
var _flash_peak := 0.0
var _last_health := 3
var _stage: Dictionary
func configure(stage: Dictionary) -> void:
	_stage = stage
func _ready() -> void:
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	# Véu de tela inteira para dano/morte, abaixo dos painéis e sem capturar toque.
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0,0,0,0)
	add_child(_flash)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = _font
	add_child(_root)
	_identity = PanelContainer.new()
	_identity.add_theme_stylebox_override("panel",box())
	_root.add_child(_identity)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	_identity.add_child(column)
	_kicker = label("CIDADE DO DESERTO  /  %02d" % int(_stage.order),11,Color("#c7b48f"))
	column.add_child(_kicker)
	_title = label(str(_stage.name),20,Color("#f5eee0"))
	column.add_child(_title)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation",12)
	column.add_child(resources)
	_health = label("VIDA  3/3",14,Color("#f1c5b7"))
	_attack = label("ATAQUE  1/1",14,Color("#e9c478"))
	_defense = label("DEFESA  1/1",14,Color("#91cee9"))
	for item in [_health,_attack,_defense]: resources.add_child(item)
	_status = PanelContainer.new()
	_status.add_theme_stylebox_override("panel",box())
	_root.add_child(_status)
	var progress_column := VBoxContainer.new()
	progress_column.add_theme_constant_override("separation",5)
	_status.add_child(progress_column)
	_district = label("PORTÕES",12,Color("#e5c58b"))
	progress_column.add_child(_district)
	_progress = label("0%   ·   00:00",13,Color("#d5e0eb"))
	progress_column.add_child(_progress)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(150,4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#c5a96a")
	_bar.add_theme_stylebox_override("fill",fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#294254")
	_bar.add_theme_stylebox_override("background",background)
	progress_column.add_child(_bar)
	_pause = Button.new()
	_pause.text = "Ⅱ"
	_pause.tooltip_text = "Pausar (Esc)"
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.add_theme_font_size_override("font_size",22)
	_pause.add_theme_stylebox_override("normal",box())
	var hover := box()
	hover.bg_color = Color("#294459")
	_pause.add_theme_stylebox_override("hover",hover)
	_pause.pressed.connect(pause_requested.emit)
	_root.add_child(_pause)
	_toast = label("",17,Color("#f1dfb4"))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal",box())
	_toast.hide()
	_root.add_child(_toast)
	_hint = label("A / D  mover     ESPAÇO  pulo ×2     J  ataque     SHIFT  defesa     S  agachar",13,Color("#d2d8df"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color",Color("#091421"))
	_hint.add_theme_constant_override("outline_size",4)
	_root.add_child(_hint)
	get_viewport().size_changed.connect(_layout)
	_layout()
func label(text: String, size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	return node
func box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.065,0.11,0.91)
	style.border_color = Color(0.65,0.57,0.39,0.65)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := get_window().size.y < 600
	# Em telas baixas os painéis encolhem e perdem a linha secundária: a ação ocupa o quadro.
	var factor := viewport_size.y/maxf(get_window().size.y,1)*0.8 if compact else 1.0
	_root.scale = Vector2.ONE*factor
	_kicker.visible = not compact
	var screen := viewport_size/factor
	_root.size = screen
	_identity.position = Vector2(14,14)
	_identity.size = _identity.get_combined_minimum_size()
	_identity.call_deferred("reset_size")
	_status.position = Vector2(screen.x-242,14)
	_status.custom_minimum_size = Vector2(174,76)
	_status.size = _status.get_combined_minimum_size()
	_pause.position = Vector2(screen.x-58,14)
	_pause.size = Vector2(44,48)
	_toast.position = Vector2(maxf(14,(screen.x-430)*0.5),92 if compact else 128)
	_toast.size = Vector2(minf(screen.x-28,430),32)
	_hint.visible = not compact
	_hint.position = Vector2(14,screen.y-30)
	_hint.size = Vector2(screen.x-28,24)
func update_resources(player: Node) -> void:
	if player.health < _last_health and player.health > 0: pulse(Color("#b8302a"),0.26,0.35)
	_last_health = player.health
	_health.text = "VIDA  %d/3" % player.health
	_health.modulate = Color(1.0,0.55,0.5) if player.health == 1 else Color.WHITE
	_attack.text = "ATAQUE  %d/1" % player.attack_charges
	_defense.text = "DEFESA  %d/1" % player.defense_charges
	_attack.modulate = Color.WHITE if player.attack_charges > 0 else Color(0.58,0.58,0.58)
	_defense.modulate = Color.WHITE if player.defense_charges > 0 else Color(0.58,0.58,0.58)
func update_progress(share: float, seconds: float, district: String) -> void:
	_bar.value = share*100.0
	_district.text = district.to_upper()
	_progress.text = "%d%%   ·   %02d:%02d" % [roundi(share*100),int(seconds)/60,int(seconds)%60]
func notify(text: String, warning := false) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color",Color("#f0b6a5") if warning else Color("#f1dfb4"))
	_toast_left = 2.0
	_toast.show()
## Tinge a tela e desvanece: vermelho curto no dano, escurecimento longo na morte.
func pulse(color: Color, peak: float, length: float, fade_in := false) -> void:
	_flash.color = Color(color,0.0 if fade_in else peak)
	_flash_peak = peak
	_flash_length = length
	_flash_time = length
	_flash.set_meta("fade_in",fade_in)
func clear_pulse() -> void:
	_flash_time = 0.0
	_flash.color.a = 0.0
func set_completed(value: bool) -> void:
	_pause.visible = not value
	_hint.visible = not value and get_window().size.y >= 600
	_toast.hide()
func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time-delta,0.0)
		var progress := 1.0-_flash_time/_flash_length
		_flash.color.a = _flash_peak*(minf(progress*2.5,1.0) if _flash.get_meta("fade_in",false) else 1.0-progress)
	if _toast_left > 0:
		_toast_left -= delta
		_toast.modulate.a = minf(_toast_left*4.0,1.0)
		if _toast_left <= 0: _toast.hide()
