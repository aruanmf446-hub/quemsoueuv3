extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("ARENA_", "PASS " if ok else "FAIL ",label)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	# Isolated local fixture: phase10 is entered after completing the preceding nine.
	assert(preload("res://scripts/desert/t15d/campaign_progress.gd").merge_highest(OwnerStorage.owner_id(),9)==OK)
	var phase := load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	root.add_child(phase)
	current_scene=phase
	await ticks(5)
	check(is_instance_valid(phase._player),"existing player opens")
	check(phase.files.size()==5,"five flat moving files")
	check(phase._order==10,"only phase10 replaced")
	check(phase._player.attack_charges==3 and phase._player.defense_charges==3,"initial charges bounded three")
	var file: Node3D=phase.files[0]
	var initial: Vector3=file.position
	await ticks(25)
	check(absf(file.position.x-initial.x)>0.05,"file actually moves")
	check(absf(file.position.x-file.origin.x)<=file.travel+0.01,"file respects travel")
	while file.position.x < -10.0:await ticks(1)
	phase._player.position=file.global_position+Vector3.UP*0.08
	phase._player.velocity=Vector3.ZERO
	phase._player._invulnerable=100
	await ticks(30)
	check(phase._player.is_on_floor(),"actual player rests on moving top")
	check(absf(phase._player.position.y-file.position.y)<0.2,"no fall through platform")
	var cam: Vector3=phase._camera.position
	phase._player.position.x+=1
	await ticks(5)
	check(phase._camera.position==cam,"camera fixed")
	phase.encounter.suspended=true
	phase._player.position=Vector3(7.8,8.95,0)
	phase._player.velocity=Vector3.ZERO
	await ticks(15)
	check(phase._near_boss_task(),"upper landing supports Task")
	phase._player.attack_charges=0
	phase._player.defense_charges=0
	phase.encounter.suspended=false
	phase.encounter.hit(4)
	check(phase._player.attack_charges==3 and phase._player.defense_charges==3,"Task fills existing skills")
	phase.encounter.tick(5.01)
	check(phase.encounter.completed_tasks==0,"failure does not advance")
	for task in range(1,4):
		phase.encounter.hit(4)
		await ticks(2)
		if task==2:
			phase._hud._bridge_task.pressed.emit()
		else:
			var key:=InputEventKey.new()
			key.physical_keycode=KEY_F
			key.pressed=true
			root.push_input(key)
			key=key.duplicate()
			key.pressed=false
			root.push_input(key)
		await ticks(1)
		check(phase.encounter.completed_tasks==task,"Task input progresses "+str(task))
		check(phase._raised_bridges.has("malagueta.task.%d" % task),"Task stored once")
	phase.encounter.tick(2)
	check(phase._boss_defeated and phase.completed,"chemical reaction triggers existing completion")
	check(phase._boss._state==phase._boss.State.DEAD,"existing boss death state applied")
	check(phase._saved and phase.Progress.is_completed(10),"existing progression persists phase10 completion")
	phase.queue_free()
	await ticks(3)
	print("ARENA_SUMMARY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
