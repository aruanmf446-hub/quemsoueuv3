extends SceneTree
## Regressões de pausa/morte e parede entre os combatentes, em janela.
var phase: Node3D
var player: SidePlayer
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func check(value: bool, text: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ")+text)
	if not value: failures += 1
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(844,390)
	phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(30)
	player = phase._player
	# Regras atuais: a derrota pausa a fase e abre o painel; nada acontece sozinho.
	player.fall_out()
	for step in range(150):
		if phase._session.opened and phase._session._death: break
		await physics_frame
	check(paused and phase._respawning and player.is_dead,"derrota pausa a fase e espera a escolha do jogador")
	await frames(120)
	check(player.is_dead and phase._session.opened,"sem escolha, o personagem não reaparece sozinho")
	phase._respawn_at_checkpoint()
	await frames(10)
	check(not paused and not phase._respawning and not player.is_dead and player.health == 3,"voltar ao checkpoint conclui o retorno uma única vez com vida 3")
	player.fall_out()
	await frames(10)
	phase._restart_level()
	await frames(10)
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	await frames(100)
	check(player.position.x > -6 and not player.is_dead and not phase._session.opened,"recomeçar cancela a derrota antiga sem painel tardio")
	var pad = phase._touch_pad
	await frames(3)
	pad._press(4,pad._areas[1].get_center())
	phase.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(5)
	check(paused and not Input.is_action_pressed("move_right") and pad._held.is_empty(),"perda de foco pausa e libera dedos/direção")
	phase._resume()
	await frames(3)
	check(not paused and not phase._session.opened,"voltar do foco não deixa overlay ou pausa presos")
	check(not quit_on_go_back,"fase assume o botão Voltar sem encerrar o aplicativo")
	phase.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(paused,"botão Voltar abre pausa")
	phase.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not paused,"botão Voltar também retoma a partida")
	var enemy = get_nodes_in_group("enemies")[0]
	for actor in get_nodes_in_group("enemies"):
		if actor != enemy: actor.set_physics_process(false)
	player.position = Vector3(-8,0.01,0)
	player.velocity = Vector3.ZERO
	player.setup(phase._find_protagonist())
	enemy.position = Vector3(-6.8,0.01,0)
	enemy.velocity = Vector3.ZERO
	enemy._player = player
	await frames(1)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1,2,2)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(-7.4,1,0)
	phase.add_child(wall)
	await frames(3)
	enemy._windup = 0.02
	enemy._attack_direction = -1
	var hp := player.health
	await frames(5)
	check(player.health == hp,"parede bloqueia o impacto do Cactus")
	wall.queue_free()
	await frames(3)
	enemy._windup = 0.02
	enemy._attack_direction = -1
	await frames(5)
	check(player.health < hp,"o mesmo golpe acerta quando a parede é removida")
	# Recoloca em alcance para isolar a recuperação visual depois do gesto.
	player.position = Vector3(-8,0.01,0)
	player.velocity = Vector3.ZERO
	enemy.position = Vector3(-6.8,0.01,0)
	enemy.velocity = Vector3.ZERO
	enemy._windup = 0
	enemy._recovery = 0
	enemy._cooldown = 1
	await frames(4)
	check(enemy._model._anim_player.assigned_animation == "pronto","Cactus volta à guarda durante intervalo do ataque")
	enemy.take_damage(99)
	await frames(2)
	phase._pause()
	await frames(120)
	check(is_instance_valid(enemy),"pausa suspende também a remoção do Cactus derrotado")
	phase._resume()
	await frames(110)
	check(not is_instance_valid(enemy),"retomar libera a remoção do Cactus derrotado")
	phase._pause()
	phase._restart_level()
	await frames(20)
	var alive := get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e._state != e.State.DEAD)
	check(alive.size() == get_nodes_in_group("enemies").size() and not alive.is_empty() and not paused,"reinício também remove cadáveres e zera a pausa")
	print("SESSION_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
