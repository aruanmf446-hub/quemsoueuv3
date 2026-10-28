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
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", 2)
	node.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = PURPLE if state == "disabled" else BLUE
		style.texture_margin_left = 16
		style.texture_margin_top = 12
		style.texture_margin_right = 16
		style.texture_margin_bottom = 12
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.modulate_color = Color(1.2, 1.2, 1.2) if state == "focus" else Color.WHITE
		node.add_theme_stylebox_override(state, style)
	node.pressed.connect(action)
	return node


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
	style.bg_color = Color("#172b49")
	style.border_color = GOLD.darkened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
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
