extends CanvasLayer
## HUD em pixels físicos: recursos, distrito e avanço têm hierarquias diferentes.
signal pause_requested
const Icons = preload("res://scripts/desert/t15d/resource_icons.gd")
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
var _font: FontFile
var _kicker: Label
var _place: Label
var _toast_left := 0.0
var _flash: ColorRect
var _icons: Control
var _hp := 3
var _atk := 1
var _def := 1
var _atk_glow := 0.0
## Pulso de cada coração (1 → 0) quando ele é perdido ou recuperado.
var _heart_pop: Array[float] = [0.0, 0.0, 0.0]
var _def_glow := 0.0
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
	_icons.custom_minimum_size = Vector2(240,40)
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
## Corações para a vida e dois medalhões (espada em chamas = ataque, escudo = defesa), os
## mesmos dos itens no mapa. Sem carga, o medalhão fica cinza.
func _draw_resources() -> void:
	var h := _icons.size.y
	var px := _root.scale.x
	var heart_size := h*0.8
	var x := 0.0
	for index in range(3):
		var pop := _heart_pop[index]
		var center := Vector2(x+heart_size*0.5,h*0.5)
		var full := index < _hp
		# Coração perdido: some crescendo e apagando; recuperado: estufa e assenta.
		if pop > 0.0 and not full:
			_icon(Icons.heart(roundi(heart_size*px),true),center,heart_size*(1.0+0.45*(1.0-pop)),pop)
		_icon(Icons.heart(roundi(heart_size*px),full),center,heart_size*(1.0+0.28*sin(pop*PI) if full else 1.0))
		x += heart_size*1.08
	x += h*0.3
	for slot: Array in [["attack",_atk > 0,_atk_glow],["defense",_def > 0,_def_glow]]:
		var center := Vector2(x+h*0.5,h*0.5)
		var glow: float = slot[2]
		if slot[1]:
			# Brilho suave atrás do medalhão; acende mais logo depois de recarregar.
			var tint := Color("#ff9a3c") if slot[0] == "attack" else Color("#5ec4ef")
			for step in range(4):
				_icons.draw_circle(center,h*(0.62-step*0.05),Color(tint,(0.06+glow*0.2)*(1.0-step*0.2)))
		_icon(Icons.medallion(slot[0],roundi(h*px),slot[1]),center,h*(1.0+0.12*sin(glow*PI)))
		x += h*1.15
func _icon(texture: Texture2D, center: Vector2, size: float, alpha := 1.0) -> void:
	_icons.draw_texture_rect(texture,Rect2(center-Vector2.ONE*size*0.5,Vector2.ONE*size),false,Color(1,1,1,alpha))
func update_resources(player: Node) -> void:
	for index in range(3):
		if (index < player.health) != (index < _hp): _heart_pop[index] = 1.0
	_hp = player.health
	if player.attack_charges > _atk: _atk_glow = 1.0
	if player.defense_charges > _def: _def_glow = 1.0
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
## Tempestade: véu cor de areia e grãos atravessando a tela (abaixo dos painéis).
var _storm_veil: ColorRect
var _storm_grains: CPUParticles2D
func set_storm(on: bool) -> void:
	if not is_instance_valid(_storm_veil):
		_storm_veil = ColorRect.new()
		_storm_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_storm_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_storm_veil.color = Color(0.72,0.52,0.3,0.0)
		add_child(_storm_veil)
		move_child(_storm_veil,0)
		_storm_grains = CPUParticles2D.new()
		_storm_grains.amount = 220
		_storm_grains.lifetime = 1.2
		_storm_grains.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_storm_grains.direction = Vector2(-1,0.12)
		_storm_grains.spread = 6
		_storm_grains.gravity = Vector2.ZERO
		_storm_grains.initial_velocity_min = 700
		_storm_grains.initial_velocity_max = 1300
		_storm_grains.scale_amount_min = 0.6
		_storm_grains.scale_amount_max = 1.4
		_storm_grains.color = Color(0.98,0.85,0.6,0.6)
		# Risco horizontal com pontas suaves: lê como areia voando, não como pixel.
		var streak := GradientTexture2D.new()
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0,0.3,1.0])
		grad.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,1),Color(1,1,1,0)])
		streak.gradient = grad
		streak.width = 48
		streak.height = 3
		_storm_grains.texture = streak
		_storm_grains.emitting = false
		add_child(_storm_grains)
		move_child(_storm_grains,1)
	var screen := get_viewport().get_visible_rect().size
	_storm_grains.position = Vector2(screen.x+20,screen.y*0.5)
	_storm_grains.emission_rect_extents = Vector2(20,screen.y*0.5)
	_storm_grains.emitting = on
	var fade := _storm_veil.create_tween()
	fade.tween_property(_storm_veil,"color:a",0.34 if on else 0.0,0.8)
## Nome do novo lugar em destaque no alto da tela, some sozinho.
func announce_place(text: String) -> void:
	if not is_instance_valid(_place):
		_place = Label.new()
		_place.add_theme_font_override("font",_font)
		_place.add_theme_color_override("font_color",Color("#f6e3bd"))
		_place.add_theme_color_override("font_outline_color",Color(0.02,0.03,0.06,0.9))
		_place.add_theme_constant_override("outline_size",8)
		_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_place)
	var screen := _root.size
	_place.add_theme_font_size_override("font_size",30)
	_place.text = text.to_upper()
	_place.position = Vector2(0,screen.y*0.22)
	_place.size = Vector2(screen.x,44)
	_place.modulate.a = 0.0
	var show := _place.create_tween()
	show.tween_property(_place,"modulate:a",1.0,0.4)
	show.tween_interval(1.8)
	show.tween_property(_place,"modulate:a",0.0,0.6)
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
	_toast.hide()
func _process(delta: float) -> void:
	if _heart_pop.any(func(value: float) -> bool: return value > 0.0):
		for index in range(3): _heart_pop[index] = maxf(_heart_pop[index]-delta*2.6,0.0)
		_icons.queue_redraw()
	if _atk_glow > 0.0 or _def_glow > 0.0:
		_atk_glow = maxf(_atk_glow-delta*1.4,0.0)
		_def_glow = maxf(_def_glow-delta*1.4,0.0)
		_icons.queue_redraw()
	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time-delta,0.0)
		var progress := 1.0-_flash_time/_flash_length
		_flash.color.a = _flash_peak*(minf(progress*2.5,1.0) if _flash.get_meta("fade_in",false) else 1.0-progress)
	if _toast_left > 0:
		_toast_left -= delta
		_toast.modulate.a = minf(_toast_left*4.0,1.0)
		if _toast_left <= 0: _toast.hide()
