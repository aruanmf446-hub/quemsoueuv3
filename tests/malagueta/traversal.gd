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
	landing.position=Vector3(9,8.85,0)
	phase.add_child(landing)
	route.append(landing)
	for target: Node3D in route:
		var arrived := false
		var airborne := -1
		var stable := 0
		for frame in 4500:
			for action in ["move_left","move_right","jump","crouch"]:Input.action_release(action)
			var ready: bool=not target.has_method("is_available") or target.is_available()
			var tolerance: float=0.18 if target.has_method("is_available") else 0.02
			var on_target: bool=ready and player.is_on_floor() and absf(player.position.y-target.global_position.y)<tolerance and absf(player.position.x-target.global_position.x)<1.65
			if on_target:
				stable+=1
				if stable>=4:
					arrived=true
					break
			else:stable=0
			if player.is_on_floor():
				airborne=-1
				var distance: float=absf(target.global_position.x-player.position.x)
				if not on_target and ready and distance<5.3 and target.global_position.y>player.position.y-0.1:
					Input.action_press("jump");airborne=0
			if airborne>=0:
				airborne+=1
				if airborne==30:Input.action_press("jump")
				var point: Vector3=target.future_position(0.2) if target.has_method("future_position") else target.global_position
				var dx: float=point.x-player.position.x
				if airborne>12 and absf(dx)>0.22:Input.action_press("move_right" if dx>0 else "move_left")
			await tick(1)
		for action in ["move_left","move_right","jump","crouch"]:Input.action_release(action)
		print("HANDOFF ",target.global_position," result=",arrived," player=",player.position," health=",player.health)
		if not arrived:
			failures+=1
			break
	if player.health!=player.RUN_MAX_HEALTH: failures+=1
	print("TRAVERSAL_HEALTH ",player.health)
	print("TRAVERSAL_SUMMARY failures=",failures)
	phase.queue_free()
	await tick(2)
	quit(1 if failures else 0)
