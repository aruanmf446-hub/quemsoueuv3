extends SceneTree
## Real scene, real controls and viewport input. Offline; no OAuth credentials.
var checks := 0
var failures := 0
var menu: Control
var hero: Control
var nav: Node
var output := ""

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("HERO_", "PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func settle(seconds := 0.65) -> void:
	await create_timer(seconds).timeout
func click(target: Control) -> void:
	var point := root.get_final_transform() * target.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame
func route() -> String:
	var history: Array = nav.get("_history")
	return "" if history.is_empty() else str(history.back().route)
func back() -> void:
	nav.back()
	await settle()
	check(route().is_empty() and hero.visible, "return reveals hero")
func shot(index: int) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	# Readback on software GL may take longer than the autoplay interval.
	# Freeze only for evidence capture, then exercise the actual timer below.
	hero.set_process(false)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output + "/slide_%d.png" % index)
	hero.set_process(true)
	hero._elapsed = 0.0
	check(error == OK, "real rendered screenshot %d" % index)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
func swipe(start: Vector2, finish: Vector2) -> void:
	var transform := root.get_final_transform()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = transform * start
	touch.pressed = true
	root.push_input(touch)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = transform * finish
	drag.relative = transform.basis_xform(finish - start)
	root.push_input(drag)
	await process_frame
	touch = touch.duplicate()
	touch.position = transform * finish
	touch.pressed = false
	root.push_input(touch)
	await settle()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1672, 941)
	for arg in args:
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--resolution="):
			var parts := arg.trim_prefix("--resolution=").split("x")
			root.size = Vector2i(int(parts[0]), int(parts[1]))
	UIScale.apply_device_profile(root)
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle(1.0)
	nav = menu.get_node("Navigation")
	hero = menu.get_node("HeroCarousel")
	check(route() == "account", "startup authentication preserved")
	await back()
	check(hero.using_art and hero._slide == 0, "story initial slide with all three artworks")
	check(menu.get_node("NowPlaying").get_index() > hero.get_index(), "real music player above hero")
	var music := root.get_node("MenuMusic")
	var player := menu.get_node("NowPlaying")
	if player.visible:
		var was_paused: bool = music.paused
		await click(player._buttons[1])
		check(music.paused != was_paused and route().is_empty(), "music toggle receives input above hero")
		player._buttons[1].grab_focus()
		await key(KEY_SPACE)
		await process_frame
		check(music.paused == was_paused, "music transport keyboard accessible")
	check(menu.get_node("LobbyArea/Stage/Viewport").render_target_update_mode == SubViewport.UPDATE_DISABLED, "3D render paused")
	for index in range(3):
		await click(hero.get_node("Indicator%d" % index))
		await settle()
		check(hero._slide == index and not hero._changing, "indicator selects %d" % index)
		var layer: Control = hero.get_node("HeroSlide%d" % index)
		for other in range(3): check(hero._layers[other].visible == (other == index), "one visible layer %d/%d" % [index, other])
		for path in ["Title", "Description", "Reward", "Play"]:
			var node: Control = layer.get_node(path)
			check(Rect2(Vector2.ZERO, hero.size).encloses(node.get_rect()), "in bounds %d %s" % [index, path])
		await shot(index)
		await click(layer.get_node("Play"))
		await settle()
		check(route() == ["story", "duel", "deck_library"][index], "CTA opens route %d" % index)
		check(not hero.visible, "hero hidden on internal screen")
		var elapsed: float = hero._elapsed
		await settle(0.2)
		check(is_equal_approx(elapsed, hero._elapsed), "autoplay paused on internal screen")
		await back()
	for shortcut: String in ["HeroCoins", "HeroEmotes"]:
		var button: Button = hero.get_node(shortcut)
		check(button.is_visible_in_tree(), "shortcut visible: " + shortcut)
		check(Rect2(Vector2.ZERO,hero.size).encloses(button.get_rect()), "shortcut in viewport: " + shortcut)
		await click(button)
		await settle()
		check(route() == ("wallet" if shortcut == "HeroCoins" else "skins"), "shortcut opens existing route: " + shortcut)
		var params: Dictionary = nav._history.back().params
		check(params.get("tab", "") == "coins" if shortcut == "HeroCoins" else params.get("cosmetic_mode", "") == "shop", "shortcut opens correct section: " + shortcut)
		await back()
	for index in [0, 1, 3]:
		await click(hero.get_node("Tab%d" % index))
		await settle()
		check(hero._slide == {0:0, 1:1, 3:2}[index] and route().is_empty(), "header selects slide %d" % index)
	for index in [2, 4, 5]:
		await click(hero.get_node("Tab%d" % index))
		await settle()
		check(route() == {2:"skins", 4:"friends", 5:"settings"}[index], "header opens route %d" % index)
		await back()
	await click(hero.get_node("NextSlide"))
	await settle()
	check(hero._slide == 0, "right arrow wraps to story")
	await click(hero.get_node("PreviousSlide"))
	await settle()
	check(hero._slide == 2, "left arrow wraps to library")
	await key(KEY_RIGHT)
	await settle()
	check(hero._slide == 0, "keyboard right selects next")
	await key(KEY_LEFT)
	await settle()
	check(hero._slide == 2, "keyboard left selects previous")
	var cta: Button = hero.get_node("HeroSlide2/Play")
	var start := cta.get_global_rect().get_center()
	await swipe(start, start - Vector2(hero.size.x * 0.16, 0))
	check(route().is_empty() and hero._slide == 0, "swipe starting on CTA changes slide without routing")
	# Swiping back and pressing Enter must not retain gesture cancellation.
	await swipe(Vector2(hero.size.x * 0.65, hero.size.y * 0.55), Vector2(hero.size.x * 0.85, hero.size.y * 0.55))
	check(hero._slide == 2 and route().is_empty(), "right swipe selects previous")
	hero.get_node("HeroSlide2/Play").grab_focus()
	await key(KEY_ENTER)
	await settle()
	check(route() == "deck_library", "keyboard focused CTA activates after swipe")
	await back()
	await click(hero.get_node("HeroFriends"))
	await settle()
	check(route() == "friends", "footer friends route")
	await back()
	await click(hero.get_node("HeroNews"))
	await settle()
	check(menu.has_node("NewsOverlay"), "native news action opens existing overlay")
	var paused_elapsed: float = hero._elapsed
	await settle(0.3)
	check(is_equal_approx(paused_elapsed, hero._elapsed), "autoplay paused for news overlay")
	if menu.has_node("NewsOverlay"): menu.get_node("NewsOverlay").queue_free()
	await settle(0.1)
	# Real ten-second timeout, rather than setting the accumulator to its threshold.
	await click(hero.get_node("Indicator0"))
	await settle()
	await settle(10.0)
	await settle()
	check(hero._slide == 1 and not hero._changing, "real 10-second autoplay advances horizontally")
	await click(hero.get_node("Indicator0"))
	await settle()
	check(hero._elapsed < 1.0, "manual interaction resets autoplay")
	print("HERO_RESULT checks=", checks, " failures=", failures, " resolution=", root.size, " logical=", hero.size)
	quit(1 if failures > 0 else 0)
