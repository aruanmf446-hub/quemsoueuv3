extends SceneTree
func _initialize() -> void: call_deferred("run")
func tick(n: int) -> void:
	for i in n: await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var phase := load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	root.add_child(phase)
	current_scene=phase
	await tick(5)
	phase._player.position=Vector3(9,8.95,0)
	phase._player.velocity=Vector3.ZERO
	phase._player._invulnerable=999
	phase.encounter.restore(2)
	phase.encounter.suspended=true
	phase.cactus_interval=999
	phase._cactus_wait=0
	await tick(3)
	var maximum := 0.0
	var enemy: Node3D=phase._troops.get_child(0)
	# Two full blade sweeps are now longer than the old 12-second patrol.
	for frame in 5400:
		await tick(1)
		maximum=maxf(maximum,enemy.position.y)
		if frame%60==0: print("CACTUS_TRACE ",frame," ",enemy.position)
		if enemy.position.y>=8.65 and enemy.is_on_floor(): break
	var ok := maximum>=8.65
	print("PURSUIT_TOP ",ok," max_y=",maximum," final=",enemy.position)
	phase._player.position=Vector3(-10.5,0.1,0)
	phase._player.velocity=Vector3.ZERO
	var descended:=false
	# Two full blade sweeps are now longer than the old 12-second patrol.
	for frame in 2400:
		await tick(1)
		if enemy.position.y<0.2 and enemy.is_on_floor():
			descended=true
			break
	print("PURSUIT_DESCENT ",descended," final=",enemy.position)
	for i in 6:
		phase._cactus_wait=0
		phase._update_troops()
	var bounded: bool=phase._troops.get_child_count()<=phase.max_cacti
	print("PURSUIT_LIMIT ",bounded)
	phase.queue_free()
	await tick(3)
	quit(0 if ok and bounded and descended else 1)
