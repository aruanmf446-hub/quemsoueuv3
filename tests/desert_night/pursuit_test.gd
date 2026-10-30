extends SceneTree
## Cacto persegue quem passa direto por ele, mais rápido que a patrulha e mais lento que o
## jogador, e desiste quando o jogador se afasta. Fixtures reposicionam o jogador (invulnerável).
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func run() -> void:
	var phase: Node3D = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(30)
	var player: SidePlayer = phase._player
	player._invulnerable = 999.0
	var enemies: Array = get_nodes_in_group("enemies")
	enemies.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.x < b.global_position.x)
	var cactus: Node3D = enemies[0]
	for other: Node3D in enemies:
		if other != cactus: other.set_physics_process(false)
	var x: float = cactus.global_position.x
	# Chegar perto e voltar pelo mesmo lado não é "passar direto".
	player.global_position = Vector3(x-2.5,0.05,0)
	await frames(3)
	player.global_position = Vector3(x-3.5,0.05,0)
	await frames(3)
	check(cactus._pursue == 0.0,"aproximar e recuar pelo mesmo lado não dispara a perseguição")
	# Passar para o outro lado dentro da janela dispara a perseguição com o "!".
	x = cactus.global_position.x
	player.global_position = Vector3(x-2.5,0.05,0)
	await frames(3)
	player.global_position = Vector3(x+2.5,0.05,0)
	await frames(2)
	check(cactus._pursue > cactus.PURSUE_TIME-0.2,"passar direto pelo Cacto inicia a perseguição")
	check(cactus.get_children().any(func(c: Node) -> bool: return c is Label3D and c.text == "!"),"Cacto mostra o \"!\" ao começar a perseguir")
	# Fora do alcance normal (5,5 m), mas dentro do da perseguição: corre atrás a 5 m/s.
	player.global_position = Vector3(cactus.global_position.x+9.0,0.05,0)
	await frames(12)
	check(cactus.velocity.x > cactus.PURSUE_SPEED-0.05,"persegue o jogador além do alcance normal, a %.1f m/s" % cactus.velocity.x)
	check(cactus.PURSUE_SPEED < SidePlayer.SPEED,"perseguição mais lenta que a corrida: dá para fugir correndo")
	# Longe demais: desiste e volta a patrulhar.
	player.global_position = Vector3(cactus.global_position.x+30.0,0.05,0)
	await frames(3)
	check(cactus._pursue == 0.0,"jogador longe demais: o Cacto desiste")
	await frames(90)
	check(cactus.global_position.x <= cactus._patrol_max+0.5 or cactus.velocity.x < 0.0,"depois de desistir, volta para a área de patrulha")
	print("PURSUIT_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
