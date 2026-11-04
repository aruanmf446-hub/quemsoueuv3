extends SceneTree
## Same real form and fake RPC as T26, checked at every iPhone safe-area size.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("_run")
func frames(count := 4) -> void:
	for index in count: await process_frame
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("IPHONE_FORM_FAIL " + text)
func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	UIScale.apply_device_profile(root)
	for line in FileAccess.get_file_as_string("res://tests/iphone/models.txt").split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.is_empty() or parts[0].begins_with("#"): continue
		var dims := parts[parts.size()-1].split("x")
		root.size = Vector2i(int(dims[0]), int(dims[1]))
		await frames()
		var services := PlayerServices.new()
		root.add_child(services)
		await frames()
		services.session.user = {"id": "00000000-0000-4000-8000-000000000926", "email": "fixture@example.invalid"}
		services.session._expires_at = Time.get_unix_time_from_system() + 86400
		var fake := preload("res://tests/duel_t26/fake_game.gd").new()
		root.add_child(fake)
		fake.access_token = "fixture-token-sem-rede"
		services.session.client = fake
		services.duel.client = fake
		var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
		root.add_child(screen)
		screen.show_screen()
		await frames(6)
		(screen.find_child("CreateRoom", true, false) as Button).pressed.emit()
		await frames(12)
		var submit := screen.find_child("SubmitRoom", true, false) as Button
		var bounds := root.get_visible_rect()
		check(submit != null and bounds.encloses(submit.get_global_rect()), parts[0] + " create button entirely visible")
		var scroll := screen.get_node("Margin/Column/Scroll") as ScrollContainer
		check(scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page + 2, parts[0] + " form has no vertical overflow")
		var panel := screen.find_child("ConfigPanel", true, false)
		for label: Label in panel.find_children("*", "Label", true, false):
			check(label.get_line_count() == 1, parts[0] + " single-line rule " + label.text)
			check(label.get_theme_font_size("font_size") >= 20, parts[0] + " readable rule " + label.text)
		var before: Array = screen.get("_form").decks.duplicate()
		var pager := screen.find_child("DeckPager", true, false)
		check(pager != null, parts[0] + " deck pagination available")
		if pager != null:
			(pager.get_child(2) as Button).pressed.emit()
			await frames()
			check(screen.find_child("DeckChoice_demo_misterio", true, false) != null, parts[0] + " remaining deck accessible")
			check(screen.get("_form").decks == before, parts[0] + " paging preserves selected decks")
		await services.duel.use_local()
		await services.duel.create("[FIXTURE] Room layout", false, {"max_players": 5, "cards_per_player": 3, "deck_ids": ["lendas_urbanas"]})
		for index in 4: await services.duel.add_bot()
		services.duel.mode = "online"
		services.duel._beat.stop()
		screen.show_screen()
		await frames(8)
		var actions := screen.find_child("RoomActions", true, false)
		check(actions != null and not scroll.is_ancestor_of(actions), parts[0] + " room actions fixed outside member scrolling")
		if actions != null:
			for button: Button in actions.find_children("*", "Button", true, false):
				check(bounds.encloses(button.get_global_rect()), parts[0] + " room action entirely visible " + button.text)
		screen.queue_free()
		services.queue_free()
		fake.queue_free()
		await frames()
	print("IPHONE_FORM checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
