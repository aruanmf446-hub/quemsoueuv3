extends SceneTree
## Casos que os 19 checks originais não cobriam. Janela real, teclado e multitouch.
var phase: Node3D
var player: SidePlayer
var checks := 0
var failures := 0
var output := "/tmp/t15d-extra"
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"_"+label+".png") == OK,"captura real "+label)
func reset_player(position: Vector3) -> void:
	for code in [KEY_A,KEY_D,KEY_SPACE,KEY_J,KEY_S,KEY_SHIFT]: key(code,false)
	player.is_dead = false
	player.position = position
	player.velocity = Vector3.ZERO
	player.setup(phase._find_protagonist())
	await frames(12)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size() > 0 else output
	var dimensions := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	await process_frame
	phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(50)
	player = phase._player
	check(player.is_on_floor(),"spawn estável")
	check(player._model._anim_player.assigned_animation == "pronto","repouso não congela corrida")
	await snap("inicio")
	# Corrida com teclado real e raiz imóvel em relação à cápsula durante o clipe.
	var before := player.position.x
	key(KEY_D,true)
	var alignment := 0.0
	for frame in range(36):
		await physics_frame
		var slot := player._model
		var hip := slot._skeleton.find_bone("mixamorig_Hips")
		var point: Vector3 = slot.to_local(slot._skeleton.to_global(slot._skeleton.get_bone_global_pose(hip).origin))
		alignment = maxf(alignment,Vector2(point.x,point.z).length())
	key(KEY_D,false)
	check(player.position.x > before+2.5,"teclado move com aceleração responsiva")
	check(alignment < 0.12,"visual acompanha cápsula, sem root motion (%.3fm)" % alignment)
	await frames(15)
	check(absf(player.velocity.x) < 0.05,"soltar direção freia sem escorregar")
	await tap(KEY_SPACE)
	await frames(9)
	check(player.jumps_used == 1 and player.position.y > 0.5,"primeiro pulo via tecla")
	await tap(KEY_SPACE)
	await frames(6)
	check(player.jumps_used == 2 and player.velocity.y > 0,"segundo impulso no ar")
	var velocity_before := player.velocity.y
	await tap(KEY_SPACE)
	check(player.jumps_used == 2 and player.velocity.y < velocity_before,"terceiro salto rejeitado")
	await frames(90)
	check(player.is_on_floor() and player.jumps_used == 0,"aterrissagem recupera os dois saltos")
	# Buffer: pressionar pouco antes do piso tem que produzir o salto após contato.
	player.position = Vector3(-6,0.07,0)
	player.velocity = Vector3(0,-2,0)
	player.jumps_used = 2
	player._coyote_timer = 0
	await tap(KEY_SPACE)
	await frames(5)
	check(player.velocity.y > 0 and player.jumps_used == 1,"buffer de salto na aterrissagem")
	await reset_player(Vector3(-6,0.05,0))
	key(KEY_S,true)
	await frames(3)
	check(player.is_crouching,"agachar reconhecido antes de inserir teto")
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8,0.4,2)
	shape.shape = box
	roof.add_child(shape)
	roof.position = player.position+Vector3(0,1.25,0)
	phase.add_child(roof)
	await frames(3)
	key(KEY_S,false)
	await frames(4)
	check(player.is_crouching,"não levanta cápsula através de teto baixo")
	roof.queue_free()
	await frames(5)
	check(not player.is_crouching,"levanta quando há espaço livre")
	# Colisores dos atores não viram plataformas; inimigos ficam fora do mask de piso.
	check(player.collision_mask == 1 and player.collision_layer == 2,"jogador não sobe no corpo dos Cactus")
	for area in phase.get_children():
		if area is Area3D: check(area.collision_mask == 2,"checkpoint/saída detectam camada do jogador")
	# Golpe tem preparação e atinge uma única vez, no momento de contato.
	var cactus = get_nodes_in_group("enemies")[0]
	cactus.set_physics_process(false)
	cactus.position = Vector3(-4.8,0.01,0)
	cactus.velocity = Vector3.ZERO
	await reset_player(Vector3(-6,0.01,0))
	player.facing = 1
	var health: int = cactus.health
	await tap(KEY_J)
	check(cactus.health == health,"ataque não causa dano instantâneo antes do gesto")
	await frames(13)
	check(cactus.health == health-SidePlayer.ATTACK_DAMAGE,"hit coincide com contato do golpe (vida=%d antes=%d timer=%.3f delivered=%s frente=%.1f)" % [cactus.health,health,player._attack_timer,player._hit_delivered,player.facing])
	await frames(17)
	check(cactus.health == health-SidePlayer.ATTACK_DAMAGE,"um golpe não acerta duas vezes")
	await snap("combate")
	await frames(12)
	await tap(KEY_J)
	await frames(15)
	check(not cactus.is_in_group("enemies"),"segundo golpe derrota o Cactus")
	# Preparação do Cactus dá tempo real para defender; não há contato instantâneo.
	var enemy = get_nodes_in_group("enemies")[0]
	await reset_player(Vector3(12,0.01,0))
	enemy.position = Vector3(13,0.01,0)
	enemy.velocity = Vector3.ZERO
	enemy._cooldown = 0
	var hp := player.health
	await frames(8)
	check(player.health == hp and enemy._windup > 0,"Cactus anuncia ataque antes de aplicar dano")
	key(KEY_SHIFT,true)
	await frames(26)
	check(player.health == hp and player.is_defending,"defesa pode reagir à preparação")
	check(absf(player.position.x-enemy.position.x) >= 1.0,"corpos não se interpenetram no combate")
	await snap("defesa")
	key(KEY_SHIFT,false)
	enemy.set_physics_process(false)
	# Uma patrulha não se suicida no abismo.
	var patrol = get_nodes_in_group("enemies")[-1]
	await reset_player(Vector3(-8,0.01,0))
	patrol.position = Vector3(1.2,0.01,0)
	patrol.velocity = Vector3.ZERO
	patrol._patrol_min = -12
	patrol._patrol_max = 2
	patrol._direction = 1
	await frames(90)
	check(patrol.position.y > -0.1 and patrol.position.x < 1.4,"patrulha detecta borda e recua")
	# Multitouch real: um dedo mantém direção enquanto outro executa pulo duplo.
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(false)
	root.size = Vector2i(844,390)
	phase._touch_pad.visible = true
	await frames(15)
	await reset_player(Vector3(-6,0.01,0))
	var pad = phase._touch_pad
	var right: Vector2 = pad._areas[1].get_center()
	var jump: Vector2 = pad._areas[5].get_center()
	touch(0,right,true)
	touch(1,jump,true)
	await frames(3)
	check(Input.is_action_pressed("move_right") and player.jumps_used == 1,"dois dedos: direção e salto simultâneos")
	touch(1,jump,false)
	await frames(9)
	touch(1,jump,true)
	await frames(3)
	check(player.jumps_used == 2 and Input.is_action_pressed("move_right"),"multitoque mantém direção no segundo salto")
	touch(0,right,false)
	touch(1,jump,false)
	await frames(3)
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),"soltar dedos não deixa ações presas")
	await snap("mobile-salto")
	await frames(90)
	await snap("mobile")
	var mouse := InputEventMouseButton.new()
	mouse.position = right
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse,true)
	check(Input.is_action_pressed("move_right"),"mouse também aciona controle virtual")
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse,true)
	check(not Input.is_action_pressed("move_right"),"soltar mouse libera controle virtual")
	check(phase._hud_box.size.y < 120 and phase._progress_box.size.y < 80,"HUD compacto sem faixas verticais")
	print("T15D_RESULT checks=",checks," failures=",failures," root_offset_max=",alignment)
	quit(1 if failures else 0)
func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event,true)
