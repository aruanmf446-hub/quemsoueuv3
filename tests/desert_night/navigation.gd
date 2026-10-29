extends SceneTree
## Fixtures de integração de navegação: o gatilho de vitória é chamado isoladamente.
## A prova de travessia/tempo está em route.gd, nunca neste teste.
const Progress = preload("res://scripts/desert/t15d/campaign_progress.gd")
var menu: Control
var output := "/tmp/night-navigation"
var mobile := false
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func click(control: Control) -> void:
	if control == null:
		check(false,"controle esperado existe")
		return
	var point := control.get_global_rect().get_center()
	if mobile:
		var event := InputEventScreenTouch.new()
		event.index = 8
		event.position = point
		event.pressed = true
		root.push_input(event,true)
		await frames(2)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event,true)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = true
		root.push_input(event,true)
		await frames(2)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event,true)
	await frames(5)
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var button := find_button(child,text)
		if button != null: return button
	return null
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames(3)
func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"_"+label+".png") == OK,"captura real "+label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output = args[0]
	var size := (args[1] if args.size() > 1 else "1920x1080").split("x")
	mobile = int(size[1]) < 600
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]),int(size[1]))
	menu = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(70)
	var story_card: Control
	for child in menu.get_node("MenuButtons").get_children():
		if child.get("button_id") == "story": story_card = child
	await click(story_card)
	await frames(40)
	var story = menu.get_node("Navigation")._active
	check(story != null and story.is_visible_in_tree(),"Modo História abre pelo menu real")
	var first: Button = story.find_child("Launch01",true,false)
	var second: Button = story.find_child("Launch02",true,false)
	check(first != null and not first.disabled and second != null and second.disabled,"novo perfil libera só a primeira fase")
	await snap("01_historia")
	await click(first)
	var host := await wait_for_host()
	check(host != null and not menu.visible,"Jogar inicia a sessão e recolhe o menu")
	if host == null: quit(1); return
	var phase: Node3D
	for child in host.get_children():
		if child is Node3D: phase = child
	check(phase._order == 1 and not quit_on_go_back,"Fase01 assume Voltar sem fechar aplicativo")
	var legacy: CanvasLayer
	for child in host.get_children():
		if child is PrototypeReturnOverlay: legacy = child
	check(legacy != null and not legacy.visible,"retorno legado não se sobrepõe ao HUD")
	await snap("02_gameplay")
	await escape()
	check(paused and phase._session.opened,"Esc abre pausa em vez de sair da fase")
	await click(find_button(phase._session,"Continuar"))
	check(not paused,"Continuar volta à partida")
	# Isola o callback de vitória para avaliar o fluxo, sem alegar percurso ou duração.
	print("NAVIGATION_FIXTURE calling goal callback; NOT a traversal test")
	phase._on_goal_entered(phase._player)
	await frames(5)
	check(Progress.is_completed(1) and Progress.is_unlocked(2),"vitória salva desbloqueio local da próxima fase")
	check(not Progress.is_unlocked(3),"vitória de01 não libera fase03")
	await click(find_button(phase._session,"Próxima fase"))
	phase = await wait_for_phase(host,2)
	check(phase != null and phase._order == 2,"Próxima fase carrega02 com controlador novo")
	check(not quit_on_go_back,"troca01→02 preserva controle do botão Voltar")
	legacy = null
	for child in host.get_children():
		if child is PrototypeReturnOverlay: legacy = child
	check(legacy != null and not legacy.visible,"troca mantém wrapper legado recolhido")
	await escape()
	await click(find_button(phase._session,"Voltar aos reinos"))
	await frames(30)
	check(menu.visible and not paused and root.get_node_or_null("StoryPrototypeSession") == null,"retornar de02 limpa sessão e reabre os reinos")
	check(quit_on_go_back,"retorno02→menu restaura política original Voltar")
	second = story.find_child("Launch02",true,false)
	check(second != null and not second.disabled,"lista atualiza fase02 liberada sem reabrir o jogo")
	await snap("03_fase02_liberada")
	await click(second)
	host = await wait_for_host()
	check(host != null,"fase02 liberada pode ser aberta pelo botão real")
	if host != null:
		for child in host.get_children():
			if child is Node3D: phase = child
		check(phase._order == 2,"relançamento mantém identidade02")
		await escape()
		await click(find_button(phase._session,"Voltar aos reinos"))
		await frames(15)
	print("NIGHT_NAVIGATION_RESULT checks=",checks," failures=",failures," mobile=",mobile)
	quit(1 if failures else 0)

func wait_for_host() -> Node:
	var deadline := Time.get_ticks_msec()+12000
	while Time.get_ticks_msec() < deadline:
		var host := root.get_node_or_null("StoryPrototypeSession")
		if host != null: return host
		await process_frame
	return null

func wait_for_phase(host: Node, order: int) -> Node3D:
	var deadline := Time.get_ticks_msec()+12000
	while Time.get_ticks_msec() < deadline:
		for child in host.get_children():
			if child is Node3D and child.get("_order") == order: return child
		await process_frame
	return null
