extends SceneTree
## Native input and geometry, using the real local duel. Stress fixtures never enter catalogs.
const ME := "00000000-0000-4000-8000-0000000000aa"
const FRIEND := "00000000-0000-4000-8000-0000000000b1"
var failures := 0
var checks := 0
var screen: PlayerScreen
var services: PlayerServices
var battle: Control
var output := ""
var navigated := ""
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	print(("PASS " if value else "FAIL ") + label)
	if not value: failures += 1
func settle() -> void:
	for frame in range(6): await process_frame
	await create_timer(0.16).timeout
func click(target: Control) -> void:
	var point := root.get_final_transform()*target.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await settle()
func capture(label: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture_"+label)
func inside(node: Control, outer: Control) -> bool:
	return outer.get_global_rect().grow(1).encloses(node.get_global_rect())
func geometry(label: String, expected: int) -> void:
	var grid: GridContainer = battle.find_child("Cards",true,false)
	check(grid.get_child_count()==expected,label+"_all_options")
	var bounds: Rect2 = grid.get_global_rect()
	for card: Control in grid.get_children():
		check(inside(card,grid) and inside(card,screen),label+"_visible_"+card.name)
		var art := card.find_child("Art",true,false) as TextureRect
		check(art != null and art.texture != null,label+"_original_art_"+card.name)
	for name in ["PublicArea","UtilityRail","RoomControls","PrivatePanel","Players"]:
		var control: Control = battle.find_child(name,true,false)
		check(inside(control,screen),label+"_bounds_"+name)
	check(screen.get_node("Margin/Column/Scroll").vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,label+"_no_board_scroll")
	var ancestor: Node = grid.get_parent()
	var unscrolled := true
	while ancestor != battle:
		if ancestor is ScrollContainer: unscrolled = false
		ancestor = ancestor.get_parent()
	check(unscrolled,label+"_public_area_never_scrolls")
	var rail: Control = battle.find_child("UtilityRail",true,false)
	print("RAIL ",label," ",rail.get_global_rect()," minimum=",rail.get_combined_minimum_size())
	if label=="confirmation":
		for key in ["_canvas","_main","_board","_board_content","_grid","_roster"]:
			var node: Control=battle.get(key)
			print("LAYOUT ",key," size=",node.size," min=",node.get_combined_minimum_size())
	print("GEOMETRY ",label," grid=",bounds," screen=",screen.size)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var parts := (args[0] if args.size()>0 else "844x390").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(parts[0]),int(parts[1]))
	if args.size()>1:
		output = ProjectSettings.globalize_path(args[1])
		DirAccess.make_dir_recursive_absolute(output)
	services = PlayerServices.new()
	root.add_child(services)
	await settle()
	await services.duel.use_local()
	var created := await services.duel.create("Batalha de teste",false,{"max_players":4,"cards_per_player":2,"deck_ids":["lendas_urbanas"]})
	check(created.ok,"real_local_room")
	await services.duel.add_bot()
	await services.duel.add_bot()
	screen = load("res://scenes/player/duel.tscn").instantiate()
	root.add_child(screen)
	screen.navigate_requested.connect(func(route: String,_params: Dictionary) -> void: navigated=route)
	screen.show_screen()
	await services.duel.start()
	await settle()
	battle = screen.body.get_node("Match")
	geometry("selection",9)
	check(not screen.get_node("Margin/Column/Header").visible,"single_battle_header")
	check(battle.find_child("CopyRoomCode",true,false)==null,"offline_no_fake_invite")
	check(battle.find_child("VoiceUnavailable",true,false)!=null,"voice_truthful_unavailable")
	await capture("selection")
	var grid: GridContainer = battle.find_child("Cards",true,false)
	var first_bounds: Rect2 = grid.get_child(0).get_global_rect()
	await click(grid.get_child(0))
	grid = battle.find_child("Cards",true,false)
	await click(grid.get_child(1))
	check(battle.get("_chosen").size()==2,"real_pointer_selects_two")
	check(grid.get_child(0).get_global_rect().is_equal_approx(first_bounds),"selection_does_not_shift_cards")
	await click(battle.find_child("ConfirmSelection",true,false))
	check(services.duel.match().phase=="countdown","real_selection_committed")
	(services.duel.get("_beat") as Timer).stop()
	services.duel.local_server.clock_offset += 5.1
	await services.duel.refresh()
	(services.duel.get("_beat") as Timer).stop()
	await settle()
	geometry("turns",9)
	var hand: GridContainer = battle.find_child("PrivateCards",true,false)
	check(hand.get_child_count()==1 and hand.get_child(0).name=="HiddenHand","hand_hidden_by_default")
	await capture("battle")
	await click(battle.find_child("TogglePrivateCards",true,false))
	check(hand.get_child_count()==2 and hand.get_child(0) is TextureRect,"private_hand_from_real_data")
	geometry("hand_open",9)
	await capture("private-hand")
	await click(battle.find_child("TogglePrivateCards",true,false))
	check(hand.get_child(0).name=="HiddenHand","private_hand_hides_again")
	# Presentation-only fixture: force the real local player to the active UI state.
	# Does not call a pick RPC with synthetic state; original data is restored below.
	(services.duel.get("_beat") as Timer).stop()
	var real_data := services.duel.room.duplicate(true)
	services.duel.room.match.phase = "turns"
	services.duel.room.match.turn_member = services.duel.room.you.member_id
	battle.refresh()
	await settle()
	grid = battle.find_child("Cards",true,false)
	var target := (services.duel.match().pool as Array).find_custom(func(item: Dictionary) -> bool: return not item.removed)
	await click(grid.get_child(target))
	check(battle.get("_pending_pick")==str(services.duel.match().pool[target].card_id),"inline_pick_confirmation")
	geometry("confirmation",9)
	check(battle.find_child("CancelPick",true,false).visible,"cancel_available")
	await capture("confirmation")
	await click(battle.find_child("CancelPick",true,false))
	check(battle.get("_pending_pick").is_empty(),"cancel_keeps_state")
	await click(battle.find_child("BattleSettings",true,false))
	check(navigated=="settings","existing_settings_route_requested")
	# Seven actual original entries, no placeholders added to fill the third row.
	services.duel.room.match.pool = real_data.match.pool.slice(0,7)
	battle.refresh()
	await settle()
	geometry("seven_fixture",7)
	services.duel.room = real_data.duplicate(true)
	battle.refresh()
	await settle()
	# Stress layouts: repeat only existing original artwork IN MEMORY, not a public deck.
	var pool: Array = []
	for index in range(30): pool.append(real_data.match.pool[index%9].duplicate(true))
	services.duel.room.match.pool = pool
	battle.refresh()
	await settle()
	geometry("thirty_layout_fixture",30)
	services.duel.room = real_data.duplicate(true)
	battle.refresh()
	await settle()
	# UI stress: many participants, real portraits and synthetic member IDs only in memory.
	for count in [5,12,20]:
		var players: Array = []
		for index in range(count):
			var player: Dictionary = real_data.match.players[index%3].duplicate(true)
			player.member_id = "layout_fixture_%d" % index
			player.is_you = index == 0
			player.lives = 6
			players.append(player)
		services.duel.room.match.players = players
		battle.refresh()
		await settle()
		geometry("players_%d_fixture" % count,9)
		var roster: Control = battle.find_child("Players",true,false)
		for panel: Control in roster.get_children(): check(inside(panel,roster),"roster_cell_%d" % count)
	services.duel.room = real_data.duplicate(true)
	battle.refresh()
	await settle()
	# No premature damage reaction while event.hits is intentionally hidden by suspense.
	var victim: Dictionary = services.duel.room.match.players[0]
	var previous := int(victim.lives)
	victim.lives = 0
	victim.eliminated = true
	victim.reason = "lives"
	services.duel.room.match.phase = "reveal"
	services.duel.room.match.events = [{"seq":999,"kind":"pick","actor":victim.member_id,"card_id":real_data.match.pool[0].card_id,"revealed":false,"hits":null}]
	battle.refresh()
	await settle()
	check(int(battle.get("_last_lives")[victim.member_id])==previous,"suspense_keeps_last_revealed_lives")
	services.duel.room.match.events[0].revealed=true
	services.duel.room.match.events[0].hits=[{"member_id":victim.member_id,"lives":0,"eliminated":true}]
	battle.refresh()
	await create_timer(0.55).timeout
	check(int(battle.get("_last_lives")[victim.member_id])==0,"revealed_damage_updates_top_panel")
	var roster: Control=battle.find_child("Players",true,false)
	var portrait: Control=roster.get_node("Player_"+str(victim.member_id)).find_child("Portrait",true,false)
	check(portrait.modulate.is_equal_approx(Color("#555967")),"eliminated_avatar_desaturated")
	await create_timer(3.6).timeout
	check(battle.find_child("BattleNotice",true,false).text.is_empty(),"notification_expires_outside_board")
	services.duel.room=real_data.duplicate(true)
	battle.refresh()
	await settle()
	# Existing ChatService, simulated transport. No live tokens or messaging.
	services.session.user={"id":ME}
	services.session._expires_at=Time.get_unix_time_from_system()+3600
	services.client.access_token="fixture-only"
	for service in [services.friends,services.wallet,services.profile,services.progression]: service.fetched_at=Time.get_ticks_msec()/1000.0
	services.friends.data={"friends":[{"user_id":FRIEND,"nickname":"Amigo de teste","equipped_character_id":"lana"}],"incoming":[],"outgoing":[]}
	if services.chat.transport != null: services.chat.transport.queue_free()
	var fake: Node = load("res://tests/chat/fixture_transport.gd").new()
	fake.friends=[FRIEND]
	root.add_child(fake)
	services.chat.transport=fake
	services.chat.me_id=ME
	var chat: Control=battle.find_child("BattleChat",true,false)
	chat.call("refresh_availability")
	var selector: OptionButton=chat.find_child("ChatFriend",true,false)
	selector.select(1)
	selector.item_selected.emit(1)
	await settle()
	check(services.chat.is_open(),"existing_private_chat_open")
	var input: LineEdit=chat.find_child("ChatInput",true,false)
	input.text="Mensagem da fixture"
	await click(chat.find_child("ChatSend",true,false))
	check(fake.calls.send==1 and services.chat.messages().size()==1,"existing_chat_service_send")
	fake.deliver(services.chat.conversation_id,FRIEND,"Resposta da fixture")
	await services.chat.poll()
	await settle()
	check(services.chat.messages().size()==2,"existing_chat_receives")
	geometry("chat_open",9)
	await capture("chat-fixture")
	services.chat.clear()
	services.session.user={}
	services.client.access_token=""
	chat.call("refresh_availability")
	await settle()
	check(chat.get("_rendered").is_empty(),"logout_clears_private_bubbles")
	check(not input.editable,"logout_blocks_composer")
	await click(battle.find_child("TogglePrivateCards",true,false))
	screen.hide()
	await settle()
	check(not battle.get("_private_shown") and not services.chat.is_open(),"hide_protects_hand_and_stops_polling")
	screen.show()
	services.duel.room=real_data
	await services.duel.leave()
	await settle()
	check(screen.get_node("Margin/Column/Header").visible,"leaving_restores_lobby_layout")
	screen.queue_free()
	fake.queue_free()
	await settle()
	services.queue_free()
	await settle()
	print("BATTLE_REFERENCE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
