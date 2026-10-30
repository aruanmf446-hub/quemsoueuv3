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
	services = PlayerServices.current
	$Margin/Column/Header/Back.pressed.connect(func() -> void: back_requested.emit())
	# Visual comum: sem a moldura ornamental (cobria o conteúdo), fundo escurecido e
	# botão Voltar inclinado no estilo do resto do menu.
	$CrestFrame.hide()
	$Tint.color = Color(0.02, 0.035, 0.07, 0.86)
	PlayerUI.style_button($Margin/Column/Header/Back, false)
	heading.add_theme_color_override("font_color", Color.WHITE)
	resized.connect(_adapt_scale)
	_adapt_scale.call_deferred()

## No celular a tela inteira é desenhada maior (em pontos da tela), como nas
## Configurações; antes o layout de computador ficava minúsculo no aparelho.
func _adapt_scale() -> void:
	if manages_own_scale or not is_inside_tree(): return
	var margin: MarginContainer = $Margin
	var factor := maxf(1.0, UIScale.unit_for(get_viewport()) * 0.75) if UIScale.is_compact() else 1.0
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2.ONE * factor
	margin.position = Vector2.ZERO
	margin.size = size / factor
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 24 if factor > 1.0 else 76)
	margin.add_theme_constant_override("margin_top", 16 if factor > 1.0 else 70)
	margin.add_theme_constant_override("margin_bottom", 12 if factor > 1.0 else 62)


func show_screen(params: Dictionary = {}) -> void:
	parameters = params.duplicate(true)
	show()
	render()
	$Margin/Column/Header/Back.grab_focus()


func render() -> void:
	pass


## Chamado pela navegação ao abrir a tela: o conteúdo entra em cascata.
func animate_in() -> void:
	PlayerUI.cascade(body)


func status(result: Dictionary) -> void:
	banner.show_state(result.state, "" if result.ok else ServiceResult.message(result))


func account_button(parent: Node) -> void:
	parent.add_child(PlayerUI.button("Entrar na conta", func() -> void: navigate_requested.emit("account", {})))


func preview(parent: Node, character_id: String) -> LobbyStage:
	var entry := services.inventory.entry(character_id)
	if entry.is_empty():
		parent.add_child(PlayerUI.label("Skin ainda não disponível.", 20))
		return null
	var stage := preload("res://scenes/lobby/lobby_stage.tscn").instantiate() as LobbyStage
	stage.custom_minimum_size = Vector2(330, 360)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.interactive = true
	parent.add_child(stage)
	stage.apply_profile(services.preferences.values.quality)
	stage.show_character(entry)
	return stage
