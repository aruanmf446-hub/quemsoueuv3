extends SceneTree
## Fixtures isoladas de regras/entrada/HUD. Reposicionamentos NÃO são evidência de percurso.
var phase: Node3D
var player: SidePlayer
var output := "/tmp/night-rules"
var failures := 0
var checks := 0
var empty_actions := 0
var blocks := 0
var deaths := 0
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
func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event,true)
func fresh() -> void:
	for code in [KEY_D,KEY_A,KEY_SPACE,KEY_J,KEY_SHIFT,KEY_S]: key(code,false)
	phase._restart_level()
	await frames(30)
	player = phase._player
	player._invulnerable = 0.0
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(false)
func snap(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"_"+label+".png") == OK,"captura real de fixture "+label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output = args[0]
	var dimensions := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(35)
	player = phase._player
	player.action_empty.connect(func(_kind: String) -> void: empty_actions += 1)
	player.blocked.connect(func() -> void: blocks += 1)
	player.died.connect(func() -> void: deaths += 1)
	check(player.health == 3 and player.attack_charges == 1 and player.defense_charges == 1,"estado inicial real: vida3, ataque1, defesa1")
	check(not player.restore_charge("attack") and not player.restore_charge("defense"),"cargas cheias recusam reposição sem consumir item")
	check(player.is_on_floor(),"spawn seguro no piso")
	var x := player.position.x
	key(KEY_D,true)
	await frames(35)
	key(KEY_D,false)
	check(player.position.x > x+2.4,"tecla física anda para frente")
	key(KEY_A,true)
	await frames(35)
	key(KEY_A,false)
	await frames(8)
	check(player.position.x < x+0.8,"tecla física permite voltar pelo mapa")
	await tap(KEY_SPACE)
	await frames(8)
	check(player.jumps_used == 1 and player.velocity.y > 0,"primeiro salto responsivo")
	await tap(KEY_SPACE)
	await frames(4)
	check(player.jumps_used == 2 and player.velocity.y > 0,"pulo duplo preservado")
	var velocity := player.velocity.y
	await tap(KEY_SPACE)
	check(player.jumps_used == 2 and player.velocity.y < velocity,"terceiro impulso rejeitado")
	await frames(95)
	check(player.is_on_floor() and player.jumps_used == 0,"aterrissar restaura saltos")
	key(KEY_S,true)
	await frames(3)
	check(player.is_crouching and player._shape.shape.height < SidePlayer.STAND_HEIGHT,"agachar continua encolhendo a cápsula")
	key(KEY_S,false)
	await frames(3)
	# Contato deve causar dano sem depender do ataque de IA do inimigo.
	await fresh()
	var enemy: Node3D = get_nodes_in_group("enemies")[0]
	enemy.position = player.position+Vector3(1.0,0,0)
	var hp: int = player.health
	var cactus_hp: int = enemy.health
	await frames(2)
	check(player.health == hp-1,"encostar no Cactus causa dano imediato")
	check(enemy.health == cactus_hp and enemy.is_in_group("enemies"),"contato não mata nem causa dano ao Cactus")
	await frames(20)
	check(player.health == hp-1,"invulnerabilidade impede drenagem de vida a cada frame")
	# Ataque e defesa são recursos, não habilidades ilimitadas.
	await fresh()
	enemy = get_nodes_in_group("enemies")[0]
	enemy.position = player.position+Vector3(1.5,0,0)
	await tap(KEY_J)
	check(player.attack_charges == 0,"golpe consome a única carga de ataque")
	await frames(16)
	check(not enemy.is_in_group("enemies"),"um ataque real é suficiente para derrotar o Cactus")
	check(phase._defeated_ids.size() == 1,"derrota recebe id persistente no percurso")
	await frames(25)
	await tap(KEY_J)
	check(player.attack_charges == 0 and empty_actions > 0,"atacar vazio informa falta de carga sem gerar golpe")
	check(player.restore_charge("attack") and player.attack_charges == 1,"reposição restaura uma carga, até o limite1")
	check(not player.restore_charge("attack"),"segunda reposição não cria carga acima de1")
	await fresh()
	await tap(KEY_SHIFT)
	check(player.defense_charges == 0 and player.is_defending,"defesa consome carga e abre a janela de proteção")
	enemy = get_nodes_in_group("enemies")[0]
	enemy.position = player.position+Vector3(1.0,0,0)
	hp = player.health
	var prior_blocks := blocks
	await frames(3)
	check(player.health == hp and blocks == prior_blocks+1,"uma defesa bloqueia um contato real")
	check(not player.is_defending,"escudo se encerra após o único bloqueio")
	await tap(KEY_SHIFT)
	check(player.defense_charges == 0 and not player.is_defending,"defesa vazia não concede nova proteção")
	# Item no chão usa o fluxo real de área/proximidade e não desaparece se cheio.
	await fresh()
	var pickup: Dictionary
	for entry: Dictionary in phase._phase.pickups:
		if entry.kind == "attack": pickup = entry; break
	var safe_origin := player.position
	player.position = Vector3(float(pickup.pos[0]),0.05,0)
	player.velocity = Vector3.ZERO
	await frames(8)
	check(not phase._collected_ids.has(pickup.id),"item de ataque permanece quando o inventário está cheio")
	for actor in get_nodes_in_group("enemies"): actor.position.x = player.position.x-30
	await tap(KEY_J)
	await frames(5)
	check(phase._collected_ids.has(pickup.id) and player.attack_charges == 1,"usar carga sobre o item permite coleta real da reposição")
	var collected_count: int = phase._collected_ids.size()
	# Só nesta fixture: teleporte para exercitar descarregamento/retorno de chunks.
	player.position = safe_origin+Vector3(260,0.1,0)
	player.velocity = Vector3.ZERO
	await frames(8)
	player.position = Vector3(float(pickup.pos[0]),0.05,0)
	player.velocity = Vector3.ZERO
	await frames(8)
	check(phase._collected_ids.has(pickup.id) and phase._collected_ids.size() == collected_count,"item coletado não reaparece ao ir para trás após streaming")
	check(phase._loaded_chunks.size() <= 7,"streaming não acumula o mapa inteiro")
	# Cair em um vão real deve matar e reconstruir a fase desde o início.
	await fresh()
	var hole: Dictionary = phase._phase.holes[0]
	player.position = Vector3((float(hole.start)+float(hole.end))*0.5,0.1,0)
	player.velocity = Vector3.ZERO
	var prior_deaths := deaths
	for frame in range(180):
		if player.is_dead: break
		await physics_frame
	check(player.is_dead and deaths == prior_deaths+1,"cair no buraco aciona morte")
	# A derrota pausa a fase e mostra o painel; sem checkpoint ativo, o primário recomeça.
	for frame in range(150):
		if phase._session.opened and phase._session._death: break
		await physics_frame
	check(phase._session.opened and paused,"morte abre o painel de derrota com a fase pausada")
	for child in phase._session._column.get_children():
		if child is Button:
			child.pressed.emit()
			break
	await frames(10)
	player = phase._player
	var spawn_x := float(phase._phase.player_spawn[0])
	check(not player.is_dead and absf(player.position.x-spawn_x) < 0.5,"sem checkpoint, a derrota volta ao início inteiro da fase")
	check(player.health == 3 and player.attack_charges == 1 and player.defense_charges == 1,"nova tentativa restaura vida e os dois recursos")
	check(phase._defeated_ids.is_empty() and phase._collected_ids.is_empty(),"nova tentativa restaura inimigos e reposições")
	# GUI: eventos reais de dois dedos e mouse, alvos físicos e pausa.
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(844,390)
		await frames(10)
		var pad: Control = phase._touch_pad
		check(pad.visible and pad._areas.size() == 6,"landscape mobile exibe todos os comandos")
		var right: Vector2 = pad._areas[1].get_center()
		var jump: Vector2 = pad._areas[5].get_center()
		var unit := root.get_visible_rect().size.y/float(root.size.y)
		var target_sizes_ok := true
		for area: Rect2 in pad._areas:
			if area.size.x/unit < 48.0 or area.size.y/unit < 48.0: target_sizes_ok = false
		check(target_sizes_ok,"alvos de toque têm pelo menos48 pixels físicos")
		touch(0,right,true)
		touch(1,jump,true)
		await frames(3)
		check(Input.is_action_pressed("move_right") and player.jumps_used == 1,"multitoque mantém direção e salta")
		touch(1,jump,false)
		await frames(8)
		touch(1,jump,true)
		await frames(3)
		check(Input.is_action_pressed("move_right") and player.jumps_used == 2,"segundo toque executa pulo duplo sem perder direção")
		touch(0,right,false)
		touch(1,jump,false)
		await frames(2)
		check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"),"soltar dedos libera ações")
		await frames(90)
		await snap("mobile_hud")
		var pause: Control = phase._hud._pause
		await click(pause)
		check(paused and phase._session.opened,"mouse abre a pausa pelo botão real")
		var stopped := player.position
		await frames(20)
		check(player.position.distance_to(stopped) < 0.001,"mundo permanece parado na pausa")
		await snap("mobile_pause")
		await click(find_button(phase._session,"Continuar"))
		check(not paused,"Continuar retoma por GUI real")
		check(pad._held.is_empty(),"retomar não deixa toque preso")
	print("NIGHT_RULES_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
func click(control: Control) -> void:
	if control == null: check(false,"botão esperado existe"); return
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event,true)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames(3)
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var button := find_button(child,text)
		if button != null: return button
	return null
