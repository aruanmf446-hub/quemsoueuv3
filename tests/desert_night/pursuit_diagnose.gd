extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	phase._player._invulnerable = 999
	Input.action_press("move_right")
	for frame in range(900):
		await physics_frame
		if frame%180 == 0:
			print("PLAYER ",phase._player.position)
			for e in phase._troops.get_children(): print("CACTUS ",e.position," velocity=",e.velocity," edge=",e.blocked_at_edge," pursuit=",e._pursue," floor=",e.is_on_floor()," processing=",e.can_process())
	Input.action_release("move_right")
	quit()
