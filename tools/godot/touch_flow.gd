extends SceneTree
# Toque real: InputEventScreenTouch (press e release) nos alvos do menu e do lobby.
# Uso: godot --headless --path . -s res://tools/godot/touch_flow.gd

var failures := 0
var menu: Control
var nav: Node


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func tap(target: Control) -> void:
	var point := target.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	root.push_input(down)
	await frames(1)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = point
	up.pressed = false
	root.push_input(up)
	await frames(1)


func current_route() -> String:
	var history: Array = nav.get("_history")
	return history.back().route if not history.is_empty() else ""


func settle() -> void:
	await frames(30)


func _run() -> void:
	root.size = Vector2i(1672, 941)
	menu = load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await frames(60)
	nav = menu.get_node("Navigation")
	var inventory: Node = menu.get_node("Services").inventory

	for card_name: String in ["BtnStory", "BtnSkins", "BtnFriends", "BtnSettings"]:
		var card := menu.get_node("MenuButtons/" + card_name) as Button
		var expected := str(card.get("button_id"))
		await tap(card)
		await settle()
		check(current_route() == expected, "touch_card_opens_" + expected)
		var back_key := InputEventKey.new()
		back_key.keycode = KEY_ESCAPE
		back_key.physical_keycode = KEY_ESCAPE
		back_key.pressed = true
		root.push_input(back_key)
		await frames(2)
		check(current_route() == "", "touch_card_back_" + expected)

	await tap(menu.get_node("FriendsPanel/Margin/Content/ViewAllButton"))
	await settle()
	check(current_route() == "friends", "touch_view_all_opens")
	nav.call("back")
	await settle()

	# Limpeza final: setas ocultas no lobby; a troca por toque passa pela tela Skins.
	check(not menu.get_node("LobbyArea/Overlay/NextButton").is_visible_in_tree(), "touch_lobby_arrows_hidden")
	var start: String = inventory.equipped_id()
	nav.call("open", "skins", {})
	await frames(30)
	var skins: Control = menu.get_node("SkinsPanel")
	var other := ""
	for entry: Dictionary in inventory.entries:
		if entry.id != start and inventory.is_unlocked(entry.id):
			other = entry.id
			break
	await skins.call("_equip", other)
	await frames(30)
	check(inventory.equipped_id() == other, "touch_skins_equip_changes_character")
	await skins.call("_equip", start)
	await frames(30)
	nav.call("back")
	await settle()
	check(inventory.equipped_id() == start, "touch_skins_restore_start")

	print("TOUCH_FLOW_FAILURES ", failures)
	quit(1 if failures else 0)
