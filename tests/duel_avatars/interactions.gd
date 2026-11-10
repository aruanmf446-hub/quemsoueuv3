extends SceneTree
## Fluxo local real, com fixture explícita de vidas para provocar uma eliminação.
var checks := 0
var screen: PlayerScreen
var duel: DuelService
var shots := ""
var label := ""
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		push_error("AVATAR_UI_FAIL "+message)
		quit(1)
		assert(value,message)
func _initialize() -> void: call_deferred("_run")
func settle(frames := 2) -> void:
	for i in frames: await process_frame
func shot(name: String) -> void:
	if shots.is_empty(): return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots+"/"+label+"_"+name+".png")
func tap(control: Control) -> void:
	var point := control.get_viewport().get_final_transform()*(control.get_global_transform_with_canvas()*(control.size*0.5))
	var motion := InputEventMouseMotion.new()
	motion.position=point
	Input.parse_input_event(motion)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await settle(2)
	await settle()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	label=args[1] if args.size()>1 else "1672x941"
	var parts := label.split("x")
	root.size=Vector2i(int(parts[0]),int(parts[1]))
	UIScale.apply_device_profile(root)
	if not args.is_empty():
		shots=args[0]
		DirAccess.make_dir_recursive_absolute(shots)
	var services := PlayerServices.new()
	root.add_child(services)
	await settle()
	duel=services.duel
	await duel.use_local()
	screen=load("res://scenes/player/duel.tscn").instantiate()
	root.add_child(screen)
	screen.show_screen()
	await screen._open_form()
	await settle()
	var decks := screen.find_children("DeckChoice_*","Button",true,false)
	check(decks.size()>1,"galeria de decks real")
	var deck: Button=decks.filter(func(b: Button)->bool:return not b.button_pressed)[0]
	var before: Array=screen.get("_form").decks.duplicate()
	await tap(deck)
	check(screen.get("_form").decks==before,"deck aguarda confirmação")
	var decision: Control=deck.get_node_or_null("SelectionDecision")
	check(decision!=null,"controles sobre o deck")
	var yes: Button=decision.find_child("AcceptSelection",true,false)
	var no: Button=decision.find_child("RejectSelection",true,false)
	check(deck.get_global_rect().encloses(yes.get_global_rect()) and deck.get_global_rect().encloses(no.get_global_rect()),"✓ e ✕ cabem na capa do deck")
	await shot("deck")
	await tap(no)
	check(screen.get("_form").decks==before and not is_instance_valid(decision),"✕ cancela sem alterar os decks")
	await tap(deck)
	await tap(deck.find_child("AcceptSelection",true,false))
	check(screen.get("_form").decks.size()==before.size()+1,"✓ confirma deck por clique real")
	await duel.create("QA avatares",false,{"max_players":3,"cards_per_player":2,"selection_seconds":120,"turn_seconds":180,"deck_ids":["lendas_urbanas"]})
	duel.local_server.bot_skins=["cowboy","michelly"]
	screen.set("_view","room")
	screen.render()
	for i in 2: await duel.add_bot()
	for frame in 300:
		if is_instance_valid(screen.get("_room_stage")) and screen.get("_room_stage").character.has_animation(&"anim_2"): break
		await process_frame
	var room_stage: LobbyStage=screen.get("_room_stage")
	check(is_instance_valid(room_stage) and room_stage.character.get("_anim_player").assigned_animation=="anim_2","avatar equipado toca reação 2 na sala")
	screen.render()
	check(screen.get("_room_stage")==room_stage,"heartbeat reutiliza o palco da sala")
	await shot("sala")
	await duel.start()
	await settle()
	var battle: Control=screen.body.get_node("Match")
	var pool: Array=duel.match().pool
	var server := duel.local_server
	# Fixture controlada: o primeiro bot será eliminado ao perder esta carta.
	var bot: Dictionary=server._players.filter(func(p: Dictionary)->bool:return p.is_bot)[0]
	var target: String=server._cards[bot.member_id][0].card_id
	bot.lives=1
	var mine: Array=pool.filter(func(c: Dictionary)->bool:return str(c.card_id)!=target).slice(0,2).map(func(c: Dictionary)->String:return str(c.card_id))
	battle._activate(mine[0])
	await settle()
	yes=battle.find_child("AcceptSelection",true,false)
	check(yes.disabled,"não confirma seleção incompleta")
	battle._activate(mine[1])
	await settle()
	yes=battle.find_child("AcceptSelection",true,false)
	check(not yes.disabled and yes.get_parent().get_parent().get_parent().get("id")==mine[1],"confirmação sobre última carta selecionada")
	check(yes.get_parent().get_parent().get_parent().get_global_rect().encloses(yes.get_global_rect()),"✓ cabe na carta")
	await shot("selecao")
	var drawn: Array=duel.match().turn_order.duplicate()
	await tap(yes)
	check(duel.match().phase=="countdown","✓ confirma cartas por clique real")
	check(duel.match().turn_order==drawn,"sorteio preservado")
	await create_timer(0.5).timeout
	await shot("ordem")
	check(battle.get("_order_shown")==str(duel.match().id),"apresentação usa ordem da autoridade")
	server.clock_offset+=duel.seconds_left()+0.1
	await duel.refresh()
	# Fixture: coloca o humano na vez sem alterar a ordem sorteada.
	var human: Dictionary=server._players.filter(func(p: Dictionary)->bool:return not p.is_bot)[0]
	server._match.turn_index=drawn.find(human.member_id)-1
	server._next_turn()
	await duel.refresh()
	await settle()
	if is_instance_valid(battle.get("_presentation")): battle.get("_presentation").queue_free()
	battle._activate(target)
	await settle()
	await tap(battle.find_child("RejectSelection",true,false))
	check(str(battle.get("_pending_pick")).is_empty(),"✕ cancela eliminação por clique real")
	battle._activate(target)
	await settle()
	await tap(battle.find_child("AcceptSelection",true,false))
	check(duel.match().phase=="reveal","eliminação aceita uma vez")
	var detail: Label=battle.find_child("RoundDetail",true,false)
	if detail!=null: check(not detail.text.contains(DuelService.card_name(target)),"carta não vaza durante suspense")
	server.clock_offset+=LocalDuelServer.TIMING.suspense+0.1
	await duel.refresh()
	var layer := battle.get_node("RevealOverlay")
	var overlay: RevealOverlay=layer.get_child(0)
	check(overlay.find_child("ResultTitle",true,false).text=="REVELANDO…","título aguarda animação")
	check(overlay.find_child("ResultList",true,false).modulate.a==0.0,"eliminados ocultos antes da animação")
	await shot("suspense")
	await create_timer(1.0).timeout
	check(overlay.find_child("ResultTitle",true,false).text.contains("ELIMINADO"),"resultado aparece depois da entrada")
	await shot("derrota")
	overlay.close()
	await create_timer(0.4).timeout
	await settle()
	var grid: Control=battle.find_child("Cards",true,false)
	check(not grid.get_children().any(func(c: Node)->bool:return c.get("id")==target),"carta eliminada sai da galeria após revelação")
	await shot("galeria")
	var chat: Control=battle.find_child("BattleChat",true,false)
	check(int(chat.get("_local_count"))>0,"bot comenta no chat local")
	chat.refresh_availability() # Uma fala pendente de nova fase pode entrar quando o cooldown termina.
	var count := int(chat.get("_local_count"))
	chat.refresh_availability()
	chat.refresh_availability()
	check(int(chat.get("_local_count"))==count,"refresh não duplica fala do bot")
	# Fixture: elimina o outro bot para testar a vitória real do servidor local.
	for player: Dictionary in server._players:
		if player.is_bot: server._eliminate(str(player.member_id),"lives")
	server._check_end()
	await duel.refresh()
	await settle()
	check(duel.match().phase=="finished","resultado de vitória produzido pelo servidor local")
	check(str(battle.get("_result_shown"))==str(duel.match().id),"reação de vitória disparada uma vez")
	await create_timer(0.4).timeout
	var sequence: Control=battle.get("_presentation")
	check(is_instance_valid(sequence) and sequence.get("_stage").character.get("_anim_player").assigned_animation=="anim_4","vencedor toca o clipe 4 existente")
	await shot("vitoria")
	screen.queue_free()
	services.queue_free()
	await settle()
	print("AVATAR_UI_PASS ",checks," ",label)
	quit(0)
