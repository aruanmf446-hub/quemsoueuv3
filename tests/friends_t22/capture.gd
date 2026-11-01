extends SceneTree
## Capturas reais das 4 categorias de Amizades com a FIXTURE de teste.
## Uso: --script res://tests/friends_t22/capture.gd -- <pasta> <LxA>
const Fixture = preload("res://tests/friends_t22/fixture.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dims := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	await process_frame
	var services := PlayerServices.new()
	root.add_child(services)
	await process_frame
	Fixture.apply(services)
	var screen := load("res://scenes/player/friends.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	for tab in ["friends", "incoming", "outgoing", "search"]:
		screen._change_tab(tab)
		if tab == "search":
			screen._term = "Luna"
			screen._results = Fixture.search_results()
			screen._searched = true
			screen.render()
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/amizades_%s_%s.png" % [args[0], tab, args[1]])
		print("CAPTURED ", tab)
	quit(0)
