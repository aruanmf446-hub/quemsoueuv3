class_name PlayerUI
extends RefCounted

## Shared clean menu direction approved by the user; see docs/referencias/README.md.
## Clear hierarchy, quiet surfaces and a restrained accent for actions and selection.
const INTERIOR_BG := Color("#111820")
const GOLD := Color("#e9b975")
const GOLD_BRIGHT := Color("#f2cd94")
## Títulos de seção ("Coleções", "Personagens") e valores em destaque.
const TITLE_GOLD := Color("#f6f3e9")
## Texto sobre o dourado (ação principal).
const INK := Color("#151e25")
const TEXT := Color("#f6f3e9")
const MUTED := Color("#a9b1bb")
## Painel grande (galeria, coleções, conteúdo de configurações).
const PANEL_BG := Color(0.035, 0.05, 0.065, 0.82)
const PANEL_BORDER := Color("#28323c")
## Campos, cartões e botões secundários.
const SURFACE := Color(0.09, 0.115, 0.14, 0.78)
const SURFACE_HOVER := Color(0.14, 0.165, 0.19, 0.9)
const FIELD_BG := SURFACE
const FIELD_BORDER := Color("#3a444d")
## Item selecionado (aba, coleção, filtro ativo): fundo âmbar escuro com filete dourado.
const SELECTED_BG := Color(0.24, 0.19, 0.12, 0.8)
## Compatibilidade com telas antigas.
## Cores das coleções.
const SWATCHES := {
	"azul": Color("#2f6fd6"),
	"dourada": Color("#d8a531"),
	"roxa": Color("#7a4fd0"),
	"verde": Color("#3f9b5a"),
	"vermelha": Color("#c9473e"),
}


static var _menu_theme: Theme

## All menu entry points, including standalone campaign overlays, share font sampling.
static func apply_theme(root: Control) -> void:
	if _menu_theme == null:
		_menu_theme = Theme.new()
		var font := preload("res://assets/desert/phase01/interface.ttf").duplicate() as FontFile
		font.multichannel_signed_distance_field = true
		_menu_theme.default_font = font
		_menu_theme.default_font_size = 20
		var popup_surface := _flat(Color(0.035, 0.05, 0.065, 0.98), FIELD_BORDER, 4, Color.WHITE)
		_pad(popup_surface, 10, 8)
		_menu_theme.set_stylebox("panel", "PopupMenu", popup_surface)
		_menu_theme.set_stylebox("hover", "PopupMenu", selected_plate())
		_menu_theme.set_color("font_color", "PopupMenu", TEXT)
		for kind in ["LineEdit", "TextEdit"]:
			_menu_theme.set_stylebox("normal", kind, button_plate())
			_menu_theme.set_stylebox("focus", kind, selected_plate())
			_menu_theme.set_color("font_color", kind, TEXT)
			_menu_theme.set_color("font_placeholder_color", kind, MUTED)
		var separator := StyleBoxLine.new()
		separator.color = Color(1, 1, 1, 0.1)
		separator.thickness = 1
		_menu_theme.set_stylebox("separator", "HSeparator", separator)
	root.theme = _menu_theme
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func unit(root: Control) -> float:
	return root.get_viewport_rect().size.y / maxf(float(root.get_window().size.y) / UIScale.device_scale(), 1.0)


## Editorial columns collapse on narrow displays instead of squeezing content off-screen.
static func split(parent: Control, collapse_width := 740.0) -> BoxContainer:
	var box: BoxContainer = VBoxContainer.new() if parent.get_viewport_rect().size.x / unit(parent) < collapse_width else HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 24)
	parent.add_child(box)
	return box


static func flow(parent: Control) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("h_separation", 10)
	box.add_theme_constant_override("v_separation", 10)
	parent.add_child(box)
	return box


static func style_back(button: Button) -> void:
	style_row(button)
	button.add_theme_color_override("font_color", MUTED)


static func style_backdrop(tint: ColorRect) -> void:
	tint.material = null
	tint.color = INTERIOR_BG


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


## Botão do modelo. Principal: dourado com texto escuro. Secundário: superfície escura com
## filete frio. Selecionado (toggle pressionado: abas, coleções, filtros): âmbar escuro + filete dourado.
static func style_button(node: Button, primary: bool) -> void:
	var states := {
		"normal": button_plate(primary),
		"hover": button_plate(primary, Color(1.12, 1.12, 1.15)),
		"pressed": selected_plate(primary),
		"hover_pressed": selected_plate(primary, Color(1.08, 1.08, 1.08)),
		"disabled": _flat(Color(0.07, 0.09, 0.13, 0.85), Color("#232c3a"), 8, Color.WHITE),
	}
	for state: String in states:
		var box: StyleBoxFlat = states[state]
		if state == "disabled": _pad(box, 20, 6)
		node.add_theme_stylebox_override(state, box)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(GOLD_BRIGHT, 0.9)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	focus.set_expand_margin_all(2)
	node.add_theme_stylebox_override("focus", focus)
	for color: String in ["font_color", "font_hover_color", "font_focus_color"]:
		node.add_theme_color_override(color, INK if primary else TEXT)
	for color: String in ["font_pressed_color", "font_hover_pressed_color"]:
		node.add_theme_color_override(color, INK if primary else TEXT)
	node.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	fluid(node)


## Linha de lista selecionável (coleções, categorias): transparente até passar o mouse;
## selecionada fica âmbar escuro com filete dourado, como na referência.
static func style_row(node: Button) -> void:
	style_button(node, false)
	var normal := _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, Color.WHITE)
	_pad(normal, 16, 6)
	node.add_theme_stylebox_override("normal", normal)
	var hover := _flat(SURFACE_HOVER, Color(0, 0, 0, 0), 8, Color.WHITE)
	_pad(hover, 16, 6)
	node.add_theme_stylebox_override("hover", hover)


## Selo de estado em largura total na base do cartão (EQUIPADO / DISPONÍVEL / BLOQUEADO).
static func pill(text: String, kind: String) -> PanelContainer:
	var node := PanelContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	_pad(box, 10, 3)
	var ink := MUTED
	match kind:
		"equipped":
			box.bg_color = Color("#5a4429")
			box.border_color = Color("#7a5d36")
			ink = Color("#f6e7c6")
		"locked":
			box.bg_color = Color(0.06, 0.08, 0.12, 0.92)
			box.border_color = Color("#232c3a")
			ink = Color("#7d8796")
		_:
			box.bg_color = Color(0.07, 0.11, 0.17, 0.92)
			box.border_color = FIELD_BORDER
	node.add_theme_stylebox_override("panel", box)
	var text_node := label(text, 12, ink)
	text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_node.autowrap_mode = TextServer.AUTOWRAP_OFF
	node.add_child(text_node)
	return node


## Campo de texto e seletores (pesquisa, filtros).
static func style_field(node: Control) -> void:
	if node is OptionButton:
		node.get_popup().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var normal := _flat(SURFACE, FIELD_BORDER, 4, Color.WHITE)
	_pad(normal, 16, 6)
	var focus := _flat(SURFACE_HOVER, Color(GOLD, 0.75), 4, Color.WHITE)
	_pad(focus, 16, 6)
	for state in ["normal", "read_only"]:
		node.add_theme_stylebox_override(state, normal)
	node.add_theme_stylebox_override("focus", focus)
	if node is Button:
		var hover := _flat(SURFACE_HOVER, Color("#3c4a62"), 8, Color.WHITE)
		_pad(hover, 16, 6)
		for state in ["hover", "pressed", "hover_pressed"]:
			node.add_theme_stylebox_override(state, hover)
		for color in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			node.add_theme_color_override(color, TEXT)
	else:
		node.add_theme_color_override("font_color", TEXT)
		node.add_theme_color_override("font_placeholder_color", MUTED)


static func _pad(box: StyleBoxFlat, horizontal: int, vertical: int) -> void:
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical


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
	box.set_border_width_all(0 if border.a < 0.01 else 1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## Cartão/linha. `gold`: destaque (o próprio jogador, o selecionado). tint clareia/escurece.
static func plate(gold := false, tint := Color.WHITE) -> StyleBoxFlat:
	var box := _flat(SELECTED_BG if gold else SURFACE, Color(GOLD, 0.6) if gold else Color.TRANSPARENT, 4, tint)
	if gold:
		box.set_border_width_all(1)
	_pad(box, 22, 8)
	return box


## Botão em repouso: dourado (principal) ou superfície escura com filete (secundário).
static func button_plate(gold := false, tint := Color.WHITE) -> StyleBoxFlat:
	var box := _flat(GOLD if gold else SURFACE, Color.TRANSPARENT, 4, tint)
	_pad(box, 20, 6)
	return box


## Botão selecionado/pressionado.
static func selected_plate(primary := false, tint := Color.WHITE) -> StyleBoxFlat:
	var box := _flat(GOLD.darkened(0.12) if primary else SELECTED_BG, Color(GOLD, 0.6), 4, tint)
	box.set_border_width_all(1)
	_pad(box, 20, 6)
	return box


## Painel de seção. `small` (celular): cantos menores.
static func frame_panel(padding := 34, small := false) -> StyleBoxFlat:
	var box := _flat(PANEL_BG, Color.TRANSPARENT, 4, Color.WHITE)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 0
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
	node.texture = portrait_texture(character_id)
	return node


static func portrait_texture(character_id: String) -> Texture2D:
	var packaged := "res://assets/portraits/%s.png" % character_id if character_id.is_valid_filename() else ""
	if not packaged.is_empty() and ResourceLoader.exists(packaged, "Texture2D"):
		return load(packaged) as Texture2D
	var cached := bust(ThumbnailCache.path_for(character_id)) if character_id.is_valid_filename() else null
	return cached if cached != null else preload("res://assets/icons/vector/icon_friends.svg")


## Bustos recortados das miniaturas (2048 px), guardados em memória e numa versão pequena
## ao lado delas ("_card_720.png"): abrir telas, buscar ou filtrar não relê nem recorta os PNGs
## grandes de novo (antes isso travava as telas por 1–2 s).
static var _busts := {}
const BUST_HEIGHT := 720


static func bust(path: String) -> Texture2D:
	if not FileAccess.file_exists(path): return null
	var stamp := FileAccess.get_modified_time(path)
	var key := "%s@%d:%d" % [path, stamp, BUST_HEIGHT]
	if _busts.has(key): return _busts[key]
	var small := path.get_basename() + "_card_%d.png" % BUST_HEIGHT
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
