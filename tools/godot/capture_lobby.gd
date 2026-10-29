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
	if actual != Vector2i(int(requested[0]), int(requested[1])):
		print("LAYOUT_WARN resolution_not_applied ", actual)
	var bounds := Rect2(Vector2.ZERO, scene.size)
	for path: String in ["MenuButtons", "ProfileCard", "TopBar", "FriendsPanel", "LobbyArea/Overlay/NameLabel"]:
		var control: Control = scene.get_node(path)
		if not bounds.encloses(control.get_global_rect()):
			push_error("LOBBY_OUT_OF_BOUNDS " + path + " " + str(control.get_global_rect()))
			quit(1)
			return
	var buttons: Control = scene.get_node("MenuButtons")
	# Avisos em vez de assert: assert em modo janela trava o processo sem salvar a captura.
	# Mede o último botão visível, não o contêiner (o VBox pode ser mais alto que o conteúdo).
	var last_button: Control = buttons.get_child(buttons.get_child_count() - 1)
	if last_button.get_global_rect().end.y >= scene.get("_mode_label").position.y:
		print("LAYOUT_WARN menu_overlaps_status buttons_end=", last_button.get_global_rect().end.y, " status_y=", scene.get("_mode_label").position.y)
	if buttons.size.x >= scene.size.x * 0.23:
		print("LAYOUT_WARN side_menu_wide ", buttons.size.x)
	var stage: LobbyStage = scene.get_node("LobbyArea/Stage")
	var camera: Camera3D = stage.get_node("Viewport/World/Camera")
	var framing := stage.character.get_framing()
	var top := camera.unproject_position(Vector3(0, float(framing.height), 0))
	var feet := camera.unproject_position(Vector3.ZERO)
	var hero_ratio: float = absf(feet.y - top.y) / stage.get_node("Viewport").size.y * stage.size.y / scene.size.y
	if not (hero_ratio > 0.68 and hero_ratio < 0.80):
		print("LAYOUT_WARN hero_framing ", hero_ratio)
	if scene.get_node("MenuMusic").stream != null:
		print("LAYOUT_WARN unapproved_audio")
	var picture := root.get_texture().get_image()
	if picture.get_size() != actual:
		print("LAYOUT_WARN capture_size ", picture.get_size(), " vs ", actual)
	var error := picture.save_png(output)
	print("LOBBY_CAPTURE ", actual, " logical=", scene.size, " hero_ratio=", hero_ratio, " file=", output)
	quit(0 if error == OK else 1)
