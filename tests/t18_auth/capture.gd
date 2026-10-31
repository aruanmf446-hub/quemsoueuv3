extends SceneTree
## Captura verdadeira do Control Godot, com renderer real/Xvfb em Actions.
## Sem contas, sem HTTP ou screenshot sintetizada.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var dest := OS.get_environment("T18_CAPTURE_DIR")
	if dest.is_empty():
		dest = "/tmp/t18-auth-captures"
	DirAccess.make_dir_recursive_absolute(dest)
	var services := PlayerServices.new()
	services.name = "Services"
	root.add_child(services)
	var scene := load("res://scenes/player/account.tscn").instantiate() as PlayerScreen
	if scene == null:
		push_error("T18_CAPTURE_FAIL scene")
		quit(1)
		return
	root.add_child(scene)
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(844, 390), Vector2i(640, 360)]:
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.size = resolution
		scene.size = Vector2(resolution)
		scene.show_screen()
		await process_frame
		await process_frame
		await process_frame
		scene.call("_layout_auth")
		await process_frame
		var picture := root.get_texture().get_image()
		if picture == null or picture.is_empty():
			push_error("T18_CAPTURE_FAIL renderer " + str(resolution))
			quit(1)
			return
		var name := "auth_%dx%d.png" % [resolution.x, resolution.y]
		var result := picture.save_png(dest.path_join(name))
		if result != OK:
			push_error("T18_CAPTURE_FAIL write " + name)
			quit(1)
			return
		print("T18_CAPTURE_OK ", name, " actual=", picture.get_size())
	quit(0)
