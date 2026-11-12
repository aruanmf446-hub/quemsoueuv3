extends SceneTree
func _initialize() -> void: call_deferred("run")
func tick(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var phase:=load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	phase.set("opening_grace",0.0) # mecânica sem o respiro de entrada
	root.add_child(phase)
	current_scene=phase
	await tick(8)
	phase.encounter.hit(4)
	assert(phase.encounter.complete_task(1))
	assert(phase._snapshot.tasks.has("malagueta.task.1"))
	phase._respawn_at_checkpoint()
	await tick(8)
	assert(phase.encounter.completed_tasks==1)
	assert(phase.encounter.state==phase.encounter.State.PHASE_2_RED)
	assert(phase._raised_bridges.has("malagueta.task.1"))
	phase._save_active_run()
	var state: Dictionary=phase.Run.read(phase._save_owner).state
	assert(phase.Run.valid(state))
	assert(state.tasks.has("malagueta.task.1"))
	print("CHECKPOINT_PASS completed Task survives retry and valid save")
	for task in [2,3]:
		phase.encounter.hit(4)
		assert(phase.encounter.complete_task(task))
	phase._respawn_at_checkpoint()
	assert(phase.encounter.completed_tasks==3 and phase.encounter.state==phase.encounter.State.CHEMICAL_REACTION)
	await tick(100)
	assert(phase.completed and phase._boss_defeated)
	print("CHECKPOINT_PASS Task3 resumes reaction and finishes after interruption")
	phase.queue_free()
	await tick(3)
	quit()
