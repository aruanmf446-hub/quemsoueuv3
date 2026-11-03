extends SceneTree
## Revelação animada numa partida LOCAL real (bots): a carta escolhida e os atingidos
## aparecem no meio da tela quando o servidor revela (sem chamar a animação à mão).
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1280,720)
	var services := PlayerServices.new()
	root.add_child(services)
	for i in 5: await process_frame
	await services.duel.use_local()
	await services.duel.create("Rev", false, {"max_players": 3, "cards_per_player": 3, "deck_ids": ["lendas_urbanas"]})
	for i in 2: await services.duel.add_bot()
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.size = Vector2(1280,720)
	screen.show_screen()
	await services.duel.start()
	var pool: Array = services.duel.room.match.pool
	await services.duel.select_cards(pool.slice(0,3).map(func(c: Dictionary) -> String: return str(c.card_id)))
	var seen := false
	var shown := 0
	for step in 900:
		await create_timer(0.1).timeout
		var battle: Node = screen.body.get_node_or_null("Match")
		if battle != null and battle.get_node_or_null("RevealOverlay") != null:
			if not seen:
				shown += 1
				print("REVEAL_SEEN at step ", step)
			seen = true
		elif seen and (battle == null or battle.get_node_or_null("RevealOverlay") == null):
			seen = false
		if false and services.duel.match().get("phase","") == "reveal":
			var ev: Array = services.duel.match().get("events",[])
			print("  reveal step ", step, " battle=", battle != null, " last=", battle.get("_last_event") if battle else "-", " revealed=", ev.back().get("revealed") if not ev.is_empty() else "-", " vis=", battle.is_visible_in_tree() if battle else false)
		if step % 50 == 0: print("step ", step, " phase=", services.duel.match().get("phase",""), " events=", (services.duel.match().get("events",[]) as Array).size())
	print("BATTLE_REVEAL shown=", shown)
	quit(0 if shown > 0 else 1)
