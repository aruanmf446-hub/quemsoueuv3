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
	var previous: Node3D = null
	for target: Node3D in route:
		var arrived := false
		var airborne := -1
		var stable := 0
		for frame in 1200:
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_release("jump")
			Input.action_release("crouch")
			var on_target: bool=player.is_on_floor() and absf(player.position.y-target.global_position.y)<0.25
			# A real double jump can skip a lower blade. Do not force the player back down.
			var passed: bool=player.is_on_floor() and player.position.y>target.global_position.y+0.25
			if passed or (on_target and absf(player.position.x-target.global_position.x)<1.0):
				stable+=1
				if stable>=6:
					arrived=true
					break
			else:stable=0
			var point: Vector3=target.global_position
			if player.is_on_floor():
				airborne=-1
				var rise: float=target.global_position.y-player.position.y
				if rise>0 and rise<1.75 and absf(point.x-player.position.x)<4.6 and absf(point.x-player.position.x)>2.9:
					Input.action_press("jump")
					airborne=0
				elif on_target:
					point=target.global_position
				elif previous!=null:
					if absf(target.global_position.x-player.global_position.x)<2.6:Input.action_press("crouch")
					# Ride the current cutter until the next crossing is in jump range.
					point=previous.global_position-Vector3(signf(target.global_position.x-player.global_position.x)*0.45,0,0)
				else:point=Vector3(-11,0,0)
			if airborne>=0:
				airborne+=1
				if airborne==30:Input.action_press("jump")
			var dx: float=point.x-player.global_position.x
			if absf(dx)>0.2:Input.action_press("move_right" if dx>0 else "move_left")
			await tick(1)
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("jump")
		print("TRAVERSE ",target.global_position," result=",arrived," player=",player.position," health=",player.health)
		if not arrived:
			failures+=1
			break
		previous=target
	if player.health!=player.RUN_MAX_HEALTH: failures+=1
	print("TRAVERSAL_HEALTH ",player.health)
	print("TRAVERSAL_SUMMARY failures=",failures)
	phase.queue_free()
	await tick(2)
	quit(1 if failures else 0)
