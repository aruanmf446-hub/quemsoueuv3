class_name DevicePreferences
extends Node

signal changed
const SAVE_PATH := "user://device_preferences_v1.cfg"
const DEFAULTS := {"muted": false, "master": 1.0, "music": 1.0, "sfx": 1.0, "quality": "medio", "locale": "pt_BR", "accept_key": KEY_ENTER, "back_key": KEY_ESCAPE,
	"menu_music": true, "shadows": true, "window": "", "control_mode": "auto"}
## Tamanhos de janela oferecidos no desktop ("" = o do sistema; "fullscreen" = tela cheia).
const WINDOW_SIZES := ["", "1280x720", "1600x900", "1920x1080", "fullscreen"]
const LANGUAGES := [["Português (Brasil)", "pt_BR"], ["English", "en"], ["Español", "es"], ["Français", "fr"], ["日本語", "ja"], ["简体中文", "zh_CN"], ["Русский", "ru"]]
var values: Dictionary = DEFAULTS.duplicate()
var last_error := OK


func _ready() -> void:
	values.quality = GraphicsProfile.default_for_platform()
	for language: Array in LANGUAGES:
		if language[1] == "pt_BR": continue
		var translations := PlayerContracts.read_json("res://data/ui/" + language[1] + ".json")
		var translation := Translation.new()
		translation.locale = language[1]
		for message: String in translations:
			translation.add_message(message, translations[message])
		TranslationServer.add_translation(translation)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for key: String in DEFAULTS:
			var value: Variant = config.get_value("device", key, DEFAULTS[key])
			if _valid(key, value):
				values[key] = value
	values.control_mode=preload("res://scripts/desert/t15d/control_scheme.gd").saved_mode(values.control_mode)
	if values.accept_key == values.back_key:
		values.accept_key = KEY_ENTER
		values.back_key = KEY_ESCAPE
	apply()


func set_preference(key: String, value: Variant) -> bool:
	if not _valid(key, value):
		return false
	if key in ["accept_key", "back_key"]:
		var other := "back_key" if key == "accept_key" else "accept_key"
		if value == values[other]:
			return false
	var previous: Variant = values[key]
	values[key] = value
	var config := ConfigFile.new()
	for item: String in values:
		config.set_value("device", item, values[item])
	last_error = config.save(SAVE_PATH)
	if key=="control_mode" and OS.has_feature("web"):
		var stored: Variant=JavaScriptBridge.eval("(()=>{try{localStorage.setItem('qse-control-mode-v1',"+JSON.stringify(str(value))+");return true;}catch(e){return false;}})()")
		if UIScale.js_true(stored):last_error=OK
	if last_error != OK:
		values[key] = previous
		return false
	apply()
	changed.emit()
	return last_error == OK


func apply() -> void:
	for bus_name: String in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
		var key: String = {"Master": "master", "Music": "music", "SFX": "sfx"}[bus_name]
		var gain := float(values[key])
		AudioServer.set_bus_mute(index, gain <= 0.001 or (bus_name == "Master" and bool(values.muted)))
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, 0.0001)))
	TranslationServer.set_locale(values.locale)
	for binding: Array in [["ui_accept", "accept_key"], ["ui_cancel", "back_key"]]:
		for event: InputEvent in InputMap.action_get_events(binding[0]):
			if event is InputEventKey:
				InputMap.action_erase_event(binding[0], event)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(values[binding[1]])
		InputMap.action_add_event(binding[0], key_event)
	get_tree().call_group("player_preview_stages", "apply_profile", values.quality)
	preload("res://scripts/desert/t15d/control_scheme.gd").apply(str(values.control_mode),get_tree())
	_apply_window()


## Janela só existe no desktop; no navegador e no Android quem manda é o aparelho.
static func window_supported() -> bool:
	return not OS.has_feature("web") and not OS.has_feature("android") and not OS.has_feature("ios") and DisplayServer.get_name() != "headless"


func _apply_window() -> void:
	if not window_supported() or str(values.window).is_empty(): return
	if values.window == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var parts := str(values.window).split("x")
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))


static func _valid(key: String, value: Variant) -> bool:
	match key:
		"control_mode": return value in ["auto","touch","keyboard","mixed"]
		"muted": return value is bool
		"master", "music", "sfx": return (value is float or value is int) and is_finite(value) and value >= 0 and value <= 1
		"accept_key", "back_key": return value is int and value > 0 and value <= 0x7fffffff
		"quality": return value in ["baixo", "medio", "alto"]
		"locale": return LANGUAGES.any(func(item: Array) -> bool: return value == item[1])
		"menu_music", "shadows": return value is bool
		"window": return value in WINDOW_SIZES
	return false


static func number(value: Variant, locale: String = "pt_BR") -> String:
	if value == null:
		return "—"
	var text := str(value)
	var fraction := ""
	if value is float:
		if not is_finite(value):
			return "—"
		var parts := String.num(value, 2).split(".")
		text = parts[0]
		fraction = parts[1] if parts.size() > 1 else ""
	var sign_text := ""
	if text.begins_with("-"):
		sign_text = "−"
		text = text.substr(1)
	if not text.is_valid_int():
		return "—"
	var separator := "." if locale.begins_with("pt") else ","
	var groups: Array[String] = []
	while text.length() > 3:
		groups.push_front(text.right(3))
		text = text.left(text.length() - 3)
	groups.push_front(text)
	var decimal_separator := "," if locale.begins_with("pt") else "."
	return sign_text + separator.join(PackedStringArray(groups)) + (decimal_separator + fraction if not fraction.is_empty() else "")
