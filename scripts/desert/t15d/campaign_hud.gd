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
var _icons: Control
var _hp := 3
var _atk := 1
var _def := 1
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
	# Os rótulos ficam para leitores de tela/testes; o jogador vê os ícones desenhados.
	for item in [_health,_attack,_defense]:
		item.hide()
		resources.add_child(item)
	_icons = Control.new()
	_icons.custom_minimum_size = Vector2(250,30)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_resources)
	resources.add_child(_icons)
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
	_bar.custom_minimum_size = Vector2(150,6)
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
	var round := box()
	round.skew = Vector2.ZERO
	round.border_width_left = 0
	round.set_border_width_all(1)
	round.set_corner_radius_all(24)
	_pause.add_theme_stylebox_override("normal",round)
	var hover := round.duplicate() as StyleBoxFlat
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
	style.bg_color = Color(0.035,0.06,0.11,0.88)
	style.border_color = Color("#f2c76e")
	style.set_corner_radius_all(3)
	style.border_width_left = 4
	style.skew = Vector2(0.12,0)
	style.anti_aliasing = true
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := UIScale.is_compact()
	# Em telas baixas os painéis encolhem e perdem a linha secundária: a ação ocupa o quadro.
	var factor := UIScale.unit_for(get_viewport())*0.8 if compact else 1.0
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
## Corações para a vida, lâmina dourada para o ataque e escudo azul para a defesa,
## nas mesmas cores das reposições do mapa. Vazios ficam só com o contorno.
func _draw_resources() -> void:
	var h := _icons.size.y
	var x := 0.0
	for index in range(3):
		_heart(Vector2(x+h*0.5,h*0.52),h*0.42,index < _hp)
		x += h*1.05
	x += h*0.5
	_blade(Vector2(x+h*0.5,h*0.5),h*0.46,_atk > 0)
	x += h*1.4
	_shield_icon(Vector2(x+h*0.5,h*0.5),h*0.42,_def > 0)
func _heart(c: Vector2, r: float, full: bool) -> void:
	var points := PackedVector2Array()
	for step in range(32):
		var t := TAU*step/32.0
		points.append(c+Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))*r/17.0)
	if full: _icons.draw_colored_polygon(points,Color("#ff5d5d"))
	points.append(points[0])
	_icons.draw_polyline(points,Color("#ffd0c4") if full else Color(1,1,1,0.35),1.6,true)
func _blade(c: Vector2, r: float, full: bool) -> void:
	var blade := PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*0.22,-r*0.55),c+Vector2(r*0.22,r*0.35),c+Vector2(-r*0.22,r*0.35),c+Vector2(-r*0.22,-r*0.55)])
	var color := Color("#f2c76e") if full else Color(1,1,1,0.0)
	if full: _icons.draw_colored_polygon(blade,color)
	blade.append(blade[0])
	_icons.draw_polyline(blade,Color("#fff0c4") if full else Color(1,1,1,0.35),1.6,true)
	_icons.draw_line(c+Vector2(-r*0.55,r*0.42),c+Vector2(r*0.55,r*0.42),Color("#f2c76e") if full else Color(1,1,1,0.35),2.4,true)
	_icons.draw_line(c+Vector2(0,r*0.45),c+Vector2(0,r*0.95),Color("#b88a3c") if full else Color(1,1,1,0.35),2.8,true)
func _shield_icon(c: Vector2, r: float, full: bool) -> void:
	var points := PackedVector2Array([c+Vector2(-r*0.85,-r*0.8),c+Vector2(r*0.85,-r*0.8),c+Vector2(r*0.8,r*0.1),c+Vector2(0,r),c+Vector2(-r*0.8,r*0.1)])
	if full: _icons.draw_colored_polygon(points,Color("#79cceb"))
	points.append(points[0])
	_icons.draw_polyline(points,Color("#d6f3ff") if full else Color(1,1,1,0.35),1.6,true)
func update_resources(player: Node) -> void:
	_hp = player.health
	_atk = player.attack_charges
	_def = player.defense_charges
	if is_instance_valid(_icons): _icons.queue_redraw()
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
	_hint.visible = not value and not UIScale.is_compact()
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
