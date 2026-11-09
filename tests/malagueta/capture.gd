extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var phase := load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	root.add_child(phase)
	current_scene=phase
	phase._player._invulnerable=999
	phase.encounter.suspended=true
	for dimensions: Vector2i in [Vector2i(1672,941),Vector2i(844,390),Vector2i(640,360)]:
		root.size=dimensions
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("arena_%dx%d.png" % [dimensions.x,dimensions.y]))
	phase.queue_free()
	await process_frame
	quit()
