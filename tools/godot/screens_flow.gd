extends SceneTree
# Testa lobby (troca de personagem), Skins, configurações com persistência,
# estados offline e layout do menu em 1920x1080, 1280x720 e 844x390.
# Uso: godot --headless --path . -s res://tools/godot/screens_flow.gd
# Atenção: grava preferências em user://; o chamador deve restaurar os .cfg depois.

var failures := 0
var menu: Control
var nav: Node
var services: Node


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


func find_all(node: Node, type: String) -> Array:
	var found: Array = []
	for child in node.find_children("*", type, true, false):
		found.append(child)
	return found


func _run() -> void:
	root.size = Vector2i(1672, 941)
	menu = load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await frames(60)
	nav = menu.get_node("Navigation")
	services = menu.get_node("Services")
	var inventory: Node = services.inventory

	await _test_lobby_swap(inventory)
	await _test_skins(inventory)
	await _test_settings_persistence()
	_test_offline_states()
	await _test_resolutions()

	print("SCREENS_FLOW_FAILURES ", failures)
	quit(1 if failures else 0)


func _test_lobby_swap(inventory: Node) -> void:
	# Limpeza final: setas e nome saem do lobby; a troca passa só pela tela Skins.
	check(not menu.get_node("LobbyArea/Overlay/NextButton").is_visible_in_tree(), "lobby_arrows_hidden")
	check(not menu.get_node("LobbyArea/Overlay/NameLabel").is_visible_in_tree(), "lobby_name_hidden")
	var lobby: Node = menu.get_node("LobbyArea")
	var start: String = inventory.equipped_id()
	var unlocked: Array = []
	for entry: Dictionary in inventory.entries:
		if inventory.is_unlocked(entry.id):
			unlocked.append(entry.id)
	check(unlocked.size() >= 2, "skins_has_two_or_more_unlocked (%d)" % unlocked.size())
	nav.call("open", "skins", {})
	await frames(30)
	var skins: Control = menu.get_node("SkinsPanel")
	for character_id: String in unlocked:
		await skins.call("_equip", character_id)
		await frames(30)
		check(lobby.call("current_character_id") == StringName(character_id), "skins_equip_updates_stage_" + character_id)
	await skins.call("_equip", start)
	await frames(30)
	nav.call("back")
	await frames(20)
	check(inventory.equipped_id() == start, "skins_restore_start_character")


func _test_skins(inventory: Node) -> void:
	nav.call("open", "skins", {})
	await frames(40)
	var skins: Control = menu.get_node("SkinsPanel")
	check(skins.is_visible_in_tree(), "skins_visible")
	var grid: Container = skins.get("_grid")
	check(grid != null and grid.get_child_count() == inventory_count(inventory), "skins_card_count_matches_catalog")
	var seen := {}
	for entry: Dictionary in inventory.entries:
		var model_path := str(entry.get("model", ""))
		check(FileAccess.file_exists(model_path) or ResourceLoader.exists(model_path), "skins_model_resolves_" + str(entry.id))
		seen[entry.id] = true
	check(seen.size() == inventory.entries.size(), "skins_ids_unique")
	for entry: Dictionary in inventory.entries:
		skins.call("_select", entry.id)
		await frames(3)
		var preview: Node = skins.get("_preview")
		var equip: Button = null
		for candidate in find_all(preview, "Button"):
			if candidate.text in ["Equipar", "Equipado"]:
				equip = candidate
		if equip == null:
			check(false, "skins_equip_button_present_" + str(entry.id))
			continue
		var unlocked: bool = inventory.is_unlocked(entry.id)
		var equipped: bool = inventory.equipped_id() == entry.id
		check(equip.disabled == (not unlocked or equipped), "skins_equip_state_" + str(entry.id))
	nav.call("back")
	await frames(20)
	check(nav.get("_history").is_empty(), "skins_back_to_lobby")


func inventory_count(inventory: Node) -> int:
	return inventory.entries.size()


func _test_settings_persistence() -> void:
	var prefs: Node = services.preferences
	nav.call("open", "settings", {})
	await frames(40)
	var sliders := find_all(nav.get("_active"), "HSlider")
	check(sliders.size() >= 3, "settings_has_volume_sliders")
	var master: HSlider = sliders[0]
	master.value = 0.35
	await frames(5)
	check(absf(float(prefs.values.master) - 0.35) < 0.001, "settings_master_saved")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.35) < 0.02, "settings_master_applied_to_bus")
	master.value = 0.0
	await frames(5)
	check(AudioServer.is_bus_mute(0), "settings_zero_mutes_master")
	master.value = 1.0
	await frames(5)
	check(not AudioServer.is_bus_mute(0), "settings_unmute_master")

	var options := find_all(nav.get("_active"), "OptionButton")
	var quality_option: OptionButton = options[0]
	quality_option.item_selected.emit(2)
	await frames(5)
	check(prefs.values.quality == "alto", "settings_quality_saved")

	check(prefs.set_preference("accept_key", KEY_SPACE), "settings_rebind_accept")
	check(not prefs.set_preference("back_key", KEY_SPACE), "settings_rebind_rejects_duplicate")
	check(prefs.set_preference("back_key", KEY_BACKSPACE), "settings_rebind_back")
	var accept_events := InputMap.action_get_events("ui_accept")
	check(accept_events.size() == 1 and accept_events[0].physical_keycode == KEY_SPACE, "settings_key_applied_to_inputmap")

	# Persistência: uma nova instância precisa ler o arquivo salvo.
	var fresh := DevicePreferences.new()
	fresh.name = "FreshPrefs"
	root.add_child(fresh)
	await frames(3)
	check(absf(float(fresh.values.master) - 1.0) < 0.001 and fresh.values.quality == "alto", "settings_persist_after_restart")
	check(fresh.values.accept_key == KEY_SPACE and fresh.values.back_key == KEY_BACKSPACE, "settings_keys_persist_after_restart")
	fresh.queue_free()
	await frames(3)

	# Restaura padrões antes de sair.
	prefs.set_preference("accept_key", KEY_ENTER)
	prefs.set_preference("back_key", KEY_ESCAPE)
	prefs.set_preference("quality", "medio")
	nav.call("back")
	await frames(20)


func _test_offline_states() -> void:
	var mode_label := menu.get("_mode_label") as Label
	check(not services.session.authenticated(), "offline_session_unauthenticated")
	check(mode_label.text.contains("Demonstração"), "offline_mode_label_shows_demo")
	var list: VBoxContainer = menu.get_node("FriendsPanel/Margin/Content/FriendList")
	var friend_rows := 0
	for child in list.get_children():
		if child.get_script() != null and child.has_method("set") and child.get("friend_name") != null:
			friend_rows += 1
	check(friend_rows == 0, "offline_no_invented_friends")
	check(services.friends.data.get("friends", []).is_empty(), "offline_friends_data_empty")


func _test_resolutions() -> void:
	var sizes := [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(844, 390)]
	var targets := ["MenuButtons/BtnStory", "MenuButtons/BtnSkins", "MenuButtons/BtnFriends", "MenuButtons/BtnSettings", "ProfileCard", "TopBar/CoinPill", "TopBar/GemPill", "FriendsPanel/Margin/Content/ViewAllButton", "LobbyArea/Overlay/NameLabel", "LobbyArea/Overlay/NextButton", "LobbyArea/Overlay/PrevButton"]
	for size: Vector2i in sizes:
		root.size = size
		await frames(40)
		# Stretch canvas_items + expand: o conteúdo é desenhado na base 1672x941 e a área
		# visível cresce no eixo sobrando. Headless não recalcula esse stretch sozinho,
		# então a área esperada é calculada aqui com a mesma regra do motor.
		var base := Vector2(1672, 941)
		var scale := minf(size.x / base.x, size.y / base.y)
		var bounds := Rect2(Vector2.ZERO, Vector2(size) / scale)
		for target: String in targets:
			var control := menu.get_node(target) as Control
			var rect := control.get_global_rect()
			var inside := bounds.encloses(rect)
			if not inside:
				print("  rect ", target, " = ", rect, " bounds ", bounds)
			check(inside, "layout_%dx%d_inside_%s" % [size.x, size.y, target.replace("/", "_")])
		check(menu.get_node("MenuButtons/BtnStory").get_global_rect().size.y >= 40, "layout_%dx%d_story_tap_height" % [size.x, size.y])
	root.size = Vector2i(1672, 941)
	await frames(10)
