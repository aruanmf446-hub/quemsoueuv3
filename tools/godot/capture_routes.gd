extends SceneTree
## Captura real de cada rota de menu em janela. Uso:
## godot --path . -s res://tools/godot/capture_routes.gd -- <prefixo> <WxH> <rota1,rota2,...>
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0]
	var size := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]), int(size[1]))
	await process_frame
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for frame in range(40):
		await process_frame
	await _shot(prefix + "_lobby")
	var nav: Node = menu.get_node("Navigation")
	for route: String in args[2].split(","):
		nav.call("open", route, {})
		for frame in range(90):
			await process_frame
		await _shot(prefix + "_" + route)
		nav.call("back")
		for frame in range(30):
			await process_frame
	quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s.png" % name)
	print("SHOT ", name)
