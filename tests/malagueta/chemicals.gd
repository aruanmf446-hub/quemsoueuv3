extends SceneTree
const Chemical=preload("res://scripts/desert/malagueta/chemical.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var phase:=load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	phase.set("opening_grace",0.0) # mecânica sem o respiro de entrada
	root.add_child(phase)
	current_scene=phase
	phase.encounter.restore(2)
	phase.encounter._green_wait=0
	phase.encounter._red_wait=0
	phase.encounter.tick(0.1)
	phase.encounter.suspended=true
	# Throw animations serialize releases; the two real projectiles must still overlap.
	for frame in 180:await physics_frame
	var green: Node3D
	var red: Node3D
	for child in phase.arena.get_children():
		if child is Chemical:
			child.set_physics_process(false)
			if child.kind=="green":green=child
			else:red=child
	assert(is_instance_valid(green) and is_instance_valid(red))
	print("CHEMICAL_PASS both attacks active in phase3")
	green._physics_process(1.0)
	red._physics_process(1.0)
	var straight_green: Vector3=green.start+green.direction*green.speed*(green.elapsed-green.warning)
	var straight_red: Vector3=red.start+red.direction*red.speed*(red.elapsed-red.warning)
	assert(absf(green.position.y-straight_green.y)>0.1)
	assert(red.position.is_equal_approx(straight_red))
	print("CHEMICAL_PASS wave and directed red keep different trajectories")
	phase.encounter.suspended=false
	phase.encounter.hit(4)
	assert(not green.active and not red.active)
	print("CHEMICAL_PASS stun clears dangerous projectiles")
	phase.queue_free()
	await process_frame
	quit()
