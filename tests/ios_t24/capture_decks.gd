extends SceneTree
## Captura do Criar sala com os decks oficiais reais (partida local). Uso: -- <pasta> <LxA>
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dims := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	var services := PlayerServices.new()
	root.add_child(services)
	for i in 3: await process_frame
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	for i in 6: await process_frame
	await screen._start_local()
	for i in 30: await process_frame
	var grid := screen.find_child("DeckChoices", true, false)
	print("DECKS ", grid.get_children().map(func(n: Node) -> String: return str(n.name)) if grid else "nenhum")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0] + "/criar_sala_decks_" + args[1] + ".png")
	print("CAPTURED")
	quit(0)
