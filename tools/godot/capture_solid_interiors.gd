extends SceneTree
## Real offline screens. Friend/chat fixtures are captured separately by the existing tests.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var parts := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(args[0])
	var services := PlayerServices.new()
	root.add_child(services)
	var routes: Dictionary = PlayerContracts.read_json("res://data/ui/routes.json").routes
	for route: String in ["settings", "deck_library", "music"]:
		var screen := load(routes[route]).instantiate() as PlayerScreen
		root.add_child(screen)
		screen.show_screen()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(args[0].path_join(route + ".png"))
		if error != OK: quit(1); return
		screen.queue_free()
		await process_frame
	services.queue_free()
	await process_frame
	quit()
