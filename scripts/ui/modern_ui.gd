class_name ModernUI
extends RefCounted

## Linguagem visual dos menus secundários (Amizades, Perfil, Carteira, Conta e História),
## alinhada ao lobby atual: painéis azul-marinho translúcidos, destaque dourado, títulos em
## caixa alta e botões planos. Não usa a moldura dourada antiga nem a textura azul dos
## botões gerais (PlayerUI), que continuam valendo para as outras telas.

const PANEL := Color(0.05, 0.09, 0.16, 0.92)
const PANEL_BORDER := Color("#2b4066")
const SURFACE := Color("#17283f")
const SURFACE_HOVER := Color("#20355a")
const SURFACE_DISABLED := Color("#141e2e")
const ACCENT := Color("#f2cf7d")
const PRIMARY := Color("#e8a95c")
const PRIMARY_TEXT := Color("#17110a")
const TEXT := Color("#edf3ff")
const MUTED := Color("#9fb2cc")
const DANGER := Color("#ff9d8f")
## Janela física estreita (ex.: 844 px): o palco escala a tela inteira, então as fontes
## lógicas são multiplicadas para continuarem legíveis em pixels reais.
const COMPACT_WINDOW := 1100
const COMPACT_SCALE := 2.2

static var scale := 1.0


## Atualiza a escala a partir da janela física. Chamar antes de montar a tela.
static func update_scale(node: Node) -> void:
	scale = COMPACT_SCALE if node.get_window().size.x < COMPACT_WINDOW else 1.0
	# A faixa de status tem fonte fixa no componente compartilhado; escalona só nestas telas.
	var screen := node as PlayerScreen
	if screen == null:
		return
	# Cabeçalho também depende da escala; é estilizado aqui para acompanhar o modo compacto.
	style_header(screen)
	if screen.banner.get_child_count() > 0:
		(screen.banner.get_child(0) as Label).add_theme_font_size_override("font_size", fs(20))


static func compact() -> bool:
	return scale > 1.0


static func fs(size: int) -> int:
	return int(round(size * scale))


## Reconstrói a tela quando a janela muda de tamanho (passagem entre modo largo e compacto).
static func follow_resize(screen: PlayerScreen) -> void:
	screen.get_viewport().size_changed.connect(func() -> void:
		if screen.is_visible_in_tree():
			screen.render())


## Cabeçalho sem moldura: botão Voltar discreto e título maior.
static func style_header(screen: PlayerScreen) -> void:
	var back := screen.get_node("Margin/Column/Header/Back") as Button
	back.add_theme_font_size_override("font_size", fs(19))
	back.custom_minimum_size = Vector2(fs(140), fs(48))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		back.add_theme_stylebox_override(state, _box(SURFACE_HOVER if state == "hover" else SURFACE, 12, ACCENT if state == "focus" else PANEL_BORDER, 12))
	screen.heading.add_theme_font_size_override("font_size", fs(38))
	screen.heading.add_theme_color_override("font_color", TEXT)


## Cartão de conteúdo. Devolve a coluna interna onde os elementos são adicionados.
static func panel(parent: Node, padding: int = 22) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box(PANEL, 18, PANEL_BORDER, fs(padding)))
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", fs(10))
	card.add_child(column)
	return column


## Rótulo de seção: pequeno, em caixa alta e dourado.
static func eyebrow(text: String) -> Label:
	return PlayerUI.label(text.to_upper(), fs(15), ACCENT)


static func title(text: String, size: int = 30) -> Label:
	return PlayerUI.label(text, fs(size), TEXT)


static func muted(text: String, size: int = 18) -> Label:
	return PlayerUI.label(text, fs(size), MUTED)


## Valor de destaque (ex.: saldo), com rótulo pequeno embaixo.
static func stat(parent: Node, caption: String, value: String, size: int = 40) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box(SURFACE, 16, PANEL_BORDER, fs(16)))
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", fs(4))
	card.add_child(column)
	column.add_child(eyebrow(caption))
	column.add_child(PlayerUI.label(value, fs(size), TEXT))
	return card


## Botão plano. `primary` destaca a ação principal, como o item "Jogar" do lobby.
static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = TranslationServer.translate(text)
	node.custom_minimum_size = Vector2(fs(110), fs(50))
	node.focus_mode = Control.FOCUS_ALL
	node.add_theme_font_size_override("font_size", fs(19))
	node.add_theme_color_override("font_color", PRIMARY_TEXT if primary else TEXT)
	node.add_theme_color_override("font_disabled_color", Color("#6f7d92"))
	var base := PRIMARY if primary else SURFACE
	var states := {"normal": base, "hover": base.lightened(0.1), "pressed": base.darkened(0.15), "focus": base, "disabled": SURFACE_DISABLED}
	for state: String in states:
		node.add_theme_stylebox_override(state, _box(states[state], 12, ACCENT if state == "focus" else base, 14, 2 if state == "focus" else 0))
	node.pressed.connect(action)
	return node


## Campo de texto com a mesma altura dos botões.
static func field(placeholder: String, secret: bool = false) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = TranslationServer.translate(placeholder)
	edit.secret = secret
	edit.custom_minimum_size.y = fs(52)
	edit.add_theme_font_size_override("font_size", fs(19))
	edit.add_theme_stylebox_override("normal", _box(SURFACE_DISABLED, 12, PANEL_BORDER, 12))
	edit.add_theme_stylebox_override("focus", _box(SURFACE_DISABLED, 12, ACCENT, 12, 2))
	return edit


static func _box(color: Color, radius: int, border: Color, padding: int, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(border_width)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
