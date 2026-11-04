extends Node
## TEST ONLY. Exported exclusively from an isolated staging project with a custom
## feature. Uses existing local/fake services; never connects to an online room.
var menu: Control
var services: PlayerServices
var _selection_callback: JavaScriptObject

func _ready() -> void:
	if not OS.has_feature("iphone_layout_fixture"):
		push_error("Web layout fixture requires the test-only export feature")
		return
	_run.call_deferred()

func settle(seconds := 0.5) -> void:
	await get_tree().create_timer(seconds).timeout

func _run() -> void:
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	services = menu.get_node("Services")
	var fake := preload("res://tests/duel_t26/fake_game.gd").new()
	add_child(fake)
	services.duel.client = fake
	services.session.client = fake
	await settle()
	menu.set("_initial_login_pending", false)
	var cover := menu.get_node_or_null("StartupSessionCover")
	if cover != null: cover.queue_free()
	var navigation := menu.get_node("Navigation")
	if not navigation.get("_history").is_empty(): navigation.back()
	await settle()
	var state := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('fixture') || 'form'"))
	var setup: Dictionary = {}
	if state in ["form", "room", "selection"]:
		services.session.user = {"id": "00000000-0000-4000-8000-000000000926", "email": "fixture@example.invalid"}
		services.session._expires_at = Time.get_unix_time_from_system() + 86400.0
		fake.access_token = "fixture-token-sem-rede"
	if state in ["room", "selection"]:
		await services.duel.use_local()
		setup["create"] = await services.duel.create("[FIXTURE LOCAL] iPhone", false, {"max_players": 5, "cards_per_player": 3, "selection_seconds": 120, "deck_ids": ["lendas_urbanas", "diva_pop"]})
		for index in 4: await services.duel.add_bot()
		if state == "selection": setup["start"] = await services.duel.start()
		# Same UI branch as online, with only an in-memory local payload.
		services.duel.mode = "online"
		services.duel._beat.stop()
		navigation.open("duel")
	elif state == "form":
		navigation.open("duel")
		await settle()
		(navigation.get("_active") as Control).call("_open_form")
	else:
		navigation.open(state if state in ["skins", "friends", "profile", "wallet", "story", "music"] else "story")
	await settle(1.0)
	var report := {"fixture": state, "setup": setup, "route": navigation.get("_history"), "iphone": UIScale.is_iphone(), "logical_size": [menu.size.x, menu.size.y], "buttons": [], "player_overlaps": [], "scrolls": []}
	var player := menu.get_node("NowPlaying") as Control
	var viewport := Rect2(Vector2.ZERO, menu.size)
	for control: Control in menu.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree() or player.is_ancestor_of(control): continue
		var rect := control.get_global_rect()
		if control is BaseButton:
			report.buttons.append({"name": str(control.name), "text": control.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "inside": viewport.grow(2).encloses(rect)})
		if control is ScrollContainer:
			var bar: VScrollBar = (control as ScrollContainer).get_v_scroll_bar()
			report.scrolls.append({"path": str(control.get_path()), "overflow": maxf(0, bar.max_value - bar.page), "height": control.size.y})
		if control is Label:
			rect.size.x = minf(rect.size.x, control.get_theme_font("font").get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x)
		if player.visible and (control is BaseButton or control is Label) and rect.intersects(player.get_global_rect()):
			report.player_overlaps.append(str(control.get_path()))
	JavaScriptBridge.eval("window.qseLayoutReport=" + JSON.stringify(report) + ";window.qseLayoutReady=true")
	if state == "selection":
		_selection_callback = JavaScriptBridge.create_callback(_selection_probe)
		JavaScriptBridge.get_interface("window").qseSelectionProbe = _selection_callback

func _selection_probe(_arguments: Array) -> void:
	var screen: Node = menu.get_node("Navigation").get("_active")
	var battle: Node = screen.get("_match_view")
	var data := {"chosen": battle.get("_chosen").size(), "confirm_disabled": battle.get("_confirm").disabled, "cards": []}
	var grid: GridContainer = battle.get("_grid")
	for card: Control in grid.get_children():
		var rect := card.get_global_rect()
		var label := card.find_child("Caption", true, false) as Label
		data.cards.append({"name": label.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "font": label.get_theme_font_size("font_size"), "caption_height": label.size.y, "lines": label.get_line_count()})
	JavaScriptBridge.eval("window.qseSelectionState=" + JSON.stringify(data))
