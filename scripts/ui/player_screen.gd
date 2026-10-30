class_name PlayerScreen
extends Control

signal back_requested
signal navigate_requested(route: String, params: Dictionary)
@onready var body: VBoxContainer = $Margin/Column/Scroll/Body
@onready var banner: StateBanner = $Margin/Column/StateBanner
@onready var heading: Label = $Margin/Column/Header/Title
var services: PlayerServices
var parameters: Dictionary = {}


## Telas que cuidam do próprio layout compacto (escala e tamanhos) ficam fora do
## ajuste automático abaixo.
var manages_own_scale := false

func _ready() -> void:
	PlayerUI.apply_theme(self)
	PlayerUI.style_backdrop($Tint)
	services = PlayerServices.current
	$Margin/Column/Header/Back.pressed.connect(func() -> void: back_requested.emit())
	# Visual comum: sem a moldura ornamental (cobria o conteúdo), fundo escurecido e
	# botão Voltar inclinado no estilo do resto do menu.
	$Tint.color = Color(0.02, 0.035, 0.07, 0.86)
	PlayerUI.style_back($Margin/Column/Header/Back)
	heading.add_theme_color_override("font_color", Color.WHITE)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Margin.grow_horizontal = Control.GROW_DIRECTION_END
	$Margin.grow_vertical = Control.GROW_DIRECTION_END
	$Margin.minimum_size_changed.connect(_refit_margin)
	resized.connect(_adapt_scale)
	_adapt_scale.call_deferred()

## No celular a tela inteira é desenhada maior (em pontos da tela), como nas
## Configurações; antes o layout de computador ficava minúsculo no aparelho.
func _adapt_scale() -> void:
	if manages_own_scale or not is_inside_tree(): return
	var margin: MarginContainer = $Margin
	var factor := PlayerUI.unit(self)
	var compact := size.y / factor < 600.0
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = size / factor
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 20 if compact else 40)
	margin.add_theme_constant_override("margin_top", 16 if compact else 28)
	margin.add_theme_constant_override("margin_bottom", 16 if compact else 28)

	var back: Button = $Margin/Column/Header/Back
	back.custom_minimum_size = Vector2(100, 44)
	back.add_theme_font_size_override("font_size", 16)
	heading.add_theme_font_size_override("font_size", 28 if compact else 34)
	$Margin/Column.add_theme_constant_override("separation", 16 if compact else 24)


## Wrapping labels can lower the minimum after the first layout pass. Refit the
## viewport-sized margin so a stale larger minimum does not leave it oversized.
func _refit_margin() -> void:
	if not is_inside_tree(): return
	var margin: MarginContainer = $Margin
	if is_zero_approx(margin.anchor_right):
		margin.set_deferred("size", size / margin.scale)
		margin.set_deferred("position", Vector2.ZERO)


func show_screen(params: Dictionary = {}) -> void:
	parameters = params.duplicate(true)
	show()
	render()
	_refit_margin.call_deferred()
	$Margin/Column/Header/Back.grab_focus()


## A screen with an internal reader may consume Back before the route is popped.
func handle_back() -> bool:
	return false


func render() -> void:
	pass


## Chamado pela navegação ao abrir a tela: o conteúdo entra em cascata.
func animate_in() -> void:
	PlayerUI.cascade(body)


func status(result: Dictionary) -> void:
	banner.show_state(result.state, "" if result.ok else ServiceResult.message(result))


func account_button(parent: Node) -> void:
	var enter := PlayerUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {}))
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	PlayerUI.style_button(enter, true)
	parent.add_child(enter)


func preview(parent: Node, character_id: String) -> LobbyStage:
	var entry := services.inventory.entry(character_id)
	if entry.is_empty():
		parent.add_child(PlayerUI.label("Skin ainda não disponível.", 20))
		return null
	var stage := preload("res://scenes/lobby/lobby_stage.tscn").instantiate() as LobbyStage
	stage.custom_minimum_size = Vector2(240, clampf(size.y / PlayerUI.unit(self) - 250, 120, 480))
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.interactive = true
	parent.add_child(stage)
	stage.apply_profile(services.preferences.values.quality)
	stage.show_character(entry)
	return stage
