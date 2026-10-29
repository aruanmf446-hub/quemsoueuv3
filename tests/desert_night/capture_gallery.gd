extends SceneTree
## Capturas reais do Godot para revisão dos distritos 01, 05 e 09.
const Progress = preload("res://scripts/desert/t15d/campaign_progress.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if args.size() > 0 else "/tmp/desert-night-gallery"
	var dimensions := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var failures := 0
	for order in [1, 5, 9]:
		for previous in range(1, order):
			Progress.complete(previous)
		var phase: Node3D = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene = phase
		for frame in range(35):
			await physics_frame
		await RenderingServer.frame_post_draw
		var path := "%s_fase_%02d.png" % [output, order]
		var error := root.get_texture().get_image().save_png(path)
		print("CAPTURE ", path, " ", error)
		if error != OK:
			failures += 1
		root.remove_child(phase)
		phase.queue_free()
		current_scene = null
		await process_frame
	quit(1 if failures else 0)
