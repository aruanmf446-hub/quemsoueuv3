extends SceneTree
## Real UI input + read-only catalog contracts. Run with a rendering display for captures.
const Catalog = preload("res://scripts/decks/deck_library_catalog.gd")
var failures := 0
var checks := 0
var menu: Control
var screen: Control
var nav: Node
var capture_dir := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func settle() -> void:
	await create_timer(0.32).timeout
	await process_frame
func click(target: Control) -> void:
	var point := root.get_final_transform() * target.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await settle()
func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await settle()
func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png")) == OK, "capture_" + name)
func route() -> String:
	var history: Array = nav.get("_history")
	return "" if history.is_empty() else str(history.back().route)
func search(value: String) -> void:
	var field: LineEdit = screen.get("_search")
	field.text = value
	field.text_changed.emit(value)
	await settle()
func bounds(target: Control) -> bool:
	var rect := target.get_global_rect()
	return rect.position.x >= -1 and rect.end.x <= screen.size.x + 1 and rect.position.y >= -1 and rect.end.y <= screen.size.y + 1
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var resolution := (args[0] if args.size() else "1672x941").split("x")
	root.size = Vector2i(int(resolution[0]), int(resolution[1]))
	if args.size() > 1:
		capture_dir = ProjectSettings.globalize_path(args[1])
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var decks := Catalog.decks()
	check(decks.size() == 1 and decks[0].id == "lendas_urbanas", "only_real_public_deck")
	if decks.is_empty(): quit(1); return
	var deck: Dictionary = decks[0]
	check(deck.official and deck.creator == "Quem Sou Eu" and deck.count == 9, "official_creator_nine_cards")
	check(deck.category.is_empty() and deck.tags.is_empty() and deck.age_rating.is_empty() and deck.description.is_empty(), "missing_metadata_not_invented")
	check(Catalog.find_deck("../lendas_urbanas").is_empty(), "reject_path_traversal")
	var names: Array[String] = []
	for entry: Dictionary in deck.cards:
		names.append(entry.name)
		var texture := load(entry.image) as Texture2D
		check(texture != null and texture.get_size() == Vector2(600, 840) and entry.description.is_empty(), "original_image_" + entry.id.get_file())
	check(names == ["Bruxa do Pântano", "Cobra Grande", "Dama de Branco", "Homem do Saco", "Homem Sorridente", "Jeff the Killer", "Loira do Banheiro", "Momo", "Slender Man"], "alphabetical_order")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Catalog.ROOT + "/lendas_urbanas/deck.json"))
	var sample := raw.duplicate(true)
	sample.visibility = "private"
	check(Catalog._parse_deck("lendas_urbanas", sample).is_empty(), "private_not_readable")
	sample.visibility = "unlisted"
	check(Catalog._parse_deck("lendas_urbanas", sample).visibility == "unlisted", "unlisted_read_contract")
	sample = raw.duplicate(true)
	for id in sample.cards.keys().slice(4): sample.cards.erase(id)
	check(Catalog._parse_deck("lendas_urbanas", sample).is_empty(), "minimum_five_enforced")
	sample = raw.duplicate(true)
	sample.cards["missing_file"] = "Missing"
	check(Catalog._parse_deck("lendas_urbanas", sample).is_empty(), "missing_image_rejects_whole_deck")
	sample = raw.duplicate(true)
	sample.tags = ["A", "A", "B", "C", "D"]
	sample.age_rating = "unknown"
	sample.cards.momo = {"name": "Momo", "description": "Texto original", "translations": {"en": {"name": "Other"}}}
	var parsed := Catalog._parse_deck("lendas_urbanas", sample)
	check(parsed.tags == ["A", "B", "C"] and parsed.age_rating.is_empty(), "valid_metadata_only")
	check(parsed.cards[7].name == "Momo" and parsed.cards[7].description == "Texto original", "original_language_preserved")
	check(Catalog.search_key("PÂNTANO Ç Quem Sou EU") == "pantano c quem sou eu", "accent_insensitive_search_key")
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	await settle()
	nav = menu.get_node("Navigation")
	await click(menu.get_node("MenuButtons/BtnLibrary"))
	check(route() == "deck_library", "real_lobby_button_opens_separate_route")
	screen = nav.get("_active")
	if screen == null or route() != "deck_library": quit(1); return
	check(screen.get("_view") == "library", "readonly_without_login")
	check(bounds(screen.get_node("Margin/Column/Header")), "header_within_landscape")
	for tab: Button in screen.get("_tabs"): check(bounds(tab), "tab_bounds_" + tab.name)
	await capture("library")
	for term in ["LENDAS", "quem sou eu", "  Lendas Urbanas  "]:
		await search(term)
		check(screen.get("_results").has_node("Deck_lendas_urbanas"), "search_" + term)
	await search("inexistente")
	check(not screen.get("_results").has_node("Deck_lendas_urbanas"), "empty_search")
	await click(screen.get("_results").get_child(2))
	check(screen.get("_query").is_empty() and screen.get("_results").has_node("Deck_lendas_urbanas"), "clear_search")
	for index in range(1, 5):
		await click(screen.get("_tabs")[index])
		check(not screen.get("_results").has_node("Deck_lendas_urbanas"), "truthful_empty_" + str(index))
		if index >= 3: check(not screen.get("_search").editable, "unavailable_account_action_" + str(index))
	await click(screen.get("_tabs")[0])
	await click(screen.get("_results").get_node("Deck_lendas_urbanas"))
	check(screen.get("_view") == "deck" and screen.get("_grid").get_child_count() == 9, "real_click_opens_nine_card_gallery")
	await capture("deck")
	var gallery: GridContainer = screen.get("_grid")
	var scroll: ScrollContainer = screen.get_node("Margin/Column/Scroll")
	scroll.ensure_control_visible(gallery.get_child(8))
	await settle()
	await click(gallery.get_child(8))
	check(screen.get("_view") == "reader" and screen.get("_index") == 8, "last_card_click")
	check(screen.get("_reader_next").disabled and not screen.get("_reader_previous").disabled, "last_card_boundary")
	await click(screen.get("_reader_gallery"))
	check(screen.get("_view") == "deck", "reader_button_returns_gallery")
	check(scroll.scroll_vertical > 0, "gallery_scroll_restored")
	gallery = screen.get("_grid")
	scroll.ensure_control_visible(gallery.get_child(0))
	await settle()
	await click(gallery.get_child(0))
	check(screen.get("_index") == 0 and screen.get("_reader_previous").disabled, "first_card_boundary")
	check(bounds(screen.get("_reader_image")) and bounds(screen.get("_reader_gallery")), "reader_bounds")
	check(scroll.get_global_rect().encloses(screen.get("_reader_gallery").get_global_rect()), "reader_actions_within_scroll_viewport")
	await capture("reader")
	for index in range(1, 9):
		await click(screen.get("_reader_next"))
		check(screen.get("_index") == index and screen.get("_reader_image").texture.resource_path == deck.cards[index].image, "next_original_image_" + str(index))
	await key(KEY_LEFT)
	check(screen.get("_index") == 7, "keyboard_previous")
	await key(KEY_ESCAPE)
	check(screen.get("_view") == "deck" and route() == "deck_library", "escape_reader_to_gallery")
	nav.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await settle()
	check(screen.get("_view") == "library", "android_back_gallery_to_library")
	await click(screen.get_node("Margin/Column/Header/Back"))
	check(route() == "", "header_back_to_lobby")
	nav.call("open", "deck_library", {"deck_id": "lendas_urbanas", "card_id": "lendas_urbanas/momo"})
	await settle()
	check(screen.get("_view") == "reader" and screen.get("_index") == 7, "local_route_parameters")
	# Three back presses consume the local views, then the navigation history entry.
	for i in range(3):
		nav.call("back")
		await settle()
	check(route() == "", "local_views_preserve_history")
	nav.call("open", "deck_library", {"deck_id": "missing"})
	await settle()
	check(screen.get("_view") == "library" and not screen.get("_results").has_node("Deck_lendas_urbanas"), "unavailable_route_safe")
	nav.call("back")
	await settle()
	menu.queue_free()
	await process_frame
	await process_frame
	print("DECK_LIBRARY_CHECKS ", checks, " FAILURES ", failures)
	quit(1 if failures else 0)
