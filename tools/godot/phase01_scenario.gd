extends SceneTree
## Roteiro jogável da Fase 01 em janela real, com as ações reais do jogo (move_right, jump,
## crouch, defend, attack). Cada etapa verifica o efeito e salva uma captura.
## godot --path . -s res://tools/godot/phase01_scenario.gd -- <saida_prefixo> [WxH]

const PHYSICS_FPS := 60.0
const PLATFORMS_PATH := "res://data/desert/phase_01.json"
const NO_FLOOR := -INF
const COMBAT_RANGE := 1.3

var failures := 0
var _prefix := "phase01"
var _phase: Node3D
var _player: SidePlayer
var _platforms: Array = []
var _blocked := 0
var _deaths := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_prefix = args[0] if not args.is_empty() else "phase01"
	var size := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]), int(size[1]))
	await physics_frame
	_platforms = (JSON.parse_string(FileAccess.get_file_as_string(PLATFORMS_PATH)) as Dictionary).get("platforms", [])
	_phase = load("res://scenes/desert/phase_01.tscn").instantiate() as Node3D
	root.add_child(_phase)
	current_scene = _phase
	await _seconds(0.8)
	_player = _phase.get("_player")
	_player.blocked.connect(func() -> void: _blocked += 1)
	_player.died.connect(func() -> void: _deaths += 1)
	check(_player.is_on_floor(), "spawn sobre o chão")
	await _snap("01_inicio")

	# Movimento lateral e animação de corrida
	var x0 := _player.global_position.x
	Input.action_press("move_right")
	await _seconds(0.8)
	Input.action_release("move_right")
	check(_player.global_position.x > x0 + 3.0, "corre para a direita (%.2f → %.2f)" % [x0, _player.global_position.x])
	check(_anim() == "base", "animação de corrida ao andar (%s)" % _anim())
	await _snap("02_correr")

	# Pulo e pulo duplo
	await _press("jump")
	await _seconds(0.12)
	check(_player.global_position.y > 0.5 and _anim() == "pulo", "pulo sobe com animação de pulo (y=%.2f, %s)" % [_player.global_position.y, _anim()])
	await _snap("03_pulo")
	var jump_height := _player.global_position.y
	await _press("jump")
	await _seconds(0.1)
	check(_player.jumps_used == 2 and _anim() == "pulo_duplo", "pulo duplo usa o segundo salto (%s)" % _anim())
	await _snap("04_pulo_duplo")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 2.0)
	await _seconds(0.1)
	check(_player.is_on_floor() and _player.jumps_used == 0, "aterrissagem zera a contagem de saltos")
	check(jump_height > 0.5, "salto simples alcança altura de plataforma")

	# Coyote time: saltar logo depois de sair da borda ainda conta como primeiro salto
	await _walk_to(2.0, 3.0, false)
	await _wait_until(func() -> bool: return not _player.is_on_floor(), 1.0)
	await _press("jump")
	await _seconds(0.05)
	check(_player.jumps_used == 1 and _player.velocity.y > 5.0, "coyote time: salto logo após sair da borda")
	await _wait_until(func() -> bool: return _player.is_on_floor(), 3.0)
	await _seconds(0.2)

	# Checkpoint 1 em x=12
	await _walk_to(12.6, 6.0)
	await _seconds(0.2)
	check(absf(float(_phase.get("_checkpoint").x) - 12.0) < 0.01, "checkpoint 1 registrado em x=12")
	await _snap("05_checkpoint")

	# Agachar encolhe a colisão e para o movimento
	var shape := _shape_of(_player)
	var stand_height := (shape.shape as CapsuleShape3D).height
	Input.action_press("crouch")
	await _seconds(0.35)
	check(_player.is_crouching and (shape.shape as CapsuleShape3D).height < stand_height and _anim() == "agachado", "agachar encolhe a colisão e toca 'agachado' (%s)" % _anim())
	await _snap("06_agachado")
	Input.action_release("crouch")
	await _seconds(0.3)
	check(not _player.is_crouching and is_equal_approx((shape.shape as CapsuleShape3D).height, stand_height), "soltar agachar restaura a colisão")

	# Defesa bloqueia o cacto de 14 m
	var cactus := _cactus_near(14.0)
	await _walk_to(13.0, 3.0, false)
	var health_before := _player.health
	var blocks_before := _blocked
	Input.action_press("defend")
	await _seconds(3.0)
	await _snap("07_defesa")
	check(_player.is_defending and _anim() == "defesa", "defesa ativa e toca 'defesa' (%s)" % _anim())
	check(_blocked > blocks_before, "defesa bloqueia ataque do cacto (%d bloqueios)" % (_blocked - blocks_before))
	check(_player.health == health_before, "defesa mantém a vida (%d → %d)" % [health_before, _player.health])
	Input.action_release("defend")
	await _seconds(0.2)

	# Ataque derrota o cacto escolhido
	await _attack(cactus, 10.0)
	check(cactus == null or not cactus.is_in_group("enemies"), "ataque derrota o cacto")
	await _snap("08_cacto_derrotado")

	# Queda no vão mata e reinicia no checkpoint
	var deaths_before := _deaths
	await _walk_to(24.0, 6.0, false)
	await _wait_until(func() -> bool: return _player.is_dead, 4.0)
	check(_player.is_dead and _deaths > deaths_before, "cair no vão causa morte")
	await _snap("09_morte")
	await _wait_until(func() -> bool: return not _player.is_dead and not bool(_phase.get("_respawning")), 4.0)
	await _seconds(0.2)
	check(_player.health == SidePlayer.MAX_HEALTH, "reinício com vida cheia")
	check(absf(_player.global_position.x - 12.0) < 0.6, "reinício no checkpoint (x=%.2f)" % _player.global_position.x)
	await _snap("10_reinicio")

	# Percurso até a saída, lutando contra cactos que bloqueiam o caminho
	var completed := false
	for attempt in 8:
		await _walk_to(52.0, 40.0, true, true)
		if bool(_phase.get("completed")):
			completed = true
			break
		if _player.is_dead:
			await _wait_until(func() -> bool: return not _player.is_dead and not bool(_phase.get("_respawning")), 4.0)
	check(completed, "fase concluída até a saída")
	await _seconds(0.5)
	await _snap("11_concluida")
	print("SCENARIO_STATS deaths=", _deaths, " blocked=", _blocked, " health=", _player.health)
	print("PHASE01_SCENARIO_FAILURES ", failures)
	quit(1 if failures > 0 else 0)


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(1)
	Input.action_release(action)


## Anda até `target_x`. Com auto_jump, pula antes de vãos e degraus. Com fight, ataca cactos
## que ficam no caminho em vez de ficar parado apanhando.
func _walk_to(target_x: float, timeout: float, auto_jump := true, fight := false) -> void:
	Input.action_press("move_right")
	var elapsed := 0.0
	while elapsed < timeout and _player.global_position.x < target_x and not _player.is_dead:
		var cactus := _cactus_ahead()
		if fight and cactus != null:
			Input.action_release("move_right")
			await _press("attack")
			await _seconds(0.45)
			Input.action_press("move_right")
		else:
			if auto_jump:
				await _auto_jump()
			await _frames(1)
		elapsed += 1.0 / PHYSICS_FPS
	Input.action_release("move_right")


func _auto_jump() -> void:
	var x := _player.global_position.x
	var y := _player.global_position.y
	if _player.is_on_floor():
		var ahead := _surface_ahead(x + 0.9)
		if ahead == NO_FLOOR or ahead > y + 0.3:
			await _press("jump")
	# No ar com um salto usado: pulo duplo para atravessar vão à frente ou subir degrau alto.
	elif _player.jumps_used == 1:
		var ahead := _surface_ahead(x + 0.9)
		# Degrau alto (topo acima de 1,5 m): o pulo duplo sai perto do ápice do primeiro salto.
		if (ahead == NO_FLOOR and y > 0.2) or (ahead > 1.5 and y >= 1.0 and y <= 1.6):
			await _press("jump")


## Topo mais alto do piso logo à frente, ou NO_FLOOR quando há vão.
func _surface_ahead(x: float) -> float:
	var best := NO_FLOOR
	for platform: Dictionary in _platforms:
		var center := float(platform["pos"][0])
		var half := float(platform["size"][0]) * 0.5
		var top := float(platform["pos"][1]) + float(platform["size"][1]) * 0.5
		if x >= center - half and x <= center + half:
			best = maxf(best, top)
	return best


## Ataca o cacto escolhido até ele sair do grupo "enemies" ou o tempo acabar.
func _attack(target: Node3D, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and target != null and target.is_in_group("enemies") and not _player.is_dead:
		var dx := target.global_position.x - _player.global_position.x
		if absf(dx) > COMBAT_RANGE:
			Input.action_press("move_right" if dx > 0.0 else "move_left")
			await _auto_jump()
			await _frames(1)
		else:
			# T15D impede atravessar o corpo do Cactus. Vire pelo input real e
			# ataque no alcance de combate, em vez de tentar entrar no alvo.
			Input.action_release("move_right")
			Input.action_release("move_left")
			Input.action_press("move_right" if dx > 0 else "move_left")
			await _frames(2)
			Input.action_release("move_right")
			Input.action_release("move_left")
			await _press("attack")
			await _seconds(0.65)
		elapsed += 1.0 / PHYSICS_FPS
	Input.action_release("move_right")
	Input.action_release("move_left")


## Cacto vivo à frente do jogador, dentro do alcance de combate.
func _cactus_ahead() -> Node3D:
	for enemy: Node3D in get_nodes_in_group("enemies"):
		var dx := enemy.global_position.x - _player.global_position.x
		if dx > -0.2 and dx <= COMBAT_RANGE and absf(enemy.global_position.y - _player.global_position.y) < 1.2:
			return enemy
	return null


## Cacto vivo mais próximo de `x`, usado para escolher o alvo do teste de combate.
func _cactus_near(x: float) -> Node3D:
	var best: Node3D = null
	for enemy: Node3D in get_nodes_in_group("enemies"):
		if best == null or absf(enemy.global_position.x - x) < absf(best.global_position.x - x):
			best = enemy
	return best


func _shape_of(player: SidePlayer) -> CollisionShape3D:
	for child in player.get_children():
		if child is CollisionShape3D:
			return child
	return null


func _anim() -> String:
	var model := _player.get_node("Model")
	var player: AnimationPlayer = model.get("_anim_player")
	return player.current_animation if player != null and player.is_playing() else "-"


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, label])


func _wait_until(condition: Callable, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and not condition.call():
		await _frames(1)
		elapsed += 1.0 / PHYSICS_FPS


func _seconds(seconds: float) -> void:
	await _frames(int(seconds * PHYSICS_FPS))


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
