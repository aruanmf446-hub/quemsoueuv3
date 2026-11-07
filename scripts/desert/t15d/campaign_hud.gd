extends CanvasLayer
## HUD em pixels físicos: recursos, distrito e avanço têm hierarquias diferentes.
signal pause_requested
signal bridge_requested
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
var _actions: HBoxContainer
var _bridge_task: Button
var _task_caption: Label
var _action_buttons := {}
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
	PlayerUI.apply_theme(_root)
	add_child(_root)
	_identity = PanelContainer.new()
	_identity.add_theme_stylebox_override("panel",box())
	_root.add_child(_identity)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",5)
	_identity.add_child(column)
	_kicker = label("CIDADE DO DESERTO  /  %02d" % int(_stage.order),11,Color("#c7b48f"))
	column.add_child(_kicker)
	_title = label(str(_stage.name),26,Color("#f5eee0"))
	column.add_child(_title)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation",12)
	column.add_child(resources)
	_health = label("VIDA  3/3",14,Color("#f1c5b7"))
	_attack = label("FOGO  1/3",14,Color("#e9c478"))
	_defense = label("DEFESA  1/3",14,Color("#91cee9"))
	# Os rótulos ficam para leitores de tela/testes; o jogador vê os ícones desenhados.
	for item in [_health,_attack,_defense]:
		item.hide()
		resources.add_child(item)
	_icons = Control.new()
	_icons.custom_minimum_size = Vector2(115,40)
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.draw.connect(_draw_resources)
	resources.add_child(_icons)
	_status = PanelContainer.new()
	_status.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	PlayerUI.style_campaign_progress(_bar)
	progress_column.add_child(_bar)
	_pause = Button.new()
	_pause.text = "Ⅱ"
	_pause.tooltip_text = "Pausar (Esc)"
	_pause.focus_mode = Control.FOCUS_ALL
	_pause.add_theme_font_size_override("font_size",22)
	PlayerUI.style_story_action(_pause)
	_pause.pressed.connect(pause_requested.emit)
	_root.add_child(_pause)
	_toast = label("",20,Color("#f1dfb4"))
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toast.add_theme_stylebox_override("normal",box())
	_toast.hide()
	_root.add_child(_toast)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation",8)
	_root.add_child(_actions)
	_bridge_task = Button.new()
	_bridge_task.text = "TASK"
	_bridge_task.custom_minimum_size = Vector2(88,88)
	_bridge_task.focus_mode = Control.FOCUS_NONE
	PlayerUI.style_story_action(_bridge_task)
	_bridge_task.pressed.connect(bridge_requested.emit)
	_bridge_task.hide()
	_root.add_child(_bridge_task)
	_task_caption=label("",20,PlayerUI.TEXT)
	_task_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_task_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_task_caption.hide()
	_root.add_child(_task_caption)
	_actions.visible = not (DisplayServer.is_touchscreen_available() or OS.has_feature("android") or OS.has_feature("web") or UIScale.is_handheld() or "--touch-controls" in OS.get_cmdline_user_args())
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
	return PlayerUI.plate()
func set_bridge_task(available: bool,caption := "Montar ponte · F") -> void:
	_bridge_task.visible = available
	_bridge_task.tooltip_text=caption
	_task_caption.text=caption.trim_suffix(" · F")
	_task_caption.visible=available
	if available:_position_task(_root.size)
func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := UIScale.is_iphone()
	# Em telas baixas os painéis encolhem e perdem a linha secundária: a ação ocupa o quadro.
	var factor := 1.0
	_root.scale = Vector2.ONE*factor
	_kicker.visible = not compact
	var screen := viewport_size/factor
	_root.size = screen
	_identity.position = Vector2(14,14)
	_identity.size = _identity.get_combined_minimum_size()
	_identity.call_deferred("reset_size")
	_status.custom_minimum_size = Vector2(174,76)
	_status.size = _status.get_combined_minimum_size()
	_status.position = Vector2(screen.x-140-_status.size.x,14)
	var pause_size := 88.0 if UIScale.is_iphone() else 64.0
	_pause.size = Vector2.ONE*pause_size
	_pause.position = Vector2(screen.x-64-pause_size*0.5,64-pause_size*0.5)
	_actions.position = Vector2(maxf(14,screen.x-_actions.get_combined_minimum_size().x-24),screen.y-104)
	_toast.position = Vector2(14,maxf(120,_identity.size.y+28))
	_toast.size = Vector2(minf(screen.x-28,460),64)
	_position_task(screen)
func _position_task(screen: Vector2) -> void:
	var area: Rect2=preload("res://scripts/desert/t15d/touch.gd").task_area(screen)
	if _actions.visible and _action_buttons.has("attack"):
		var attack: Button=_action_buttons.attack
		area=Rect2(attack.global_position-Vector2(0,104),Vector2(88,88))
	_bridge_task.size=area.size
	_bridge_task.position=area.position
	_task_caption.size=Vector2(240,56)
	_task_caption.position=Vector2(area.get_center().x-120,area.position.y-58)
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
func _icon(texture: Texture2D, center: Vector2, size: float, alpha := 1.0) -> void:
	_icons.draw_texture_rect(texture,Rect2(center-Vector2.ONE*size*0.5,Vector2.ONE*size),false,Color(1,1,1,alpha))
func update_resources(player: Node) -> void:
	if is_instance_valid(_actions):
		for known: String in _action_buttons:
			(_action_buttons[known] as Button).visible=known=="jump" or player.discovered.has(known)
		var action_index := 0
		for kind in ["attack","rupture","amber","dash","defense","jump"]:
			if kind != "jump" and not player.discovered.has(kind): continue
			if not _action_buttons.has(kind):
				var button := Button.new()
				button.custom_minimum_size = Vector2(88,88)
				PlayerUI.style_story_action(button)
				button.tooltip_text = {"attack":"Fogo (J)","defense":"Defesa (K / Shift)","jump":"Pulo (Espaço)","rupture":"Ruptura (Q)","amber":"Âmbar (E)","dash":"Relâmpago (R)"}[kind]
				button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				for spec: Array in [["Count",Vector2(60,7),18],["Key",Vector2(0,64),16]]:
					var caption := Label.new()
					caption.name = spec[0]
					caption.position = spec[1]
					caption.size = Vector2(88 if spec[0] == "Key" else 24,22)
					caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					caption.add_theme_font_size_override("font_size",spec[2])
					caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
					button.add_child(caption)
				button.gui_input.connect(func(event: InputEvent) -> void:
					if event is InputEventMouseButton and not event.pressed: button.release_focus())
				var action: String = "defend" if kind == "defense" else kind
				button.button_down.connect(func() -> void: Input.action_press(action))
				button.button_up.connect(func() -> void: Input.action_release(action))
				_actions.add_child(button)
				_action_buttons[kind] = button
			var node: Button = _action_buttons[kind]
			node.show()
			_actions.move_child(node,action_index)
			action_index += 1
			node.text = "↑" if kind == "jump" else ""
			(node.get_node("Count") as Label).text = "" if kind == "jump" else str(player.charges(kind))
			(node.get_node("Key") as Label).text = {"attack":"J","defense":"K","rupture":"Q","amber":"E","dash":"R","jump":"Espaço"}[kind]
			if kind != "jump": node.icon = Icons.medallion(kind,36,player.charges(kind)>0)
		_layout()
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
	_attack.text = "FOGO  %d/3" % player.attack_charges
	_defense.text = "DEFESA  %d/3" % player.defense_charges
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
	if _bridge_task.visible:_position_task(_root.size)
	for child in get_children():
		if child is Control and child.has_method("_button_at"):
			_actions.visible = not child.visible
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

## O alvo de toque é maior que o ícone; a composição padrão não muda por densidade.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and is_instance_valid(_pause) and _pause.is_visible_in_tree():
		var target := Rect2(Vector2(_root.size.x-128,0),Vector2(128,128))
		if target.has_point(event.position):
			get_viewport().set_input_as_handled()
			pause_requested.emit()
