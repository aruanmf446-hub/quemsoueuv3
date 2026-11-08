extends Control
## Only the shell expected by the production HeroCarousel; no gameplay or backend.
var _nickname_modal: Control
var hero: Control
class Composition extends Node:
	var brand: CanvasItem
	var brand_logo: CanvasItem
	var eyebrow: CanvasItem
	var footer: CanvasItem
	var chapter: CanvasItem
	var chapter_title: CanvasItem
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["MenuButtons","Logo","LobbyArea","FriendsPanel","NewsButton","Background"]:
		var node := Control.new()
		node.name=key
		add_child(node)
	var stage := Control.new()
	stage.name="Stage"
	$LobbyArea.add_child(stage)
	var viewport := SubViewport.new()
	viewport.name="Viewport"
	stage.add_child(viewport)
	var world := Node3D.new()
	world.name="World"
	viewport.add_child(world)
	var composition := Composition.new()
	composition.name="LobbyComposition"
	add_child(composition)
	var navigation := NavigationManager.new()
	navigation.name="Navigation"
	add_child(navigation)
	hero=load("res://scripts/menu/hero_carousel.gd").new()
	add_child(hero)

func update_pending() -> void:
	hero.set_pending_rewards(PlayerServices.current.rewards.pending_count())
