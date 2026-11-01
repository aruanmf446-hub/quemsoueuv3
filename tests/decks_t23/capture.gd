extends SceneTree
## Capturas reais das 5 abas da Biblioteca T23. Usa a FIXTURE de teste (decks [DEMO]) além do catálogo real.
## Uso: --script res://tests/decks_t23/capture.gd -- <pasta> <LxA>
func _initialize() -> void:
	call_deferred("_run")


func _shot(folder: String, name: String) -> void:
	for i in 24: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + name + ".png")
	print("CAPTURED ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0]
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
	var store: DeckDrafts = screen._store()
	var made: Array[String] = []
	for title in ["Meu Deck de Heróis", "Deck do Terror"]:
		var draft := store.new_draft()
		draft.name = "[DEMO] " + title
		store.save(draft)
		made.append(str(draft.id))
	var had_fav := store.is_favorite("lendas_urbanas")
	store.set_favorite("lendas_urbanas", true)
	screen._demo_entries = load("res://tests/decks_t23/fixture.gd").entries()
	for tab in ["Descobrir", "Populares", "Recentes", "Favoritos", "Meus Decks"]:
		screen._select_tab(tab)
		await _shot(folder, tab.to_lower().replace(" ", "_") + "_" + args[1])
	store.set_favorite("lendas_urbanas", had_fav)
	for id in made: store.delete(id)
	quit(0)
