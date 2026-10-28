class_name DevicePreferences
extends Node

signal changed
const SAVE_PATH := "user://device_preferences_v1.cfg"
const DEFAULTS := {"master": 1.0, "music": 1.0, "sfx": 1.0, "quality": "medio", "locale": "pt_BR", "accept_key": KEY_ENTER, "back_key": KEY_ESCAPE}
var values: Dictionary = DEFAULTS.duplicate()
var last_error := OK


func _ready() -> void:
	values.quality = GraphicsProfile.default_for_platform()
	var translations := PlayerContracts.read_json("res://data/ui/en.json")
	var english := Translation.new()
	english.locale = "en"
	for message: String in translations:
		english.add_message(message, translations[message])
	TranslationServer.add_translation(english)
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for key: String in DEFAULTS:
			var value: Variant = config.get_value("device", key, DEFAULTS[key])
			if _valid(key, value):
				values[key] = value
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
	values[key] = value
	var config := ConfigFile.new()
	for item: String in values:
		config.set_value("device", item, values[item])
	last_error = config.save(SAVE_PATH)
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
		var key := {"Master": "master", "Music": "music", "SFX": "sfx"}[bus_name]
		var gain := float(values[key])
		AudioServer.set_bus_mute(index, gain <= 0.001)
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


static func _valid(key: String, value: Variant) -> bool:
	match key:
		"master", "music", "sfx": return (value is float or value is int) and is_finite(value) and value >= 0 and value <= 1
		"accept_key", "back_key": return value is int and value > 0 and value <= 0x7fffffff
		"quality": return value in ["baixo", "medio", "alto"]
		"locale": return value in ["pt_BR", "en"]
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
