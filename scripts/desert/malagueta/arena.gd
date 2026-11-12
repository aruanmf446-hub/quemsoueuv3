extends "res://scripts/desert/t15d/phase.gd"
## Phase 10 only. Existing campaign owns player/HUD/input/save/pause/ending.
const Encounter = preload("res://scripts/desert/malagueta/encounter.gd")
const FilePlatform = preload("res://scripts/desert/malagueta/moving_file.gd")
const Chemical = preload("res://scripts/desert/malagueta/chemical.gd")
@export var file_speed := 2.2
@export var file_travel := 28.0
@export var cactus_interval := 7.0
@export var max_cacti := 3
@export var refill_interval := 12.0
@export var hazard_damage := 1
@export var damage_to_stun := 4
@export var stun_seconds := 5.0
@export var green_interval := 3.2
@export var green_speed := 4.0
@export var green_amplitude := 0.45
@export var red_interval := 2.6
@export var red_speed := 5.5
var encounter: Node
var arena: Node3D
var files: Array[Node3D] = []
var _cactus_wait := 4.0
var _refill_wait := 0.0
var _spawn_serial := 0
var _pending_throws: Array[String] = []
var _upper_landing: StaticBody3D
## Entrada do jogador na arena, afastada da parede por onde a primeira serra entra.
const ENTRY := Vector3(-6.5,0.1,0)
## Respiro ao entrar ou voltar à arena: serras e Malagueta só começam depois dele. Antes a
## primeira serra chegava ao ponto de entrada em meio segundo e tirava duas vidas na passada.
@export var opening_grace := 3.5
var _grace := 0.0
## Aviso piscante na parede por onde a próxima serra vai entrar, na altura dela.
var _warnings: Array[MeshInstance3D] = []
var _player_light: OmniLight3D
var _landing_pass_through := {}
var _steps: Array[StaticBody3D] = []
var _step_pass_through := {}

func _layout_for_phase(_number: int) -> Dictionary:
	var data := Layout.build(10)
	data.merge({"player_spawn":[ENTRY.x,ENTRY.y,0],"length":24.0,"total_length":24.0,
		"bounds":{"min_x":-12.0,"max_x":12.0},"goal":{"pos":[9,9.65,0]},
		"boss":{"id":"p10.malagueta","pos":[8.2,8.85,0],"patrol":[-1,1]},
		"tasks":[],"platforms":[],"enemies":[],"pickups":[],"checkpoints":[{"id":"p10.arena","pos":[ENTRY.x,ENTRY.y,0]}],
		"holes":[{"start":1000.0,"end":1001.0}],"storms":[],"kill_plane_y":-4.0,
		"surfaces":[{"left":-12.0,"right":12.0,"height":0.0}]},true)
	return data
func _restore_game_checkpoint() -> void:
	if not _loaded_run.is_empty() and int(_loaded_run.phase)==10:
		var arena_save: bool=int(_loaded_run.get("task_steps",{}).get("malagueta.handoff",0))==1
		var tasks: Array=_loaded_run.get("tasks",[]).filter(func(id: String) -> bool: return id.begins_with("malagueta.task."))
		_loaded_run.checkpoint=0 if not tasks.is_empty() else -1
		_loaded_run.tasks=tasks
		_loaded_run.task_steps={"malagueta.arena":1,"malagueta.handoff":1}
		_loaded_run.boss_defeated=tasks.size()==3
		var at: Array=_loaded_run.position
		if not arena_save or absf(float(at[0]))>11.0 or float(at[1])>11.5:
			_loaded_run.position=[ENTRY.x,ENTRY.y]
	super._restore_game_checkpoint()
	_task_steps["malagueta.arena"]=1
	_task_steps["malagueta.handoff"]=1
func _new_cactus_actor() -> Node3D:
	return preload("res://scripts/desert/malagueta/pursuer.gd").new()
func _ready() -> void:
	super._ready()
	# Starting the boss must never depend on arriving with spare attack charges.
	_player.fill_ability("attack")
	_player.fill_ability("defense")
	_hud.notify("Suba pelos degraus de pedra à direita • serras ferem por baixo; o aviso laranja mostra a próxima")
	# O herói escuro sumia no fundo da mina: uma luz própria acompanha o jogador.
	_player_light=OmniLight3D.new()
	_player_light.light_color=Color("#ffe2b8")
	_player_light.light_energy=1.8
	_player_light.omni_range=5.5
	_player_light.shadow_enabled=false
	_player_light.position=Vector3(0,1.3,1.6)
	_player.add_child(_player_light)
	_session.full_restore_on_checkpoint=true
## Na arena do chefe a volta ao checkpoint devolve vida e cargas cheias: com 1 vida e sem
## ataque (regra das outras fases) a luta recomeçava impossível de vencer.
func _respawn_at_checkpoint() -> void:
	var from_checkpoint := _checkpoint_index >= 0
	super._respawn_at_checkpoint()
	if not from_checkpoint: return
	_player.health=_player.RUN_MAX_HEALTH
	_player.health_changed.emit(_player.health,_player.RUN_MAX_HEALTH)
	_hud._last_health=_player.health
	_player.fill_ability("attack")
	_player.fill_ability("defense")
	_sync_resources()
	_save_active_run()
func _begin_grace() -> void:
	_grace=opening_grace
	if opening_grace<=0.0: return
	for file in files:
		file.elapsed=0.0
		file.enabled=false
func _end_grace() -> void:
	_grace=0.0
	if not is_instance_valid(encounter): return
	if encounter.fighting() or encounter.is_stunned():
		for file in files: file.enabled=true
func _build_goal() -> void:
	_goal=Area3D.new()
	_goal.name="BossExit"
	_goal.position=Vector3(9,9.65,0)
	_goal.collision_layer=0
	_goal.collision_mask=2
	add_child(_goal)
	# Completion is called by the real third Task/reaction, never by crossing a portal.
func _build_environment() -> void:
	super._build_environment()
	_environment.ambient_light_energy=1.05
func _stream_world(_x: float, force := false) -> void:
	if is_instance_valid(arena) and not arena.is_queued_for_deletion() and not force: return
	if is_instance_valid(arena):
		arena.get_parent().remove_child(arena)
		arena.queue_free()
	arena = Node3D.new()
	arena.name = "MiningBossArena"
	_world.add_child(arena)
	files.clear()
	_task_steps["malagueta.arena"]=1
	_task_steps["malagueta.handoff"]=1
	var props:=preload("res://scripts/desert/t15d/city_props.gd").new()
	arena.add_child(props)
	props.set("_order",10)
	var workshop:=preload("res://scripts/desert/malagueta/workshop.gd").new()
	arena.add_child(workshop)
	# O guindaste saiu de trás do ponto de entrada (escondia o herói) e foi para o fundo
	# central; os cristais ficam nos cantos.
	props.place_asset("desert_mining_gantry",Vector3(1.5,-0.3,-6),6.4)
	props.place_asset("desert_mine_crystals",Vector3(-10.6,-0.1,-4),2.6)
	props.place_asset("desert_mine_crystals",Vector3(-3.4,-0.1,-4.4),2.4)
	props._lantern(Vector3(-10,2.0,-2))
	props._lantern(Vector3(10,10.0,-2))
	props._flush()
	var terrain := Terrain.new()
	arena.add_child(terrain)
	_solid(Vector3(0,-0.5,0),Vector3(24,1,4),false)
	for side in [-1,1]: _solid(Vector3(side*12.5,5,0),Vector3(1,12,4),true)
	terrain.build([{"pos":[0,-0.5,0],"size":[24,1,4],"kind":"ground"}])
	for at: Vector3 in [Vector3(-8,1.2,0),Vector3(-4.6,3.1,0),Vector3(-1.2,5.0,0),Vector3(2.2,6.9,0),Vector3(5.6,8.8,0)]:
		var file := FilePlatform.new()
		file.position = at
		file.speed = file_speed
		file.travel = file_travel
		file.damage = hazard_damage
		file.sweep_index = files.size()
		file.sweep_count = 5
		arena.add_child(file)
		files.append(file)
	_warnings.clear()
	var warning_material:=StandardMaterial3D.new()
	warning_material.albedo_color=Color("#ff8a2a")
	warning_material.emission_enabled=true
	warning_material.emission=Color("#ff7a1a")
	warning_material.emission_energy_multiplier=2.2
	warning_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for file in files:
		var marker:=MeshInstance3D.new()
		var arrow:=PrismMesh.new()
		arrow.size=Vector3(0.7,0.9,0.25)
		marker.mesh=arrow
		marker.material_override=warning_material
		var from_left: bool=file.sweep_index%2==0
		marker.position=Vector3(-11.2 if from_left else 11.2,file.origin.y,0.6)
		marker.rotation.z=-PI*0.5 if from_left else PI*0.5
		marker.visible=false
		arena.add_child(marker)
		_warnings.append(marker)
	# Fixed upper landing keeps melee/Task/ground-only defense accessible.
	var landing := StaticBody3D.new()
	_upper_landing=landing
	_landing_pass_through.clear()
	landing.position = Vector3(9,8.65,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.2,0.4,2)
	shape.shape = box
	landing.add_child(shape)
	var mesh := MeshInstance3D.new()
	var deck := BoxMesh.new()
	deck.size = box.size
	mesh.mesh = deck
	mesh.material_override = Terrain.stone_material(Color("#726c68"))
	landing.add_child(mesh)
	arena.add_child(landing)
	landing.add_to_group("mining_files")
	# Escada fixa até o patamar do chefe: a subida não depende mais de esperar o ciclo das
	# serras. Os degraus ficam na altura das serras (elas deslizam sob os pés, sem ferir) e
	# deixam passar por baixo, como o patamar.
	_steps.clear()
	_step_pass_through.clear()
	var lip:=StandardMaterial3D.new()
	lip.albedo_color=Color("#f2c14e")
	lip.emission_enabled=true
	lip.emission=Color("#d99a2b")
	lip.emission_energy_multiplier=0.7
	lip.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var stone:=StandardMaterial3D.new()
	stone.albedo_color=Color("#a89a86")
	stone.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for top: float in [1.2,3.1,5.0,6.9]:
		var step:=StaticBody3D.new()
		step.position=Vector3(10.6,top-0.15,0)
		var step_shape:=CollisionShape3D.new()
		var step_box:=BoxShape3D.new()
		step_box.size=Vector3(2.6,0.3,2)
		step_shape.shape=step_box
		step.add_child(step_shape)
		var slab:=MeshInstance3D.new()
		var slab_mesh:=BoxMesh.new()
		slab_mesh.size=step_box.size
		slab.mesh=slab_mesh
		slab.material_override=stone
		step.add_child(slab)
		var edge:=MeshInstance3D.new()
		var edge_mesh:=BoxMesh.new()
		edge_mesh.size=Vector3(2.6,0.09,0.5)
		edge.mesh=edge_mesh
		edge.material_override=lip
		edge.position=Vector3(0,0.12,0.78)
		step.add_child(edge)
		step.set_meta("one_way_top",top)
		arena.add_child(step)
		_steps.append(step)
	encounter = Encounter.new()
	arena.add_child(encounter)
	encounter.damage_to_stun=damage_to_stun
	encounter.stun_seconds=stun_seconds
	encounter.green_interval=green_interval
	encounter.red_interval=red_interval
	var done := 0
	for i in range(1,4):
		if _raised_bridges.has("malagueta.task.%d" % i): done += 1
		else: break
	encounter.restore(done)
	encounter.attack_requested.connect(_launch_chemical)
	encounter.stunned.connect(func(_task: int) -> void:
		_clear_chemicals()
		if is_instance_valid(_boss): _boss.set_stunned(true)
		_player.fill_ability("attack")
		_player.fill_ability("defense")
		if is_instance_valid(_hud): _hud.notify("Malagueta atordoado • TASK disponível por 5 segundos"))
	encounter.state_changed.connect(func() -> void:
		if is_instance_valid(_boss) and encounter.fighting() and _boss.stunned: _boss.set_stunned(false))
	encounter.task_completed.connect(func(task: int) -> void:
		_raised_bridges["malagueta.task.%d" % task] = true
		_checkpoint_index=0
		_checkpoint=ENTRY
		_snapshot={"defeated":_defeated_ids.duplicate(),"collected":{},"tasks":_raised_bridges.duplicate(),"task_steps":_task_steps.duplicate(),"attack":3,"defense":3}
		_clear_chemicals()
		_save_active_run())
	encounter.reaction_started.connect(func() -> void:
		_clear_chemicals()
		for enemy in _troops.get_children(): _retire_enemy(enemy)
		for file in files: file.enabled = false
		_impact(Vector3(9,9.65,0),Color("#b7ed85")))
	encounter.defeated.connect(func() -> void:
		_boss_defeated = true
		if is_instance_valid(_boss):
			_boss.defeat()
		_on_goal_entered(_player))
	_build_malagueta()
	if done==3: encounter.call_deferred("emit_signal","reaction_started")
	else: _begin_grace()
	_refill_wait = 0
func _build_malagueta() -> void:
	_boss = preload("res://scripts/desert/malagueta/target.gd").new()
	_boss.name = "Malagueta"
	_boss.position = Vector3(8.2,8.85,0)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 2.0
	capsule.radius = 0.4
	collision.shape = capsule
	collision.position.y = 1.0
	_boss.add_child(collision)
	var model := preload("res://scripts/desert/malagueta/model.gd").new()
	model.name = "Model"
	_boss.add_child(model)
	arena.add_child(_boss)
	_boss.setup(_enemy_catalog.malagueta,_phase.boss)
	_boss.hit_received.connect(func(amount: int) -> void: encounter.hit(amount))
func _follow_camera(_delta: float) -> void:
	# Enquadra a arena inteira (24 m) sem sobra: antes a câmera ficava em 18 m de altura e o
	# herói virava um ponto. Em telas largas (celular deitado) aproxima ainda mais.
	var aspect:=maxf(get_viewport().get_visible_rect().size.aspect(),1.0)
	_camera.size = maxf(15.0,25.2/aspect)
	# Chão a 20% da altura da tela: o herói fica acima dos controles de toque.
	_camera.position = Vector3(0,_camera.size*0.30,24)
	_camera.rotation = Vector3.ZERO
func _update_progress() -> void:
	if is_instance_valid(encounter): _hud.update_progress(encounter.completed_tasks/3.0,_elapsed,"Malagueta • Task %d/3" % encounter.completed_tasks)
func _update_bridge_hint() -> void:
	if not is_instance_valid(encounter): return
	var available: bool = encounter.is_stunned() and _near_boss_task()
	_hud.set_bridge_task(available,"Frasco %d • %.1f s · F" % [encounter.stage(),encounter.remaining] if encounter.is_stunned() else "")
func _near_boss_task() -> bool:
	return _player.is_on_floor() and absf(_player.position.x-9.0) <= 2.1 and absf(_player.position.y-8.85) < 0.4
func _raise_earth_bridge() -> void:
	if _paused or completed or _player.is_dead or not _near_boss_task(): return
	encounter.complete_task(encounter.stage())
func _physics_process(delta: float) -> void:
	_update_landing_support()
	if _grace>0.0 and not _paused and not completed and not _player.is_dead:
		_grace-=delta
		if _grace<=0.0: _end_grace()
	for index in mini(files.size(),_warnings.size()):
		var file:=files[index]
		var soon: bool=(file.enabled and not file.is_available() and file.is_available(1.8)) or (index==0 and _grace>0.0 and _grace<1.8)
		_warnings[index].visible=soon and int(Time.get_ticks_msec()/160)%2==0
	super._physics_process(delta)
	if completed or _paused or _player.is_dead or not is_instance_valid(encounter): return
	# No respiro o chefe não ataca, mas já pode ser atingido.
	if _grace<=0.0: encounter.tick(delta)
	if encounter.fighting() and not _pending_throws.is_empty() and not _boss.throwing():
		var kind: String=_pending_throws[0]
		if _boss.throw_bottle(kind):
			_pending_throws.pop_front()
			_spawn_chemical(kind)
	_refill_wait -= delta
	if _refill_wait <= 0 and encounter.fighting():
		_refill_wait = refill_interval
		# Recargas no miolo da arena, fora da área coberta pelos controles de toque.
		_spawn_refill("attack",Vector3(-4.2,0.1,0))
		_spawn_refill("defense",Vector3(4.2,0.1,0))
func _spawn_refill(kind: String, at: Vector3) -> void:
	for item in arena.get_children():
		if item is Pickup and item.kind == kind: return
	var item := Pickup.new()
	_spawn_serial += 1
	item.kind = kind
	item.pickup_id = "boss.refill.%d" % _spawn_serial
	item.position = at
	arena.add_child(item)
	item.collected.connect(func(_id: String,_kind: String) -> void: _sync_resources())
	item.full_touched.connect(func(power: String) -> void: _hud.notify(("Ataque" if power=="attack" else "Defesa")+" já está em 3/3"))
func _launch_chemical(kind: String) -> void:
	if not encounter.fighting(): return
	if not _pending_throws.has(kind): _pending_throws.append(kind)

func _spawn_chemical(kind: String) -> void:
	if not encounter.fighting(): return
	if is_instance_valid(_boss) and _boss.crystallized_left>0:
		if kind=="green":encounter.green_active=false
		return
	var projectile := Chemical.new()
	projectile.kind = kind
	projectile.damage = hazard_damage
	projectile.position = _boss.position + Vector3(0,1,0)
	projectile.thrower = _boss
	projectile.throw_serial = _boss.throw_serial
	var aim: Vector3 = _player.position + Vector3.UP*0.65 - projectile.position
	if aim.length_squared() < 0.01: aim = Vector3.LEFT
	projectile.direction = aim.normalized()
	projectile.speed = green_speed if kind == "green" else red_speed
	projectile.amplitude=green_amplitude
	arena.add_child(projectile)
	if kind == "green": projectile.expired.connect(func() -> void:
		if is_instance_valid(encounter): encounter.green_active = false)
func _clear_chemicals() -> void:
	_pending_throws.clear()
	if is_instance_valid(encounter): encounter.green_active=false
	if not is_instance_valid(arena): return
	for child in arena.get_children():
		if child is Chemical: child.remove()
func _update_troops() -> void:
	if not is_instance_valid(encounter) or encounter.stage()!=3 or not encounter.fighting(): return
	_cactus_wait -= get_physics_process_delta_time()
	if _cactus_wait > 0 or _troops.get_child_count() >= max_cacti: return
	_cactus_wait = cactus_interval
	_spawn_serial += 1
	_spawn_enemy(_troops,{"id":"boss.cactus.%d" % _spawn_serial,"pos":[-11,0.1,0],"patrol":[-10,10],"troop":true})

func _solid(at: Vector3, dimensions: Vector3, visible_stone: bool) -> void:
	var body:=StaticBody3D.new()
	body.position=at
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=dimensions
	shape.shape=box
	body.add_child(shape)
	if visible_stone:
		var view:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=dimensions
		view.mesh=mesh
		view.material_override=Terrain.stone_material(Color("#514f55"))
		body.add_child(view)
	arena.add_child(body)
	if not visible_stone:
		body.add_to_group("mining_files")
		body.set_meta("navigation_point",Vector3(-10.5,0,0))

func _update_landing_support() -> void:
	if not is_instance_valid(_upper_landing):return
	var actors:=get_tree().get_nodes_in_group("player")
	actors.append_array(get_tree().get_nodes_in_group("enemies"))
	for actor in actors:
		if not actor is PhysicsBody3D:continue
		var id:=actor.get_instance_id()
		var ignored:=bool(_landing_pass_through.get(id,false))
		if not ignored and actor.global_position.y<8.80:
			_upper_landing.add_collision_exception_with(actor);_landing_pass_through[id]=true
		elif ignored and actor.global_position.y>8.90:
			_upper_landing.remove_collision_exception_with(actor);_landing_pass_through[id]=false
		for step in _steps:
			if not is_instance_valid(step):continue
			var key:=str(id)+":"+str(step.get_instance_id())
			var top:=float(step.get_meta("one_way_top"))
			var skipped:=bool(_step_pass_through.get(key,false))
			if not skipped and actor.global_position.y<top-0.05:
				step.add_collision_exception_with(actor);_step_pass_through[key]=true
			elif skipped and actor.global_position.y>top+0.05:
				step.remove_collision_exception_with(actor);_step_pass_through[key]=false
