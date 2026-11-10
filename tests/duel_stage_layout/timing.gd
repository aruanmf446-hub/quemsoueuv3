extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("TIMING_", "PASS " if ok else "FAIL ", text)
func settle() -> void:
	for i in 6: await process_frame
func run() -> void:
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	await services.duel.use_local()
	await services.duel.create("Timing fixture",false,{"max_players":3,"cards_per_player":2,"deck_ids":["lendas_urbanas"]})
	await services.duel.add_bot()
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await services.duel.start()
	await settle()
	var duel := services.duel
	var server := duel.local_server
	var pool: Array = duel.match().pool
	await duel.select_cards([pool[0].card_id,pool[1].card_id])
	(duel.get("_beat") as Timer).stop()
	check(duel.match().phase=="countdown","selection starts authoritative countdown")
	check(duel.seconds_left()>=12.0,"two players have six seconds each plus load reserve")
	var deadline: float = server._match.phase_deadline
	server.finish_presentation("wrong-match","countdown")
	check(server._match.phase_deadline==deadline,"stale completion cannot alter match")
	var battle: Control = screen.body.get_node("Match")
	var intro: Control = battle.get("_presentation")
	check(is_instance_valid(intro),"actual intro created")
	if is_instance_valid(intro): intro.cancel()
	check(server._match.phase_deadline<=server.now()+0.3,"continue advances local without waiting load reserve")
	await settle()
	duel.room.match.phase="turns"
	battle.refresh()
	check(not is_instance_valid(battle.get("_presentation")),"turn unobstructed after countdown")
	# Mimic online result and automatic return to lobby using isolated authority data.
	var result := Control.new()
	battle.add_child(result)
	result.set_meta("phase","finished")
	result.set_meta("match_id",duel.match().id)
	battle.set("_presentation",result)
	duel.room.match.phase="finished"
	duel.room.room.status="lobby"
	check(battle.holding_results(),"final presentation holds across room return")
	screen.render()
	check(screen.body.get_node_or_null("Match")==battle,"room heartbeat keeps final stage")
	duel.room.room.status="in_match"
	duel.room.match.id="new-match-fixture"
	duel.room.match.phase="selection"
	check(not battle.holding_results(),"new match releases old result")
	screen.render()
	await settle()
	check(not is_instance_valid(battle.get("_presentation")),"new match removes obsolete stage")
	screen.queue_free()
	services.queue_free()
	await settle()
	print("TIMING_SUMMARY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
