extends SceneTree
## Capturas T25. FIXTURE DE TESTE: salas de demonstração aguardando (nada gravado no Supabase).
## Uso: --script res://tests/duel_t25/capture.gd -- <pasta> <LxA>
const Fake := preload("res://tests/duel_t25/fake_rooms.gd")


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
	var services := PlayerServices.new()
	root.add_child(services)
	for i in 3: await process_frame
	services.session.user = {"id": "00000000-0000-4000-8000-000000000925", "email": "fixture@example.invalid"}
	services.session.client.access_token = "fixture-token-sem-rede"
	services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
	var fake: SupabaseClient = Fake.new()
	root.add_child(fake)
	services.duel.client = fake
	fake.rooms = [Fake.room("QSE482", 7, 10, ["Lendas Urbanas"]), Fake.room("QSE915", 4, 10, ["Deck de demonstração"]),
		Fake.room("QSE578", 2, 10, ["Deck de demonstração"]), Fake.room("QSE341", 6, 10, ["Deck de demonstração"])]
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await _shot(args[0], "mata_mata_salas_" + args[1])
	fake.rooms = []
	screen._load_rooms(true)
	await _shot(args[0], "mata_mata_vazio_" + args[1])
	quit(0)
