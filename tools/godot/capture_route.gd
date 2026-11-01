extends SceneTree
## Captura real do lobby (como visitante) ou de uma rota aberta pela navegação.
## Uso: --script res://tools/godot/capture_route.gd -- <saida.png> <LxA> [rota] [json_params]
func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "/tmp/route.png"
	var requested := (args[1] if args.size() > 1 else "1920x1080").split("x")
	var route := args[2] if args.size() > 2 else ""
	var params: Dictionary = JSON.parse_string(args[3]) if args.size() > 3 else {}
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(requested[0]), int(requested[1]))
	await process_frame
	var scene := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	for frame in range(20):
		await process_frame
	var navigation: Node = scene.get_node("Navigation")
	var history: Array = navigation.get("_history")
	if not history.is_empty() and history.back().route == "account":
		navigation.call("back")
		await _settle(navigation)
	if not route.is_empty():
		navigation.call("open", route, params)
		await _settle(navigation)
	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	print("CAPTURED ", output)
	quit(0)


func _settle(navigation: Node) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	await process_frame
	while navigation.get("_busy") and Time.get_ticks_msec() < deadline:
		await process_frame
