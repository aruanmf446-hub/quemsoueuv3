class_name PlayerScreen
extends Control

signal back_requested
signal navigate_requested(route: String, params: Dictionary)
@onready var body: VBoxContainer = $Margin/Column/Scroll/Body
@onready var banner: StateBanner = $Margin/Column/StateBanner
@onready var heading: Label = $Margin/Column/Header/Title
var services: PlayerServices
var parameters: Dictionary = {}


func _ready() -> void:
	services = PlayerServices.current
	$Margin/Column/Header/Back.pressed.connect(func() -> void: back_requested.emit())
	# A moldura dourada cortava títulos e conteúdo; o padrão das telas agora é sem moldura.
	var crest := get_node_or_null("CrestFrame")
	if crest != null:
		crest.hide()


func show_screen(params: Dictionary = {}) -> void:
	parameters = params.duplicate(true)
	show()
	render()
	$Margin/Column/Header/Back.grab_focus()


func render() -> void:
	pass


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
