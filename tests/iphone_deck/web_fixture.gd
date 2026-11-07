extends Node
## Isolated Web export only; all account/deck calls use fixtures, never Supabase.
var services: PlayerServices
var ui: Control
var callback: JavaScriptObject
var fixture_mode := "deck"
var report_sequence := 0
var fixture_game: SupabaseClient
func _ready() -> void:
	if OS.has_feature("web") and not OS.has_feature("iphone_layout_fixture"):
		push_error("Use only the isolated fixture export")
		return
	_run.call_deferred()
func _run() -> void:
	services=PlayerServices.new()
	add_child(services)
	await get_tree().process_frame
	var mode := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('fixture')||'nickname'")) if OS.has_feature("web") else fixture_mode
	var fake: SupabaseClient
	if mode=="community": fake=preload("res://tests/community_attribution/fake_game.gd").new()
	elif mode=="claim": fake=preload("res://tests/community_claims/visual_game.gd").new()
	elif mode=="report": fake=preload("res://tests/deck_runtime_corrections/fake_game.gd").new()
	elif mode=="stripe": fake=preload("res://tests/coin_store/fake_game.gd").new()
	elif mode in ["emotes","coins","variations"]: fake=preload("res://tests/skin_emotes/fake_game.gd").new()
	elif mode=="player_report": fake=preload("res://tests/player_reports/fake_game.gd").new()
	else: fake=preload("res://tests/community_t27/fake_game.gd").new()
	add_child(fake)
	fixture_game=fake
	if mode=="claim":
		services.community_decks.queue_free()
		services.community_decks=preload("res://tests/community_claims/visual_service.gd").new()
		services.add_child(services.community_decks)
	var profile := preload("res://tests/nickname_onboarding/fake_profile_client.gd").new()
	add_child(profile)
	fake.user=profile.user_id
	fake.access_token="fixture-not-real"
	services.client=fake
	services.session.client=fake
	services.session.user={"id":profile.user_id,"user_metadata":{"name":"Nome do Gmail"}}
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	services.session.set_process(false)
	services.profile.client=profile
	services.profile.data=profile.profile()
	services.profile.state="success"
	services.friends.client=fake
	services.emote_shop.client=fake
	services.wallet.client=fake
	services.coin_store.client=fake
	if mode in ["coins","stripe"]:
		await services.wallet.refresh()
		ui=load("res://scenes/player/wallet.tscn").instantiate()
		add_child(ui)
		ui.show_screen({"tab":"coins"})
	elif mode in ["emotes","variations"]:
		services.progression.state="success"
		services.progression.data={"unlocked_character_ids":PlayerContracts.initial_ids(),"equipped_character_id":"cowboy"}
		ui=load("res://scenes/skins/skins_panel.tscn").instantiate()
		add_child(ui)
		# Os retratos distribuídos já cobrem a galeria. Testar só as novas prévias.
		ui._generating=true
		if mode=="variations":
			for entry: Dictionary in CharacterCatalog.load_entries():
				ui._paths[str(entry.id)]="res://assets/portraits/"+str(entry.id)+".png"
		ui.open("cowboy")
	elif mode=="player_report":
		services.profile.client=fake
		ui=load("res://scenes/player/public_profile.tscn").instantiate()
		add_child(ui)
		ui.show_screen({"public_id":fake.target.public_id})
		await get_tree().process_frame
		ui._open_report(fake.target.public_id)
		fake.report_code="cannot_report_self"
	elif mode=="nickname":
		services.profile.state="loading"
		ui=preload("res://scripts/ui/nickname_onboarding.gd").new()
		ui.setup(services)
		add_child(ui)
		await get_tree().create_timer(0.35).timeout
		services.profile.state="success"
		services.profile.changed.emit()
	else:
		ui=load("res://scenes/player/deck_library.tscn").instantiate()
		add_child(ui)
		if mode=="claim": ui._render_deck(fake.gallery())
		elif mode=="status": await _seed_submission()
		elif mode=="report":
			await ui._open_community(fake.PUBLISHED)
			fake.report_code="cannot_report_own"
			ui._report_deck(fake.PUBLISHED)
		elif mode=="community":
			fake.rows.back().status="published"
			fake.rows.back().visibility="public"
			CommunityService.items=[]
			CommunityService.state="idle"
			CommunityService.loaded_at=-1000.0
			CommunityService.next_cursor=""
			ui._render_library()
		else: ui._create_deck()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.qseSetInternalScreen && window.qseSetInternalScreen(true)")
		callback=JavaScriptBridge.create_callback(_probe)
		JavaScriptBridge.get_interface("window").qseDeckInputProbe=callback
		await get_tree().create_timer(1.0).timeout
		_probe([])
		JavaScriptBridge.eval("window.qseDeckInputReady=true")
func _seed_submission() -> void:
	var store := DeckDrafts.for_current()
	for old in store.list(): store.delete(str(old.id))
	var draft := store.new_draft()
	draft.name="[TESTE] Rappers"
	draft.description="Artistas do rap em cartas. Fixture local sem rede."
	draft.category="Personagens"
	store.save(draft)
	var image := (load("res://assets/duel/decks/oficial/lendas_urbanas/momo.png") as Texture2D).get_image()
	for i in 5:
		var card := {"id":"test_"+str(i),"name":"Artista "+str(i+1),"crops":{}}
		card.image_file=store.store_original(str(draft.id),str(card.id),image.save_png_to_buffer(),"png")
		store.store_previews(str(draft.id),card,image)
		draft.cards.append(card)
	await CreatorSync.for_current(store).push(draft)
	fixture_game.db.qse_creator_decks[0].status="rejected"
	fixture_game.db.qse_creator_decks[0].review_note="As imagens não correspondem aos artistas de rap descritos. Corrija as cartas e envie novamente."
	draft.server_status="pending_review"
	store.save(draft)
	ui._pulled_decks=true
	ui._draft=draft
	ui._open_submissions()

func _probe(args: Array) -> void:
	if args.size() and str(args[0]).begins_with("variation_character:"):
		ui._select(str(args[0]).trim_prefix("variation_character:"))
	if args.size() and str(args[0])=="owned_collection": ui._select_tab("Meus Decks")
	if args.size() and str(args[0])=="report_success" and is_instance_valid(fixture_game):
		fixture_game.report_code=""
	if args.size() and str(args[0])=="approve_fixture" and is_instance_valid(fixture_game):
		fixture_game.db.qse_creator_decks[0].status="published"
		fixture_game.db.qse_creator_decks[0].review_note=null
	if args.size() and str(args[0]).begins_with("focus:"):
		var target := ui.find_child(str(args[0]).trim_prefix("focus:"),true,false) as Control
		var scroll := ui.get_node_or_null("Margin/Column/Scroll") as ScrollContainer
		if target!=null and scroll!=null and scroll.is_ancestor_of(target): scroll.ensure_control_visible(target)
	if args.size() and str(args[0])=="bottom":
		var scroll: ScrollContainer=ui.get_node("Margin/Column/Scroll")
		scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	report_sequence+=1
	var result := {"sequence":report_sequence,"size":[ui.size.x,ui.size.y],"controls":[],"fields":{},"cards":0,"labels":[],"emote_thumbnails":[]}
	if ui.get("_selected_styles") is Dictionary:
		result.variations={"character":ui._selected,"style":ui._selected_styles.get(ui._selected,"original"),"thumbnails":[]}
	if services.emote_shop!=null and services.emote_shop.state=="success":
		result.shop={"coins":services.emote_shop.data.get("coins",""),"owned":services.emote_shop.product("dance_01").get("owned",false)}
	if services.wallet.state=="success": result.wallet_coins=services.wallet.data.get("coins","")
	if ui.get("_stage") is LobbyStage and is_instance_valid(ui.get("_stage")):
		var stage: LobbyStage=ui.get("_stage")
		result.preview_render={"static":stage.static_preview,"update":stage.get_node("Viewport").render_target_update_mode}
		var player: AnimationPlayer=stage.character.get("_anim_player")
		if player!=null: result.emote={"animation":player.assigned_animation,"playing":player.is_playing(),"static":stage.character.is_static_pose}
	for node: Control in ui.find_children("*","Control",true,false):
		if not node.is_visible_in_tree(): continue
		if node is Label: result.labels.append(node.text)
		if node is TextureRect and str(node.name).begins_with("EmoteThumbnail_"):
			result.emote_thumbnails.append({"name":str(node.name),"ready":node.texture!=null,"height":node.size.y})
		if node is TextureRect and str(node.name).begins_with("VariationThumbnail_"):
			result.variations.thumbnails.append({"name":str(node.name),"ready":node.texture!=null,"height":node.size.y})
		if node is LineEdit or node is TextEdit: result.fields[str(node.name)]=str(node.text)
		if node is BaseButton or node is LineEdit or node is TextEdit:
			var r := node.get_global_rect()
			result.controls.append({"name":str(node.name),"rect":[r.position.x,r.position.y,r.size.x,r.size.y]})
	if ui.get("_draft") is Dictionary:
		result.cards=ui._draft.get("cards",[]).size()
		result.card_names=ui._draft.get("cards",[]).map(func(c:Dictionary)->String:return str(c.get("name","")))
		result.description=str(ui._draft.get("description",""))
		result.name=str(ui._draft.get("name",""))
		result.category=str(ui._draft.get("category",""))
		result.cover=ui._draft.get("cover",{})
	JavaScriptBridge.eval("window.qseDeckInputReport="+JSON.stringify(result))
