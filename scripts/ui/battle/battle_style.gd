extends RefCounted
## Battle-specific composition; shared font, colors and interactions come from PlayerUI.
const BLUE := Color("#253e52")
const EDGE := Color("#725d3c")
const FACE := Color("#0c141e")
static var _bold: FontVariation
static func strong(label: Control) -> void:
	if _bold == null:
		var font := preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
		font.multichannel_signed_distance_field = true
		_bold = FontVariation.new()
		_bold.base_font = font
		_bold.variation_embolden = 0.45
	label.add_theme_font_override("font",_bold)
static func panel(padding := 8, active := false) -> StyleBoxFlat:
	var style := PlayerUI.plate(active)
	style.bg_color = Color("#252016") if active else Color("#101a27")
	style.border_color = PlayerUI.GOLD if active else Color("#435367")
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0,0,0,0.36)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0,2)
	style.set_content_margin_all(padding)
	if active:
		style.shadow_color = Color(0.95, 0.58, 0.17, 0.2)
		style.shadow_size = 6
	return style
static func label(text: String, font_size := 14, color := PlayerUI.TEXT) -> Label:
	var label := PlayerUI.label(text, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
static func action(text: String, callback: Callable, icon := "", primary := false) -> Button:
	var button := PlayerUI.button(text, callback)
	PlayerUI.style_button(button, primary)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var box := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		if state == "normal" and not primary:
			box.bg_color = Color("#111b28")
			box.border_color = Color("#817050")
			box.shadow_color = Color(0,0,0,0.4)
			box.shadow_size = 2
			box.shadow_offset = Vector2(0,1)
			box.set_border_width_all(1)
		button.add_theme_stylebox_override(state,box)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_constant_override("h_separation", 5)
	if not icon.is_empty():
		button.icon = load("res://assets/ui/battle/%s.svg" % icon)
	return button
