extends SceneTree
## Captura todas as telas do menu numa resolução, para comparar proporções entre aparelhos.
## Uso: --script res://tests/responsive/capture_all.gd -- <pasta> <LxA> [--ui-scale=N]
const ROUTES := ["deck_library", "duel", "friends", "settings", "skins"]


func _initialize() -> void:
	call_deferred("_run")


func _shot(folder: String, name: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + name + ".png")
	print("CAPTURED ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dims := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	await process_frame
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for i in 40: await process_frame
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		for i in 30: await process_frame
	await _shot(args[0], "lobby_" + args[1])
	for route: String in ROUTES:
		nav.open(route, {})
		await _shot(args[0], route + "_" + args[1])
		nav.back()
		for i in 20: await process_frame
	quit(0)
