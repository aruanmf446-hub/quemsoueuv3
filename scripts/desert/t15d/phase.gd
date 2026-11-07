extends "res://scripts/desert/phase_01.gd"
## Dez percursos noturnos modulares; modelos e movimentação originais preservados.
const ActorSlot = preload("res://scripts/desert/t15d/actor_slot.gd")
const Player = preload("res://scripts/desert/t15d/player.gd")
const Cactus = preload("res://scripts/desert/t15d/cactus.gd")
const Terrain = preload("res://scripts/desert/t15d/terrain.gd")
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
const Progress = preload("res://scripts/desert/t15d/campaign_progress.gd")
const Run=preload("res://scripts/desert/t15d/campaign_run.gd")
const Pickup = preload("res://scripts/desert/t15d/charge_pickup.gd")
const CHUNK_SIZE := 64.0
const AHEAD := 2
signal return_requested
var _boss: Node3D
var _order := 1
var _scenery: Node3D
var _session: CanvasLayer
var _hud: CanvasLayer
var _touch_pad: Control
var _reserve: Node3D
var _troops: Node3D
var _enemy_live := {}
var _wave_gates := {}
var _last_wave := -99.0
var _ruptured := {}
var _floor_parts := {}
var _raised_bridges := {}
var _task_steps: Dictionary={}
var _bridge_hints := {}
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
var _first_use: CanvasLayer
var _shield: Node3D
var _saved := false
var _handoff := false
var _advancing := false
var _actor_resources: Array[PackedScene] = []
var _lead := 0.0
var _build_queue: Array[Dictionary] = []
## Checkpoint ativo (-1 = início da fase) e o estado salvo ao passar por ele.
var _checkpoint_index := -1
var _snapshot := {}
var _sfx: Node
var _shake := 0.0
var _hit_stopping := false
var _environment: Environment
var _announced_place := false
var _key_light: OmniLight3D
var _save_owner:=""
var _run_id:=""
var _loaded_run: Dictionary={}
var _run_template: Dictionary={}
var _save_error:=false
var _safe_position:=Vector3.ZERO
var _run_ready:=false
var _save_clock:=0.0
var _cloud_clock:=0.0
func _ready() -> void:
	preload("res://scripts/desert/t15d/control_scheme.gd").load_saved(get_tree())
	add_to_group("campaign_control_consumers")
	_save_owner=OwnerStorage.owner_id()
	_loaded_run=Run.read(_save_owner).state
	_set_web_story_playing(true)
	_previous_go_back = bool(get_meta("previous_go_back",get_tree().quit_on_go_back))
	get_tree().quit_on_go_back = false
	_order = clampi(int(phase_path.get_file().get_basename().trim_prefix("phase_")),1,10)
	_ensure_input_actions()
	_phase = Layout.build(_order)
	_enemy_catalog = _read_json(ENEMIES_PATH).get("enemies",{})
	# Mantém fontes FBX em cache para não reler modelos ao trocar de trecho.
	var sources := {}
	for entry: Dictionary in [_find_protagonist(),_enemy_catalog.cactus]:
		sources[str(entry.model)] = true
		for source in entry.animations.values(): sources[str(source)] = true
	for source in sources: _actor_resources.append(load(source) as PackedScene)
	# Medalhões dos itens (SVG + anel) montados já, e não no meio da corrida.
	for kind in ["attack","defense","health","rupture","amber","dash"]: Pickup.Icons.medallion(kind,256,true,true)
	_checkpoint = _vec3(_phase.player_spawn)
	_sfx = preload("res://scripts/desert/t15d/combat_sfx.gd").new()
	_sfx.name = "CombatSfx"
	add_child(_sfx)
	_build_environment()
	_troops = Node3D.new()
	_troops.name = "PersistentTroops"
	add_child(_troops)
	_reserve = Node3D.new()
	_reserve.name = "TroopReserve"
	_reserve.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_reserve)
	for index in range(8):
		var enemy := _create_enemy()
		enemy.setup(_enemy_catalog.cactus,{"patrol":[-2,2]})
		_retire_enemy(enemy)
	for pair in [["rupture",KEY_Q],["amber",KEY_E],["dash",KEY_R]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var key := InputEventKey.new()
			key.physical_keycode = pair[1]
			InputMap.action_add_event(pair[0],key)
	_world = Node3D.new()
	_world.name = "StreamedCity"
	add_child(_world)
	_build_player()
	_restore_game_checkpoint()
	_build_goal()
	_stream_world(_player.position.x,true)
	_build_camera()
	_build_hud()
	_first_use=preload("res://scripts/desert/t15d/first_use_tutorial.gd").new()
	add_child(_first_use)
	if not _loaded_run.is_empty():_first_use.import_seen(_loaded_run.get("lessons",[]))
	_restore_ability_buttons()
	_sync_resources()
	_player.controls.reset()
	_first_use.opened.connect(func(_kind: String) -> void:
		_release_input()
		_player._model.visible=true)
	_first_use.closed.connect(func(_kind: String) -> void:
		_release_input()
		_save_active_run())
	_safe_position=_player.position
	_run_ready=true
	_save_active_run(false,"start" if _loaded_run.is_empty() else "save")
	_sync_run_cloud()
	if _order==1:_first_use.present.call_deferred("attack")
func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player): return
	if not completed and not _respawning:
		_elapsed += delta
		if _player.position.y < float(_phase.kill_plane_y): _player.fall_out()
		_stream_world(_player.position.x)
		_update_troops()
		_update_progress()
		_check_checkpoints()
		_update_storm()
		_update_bridge_hint()
		if _player.is_on_floor():
			var floor:=Layout.floor_at(_phase,_player.position.x)
			var stable: bool=not floor.is_empty()
			for task: Dictionary in _phase.tasks:
				if _raised_bridges.has(str(task.id)) and _player.position.x>=float(task.start) and _player.position.x<=float(task.end):stable=true
			if stable:_safe_position=_player.position
		_save_clock+=delta
		_cloud_clock+=delta
		if _save_clock>=2.0:
			_save_clock=0.0
			_save_active_run()
		if _cloud_clock>=15.0:
			_cloud_clock=0.0
			_sync_run_cloud()
		if not _tutorial_pit and _player.position.x > float(_phase.holes[0].start)-12.0:
			_tutorial_pit = true
			_hud.notify("Buraco à frente • pule para atravessar")
	for id in _ruptured.keys():
		_ruptured[id] -= delta
		if float(_ruptured[id]) <= 0.0:
			var occupied := false
			for node in _floor_parts.get(id,[]):
				if is_instance_valid(node) and node is StaticBody3D:
					if _player.position.x > float(node.get_meta("floor_left"))-0.7 and _player.position.x < float(node.get_meta("floor_right"))+0.7 and _player.position.y < float(node.get_meta("floor_top",0.0))+0.5: occupied = true
			if occupied: continue
			_ruptured.erase(id)
			_set_floor_broken(id,false)
	_follow_camera(delta)
	_key_light.position = _player.position+Vector3(0.0,1.5,1.8)
	_shield.active = _player.is_defending and not _player.is_dead
	_shield.facing = _player.facing
	_shield.position = _player.position
func _ensure_input_actions() -> void:
	super._ensure_input_actions()
	# O protótipo legado mapeava J e K para ataque. Na campanha K é defesa.
	for event in InputMap.action_get_events("attack"):
		if event is InputEventKey and (event.physical_keycode==KEY_K or event.keycode==KEY_K):InputMap.action_erase_event("attack",event)
	var defense:=InputEventKey.new()
	defense.physical_keycode=KEY_K
	if not InputMap.action_has_event("defend",defense):InputMap.action_add_event("defend",defense)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	var environment := world_environment.environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#091627")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#819ecb")
	environment.ambient_light_energy = 0.40 if _order == 10 else 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world_environment)
	_environment = environment
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-40,-30,0)
	moon.light_color = Color("#aac8f3")
	moon.light_energy = 0.12 if _order == 10 else 0.72
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
	_scenery.location_changed.connect(_on_location_changed)
	# Luz de contorno fria vinda de trás: recorta personagens e Cactus do fundo iluminado.
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.rotation_degrees = Vector3(-18,165,0)
	rim.light_color = Color("#8fb4ff")
	rim.light_energy = 0.9
	rim.light_specular = 0.6
	add_child(rim)
	# Antisserrilhado: 4× no computador (incluindo Web), 2× em telas compactas.
	get_viewport().msaa_3d = Viewport.MSAA_2X if UIScale.is_handheld() else Viewport.MSAA_4X
## Tempestade de areia: tela tingida, grãos voando e vento contra quem vai para a direita.
var _in_storm := false
func _update_storm() -> void:
	var inside := false
	for storm: Dictionary in _phase.get("storms",[]):
		if _player.position.x >= float(storm.start) and _player.position.x <= float(storm.end): inside = true
	if inside == _in_storm: return
	_in_storm = inside
	_player.wind = -0.8 if inside else 0.0
	_hud.set_storm(inside)
	_hud.notify("Tempestade de areia • vento contra" if inside else "A tempestade passou",inside)
## Mudou de lugar: a luz ambiente acompanha a cor do novo cenário e o nome aparece.
func _on_location_changed(place: Dictionary) -> void:
	if is_instance_valid(_environment):
		create_tween().tween_property(_environment,"ambient_light_color",place.ambient,1.2)
	if _announced_place and is_instance_valid(_hud): _hud.announce_place(str(place.name))
	_announced_place = true
func _build_player() -> void:
	_player = Player.new()
	_player.name = "ElFuego"
	_player.position = _vec3(_phase.player_spawn)
	var model := ActorSlot.new()
	model.name = "Model"
	model.position.y=-0.06
	_player.add_child(model)
	add_child(_player)
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_player.strike_landed.connect(_impact)
	_player.inventory_changed.connect(_sync_resources)
	_player.swung.connect(func() -> void: _sfx.play("swing"))
	_player.jumped_up.connect(func() -> void:
		var double_jump:=_player.jumps_used>=2
		_sfx.play("double_jump" if double_jump else "jump",1.0,-6.0)
		if double_jump:
			var dust:=preload("res://scripts/desert/t15d/sand_fx.gd").DoubleJumpDust.new()
			var feet:=_player.global_position+Vector3.UP*0.12
			var skeleton: Skeleton3D=_player._model._skeleton
			if is_instance_valid(skeleton):
				var points: Array[Vector3]=[]
				for name in ["mixamorig_LeftFoot","mixamorig_RightFoot"]:
					var bone:=skeleton.find_bone(name)
					if bone>=0:points.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin)
				if points.size()==2:feet=(points[0]+points[1])*0.5
			dust.position=to_local(feet)
			add_child(dust))
	_player.stepped.connect(func() -> void:
		var cue:="step"
		for i in _player.get_slide_collision_count():
			var body:=_player.get_slide_collision(i).get_collider()
			if not body is Node:continue
			if body.get_meta("canopy",false):cue="step_soft"
			elif (body.get_meta("parkour_route",false) and _order in [5,7,9]) or (body.name=="EarthDeck" and _order not in [4,6]) or (body.is_in_group("crumble_stones") and body.timber):cue="step_wood"
		_sfx.play(cue,1.0,-9.0))
	_player.landed.connect(func() -> void: _sfx.play("land",1.0,-8.0))
	_player.hurt.connect(func() -> void: _sfx.play("hurt"))
	_player.strike_landed.connect(func(_point: Vector3) -> void:
		_sfx.play("hit")
		_hit_stop(0.05)
		_shake = 0.1)
	_player.hurt.connect(func() -> void: _shake = 0.14)
	_player.blocked.connect(func() -> void: _sfx.play("block"))
	_player.action_empty.connect(func(_kind: String) -> void: _sfx.play("empty",1.0,-5.0))
	_player.action_empty.connect(func(kind: String) -> void:
		if is_instance_valid(_hud): _hud.notify(str(TranslationServer.translate("Sem carga de %s • procure uma recarga")) % {"attack":"fogo","defense":"defesa","rupture":"ruptura","amber":"âmbar","dash":"relâmpago"}.get(kind,kind),true))
	_player.blocked.connect(func() -> void: _impact(_player.position+Vector3(_player.facing*0.45,0.9,0),Color("#9cdeff")))
	_player.ability_used.connect(_on_ability_used)
	_player.setup(_find_protagonist())
	_apply_starting_resources(true)
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
func _apply_starting_resources(use_carry:=false) -> void:
	if _order==1:
		_player.attack_charges=0
		_player.defense_charges=0
	# O arquivo antigo misturava descoberta por coleta com concessões automáticas.
	# O tutorial por perfil agora é a fonte da apresentação, sem apagar progresso.
	for ability: String in Layout.ABILITY_PHASE:
		_player.abilities[ability]=0
	if use_carry:
		var carry: Dictionary=get_meta("carry_charges",Progress.carry_for(_order,OwnerStorage.owner_id()))
		if not carry.is_empty():
			_player.attack_charges=clampi(int(carry.get("attack",0)),0,3)
			_player.defense_charges=clampi(int(carry.get("defense",0)),0,3)
			for ability: String in Layout.ABILITY_PHASE:
				if _order>=int(Layout.ABILITY_PHASE[ability]):_player.abilities[ability]=clampi(int(carry.get(ability,0)),0,3)
	_restore_ability_buttons()
func _restore_ability_buttons() -> void:
	for ability: String in Layout.ABILITY_PHASE:
		_player.discovered.erase(ability)
		if _order>=int(Layout.ABILITY_PHASE[ability]) and is_instance_valid(_first_use) and (_first_use.seen(ability) or _player.charges(ability)>0):
			_player.discovered[ability]=true
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
	# Só a entrada/reinício monta o entorno imediato de uma vez. O restante sempre
	# usa a fila, inclusive ao voltar pelo mapa; colisores continuam imediatos.
	var order: Array = wanted.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return absi(a-center) < absi(b-center))
	for index in order:
		if not _loaded_chunks.has(index): _load_chunk(index,force and absi(index-center) <= 1)
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
	var solid := platforms.filter(func(p: Dictionary) -> bool: return p.kind != "crumble")
	_build_collision(chunk,solid)
	for platform: Dictionary in platforms:
		if platform.kind == "crumble": _build_crumble(chunk,platform)
	if not solid.is_empty():
		for platform: Dictionary in solid:
			tasks.append(_build_terrain_piece.bind(chunk,platform))
		var props := preload("res://scripts/desert/t15d/city_props.gd").new()
		chunk.add_child(props)
		for job: Callable in props.prepare_build(solid,_order,float(_phase.length),float(_phase.player_spawn[0])):
			tasks.append(_build_props_piece.bind(chunk,job))
	for spawn: Dictionary in _phase.enemies:
		if _in_chunk(float(spawn.pos[0]),index) and not _defeated_ids.has(str(spawn.id)):
			tasks.append(_spawn_enemy.bind(chunk,spawn))
	tasks.append(_build_chunk_details.bind(chunk,index))
	for task in tasks:
		if immediate: task.call()
		else: _build_queue.append({"chunk_id":chunk.get_instance_id(),"task":task})
func _process(_delta: float) -> void:
	# Uma etapa por quadro (mais etapas só enquanto o quadro gastou menos de 1ms).
	var started := Time.get_ticks_usec()
	while not _build_queue.is_empty() and Time.get_ticks_usec()-started < 1000:
		var pending: Dictionary = _build_queue.pop_front()
		var chunk := instance_from_id(int(pending.chunk_id)) as Node
		if is_instance_valid(chunk) and chunk.is_inside_tree():
			var task: Callable = pending.task
			if task.is_valid(): task.call()
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
		var body:=StaticBody3D.new()
		body.collision_layer = 1
		body.position = _vec3(part.pos)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var dimensions := _vec3(part.size)
		if part.kind == "ground":
			dimensions.y = 1.0
			body.position.y = float(part.pos[1])
		if part.get("parkour_route",false):
			# Arcadas, balcões, troncos e cargas ocupam todo o volume até o chão.
			# A colisão antiga era só uma tampa atravessável: o jogador entrava na arte.
			var top:=body.position.y+dimensions.y*0.5
			var floor_top:=float(part.surface_top)
			dimensions.y=top-floor_top
			body.position.y=(top+floor_top)*0.5
			body.name="SolidRunningObstacle"
			body.set_meta("parkour_route",true)
			body.set_meta("obstacle_top",top)
			body.set_meta("obstacle_floor",floor_top)
			body.set_meta("obstacle_id",str(part.id))
			body.set_meta("obstacle_span",Vector2(body.position.x-dimensions.x*0.5,body.position.x+dimensions.x*0.5))
			body.add_to_group("campaign_solid_obstacles")
		box.size = dimensions
		shape.shape = box
		body.add_child(shape)
		if part.kind=="ground": body.set_meta("walkable_floor",true)
		chunk.add_child(body)
		if part.get("breakable",false):
			var id := str(part.id)
			if not _floor_parts.has(id): _floor_parts[id] = []
			_floor_parts[id].append(body)
			body.set_meta("floor_right",float(part.span_end))
			body.set_meta("floor_left",float(part.span_start))
			body.set_meta("floor_top",float(part.pos[1])+0.5)
			if _ruptured.has(id): body.collision_layer = 0
func _build_crumble(chunk: Node3D, platform: Dictionary) -> void:
	var stone := preload("res://scripts/desert/t15d/parkour.gd").CrumbleStone.new()
	stone.position = _vec3(platform.pos)
	stone.stone_size = _vec3(platform.size)
	stone.crumbled.connect(func() -> void: _sfx.play("land",0.6,-2.0))
	chunk.add_child(stone)
func _build_terrain_piece(chunk: Node3D, platform: Dictionary) -> void:
	var terrain := preload("res://scripts/desert/t15d/modular_architecture.gd").new()
	chunk.add_child(terrain)
	terrain.build_surface(platform,_order)
	if platform.get("breakable",false):
		var id := str(platform.id)
		if not _floor_parts.has(id): _floor_parts[id] = []
		_floor_parts[id].append(terrain)
		terrain.visible = not _ruptured.has(id)
func _build_props_piece(_chunk: Node3D, job: Callable) -> void:
	if job.is_valid(): job.call()
func _build_props(chunk: Node3D, platforms: Array) -> void:
	var props := preload("res://scripts/desert/t15d/city_props.gd").new()
	chunk.add_child(props)
	props.build(platforms,_order)
func _build_chunk_details(chunk: Node3D, index: int) -> void:
	var left := index*CHUNK_SIZE
	var right := left+CHUNK_SIZE
	for spawn: Dictionary in _phase.pickups:
		if _in_chunk(float(spawn.pos[0]),index):
			# Uma base por estação, inclusive ao revisitar um trecho já coletado.
			var pedestal := Pickup.create_pedestal(str(spawn.kind),_order,_collected_ids.has(str(spawn.id)))
			pedestal.name = "RechargePedestal"
			pedestal.position += _vec3(spawn.pos)
			pedestal.set_meta("pickup_id",str(spawn.id))
			pedestal.add_to_group("campaign_pedestals")
			chunk.add_child(pedestal)
			if _collected_ids.has(str(spawn.id)): continue
			var item := Pickup.new()
			item.pickup_id = str(spawn.id)
			item.kind = str(spawn.kind)
			item.position = _vec3(spawn.pos)
			item.collected.connect(_on_pickup_collected)
			item.full_touched.connect(func(kind: String) -> void:
				if is_instance_valid(_hud): _hud.notify({"attack":"Ataque cheio","defense":"Defesa cheia","health":"Vida cheia"}.get(kind,"Cheio")+" • item preservado"))
			chunk.add_child(item)
	for hole: Dictionary in _phase.holes:
		var middle := (float(hole.start)+float(hole.end))*0.5
		if _in_chunk(middle,index):
			if hole.get("crumble_bridge",false):
				var bridge := preload("res://scripts/desert/t15d/parkour.gd").CrumbleStone.new()
				bridge.name = "CrumblingBridge"
				bridge.timber = true
				bridge.delay = 0.85
				bridge.stone_size = Vector3(float(hole.width)+0.12,0.22,3.8)
				bridge.position = Vector3(middle,minf(float(hole.from_y),float(hole.to_y))-0.11,0)
				chunk.add_child(bridge)
		if hole.get("ferry",false) and _in_chunk(middle,index):
			var ferry := preload("res://scripts/desert/t15d/parkour.gd").Ferry.new()
			ferry.from_x = float(hole.start)+1.9
			ferry.to_x = float(hole.end)-1.9
			chunk.add_child(ferry)
	for task: Dictionary in _phase.get("tasks",[]):
		if _in_chunk((float(task.start)+float(task.end))*0.5,index):
			var device := preload("res://scripts/desert/t15d/earth_bridge.gd").new()
			device.configure(task)
			chunk.add_child(device)
			device.set_progress(int(_task_steps.get(str(task.id),0)))
			if _raised_bridges.has(str(task.id)): device.raise_bridge(false)
	for geyser: Dictionary in _phase.get("geysers",[]):
		if _in_chunk(float(geyser.pos[0]),index):
			var pad := preload("res://scripts/desert/t15d/parkour.gd").Geyser.new()
			pad.position = _vec3(geyser.pos)
			pad.launched.connect(func() -> void: _sfx.play("jump",0.7,-2.0))
			chunk.add_child(pad)
	var points: Array = _phase.get("checkpoints",[])
	for point_index in range(points.size()):
		if _in_chunk(float(points[point_index].pos[0]),index):
			var marker := preload("res://scripts/desert/t15d/checkpoint_banner.gd").new()
			marker.index = point_index
			marker.position = _vec3(points[point_index].pos)+Vector3(-0.9,0,-1.6)
			chunk.add_child(marker)
			marker.refresh_lit(_checkpoint_index)
	for hole: Dictionary in _phase.holes:
		var x0 := maxf(float(hole.start),left)
		var x1 := minf(float(hole.end),right)
		for edge in [float(hole.start),float(hole.end)]:
			if _order!=2 and _in_chunk(edge,index): _build_pit_lip(chunk,edge,edge == float(hole.start))
func _in_chunk(x: float, index: int) -> bool:
	return floori(x/CHUNK_SIZE) == index
func _near_bridge(hole: Dictionary, distance := 4.0) -> bool:
	var x := _player.position.x
	return (absf(x-float(hole.start))<distance and absf(_player.position.y-float(hole.from_y))<0.7) or (absf(x-float(hole.end))<distance and absf(_player.position.y-float(hole.to_y))<0.7)
func _near_task_action(device: Node3D) -> bool:
	var step:=int(_task_steps.get(str(device.hole.id),0))
	for right in [false,true]:
		var point: Vector3=device.action_point(step,right)
		var reach:=0.45 if right and str(device.hole.get("task_kind",""))=="gate" else 1.25
		if absf(_player.position.x-point.x)<reach and absf(_player.position.y-point.y)<0.7:return true
	return false
func _update_bridge_hint() -> void:
	var task_available := false
	var caption := ""
	for hole: Dictionary in _phase.holes:
		if hole.get("crumble_bridge",false) and _near_bridge(hole,6.0) and not _bridge_hints.has(str(hole.id)):
			_bridge_hints[str(hole.id)] = true
			_hud.notify("Ponte frágil • atravesse antes que desabe; ela se recompõe")
	for device in get_tree().get_nodes_in_group("earth_bridges"):
		if is_ancestor_of(device) and not device.raised and _near_task_action(device) and _player.is_on_floor():
			task_available=true
			var actions: Array=device.hole.get("actions",[device.hole.get("task_text","Montar ponte")])
			var step:=mini(int(_task_steps.get(str(device.hole.id),0)),actions.size()-1)
			caption=tr(str(actions[step]))+(" (%d/%d)" % [step+1,actions.size()] if actions.size()>1 else "")+" · F"
			break
	_hud.set_bridge_task(task_available and not _player.is_dead and not completed,caption)
	if task_available and _order==1 and is_instance_valid(_first_use) and not _first_use.seen("task"):
		_first_use.present.call_deferred("task","Nesta passagem: "+caption.trim_suffix(" · F")+".")
func _raise_earth_bridge() -> void:
	if _player.is_dead or not _player.is_on_floor() or completed or _paused: return
	for bridge in get_tree().get_nodes_in_group("earth_bridges"):
		if not is_ancestor_of(bridge) or bridge.raised or not _near_task_action(bridge): continue
		var id:=str(bridge.hole.id)
		var actions: Array=bridge.hole.get("actions",[bridge.hole.get("task_text","Montar ponte")])
		var step:=int(_task_steps.get(id,0))
		if step<actions.size()-1:
			_task_steps[id]=step+1
			bridge.set_progress(step+1)
			_hud.set_bridge_task(false)
			_hud.notify(tr("%s • siga para o ponto iluminado") % tr(str(actions[step])))
			_save_active_run()
			return
		# Montagem dura 0,8s: impede correr no vazio antes de a peça virar piso.
		var life := _life_token
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(false)
		bridge.assembled.connect(func() -> void:
			if life == _life_token and not _player.is_dead: _player.set_physics_process(true),CONNECT_ONE_SHOT)
		bridge.raise_bridge()
		_task_steps[id]=actions.size()
		_raised_bridges[str(bridge.hole.id)] = true
		_save_active_run()
		_hud.set_bridge_task(false)
		_hud.notify("Tarefa concluída • passagem liberada")
		return
func _is_pit_edge(x: float, left: bool) -> bool:
	for hole: Dictionary in _phase.holes:
		if absf(x-float(hole.end if left else hole.start)) < 0.02: return true
	return false
func _is_exposed_edge(x: float, left: bool, kind: String) -> bool:
	if kind != "ground": return true
	return _is_pit_edge(x,left) or absf(x-float(_phase.bounds.min_x if left else _phase.bounds.max_x))<0.02
func _create_enemy() -> Node3D:
	var enemy := Cactus.new()
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
	_reserve.add_child(enemy)
	enemy.winding_up.connect(func() -> void: _sfx.play("windup",0.9,-4.0))
	enemy.alerted.connect(func() -> void: _sfx.play("windup",1.45,-7.0))
	enemy.retired.connect(_retire_enemy)
	enemy.defeated.connect(func() -> void:
		_defeated_ids[str(enemy.get_meta("spawn_id",""))] = true
		_defeated = _defeated_ids.size())
	return enemy

func _spawn_enemy(_chunk: Node3D, spawn: Dictionary) -> void:
	var id := str(spawn.id)
	if not spawn.get("troop",false) and absf(float(spawn.pos[0])-_player.position.x) > 50.0: return
	if is_instance_valid(_enemy_live.get(id)) or _troops.get_child_count() >= 8 or _reserve.get_child_count() == 0: return
	var enemy := _reserve.get_child(0) as Cactus
	enemy.reparent(_troops,false)
	enemy.position = _vec3(spawn.pos)
	enemy.set_meta("spawn_id",id)
	_enemy_live[id] = enemy
	enemy.persistent_follow = bool(spawn.get("troop",false))
	var encounter := spawn.duplicate(true)
	encounter.challenger=_order<10
	if not str(encounter.get("spear_supply","")).is_empty():
		encounter.spear_enabled=_collected_ids.has(str(encounter.spear_supply))
	enemy.setup(_enemy_catalog.cactus,encounter)
	enemy.add_to_group("enemies")
	enemy.show()
	enemy.set_physics_process(true)

func _retire_enemy(enemy: Node3D) -> void:
	if is_instance_valid(enemy._spear_guard):enemy._spear_guard.shutdown()
	_enemy_live.erase(str(enemy.get_meta("spawn_id","")))
	enemy.remove_from_group("enemies")
	enemy.set_physics_process(false)
	enemy.collision_layer = 0
	enemy.hide()
	if enemy.get_parent() != _reserve: enemy.reparent(_reserve,false)

## Borda de perigo: friso âmbar no lábio do piso e faixa marcada antes do vão.
func _build_pit_lip(chunk: Node3D, x: float, left_edge: bool) -> void:
	var inward := -1.0 if left_edge else 1.0
	var lip := MeshInstance3D.new()
	lip.name = "PitLip"
	var strip := BoxMesh.new()
	strip.size = Vector3(0.07,0.06,4.1)
	lip.mesh = strip
	var floor_top := 0.0
	for hole: Dictionary in _phase.holes:
		if absf(float(hole.start)-x)<0.02: floor_top = float(hole.from_y)
		if absf(float(hole.end)-x)<0.02: floor_top = float(hole.to_y)
	lip.position = Vector3(x+inward*0.035,floor_top,0.0)
	lip.set_meta("pit_edge",x)
	lip.material_override = _pit_material("lip")
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.add_child(lip)
	var band := MeshInstance3D.new()
	band.name = "PitBand"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9,3.9)
	band.mesh = plane
	band.position = Vector3(x+inward*0.57,floor_top+0.012,0.0)
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
	for enemy in _troops.get_children():
		if is_instance_valid(enemy._spear_guard):enemy._spear_guard.enable_for(id)
	_collected_ids[id] = true
	for pedestal: MeshInstance3D in get_tree().get_nodes_in_group("campaign_pedestals"):
		if is_ancestor_of(pedestal) and str(pedestal.get_meta("pickup_id",""))==id:
			Pickup.mark_pedestal_spent(pedestal)
	if _order==1 and kind=="defense" and is_instance_valid(_first_use):
		_first_use.present.call_deferred("defense")
	if Layout.ABILITY_PHASE.has(kind) and is_instance_valid(_first_use):
		_first_use.present.call_deferred(kind)
	_sfx.play("pickup",1.0 if kind == "attack" else 1.25)
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
	if _order in [8,9,10]:
		var portal := preload("res://scripts/desert/t15d/modular_architecture.gd").new()
		add_child(portal)
		portal.build_portal(Vector3(float(_phase.goal.pos[0]),float(_phase.goal.pos[1])-1.5,-4.0),_order)
	else:
		arch.arch(Vector3(float(_phase.goal.pos[0]),float(_phase.goal.pos[1])-1.5,-1.8),1.8)
	if _order == 1:
		var entrance := preload("res://scripts/desert/t15d/modular_architecture.gd").new()
		add_child(entrance)
		entrance.build_portal(Vector3(float(_phase.player_spawn[0])+1.0,float(_phase.player_spawn[1])-0.1,-5.0),1)
	var label := Label3D.new()
	label.text = "MINERADORA" if _order == 9 else ("FIM DO REINO" if _order == 10 else "SAÍDA")
	label.font = preload("res://assets/desert/phase01/interface.ttf")
	label.font_size = 48
	label.pixel_size = 0.007
	label.modulate = Color("#e5c58b")
	label.outline_modulate = Color("#081523")
	label.outline_size = 10
	# Acima do arco e sem teste de profundidade: antes as colunas cortavam o texto.
	label.no_depth_test = true
	label.position = Vector3(float(_phase.goal.pos[0]),float(_phase.goal.pos[1])+2.65,-1.0)
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
	_warm_pickup_shaders()
## O primeiro desenho do medalhão e do halo dos itens compila os shaders deles (um engasgo
## de dezenas de ms). Desenha uma cópia minúscula à frente da câmera por 3 quadros, já na
## entrada da fase, e não no meio da corrida.
func _warm_pickup_shaders() -> void:
	var warm := Node3D.new()
	warm.position = Vector3(0, 0, -5)
	warm.scale = Vector3.ONE*0.01
	var halo := MeshInstance3D.new()
	halo.mesh = QuadMesh.new()
	halo.material_override = Pickup._halo_material(Color.WHITE)
	warm.add_child(halo)
	var medal := Sprite3D.new()
	medal.texture = Pickup.Icons.medallion("attack",256,true,true)
	medal.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	medal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	warm.add_child(medal)
	_camera.add_child(warm)
	# Callback pertence ao objeto aquecido: sair da fase cancela a conexão sem
	# retomar uma coroutine cujo dono já foi liberado.
	get_tree().create_timer(0.1,true).timeout.connect(warm.queue_free)
func _follow_camera(delta: float) -> void:
	# Telas baixas (844×390) aproximam mais: o personagem não pode virar um ícone.
	_camera.size = 6.0 if UIScale.is_iphone() else 7.0
	# Antecipação maior na direção da corrida: o próximo vão entra no quadro mais cedo.
	_lead = move_toward(_lead,clampf(_player.velocity.x/6.0,-1.0,1.0)*2.4,delta*4.0)
	var lead := _lead
	# Em telas baixas o chão sobe no quadro (~60%): os botões de toque ficam sobre a
	# parede do terreno, não sobre a borda dos buracos à frente.
	var base := float(_phase.player_spawn[1])-0.1
	var support := Layout.floor_at(_phase,_player.position.x)
	if not support.is_empty(): base = float(support.height)
	var floor_y := base+(0.75 if UIScale.is_iphone() else 1.65)
	# Mostrar fachadas e arcos sob a rota, mantendo antecipação e acompanhamento do salto.
	if _order in [2,4,7]: floor_y=base+(0.20 if UIScale.is_iphone() else 0.50)
	var target := Vector3(clampf(_player.position.x+lead,float(_phase.player_spawn[0]),float(_phase.goal.pos[0])),maxf(floor_y,_player.position.y+1.4-_camera.size*0.5+0.55),0)
	# Só a fase 2 inclina mais para revelar a superfície dos telhados; mira e alcance iguais.
	var camera_drop := 2.2 if _order == 2 else 1.0
	var destination := target+Vector3(0,camera_drop,14)
	_camera.position = _camera.position.lerp(destination,1.0-exp(-8*delta))
	# Tremida curta no golpe e no dano; some em ~0,1s.
	if _shake > 0.0:
		_shake = maxf(_shake-delta,0.0)
		var amount := _shake*0.6
		_camera.position += Vector3(randf_range(-amount,amount),randf_range(-amount,amount),0)
	_camera.look_at(Vector3(_camera.position.x,_camera.position.y-camera_drop,0),Vector3.UP)
	_scenery.follow(_camera,_player.position.x)
func _build_hud() -> void:
	_hud = preload("res://scripts/desert/t15d/campaign_hud.gd").new()
	_hud.configure(_phase)
	add_child(_hud)
	_hud.pause_requested.connect(_pause)
	_hud.bridge_requested.connect(_raise_earth_bridge)
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
		_advance(str(_phase.next_scene)))
	_session.return_requested.connect(_return_to_story)
	_sync_resources()
func apply_control_scheme() -> void:
	if not is_instance_valid(_player):return
	_release_input()
	_player._jump_buffer=0.0
	_player._attack_buffer=0.0
	_player._defend_buffer=0.0
	if is_instance_valid(_touch_pad):
		_touch_pad.visible=_touch_pad._wanted()
		_touch_pad.queue_redraw()
	if is_instance_valid(_hud):_hud.apply_control_scheme()
func _sync_resources() -> void:
	if is_instance_valid(_hud): _hud.update_resources(_player)
	if _run_ready:_save_active_run.call_deferred()
func _on_player_health_changed(_current: int, _maximum: int) -> void:
	_sync_resources()
func _update_progress() -> void:
	var share := clampf((_player.position.x-float(_phase.player_spawn[0]))/float(_phase.length),0,1)
	var district := mini(int(share*8),7)
	_hud.update_progress(share,_elapsed,str(_phase.districts[district].name))
## Pausa de impacto: o mundo congela ~3 quadros quando o soco acerta (dá peso ao golpe).
## Usa time_scale e um temporizador que ignora a escala, então nunca fica preso.
func _hit_stop(seconds: float) -> void:
	if _hit_stopping or get_tree().paused: return
	_hit_stopping = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds,true,false,true).timeout
	Engine.time_scale = 1.0
	_hit_stopping = false
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
	for task: Dictionary in _phase.get("tasks",[]):
		if not _raised_bridges.has(str(task.id)):
			_hud.notify(tr("Falta concluir: %s") % tr(str(task.task_text)),true)
			return
	if _order == 10 and not _boss_defeated:
		_hud.notify("Derrote Malagueta para concluir a travessia",true)
		return
	completed = true
	_saved = Progress.complete(_order) == OK
	if _order<10:Progress.store_carry(_order+1,_charge_snapshot(),OwnerStorage.owner_id())
	if _order<10:
		var next_run:=Run.fresh(_order+1,_charge_snapshot())
		next_run.lessons=_learned_lessons()
		Run.save(_save_owner,next_run,"start")
	_sync_run_cloud()
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_player._model.play_animation("pronto",true)
	_release_input()
	_player.cancel_dash()
	_touch_pad.hide()
	_touch_pad.set_process(false)
	_hud.set_completed(true)
	_hud.update_progress(1.0,_elapsed,"Concluída")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(enemy): enemy.set_physics_process(false)
	_session.show_completion(_defeated,_elapsed,_saved)
func _release_input() -> void:
	if is_instance_valid(_touch_pad): _touch_pad.release_all()
	for action in ["move_left","move_right","jump","attack","defend","crouch","rupture","amber","dash"]: Input.action_release(action)
	if is_instance_valid(_player):_player.controls.reset()
func _pause() -> void:
	if is_instance_valid(_first_use) and _first_use.active:return
	if completed or _paused or _respawning: return
	_save_active_run()
	_sync_run_cloud()
	_release_input()
	_player.cancel_dash()
	_touch_pad.hide()
	_paused = true
	_session.show_pause()
	get_tree().paused = true
func _resume() -> void:
	if is_instance_valid(_session) and _session.operation_busy: return
	get_tree().paused = false
	_paused = false
	_release_input()
	_session.close()
	_touch_pad._last_pixels = Vector2i.ZERO
	get_viewport().gui_release_focus()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F and preload("res://scripts/desert/t15d/control_scheme.gd").keyboard_enabled():
		_raise_earth_bridge()
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
	_save_active_run(true)
	_sync_run_cloud()
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
## Checkpoints: ao passar pelo marcador de um distrito, guarda posição, cargas, Cactus
## derrotados e itens coletados. Voltar a ele restaura esse estado com 1 vida e sem cargas.
func _check_checkpoints() -> void:
	var points: Array = _phase.get("checkpoints",[])
	var next := _checkpoint_index+1
	if next >= points.size() or _player.is_dead: return
	if _player.position.x < float(points[next].pos[0]) or not _player.is_on_floor(): return
	_checkpoint_index = next
	_checkpoint = _vec3(points[next].pos)
	_snapshot = {"defeated":_defeated_ids.duplicate(),"collected":_collected_ids.duplicate(),"attack":_player.attack_charges,"defense":_player.defense_charges,"tasks":_raised_bridges.duplicate(),"task_steps":_task_steps.duplicate()}
	_save_active_run()
	_sfx.play("checkpoint")
	if not _save_error:_hud.notify(tr("Checkpoint %d/%d salvo") % [next+1,points.size()])
	get_tree().call_group("campaign_checkpoints","refresh_lit",_checkpoint_index)
	if PlayerServices.current != null and PlayerServices.current.session.authenticated():
		_sync_game_checkpoint(_checkpoint_index)
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
	_reset_remaster_state()
	_raised_bridges=(_snapshot.get("tasks",{}) as Dictionary).duplicate()
	_task_steps=(_snapshot.get("task_steps",{}) as Dictionary).duplicate()
	for chunk: Node in _loaded_chunks.values():
		_world.remove_child(chunk)
		chunk.queue_free()
	_loaded_chunks.clear()
	_player.is_dead = false
	_player.position = _checkpoint+Vector3.UP*0.05
	_player.velocity = Vector3.ZERO
	_player.facing = 1
	_player.setup(_find_protagonist())
	# Penalidade do checkpoint: volta com 1 vida e sem cargas de ataque/defesa.
	_apply_starting_resources()
	_player.health = 1
	_player.health_changed.emit(_player.health,_player.RUN_MAX_HEALTH)
	_player.attack_charges = 0
	_player.defense_charges = 0
	_player.inventory_changed.emit()
	_player._invulnerable = 1.5
	_player.set_physics_process(true)
	_touch_pad.set_process(true)
	_lead = 0.0
	_hud.clear_pulse()
	_hud._last_health = 1
	_stream_world(_player.position.x,true)
	_follow_camera(1.0)
	_sync_resources()
	_hud.notify("De volta ao checkpoint %d" % (_checkpoint_index+1))
	_safe_position=_player.position
	_save_active_run()
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
	_run_id=PlayerContracts.uuid()
	_loaded_run={}
	_in_storm = false
	_player.wind = 0.0
	_hud.set_storm(false)
	_checkpoint = _vec3(_phase.player_spawn)
	_build_queue.clear()
	_reset_remaster_state()
	for chunk: Node in _loaded_chunks.values():
		_world.remove_child(chunk)
		chunk.queue_free()
	_loaded_chunks.clear()
	_player.is_dead = false
	_player.position = _vec3(_phase.player_spawn)
	_player.velocity = Vector3.ZERO
	_player.facing = 1
	_player.setup(_find_protagonist())
	_apply_starting_resources()
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
	_safe_position=_player.position
	_save_active_run(false,"start")
func _charge_snapshot() -> Dictionary:
	return {"attack":_player.attack_charges,"defense":_player.defense_charges,"amber":_player.charges("amber"),"dash":_player.charges("dash"),"rupture":_player.charges("rupture")}
static func _id_set(ids: Array) -> Dictionary:
	var result: Dictionary={}
	for id: Variant in ids:result[str(id)]=true
	return result
func _learned_lessons() -> Array:
	var result: Array=[]
	if is_instance_valid(_first_use):
		for kind: String in ["attack","defense","task","amber","dash","rupture"]:
			if _first_use.seen(kind):result.append(kind)
	return result
func _save_active_run(death:=false,intent:="save") -> void:
	if not _run_ready or completed or not is_instance_valid(_player) or (_player.is_dead and not death):return
	var state:=_run_template.duplicate(true)
	state.run_id=_run_id
	state.checkpoint=_checkpoint_index
	state.position=[_safe_position.x,_safe_position.y]
	state.health=_player.health
	state.charges=_charge_snapshot()
	state.defeated=_defeated_ids.keys()
	state.collected=_collected_ids.keys()
	state.tasks=_raised_bridges.keys()
	state.task_steps=_task_steps.duplicate()
	state.elapsed=_elapsed
	state.lessons=_learned_lessons()
	state.checkpoint_state={"defeated":(_snapshot.get("defeated",{}) as Dictionary).keys(),"collected":(_snapshot.get("collected",{}) as Dictionary).keys(),"tasks":(_snapshot.get("tasks",{}) as Dictionary).keys(),"task_steps":(_snapshot.get("task_steps",{}) as Dictionary).duplicate()}
	state.boss_defeated=_boss_defeated
	state.boss_health=0 if _boss_defeated else (_boss.health if is_instance_valid(_boss) else int(_loaded_run.get("boss_health",20)))
	if death:
		var at: Vector3=_checkpoint if _checkpoint_index>=0 else _vec3(_phase.player_spawn)
		state.position=[at.x,at.y]
		state.health=1 if _checkpoint_index>=0 else 3
		state.charges={"attack":0,"defense":0,"amber":0,"dash":0,"rupture":0} if _checkpoint_index>=0 else Run.fresh(_order).charges
		state.defeated=state.checkpoint_state.defeated
		state.collected=state.checkpoint_state.collected
		state.tasks=state.checkpoint_state.tasks
		state.task_steps=state.checkpoint_state.task_steps
		state.boss_defeated=false
		state.boss_health=20
	var error:=Run.save(_save_owner,state,intent)
	if error!=OK and not _save_error and is_instance_valid(_hud):_hud.notify("Não foi possível salvar a partida neste aparelho",true)
	_save_error=error!=OK
func _sync_run_cloud() -> void:
	if _save_owner!=OwnerStorage.owner_id() or PlayerServices.current==null:return
	var service:=PlayerServices.current.story_progress
	if service!=null:service.sync.call_deferred()
func _advance(path: String) -> void:
	if _advancing:return
	_advancing=true
	var loading := CampaignLoading.new()
	loading.name = "CampaignLoading"
	get_tree().root.add_child(loading)
	loading.cancelled.connect(func() -> void:_advancing=false)
	loading.begin(path, _present_next_phase.bind(path))

func _present_next_phase(packed: PackedScene, path: String) -> void:
	var order := int(path.get_file().get_basename().trim_prefix("phase_"))
	var story := PhaseStory.new()
	story.name = "PhaseStory"
	get_tree().root.add_child(story)
	story.finished.connect(_finish_advance.bind(packed))
	story.begin(order)

func _finish_advance(packed: PackedScene) -> void:
	_resume()
	var next := packed.instantiate()
	next.set_meta("carry_charges",_charge_snapshot())
	next.set_meta("from_previous_phase",true)
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
	_save_active_run()
	_sync_run_cloud()
	_resume()
	if return_requested.get_connections().is_empty(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	else: return_requested.emit()
func _exit_tree() -> void:
	_save_active_run()
	# Cancela tarefas ligadas aos nós antes de liberar o cenário em streaming.
	_build_queue.clear()
	_actor_resources.clear()
	_floor_parts.clear()
	if is_instance_valid(_sfx):
		for channel in _sfx._players: channel.stop()
	_set_web_story_playing(false)
	if _hit_stopping: Engine.time_scale = 1.0
	if _paused: get_tree().paused = false
	if not _handoff: get_tree().quit_on_go_back = _previous_go_back
	if is_instance_valid(get_parent()):
		for sibling in get_parent().get_children():
			if sibling is PrototypeReturnOverlay:
				sibling.show()
				sibling.process_mode = Node.PROCESS_MODE_INHERIT


## Partida jogável é separada dos contratos assinados de economia e recompensas.
func _sync_game_checkpoint(_index: int) -> void:
	_save_active_run()
	_sync_run_cloud()

func _restore_game_checkpoint() -> void:
	_run_template=Run.fresh(_order,_charge_snapshot())
	_run_id=_run_template.run_id
	if _loaded_run.is_empty() or int(_loaded_run.phase)!=_order:
		_loaded_run={}
		_restore_legacy_checkpoint()
		return
	_run_id=str(_loaded_run.run_id)
	_checkpoint_index=int(_loaded_run.checkpoint)
	if _checkpoint_index>=0:_checkpoint=_vec3(_phase.checkpoints[_checkpoint_index].pos)
	_elapsed=float(_loaded_run.elapsed)
	_defeated_ids=_id_set(_loaded_run.defeated)
	_collected_ids=_id_set(_loaded_run.collected)
	_raised_bridges=_id_set(_loaded_run.tasks)
	_task_steps=(_loaded_run.task_steps as Dictionary).duplicate()
	_defeated=_defeated_ids.size()
	var snap: Dictionary=_loaded_run.checkpoint_state
	_snapshot={"defeated":_id_set(snap.defeated),"collected":_id_set(snap.collected),"tasks":_id_set(snap.tasks),"task_steps":(snap.task_steps as Dictionary).duplicate(),"attack":0,"defense":0}
	_player.health=int(_loaded_run.health)
	_player.attack_charges=int(_loaded_run.charges.attack)
	_player.defense_charges=int(_loaded_run.charges.defense)
	for kind: String in Layout.ABILITY_PHASE:
		_player.abilities[kind]=int(_loaded_run.charges[kind]) if _order>=int(Layout.ABILITY_PHASE[kind]) else 0
	var at:=Vector3(float(_loaded_run.position[0]),float(_loaded_run.position[1]),0)
	var stable: bool=not Layout.floor_at(_phase,at.x).is_empty()
	for task: Dictionary in _phase.tasks:
		if _raised_bridges.has(str(task.id)) and at.x>=float(task.start) and at.x<=float(task.end):stable=true
	_player.position=(at if stable else _checkpoint)+Vector3.UP*0.05
	_boss_defeated=bool(_loaded_run.boss_defeated)

func _restore_legacy_checkpoint() -> void:
	if bool(get_meta("from_previous_phase",false)):return
	if PlayerServices.current == null or not PlayerServices.current.session.authenticated():
		return
	var progress := PlayerServices.current.progression
	if progress.state != "success":
		return
	var data: Dictionary = progress.data
	var expected := "desert_phase_%02d" % _order
	if str(data.get("active_phase_id", "")) != expected:
		return
	var checkpoint: Variant = data.get("checkpoint")
	if not checkpoint is Dictionary or str(checkpoint.get("phase_id", "")) != expected:
		return
	var ids: Array = PlayerContracts.read_json(PlayerContracts.RULES_PATH).get("phases", [])
	if _order < 1 or _order > ids.size():
		return
	var cp_ids: Array = ids[_order - 1].get("checkpoint_ids", [])
	var index := cp_ids.find(str(checkpoint.get("checkpoint_id", "")))
	var points: Array = _phase.get("checkpoints", [])
	if index < 0 or index >= points.size():
		return
	_checkpoint_index = index
	_checkpoint = _vec3(points[index].pos)
	_snapshot = {"defeated": {}, "collected": {}, "attack": 0, "defense": 0}
	_player.position = _checkpoint + Vector3.UP * 0.05

func _reset_remaster_state() -> void:
	if is_instance_valid(_boss): _boss.queue_free()
	_boss = null
	_boss_defeated = false
	for enemy in _troops.get_children():
		_retire_enemy(enemy)
	_enemy_live.clear()
	_wave_gates.clear()
	_last_wave=-99.0
	_ruptured.clear()
	_raised_bridges.clear()
	_task_steps.clear()
	_bridge_hints.clear()
	_floor_parts.clear()

func _update_troops() -> void:
	if _order == 10 and not _boss_defeated and not is_instance_valid(_boss) and _player.position.x > float(_phase.goal.pos[0])-42:
		_build_malagueta()
	for id in _enemy_live.keys():
		if not is_instance_valid(_enemy_live[id]):
			_enemy_live.erase(id)
			continue
		var enemy := _enemy_live[id] as Node3D
		if _player.position.x-enemy.global_position.x > 110.0:
			_retire_enemy(enemy)
	for spawn: Dictionary in _phase.enemies:
		var ahead := float(spawn.pos[0])-_player.position.x
		if ahead >= -12 and ahead <= 40 and not _defeated_ids.has(str(spawn.id)): _spawn_enemy(_troops,spawn)
	# Pequenas ondas só de um portão já ultrapassado e fora do quadro da câmera.
	var district := clampi(int((_player.position.x-float(_phase.player_spawn[0]))/float(_phase.length)*8),0,7)
	if _wave_gates.has(district): return
	var gate := float(_phase.districts[district].start)+18.0
	var support := Layout.floor_at(_phase,gate)
	if support.is_empty():
		_wave_gates[district] = true
		return
	var gate_y := float(support.height)
	if _player.position.x < gate+28.0: return
	var safe := false
	for platform: Dictionary in _phase.platforms:
		if platform.kind == "ground" and gate > float(platform.span_start)+4 and gate < float(platform.span_end)-4: safe = true
	if not safe:
		_wave_gates[district] = true
		return
	var count: int = _wave_gates.get("pending",0)
	var desired: int = [2,3,3,4,4,4,5,5,6,6][_order-1]
	if _troops.get_child_count() >= 8 or _elapsed-_last_wave<0.65: return
	var wave_x := gate-count*1.1
	var wave_floor := Layout.floor_at(_phase,wave_x)
	if wave_floor.is_empty() or wave_x<float(wave_floor.left)+0.6 or wave_x>float(wave_floor.right)-0.6:
		_wave_gates[district]=true
		return
	_last_wave=_elapsed
	_spawn_enemy(_troops,{"id":"wave.%d.%d" % [district,count],"pos":[wave_x,float(wave_floor.height)+0.02,0],"patrol":[gate-2,gate+2],"troop":true})
	count += 1
	_wave_gates["pending"] = count
	if count >= desired:
		_wave_gates[district] = true
		_wave_gates.erase("pending")

func _on_ability_used(kind: String) -> void:
	if kind != "rupture": return
	var best := ""
	var best_distance := INF
	for id in _floor_parts:
		if _ruptured.has(id): continue
		for node in _floor_parts[id]:
			if not is_instance_valid(node) or not node is StaticBody3D: continue
			var edge := float(node.get_meta("floor_right" if _player.facing>0 else "floor_left"))
			var distance := (_player.position.x-edge)*_player.facing
			if distance>=2.0 and distance<=32.0 and distance<best_distance:
				best = id
				best_distance = distance
	if best.is_empty():
		_player.abilities.rupture += 1
		_hud.notify("Ruptura precisa de piso marcado atrás de você")
		return
	_ruptured[best] = 8.0
	_set_floor_broken(best,true)
	_hud.notify("Piso rompido • restaura em 8 segundos")

func _set_floor_broken(id: String, broken: bool) -> void:
	for node in _floor_parts.get(id,[]):
		if not is_instance_valid(node): continue
		if node is StaticBody3D: node.collision_layer = 0 if broken else 1
		elif node is Node3D:
			if node.has_meta("rupture_tween"):
				var previous: Tween = node.get_meta("rupture_tween")
				if previous != null and previous.is_valid(): previous.kill()
			if broken:
				node.set_meta("rupture_state","BREAKING")
				var fall: Tween = node.create_tween()
				node.set_meta("rupture_tween",fall)
				fall.tween_property(node,"position:y",-3.0,0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				fall.tween_callback(func() -> void:
					node.visible = false
					node.set_meta("rupture_state","BROKEN"))
			else:
				node.set_meta("rupture_state","RESTORING")
				node.position.y = 0
				node.visible = true
				node.set_meta("rupture_state","INTACT")

## O convite HTML de instalação não pode cobrir a pausa da campanha.
func _set_web_story_playing(active: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (window.qseSetStoryPlaying) window.qseSetStoryPlaying(%s);" % ("true" if active else "false"))

## Reutiliza o chefe existente, sem reciclar seu modelo na reserva de soldados.
func _build_malagueta() -> void:
	_boss = Cactus.new()
	_boss.name = "Malagueta"
	_boss.position = _vec3(_phase.boss.pos)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	_boss.add_child(shape)
	var model := ActorSlot.new()
	model.name = "Model"
	_boss.add_child(model)
	add_child(_boss)
	_boss.setup(_enemy_catalog.malagueta,_phase.boss)
	if not _loaded_run.is_empty():_boss.health=clampi(int(_loaded_run.get("boss_health",20)),1,20)
	_boss.persistent_follow = false
	_boss.defeated.connect(func() -> void:
		_boss_defeated = true
		_hud.notify("Malagueta derrotado • saída liberada")
		if _goal.get_overlapping_bodies().has(_player): _on_goal_entered(_player))
	_boss.retired.connect(func(enemy: Node3D) -> void: enemy.queue_free())
