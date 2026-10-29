extends SceneTree
## Trecho contínuo de execução: nenhuma posição é atribuída após o spawn.
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	var phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(35)
	var player: SidePlayer = phase._player
	Input.action_press("move_right")
	for frame in range(160):
		if player.position.x >= 0.9: break
		await physics_frame
	await tap("jump")
	await frames(24)
	await tap("jump")
	for frame in range(140):
		var close := false
		for enemy: Node3D in get_nodes_in_group("enemies"):
			var dx := enemy.position.x-player.position.x
			if dx > 0 and dx < 1.5 and absf(enemy.position.y-player.position.y) < 1.0: close = true
		if player.position.x >= 11.0 or player.is_dead or close: break
		await physics_frame
	Input.action_release("move_right")
	await frames(12)
	Input.action_press("defend")
	await frames(80)
	Input.action_release("defend")
	await tap("attack")
	await frames(42)
	await tap("attack")
	await frames(50)
	print("DEMO_CONTINUOUS x=",player.position.x," health=",player.health," dead=",player.is_dead)
	quit()
