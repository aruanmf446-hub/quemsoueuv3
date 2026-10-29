extends "res://scripts/desert/phase_01.gd"
## Entrada exclusiva de T15D. Os scripts/cenas compartilhados das outras nove fases ficam intactos.
const ActorSlot = preload("res://scripts/desert/t15d/actor_slot.gd")
const Player = preload("res://scripts/desert/t15d/player.gd")
const Cactus = preload("res://scripts/desert/t15d/cactus.gd")
const Terrain = preload("res://scripts/desert/t15d/terrain.gd")
var _backdrop: Sprite3D
var _hud_root: Control
var _hud_box: PanelContainer
var _progress_box: PanelContainer
var _bar: ProgressBar
var _hint: Label
var _touch_pad: Control
var _markers: Array[MeshInstance3D] = []
var _last_checkpoint := Vector3.ZERO
var _font: FontFile
func _physics_process(delta: float) -> void:
	if is_instance_valid(_player):
		if not completed and not _respawning:
			if _player.position.y < float(_phase.get("kill_plane_y",-8)): _player.fall_out()
			_update_progress()
		_follow_camera(delta)
		if _last_checkpoint != _checkpoint:
			_last_checkpoint = _checkpoint
			for marker in _markers:
				marker.material_override = _marker_material(marker.position.x <= _checkpoint.x)
func _build_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#b2c4cc")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b4c9dc")
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_color = Color("#ffe2b0")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 38
	sun.shadow_bias = 0.04
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,0,0)
	fill.light_color = Color("#d3e4ff")
	fill.light_energy = 0.45
	add_child(fill)
	_backdrop = Sprite3D.new()
	_backdrop.texture = preload("res://assets/desert/phase01/desert_kingdom.png")
	_backdrop.pixel_size = 0.01
	_backdrop.shaded = false
	_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_backdrop)
	get_viewport().msaa_3d = Viewport.MSAA_2X
func _build_platforms() -> void:
	for platform: Dictionary in _phase.platforms:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var dimensions := _vec3(platform.size)
		body.position = _vec3(platform.pos)
		if platform.kind == "ground":
			dimensions.y = 5.5
			body.position.y = -2.75
		box.size = dimensions
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	var terrain := Terrain.new()
	terrain.name = "DesertArchitecture"
	add_child(terrain)
	terrain.build(_phase.platforms)
func _build_player() -> void:
	_player = Player.new()
	_player.name = "ElFuego"
	_player.position = _vec3(_phase.player_spawn)
	var model := ActorSlot.new()
	model.name = "Model"
	_player.add_child(model)
	add_child(_player)
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_player.strike_landed.connect(_impact)
	_player.setup(_find_protagonist())
func _build_enemies() -> void:
	for spawn: Dictionary in _phase.enemies:
		var entry: Dictionary = _enemy_catalog.get(spawn.type,{})
		if entry.is_empty(): continue
		var enemy := Cactus.new()
		enemy.position = _vec3(spawn.pos)
		enemy.set_meta("spawn_position",enemy.position)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.45
		shape.shape = capsule
		shape.position.y = 0.725
		enemy.add_child(shape)
		var model := ActorSlot.new()
		model.name = "Model"
		enemy.add_child(model)
		add_child(enemy)
		enemy.setup(entry,spawn)
func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	_camera.far = 90
	add_child(_camera)
	_follow_camera(1.0)
func _follow_camera(delta: float) -> void:
	var compact := get_window().size.y < 600
	_camera.size = 6.5 if compact else 7.3
	var lead := clampf(_player.velocity.x/6.0,-1.0,1.0)*1.2
	var target := Vector3(clampf(_player.position.x+lead,-8.0,52.0),maxf(1.65,_player.position.y+1.4-_camera.size*0.5+0.55),0)
	var destination := target+Vector3(0,1.0,14)
	_camera.position = _camera.position.lerp(destination,1.0-exp(-8.0*delta))
	_camera.look_at(Vector3(_camera.position.x,_camera.position.y-1.0,0),Vector3.UP)
	_backdrop.basis = _camera.basis
	_backdrop.position = _camera.position-_camera.basis.z*48+_camera.basis.x*(sin(_player.position.x*0.028)*0.6)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var height := maxf(_camera.size*1.18,_camera.size*aspect/1.778*1.18)
	_backdrop.scale = Vector3.ONE*height/(_backdrop.texture.get_height()*0.01)
func _build_hud() -> void:
	_font = preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
	_font.multichannel_signed_distance_field = true
	_font.msdf_size = 48
	var layer := CanvasLayer.new()
	layer.name = "PhaseHUD"
	add_child(layer)
	_hud_root = Control.new()
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.theme = Theme.new()
	_hud_root.theme.default_font = _font
	layer.add_child(_hud_root)
	_hud_box = PanelContainer.new()
	_hud_box.add_theme_stylebox_override("panel",_ui_box())
	_hud_root.add_child(_hud_box)
	var column := VBoxContainer.new()
	_hud_box.add_child(column)
	column.add_theme_constant_override("separation",4)
	column.add_child(_hud_label("REINO DO DESERTO   /   01",12,Color("#e7c586")))
	column.add_child(_hud_label("Entrada do Deserto",21,Color.WHITE))
	_health_label = _hud_label("VIDA  5 / 5",16,Color("#efddbc"))
	column.add_child(_health_label)
	_progress_box = PanelContainer.new()
	_progress_box.add_theme_stylebox_override("panel",_ui_box())
	_hud_root.add_child(_progress_box)
	var progress := VBoxContainer.new()
	_progress_box.add_child(progress)
	_progress_label = _hud_label("PROGRESSO   0%",13,Color("#e7c586"))
	progress.add_child(_progress_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(160,5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#d5b36d")
	_bar.add_theme_stylebox_override("fill",fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#283747")
	_bar.add_theme_stylebox_override("background",back)
	progress.add_child(_bar)
	_message_label = PlayerUI.label("",24,Color("#fff0cc"))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_outline_color",Color("#132232"))
	_message_label.add_theme_constant_override("outline_size",5)
	_message_label.visible = false
	_hud_root.add_child(_message_label)
	_hint = PlayerUI.label("A / D  mover     ESPAÇO  pulo ×2     J  atacar     SHIFT  defender     S  agachar",13,Color("#f3dfbb"))
	_hint.add_theme_color_override("font_outline_color",Color("#172536"))
	_hint.add_theme_constant_override("outline_size",4)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_root.add_child(_hint)
	_touch_pad = preload("res://scripts/desert/t15d/touch.gd").new()
	layer.add_child(_touch_pad)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()
	_on_player_health_changed(_player.health,SidePlayer.MAX_HEALTH)
func _hud_label(text: String, pixels: int, color: Color) -> Label:
	var label := PlayerUI.label(text,pixels,color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font",_font)
	return label
func _ui_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.065,0.11,0.84)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.8,0.65,0.38,0.6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
func _layout_hud() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := viewport_size.y/maxf(get_window().size.y,1) if get_window().size.y < 600 else 1.0
	_hud_root.scale = Vector2.ONE*factor
	var screen := viewport_size/factor
	_hud_root.size = screen
	_hud_box.position = Vector2(14,14)
	_hud_box.custom_minimum_size = Vector2(240,84)
	_hud_box.size = _hud_box.custom_minimum_size
	_progress_box.position = Vector2(screen.x-196,14)
	_progress_box.custom_minimum_size = Vector2(182,48)
	_progress_box.size = _progress_box.custom_minimum_size
	_message_label.position = Vector2(14,screen.y*0.20)
	_message_label.size = Vector2(screen.x-28,80)
	_hint.visible = get_window().size.y >= 600
	_hint.position = Vector2(10,screen.y-30)
	_hint.size.x = screen.x-20
func _update_progress() -> void:
	super._update_progress()
	_bar.value = clampf((_player.position.x+8)/60.0*100.0,0,100)
func _build_checkpoints() -> void:
	super._build_checkpoints()
	for area in get_children():
		if area is Area3D: area.collision_mask = 2
	for checkpoint: Dictionary in _phase.checkpoints:
		var marker := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.23
		ring.outer_radius = 0.30
		marker.mesh = ring
		marker.rotation_degrees.x = 90
		marker.position = _vec3(checkpoint.pos)+Vector3(0,0.7,-0.7)
		marker.material_override = _marker_material(false)
		add_child(marker)
		_markers.append(marker)
func _marker_material(active: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#eac47e") if active else Color("#77c8db")
	mat.emission_enabled = true
	mat.emission = mat.albedo_color*0.35
	return mat
func _build_goal() -> void:
	super._build_goal()
	for area in get_children():
		if area is Area3D: area.collision_mask = 2
	var arch := Terrain.new()
	add_child(arch)
	arch.arch(Vector3(52,0,-0.6),1.6)
func _respawn_player() -> void:
	super._respawn_player()
	_follow_camera(1.0)
func _impact(point: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = point
	particles.amount = 12
	particles.one_shot = true
	particles.lifetime = 0.22
	particles.explosiveness = 1
	particles.direction = Vector3(0,1,1)
	particles.spread = 75
	particles.initial_velocity_min = 1
	particles.initial_velocity_max = 3
	particles.gravity = Vector3(0,-8,0)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.65
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color("#ffd58a")
	mesh.material = material
	particles.mesh = mesh
	particles.color = Color("#ffd58a")
	add_child(particles)
	get_tree().create_timer(0.8).timeout.connect(particles.queue_free)

func _on_goal_entered(body: Node3D) -> void:
	super._on_goal_entered(body)
	if not completed: return
	_player.velocity = Vector3.ZERO
	_bar.value = 100
	_progress_label.text = "Progresso 100%"
	_hint.hide()
	for index in _touch_pad._held.keys(): _touch_pad._release(index)
	_touch_pad.hide()
	_touch_pad.set_process(false)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy.get_parent() == self: enemy.set_physics_process(false)
	_player._model.play_animation("pronto",true)
	_show_message("Fase concluída")
	for child in _hud_root.get_children():
		if child is Button and child.text == "Próxima fase":
			child.position = _hud_root.size*0.5+Vector2(-110,30)
