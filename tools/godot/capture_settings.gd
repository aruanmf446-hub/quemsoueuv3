extends SceneTree
## Capturas reais das cinco categorias de Configurações.
## Uso: --script res://tools/godot/capture_settings.gd -- <pasta> <LxA>
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dims := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	await process_frame
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for i in 20: await process_frame
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		for i in 30: await process_frame
	nav.open("settings", {})
	for i in 30: await process_frame
	var screen: Node = nav.get("_active")
	for index in range(5):
		screen._select(index)
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/settings_%d_%s.png" % [args[0], index, args[1]])
		print("CAPTURED ", index)
	quit(0)
