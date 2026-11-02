extends SceneTree
## Verifica controles reais na mesma base, inclusive com densidade simulada 3.
## Capturas são do renderizador do Godot; não equivalem a teste em aparelho físico.
const ROUTES := ["story", "deck_library", "duel", "friends", "settings", "skins", "music", "profile"]
var failures := 0
var measurements := {}
var baseline := {}
var folder := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1

func frames(count := 30) -> void:
	for i in count: await process_frame

func sample(id: String, control: Control, font: Control = null, fixed_width := true) -> void:
	var data := [snappedf(control.size.x, 0.1), snappedf(control.size.y, 0.1)]
	if font != null: data.append(font.get_theme_font_size("font_size"))
	if baseline.has(id): check((data if fixed_width else data.slice(1)) == (baseline[id] if fixed_width else baseline[id].slice(1)), id + " mantém tamanho de design: " + str(data))
	else: baseline[id] = data
	measurements[str(root.size)][id] = data
	var bounds := Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1)
	check(bounds.encloses(control.get_global_rect()), id + " dentro da tela")

func shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + id + "_%dx%d.png" % [root.size.x, root.size.y])

func _run() -> void:
	folder = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	await frames(2)
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await frames(40)
	var nav := menu.get_node("Navigation")
	if not nav.get("_history").is_empty():
		nav.back()
		await frames()
	check(not UIScale.is_compact() and UIScale.unit_for(root) == 1.0, "escala única preservada")
	for dims in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(844,390), Vector2i(640,360)]:
		root.size = dims
		await frames()
		measurements[str(root.size)] = {}
		var history := menu.get_node("MenuButtons/BtnHistory") as Control
		sample("lobby/history", history, history.get_node("ActionBody/Text/Title"))
		var play := menu.get_node("MenuButtons/BtnStory") as Control
		sample("lobby/play", play, play.get_node("ActionBody/Text/Title"))
		sample("lobby/news", menu.get_node("NewsButton"), menu.get_node("NewsButton"))
		await shot("lobby")
		for route: String in ROUTES:
			nav.open(route, {})
			await frames(40)
			var screen := nav.get("_screens").get(route) as Control
			if screen == null:
				check(false, "rota disponível: " + route)
				continue
			if route == "skins":
				for i in 600:
					if not screen.get("_generating"): break
					await process_frame
			var back := screen.get_node("Margin/Column/Header/Back") as Button
			sample(route + "/back", back, back)
			if route == "settings":
				for category in 5:
					screen.call("_select", category)
					await frames(3)
					var tab: Button = screen.get("_tabs")[category]
					sample("settings/tab%d" % category, tab, tab, false)
					await shot("settings_%d" % category)
				screen.call("_select", 0)
			await shot(route)
			nav.back()
			await frames()
	var file := FileAccess.open(folder + "/metrics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "sizes": measurements}, "\t"))
	file.close()
	print("CONTROL_SIZES failures=", failures)
	quit(1 if failures else 0)
