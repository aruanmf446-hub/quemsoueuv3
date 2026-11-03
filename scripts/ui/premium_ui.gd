class_name PremiumUI
extends RefCounted
## Sistema visual das telas internas redesenhadas (Configurações T22, Amizades T22):
## azul-marinho, painéis grafite azulado, dourado para seleção e ação principal.

const GOLD := PlayerUI.GOLD
const GOLD_LIGHT := Color("#f4cf7a")
const MUTED := Color("#a8bad3")
const PANEL := Color(0.055, 0.08, 0.125, 0.94)
const ROW := Color(0.035, 0.05, 0.085, 0.92)
const EDGE := Color(0.42, 0.52, 0.68, 0.28)
const INK := Color("#141006")
const ONLINE := Color("#4cd964")
const OFFLINE := Color("#8a94a6")
const ICONS := {
	"eye": '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
	"eye_off": '<path d="M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c6.4 0 10 7 10 7a17 17 0 0 1-3.2 4.1M6.6 6.6A17 17 0 0 0 2 12s3.6 7 10 7a9.6 9.6 0 0 0 5.4-1.6M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
	"chevron_down": '<path d="M6 9l6 6 6-6"/>',
	"star_outline": '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
	"swords": '<path d="M4 4l9.5 9.5M4 4h4l9 9M4 4v4l9 9" fill="currentColor" fill-opacity="0.25"/><path d="M20 4l-9.5 9.5M20 4h-4l-3.2 3.2M20 4v4l-3.2 3.2"/><path d="M13.5 13.5l4 4M10.5 13.5l-4 4M16 19l3-3M8 19l-3-3M18.5 20.5l2-2M5.5 20.5l-2-2"/>',
	"plus": '<path d="M12 5v14M5 12h14"/>',
	"play": '<path d="M8 5.5v13l10.5-6.5z" fill="currentColor"/>',
	"layers": '<path d="M12 3 2 8l10 5 10-5z"/><path d="M2 13l10 5 10-5"/>',
	"tag": '<path d="M3 12V4a1 1 0 0 1 1-1h8l9 9-9 9z"/><circle cx="8" cy="8" r="1.4"/>',
	"cards": '<rect x="3" y="6" width="12" height="15" rx="2"/><path d="M8 3h11a2 2 0 0 1 2 2v13"/>',
	"filter": '<path d="M3 5h18l-7 8v6l-4 2v-8z"/>',
	"pencil": '<path d="M4 20l1-5L16 4l4 4L9 19z"/><path d="M14 6l4 4"/>',
	"back": '<path d="M15 6l-6 6 6 6"/>',
	"crown": '<path d="M3 18h18l-1.5-10-4.5 4-3-6-3 6-4.5-4z"/><path d="M4 21h16"/>',
	"friends": '<circle cx="8" cy="8" r="3"/><circle cx="17" cy="9" r="2.6"/><path d="M2 20v-1a6 6 0 0 1 12 0v1M14 14.5a5 5 0 0 1 8 4.5v1"/>',
	"inbox": '<path d="M12 3v11M7 10l5 5 5-5"/><path d="M4 15v4a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-4"/>',
	"outbox": '<path d="M12 15V4M7 9l5-5 5 5"/><path d="M4 13v6a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-6"/>',
	"search": '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
	"copy": '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3"/>',
	"star": '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z" fill="currentColor"/>',
	"gamepad": '<path d="M7 8h10a4 4 0 0 1 4 4v2a3 3 0 0 1-5.4 1.8L14 14h-4l-1.6 1.8A3 3 0 0 1 3 14v-2a4 4 0 0 1 4-4z"/><path d="M7 11v3M5.5 12.5h3"/><circle cx="16" cy="11.5" r="0.6"/><circle cx="18" cy="13.5" r="0.6"/>',
	"chat": '<path d="M4 12a8 7 0 1 1 3.5 5.8L4 19.5l1.2-3.6A6.6 6.6 0 0 1 4 12z"/><path d="M9 12h.01M12 12h.01M15 12h.01"/>',
	"user_minus": '<circle cx="9" cy="8" r="4"/><path d="M2 21v-1a7 7 0 0 1 14 0v1M17 11h5"/>',
	"user_plus": '<circle cx="9" cy="8" r="4"/><path d="M2 21v-1a7 7 0 0 1 14 0v1M19.5 8.5v5M17 11h5"/>',
	"user": '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a8 8 0 0 1 16 0v1"/>',
	"x": '<path d="M6 6l12 12M18 6 6 18"/>',
	"skull": '<path d="M12 3a8 8 0 0 0-8 8c0 2.7 1.3 4.6 3 5.8V20a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1v-3.2c1.7-1.2 3-3.1 3-5.8a8 8 0 0 0-8-8z" fill="currentColor" fill-opacity="0.18"/><circle cx="9" cy="11.5" r="1.8" fill="currentColor"/><circle cx="15" cy="11.5" r="1.8" fill="currentColor"/><path d="M12 14.5l-1 2h2zM10 21v-2.5M14 21v-2.5"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
	"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
	"bolt": '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
	"mail": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
	"info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
	"send": '<path d="M21 3 3 10.5l7 2.5 2.5 7z"/><path d="M21 3 10 13"/>',
	"refresh": '<path d="M20 12a8 8 0 0 1-14 5.3M4 12a8 8 0 0 1 14-5.3"/><path d="M18 3v4h-4M6 21v-4h4"/>',
	"chevron": '<path d="M9 5l7 7-7 7"/>',
	"dots": '<circle cx="5" cy="12" r="1.2" fill="currentColor"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><circle cx="19" cy="12" r="1.2" fill="currentColor"/>',
	"stats": '<path d="M4 20V10M10 20V4M16 20v-8M22 20H2"/>',
	"hourglass": '<path d="M6 3h12M6 21h12M7 3c0 5 10 5 10 9s-10 4-10 9M17 3c0 5-10 5-10 9s10 4 10 9"/>',
}
static var _cache := {}


static func icon(name: String, color: Color, pixels: int = 48) -> Texture2D:
	var key := "%s|%s|%d" % [name, color.to_html(), pixels]
	if _cache.has(key): return _cache[key]
	var hex := "#" + color.to_html(false)
	var body := str(ICONS.get(name, "")).replace("currentColor", hex)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24"><g fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [pixels, pixels, hex, body]
	var image := Image.new()
	image.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func icon_rect(name: String, color: Color, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(name, color, maxi(side * 2, 48))
	rect.custom_minimum_size = Vector2.ONE * side
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func flat(color: Color, border: Color, radius: int, width: int, margin := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	box.anti_aliasing = true
	return box


static func panel(node_name: String, margin := 18) -> PanelContainer:
	var node := PanelContainer.new()
	node.name = node_name
	var box := flat(PANEL, EDGE, 18, 1, margin)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 6)
	node.add_theme_stylebox_override("panel", box)
	return node


static func row_box(compact := false) -> StyleBoxFlat:
	var box := flat(ROW, Color(1, 1, 1, 0.06), 12, 1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8 if compact else 12
	box.content_margin_bottom = 8 if compact else 12
	return box


## Rótulo de uma linha, do tamanho do texto.
static func plain(text: String, size: int, color: Color, translate := true) -> Label:
	var label := PlayerUI.label(text, size, color)
	if not translate:
		label.text = text
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


## Aba/linha selecionável: grafite; selecionada em dourado com contorno iluminado.
static func style_tab(node: Button) -> void:
	var normal := flat(Color(0.06, 0.085, 0.13), EDGE, 12, 1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(GOLD, 0.55)
	var selected := flat(Color("#7f5f26"), GOLD_LIGHT, 12, 2)
	selected.shadow_color = Color(GOLD, 0.35)
	selected.shadow_size = 10
	var focus := flat(Color.TRANSPARENT, GOLD_LIGHT, 12, 2)
	focus.draw_center = false
	for state in ["normal", "disabled"]: node.add_theme_stylebox_override(state, normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", selected)
	node.add_theme_stylebox_override("hover_pressed", selected)
	node.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]: node.add_theme_color_override(state, Color("#eef2f7"))
	for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]: node.add_theme_color_override(state, Color.WHITE)


static func style_gold(node: Button) -> void:
	var box := flat(Color("#c3923a"), GOLD_LIGHT, 12, 2)
	box.shadow_color = Color(GOLD, 0.3)
	box.shadow_size = 8
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#d4a347")
	var focus := flat(Color.TRANSPARENT, Color.WHITE, 12, 2)
	focus.draw_center = false
	node.add_theme_stylebox_override("normal", box)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_stylebox_override("disabled", flat(Color(0.25, 0.22, 0.16), Color.TRANSPARENT, 12, 0))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: node.add_theme_color_override(state, INK)
	node.add_theme_color_override("font_disabled_color", Color(MUTED, 0.7))


static func style_outline(node: Button) -> void:
	var box := flat(Color(0.05, 0.07, 0.11), Color(GOLD, 0.85), 12, 2)
	var hover := box.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.1, 0.1, 0.1)
	var focus := flat(Color.TRANSPARENT, GOLD_LIGHT, 12, 2)
	focus.draw_center = false
	var disabled := flat(Color(0.05, 0.07, 0.11), Color(MUTED, 0.25), 12, 1)
	node.add_theme_stylebox_override("normal", box)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_stylebox_override("disabled", disabled)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: node.add_theme_color_override(state, Color("#f1e6d0"))
	node.add_theme_color_override("font_disabled_color", Color(MUTED, 0.6))


static func action(text: String, icon_name: String, primary: bool, callback: Callable, compact := false) -> Button:
	var button := Button.new()
	button.text = TranslationServer.translate(text)
	button.icon = icon(icon_name, INK if primary else GOLD, 36)
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_constant_override("h_separation", 10)
	button.custom_minimum_size = Vector2(0, PlayerUI.CONTROL_HEIGHT)
	button.add_theme_font_size_override("font_size", PlayerUI.CONTROL_FONT)
	button.focus_mode = Control.FOCUS_ALL
	if primary: style_gold(button)
	else: style_outline(button)
	button.pressed.connect(callback)
	return button


## Retrato circular com aro dourado (recorte pelo próprio painel).
static func avatar(texture: Texture2D, side: int, ring := 3) -> Control:
	var holder := PanelContainer.new()
	holder.name = "Avatar"
	holder.custom_minimum_size = Vector2(side, side)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := flat(Color(0.14, 0.1, 0.06), Color.TRANSPARENT, side, 0, 0)
	holder.add_theme_stylebox_override("panel", mask)
	holder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := flat(Color.TRANSPARENT, GOLD_LIGHT, side, ring, 0)
	border.draw_center = false
	frame.add_theme_stylebox_override("panel", border)
	holder.add_child(frame)
	return holder


## Ponto de presença colorido + texto.
static func presence(text: String, online: bool, size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var dot := Panel.new()
	var side := maxf(7.0, size * 0.6)
	dot.custom_minimum_size = Vector2.ONE * side
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", flat(ONLINE if online else OFFLINE, Color.TRANSPARENT, int(side), 0, 0))
	row.add_child(dot)
	row.add_child(plain(text, size, ONLINE if online else MUTED))
	return row


static func backdrop() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "PremiumBackdrop"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec3 base = vec3(0.024, 0.043, 0.078);
	base += vec3(0.02, 0.04, 0.07) * (1.0 - UV.y) * (1.0 - UV.x * 0.6);
	COLOR = vec4(base, 1.0);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	return rect


## Botão "olho" dentro de um campo de senha: mostra/oculta o que está sendo digitado.
static func reveal_toggle(field: LineEdit) -> Button:
	var eye := Button.new()
	eye.name = "RevealPassword"
	eye.flat = true
	eye.toggle_mode = true
	eye.focus_mode = Control.FOCUS_NONE
	eye.custom_minimum_size = Vector2(44, 0)
	eye.icon = icon("eye", MUTED, 40)
	eye.add_theme_constant_override("icon_max_width", 22)
	eye.tooltip_text = TranslationServer.translate("Mostrar senha")
	eye.toggled.connect(func(visible_text: bool) -> void:
		field.secret = not visible_text
		eye.icon = icon("eye_off" if visible_text else "eye", GOLD if visible_text else MUTED, 40)
		eye.tooltip_text = TranslationServer.translate("Ocultar senha" if visible_text else "Mostrar senha"))
	field.add_child(eye)
	eye.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	eye.offset_left = -48
	# O texto não passa por baixo do olho.
	for state in ["normal", "focus", "read_only"]:
		var box := field.get_theme_stylebox(state)
		if box != null:
			box = box.duplicate()
			box.content_margin_right = maxf(box.content_margin_right, 50)
			field.add_theme_stylebox_override(state, box)
	return eye
