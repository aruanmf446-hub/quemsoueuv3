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
var _rupture_release_at := -1
var _amber_release_at := -1
var _defense_release_at := -1
var _previous_attack_charge := 1
var _render_intervals: Array[float] = []
var _last_render_tick := 0
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
	_last_render_tick = Time.get_ticks_usec()
	process_frame.connect(func() -> void:
		var tick := Time.get_ticks_usec()
		if _frame_count > 30 and is_instance_valid(phase) and not phase.completed:
			_render_intervals.append((tick-_last_render_tick)/1000.0)
		_last_render_tick = tick)
	var start_tick := Engine.get_physics_frames()
	_previous_x = player.position.x
	var last_tick := Time.get_ticks_usec()
	var step_times: Array[float] = []
	for step in range(60*420):
		_frame_count = step
		var tick := Time.get_ticks_usec()
		# O passo da vitória (salvar e abrir a tela final) fica fora: o jogo já parou.
		if step > 30 and not phase.completed:
			step_times.append((tick-last_tick)/1000.0)
			if (tick-last_tick)/1000.0 > 33: print("ROUTE_SLOW step=",step," ms=",(tick-last_tick)/1000.0," x=",player.position.x," time_scale=",Engine.time_scale," active=",phase._troops.get_child_count()," queue=",phase._build_queue.size())
		last_tick = tick
		if phase.completed or deaths > 0: break
		if step == _jump_release_at: Input.action_release("jump")
		if step == _attack_release_at: Input.action_release("attack")
		if step == _rupture_release_at: Input.action_release("rupture")
		if step == _amber_release_at: Input.action_release("amber")
		if step == _defense_release_at: Input.action_release("defend")
		if player.is_on_floor() and player.defense_charges>0 and player._shield_timer<=0 and player._attack_timer<=0.15:
			for threat: Node3D in get_nodes_in_group("enemies"):
				if threat.has_method("can_jump_gap") and threat._windup>0 and absf(threat.position.x-player.position.x)<2.2:
					Input.action_press("defend")
					_defense_release_at=step+2
					break
		if order >= 2 and player.is_on_floor() and player.charges("rupture")>0 and step%60==0:
			for pursuer: Node3D in get_nodes_in_group("enemies"):
				var behind := player.position.x-pursuer.position.x
				if behind>3 and behind<20:
					Input.action_press("rupture")
					_rupture_release_at=step+2
					break
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
		if order==10 and phase._boss_defeated and player.position.x>goal:
			Input.action_release("move_right")
			Input.action_press("move_left")
			await physics_frame
			continue
		if fight_malagueta(step):
			await physics_frame
			continue
		var enemy := enemy_ahead(2.5)
		if await ride_ferry(step):
			_stalled = 0
			continue
		if player._attack_timer > 0.0:
			if player.is_on_floor() or order!=2: Input.action_release("move_right")
			else:
				Input.action_press("move_right")
				auto_jump(step)
		elif enemy != null and player.attack_charges > 0 and (player.is_on_floor() or (order==2 and surface_at(player.position.x) != -INF)):
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
	step_times.sort()
	var cost := {"p95_ms": step_times[int(step_times.size()*0.95)] if not step_times.is_empty() else 0.0, "max_ms": step_times[-1] if not step_times.is_empty() else 0.0}
	# O hit-stop intencional desacelera a física a 0,05×: um intervalo físico contém
	# vários quadros e não mede o custo de UM quadro. Registra ambos sem ocultar picos.
	_render_intervals.sort()
	var render_cost := {"p95_ms":_render_intervals[int(_render_intervals.size()*0.95)] if not _render_intervals.is_empty() else INF,"max_ms":_render_intervals[-1] if not _render_intervals.is_empty() else INF}
	if not capture_frames: check(render_cost.p95_ms < 33.0,"95%% dos quadros ficam no orçamento de 33ms (p95 %.1fms, pico %.1fms)" % [render_cost.p95_ms,render_cost.max_ms])
	var result := {"cpu_step":cost,"render_frame_wall":render_cost,"measurement":"wall-clock; physics intervals include intentional 0.05x hit-stop; all maxima retained","order":order,"completed":phase.completed,"deaths":deaths,"checks":checks,"failures":failures,"physics_seconds":physics_seconds,"phase_seconds":phase._elapsed,"health":player.health,"swings":swings,"defeated":phase._defeated_ids.size(),"collected":phase._collected_ids.size(),"captured":capture_frames,"position":[player.position.x,player.position.y,player.position.z]}
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("NIGHT_ROUTE_RESULT ",JSON.stringify(result))
	quit(1 if failures else 0)
## Balsa: espera na borda até ela encostar, sobe, fica parado e salta na outra borda.
## Retorna true quando controlou este quadro.
func ride_ferry(step: int) -> bool:
	var hole: Dictionary = {}
	for candidate: Dictionary in phase._phase.holes:
		if candidate.get("ferry",false) and player.position.x > float(candidate.start)-1.2 and player.position.x < float(candidate.end)+0.3:
			hole = candidate
	if hole.is_empty() or not player.is_on_floor(): return false
	var ferry: Node3D
	for node in get_nodes_in_group("ferries"):
		if node.from_x > float(hole.start) and node.to_x < float(hole.end): ferry = node
	if ferry == null: return false
	var start := float(hole.start)
	var finish := float(hole.end)
	if player.position.x > finish: return false
	if player.position.x < start:
		# Na borda: espera a balsa chegar perto e sobe com um passo/pulinho.
		Input.action_release("move_right")
		if player.position.x < start-0.6:
			Input.action_press("move_right")
		elif absf(ferry.position.x-ferry.from_x) < 0.15:
			# A balsa encosta na borda (0,1m): basta andar para subir.
			Input.action_press("move_right")
		await physics_frame
		return true
	# Em cima da balsa: centraliza, espera chegar ao outro lado e desce andando.
	Input.action_release("move_right")
	if absf(ferry.position.x-ferry.to_x) < 0.15 or player.position.x < ferry.position.x-0.6:
		Input.action_press("move_right")
	await physics_frame
	return true
func jump(step: int) -> void:
	if Input.is_action_pressed("jump"): return
	Input.action_press("jump")
	_jump_release_at = step+2
func auto_jump(step: int) -> void:
	var ahead := surface_at(player.position.x+0.9)
	if player.is_on_floor():
		if ahead == -INF or ahead > player.position.y+0.3: jump(step)
	elif player.jumps_used == 1:
		if order!=2 and ahead == -INF and player.velocity.y>0:
			jump(step)
		elif player.velocity.y < 0:
			var landing := -INF
			for hole: Dictionary in phase._phase.holes:
				if player.position.x >= float(hole.start)-1.0 and player.position.x <= float(hole.end)+1.0: landing=maxf(float(hole.get("from_y",0.0)),float(hole.get("to_y",0.0)))
			if (ahead == -INF and player.position.y < landing+0.6) or (ahead != -INF and ahead > player.position.y-0.1): jump(step)
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

## A arena usa as mesmas entradas e itens do jogador, inclusive Âmbar para recarregar.
func fight_malagueta(step: int) -> bool:
	if order!=10 or not is_instance_valid(phase._boss) or phase._boss_defeated: return false
	var boss: Node3D=phase._boss
	if absf(player.position.x-boss.position.x)>38:return false
	if player.charges("amber")>0 and boss.crystallized_left<=0.15 and absf(player.position.x-boss.position.x)<7:
		Input.action_press("amber")
		_amber_release_at=step+2
	var target:float=boss.position.x
	if player.attack_charges==0:
		var distance:=INF
		for item: Dictionary in phase._phase.pickups:
			if item.kind!="attack" or phase._collected_ids.has(str(item.id)):continue
			var gap:=absf(float(item.pos[0])-player.position.x)
			if gap<distance:
				distance=gap
				target=float(item.pos[0])
	var direction:=signf(target-player.position.x)
	Input.action_release("move_left")
	Input.action_release("move_right")
	if player._attack_timer<=0 or not player.is_on_floor():Input.action_press("move_right" if direction>=0 else "move_left")
	if player.attack_charges>0 and absf(boss.position.x-player.position.x)<=1.65 and absf(boss.position.y-player.position.y)<1.3 and player._attack_cooldown<=0:
		Input.action_press("attack")
		_attack_release_at=step+2
		swings+=1
	if player.attack_charges==0 and absf(boss.position.x-player.position.x)<2.5 and player.is_on_floor():jump(step)
	return true
