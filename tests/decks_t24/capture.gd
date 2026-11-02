extends SceneTree
## Capturas T24 (Populares e Recentes). FIXTURE de teste: decks [DEMO] e totais falsos, sem rede.
## Uso: --script res://tests/decks_t24/capture.gd -- <pasta> <LxA>
func _initialize() -> void:
	call_deferred("_run")


func _shot(folder: String, name: String) -> void:
	for i in 24: await process_frame
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
	for i in 20: await process_frame
	var nav: Node = menu.get_node("Navigation")
	if not nav.get("_history").is_empty() and nav.get("_history").back().route == "account":
		nav.back()
		for i in 30: await process_frame
	nav.open("deck_library", {})
	for i in 30: await process_frame
	var screen: Node = nav.get("_active")
	var fixture: Array[Dictionary] = load("res://tests/decks_t23/fixture.gd").entries()
	var now := Time.get_unix_time_from_system()
	for i in fixture.size():
		fixture[i].ref = "creator:demo%d" % i
		fixture[i].published = now - 3600.0 * (2 + i * 30)
	var game: Node = load("res://tests/decks_t24/fake_game.gd").new()
	root.add_child(game)
	game.stats = [
		{"deck_ref": "creator:demo0", "plays_30d": 41, "players_30d": 17, "favorites": 6, "score": 93},
		{"deck_ref": "creator:demo3", "plays_30d": 12, "players_30d": 5, "favorites": 2, "score": 28},
		{"deck_ref": "creator:demo1", "plays_30d": 4, "players_30d": 2, "favorites": 0, "score": 8}]
	screen._stats_client = game
	screen._demo_entries = fixture
	screen._select_tab("Populares")
	for i in 20: await process_frame
	await _shot(args[0], "t24_populares_" + args[1])
	screen._select_tab("Recentes")
	await _shot(args[0], "t24_recentes_" + args[1])
	quit(0)
