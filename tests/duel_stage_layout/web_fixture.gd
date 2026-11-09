extends Control
## Isolated local fixture. Never the production main scene.
var services: PlayerServices
var screen: PlayerScreen
var battle: Control
var _bridge: JavaScriptObject
var _callback: JavaScriptObject
var _sequence := 0
func _ready() -> void:
	_run.call_deferred()
func settle() -> void:
	for i in 12: await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
func _run() -> void:
	UIScale.apply_device_profile(get_tree().root)
	print("STAGE_BOOT services")
	services=PlayerServices.new()
	add_child(services)
	await settle()
	print("STAGE_BOOT local")
	await services.duel.use_local()
	await services.duel.create("Web local fixture",false,{"max_players":4,"cards_per_player":2,"deck_ids":["lendas_urbanas"]})
	print("STAGE_BOOT bots")
	for i in 3: await services.duel.add_bot()
	screen=load("res://scenes/player/duel.tscn").instantiate()
	add_child(screen)
	screen.show_screen()
	print("STAGE_BOOT start")
	await services.duel.start()
	# Freeze authority clocks only in this isolated geometry fixture; software rendering
	# may need longer than a real selection timer to capture a screenshot.
	services.duel.local_server._match.phase_deadline=services.duel.local_server.now()+3600.0
	services.duel._beat.stop()
	screen._auto_refresh.stop()
	await settle()
	battle=screen.body.get_node("Match")
	_callback=JavaScriptBridge.create_callback(_probe)
	_bridge=JavaScriptBridge.get_interface("window")
	_bridge.stageProbe=_callback
	_bridge.stageReady=true
	print("STAGE_BOOT ready")
	_report()
func _probe(args: Array) -> void:
	print("STAGE_PROBE ",args)
	var action := str(args[0]) if args.size()>0 else ""
	if action=="reset_selection":
		services.duel.room.match.phase="selection"
		battle.set("_chosen",[])
		battle.refresh()
	elif action=="turns":
		services.duel.room.match.phase="turns"
		services.duel.room.match.turn_member=services.duel.room.match.players[0].member_id
		battle.refresh()
	elif action=="remove":
		for i in 4: services.duel.room.match.pool[i].removed=true
		battle.refresh()
	elif action=="hand":
		battle.set("_private_shown",true)
		battle.set("_private_signature","")
		battle.refresh()
	elif action=="chat": battle.find_child("BattleChat",true,false)._toggle()
	elif action.begins_with("stage:"):
		var players: Array=services.duel.room.match.players
		battle._play_sequence(players.slice(0,1),action.get_slice(":",1),6.0)
	_report()
func _rect(control: Control) -> Array:
	var r := control.get_global_rect()
	return [r.position.x,r.position.y,r.size.x,r.size.y]
func _report() -> void:
	print("STAGE_REPORT")
	_sequence+=1
	var report := {"sequence":_sequence,"size":[size.x,size.y],"phase":services.duel.match().get("phase",""),"panels":{},"cards":[],"controls":[]}
	for key in ["BattleBoard","UtilityRail","BattleChat","PrivatePanel","Players"]:
		var control := battle.find_child(key,true,false) as Control
		if control!=null: report.panels[key]=_rect(control)
	for card in battle.find_child("Cards",true,false).get_children():
		var art := card.find_child("Art",true,false) as TextureRect
		report.cards.append({"rect":_rect(card),"art_mode":art.stretch_mode,"cropped":art.texture is AtlasTexture})
	for button in battle.find_children("*","Button",true,false):
		if button.is_visible_in_tree(): report.controls.append({"name":button.name,"rect":_rect(button)})
	JavaScriptBridge.eval("window.stageReport="+JSON.stringify(report),true)
