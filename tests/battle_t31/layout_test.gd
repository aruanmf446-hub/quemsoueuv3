extends SceneTree
## T31 — cartas maiores sem rolagem, em render nativo do Godot 4.7.2.
## Somente fixtures de sala local; nenhuma alteração no Supabase ou em decks.
var checks := 0
var failed := 0
var output := ""

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print(("T31_PASS " if ok else "T31_FAIL ") + message)
	if not ok: failed += 1

func settle() -> void:
	for _frame in range(9): await process_frame
	await create_timer(0.14).timeout

func capture(label: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check(img != null and not img.is_empty(), "renderer_" + label)
	if img != null and not img.is_empty():
		check(img.save_png(output.path_join(label + ".png")) == OK, "png_" + label)

func inside(node: Control, parent: Control) -> bool:
	return parent.get_global_rect().grow(1.5).encloses(node.get_global_rect())

func _verify(battle: Control, screen: Control, label: String, count: int) -> void:
	var grid := battle.find_child("Cards",true,false) as GridContainer
	check(grid != null and grid.get_child_count() == count, label + " all cards")
	check(grid.columns >= 2 and grid.columns <= 10, label + " adaptive columns")
	check(screen.get_node("Margin/Column/Scroll").vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		label + " board scroll disabled")
	var node: Node = grid
	while node != battle:
		check(not node is ScrollContainer,label + " no grid scrolling")
		node = node.get_parent()
	var first: Control = grid.get_child(0)
	check(first.size.x >= 38 and first.size.y >= 32, label + " nonzero card area")
	for card: Control in grid.get_children():
		check(inside(card,grid) and inside(card,screen),label + " visible " + str(card.name))
		var title := card.find_child("Caption",true,false) as Label
		check(title != null and not title.text.contains("{") and not title.text.contains('"name"'),
			label + " pure display name " + str(card.name))
	print("T31_GEOMETRY ", label, " cols=", grid.columns, " rows=", ceili(float(count)/grid.columns),
		" first=", first.size," screen=", screen.size)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if args.size()>0 else ""
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	await services.duel.use_local()
	var created := await services.duel.create("Proporção de cartas T31",false,
		{"max_players":4,"cards_per_player":2,"deck_ids":["lendas_urbanas"]})
	check(created.ok,"local room")
	await services.duel.add_bot()
	await services.duel.add_bot()
	var screen := load("res://scenes/player/duel.tscn").instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await services.duel.start()
	await settle()
	var battle: Control = screen.body.get_node("Match")
	check(DuelService.card_name("diva_pop/carta_01") == "Selina Chartpenter",
		"Diva Pop name parsed from dictionary instead of JSON")
	check(DuelService.card_name("nostalgia_web/carta_02").length() < 90,
		"Nostalgia name short and readable")
	var real_state: Dictionary = services.duel.room.duplicate(true)
	var pool: Array = []
	for index in range(10):
		var card: Dictionary = real_state.match.pool[index%9].duplicate(true)
		card.card_id = "diva_pop/carta_%02d" % (index+1)
		card.removed = false
		pool.append(card)
	for index in range(10):
		var card: Dictionary = real_state.match.pool[index%9].duplicate(true)
		card.card_id = "nostalgia_web/carta_%02d" % (index+1)
		card.removed = false
		pool.append(card)
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(844,390),Vector2i(640,360)]:
		DisplayServer.window_set_size(resolution)
		root.content_scale_size = resolution
		root.size = resolution
		screen.size = Vector2(resolution)
		battle.size = Vector2(resolution)
		await settle()
		services.duel.room.match.pool = pool.duplicate(true)
		battle.refresh()
		await settle()
		_verify(battle,screen,"%dx%d_20cards"%[resolution.x,resolution.y],20)
		await capture("%dx%d_20cards"%[resolution.x,resolution.y])
	# Preserve dynamic layout with the usual nine-card room and extreme 30-card fixture.
	services.duel.room = real_state.duplicate(true)
	battle.refresh()
	await settle()
	_verify(battle,screen,"640x360_9cards",9)
	await capture("640x360_9cards")
	pool = []
	for index in range(30):
		var card: Dictionary = real_state.match.pool[index%9].duplicate(true)
		card.card_id = "diva_pop/carta_%02d" % (index%10+1)
		pool.append(card)
	services.duel.room.match.pool = pool
	battle.refresh()
	await settle()
	_verify(battle,screen,"640x360_30cards",30)
	# Do not capture overload fixture: it is only a geometry stress test.
	screen.queue_free()
	services.queue_free()
	await settle()
	print("T31_SUMMARY checks=",checks," failures=",failed)
	quit(1 if failed else 0)
