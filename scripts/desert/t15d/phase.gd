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
const AHEAD := 2
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
var _shield: Node3D
var _saved := false
var _handoff := false
var _actor_resources: Array[PackedScene] = []
var _lead := 0.0
var _build_queue: Array[Callable] = []
## Checkpoint ativo (-1 = início da fase) e o estado salvo ao passar por ele.
var _checkpoint_index := -1
var _snapshot := {}
var _sfx: Node
var _key_light: OmniLight3D
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
	_sfx = preload("res://scripts/desert/t15d/combat_sfx.gd").new()
	_sfx.name = "CombatSfx"
	add_child(_sfx)
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
		_check_checkpoints()
		if not _tutorial_pit and _player.position.x > float(_phase.holes[0].start)-12.0:
			_tutorial_pit = true
			_hud.notify("Buraco à frente • pule para atravessar")
	_follow_camera(delta)
	_key_light.position = _player.position+Vector3(0.0,1.5,1.8)
	_shield.active = _player.is_defending and not _player.is_dead
	_shield.position = _player.position
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
	# Luz de contorno fria vinda de trás: recorta personagens e Cactus do fundo iluminado.
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.rotation_degrees = Vector3(-18,165,0)
	rim.light_color = Color("#8fb4ff")
	rim.light_energy = 0.9
	rim.light_specular = 0.6
	add_child(rim)
	# Antisserrilhado: 4× no computador, 2× em celulares e no navegador.
	get_viewport().msaa_3d = Viewport.MSAA_2X if UIScale.is_compact() or OS.has_feature("web") else Viewport.MSAA_4X
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
	_player.swung.connect(func() -> void: _sfx.play("swing"))
	_player.jumped_up.connect(func() -> void: _sfx.play("jump",1.0 if _player.jumps_used < 2 else 1.25,-9.0))
	_player.landed.connect(func() -> void: _sfx.play("land",1.0,-8.0))
	_player.hurt.connect(func() -> void: _sfx.play("hurt"))
	_player.strike_landed.connect(func(_point: Vector3) -> void: _sfx.play("hit"))
	_player.blocked.connect(func() -> void: _sfx.play("block"))
	_player.action_empty.connect(func(_kind: String) -> void: _sfx.play("empty",1.0,-5.0))
	_player.action_empty.connect(func(kind: String) -> void:
		if is_instance_valid(_hud): _hud.notify("Sem ataque • procure a lâmina dourada" if kind == "attack" else "Sem defesa • procure o escudo azul",true))
	_player.blocked.connect(func() -> void: _impact(_player.position+Vector3(_player.facing*0.45,0.9,0),Color("#9cdeff")))
	_player.setup(_find_protagonist())
	# Luz de recorte que acompanha o protagonista: o traje escuro não some na muralha.
	_key_light = OmniLight3D.new()
	_key_light.name = "PlayerKeyLight"
	_key_light.light_color = Color("#ffd9b0")
	_key_light.light_energy = 0.75
	_key_light.omni_range = 3.6
	_key_light.shadow_enabled = false
	add_child(_key_light)
	_shield = preload("res://scripts/desert/t15d/sand_fx.gd").SandShield.new()
	_shield.name = "SandShield"
	add_child(_shield)
	_player.blocked.connect(func() -> void: _shield.absorb(-_player.facing))
func _stream_world(x: float, force := false) -> void:
	var center := floori(x/CHUNK_SIZE)
	if center == _stream_center and not force: return
	_stream_center = center
	var minimum := floori(float(_phase.bounds.min_x)/CHUNK_SIZE)
	var maximum := floori(float(_phase.bounds.max_x)/CHUNK_SIZE)
	# Dois trechos à frente e atrás: o próximo trecho fica pronto bem antes de aparecer.
	var wanted := {}
	for index in range(maxi(minimum,center-AHEAD),mini(maximum,center+AHEAD)+1): wanted[index] = true
	for index in _loaded_chunks.keys():
		if not wanted.has(index):
			var old: Node3D = _loaded_chunks[index]
			_world.remove_child(old)
			old.queue_free()
			_loaded_chunks.erase(index)
	# O trecho atual e os vizinhos imediatos são montados na hora (spawn, reinício,
	# checkpoint); os mais distantes entram na fila e são montados aos poucos.
	var order: Array = wanted.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return absi(a-center) < absi(b-center))
	for index in order:
		if not _loaded_chunks.has(index): _load_chunk(index,force or absi(index-center) <= 1)
## Monta o trecho em etapas. Antes tudo era feito num único quadro (20–55ms no desktop,
## bem mais no celular), o que travava a corrida a cada 64m.
func _load_chunk(index: int, immediate := true) -> void:
	var chunk := Node3D.new()
	chunk.name = "DistrictChunk_%d" % index
	_world.add_child(chunk)
	_loaded_chunks[index] = chunk
	var tasks: Array[Callable] = []
	var platforms := _chunk_platforms(index)
	# Colisão primeiro: é barata e precisa existir antes de qualquer visual.
	_build_collision(chunk,platforms)
	if not platforms.is_empty():
		for platform: Dictionary in platforms:
			tasks.append(_build_terrain_piece.bind(chunk,platform))
		tasks.append(_build_props.bind(chunk,platforms))
	for spawn: Dictionary in _phase.enemies:
		if _in_chunk(float(spawn.pos[0]),index) and not _defeated_ids.has(str(spawn.id)):
			tasks.append(_spawn_enemy.bind(chunk,spawn))
	tasks.append(_build_chunk_details.bind(chunk,index))
	for task in tasks:
		if immediate: task.call()
		else: _build_queue.append(task)
func _process(_delta: float) -> void:
	# Uma etapa por quadro (mais etapas só enquanto o quadro gastou menos de 1ms).
	var started := Time.get_ticks_usec()
	while not _build_queue.is_empty() and Time.get_ticks_usec()-started < 1000:
		var task: Callable = _build_queue.pop_front()
		var chunk: Object = task.get_bound_arguments()[0] if not task.get_bound_arguments().is_empty() else null
		if chunk == null or is_instance_valid(chunk) and (chunk as Node).is_inside_tree(): task.call()
func _chunk_platforms(index: int) -> Array:
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
	return platforms
func _build_collision(chunk: Node3D, platforms: Array) -> void:
	for part: Dictionary in platforms:
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
func _build_terrain_piece(chunk: Node3D, platform: Dictionary) -> void:
	var terrain := Terrain.new()
	terrain.order = _order
	chunk.add_child(terrain)
	terrain.build([platform])
func _build_props(chunk: Node3D, platforms: Array) -> void:
	var props := preload("res://scripts/desert/t15d/city_props.gd").new()
	chunk.add_child(props)
	props.build(platforms,_order)
func _build_chunk_details(chunk: Node3D, index: int) -> void:
	var left := index*CHUNK_SIZE
	var right := left+CHUNK_SIZE
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
	var points: Array = _phase.get("checkpoints",[])
	for point_index in range(points.size()):
		if _in_chunk(float(points[point_index].pos[0]),index):
			var banner := preload("res://scripts/desert/t15d/checkpoint_banner.gd").new()
			banner.index = point_index
			banner.position = _vec3(points[point_index].pos)+Vector3(-0.9,0,-1.6)
			chunk.add_child(banner)
			banner.refresh_lit(_checkpoint_index)
	for hole: Dictionary in _phase.holes:
		var x0 := maxf(float(hole.start),left)
		var x1 := minf(float(hole.end),right)
		if x1 > x0: _build_pit_void(chunk,x0,x1)
		for edge in [float(hole.start),float(hole.end)]:
			if _in_chunk(edge,index): _build_pit_lip(chunk,edge,edge == float(hole.start))
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
	enemy.winding_up.connect(func() -> void: _sfx.play("windup",0.9,-4.0))
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
## Fundo do vão: antes o panorama aparecia pelo buraco e o vão parecia uma janela.
## Um poço escuro com gradiente deixa claro que ali não há chão.
func _build_pit_void(chunk: Node3D, x0: float, x1: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bands := [[0.0,Color("#2b1d16")],[-0.7,Color("#140d0c")],[-2.4,Color("#050609")],[-12.0,Color("#020205")]]
	for band in range(bands.size()-1):
		var top: float = bands[band][0]
		var bottom: float = bands[band+1][0]
		var a: Color = bands[band][1]
		var b: Color = bands[band+1][1]
		for vertex in [[x0,top,a],[x1,top,a],[x1,bottom,b],[x0,top,a],[x1,bottom,b],[x0,bottom,b]]:
			st.set_color(vertex[2])
			st.add_vertex(Vector3(vertex[0],vertex[1],-2.1))
	# Fundo da fenda atrás do corredor: sem ele o panorama aparecia numa faixa acima do poço.
	for vertex in [[x0,-6.5],[x1,-6.5],[x1,-2.1],[x0,-6.5],[x1,-2.1],[x0,-2.1]]:
		st.set_color(Color("#21160f"))
		st.add_vertex(Vector3(vertex[0],-0.01,vertex[1]))
	var mesh := MeshInstance3D.new()
	mesh.name = "PitVoid"
	mesh.set_meta("pit_void",Vector2(x0,x1))
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(mesh)
## Borda de perigo: friso âmbar no lábio do piso e faixa marcada antes do vão.
func _build_pit_lip(chunk: Node3D, x: float, left_edge: bool) -> void:
	var inward := -1.0 if left_edge else 1.0
	var lip := MeshInstance3D.new()
	lip.name = "PitLip"
	var strip := BoxMesh.new()
	strip.size = Vector3(0.07,0.06,4.1)
	lip.mesh = strip
	lip.position = Vector3(x+inward*0.035,0.0,0.0)
	lip.set_meta("pit_edge",x)
	lip.material_override = _pit_material("lip")
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(lip)
	var band := MeshInstance3D.new()
	band.name = "PitBand"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9,3.9)
	band.mesh = plane
	band.position = Vector3(x+inward*0.57,0.012,0.0)
	band.material_override = _pit_material("band")
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(band)
var _pit_materials := {}
func _pit_material(key: String) -> StandardMaterial3D:
	if _pit_materials.has(key): return _pit_materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if key == "lip":
		material.albedo_color = Color("#e09a45")
	else:
		material.albedo_color = Color(0.85,0.42,0.12,0.22)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pit_materials[key] = material
	return material
func _on_pickup_collected(id: String, kind: String) -> void:
	_collected_ids[id] = true
	_sfx.play("pickup",1.0 if kind == "attack" else 1.25)
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
	label.outline_modulate = Color("#081523")
	label.outline_size = 10
	# Acima do arco e sem teste de profundidade: antes as colunas cortavam o texto.
	label.no_depth_test = true
	label.position = Vector3(float(_phase.goal.pos[0]),4.15,-1.0)
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
	# Telas baixas (844×390) aproximam mais: o personagem não pode virar um ícone.
	_camera.size = 6.0 if UIScale.is_compact() else 7.0
	# Antecipação maior na direção da corrida: o próximo vão entra no quadro mais cedo.
	_lead = move_toward(_lead,clampf(_player.velocity.x/6.0,-1.0,1.0)*2.4,delta*4.0)
	var lead := _lead
	# Em telas baixas o chão sobe no quadro (~60%): os botões de toque ficam sobre a
	# parede do terreno, não sobre a borda dos buracos à frente.
	var floor_y := 0.75 if UIScale.is_compact() else 1.65
	var target := Vector3(clampf(_player.position.x+lead,float(_phase.player_spawn[0]),float(_phase.goal.pos[0])),maxf(floor_y,_player.position.y+1.4-_camera.size*0.5+0.55),0)
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
	_session.checkpoint_requested.connect(_respawn_at_checkpoint)
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
	if completed or _paused or _respawning: return
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
		# Na tela de derrota, Voltar equivale a escolher o checkpoint.
		if _respawning:
			if _paused: _respawn_at_checkpoint()
		elif _paused: _resume()
		else: _pause()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _pause()
func _on_player_died() -> void:
	if _respawning or completed: return
	_respawning = true
	_release_input()
	_life_token += 1
	var token := _life_token
	var fell := _player.position.y < -1.0
	_sfx.play("fall" if fell else "hurt",1.0 if fell else 0.7)
	_hud.pulse(Color(0.02,0.015,0.03),0.8,1.0,true)
	# Depois da queda/animação de morte, a fase pausa e o jogador escolhe para onde voltar.
	get_tree().create_timer(1.0,false).timeout.connect(func() -> void:
		if token != _life_token or completed: return
		_touch_pad.hide()
		_session.show_death(fell,"checkpoint %d" % (_checkpoint_index+1) if _checkpoint_index >= 0 else "")
		_paused = true
		get_tree().paused = true)
## Checkpoints: ao passar pela bandeira de um distrito, guarda posição, cargas, Cactus
## derrotados e itens coletados. Voltar a ele restaura esse estado com a vida cheia.
func _check_checkpoints() -> void:
	var points: Array = _phase.get("checkpoints",[])
	var next := _checkpoint_index+1
	if next >= points.size() or _player.is_dead: return
	if _player.position.x < float(points[next].pos[0]) or not _player.is_on_floor(): return
	_checkpoint_index = next
	_checkpoint = _vec3(points[next].pos)
	_snapshot = {"defeated":_defeated_ids.duplicate(),"collected":_collected_ids.duplicate(),"attack":_player.attack_charges,"defense":_player.defense_charges}
	_sfx.play("checkpoint")
	_hud.notify("Checkpoint %d de %d salvo" % [next+1,points.size()])
	get_tree().call_group("campaign_checkpoints","refresh_lit",_checkpoint_index)
func _respawn_at_checkpoint() -> void:
	if _checkpoint_index < 0:
		_restart_level()
		return
	_life_token += 1
	_resume()
	_respawning = false
	_build_queue.clear()
	_defeated_ids = (_snapshot.defeated as Dictionary).duplicate()
	_collected_ids = (_snapshot.collected as Dictionary).duplicate()
	_defeated = _defeated_ids.size()
	for chunk: Node in _loaded_chunks.values():
		_world.remove_child(chunk)
		chunk.queue_free()
	_loaded_chunks.clear()
	_player.is_dead = false
	_player.position = _checkpoint+Vector3.UP*0.05
	_player.velocity = Vector3.ZERO
	_player.facing = 1
	_player.setup(_find_protagonist())
	_player.attack_charges = int(_snapshot.attack)
	_player.defense_charges = int(_snapshot.defense)
	_player.inventory_changed.emit()
	_player._invulnerable = 1.5
	_player.set_physics_process(true)
	_touch_pad.set_process(true)
	_lead = 0.0
	_hud.clear_pulse()
	_hud._last_health = 3
	_stream_world(_player.position.x,true)
	_follow_camera(1.0)
	_sync_resources()
	_hud.notify("De volta ao checkpoint %d" % (_checkpoint_index+1))
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
	_checkpoint_index = -1
	_snapshot = {}
	_checkpoint = _vec3(_phase.player_spawn)
	_build_queue.clear()
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
	_lead = 0.0
	_hud.clear_pulse()
	_hud._last_health = 3
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
