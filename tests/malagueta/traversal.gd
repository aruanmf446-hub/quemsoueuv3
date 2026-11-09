extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func tick(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var phase := load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	root.add_child(phase)
	current_scene=phase
	await tick(6)
	phase.encounter.suspended=true
	var player: Node3D=phase._player
	player._invulnerable=0
	player.position=Vector3(-11,0.1,0)
	player.velocity=Vector3.ZERO
	await tick(10)
	var route: Array=phase.files.slice(0,5)
	var landing := Node3D.new()
	landing.position=Vector3(9,6.6,0)
	phase.add_child(landing)
	route.append(landing)
	for target: Node3D in route:
		Input.action_press("jump")
		await tick(1)
		Input.action_release("jump")
		var arrived := false
		for frame in 150:
			var dx: float=target.global_position.x-player.global_position.x
			Input.action_release("move_left")
			Input.action_release("move_right")
			if absf(dx)>0.3: Input.action_press("move_right" if dx>0 else "move_left")
			if frame==18: Input.action_press("jump")
			if frame==19: Input.action_release("jump")
			await tick(1)
			if frame>24 and player.is_on_floor() and absf(player.position.y-target.global_position.y)<0.25:
				arrived=true
				break
		Input.action_release("move_left")
		Input.action_release("move_right")
		await tick(15)
		print("TRAVERSE ",target.global_position," result=",arrived," player=",player.position)
		if not arrived:
			failures+=1
			break
	if player.health!=player.RUN_MAX_HEALTH: failures+=1
	print("TRAVERSAL_HEALTH ",player.health)
	print("TRAVERSAL_SUMMARY failures=",failures)
	phase.queue_free()
	await tick(2)
	quit(1 if failures else 0)
