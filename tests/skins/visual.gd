extends SceneTree
## Integração e capturas reais (requer display OpenGL; user data isolado via XDG).
var panel: Control
var checks := 0
var output := "/tmp/qse-skins"
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
	panel._select("el_fuego")
	await settle()
	check(panel._preview.find_children("*", "Button", true, false).any(func(b): return b.text == "BLOQUEADO" and b.disabled), "bloqueado não compra nem equipa")
	await capture("bloqueado")
	for entry: Dictionary in services.inventory.entries:
		panel._select(entry.id)
		await settle(2)
		check(not panel._stage.character.get_framing().is_empty(), "modelo " + entry.id)
	panel._select("lana")
	await settle()
	await capture("equipado")
	for resolution in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(800, 450)]:
		root.size = resolution
		await settle(10)
		check(panel._side.get_global_rect().end.x <= resolution.x + 1, "painel cabe " + str(resolution))
		check(panel._preview.get_global_rect().end.y <= resolution.y + 1, "ações cabem " + str(resolution))
		check(panel._stage.size.y > 80, "palco visível " + str(resolution))
		panel._scroll.scroll_vertical = 10000
		await settle()
		await capture("%dx%d" % [resolution.x, resolution.y])
	print("PASS ", checks, " verificações; capturas em ", output)
	quit()
