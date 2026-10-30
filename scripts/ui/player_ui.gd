class_name PlayerUI
extends RefCounted

const GOLD := Color("#f2cf7d")
const INK := Color("#12223b")
const TEXT := Color("#edf3ff")
## Aparência aprovada dos menus: superfícies escuras e discretas, filete fino e dourado só
## no principal/selecionado. Não usar molduras ou placas de imagem (assets/ui/kit,
## assets/processed/frames) nos menus: esse visual foi reprovado. Ver AGENTS.md.
const PANEL_BG := Color(0.07, 0.11, 0.19, 0.92)
const PANEL_BORDER := Color("#2c3a52")
const FIELD_BG := Color("#16233a")
## Texto sobre superfícies douradas (principal/selecionado).
const KIT_INK := INK
## Cores das coleções (antes texturas do kit).
const SWATCHES := {
	"azul": Color("#2f6fd6"),
	"dourada": Color("#d8a531"),
	"roxa": Color("#7a4fd0"),
	"verde": Color("#3f9b5a"),
	"vermelha": Color("#c9473e"),
}


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


## Botão discreto: superfície escura com filete; o principal e o selecionado são dourados.
static func style_button(node: Button, primary: bool) -> void:
	var states := {
		"normal": button_plate(primary),
		"hover": button_plate(primary, Color(1.16, 1.16, 1.2)),
		"pressed": button_plate(true, Color(0.92, 0.92, 0.92)),
		"hover_pressed": button_plate(true, Color(1.08, 1.08, 1.08)),
		"disabled": button_plate(false, Color(0.5, 0.52, 0.58, 0.85)),
	}
	for state: String in states:
		node.add_theme_stylebox_override(state, states[state])
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(GOLD, 0.9)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	focus.set_expand_margin_all(2)
	node.add_theme_stylebox_override("focus", focus)
	for color: String in ["font_color", "font_hover_color", "font_focus_color"]:
		node.add_theme_color_override(color, KIT_INK if primary else TEXT)
	for color: String in ["font_pressed_color", "font_hover_pressed_color"]:
		node.add_theme_color_override(color, KIT_INK)
	node.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.38))
	fluid(node)


## Movimento dos botões: crescem um pouco sob o mouse e afundam ao pressionar.
## O crescimento é limitado em pixels, para botões largos não "incharem".
static func fluid(node: BaseButton) -> void:
	if node.has_meta("fluid"): return
	node.set_meta("fluid", true)
	_center_pivot(node)
	# No toque não existe "passar o mouse": só o afundar do clique.
	var hover := not DisplayServer.is_touchscreen_available()
	var state := {"hover": false}
	var settle := func() -> void:
		var grow := 1.0 + minf(0.04, 8.0 / maxf(node.size.x, 1.0)) if state.hover and not node.disabled else 1.0
		_scale_to(node, grow, 0.16)
	if hover:
		node.mouse_entered.connect(func() -> void:
			state.hover = true
			settle.call())
		node.mouse_exited.connect(func() -> void:
			state.hover = false
			settle.call())
	node.button_down.connect(func() -> void: _scale_to(node, 1.0 - minf(0.04, 10.0 / maxf(node.size.x, 1.0)), 0.07))
	node.button_up.connect(settle)


## Entrada suave de um item: surge da transparência crescendo de 97% a 100%.
static func reveal(node: Control, delay := 0.0, time := 0.24) -> void:
	if not node.is_inside_tree(): return
	_center_pivot(node)
	var rest := node.scale
	node.modulate.a = 0.0
	node.scale = rest * 0.97
	var tween := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, time).set_delay(delay)
	tween.tween_property(node, "scale", rest, time).set_delay(delay)


## Entrada em cascata dos filhos visíveis de um container (a partir do índice from).
static func cascade(container: Node, from := 0, step := 0.035) -> void:
	var index := 0
	for child in container.get_children():
		if child.get_index() < from or not child is Control or not (child as Control).visible: continue
		reveal(child, minf(index * step, 0.3))
		index += 1


static func _center_pivot(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	if node.has_meta("pivot_centered"): return
	node.set_meta("pivot_centered", true)
	node.resized.connect(func() -> void: node.pivot_offset = node.size * 0.5)


static func _scale_to(node: Control, value: float, time: float) -> void:
	if not node.is_inside_tree(): return
	var old: Variant = node.get_meta("fluid_tween") if node.has_meta("fluid_tween") else null
	if old is Tween and (old as Tween).is_valid(): (old as Tween).kill()
	var tween := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * value, time)
	node.set_meta("fluid_tween", tween)


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


## Linha/cartão de lista.
static func card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := plate()
	style.content_margin_left = 22
	style.content_margin_top = 18
	style.content_margin_right = 22
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return column(panel)


## Painel grande (superfície escura com filete fino).
static func panel(parent: Node, padding := 34) -> VBoxContainer:
	var node := PanelContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_stylebox_override("panel", frame_panel(padding))
	parent.add_child(node)
	return column(node)


static func _flat(bg: Color, border: Color, radius: int, tint: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg * tint
	box.border_color = border * tint
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## Cartão/linha. `gold`: destaque (o próprio jogador, o selecionado). tint clareia/escurece.
static func plate(gold := false, tint := Color.WHITE) -> StyleBoxFlat:
	var box := _flat(Color("#1f2c43") if gold else Color(0.06, 0.10, 0.17, 0.94), Color(GOLD, 0.85) if gold else PANEL_BORDER, 10, tint)
	if gold: box.set_border_width_all(2)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


## Botões, abas e campos: escuros com filete; dourado sólido no principal/selecionado.
static func button_plate(gold := false, tint := Color.WHITE) -> StyleBoxFlat:
	var box := _flat(GOLD if gold else FIELD_BG, Color(GOLD, 0.0) if gold else Color("#3a4a64"), 8, tint)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## Painel de seção. `small` (celular): cantos menores.
static func frame_panel(padding := 34, small := false) -> StyleBoxFlat:
	var box := _flat(PANEL_BG, PANEL_BORDER, 8 if small else 12, Color.WHITE)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box


static func swatch(color_name: String) -> Color:
	return SWATCHES.get(color_name, SWATCHES.azul)


static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


## Retrato (busto) do personagem, do cache: não relê a miniatura grande a cada desenho.
static func portrait(character_id: String, side: int = 82) -> TextureRect:
	var node := TextureRect.new()
	node.custom_minimum_size = Vector2(side, side)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := bust(ThumbnailCache.path_for(character_id))
	node.texture = texture if texture != null else preload("res://assets/icons/vector/icon_friends.svg")
	return node


## Bustos recortados das miniaturas (2048 px), guardados em memória e numa versão pequena
## ao lado delas ("_card.png"): abrir telas, buscar ou filtrar não relê nem recorta os PNGs
## grandes de novo (antes isso travava as telas por 1–2 s).
static var _busts := {}
const BUST_HEIGHT := 360


static func bust(path: String) -> Texture2D:
	if not FileAccess.file_exists(path): return null
	var stamp := FileAccess.get_modified_time(path)
	var key := "%s@%d" % [path, stamp]
	if _busts.has(key): return _busts[key]
	var small := path.get_basename() + "_card.png"
	var image: Image
	if FileAccess.file_exists(small) and FileAccess.get_modified_time(small) >= stamp:
		image = Image.load_from_file(small)
	else:
		image = _crop_bust(path)
		if image != null: image.save_png(small)
	if image == null or image.is_empty(): return null
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_busts[key] = texture
	return texture


## Recorte por pixels opacos: chapéus, cabelos e alturas diferentes têm a mesma escala
## visual sem ajustes arbitrários por personagem.
static func _crop_bust(path: String) -> Image:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	var bounds := image.get_used_rect()
	if bounds.size.x == 0 or bounds.size.y == 0:
		return image
	var crop_height := mini(image.get_height() - bounds.position.y, int(bounds.size.y * 0.48))
	var crop_width := mini(image.get_width(), int(crop_height * 1.05))
	var crop_x := clampi(int(bounds.get_center().x - crop_width * 0.5), 0, image.get_width() - crop_width)
	var cropped := image.get_region(Rect2i(crop_x, bounds.position.y, crop_width, crop_height))
	if cropped.get_height() > BUST_HEIGHT:
		cropped.resize(roundi(cropped.get_width() * BUST_HEIGHT / float(cropped.get_height())), BUST_HEIGHT, Image.INTERPOLATE_LANCZOS)
	return cropped
