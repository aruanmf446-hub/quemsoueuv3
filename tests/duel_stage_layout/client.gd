extends SceneTree
## Local-only fixture: compare actual geometry through round state/hand/chat changes.
var failures := 0
var checks := 0
var output := ""
var battle: Control
var screen: PlayerScreen
var services: PlayerServices

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("STAGE_PASS " if ok else "STAGE_FAIL ") + label)
	if not ok: failures += 1
func settle() -> void:
	for i in 12: await process_frame
	await create_timer(0.2).timeout
func capture(label: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func geometry() -> Dictionary:
	var result := {}
	for key in ["BattleBoard", "UtilityRail", "BattleChat", "PrivatePanel"]:
		var control := battle.find_child(key,true,false) as Control
		if control != null: result[key] = control.get_global_rect()
	return result
func stable(before: Dictionary, label: String) -> void:
	var after := geometry()
	for key in before:
		check(after.has(key) and before[key].is_equal_approx(after[key]),label+" stable "+key)
func card_size() -> Vector2:
	var cards := battle.find_child("Cards",true,false)
	return cards.get_child(0).size if cards.get_child_count()>0 else Vector2.ZERO
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var resolution := (args[0] if args.size()>0 else "1672x941").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(resolution[0]),int(resolution[1]))
	UIScale.apply_device_profile(root)
	output = args[1] if args.size()>1 and not args[1].begins_with("--") else ""
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	services=PlayerServices.new()
	root.add_child(services)
	await settle()
	await services.duel.use_local()
	var response := await services.duel.create("Layout fixture",false,{"max_players":4,"cards_per_player":2,"deck_ids":["lendas_urbanas"]})
	check(response.ok,"local room")
	for i in 3: await services.duel.add_bot()
	screen=load("res://scenes/player/duel.tscn").instantiate()
	root.add_child(screen)
	screen.show_screen()
	await services.duel.start()
	await settle()
	battle=screen.body.get_node("Match")
	var before := geometry()
	var size_before := card_size()
	await capture("selection")
	var grid := battle.find_child("Cards",true,false)
	for card in grid.get_children():
		var art := card.find_child("Art",true,false) as TextureRect
		check(art != null and art.texture != null,"original art present "+card.name)
		check(art.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"full art no crop "+card.name)
		check(not art.texture is AtlasTexture,"no cropped atlas "+card.name)
		check(absf(card.size.x/card.size.y-9.0/16.0)<0.03,"portrait aspect "+card.name)
	# Authority data fixture, no backend: mimic moving to turns and losing four cards.
	services.duel.room.match.phase="turns"
	services.duel.room.match.turn_member=services.duel.room.match.players[0].member_id
	battle.refresh()
	await settle()
	stable(before,"turn transition")
	check(card_size().is_equal_approx(size_before),"same card size after phase")
	for i in 4: services.duel.room.match.pool[i].removed=true
	battle.refresh()
	await settle()
	stable(before,"removed cards")
	check(card_size().is_equal_approx(size_before),"same card size after removal")
	await capture("turns")
	services.duel.room.match.my_cards=services.duel.room.match.pool.slice(4,6).duplicate(true)
	battle.set("_private_shown",true)
	battle.set("_private_signature","")
	battle.refresh()
	await settle()
	stable(before,"private shown")
	var clip: Control=battle.find_child("PrivateCardsScroll",true,false)
	for image: Control in battle.find_children("Private_*","TextureRect",true,false):
		check(clip.get_global_rect().grow(1).encloses(image.get_global_rect()),"private illustration fully visible")
	var chat := battle.find_child("BattleChat",true,false)
	if chat != null:
		chat._toggle()
		await settle()
		stable(before,"chat toggle")
	await capture("chat_hand")
	var players_scroll: Control=battle.find_child("PlayersScroll",true,false)
	var roster_before := players_scroll.get_global_rect()
	var players: Array=services.duel.room.match.players
	var template: Dictionary=players.back().duplicate(true)
	while players.size()<20:
		var extra: Dictionary=template.duplicate(true)
		extra.member_id="roster-fixture-%d" % players.size()
		extra.nickname="Jogador %d" % players.size()
		extra.is_you=false
		players.append(extra)
	battle.refresh()
	await settle()
	check(players_scroll.get_global_rect().is_equal_approx(roster_before),"twenty players retain roster bounds")
	check(players_scroll.get_global_rect().end.x <= before.BattleBoard.position.x,"roster left of board")
	var scroll := players_scroll as ScrollContainer
	scroll.scroll_vertical = 100000
	await settle()
	var last := battle.find_child("Players",true,false).get_child(-1) as Control
	check(scroll.scroll_vertical > 0 and scroll.get_global_rect().grow(1).encloses(last.get_global_rect()),"last player reachable")
	stable(before,"twenty players")
	screen.queue_free()
	services.queue_free()
	await settle()
	print("STAGE_SUMMARY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
