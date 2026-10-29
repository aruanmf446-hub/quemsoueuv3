extends SceneTree
## Integração e capturas reais (requer display OpenGL; user data isolado via XDG).
var panel: Control
var checks := 0
var output := "/tmp/qse-skins-refined"
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL " + message)
		quit(1)
		assert(value, message)
func settle(frames := 5) -> void:
	for i in range(frames): await process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1672, 941)
	root.content_scale_size = Vector2i.ZERO
	var services := PlayerServices.new()
	root.add_child(services)
	panel = load("res://scenes/skins/skins_panel.tscn").instantiate()
	root.add_child(panel)
	panel.open("rodrigo")
	await settle(35)
	check(panel._cards.size() == 8, "catálogo real")
	var equipped := services.inventory.equipped_id()
	check(panel._selected == "rodrigo" and services.inventory.equipped_id() == equipped, "seleção não equipa")
	check(not panel._header.has_node("CatalogTabs"), "sem abas inexistentes")
	var unlocked := 0
	for entry: Dictionary in services.inventory.entries:
		if services.inventory.is_unlocked(entry.id): unlocked += 1
	check(panel._collection_count.text == "%d/%d desbloqueados" % [unlocked, services.inventory.entries.size()], "contador real de desbloqueio")
	await capture("desktop")
	var card: Control = panel._cards["cowboy"]
	var click := InputEventMouseButton.new()
	click.position = card.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await settle()
	check(panel._selected == "cowboy", "clique real no card")
	panel._select_neighbor(1)
	check(panel._selected != "cowboy", "setas navegam na galeria")
	panel._search_field.text = "Lana"
	panel._search_field.text_changed.emit("Lana")
	await settle()
	check(panel._cards.size() == 1 and panel._cards.has("lana"), "pesquisa")
	panel._search_field.text = "sem-resultados"
	panel._search_field.text_changed.emit("sem-resultados")
	await settle()
	check(panel._cards.is_empty(), "pesquisa vazia")
	panel._search_field.text = ""
	panel._search_field.text_changed.emit("")
	panel._toggle_favorite("lana")
	panel._toggle_favorite_only()
	await settle()
	check(panel._cards.size() == 1 and panel._cards.has("lana"), "favoritos filtrados")
	panel._favorites.clear()
	panel._load_favorites()
	check(panel._favorites.has("lana"), "favorito persistido")
	panel._toggle_favorite_only()
	panel._status_filter = 2
	panel._rebuild_gallery()
	check(panel._cards.size() == 1 and panel._cards.has("el_fuego"), "filtro bloqueado")
	panel._status_filter = 0
	panel._rebuild_gallery()
	panel._sort_button.select(1)
	panel._sort_button.item_selected.emit(1)
	check(panel._cards.keys()[0] == "rodrigo", "ordenação Z-A")
	panel._sort_button.select(0)
	panel._sort_button.item_selected.emit(0)
	check(panel._cards.keys()[0] == "cowboy", "ordenação A-Z")
	panel._select("lana")
	await settle()
	check(services.inventory.equipped_id() == equipped, "prévia independente")
	var stage: LobbyStage = panel._stage
	var yaw: float = stage._yaw
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(55, 4)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	stage._gui_input(drag)
	check(stage._yaw != yaw, "rotação por arraste")
	var touch := InputEventScreenDrag.new()
	touch.relative = Vector2(-20, 0)
	stage._gui_input(touch)
	check(stage._yaw != yaw, "rotação touch")
	await panel._equip("lana")
	await settle()
	check(services.inventory.equipped_id() == "lana", "equipar via serviço")
	check(panel._preview.find_children("*", "Button", true, false).any(func(b): return b.text == "EQUIPADO" and b.disabled), "estado equipado")
	check(not panel._preview.find_children("*", "Label", true, false).any(func(label): return label.text.to_upper().contains("EQUIPADO")), "sem estado duplicado na prévia")
	panel._select("el_fuego")
	await settle()
	check(panel._preview.find_children("*", "Button", true, false).any(func(b): return b.text == "BLOQUEADO" and b.disabled), "bloqueado não compra nem equipa")
	await capture("bloqueado")
	for entry: Dictionary in services.inventory.entries:
		panel._select(entry.id)
		await settle(2)
		check(not panel._stage.character.get_framing().is_empty(), "modelo " + entry.id)
		check_framing(entry.id)
		await capture("desktop-" + entry.id)
	panel._select("lana")
	await settle()
	await capture("equipado")
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(800, 450)]:
		root.size = resolution
		await settle(10)
		check(panel._side.get_global_rect().end.x <= resolution.x + 1, "painel cabe " + str(resolution))
		check(panel._preview.get_global_rect().end.y <= resolution.y + 1, "ações cabem " + str(resolution))
		check(panel._stage.size.y > 80, "palco visível " + str(resolution))
		for entry: Dictionary in services.inventory.entries:
			panel._select(entry.id)
			await settle(3)
			check_framing(str(resolution) + " " + entry.id)
			if resolution.x == 800:
				await capture("mobile-" + entry.id)
		panel._select("lana")
		await settle()
		await pointer_rotation()
		panel._stage.reset_view()
		panel._scroll.scroll_vertical = 10000
		await settle()
		await capture("%dx%d" % [resolution.x, resolution.y])
	print("PASS ", checks, " verificações; capturas em ", output)
	quit()


func check_framing(label: String) -> void:
	var stage = panel._stage
	check(stage._pose_measured, "pose medida " + label)
	var rect := Rect2(Vector2.ZERO, Vector2(stage._viewport.size)).grow(1.0)
	for angle in [0.0, 0.8, 2.8]:
		stage._yaw = angle
		stage._update_camera()
		var fits := true
		for box: AABB in stage._fit_boxes:
			for corner in range(8):
				var point: Vector3 = stage.character.to_global(box.get_endpoint(corner))
				fits = fits and not stage._camera.is_position_behind(point)
				fits = fits and rect.has_point(stage._camera.unproject_position(point))
		check(fits, "modelo e pedestal sem cortes " + label + " yaw=" + str(angle))
	stage._yaw = 0.0
	stage._update_camera()


func pointer_rotation() -> void:
	var stage = panel._stage
	var center: Vector2 = stage.get_global_rect().get_center()
	var before: float = stage._yaw
	var mouse := InputEventMouseButton.new()
	mouse.position = center
	mouse.global_position = center
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(30, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(30, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	mouse.pressed = false
	mouse.position = motion.position
	root.push_input(mouse)
	await settle()
	check(stage._yaw != before, "mouse via viewport " + str(root.size))
	before = stage._yaw
	var press := InputEventScreenTouch.new()
	press.position = center
	press.pressed = true
	root.push_input(press)
	var drag := InputEventScreenDrag.new()
	drag.position = center - Vector2(20, 0)
	drag.relative = Vector2(-20, 0)
	root.push_input(drag)
	press.position = drag.position
	press.pressed = false
	root.push_input(press)
	await settle()
	check(stage._yaw != before, "touch via viewport " + str(root.size))
