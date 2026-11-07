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
