extends SceneTree
## Real rendered frames, no image compositing or backend configuration.
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "/tmp/lobby.png"
	var requested := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(requested[0]), int(requested[1]))
	await process_frame
	var scene := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	for frame in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	var actual := DisplayServer.window_get_size()
	assert(actual == Vector2i(int(requested[0]), int(requested[1])), "Requested resolution was not applied")
	var bounds := Rect2(Vector2.ZERO, scene.size)
	for path: String in ["MenuButtons", "ProfileCard", "TopBar", "FriendsPanel", "LobbyArea/Overlay/NameLabel"]:
		var control: Control = scene.get_node(path)
		if not bounds.encloses(control.get_global_rect()):
			push_error("LOBBY_OUT_OF_BOUNDS " + path + " " + str(control.get_global_rect()))
			quit(1)
			return
	var buttons: Control = scene.get_node("MenuButtons")
	assert(buttons.get_global_rect().end.y < scene.get("_mode_label").position.y, "Menu overlaps status")
	assert(buttons.size.x < scene.size.x * 0.23, "Side menu must remain compact")
	var stage: LobbyStage = scene.get_node("LobbyArea/Stage")
	var camera: Camera3D = stage.get_node("Viewport/World/Camera")
	var framing := stage.character.get_framing()
	var top := camera.unproject_position(Vector3(0, float(framing.height), 0))
	var feet := camera.unproject_position(Vector3.ZERO)
	var hero_ratio: float = absf(feet.y - top.y) / stage.get_node("Viewport").size.y * stage.size.y / scene.size.y
	assert(hero_ratio > 0.68 and hero_ratio < 0.80, "Hero framing outside target")
	assert(scene.get_node("MenuMusic").stream == null, "Unapproved audio")
	var picture := root.get_texture().get_image()
	assert(picture.get_size() == actual, "Capture must match native window pixels")
	var error := picture.save_png(output)
	print("LOBBY_CAPTURE ", actual, " logical=", scene.size, " hero_ratio=", hero_ratio, " file=", output)
	quit(0 if error == OK else 1)
