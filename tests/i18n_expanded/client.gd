extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func run() -> void:
	var prefs := DevicePreferences.new()
	root.add_child(prefs)
	var control := Control.new()
	root.add_child(control)
	PlayerUI.apply_theme(control)
	var label := PlayerUI.label("Idioma",24)
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
	control.add_child(label)
	var nickname := PlayerUI.label("Configurações",24)
	nickname.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	nickname.autowrap_mode=TextServer.AUTOWRAP_OFF
	control.add_child(nickname)
	var original_width := nickname.get_minimum_size().x
	var widths: Array[float]=[]
	var font := control.theme.default_font
	for item: Array in DevicePreferences.LANGUAGES:
		if item[1]=="pt_BR": continue
		TranslationServer.set_locale(item[1])
		for i in 4: await process_frame
		check(label.text=="Idioma","source survives language change: "+item[1])
		widths.append(label.get_minimum_size().x)
		check(nickname.text=="Configurações" and is_equal_approx(nickname.get_minimum_size().x,original_width),"nickname unchanged: "+item[1])
		var catalog := PlayerContracts.read_json("res://data/ui/"+item[1]+".json")
		for key: String in catalog:
			check(str(TranslationServer.translate(key))==str(catalog[key]),"catalog registered: "+item[1]+" "+key)
			for index in str(catalog[key]).length():
				var point := str(catalog[key]).unicode_at(index)
				if point>=0x3000 and point<=0x9fff: check(font.has_char(point),"missing glyph: "+str(point))
		check((str(TranslationServer.translate("Começa em %d")) % 5).contains("5"),"dynamic count preserved")
		var names_catalog = preload("res://scripts/decks/deck_library_catalog.gd")
		for id: String in names_catalog.OFFICIAL_IDS:
			var official: Dictionary = names_catalog.find_deck(id)
			check(not official.is_empty(),"official deck loads: "+id)
			var source: Dictionary = PlayerContracts.read_json(names_catalog.ROOT+"/"+id+"/deck.json")
			check(official.name==catalog[source.name],"localized official title: "+id)
			for card: Dictionary in official.cards:
				var original: String = source.cards[card.id.get_slice("/",1)].name
				check(card.name==catalog[original],"localized library card: "+card.id)
				check(DuelService.card_name(card.id)==card.name,"duel matches library: "+card.id)
		check(names_catalog.display_name("creator:abc","Pinturas")=="Pinturas","creator title unchanged even when matching official title")
		CommunityDecksService.cards["community:test/card"]={"name":"Cowboy"}
		check(DuelService.card_name("community:test/card")=="Cowboy","creator card name unchanged")
		for character: Dictionary in CharacterCatalog.load_entries():
			check(catalog.has(character.name),"character has localized display name: "+character.id)
			for variant: Dictionary in preload("res://scripts/skins/skin_variations.gd").entries(character.id):
				check(catalog.has(variant.name),"variant has localized name: "+character.id)
		check(not PlayerContracts.ago(Time.get_unix_time_from_system()-180000).begins_with("há "),"relative time translated")
	check(not is_equal_approx(widths[0],widths[3]),"existing Label redraws in a different script")
	TranslationServer.set_locale("pt_BR")
	var menu: Control=load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 8: await process_frame
	for item: Array in DevicePreferences.LANGUAGES:
		TranslationServer.set_locale(item[1])
		menu.get_node("LobbyComposition").call("_language")
		check(menu.get_node("MenuButtons").auto_translate_mode==Node.AUTO_TRANSLATE_MODE_INHERIT,"lobby allows every locale: "+item[1])
		check(menu.get_node("ProfileCard/Content/Info/Name").auto_translate_mode==Node.AUTO_TRANSLATE_MODE_DISABLED,"lobby preserves nickname: "+item[1])
	TranslationServer.set_locale("pt_BR")
	print("I18N_EXPANDED checks=",checks," failures=",failures)
	quit(1 if failures else 0)
