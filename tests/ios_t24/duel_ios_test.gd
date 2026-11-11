extends SceneTree
## T24 iOS — partida: HUD maior (6–20 jogadores), "Suas cartas" com ampliação temporária
## (fecha por toque, Esc e perda de foco) e ponte de teclado só no iOS Web. Sala LOCAL de teste.
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1


func settle() -> void:
	for _frame in range(10): await process_frame
	await create_timer(0.15).timeout


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	await services.duel.use_local()
	await services.duel.create("T24 iOS", false, {"max_players": 10, "cards_per_player": 3, "deck_ids": ["lendas_urbanas", "diva_pop"]})
	for i in 9: await services.duel.add_bot()
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await services.duel.start()
	await settle()
	var battle: Control = screen.body.get_node("Match")
	var pool: Array = services.duel.room.match.pool
	await services.duel.select_cards(pool.slice(0, 3).map(func(c: Dictionary) -> String: return str(c.card_id)))
	services.duel.local_server.clock_offset += 120
	await services.duel.refresh()
	await settle()
	var roster := battle.find_child("Players", true, false) as VBoxContainer
	check(roster.get_child_count() == 10 and roster.get_child(1).position.y >= roster.get_child(0).get_rect().end.y, "10 jogadores em lista vertical")
	var slot := roster.get_child(0)
	var portrait := slot.find_child("Portrait", true, false) as TextureRect
	check(portrait.texture is AtlasTexture and portrait.custom_minimum_size.y >= 36, "retrato com recorte do busto (%s)" % portrait.custom_minimum_size)
	var lives := slot.find_child("Lives", true, false) as Label
	check(lives != null and lives.get_theme_font_size("font_size") >= 16, "vidas em destaque")
	battle.set("_private_shown", true)
	battle.set("_private_signature", "")
	battle.refresh()
	await settle()
	var thumbs := battle.find_children("Private_*", "TextureRect", true, false)
	check(thumbs.size() == 3 and (thumbs[0] as Control).mouse_filter == Control.MOUSE_FILTER_STOP, "3 cartas privadas tocáveis")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(thumbs[1] as Control).gui_input.emit(click)
	await settle()
	var preview := battle.get_node_or_null("PrivatePreview")
	check(preview != null and preview.find_children("PreviewCard", "TextureRect", true, false).size() == 3, "toque amplia as 3 cartas")
	check((preview.find_children("PreviewCard", "TextureRect", true, false)[0] as Control).custom_minimum_size.y >= 140, "ampliação grande")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	battle._unhandled_input(escape)
	await settle()
	check(battle.get_node_or_null("PrivatePreview") == null, "Esc/Voltar fecha a ampliação")
	(battle.find_children("Private_*", "TextureRect", true, false)[0] as Control).gui_input.emit(click)
	await settle()
	(battle.get_node("PrivatePreview") as Control).gui_input.emit(click)
	await settle()
	check(battle.get_node_or_null("PrivatePreview") == null, "toque fora fecha a ampliação")
	(battle.find_children("Private_*", "TextureRect", true, false)[0] as Control).gui_input.emit(click)
	await settle()
	root.focus_exited.emit()
	await settle()
	check(battle.get_node_or_null("PrivatePreview") == null and not battle.get("_private_shown"), "perder o foco esconde a ampliação e as cartas")
	check(str(services.duel.room.match.phase) in ["turns", "reveal", "selection"], "ampliar não muda a partida")
	# Teclado nativo: só no iOS Web; aqui (sem Web) o LineEdit fica intacto.
	var chat_input := battle.find_child("ChatInput", true, false) as LineEdit
	check(not WebTextBridge.enabled() and (chat_input == null or chat_input.find_child("WebTextBridge", false, false) == null), "fora do iOS Web o chat não muda")
	print("T24_IOS_DUEL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
