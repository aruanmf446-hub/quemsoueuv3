extends SceneTree
## Travessia completa por entradas, sem atribuir posição após o spawn.
## -- <output> <order> <WxH> [captures|no-captures]
const Progress = preload("res://scripts/desert/t15d/campaign_progress.gd")
var phase: Node3D
var player: SidePlayer
var failures := 0
var checks := 0
var deaths := 0
var swings := 0
var order := 1
var output := "/tmp/desert-night-route"
var capture_frames := false
var platforms: Array = []
var _frame_count := 0
var _captured := {}
var _previous_x := 0.0
var _stalled := 0
var _jump_release_at := -1
var _attack_release_at := -1
var _previous_attack_charge := 1
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func snap(label: String) -> void:
	if not capture_frames: return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"_"+label+".png")
	check(error == OK,"captura nativa "+label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output = args[0]
	if args.size() > 1: order = int(args[1])
	var dimensions := (args[2] if args.size() > 2 else "1920x1080").split("x")
	capture_frames = DisplayServer.get_name() != "headless" and (args.size() < 4 or args[3] != "no-captures")
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	# Fixture de acesso para executar cada mapa isoladamente, sem falsificar sua vitória.
	for previous in range(1,order):
		if Progress.complete(previous) != OK:
			check(false,"pré-condição local de acesso")
			quit(1)
			return
	phase = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
	root.add_child(phase)
	current_scene = phase
	player = phase._player
	platforms = phase._phase.platforms
	player.died.connect(func() -> void: deaths += 1)
	await frames(30)
	check(phase._phase.get("order",0) == order,"cena carrega o mapa correto %02d" % order)
	check(player.health == 3 and player.attack_charges == 1 and player.defense_charges == 1,"vida e recursos iniciais 3/3, 1/1 e 1/1")
	check(phase._phase.get("checkpoints",[]).size() == 7,"sete checkpoints de distrito")
	var origin := player.position.x
	var goal := float(phase._phase.goal.pos[0])
	check((goal-origin-1.0)/6.0 >= 180.0,"distância obrigatória garante três minutos mesmo sem combate")
	await snap("01_spawn")
	var start_tick := Engine.get_physics_frames()
	_previous_x = player.position.x
	for step in range(60*420):
		_frame_count = step
		if phase.completed or deaths > 0: break
		if step == _jump_release_at: Input.action_release("jump")
		if step == _attack_release_at: Input.action_release("attack")
		var share := (player.position.x-origin)/maxf(goal-origin,1)
		if capture_frames:
			if player.attack_charges == 0 and _previous_attack_charge == 1 and not _captured.has("attack"):
				_captured["attack"] = true
				await snap("ataque_carga0")
			if player.attack_charges == 1 and _previous_attack_charge == 0 and not _captured.has("refill"):
				_captured["refill"] = true
				await snap("reposicao_carga1")
			if player.position.x >= float(phase._phase.holes[0].start)-6.0 and not _captured.has("pit"):
				_captured["pit"] = true
				await snap("buraco_antecipado")
		_previous_attack_charge = player.attack_charges
		for milestone in [0.33,0.67]:
			if capture_frames and share >= milestone and not _captured.has(milestone):
				_captured[milestone] = true
				await snap("percurso_%02d" % int(milestone*100))
		if step%600 == 0:
			print("ROUTE_TICK phase=",order," seconds=",step/60.0," x=",player.position.x," hp=",player.health," attack=",player.attack_charges," loaded=",phase._loaded_chunks.size())
		if player.position.distance_to(Vector3(player.position.x,player.position.y,0)) > 0.01:
			check(false,"movimento permanece no plano 2.5D")
			break
		if absf(player.position.x-_previous_x) < 0.01 and player.is_on_floor(): _stalled += 1
		else: _stalled = 0
		_previous_x = player.position.x
		if _stalled > 60*8:
			print("STALL x=",player.position.x," y=",player.position.y," ahead=",surface_at(player.position.x+0.9)," grounded=",player.is_on_floor()," timer=",player._attack_timer," charge=",player.attack_charges)
			check(false,"não fica preso no percurso por oito segundos")
			break
		var enemy := enemy_ahead(2.5)
		if player._attack_timer > 0.0:
			Input.action_release("move_right")
		elif enemy != null and player.attack_charges > 0 and player.is_on_floor():
			var gap := enemy.global_position.x-player.global_position.x
			var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.7,enemy.global_position+Vector3.UP*0.7,1)
			var clear := player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
			if gap <= 1.65 and clear:
				Input.action_release("move_right")
				if not Input.is_action_pressed("attack"):
					Input.action_press("attack")
					_attack_release_at = step+2
					swings += 1
			else:
				Input.action_press("move_right")
				auto_jump(step)
		else:
			Input.action_press("move_right")
			if enemy != null and player.attack_charges <= 0 and player.is_on_floor(): jump(step)
			else: auto_jump(step)
		await physics_frame
	for action in ["move_right","move_left","jump","attack","defend","crouch"]: Input.action_release(action)
	var physics_seconds := float(Engine.get_physics_frames()-start_tick)/60.0
	check(deaths == 0,"travessia completa sem morte ou respawn")
	check(phase.completed,"saída alcançada exclusivamente por ações reais")
	check(float(phase._elapsed) >= 180.0,"tempo físico da fase >=180s (%.2f)" % phase._elapsed)
	check(physics_seconds >= 180.0,"relógio independente confirma >=180s (%.2f)" % physics_seconds)
	check(phase._loaded_chunks.size() <= 7,"streaming mantém quantidade limitada de distritos carregados")
	check(phase._checkpoint_index == 6,"percurso ativa os sete checkpoints")
	if phase.completed: await snap("04_vitoria")
	var result := {"order":order,"completed":phase.completed,"deaths":deaths,"checks":checks,"failures":failures,"physics_seconds":physics_seconds,"phase_seconds":phase._elapsed,"health":player.health,"swings":swings,"defeated":phase._defeated_ids.size(),"collected":phase._collected_ids.size(),"captured":capture_frames,"position":[player.position.x,player.position.y,player.position.z]}
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("NIGHT_ROUTE_RESULT ",JSON.stringify(result))
	quit(1 if failures else 0)
func jump(step: int) -> void:
	if Input.is_action_pressed("jump"): return
	Input.action_press("jump")
	_jump_release_at = step+2
func auto_jump(step: int) -> void:
	var ahead := surface_at(player.position.x+0.9)
	if player.is_on_floor():
		if ahead == -INF or ahead > player.position.y+0.3: jump(step)
	elif player.jumps_used == 1:
		if (ahead == -INF and player.position.y > 0.2) or (ahead > 1.5 and player.position.y >= 1.0 and player.position.y <= 1.6): jump(step)
func surface_at(x: float) -> float:
	var top := -INF
	for platform: Dictionary in platforms:
		var half := float(platform.size[0])*0.5
		if x >= float(platform.pos[0])-half and x <= float(platform.pos[0])+half:
			top = maxf(top,float(platform.pos[1])+float(platform.size[1])*0.5)
	return top
func enemy_ahead(distance: float) -> Node3D:
	var nearest: Node3D
	for actor: Node3D in get_nodes_in_group("enemies"):
		var gap := actor.global_position.x-player.global_position.x
		if gap > 0 and gap < distance and absf(actor.global_position.y-player.global_position.y) < 1.1:
			if nearest == null or gap < nearest.global_position.x-player.global_position.x: nearest = actor
	return nearest
