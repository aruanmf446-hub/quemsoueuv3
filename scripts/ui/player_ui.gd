class_name PlayerUI
extends RefCounted

const GOLD := Color("#f2cf7d")
const INK := Color("#12223b")
const TEXT := Color("#edf3ff")
const FRAME := preload("res://assets/processed/frames/frame_painel_brasao.png")
const BLUE := preload("res://assets/processed/textures/textura_azul.png")
const PURPLE := preload("res://assets/processed/textures/textura_roxa.png")


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = TranslationServer.translate(text)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = TranslationServer.translate(text)
	node.custom_minimum_size = Vector2(130, 52)
	node.focus_mode = Control.FOCUS_ALL
	node.add_theme_font_size_override("font_size", 21)
	style_button(node, false)
	node.pressed.connect(action)
	return node


## Botão inclinado do menu: vidro escuro com borda dourada; o principal é dourado.
static func style_button(node: Button, primary: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.skew = Vector2(0.16, 0)
		style.anti_aliasing = true
		style.set_corner_radius_all(3)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.bg_color = GOLD if primary else Color(0.06, 0.10, 0.17, 0.94)
		style.border_color = Color(GOLD, 0.0 if primary else 0.5)
		style.set_border_width_all(1)
		if state == "hover": style.bg_color = style.bg_color.lightened(0.1)
		if state in ["pressed", "hover_pressed"]: style.bg_color = GOLD.darkened(0.1)
		if state == "disabled": style.bg_color = Color(0.05, 0.07, 0.11, 0.75)
		if state == "focus":
			style.draw_center = false
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
		node.add_theme_stylebox_override(state, style)
	for color: String in ["font_color", "font_hover_color", "font_focus_color"]:
		node.add_theme_color_override(color, INK if primary else TEXT)
	for color: String in ["font_pressed_color", "font_hover_pressed_color"]:
		node.add_theme_color_override(color, INK)
	node.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.38))


static func column(parent: Node) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation", 14)
	parent.add_child(node)
	return node


static func row(parent: Node) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", 14)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node


static func card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.06, 0.11, 0.92)
	style.border_color = Color(GOLD, 0.6)
	style.border_width_top = 2
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	style.content_margin_left = 22
	style.content_margin_top = 18
	style.content_margin_right = 22
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return column(panel)


static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


static func portrait(character_id: String, side: int = 82) -> TextureRect:
	var node := TextureRect.new()
	node.custom_minimum_size = Vector2(side, side)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := ThumbnailCache.path_for(character_id)
	if FileAccess.file_exists(path):
		node.texture = ImageTexture.create_from_image(Image.load_from_file(path))
	else:
		node.texture = preload("res://assets/icons/vector/icon_friends.svg")
	return node
