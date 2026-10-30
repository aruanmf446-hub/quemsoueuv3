extends SceneTree
## Real NavigationManager stack: battle -> existing Settings -> battle -> lobby.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func settle() -> void:
	await create_timer(0.35).timeout
	for frame in range(4): await process_frame
func click(target: Control) -> void:
	var point := root.get_final_transform()*target.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		event.global_position=point
		root.push_input(event)
		await process_frame
	await settle()
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(844,390)
	var menu: Control=load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await settle()
	var services: PlayerServices=menu.get_node("Services")
	var nav: NavigationManager=menu.get_node("Navigation")
	nav.open("duel",{})
	await settle()
	await services.duel.use_local()
	await services.duel.create("Navegação de teste",false,{"max_players":4,"cards_per_player":2,"deck_ids":["lendas_urbanas"]})
	await services.duel.add_bot()
	await services.duel.add_bot()
	await services.duel.start()
	await settle()
	var duel_screen: PlayerScreen=nav.get("_active")
	var battle: Control=duel_screen.body.get_node("Match")
	check(battle.find_child("Cards",true,false).get_child_count()==9,"actual_route_has_nine_options")
	await click(battle.find_child("BattleSettings",true,false))
	check(nav.get("_history").back().route=="settings","battle_opens_existing_settings")
	check(not duel_screen.visible and not battle.get("_private_shown"),"settings_hides_battle_and_private_hand")
	nav.back()
	await settle()
	check(nav.get("_active")==duel_screen,"settings_returns_same_battle_instance")
	check(battle.find_child("Cards",true,false).get_child_count()==9,"return_preserves_all_options")
	check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().name=="BattleBack","return_restores_visible_focus")
	await click(battle.find_child("BattleBack",true,false))
	check(nav.get("_history").is_empty(),"battle_back_returns_real_lobby")
	check(services.duel.in_room(),"navigation_does_not_change_leave_rules")
	nav.open("duel",{})
	await settle()
	await click(battle.find_child("LeaveBattle",true,false))
	check(not services.duel.in_room(),"leave_uses_existing_service")
	check(duel_screen.get_node("Margin/Column/Header").visible,"leave_restores_regular_screen")
	menu.queue_free()
	await settle()
	print("BATTLE_NAVIGATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
