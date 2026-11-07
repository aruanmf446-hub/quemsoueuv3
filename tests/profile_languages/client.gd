extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var preferences := DevicePreferences.new()
	root.add_child(preferences)
	for item: Array in DevicePreferences.LANGUAGES:
		check(DevicePreferences._valid("locale", item[1]), "locale accepted: " + item[1])
		if item[1] == "pt_BR": continue
		TranslationServer.set_locale(item[1])
		check(TranslationServer.translate("Configurações") != "Configurações", "settings translated: " + item[1])
		check(TranslationServer.translate("Jogar") != "Jogar", "play translated: " + item[1])
		check(preferences.set_preference("locale", item[1]), "saved: " + item[1])
		var restored := DevicePreferences.new()
		root.add_child(restored)
		check(restored.values.locale == item[1], "restored: " + item[1])
		restored.queue_free()
	check(not DevicePreferences._valid("locale", "invalid"), "unknown locale rejected")
	preferences.set_preference("locale", "pt_BR")
	var control := Control.new()
	root.add_child(control)
	PlayerUI.apply_theme(control)
	var font := control.theme.default_font
	for text: String in ["日本語", "简体中文", "Русский"]:
		for point: int in text.to_utf32_buffer().size() / 4:
			check(font.has_char(text.unicode_at(point)), "glyph: " + text.substr(point, 1))
	print("PROFILE_LANGUAGES checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
