extends SceneTree
## Capturas locais de revisão; habilidades concedidas SOMENTE nesta fixture isolada.
var failures := 0
func _initialize() -> void: call_deferred("run")
func settle(phase: Node3D,count: int) -> void:
	for frame in range(count):
		if paused and is_instance_valid(phase): phase._resume()
		paused = false
		await process_frame
func audit(phase: Node3D) -> void:
	var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
	var status: Rect2 = phase._hud._status.get_global_rect()
	var pause: Rect2 = phase._hud._pause.get_global_rect()
	if not bounds.encloses(status) or not bounds.encloses(pause) or status.intersects(pause):
		failures += 1
		print("FAIL HUD status/pause bounds ",phase._phase.name," ",status," ",pause)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size() else "/tmp/reino-v3"
	DirAccess.make_dir_recursive_absolute(output)
	var dimensions := (args[1] if args.size()>1 else "1672x941").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	var records: Array = []
	for order in range(1,10):
		var phase: Node3D = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene = phase
		phase._player.position.y = 0.02
		await settle(phase,8)
		if order >= 2: phase._player.restore_charge("rupture")
		if order >= 4: phase._player.restore_charge("amber")
		if order >= 6: phase._player.restore_charge("dash")
		phase._player.inventory_changed.emit()
		await settle(phase,3)
		await RenderingServer.frame_post_draw
		audit(phase)
		var file := "%s/fase_%02d.png" % [output,order]
		var error := root.get_texture().get_image().save_png(file)
		if error != OK: failures += 1
		records.append({"order":order,"name":phase._phase.name,"viewport":root.get_visible_rect().size,"window":root.size,"iphone":UIScale.is_iphone(),"image":file,"result":error})
		print("CAPTURE ",file," result=",error)
		phase._player._invulnerable = 999.0
		phase._player.position = phase._vec3(phase._phase.checkpoints[3].pos)+Vector3.UP*0.05
		phase._player.velocity = Vector3.ZERO
		phase._stream_world(phase._player.position.x,true)
		phase._follow_camera(1.0)
		phase._player.set_physics_process(false)
		await settle(phase,6)
		phase._player._model.visible = true
		await RenderingServer.frame_post_draw
		audit(phase)
		var middle_file := "%s/fase_%02d_distrito05_fixture.png" % [output,order]
		var middle_error := root.get_texture().get_image().save_png(middle_file)
		if middle_error != OK: failures += 1
		records.append({"order":order,"name":phase._phase.name,"fixture_teleport":true,"district":5,"viewport":root.get_visible_rect().size,"window":root.size,"iphone":UIScale.is_iphone(),"image":middle_file,"result":middle_error})
		print("CAPTURE ",middle_file," result=",middle_error)
		root.remove_child(phase)
		phase.queue_free()
		current_scene = null
		paused = false
		for frame in range(3): await process_frame
	var report := FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(records,"\t"))
	print("REINO_GALLERY failures=",failures)
	quit(1 if failures else 0)
