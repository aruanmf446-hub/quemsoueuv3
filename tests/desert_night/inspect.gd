extends SceneTree
## Inspeção visual por fixtures: capturas reais do framebuffer em momentos de animação,
## combate, borda de buraco, queda, morte, reinício e conclusão.
## Reposiciona o jogador para chegar a cada situação: NÃO é evidência de percurso.
## -- <output_prefix> <order> <WxH>
var phase: Node3D
var player: SidePlayer
var output := "/tmp/night-inspect"
var order := 1
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"_"+label+".png") == OK,"captura "+label)
## Faixa de quadros recortados em volta do jogador para revisar a animação no tempo.
func strip(label: String, count: int, gap: int, action: Callable, full_at := -1, full_label := "") -> void:
	var tiles: Array[Image] = []
	for index in range(count):
		action.call(index)
		await frames(gap)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if index == full_at: check(image.save_png(output+"_"+full_label+".png") == OK,"captura "+full_label)
		var screen: Vector2 = phase._camera.unproject_position(player.global_position+Vector3.UP*0.75)
		var side := int(root.size.y*0.36)
		var corner := Vector2i(clampi(int(screen.x)-side/2,0,image.get_width()-side),clampi(int(screen.y)-side/2,0,image.get_height()-side))
		var rect := Rect2i(corner,Vector2i(side,side))
		var tile := image.get_region(rect)
		tile.resize(240,240)
		tiles.append(tile)
	var sheet := Image.create(240*count,240,false,tiles[0].get_format())
	for index in range(count): sheet.blit_rect(tiles[index],Rect2i(0,0,240,240),Vector2i(index*240,0))
	check(sheet.save_png(output+"_strip_"+label+".png") == OK,"faixa "+label)
func release() -> void:
	for code in [KEY_D,KEY_A,KEY_SPACE,KEY_J,KEY_SHIFT,KEY_S]: key(code,false)
## Fixture: mantém o jogador vivo nas sequências de combate para chegar às próximas cenas.
func keep_alive() -> void:
	if player.health < 2 and not player.is_dead:
		player.health = 3
		player.health_changed.emit(3,3)
func place(x: float) -> void:
	player.position = Vector3(x,0.05,0)
	player.velocity = Vector3.ZERO
	phase._stream_world(x,true)
	phase._follow_camera(1.0)
	await frames(20)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output = args[0]
	if args.size() > 1: order = int(args[1])
	var dimensions := (args[2] if args.size() > 2 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	phase = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(40)
	player = phase._player
	await snap("01_inicio")
	await strip("repouso",6,10,func(_i: int) -> void: pass)
	await strip("arranque_corrida",8,4,func(i: int) -> void:
		if i == 0: key(KEY_D,true),7,"01b_movimento_corrida")
	await strip("virada",8,3,func(i: int) -> void:
		if i == 0:
			key(KEY_D,false)
			key(KEY_A,true))
	key(KEY_A,false)
	await strip("frenagem",6,4,func(_i: int) -> void: pass)
	await strip("salto_duplo_queda",12,5,func(i: int) -> void:
		if i == 0: key(KEY_SPACE,true)
		if i == 1: key(KEY_SPACE,false)
		if i == 3: key(KEY_SPACE,true)
		if i == 4: key(KEY_SPACE,false))
	await frames(40)
	# Combate: o primeiro Cactus do mapa, com o jogador chegando por entrada.
	var enemy_spawn: Dictionary = phase._phase.enemies[0]
	await place(float(enemy_spawn.pos[0])-5.0)
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(false)
	await snap("02_cactus_aproximacao")
	var target: Node3D
	for actor: Node3D in get_nodes_in_group("enemies"):
		if target == null or absf(actor.global_position.x-player.position.x) < absf(target.global_position.x-player.position.x): target = actor
	key(KEY_D,true)
	while target.global_position.x-player.position.x > 1.5: await physics_frame
	key(KEY_D,false)
	await frames(6)
	# Câmera lenta só para a captura: o rastro do golpe dura 0,16s e o renderizador por
	# software desenha poucos quadros por segundo. A física continua em passos iguais.
	Engine.time_scale = 0.2
	await strip("ataque",12,2,func(i: int) -> void:
		if i == 0: key(KEY_J,true)
		if i == 1: key(KEY_J,false),5,"02b_combate_golpe")
	Engine.time_scale = 1.0
	await snap("03_cactus_derrotado")
	check(player.attack_charges == 0,"ataque consumiu a carga")
	# Dano por contato e defesa contra o próximo Cactus.
	var second: Dictionary = phase._phase.enemies[1]
	await place(float(second.pos[0])-4.0)
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(true)
	player._invulnerable = 0.0
	var foe: Node3D
	for actor: Node3D in get_nodes_in_group("enemies"):
		if foe == null or absf(actor.global_position.x-player.position.x) < absf(foe.global_position.x-player.position.x): foe = actor
	await strip("cactus_preparacao",8,4,func(i: int) -> void:
		if i == 0: key(KEY_D,true)
		if not is_instance_valid(foe) or foe.global_position.x-player.position.x < 1.6: key(KEY_D,false))
	key(KEY_D,false)
	keep_alive()
	await strip("dano",8,4,func(i: int) -> void:
		if i == 0:
			player._invulnerable = 0.0
			player.take_damage(1,foe.global_position.x if is_instance_valid(foe) else player.position.x+1.0))
	keep_alive()
	await snap("04_dano_hud")
	await frames(60)
	player._invulnerable = 0.0
	await strip("defesa",8,4,func(i: int) -> void:
		if i == 0: key(KEY_SHIFT,true)
		if i == 1: key(KEY_SHIFT,false)
		if i == 3: player.take_damage(1,player.position.x+1.0)
		keep_alive())
	# Buraco: aproximação, borda, queda e morte.
	var hole: Dictionary = phase._phase.holes[2]
	for actor in get_nodes_in_group("enemies"): actor.queue_free()
	await place(float(hole.start)-9.0)
	key(KEY_D,true)
	while player.position.x < float(hole.start)-4.0: await physics_frame
	key(KEY_D,false)
	await frames(10)
	await snap("05_buraco_aproximacao")
	key(KEY_D,true)
	while player.position.x < float(hole.start)-0.6: await physics_frame
	key(KEY_D,false)
	await frames(12)
	await snap("06_buraco_borda")
	await strip("travessia_buraco",10,5,func(i: int) -> void:
		if i == 0:
			key(KEY_D,true)
			key(KEY_SPACE,true)
		if i == 1: key(KEY_SPACE,false),3,"06b_salto_sobre_buraco")
	key(KEY_D,false)
	await frames(20)
	check(player.position.x > float(hole.end) and player.is_on_floor(),"salto atravessa o buraco para a frente")
	key(KEY_A,true)
	while player.position.x > float(hole.end)+0.6: await physics_frame
	key(KEY_SPACE,true)
	await frames(3)
	key(KEY_SPACE,false)
	while not player.is_on_floor(): await physics_frame
	key(KEY_A,false)
	await frames(10)
	check(player.position.x < float(hole.start),"salto atravessa o buraco de volta")
	key(KEY_D,true)
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	await strip("queda_buraco",10,6,func(i: int) -> void:
		if i == 5: key(KEY_D,false))
	await frames(20)
	await snap("07_morte_queda")
	check(deaths[0] == 1,"queda mata")
	for step in range(150):
		if phase._session.opened: break
		await physics_frame
	await snap("07b_painel_derrota")
	for child in phase._session._column.get_children():
		if child is Button:
			child.pressed.emit()
			break
	await frames(30)
	await snap("08_reinicio")
	check(player.health == 3 and not player.is_dead,"retorno restaura a vida")
	check(absf(player.position.x-phase._checkpoint.x) < 1.0,"retorno volta ao último checkpoint (ou ao início)")
	release()
	# Conclusão: aciona a saída para ver a tela final (fixture; não é percurso).
	await place(float(phase._phase.goal.pos[0])-4.0)
	key(KEY_D,true)
	while not phase.completed: await physics_frame
	key(KEY_D,false)
	await frames(40)
	await snap("09_conclusao")
	print("INSPECT_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
