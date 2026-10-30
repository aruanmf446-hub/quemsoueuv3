extends RefCounted
## Battle-specific composition; shared font, colors and interactions come from PlayerUI.
const BLUE := Color("#253e52")
const EDGE := Color("#725d3c")
const FACE := Color("#0c141e")
static func panel(padding := 8, active := false) -> StyleBoxFlat:
	var style := PlayerUI.plate(active)
	style.bg_color = Color("#211c15") if active else FACE
	style.border_color = PlayerUI.GOLD if active else Color("#354350")
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(6)
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
			box.border_color = Color("#5f523d")
			box.set_border_width_all(1)
		button.add_theme_stylebox_override(state,box)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("h_separation", 5)
	if not icon.is_empty():
		button.icon = load("res://assets/ui/battle/%s.svg" % icon)
	return button
