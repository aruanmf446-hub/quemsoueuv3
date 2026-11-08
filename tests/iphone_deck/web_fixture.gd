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
	if OS.has_feature("web") and str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('fixture')"))=="fbx_dance":
		add_child(preload("res://tests/fbx_dance/preview.gd").new())
		return
	services=PlayerServices.new()
	add_child(services)
	await get_tree().process_frame
	var mode := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('fixture')||'nickname'")) if OS.has_feature("web") else fixture_mode
	if OS.has_feature("web"):
		var locale := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('lang')||'pt_BR'"))
		if DevicePreferences._valid("locale",locale): services.preferences.set_preference("locale",locale)
	var fake: SupabaseClient
	if mode=="manual_claim": fake=preload("res://tests/lado_sombrio_claim/fake_game.gd").new()
	elif mode=="i18n": fake=preload("res://tests/i18n_expanded/fake_game.gd").new()
	elif mode in ["languages","public_profile","friends_search","duel_admin"]: fake=preload("res://tests/profile_languages/fake_game.gd").new()
	elif mode in ["ability_refills","refill_store"]: fake=preload("res://tests/ability_refills/fake_game.gd").new()
	elif mode.begins_with("commerce"): fake=preload("res://tests/commerce/fake_game.gd").new()
	elif mode=="community": fake=preload("res://tests/community_attribution/fake_game.gd").new()
	elif mode=="universal": fake=preload("res://tests/skin_emotes/universal_game.gd").new()
	elif mode=="claim": fake=preload("res://tests/community_claims/visual_game.gd").new()
	elif mode=="report": fake=preload("res://tests/deck_runtime_corrections/fake_game.gd").new()
	elif mode=="stripe": fake=preload("res://tests/coin_store/fake_game.gd").new()
	elif mode in ["emotes","coins","variations","samba"]: fake=preload("res://tests/skin_emotes/fake_game.gd").new()
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
	if mode=="universal": fake.account=profile.user_id
	services.session._expires_at=Time.get_unix_time_from_system()+86400.0
	services.session.set_process(false)
	services.profile.client=profile
	services.profile.data=profile.profile()
	services.profile.state="success"
	services.friends.client=fake
	services.emote_shop.client=fake
	services.wallet.client=fake
	services.coin_store.client=fake
	services.cosmetic_shop.client=fake
	services.ability_refills.client=fake
	if mode.begins_with("commerce"): await services.cosmetic_shop.refresh()
	if mode=="manual_claim":
		services.rewards.client=fake
		await services.rewards.refresh()
		await _i18n_screen("lobby")
	elif mode=="commerce_entrypoints":
		await _i18n_screen("lobby")
	elif mode=="i18n":
		profile.nickname="NicknameOriginal"
		services.profile.data=profile.profile()
		await _i18n_screen("editor")
	elif mode in ["languages","public_profile","friends_search","duel_admin"]:
		profile.nickname="VisitanteTeste"
		services.profile.data=profile.profile()
		if mode=="languages":
			ui=load("res://scenes/player/settings.tscn").instantiate()
			add_child(ui)
			ui._category=4
			ui.show_screen()
		elif mode=="public_profile":
			services.profile.client=fake
			ui=load("res://scenes/player/public_profile.tscn").instantiate()
			add_child(ui)
			ui.show_screen({"public_id":fake.target.public_id})
		elif mode=="friends_search":
			services.friends.state="success"
			services.friends.data={"friends":[],"incoming":[],"outgoing":[]}
			ui=load("res://scenes/player/friends.tscn").instantiate()
			add_child(ui)
			ui.show_screen({"tab":"search"})
			await ui._search("aruan")
		else:
			await services.duel.use_local()
			await services.duel.create("Sala de teste", false, {"deck_ids":["lendas_urbanas"]})
			ui=load("res://scenes/player/duel.tscn").instantiate()
			add_child(ui)
			ui.show_screen()
			await ui._open_form()
	elif mode=="ability_refills":
		ui=preload("res://tests/ability_refills/visual.gd").new()
		add_child(ui)
	elif mode in ["coins","stripe","commerce","refill_store"]:
		await services.wallet.refresh()
		ui=load("res://scenes/player/wallet.tscn").instantiate()
		add_child(ui)
		ui.show_screen({"tab":"coins","category":"refills"} if mode=="refill_store" else {"tab":"coins"})
	elif mode in ["emotes","variations","universal","samba","commerce_skins"]:
		services.progression.state="success"
		services.progression.data={"unlocked_character_ids":PlayerContracts.initial_ids(),"equipped_character_id":"cowboy"}
		ui=load("res://scenes/skins/skins_panel.tscn").instantiate()
		add_child(ui)
		# Os retratos distribuídos já cobrem a galeria. Testar só as novas prévias.
		ui._generating=true
		if mode=="variations":
			for entry: Dictionary in CharacterCatalog.load_entries():
				ui._paths[str(entry.id)]="res://assets/portraits/"+str(entry.id)+".png"
		if mode in ["emotes","universal"]: ui._shop_item="dance_01"
		ui.open("cowboy")
		if mode=="samba" or mode=="commerce_skins": ui._choose_cosmetic_mode("shop")
		if mode=="universal":
			_fixture_universal_motion()
			ui._choose_cosmetic_mode("shop")
			ui.heading.text="Emotes universais · teste"
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

func _i18n_screen(screen: String) -> void:
	if get_tree().paused: get_tree().paused=false
	if is_instance_valid(ui):
		ui.hide()
		ui.queue_free()
		await get_tree().process_frame
	match screen:
		"lobby":
			ui=preload("res://tests/i18n_expanded/hero_host.gd").new()
			add_child(ui)
			if fixture_game.get_script()==preload("res://tests/lado_sombrio_claim/fake_game.gd"):
				ui.hero.set_pending_rewards(services.rewards.pending_count())
				services.rewards.changed.connect(ui.update_pending)
				ui.hero.news_requested.connect(func()->void: ui.add_child(NewsOverlay.new()))
			ui.hero.route_requested.connect(func(route: String)->void:
				if route in ["wallet","emotes"]: _i18n_screen("commerce_wallet" if route=="wallet" else "commerce_emotes"))
		"commerce_wallet":
			ui=load("res://scenes/player/wallet.tscn").instantiate()
			add_child(ui)
			ui.show_screen({"tab":"coins"})
		"commerce_emotes":
			ui=load("res://scenes/skins/skins_panel.tscn").instantiate()
			add_child(ui)
			ui._generating=true
			for entry: Dictionary in CharacterCatalog.load_entries():
				ui._paths[str(entry.id)]="res://assets/portraits/"+str(entry.id)+".png"
			ui.show_screen({"cosmetic_mode":"shop"})
		"originals", "originals_gallery":
			ui=load("res://scenes/player/deck_library.tscn").instantiate()
			add_child(ui)
			if screen=="originals": ui._render_deck(preload("res://scripts/decks/deck_library_catalog.gd").find_deck("lado_sombrio"))
			else:
				ui.show_screen()
				ui._query="Lado Sombrio"
				ui._update_results()
		"skins_locked", "skins_unlocked":
			services.progression.state="success"
			services.progression.data={"unlocked_character_ids":PlayerContracts.initial_ids(),"equipped_character_id":"cowboy"}
			if screen=="skins_unlocked": services.progression.data.unlocked_character_ids.append("el_fuego")
			ui=load("res://scenes/skins/skins_panel.tscn").instantiate()
			add_child(ui)
			ui._generating=true
			for entry: Dictionary in CharacterCatalog.load_entries(): ui._paths[str(entry.id)]="res://assets/portraits/"+str(entry.id)+".png"
			ui.open("el_fuego")
		"library", "official_cards":
			ui=load("res://scenes/player/deck_library.tscn").instantiate()
			add_child(ui)
			ui.show_screen()
			if screen=="official_cards": ui._render_deck(preload("res://scripts/decks/deck_library_catalog.gd").find_deck("lendas_urbanas"))
		"skins":
			ui=load("res://scenes/skins/skins_panel.tscn").instantiate()
			add_child(ui)
			ui._generating=true
			for entry: Dictionary in CharacterCatalog.load_entries():
				ui._paths[str(entry.id)]="res://assets/portraits/"+str(entry.id)+".png"
			ui.open("cowboy")
		"editor", "review":
			ui=load("res://scenes/player/deck_library.tscn").instantiate()
			add_child(ui)
			ui._create_deck()
			if screen=="review": ui._render_review()
		"friends":
			services.friends.state="success"
			services.friends.data={"friends":[],"incoming":[],"outgoing":[]}
			ui=load("res://scenes/player/friends.tscn").instantiate()
			add_child(ui)
			ui.show_screen({"tab":"search"})
			await ui._search("Configurações")
		"duel":
			await services.duel.use_local()
			if not services.duel.in_room(): await services.duel.create("Custom Room",false,{"deck_ids":["lendas_urbanas"]})
			ui=load("res://scenes/player/duel.tscn").instantiate()
			add_child(ui)
			ui.show_screen()
			await ui._open_form()
		"tutorial":
			ui=Control.new()
			ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(ui)
			var lesson: Node=load("res://scripts/desert/t15d/first_use_tutorial.gd").new()
			ui.add_child(lesson)
			lesson.call("present","amber")
	await get_tree().process_frame

func _probe(args: Array) -> void:
	if args.size() and str(args[0])=="claim_fail": fixture_game.fail_claim=true
	if args.size() and str(args[0])=="claim_success": fixture_game.fail_claim=false
	if args.size() and str(args[0])=="claim_refresh": await services.rewards.refresh()
	if args.size() and str(args[0])=="claim_other_account":
		fixture_game.user="00000000-0000-4000-8000-000000000092"
		services.session.user={"id":fixture_game.user}
		services.rewards.clear()
		await services.rewards.refresh()
	if args.size() and str(args[0]).begins_with("original_card:"):
		ui._render_card(str(args[0]).trim_prefix("original_card:").to_int())
	if args.size() and str(args[0]).begins_with("i18n_screen:"):
		await _i18n_screen(str(args[0]).trim_prefix("i18n_screen:"))
	if args.size() and str(args[0])=="start_refill_phase":
		ui.hide();ui.queue_free()
		ui=preload("res://tests/ability_refills/visual.gd").new()
		add_child(ui)
	if args.size() and str(args[0]).begins_with("universal_character:"):
		ui._select(str(args[0]).trim_prefix("universal_character:"))
		_fixture_universal_motion()
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
	var result := {"locale":services.preferences.values.locale,"language_choice":ui.get("_language_choice"),"sequence":report_sequence,"size":[ui.size.x,ui.size.y],"controls":[],"fields":{},"cards":0,"labels":[],"emote_thumbnails":[]}
	result.pending_rewards=services.rewards.pending_count()
	result.lado_access=preload("res://scripts/decks/deck_library_catalog.gd").can_access("lado_sombrio")
	result.local_lado=services.duel.local_server.decks().any(func(d:Dictionary)->bool:return str(d.id)=="lado_sombrio")
	var margin := ui.get_node_or_null("Margin") as Control
	if margin!=null: result.layout_width=margin.size.x * margin.scale.x
	if ui.get("_selected_styles") is Dictionary:
		result.variations={"character":ui._selected,"style":ui._selected_styles.get(ui._selected,"original"),"thumbnails":[]}
	if ui.has_method("_sync_resources") and ui.get("_player")!=null:
		result.refills={"defense":ui._player.defense_charges,"attack":ui._player.attack_charges,"dash":ui._player.charges("dash"),"count":services.ability_refills.count(),"paused":get_tree().paused,"calls":fixture_game.refill_calls.size()}
	if services.emote_shop!=null and services.emote_shop.state=="success":
		result.shop={"coins":services.emote_shop.data.get("coins",""),"owned":services.emote_shop.product("dance_01").get("owned",false)}
	if services.wallet.state=="success": result.wallet_coins=services.wallet.data.get("coins","")
	if fixture_game.get("purchase_calls") is Array: result.emote_purchases=fixture_game.purchase_calls.size()
	if fixture_game.get("checkout_calls") is Array: result.checkout_calls=fixture_game.checkout_calls.size()
	if ui.get("_stage") is LobbyStage and is_instance_valid(ui.get("_stage")):
		var stage: LobbyStage=ui.get("_stage")
		result.preview_render={"static":stage.static_preview,"update":stage.get_node("Viewport").render_target_update_mode}
		var player: AnimationPlayer=stage.character.get("_anim_player")
		if player!=null: result.emote={"animation":player.assigned_animation,"playing":player.is_playing(),"static":stage.character.is_static_pose}
	for node: Control in ui.find_children("*","Control",true,false):
		if not node.is_visible_in_tree(): continue
		if node is Label: result.labels.append(node.text if node.auto_translate_mode==Node.AUTO_TRANSLATE_MODE_DISABLED else str(node.tr(node.text)))
		if node is TextureRect and str(node.name).begins_with("EmoteThumbnail_"):
			result.emote_thumbnails.append({"name":str(node.name),"ready":node.texture!=null,"height":node.size.y})
		if node is TextureRect and str(node.name).begins_with("VariationThumbnail_"):
			result.variations.thumbnails.append({"name":str(node.name),"ready":node.texture!=null,"height":node.size.y})
		if node is LineEdit or node is TextEdit: result.fields[str(node.name)]=str(node.text)
		if node is BaseButton or node is LineEdit or node is TextEdit:
			var r := node.get_global_rect()
			result.controls.append({"name":str(node.name),"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"text":(node.text if node.auto_translate_mode==Node.AUTO_TRANSLATE_MODE_DISABLED else str(node.tr(node.text))) if node is Button else "","disabled":node.disabled if node is BaseButton else false})
	if ui.get("_draft") is Dictionary:
		result.cards=ui._draft.get("cards",[]).size()
		result.card_names=ui._draft.get("cards",[]).map(func(c:Dictionary)->String:return str(c.get("name","")))
		result.description=str(ui._draft.get("description",""))
		result.name=str(ui._draft.get("name",""))
		result.category=str(ui._draft.get("category",""))
		result.cover=ui._draft.get("cover",{})
	JavaScriptBridge.eval("window.qseDeckInputReport="+JSON.stringify(result))


func _fixture_universal_motion() -> void:
	# Existing base clip tests binding/entitlement ONLY. Not an approved dance asset.
	var entry := services.inventory.entry(ui._selected)
	preload("res://scripts/skins/universal_emotes.gd").install_from_catalog(ui._stage.character,"emote_dance_01",{
		"items":[{"scope":"account","animation_key":"emote_dance_01","clips":{str(entry.id):str(entry.animations.base)}}]})
