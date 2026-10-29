extends "res://tools/godot/phase01_scenario.gd"
## Entrada pelo menu, pausa e bot de percurso real. Sem atribuir posição dos atores.
var _menu: Control
var _mobile := false
var _checks := 0
func check(ok: bool, label: String) -> void:
	_checks += 1
	super.check(ok,label)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_prefix = args[0] if args.size() > 0 else "/tmp/t15d-journey"
	var size := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]),int(size[1]))
	_mobile = root.size.y < 600
	await physics_frame
	_menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(_menu)
	current_scene = _menu
	await _frames(70)
	var story_card: Control
	for card in _menu.get_node("MenuButtons").get_children():
		if card.get("button_id") == "story": story_card = card
	check(story_card != null,"card Modo História acessível no menu")
	await click(story_card)
	await _frames(35)
	var story = _menu.get_node("Navigation")._active
	check(story != null and story.is_visible_in_tree(),"Modo História aberto por clique real")
	await click(find_button(story,"Iniciar protótipo"))
	await _frames(55)
	var host := root.get_node_or_null("StoryPrototypeSession")
	check(host != null and not _menu.visible,"menu inicia uma sessão de gameplay")
	if host == null: quit(1); return
	_phase = host.get_child(0)
	_player = _phase._player
	_platforms = (JSON.parse_string(FileAccess.get_file_as_string(PLATFORMS_PATH)) as Dictionary).platforms
	_player.died.connect(func() -> void: _deaths += 1)
	check(_player.is_on_floor() and not _player.is_dead,"entrada pelo menu pousa em chão seguro")
	check(not host.get_child(1).visible,"retorno antigo recolhido sem sobrepor HUD")
	await _snap("01_entrada_real")
	await escape()
	check(paused and _phase._session.opened,"Esc abre pausa e congela a partida")
	var initial := _player.position
	await _frames(30)
	check(_player.position.distance_to(initial) < 0.001,"jogador imóvel durante pausa")
	await _snap("02_pausa")
	await click(find_button(_phase._session,"Continuar"))
	check(not paused and not _phase._session.opened,"Continuar retoma por mouse/toque")
	await _frames(15)
	await _walk_to(12.2,7,true,false)
	check(_phase._checkpoint.x == 12,"percurso real ativa primeiro checkpoint")
	await escape()
	await click(find_button(_phase._session,"Retomar do checkpoint"))
	await _frames(20)
	check(not paused and _player.health == 5 and absf(_player.position.x-12)<1,"retomar checkpoint restaura vida e controle")
	await escape()
	await click(find_button(_phase._session,"Recomeçar fase"))
	await _frames(30)
	check(not _phase.completed and _phase._checkpoint.x == -8 and get_nodes_in_group("enemies").size() == 3,"reinício restaura mapa e três Cactus")
	check(_player.health == 5 and _player.is_on_floor(),"reinício entrega personagem vivo no início")
	# Ida/volta pelo wrapper real, preservando a rota e liberando o relançamento.
	await escape()
	await click(find_button(_phase._session,"Voltar aos reinos"))
	await _frames(20)
	check(_menu.visible and not paused and root.get_node_or_null("StoryPrototypeSession") == null,"retorno limpa sessão e mostra os reinos")
	await click(find_button(story,"Iniciar protótipo"))
	await _frames(45)
	host = root.get_node("StoryPrototypeSession")
	_phase = host.get_child(0)
	_player = _phase._player
	_player.died.connect(func() -> void: _deaths += 1)
	check(get_nodes_in_group("player").size() == 1,"relançar não duplica jogador nem sessão")
	# Trecho inteiro: somente ações de movimento/salto/combate desde o spawn.
	await _walk_to(15.5,18,true,true)
	await _snap("03_primeiro_combate")
	await _walk_to(31.0,20,true,true)
	await _snap("04_canions")
	for attempt in range(5):
		await _walk_to(52.0,40,true,true)
		if _phase.completed: break
		if _player.is_dead:
			await _wait_until(func() -> bool: return not _player.is_dead,4)
	check(_phase.completed,"jornada do menu até a saída sem teleporte")
	check(_phase._bar.value == 100 and _phase._session.opened,"vitória fecha progresso e apresenta ações")
	check(not _phase._touch_pad.visible and not _player.is_physics_processing(),"vitória encerra controle sem queda ou toque preso")
	check(_phase._scenery.travel > 0.97 and _phase._scenery.parallax_offset > 0.0,"panorâmica e paralaxe acompanham o percurso")
	await _snap("05_conclusao")
	await click(find_button(_phase._session,"Jogar novamente"))
	await _frames(30)
	check(not _phase.completed and _player.is_on_floor() and _player.health == 5,"Jogar novamente reabre uma partida funcional")
	check(get_nodes_in_group("enemies").size() == 3 and _phase._defeated == 0,"replay restaura inimigos e estatísticas")
	# Valida navegação para a próxima cena sem fazer uma segunda travessia.
	# O botão usa o mesmo callback real de avanço; estado de conclusão isolado.
	_phase._on_goal_entered(_player)
	await _frames(3)
	await click(find_button(_phase._session,"Próxima fase"))
	await _frames(40)
	var next_scene: Node
	for child in host.get_children():
		if child is Node3D: next_scene = child
	check(next_scene != null and next_scene.scene_file_path.ends_with("phase_02.tscn"),"Próxima fase abre cena existente sem alterar seus dados")
	check(host.get_child(0) is CanvasLayer and host.get_child(0).visible,"wrapper de retorno restaurado para a fase legada")
	await click(find_button(host.get_child(0),"‹ Voltar aos reinos"))
	await _frames(20)
	check(_menu.visible and not paused,"retorno após avançar preserva menu")
	check(quit_on_go_back,"sair da Fase 01 restaura a política Voltar do aplicativo")
	print("JOURNEY_RESULT checks=",_checks," failures=",failures," deaths=",_deaths," mobile=",_mobile)
	quit(1 if failures else 0)
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var button := find_button(child,text)
		if button != null: return button
	return null
func click(control: Control) -> void:
	if control == null:
		check(false,"botão esperado existe")
		return
	var point := control.get_global_rect().get_center()
	if _mobile:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 7
		event.pressed = true
		root.push_input(event,true)
		await _frames(2)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event,true)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		root.push_input(event,true)
		await _frames(2)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event,true)
	await _frames(3)
func escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
	await _frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await _frames(2)
