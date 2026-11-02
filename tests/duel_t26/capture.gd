extends SceneTree
## Capturas T26 (Criar sala). FIXTURE DE TESTE: decks [DEMO] e servidor falso, sem rede.
## Uso: --script res://tests/duel_t26/capture.gd -- <pasta> <LxA>


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
	services.session.user = {"id": "00000000-0000-4000-8000-000000000926", "email": "fixture@example.invalid"}
	services.session.client.access_token = "fixture-token-sem-rede"
	services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
	var fake: SupabaseClient = load("res://tests/duel_t26/fake_game.gd").new()
	root.add_child(fake)
	services.duel.client = fake
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	for i in 6: await process_frame
	(screen.find_child("CreateRoom", true, false) as Button).pressed.emit()
	await _shot(args[0], "criar_sala_" + args[1])
	var picker := screen.find_child("Pick_max_players", true, false) as OptionButton
	picker.show_popup()
	await _shot(args[0], "criar_sala_lista_aberta_" + args[1])
	picker.get_popup().hide()
	screen.set_form_value("max_players", 12)
	screen.set_form_value("turn_seconds", 90)
	(screen.find_child("DeckChoice_demo_folclore", true, false) as Button).button_pressed = true
	await _shot(args[0], "criar_sala_resumo_atualizado_" + args[1])
	quit(0)
