extends SceneTree
## Regras de sensação/animação/leitura de perigo adicionadas nesta revisão.
## Fixtures isoladas: o reposicionamento NÃO é evidência de percurso.
## -- [order]
var phase: Node3D
var player: SidePlayer
var failures := 0
var checks := 0
var order := 1
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
func release_keys() -> void:
	for code in [KEY_D,KEY_A,KEY_SPACE,KEY_J,KEY_SHIFT,KEY_S]: key(code,false)
func place(x: float) -> void:
	player.position = Vector3(x,0.05,0)
	player.velocity = Vector3.ZERO
	phase._stream_world(x,true)
	await frames(12)
func clip() -> String:
	return player._actor.current_clip()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: order = int(args[0])
	Engine.physics_ticks_per_second = 60
	phase = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(40)
	player = phase._player
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(false)
	check(phase.get_node_or_null("CombatSfx") != null and phase._sfx._streams.size() == 11,"onze sons sintetizados (combate, coleta, checkpoint, pulo e aterrissagem)")
	# Corrida: cadência proporcional à velocidade no arranque, plena em velocidade máxima.
	key(KEY_D,true)
	await frames(3)
	var early_rate: float = player._actor._anim_player.speed_scale
	await frames(30)
	check(clip() == "base" and early_rate < 0.9 and is_equal_approx(player._actor._anim_player.speed_scale,1.0),"cadência da corrida acompanha a aceleração (%.2f→1.0)" % early_rate)
	# Virada: o colisor vira na hora, o modelo gira em alguns quadros.
	key(KEY_D,false)
	key(KEY_A,true)
	await frames(2)
	var yaw_mid: float = player._yaw
	check(player.facing < 0 and absf(yaw_mid) < PI*0.5-0.05 and absf(yaw_mid) > 0.0,"modelo gira entre direções em vez de saltar 180°")
	await frames(20)
	check(absf(player._yaw+PI*0.5) < 0.05,"virada termina alinhada à nova direção")
	key(KEY_A,false)
	await frames(30)
	# Salto: subida mantém o clipe de pulo; descida passa à pose de queda; chão toca a aterrissagem.
	key(KEY_SPACE,true)
	await frames(3)
	key(KEY_SPACE,false)
	check(clip() == "pulo","salto usa o clipe de impulso")
	var saw_fall := false
	var saw_landing := false
	for step in range(90):
		await physics_frame
		if clip() == "queda" and player.velocity.y < 0: saw_fall = true
		if player.is_on_floor() and clip() == "aterrissagem": saw_landing = true
		if saw_landing: break
	check(saw_fall,"descida do salto mostra a pose de queda")
	check(saw_landing,"aterrissagem usa o amortecimento do próprio salto, não o recuo de dano")
	await frames(20)
	# Sair andando de uma borda: antes a corrida continuava no ar.
	var hole: Dictionary = phase._phase.holes[0]
	await place(float(hole.start)-2.0)
	key(KEY_D,true)
	var fall_clip := false
	for step in range(60):
		await physics_frame
		if not player.is_on_floor() and player.position.y < -0.4 and clip() in ["queda","morte"]: fall_clip = true
		if player.is_dead: break
	key(KEY_D,false)
	check(fall_clip,"cair de uma borda troca a corrida pela pose de queda")
	var panel := false
	for step in range(150):
		await physics_frame
		if phase._session.opened and phase._session._death: panel = true; break
	check(panel and get_root().get_tree().paused,"morte pausa e mostra o painel de derrota")
	var labels: Array[String] = []
	for child in phase._session._column.get_children():
		if child is Button: labels.append(child.text)
	check(labels == ["Recomeçar do início","Voltar ao menu"],"sem checkpoint: recomeçar ou voltar ao menu (%s)" % ", ".join(labels))
	(phase._session._column.get_children().filter(func(c: Node) -> bool: return c is Button)[0] as Button).pressed.emit()
	await frames(20)
	check(not player.is_dead and player.health == 3 and not paused,"botão do painel volta ao jogo com vida cheia")
	check(phase._hud._flash.color.a < 0.01,"véu de morte é removido no reinício")
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),"nenhuma ação fica presa depois da morte")
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(false)
	# Buraco: poço escuro e frisos nas duas bordas.
	await place(float(hole.start)-3.0)
	var voids := 0
	var lips: Array[float] = []
	for node: Node in phase._world.find_children("*","MeshInstance3D",true,false):
		if node.has_meta("pit_void"): voids += 1
		if node.has_meta("pit_edge"): lips.append(float(node.get_meta("pit_edge")))
	var left_lip := lips.has(float(hole.start))
	var right_lip := lips.has(float(hole.end))
	check(voids >= 1,"buraco tem fundo escuro em vez de mostrar o panorama")
	check(left_lip and right_lip,"bordas dos dois lados do buraco são marcadas")
	# Travessia por entrada nos dois sentidos.
	key(KEY_D,true)
	while player.position.x < float(hole.start)-0.7: await physics_frame
	key(KEY_SPACE,true)
	await frames(3)
	key(KEY_SPACE,false)
	while not player.is_on_floor() or player.position.x < float(hole.start): await physics_frame
	key(KEY_D,false)
	await frames(20)
	check(player.position.x > float(hole.end) and not player.is_dead,"pulo atravessa o buraco para a frente")
	key(KEY_A,true)
	while player.position.x > float(hole.end)+0.7: await physics_frame
	key(KEY_SPACE,true)
	await frames(3)
	key(KEY_SPACE,false)
	while not player.is_on_floor() or player.position.x > float(hole.end): await physics_frame
	key(KEY_A,false)
	await frames(20)
	check(player.position.x < float(hole.start) and not player.is_dead,"pulo atravessa o mesmo buraco de volta")
	# Combate: golpe no tempo do gesto, som e consumo.
	var enemy_spawn: Dictionary = phase._phase.enemies[0]
	await place(float(enemy_spawn.pos[0])-6.0)
	var target: Node3D
	for actor: Node3D in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)
		if target == null or absf(actor.global_position.x-player.position.x) < absf(target.global_position.x-player.position.x): target = actor
	await place(target.global_position.x-1.6)
	# Vira para o alvo pela entrada antes de golpear.
	key(KEY_D,true)
	await frames(2)
	key(KEY_D,false)
	await frames(10)
	var swings := [0]
	player.swung.connect(func() -> void: swings[0] += 1)
	var hit_frame := [-1]
	var start := Engine.get_physics_frames()
	player.strike_landed.connect(func(_point: Vector3) -> void: hit_frame[0] = Engine.get_physics_frames()-start)
	key(KEY_J,true)
	await frames(2)
	key(KEY_J,false)
	check(clip() == "golpe" and swings[0] == 1,"ataque toca a investida recortada, sem o mortal do combo")
	var arc_seen := false
	for step in range(14):
		await physics_frame
		for child in phase.get_children():
			if child.get_class() == "Node3D" and child.has_method("impact"): arc_seen = true
	check(arc_seen,"areia envolve o punho no soco")
	await frames(16)
	check(hit_frame[0] >= 8 and hit_frame[0] <= 13,"soco acerta com o braço estendido (quadro %d)" % hit_frame[0])
	check(player.attack_charges == 0,"golpe consome a carga")
	# Dano: reação própria, sinal e véu vermelho; depois pisca na invulnerabilidade.
	await frames(30)
	var hurt := [0]
	player.hurt.connect(func() -> void: hurt[0] += 1)
	player._invulnerable = 0.0
	player.take_damage(1,player.position.x+1.0)
	await frames(2)
	check(clip() == "dano" and hurt[0] == 1 and phase._hud._flash.color.a > 0.05,"dano mostra recuo, som e véu vermelho")
	check(player.velocity.x < 0,"recuo afasta o jogador da origem do dano")
	var hidden := false
	for step in range(50):
		await physics_frame
		if not player._model.visible: hidden = true
	check(hidden,"invulnerabilidade pisca o personagem")
	await frames(30)
	check(player._model.visible,"personagem volta a ficar visível ao fim da invulnerabilidade")
	release_keys()
	print("FEEL_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
