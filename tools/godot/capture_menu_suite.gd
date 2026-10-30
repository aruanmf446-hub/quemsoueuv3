extends SceneTree
## Real route captures. Duel fixtures are local presentation data; no account/RPC is used.
var output := "/tmp/menu-suite"
var screen: PlayerScreen
var failures := 0
class PublicProfileFixture extends ProfileService:
	func public_profile(_id: String) -> Dictionary:
		return ServiceResult.success({"nickname": "Visitante", "public_id": "VISUAL", "equipped_character_id": "lana", "level": null, "user_id": "visual"})
func _initialize() -> void: call_deferred("run")
func settle(count := 6) -> void:
	for i in range(count): await process_frame
func save(label: String) -> void:
	await settle(10)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	if is_instance_valid(screen) and screen.is_inside_tree():
		var margin: Control = screen.get_node("Margin")
		var fits := margin.get_global_rect().end.x <= screen.size.x + 1 and margin.get_global_rect().position.x >= -1 and margin.get_global_rect().position.y >= -1
		check(fits, "margin bounds: " + label)
		var header: Control = screen.get_node("Margin/Column/Header")
		check(Rect2(Vector2.ZERO, screen.size).encloses(header.get_global_rect()), "header visible: " + label)
		if not fits:
			print("BOUNDS ", label, " screen=", screen.size, " margin=", margin.get_global_rect(), " minimum=", margin.get_combined_minimum_size())
			for path: String in ["Margin/Column/Header", "Margin/Column/StateBanner", "Margin/Column/Scroll/Body"]:
				var node := screen.get_node_or_null(path) as Control
				if node != null: print("MIN ", path, " ", node.get_combined_minimum_size(), " size=", node.size)
	var err := root.get_texture().get_image().save_png(output + "/" + label + ".png")
	check(err == OK, "capture saved: " + label)
	print("CAPTURE ", label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): output = args[0]
	var resolution := (args[1] if args.size() > 1 else "1280x800").split("x")
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(resolution[0]), int(resolution[1]))
	await settle()
	if root.size.y > root.size.x:
		var guard := PlayerOrientationGuard.new()
		root.add_child(guard)
		await save("orientation")
		print("MENU_SUITE_FAILURES ", failures)
		quit(failures)
		return
	var match_script := load("res://scripts/ui/screens/duel_match_view.gd") as Script
	if match_script == null or not match_script.can_instantiate():
		push_error("Battle renderer cannot be instantiated")
		quit(1)
		return
	var services := PlayerServices.new()
	root.add_child(services)
	var routes: Dictionary = PlayerContracts.read_json("res://data/ui/routes.json").routes
	var only: PackedStringArray = []
	for arg in args:
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=").split(",")
	for route: String in routes:
		if not only.is_empty() and not route in only: continue
		var original_profile := services.profile
		if route == "public_profile":
			services.profile = PublicProfileFixture.new()
			root.add_child(services.profile)
		screen = load(routes[route]).instantiate() as PlayerScreen
		root.add_child(screen)
		screen.show_screen()
		if route == "skins":
			while screen.get("_generating"): await process_frame
		await save(route + ("-fixture" if route == "public_profile" else ""))
		if route == "duel":
			await duel_states(services)
		root.remove_child(screen)
		screen.free()
		if route == "public_profile":
			services.profile.free()
			services.profile = original_profile
	var session: CanvasLayer = load("res://scripts/desert/t15d/session_overlay.gd").new()
	root.add_child(session)
	session.phase_name = "Entrada do Deserto"
	session.total_enemies = 4
	session.show_pause()
	await save("campaign-pause")
	session.show_death(false, "Mercado")
	await save("campaign-defeat")
	session.show_completion(4, 135.0)
	await save("campaign-complete")
	session.free()
	print("MENU_SUITE_FAILURES ", failures)
	quit(failures)
func duel_states(services: PlayerServices) -> void:
	(screen.get("_auto_refresh") as Timer).stop()
	services.duel.defaults = {"max_players": 4, "cards_per_player": 2, "turn_seconds": 30, "selection_seconds": 30, "bots_allowed": true, "deck_ids": ["lendas_urbanas"], "tiebreak_base": 4, "tiebreak_per_player": 1}
	services.duel.decks = [{"id": "lendas_urbanas", "name": "Lendas Urbanas", "size": 9}]
	PlayerUI.clear(screen.body)
	screen.call("_render_form")
	await save("duel-create-fixture")
	var members: Array = []
	for spec: Array in [["p1", "Jogador", "cowboy", true], ["p2", "Convidado", "lana", false]]:
		members.append({"member_id": spec[0], "nickname": spec[1], "character_id": spec[2], "skin_id": spec[2], "is_you": spec[3], "is_admin": spec[3], "is_bot": false, "online": true, "role": "player", "confirmed": false, "eliminated": false, "lives": 2, "faults": 0, "reason": ""})
	services.duel.room = {"room": {"id": "fixture", "name": "Sala de demonstração visual", "code": "VISUAL", "status": "lobby", "is_public": true, "settings": services.duel.defaults, "decks": services.duel.decks}, "members": members, "you": members[0]}
	PlayerUI.clear(screen.body)
	screen.call("_render_room")
	await save("duel-room-fixture")
	var pool: Array = []
	var files := DirAccess.get_files_at("res://assets/duel/decks/lendas_urbanas")
	for file in files:
		if file.ends_with(".png") and pool.size() < 8: pool.append({"card_id": "lendas_urbanas/" + file.get_basename(), "removed": false})
	var data := {"phase": "selection", "players": members, "pool": pool, "my_cards": [], "events": [], "cards_per_player": 2, "turn_member": "p1", "result": {"winners": ["p1"]}, "server_now": "2026-10-30T15:00:00+00:00", "deadline": "2026-10-30T15:00:30+00:00"}
	services.duel.room["match"] = data
	services.duel.room.room.status = "in_match"
	for phase: String in ["selection", "countdown", "turns", "reveal", "finished"]:
		data.phase = phase
		data.deadline = "2026-10-30T15:00:05+00:00" if phase == "countdown" else "2026-10-30T15:00:30+00:00"
		services.duel.set("_received_at", Time.get_ticks_msec() / 1000.0)
		data.my_cards = [] if phase in ["selection", "countdown"] else [{"card_id": pool[0].card_id, "lost": false}, {"card_id": pool[1].card_id, "lost": false}]
		data.events = [{"seq": 1, "revealed": true, "card_id": pool[0].card_id, "kind": "pick", "actor": "p1", "hits": [{"member_id": "p2", "lives": 1, "faults": 0, "eliminated": false}]}] if phase == "reveal" else []
		var kept: Node = screen.get("_match_view")
		if is_instance_valid(kept) and kept.get_parent() == screen.body: screen.body.remove_child(kept)
		PlayerUI.clear(screen.body)
		screen.call("_render_room")
		await save("duel-" + phase + "-fixture")
		if phase == "selection": await check_selection()
		if phase == "turns":
			var match_view: Node = screen.get("_match_view")
			match_view.call("_confirm_pick", pool[0].card_id)
			await save("duel-confirm-fixture")
			find_button(screen, "Cancelar").pressed.emit()
			await settle()
	services.duel.room = {}

func find_button(parent: Node, text: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null
func check_selection() -> void:
	var view: Node = screen.get("_match_view")
	var sent := [0]
	view.set("act", func(_action: Callable) -> Dictionary:
		sent[0] += 1
		return ServiceResult.success({}))
	check(find_button(view, "Confirmar cartas").disabled, "confirmation disabled before choice")
	for index in range(2):
		var grid: GridContainer = view.get_node("Cards")
		var card := grid.get_child(index) as Control
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		card.gui_input.emit(event)
		await settle()
	check((view.get("_chosen") as Array).size() == 2, "two cards selected")
	check(not find_button(view, "Confirmar cartas").disabled, "confirmation enabled after choice")
	find_button(view, "Confirmar cartas").pressed.emit()
	await settle()
	check(sent[0] == 1, "one action dispatched")
	check((view.get("_chosen") as Array).is_empty(), "local choices cleared")
	print("PASS battle selection, enabled confirmation, one dispatched action, cleared local choices")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
