extends SceneTree
## Peças de parkour: gêiser leva por cima da muralha nos dois sentidos; pedra do vão largo
## desmorona depois de pisada e volta; telhados em escada são escaláveis.
## Fixtures reposicionam o jogador perto de cada peça; o resto é feito por entradas.
var failures := 0
var checks := 0
var phase: Node3D
var player: SidePlayer
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func place(x: float) -> void:
	player.position = Vector3(x,0.05,0)
	player.velocity = Vector3.ZERO
	phase._stream_world(x,true)
	for actor in get_nodes_in_group("enemies"): actor.queue_free()
	await frames(10)
func walk(action: String, until: Callable, limit := 600) -> float:
	var top := -INF
	Input.action_press(action)
	for step in range(limit):
		await physics_frame
		top = maxf(top, player.position.y)
		if until.call(): break
	Input.action_release(action)
	return top
func run() -> void:
	Engine.physics_ticks_per_second = 60
	phase = load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(30)
	player = phase._player
	var wall: Dictionary
	for platform: Dictionary in phase._phase.platforms:
		if platform.kind == "geyser_wall": wall = platform; break
	var wx := float(wall.pos[0])
	await place(wx-7.0)
	var top := await walk("move_right", func() -> bool: return player.position.x > wx+3.0 and player.is_on_floor())
	check(player.position.x > wx+3.0 and not player.is_dead,"gêiser leva por cima da muralha indo para a direita")
	check(top > 4.3,"lançamento passa da altura da muralha (%.1fm)" % top)
	check(player.jumps_used == 0,"pulo volta ao normal depois de aterrissar")
	top = await walk("move_left", func() -> bool: return player.position.x < wx-3.0 and player.is_on_floor())
	check(player.position.x < wx-3.0 and not player.is_dead,"gêiser do outro lado traz de volta")
	# Pedra que desmorona: salta da borda, solta a direção sobre a pedra e pousa nela.
	var hole: Dictionary
	for candidate: Dictionary in phase._phase.holes:
		if candidate.stepping: hole = candidate; break
	var center := (float(hole.start)+float(hole.end))*0.5
	await place(float(hole.start)-3.0)
	var landed := await hop_to_stone(1.0, float(hole.start), center)
	check(landed,"salto alcança a pedra no meio do vão largo")
	var stone: Node3D
	for node in get_nodes_in_group("crumble_stones"):
		if absf(node.global_position.x-center) < 0.1: stone = node
	await frames(45)
	check(stone != null and stone._shape.disabled,"pedra desmorona pouco depois de pisada")
	for step in range(200):
		if player.is_dead: break
		await physics_frame
	check(player.is_dead,"ficar parado na pedra derruba no vão")
	for step in range(200):
		if phase._session.opened: break
		await physics_frame
	(phase._session._column.get_children().filter(func(c: Node) -> bool: return c is Button)[0] as Button).pressed.emit()
	await frames(10)
	await place(float(hole.start)-3.0)
	await frames(160)
	var restored := false
	for node in get_nodes_in_group("crumble_stones"):
		if absf(node.global_position.x-center) < 0.1 and not node._shape.disabled: restored = true
	check(restored,"pedra volta para uma nova tentativa")
	# Dois saltos: borda → pedra → outra borda, nos dois sentidos.
	check(await hop_to_stone(1.0, float(hole.start), center) and await hop_off(1.0, float(hole.end)),"vão largo atravessado indo")
	await frames(170)
	check(await hop_to_stone(-1.0, float(hole.end), center) and await hop_off(-1.0, float(hole.start)),"vão largo atravessado voltando")
	print("PARKOUR_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func hop_to_stone(direction: float, edge: float, center: float) -> bool:
	var action := "move_right" if direction > 0 else "move_left"
	Input.action_press(action)
	while (player.position.x-(edge-direction*0.5))*direction < 0.0: await physics_frame
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	while (player.position.x-(center-direction*0.4))*direction < 0.0 and not player.is_dead: await physics_frame
	Input.action_release(action)
	for step in range(90):
		await physics_frame
		if player.is_on_floor() and absf(player.position.x-center) < 0.9: return true
	return false
func hop_off(direction: float, far_edge: float) -> bool:
	var action := "move_right" if direction > 0 else "move_left"
	Input.action_press(action)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	for step in range(120):
		await physics_frame
		if player.is_on_floor() and (player.position.x-far_edge)*direction > 0.3: break
	Input.action_release(action)
	return (player.position.x-far_edge)*direction > 0.0 and not player.is_dead
