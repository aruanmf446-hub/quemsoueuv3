extends SceneTree
## Do lobby à fase 02. A vitória é fixture; o percurso completo está em route.gd.
var checks := 0
var failures := 0
var menu: Control

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in count: await physics_frame
func wait_for_node(path: NodePath, seconds := 15.0) -> Node:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var node := root.get_node_or_null(path)
		if node != null: return node
		await process_frame
	return null
func find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found := find_button(child, label)
		if found != null: return found
	return null
func click(control: Control) -> void:
	check(control != null, "controle visível")
	if control == null: return
	var point := control.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	root.push_input(event, true)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(5)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var dimensions := (args[1] if args.size() > 1 else "1280x720").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(70)
	var story_entry: Control
	for card in menu.get_node("MenuButtons").get_children():
		if card.get("button_id") == "story": story_entry = card
	check(story_entry != null, "Modo História acessível no lobby")
	if story_entry == null: quit(1); return
	await click(story_entry)
	await frames(35)
	var screen: Control = menu.get_node("Navigation")._active
	var launch := screen.find_child("Launch01", true, false) as Button
	check(launch != null and not launch.disabled, "fase 01 liberada na tela atual")
	if launch == null: quit(1); return
	await click(launch)
	var story := await wait_for_node("PhaseStory") as PhaseStory
	check(story != null and story._carousel.cards.size() == 2, "história da fase 01 antes do gameplay")
	if story == null: quit(1); return
	story._carousel.next()
	var deadline := Time.get_ticks_msec() + 3000
	while story._carousel.index != 1 and Time.get_ticks_msec() < deadline: await process_frame
	check(story._carousel.index == 1, "Próximo avança para a segunda imagem")
	story._carousel.next()
	var host := await wait_for_node("StoryPrototypeSession")
	check(host != null and not menu.visible, "Começar fase abre a sessão")
	if host == null: quit(1); return
	var phase: Node3D
	for child in host.get_children():
		if child is Node3D: phase = child
	check(phase != null and phase._order == 1, "fase 01 é a campanha atual")
	if phase == null: quit(1); return
	await frames(12)
	var player: SidePlayer = phase._player
	check(player.health == 3 and player.attack_charges == 1 and player.defense_charges == 1, "vida 3/3, ataque 1/1 e defesa 1/1")
	var origin := player.position.x
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(player.position.x > origin + 1.0, "controle move El Fuego pelo mapa")
	player.fall_out()
	deadline = Time.get_ticks_msec() + 5000
	while not phase._session.opened and Time.get_ticks_msec() < deadline: await process_frame
	check(phase._session.opened and player.is_dead, "queda abre o painel de derrota")
	await click(find_button(phase._session, "Recomeçar do início"))
	await frames(15)
	check(not player.is_dead and player.health == 3 and not paused, "recomeço devolve controle e vida cheia")
	phase._on_goal_entered(player)
	await frames(5)
	check(phase.completed and phase._session.opened, "conclusão abre o resultado")
	await click(find_button(phase._session, "Próxima fase"))
	story = await wait_for_node("PhaseStory") as PhaseStory
	check(story != null and story._carousel.cards.size() == 2, "fase 02 apresenta sua própria história")
	if story == null: quit(1); return
	story._carousel.skip_requested.emit()
	deadline = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		phase = null
		for child in host.get_children():
			if child is Node3D: phase = child
		if phase != null and phase._order == 2: break
		await process_frame
	check(phase != null and phase._order == 2, "Pular história entra na fase 02")
	print("JOURNEY_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
