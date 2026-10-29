extends "res://scripts/desert/phase_01.gd"
## Campanha urbana noturna 01–09. A fase 10 continua no controlador original.
const ActorSlot = preload("res://scripts/desert/t15d/actor_slot.gd")
const Player = preload("res://scripts/desert/t15d/player.gd")
const Cactus = preload("res://scripts/desert/t15d/cactus.gd")
const Terrain = preload("res://scripts/desert/t15d/terrain.gd")
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
const Progress = preload("res://scripts/desert/t15d/campaign_progress.gd")
const Pickup = preload("res://scripts/desert/t15d/charge_pickup.gd")
const CHUNK_SIZE := 64.0
signal return_requested
var _order := 1
var _scenery: Node3D
var _session: CanvasLayer
var _hud: CanvasLayer
var _touch_pad: Control
var _world: Node3D
var _loaded_chunks := {}
var _defeated_ids := {}
var _collected_ids := {}
var _stream_center := -9999
var _elapsed := 0.0
var _defeated := 0
var _life_token := 0
var _paused := false
var _previous_go_back := true
var _goal: Area3D
var _tutorial_pit := false
var _shield: MeshInstance3D
var _saved := false
var _handoff := false
var _actor_resources: Array[PackedScene] = []
func _ready() -> void:
	_previous_go_back = bool(get_meta("previous_go_back",get_tree().quit_on_go_back))
	get_tree().quit_on_go_back = false
	_order = clampi(int(phase_path.get_file().get_basename().trim_prefix("phase_")),1,9)
	_ensure_input_actions()
	_phase = Layout.build(_order)
	_enemy_catalog = _read_json(ENEMIES_PATH).get("enemies",{})
	# Mantém fontes FBX em cache para não reler modelos ao trocar de trecho.
	var sources := {}
	for entry: Dictionary in [_find_protagonist(),_enemy_catalog.cactus]:
		sources[str(entry.model)] = true
		for source in entry.animations.values(): sources[str(source)] = true
	for source in sources: _actor_resources.append(load(source) as PackedScene)
	_checkpoint = _vec3(_phase.player_spawn)
	_build_environment()
	_world = Node3D.new()
	_world.name = "StreamedCity"
	add_child(_world)
	_build_player()
	_build_goal()
	_stream_world(_player.position.x,true)
	_build_camera()
	_build_hud()
	_hud.notify("Vida 3/3 • ataque e defesa têm uma carga")
func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player): return
	if not completed and not _respawning:
		_elapsed += delta
		if _player.position.y < float(_phase.kill_plane_y): _player.fall_out()
		_stream_world(_player.position.x)
		_update_progress()
		if not _tutorial_pit and _player.position.x > float(_phase.holes[0].start)-12.0:
			_tutorial_pit = true
			_hud.notify("Buraco à frente • pule para atravessar")
	_follow_camera(delta)
	_shield.visible = _player.is_defending and not _player.is_dead
	_shield.position = _player.position+Vector3(0,0.8,0)
func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	var environment := world_environment.environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#091627")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#819ecb")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-40,-30,0)
	moon.light_color = Color("#aac8f3")
	moon.light_energy = 0.72
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 32
	moon.shadow_bias = 0.04
	add_child(moon)
	var front := DirectionalLight3D.new()
	front.rotation_degrees = Vector3(-20,0,0)
	front.light_color = Color("#c8d9ee")
	front.light_energy = 0.28
	add_child(front)
	_scenery = preload("res://scripts/desert/t15d/night_scenery.gd").new()
	_scenery.configure(_order,float(_phase.length),float(_phase.player_spawn[0]))
	add_child(_scenery)
	get_viewport().msaa_3d = Viewport.MSAA_2X
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
	_player.inventory_changed.connect(_sync_resources)
	_player.action_empty.connect(func(kind: String) -> void:
		if is_instance_valid(_hud): _hud.notify("Sem ataque • procure a lâmina dourada" if kind == "attack" else "Sem defesa • procure o escudo azul",true))
	_player.blocked.connect(func() -> void: _impact(_player.position+Vector3(_player.facing*0.45,0.9,0),Color("#9cdeff")))
	_player.setup(_find_protagonist())
	_shield = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.74
	ring.outer_radius = 0.78
	ring.rings = 24
	ring.ring_segments = 6
	_shield.mesh = ring
	_shield.rotation_degrees.x = 90
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#8edfff")
	_shield.material_override = material
	_shield.hide()
	add_child(_shield)
func _stream_world(x: float, force := false) -> void:
	var center := floori(x/CHUNK_SIZE)
	if center == _stream_center and not force: return
	_stream_center = center
	var minimum := floori(float(_phase.bounds.min_x)/CHUNK_SIZE)
	var maximum := floori(float(_phase.bounds.max_x)/CHUNK_SIZE)
	var wanted := {}
	for index in range(maxi(minimum,center-1),mini(maximum,center+1)+1): wanted[index] = true
	for index in _loaded_chunks.keys():
		if not wanted.has(index):
			var old: Node3D = _loaded_chunks[index]
			_world.remove_child(old)
			old.queue_free()
			_loaded_chunks.erase(index)
	for index in wanted:
		if not _loaded_chunks.has(index): _load_chunk(index)
func _load_chunk(index: int) -> void:
	var chunk := Node3D.new()
	chunk.name = "DistrictChunk_%d" % index
	_world.add_child(chunk)
	_loaded_chunks[index] = chunk
	var left := index*CHUNK_SIZE
	var right := left+CHUNK_SIZE
	var platforms: Array = []
	for source: Dictionary in _phase.platforms:
		var original_left := float(source.pos[0])-float(source.size[0])*0.5
		var original_right := float(source.pos[0])+float(source.size[0])*0.5
		var x0 := maxf(original_left,left)
		var x1 := minf(original_right,right)
		if x1-x0 < 0.01: continue
		var part: Dictionary = source.duplicate(true)
		part.pos[0] = (x0+x1)*0.5
		part.size[0] = x1-x0
		# Somente bordas reais do terreno recebem laterais/lanternas de aviso.
		part.cap_left = _is_exposed_edge(x0,true,source.kind)
		part.cap_right = _is_exposed_edge(x1,false,source.kind)
		if source.kind != "ground":
			part.cap_left = absf(x0-original_left)<0.02
			part.cap_right = absf(x1-original_right)<0.02
		part.pit_left = source.kind == "ground" and _is_pit_edge(x0,true)
		part.pit_right = source.kind == "ground" and _is_pit_edge(x1,false)
		platforms.append(part)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = _vec3(part.pos)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var dimensions := _vec3(part.size)
		if part.kind == "ground":
			dimensions.y = 5.5
			body.position.y = -2.75
		box.size = dimensions
		shape.shape = box
		body.add_child(shape)
		chunk.add_child(body)
	if not platforms.is_empty():
		var terrain := Terrain.new()
		terrain.order = _order
		chunk.add_child(terrain)
		terrain.build(platforms)
		var props := preload("res://scripts/desert/t15d/city_props.gd").new()
		chunk.add_child(props)
		props.build(platforms,_order)
	for spawn: Dictionary in _phase.enemies:
		if _in_chunk(float(spawn.pos[0]),index) and not _defeated_ids.has(str(spawn.id)):
			_spawn_enemy(chunk,spawn)
	for spawn: Dictionary in _phase.pickups:
		if _in_chunk(float(spawn.pos[0]),index) and not _collected_ids.has(str(spawn.id)):
			var item := Pickup.new()
			item.pickup_id = str(spawn.id)
			item.kind = str(spawn.kind)
			item.position = _vec3(spawn.pos)
			item.collected.connect(_on_pickup_collected)
			item.full_touched.connect(func(kind: String) -> void:
				if is_instance_valid(_hud): _hud.notify("Ataque cheio • reposição preservada" if kind == "attack" else "Defesa cheia • reposição preservada"))
			chunk.add_child(item)
	for sign: Dictionary in _phase.signs:
		if _in_chunk(float(sign.pos[0]),index): _build_pit_sign(chunk,sign)
func _in_chunk(x: float, index: int) -> bool:
	return floori(x/CHUNK_SIZE) == index
func _is_pit_edge(x: float, left: bool) -> bool:
	for hole: Dictionary in _phase.holes:
		if absf(x-float(hole.end if left else hole.start)) < 0.02: return true
	return false
func _is_exposed_edge(x: float, left: bool, kind: String) -> bool:
	if kind != "ground": return true
	return _is_pit_edge(x,left) or absf(x-float(_phase.bounds.min_x if left else _phase.bounds.max_x))<0.02
func _spawn_enemy(chunk: Node3D, spawn: Dictionary) -> void:
	var enemy := Cactus.new()
	enemy.position = _vec3(spawn.pos)
	enemy.set_meta("spawn_id",str(spawn.id))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.45
	collision.shape = capsule
	collision.position.y = 0.725
	enemy.add_child(collision)
	var model := ActorSlot.new()
	model.name = "Model"
	enemy.add_child(model)
	chunk.add_child(enemy)
	enemy.setup(_enemy_catalog.cactus,spawn)
	enemy.defeated.connect(func() -> void:
		_defeated_ids[str(spawn.id)] = true
		_defeated = _defeated_ids.size())
func _build_pit_sign(chunk: Node3D, entry: Dictionary) -> void:
	var label := Label3D.new()
	label.text = "VÃO →" if int(entry.direction)>0 else "← VÃO"
	label.font = preload("res://assets/desert/phase01/interface.ttf")
	label.font_size = 44
	label.pixel_size = 0.006
	label.position = _vec3(entry.pos)+Vector3.UP*0.8
	label.modulate = Color("#e1bd7d")
	label.outline_modulate = Color("#081523")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chunk.add_child(label)
func _on_pickup_collected(id: String, kind: String) -> void:
	_collected_ids[id] = true
	_hud.notify("Ataque +1" if kind == "attack" else "Defesa +1")
func _build_goal() -> void:
	_goal = Area3D.new()
	_goal.name = "ExitGate"
	_goal.position = _vec3(_phase.goal.pos)
	_goal.collision_layer = 0
	_goal.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2,3.0,1.5)
	shape.shape = box
	_goal.add_child(shape)
	_goal.body_entered.connect(_on_goal_entered)
	add_child(_goal)
	var arch := Terrain.new()
	add_child(arch)
	arch.arch(Vector3(float(_phase.goal.pos[0]),0,-1.8),1.8)
	var label := Label3D.new()
	label.text = "PRÓXIMO DISTRITO"
	label.font = preload("res://assets/desert/phase01/interface.ttf")
	label.font_size = 48
	label.pixel_size = 0.007
	label.modulate = Color("#e5c58b")
	label.position = Vector3(float(_phase.goal.pos[0]),3.5,-1.4)
	add_child(label)
	var boundary := StaticBody3D.new()
	boundary.position = Vector3(float(_phase.bounds.min_x)-0.25,2.5,0)
	var barrier := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.5,5,4)
	barrier.shape = wall_shape
	boundary.add_child(barrier)
	var visual := MeshInstance3D.new()
	var wall := BoxMesh.new()
	wall.size = wall_shape.size
	visual.mesh = wall
	visual.material_override = Terrain.stone_material(Color("#8390a0"))
	boundary.add_child(visual)
	add_child(boundary)
func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.current = true
	_camera.far = 90
	add_child(_camera)
	_follow_camera(1.0)
func _follow_camera(delta: float) -> void:
	_camera.size = 6.9 if get_window().size.y < 600 else 7.6
	var lead := clampf(_player.velocity.x/6.0,-1.0,1.0)*1.4
	var target := Vector3(clampf(_player.position.x+lead,float(_phase.player_spawn[0]),float(_phase.goal.pos[0])),maxf(1.65,_player.position.y+1.4-_camera.size*0.5+0.55),0)
	var destination := target+Vector3(0,1,14)
	_camera.position = _camera.position.lerp(destination,1.0-exp(-8*delta))
	_camera.look_at(Vector3(_camera.position.x,_camera.position.y-1,0),Vector3.UP)
	_scenery.follow(_camera,_player.position.x)
func _build_hud() -> void:
	_hud = preload("res://scripts/desert/t15d/campaign_hud.gd").new()
	_hud.configure(_phase)
	add_child(_hud)
	_hud.pause_requested.connect(_pause)
	_touch_pad = preload("res://scripts/desert/t15d/touch.gd").new()
	_touch_pad.actor = _player
	_hud.add_child(_touch_pad)
	var combat := preload("res://scripts/desert/t15d/combat_readout.gd").new()
	combat.phase = self
	_hud.add_child(combat)
	_session = preload("res://scripts/desert/t15d/session_overlay.gd").new()
	_session.order = _order
	_session.phase_name = str(_phase.name)
	_session.total_enemies = _phase.enemies.size()
	add_child(_session)
	_session.resume_requested.connect(_resume)
	_session.restart_requested.connect(_restart_level)
	_session.next_requested.connect(func() -> void:
		_resume()
		_advance(str(_phase.next_scene)))
	_session.return_requested.connect(_return_to_story)
	_sync_resources()
func _sync_resources() -> void:
	if is_instance_valid(_hud): _hud.update_resources(_player)
func _on_player_health_changed(_current: int, _maximum: int) -> void:
	_sync_resources()
func _update_progress() -> void:
	var share := clampf((_player.position.x-float(_phase.player_spawn[0]))/float(_phase.length),0,1)
	var district := mini(int(share*8),7)
	_hud.update_progress(share,_elapsed,str(_phase.districts[district].name))
func _impact(point: Vector3, color := Color("#ffd58a")) -> void:
	var particles := CPUParticles3D.new()
	particles.position = point
	particles.amount = 10
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
	material.albedo_color = color
	mesh.material = material
	particles.mesh = mesh
	add_child(particles)
	get_tree().create_timer(0.8,false).timeout.connect(particles.queue_free)
func _on_goal_entered(body: Node3D) -> void:
	if body != _player or completed or _player.is_dead or _respawning: return
	completed = true
	_saved = Progress.complete(_order) == OK
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_player._model.play_animation("pronto",true)
	_release_input()
	_touch_pad.hide()
	_touch_pad.set_process(false)
	_hud.set_completed(true)
	_hud.update_progress(1.0,_elapsed,"Concluída")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(enemy): enemy.set_physics_process(false)
	_session.show_completion(_defeated,_elapsed,_saved)
func _release_input() -> void:
	if is_instance_valid(_touch_pad): _touch_pad.release_all()
	for action in ["move_left","move_right","jump","attack","defend","crouch"]: Input.action_release(action)
func _pause() -> void:
	if completed or _paused: return
	_release_input()
	_touch_pad.hide()
	_paused = true
	_session.show_pause()
	get_tree().paused = true
func _resume() -> void:
	get_tree().paused = false
	_paused = false
	_release_input()
	_session.close()
	_touch_pad._last_pixels = Vector2i.ZERO
	get_viewport().gui_release_focus()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not completed:
		_pause()
		get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if not is_instance_valid(_session) or completed: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _paused: _resume()
		else: _pause()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _pause()
func _on_player_died() -> void:
	if _respawning or completed: return
	_respawning = true
	_release_input()
	_life_token += 1
	var token := _life_token
	_hud.notify("Você caiu • recomeçando a fase" if _player.position.y < -3 else "Derrotado • recomeçando a fase",true)
	get_tree().create_timer(1.4,false).timeout.connect(func() -> void:
		if token == _life_token: _restart_level())
func _respawn_player() -> void:
	_restart_level()
func _restart_level() -> void:
	_life_token += 1
	_resume()
	completed = false
	_respawning = false
	_saved = false
	_elapsed = 0.0
	_defeated = 0
	_defeated_ids.clear()
	_collected_ids.clear()
	_tutorial_pit = false
	for chunk: Node in _loaded_chunks.values():
		_world.remove_child(chunk)
		chunk.queue_free()
	_loaded_chunks.clear()
	_player.is_dead = false
	_player.position = _vec3(_phase.player_spawn)
	_player.velocity = Vector3.ZERO
	_player.facing = 1
	_player.setup(_find_protagonist())
	_player._invulnerable = 0.6
	_player.set_physics_process(true)
	_touch_pad.set_process(true)
	_stream_world(_player.position.x,true)
	_follow_camera(1.0)
	_hud.set_completed(false)
	_sync_resources()
func _advance(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_hud.notify("Não foi possível abrir a próxima fase",true)
		return
	var next := packed.instantiate()
	if next.has_signal("return_requested"):
		_handoff = true
		next.set_meta("previous_go_back",_previous_go_back)
		for connection in return_requested.get_connections(): next.connect("return_requested",connection.callable)
	get_parent().add_child(next)
	if next.has_method("_hide_legacy_wrapper"):
		tree_exited.connect(next.call_deferred.bind("_hide_legacy_wrapper"))
	queue_free()
func _hide_legacy_wrapper() -> void:
	for sibling in get_parent().get_children():
		if sibling is PrototypeReturnOverlay:
			sibling.hide()
			sibling.process_mode = Node.PROCESS_MODE_DISABLED
func _return_to_story() -> void:
	_resume()
	if return_requested.get_connections().is_empty(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	else: return_requested.emit()
func _exit_tree() -> void:
	if _paused: get_tree().paused = false
	if not _handoff: get_tree().quit_on_go_back = _previous_go_back
	if is_instance_valid(get_parent()):
		for sibling in get_parent().get_children():
			if sibling is PrototypeReturnOverlay:
				sibling.show()
				sibling.process_mode = Node.PROCESS_MODE_INHERIT
