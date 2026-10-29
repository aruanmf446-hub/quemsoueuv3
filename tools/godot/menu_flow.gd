extends SceneTree
# Clica de verdade no menu principal (eventos de mouse no viewport) e confere
# a navegação resultante. Uso: godot --headless --path . -s res://tools/godot/menu_flow.gd

var failures := 0
var menu: Control


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func click(target: Control) -> void:
	var point := target.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = point
	press.global_position = point
	press.pressed = true
	root.push_input(press)
	await frames(1)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)
	await frames(1)


func press_escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key)
	await frames(1)
	key.pressed = false
	root.push_input(key)
	await frames(1)


func current_route() -> String:
	var history: Array = menu.get_node("Navigation").get("_history")
	return history.back().route if not history.is_empty() else ""


func settle() -> void:
	await frames(30)


func _run() -> void:
	root.size = Vector2i(1672, 941)
	menu = load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await frames(60)

	# 1) Botões do menu principal
	var card_ids: Array[String] = []
	for child in menu.get_node("MenuButtons").get_children():
		if child.has_method("_refresh") and child.get("button_id") != null:
			card_ids.append(str(child.get("button_id")))
			if child.disabled:
				check(true, "menu_card_disabled_" + str(child.get("button_id")))
				continue
			await click(child)
			await settle()
			check(current_route() == str(child.get("button_id")), "menu_card_opens_" + str(child.get("button_id")))
			await press_escape()
			await settle()
			check(current_route() == "", "menu_card_closes_" + str(child.get("button_id")))
	check(card_ids.size() >= 4, "menu_card_count")

	# 2) Barra superior: Mail, Amizades e Configurações foram ocultados pelo lobby aprovado
	# (lobby_composition.gd), então não devem ser clicáveis. O acesso passa pelos cards.
	for path: String in ["TopBar/MailButton", "TopBar/FriendsButton", "TopBar/SettingsButton"]:
		check(not menu.get_node(path).is_visible_in_tree(), "topbar_hidden_by_design_" + path.get_file())
	await click(menu.get_node("FriendsPanel/Margin/Content/ViewAllButton"))
	await settle()
	check(current_route() == "friends", "friends_view_all_opens")
	await press_escape()
	await settle()
	check(current_route() == "", "friends_view_all_closes")

	# 3) Hotspots de perfil e carteira (criados no _hotspot)
	for hotspot: Control in [menu.get_node("ProfileCard"), menu.get_node("TopBar/CoinPill"), menu.get_node("TopBar/GemPill")]:
		await click(hotspot)
		await settle()
		var route := current_route()
		check(route in ["profile", "wallet"], "hotspot_opens_" + hotspot.name.to_lower())
		await press_escape()
		await settle()
		check(current_route() == "", "hotspot_closes_" + hotspot.name.to_lower())

	# 4) Navegação em pilha: abrir configurações sobre amigos, voltar duas vezes
	await click(menu.get_node("FriendsPanel/Margin/Content/ViewAllButton"))
	await settle()
	var nav: Node = menu.get_node("Navigation")
	nav.call("open", "settings", {})
	await settle()
	check(current_route() == "settings", "stack_push_settings")
	nav.call("back")
	await settle()
	check(current_route() == "friends", "stack_back_to_friends")
	nav.call("back")
	await settle()
	check(current_route() == "", "stack_back_to_menu")

	# 5) Rota inexistente não pode quebrar a navegação
	nav.call("open", "rota_inexistente", {})
	await settle()
	check(current_route() == "", "unknown_route_ignored")

	print("MENU_FLOW_FAILURES ", failures)
	quit(1 if failures else 0)
