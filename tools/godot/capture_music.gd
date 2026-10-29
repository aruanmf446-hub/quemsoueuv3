extends SceneTree
## Captura real da tela Músicas em janela. Uso:
## godot --path . -s res://tools/godot/capture_music.gd -- <saida.png> <WxH> <inicio|rascunho>
## "rascunho" mostra a categoria Pop com uma faixa oculta, sem salvar.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "music.png"
	var requested := (args[1] if args.size() > 1 else "1920x1080").split("x")
	var mode := args[2] if args.size() > 2 else "inicio"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(requested[0]), int(requested[1]))
	await process_frame
	var music: Node = root.get_node("MenuMusic")
	music.set_process(false)
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for frame in range(30):
		await process_frame
	var nav: Node = menu.get_node("Navigation")
	nav.call("open", "music", {})
	for frame in range(60):
		await process_frame
	var screen: Control = nav.get("_screens").get("music")
	if mode == "rascunho":
		screen.call("_select_category", "pop")
		screen.call("_set_hidden", "pop-almost-in-love", true)
	for frame in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var error := picture.save_png(output)
	print("MUSIC_CAPTURE ", mode, " ", DisplayServer.window_get_size(), " file=", output)
	quit(0 if error == OK else 1)
