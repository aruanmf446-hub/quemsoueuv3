extends SceneTree
## Capturas da partida (sala LOCAL de teste, bots): HUD com N jogadores, 20 cartas no tabuleiro
## e 3 cartas privadas visíveis. Uso: -- <pasta> <LxA> <jogadores> <prefixo>
func _initialize() -> void:
	call_deferred("_run")


func settle() -> void:
	for _frame in range(10): await process_frame
	await create_timer(0.15).timeout


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dims := args[1].split("x")
	var players := int(args[2])
	var resolution := Vector2i(int(dims[0]), int(dims[1]))
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_size(resolution)
	root.size = resolution
	UIScale.apply_device_profile(root)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	await services.duel.use_local()
	await services.duel.create("Captura T24", false, {"max_players": players, "cards_per_player": 3, "deck_ids": ["lendas_urbanas", "diva_pop", "nostalgia_web"]})
	for i in players - 1: await services.duel.add_bot()
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.size = root.get_visible_rect().size
	screen.show_screen()
	await services.duel.start()
	await settle()
	var battle: Control = screen.body.get_node("Match")
	# Seleção automática das 3 cartas privadas (como o jogador faria) e partida em turnos.
	var pool: Array = services.duel.room.match.pool
	var picks: Array = pool.slice(0, 3).map(func(c: Dictionary) -> String: return str(c.card_id))
	await services.duel.select_cards(picks)
	services.duel.local_server.clock_offset += 120
	await services.duel.refresh()
	await settle()
	battle.set("_private_shown", true)
	battle.set("_private_signature", "")
	battle.refresh()
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s_%dj_%s.png" % [args[0], args[3], players, args[1]])
	if args.size() > 4 and args[4].begins_with("voice"):
		# FIXTURE DE TESTE (T33): batalha vista como sala ONLINE para o widget de voz aparecer;
		# estados simulados sem rede/microfone: off | connected (com falas) | error.
		services.duel.mode = "online"
		services.duel.changed.emit()
		var voice: VoiceService = services.voice
		if args[4] == "voice_connected":
			voice.state = "connected"
			voice.mic_enabled = true
			voice.self_speaking = true
			voice.participants = [{"id": "a".repeat(64), "name": "Lucas", "speaking": true}, {"id": "b".repeat(64), "name": "Bruno", "speaking": false}]
		elif args[4] == "voice_error":
			voice.state = "error"
		voice.changed.emit()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [args[0], args[3], args[4], args[1]])
		print("CAPTURED")
		quit(0)
		return
	if args.size() > 4 and args[4] in ["reveal", "reveal_none"]:
		# Revelação animada (FIXTURE DE TESTE): 2 perdem vida e 1 é eliminado, ou ninguém.
		var match_players: Array = services.duel.match().players
		var hits: Array = [] if args[4] == "reveal_none" else [
			{"member_id": match_players[0].member_id, "eliminated": false},
			{"member_id": match_players[1].member_id, "eliminated": false},
			{"member_id": match_players[2].member_id, "eliminated": true}]
		battle._show_reveal(str(pool[5].card_id), hits)
		await create_timer(2.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [args[0], args[3], args[4], args[1]])
		print("CAPTURED")
		quit(0)
		return
	if args.size() > 4 and args[4] == "zoom":
		var first := battle.find_child("Private_*", true, false)
		var thumbs := battle.find_children("Private_*", "", true, false)
		if not thumbs.is_empty() and battle.has_method("_preview_private"):
			battle._preview_private(str(thumbs[0].get_meta("card_id", "")))
			await settle()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_ampliada_%s.png" % [args[0], args[3], args[1]])
	print("CAPTURED")
	quit(0)
