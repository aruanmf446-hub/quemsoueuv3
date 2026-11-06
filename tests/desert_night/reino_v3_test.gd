extends SceneTree
## Fixtures físicas locais; não chama serviços externos nem concede progresso online.
const Props = preload("res://scripts/desert/t15d/city_props.gd")
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+message)
func frames(count: int) -> void:
	for index in range(count): await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	for order in range(1,10):
		var stage := Layout.build(order)
		check(stage.districts.size() == 8,"fase %d: oito distritos" % order)
		check(float(stage.minimum_traversal_seconds) >= 180 and (float(stage.length)-1-float(stage.transport_allowance))/7.4 >= 180,"fase %d: piso180s com dash" % order)
		check(stage.platforms.any(func(p: Dictionary) -> bool: return p.get("breakable",false)),"fase %d: piso rompível sinalizado" % order)
		var runs := Props._ground_runs(stage.platforms)
		check(runs.size() == stage.holes.size()+1,"fase %d: arquitetura contínua preserva todos os abismos" % order)
		var distinct_pickups := true
		for pickup: Dictionary in stage.pickups:
			if pickup.kind not in ["rupture","amber","dash"]: continue
			for other: Dictionary in stage.pickups:
				if other.id != pickup.id and absf(float(other.pos[0])-float(pickup.pos[0])) < 2.5: distinct_pickups = false
		check(distinct_pickups,"fase %d: recargas novas não sobrepõem outros itens" % order)
	var phase: Node3D = load("res://scenes/desert/phase_06.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(20)
	var unlearned := preload("res://scripts/desert/t15d/player.gd").new()
	var pad := preload("res://scripts/desert/t15d/touch.gd").new()
	pad.actor = unlearned
	root.add_child(pad)
	pad._layout()
	check(not pad._buttons.has("rupture") and not pad._buttons.has("amber") and not pad._buttons.has("dash"),"poderes desconhecidos não deixam botões ou molduras")
	unlearned.discovered.rupture = true
	pad._layout()
	check(pad._buttons.has("rupture") and not pad._buttons.has("amber"),"apenas o poder aprendido aparece")
	pad.queue_free()
	unlearned.free()
	var player: Node3D = phase._player
	check(player.discovered.has("dash") and player.charges("dash")==0,"poder já apresentado mantém botão, sem ganhar carga ao entrar no capítulo6")
	player._invulnerable = 999
	player.set_physics_process(false)
	for kind in ["attack","defense","rupture","amber","dash"]:
		for index in range(4): player.restore_charge(kind)
		check(player.charges(kind) == 3,"%s armazena até três cargas" % kind)
		check(not player.restore_charge(kind),"%s cheio preserva coletável" % kind)
	check(player.use_ability("dash") and player._dash_left > 1,"dash ativa impulso temporário")
	player.cancel_dash()
	check(player._dash_left == 0,"cancelamento/pausa remove dash")
	var cactus: Node3D = get_first_node_in_group("enemies")
	check(is_instance_valid(cactus),"inimigo real disponível")
	if is_instance_valid(cactus):
		cactus.crystallize(0.15)
		var point := cactus.position
		await frames(4)
		check(cactus.position.is_equal_approx(point) and cactus.crystallized_left > 0,"âmbar imobiliza movimento e ataque")
		await frames(15)
		check(cactus.crystallized_left == 0,"âmbar libera inimigo")
		check(cactus.get_parent() == phase._troops,"inimigo fora dos chunks")
	var candidate: Dictionary = {}
	for p: Dictionary in phase._phase.platforms:
		if p.get("breakable",false): candidate = p; break
	check(not candidate.is_empty(),"fixture encontra piso rompível")
	if not candidate.is_empty():
		player.position = Vector3(float(candidate.span_end)+3,0.05,0)
		phase._stream_world(player.position.x,true)
		await frames(20)
		phase._on_ability_used("rupture")
		check(phase._ruptured.has(candidate.id),"ruptura registra estado por ID")
		var query := PhysicsRayQueryParameters3D.create(Vector3(candidate.pos[0],1,0),Vector3(candidate.pos[0],-4,0),1)
		check(phase.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"ruptura abre colisão real")
		phase._set_floor_broken(candidate.id,false)
		await frames(2)
		check(not phase.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"restauração recupera colisão")
	# Piso contínuo e blocos reais em arena isolada para o detector de salto.
	phase.set_physics_process(false)
	var arena := Node3D.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60,1,4)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	floor_body.position = Vector3(5000,-0.5,0)
	var block := StaticBody3D.new()
	block.collision_layer = 1
	var block_shape := CollisionShape3D.new()
	var block_box := BoxShape3D.new()
	block_box.size = Vector3(1.1,0.55,3)
	block_shape.shape = block_box
	block.add_child(block_shape)
	arena.add_child(block)
	block.position = Vector3(5001.1,0.275,0)
	cactus = get_first_node_in_group("enemies")
	if is_instance_valid(cactus):
		cactus.set_physics_process(false)
		cactus.position = Vector3(5000,0.02,0)
		await frames(3)
		check(cactus.can_jump_low(1),"salto baixo reconhece bloco de 0,55m com aterrissagem sólida")
		player.position = Vector3(5006,0.05,0)
		cactus.persistent_follow = true
		cactus.velocity = Vector3.ZERO
		cactus.set_physics_process(true)
		var peak := 0.0
		for frame in range(60):
			await physics_frame
			peak = maxf(peak,cactus.position.y)
		check(cactus.position.x > 5002.4 and peak > 0.65,"Cactus atravessa bloco baixo por salto físico real")
		cactus.set_physics_process(false)
		cactus.position = Vector3(5000,0.02,0)
		cactus.velocity = Vector3.ZERO
		block_box.size.x = 1.7
		await frames(3)
		check(not cactus.can_jump_low(1),"bloco largo demais não provoca salto")
		block_box.size.x = 1.1
		block_box.size.y = 2.0
		block.position.y = 1.0
		await frames(3)
		check(not cactus.can_jump_low(1),"muro alto bloqueia perseguidor")
		block_box.size.y = 0.55
		block.position.y = 0.275
		floor_body.collision_layer = 0
		await frames(3)
		check(not cactus.can_jump_low(1),"sem chão depois do bloco nunca pula")
	if is_instance_valid(cactus): cactus.remove_from_group("enemies")
	# Beira real: piso termina antes da aterrissagem; o Cactus deve continuar sobre ele.
	floor_body.collision_layer = 1
	floor_box.size = Vector3(20,1,4)
	floor_body.position.x = 4990.5
	block.collision_layer = 0
	cactus.position = Vector3(5000,0.02,0)
	cactus.velocity = Vector3.ZERO
	cactus.set_physics_process(true)
	await frames(60)
	check(cactus.position.x < 5000.5 and cactus.position.y > -0.1,"Cactus para fisicamente na borda do abismo")
	cactus.set_physics_process(false)
	floor_box.size = Vector3(60,1,4)
	floor_body.position.x = 5000
	# Distância real do dash comparada à corrida, sem mover o ator dentro de cada percurso.
	floor_body.collision_layer = 1
	block.collision_layer = 0
	player.position = Vector3(5000,0.05,0)
	player.velocity = Vector3.ZERO
	player.wind = 0
	player.set_physics_process(true)
	await frames(5)
	var origin := player.position.x
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	var normal_distance := player.position.x-origin
	check(normal_distance > 5.0 and normal_distance <= 6.1,"fixture mede corrida normal real a 6m/s")
	player.position = Vector3(5000,0.05,0)
	player.velocity = Vector3.ZERO
	player.restore_charge("dash")
	player.use_ability("dash")
	await frames(60)
	var dash_distance := player.position.x-5000
	check(dash_distance > normal_distance+0.7,"dash percorre mais distância que corrida normal: %.2f > %.2f" % [dash_distance,normal_distance])
	block.collision_layer = 1
	block_box.size = Vector3(1.1,3,3)
	block.position = Vector3(5010,1.5,0)
	player.restore_charge("dash")
	player.use_ability("dash")
	await frames(60)
	check(player.position.x < 5009.5,"dash respeita a colisão de uma parede")
	player.cancel_dash()
	player.set_physics_process(false)
	arena.queue_free()
	phase._reset_remaster_state()
	player.position = Vector3(25,0.05,0)
	phase._stream_world(25,true)
	for index in range(9):
		phase._spawn_enemy(phase._troops,{"id":"test.troop.%d" % index,"pos":[8-index*0.8,0.02,0],"patrol":[0,12],"troop":true})
	check(phase._troops.get_child_count() == 8,"tropas acumulam até oito e rejeitam o nono")
	await frames(60)
	var moving := 0
	for enemy in phase._troops.get_children():
		if enemy.velocity.x > 4.5: moving += 1
	check(moving >= 3,"três ou mais Cactus perseguem simultaneamente")
	var living_before_stream: Array=phase._troops.get_children()
	phase._stream_world(220,true)
	check(not living_before_stream.is_empty() and phase._troops.get_children()==living_before_stream,"descarregar chunks preserva os mesmos perseguidores que estavam vivos")
	phase._reset_remaster_state()
	check(phase._troops.get_child_count() == 0 and phase._ruptured.is_empty(),"reset limpa tropas e ruptura")
	player.setup(phase._find_protagonist())
	check(player.discovered.has("rupture") and player.discovered.has("amber") and player.discovered.has("dash") and player.abilities.values().all(func(value: int) -> bool: return value == 0),"replay conserva descobertas e reinicia cargas novas")
	player.restore_charge("dash")
	player.use_ability("dash")
	player._invulnerable = 0
	player.take_damage(1,player.position.x-2)
	check(player._dash_left == 0 and player.health == 2 and absf(player.velocity.x) <= player.SPEED,"dano real interrompe Relâmpago")
	player.setup(phase._find_protagonist())
	player.restore_charge("dash")
	player.use_ability("dash")
	player.fall_out()
	check(player.is_dead and player._dash_left == 0 and player.velocity == Vector3.ZERO,"morte real interrompe Relâmpago e velocidade")
	phase._restart_level()
	root.remove_child(phase)
	phase.queue_free()
	for frame in range(4): await process_frame
	print("REINO_V3_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
