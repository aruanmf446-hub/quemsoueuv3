extends Control
## Entrada do jogo: mostra cartões de abertura enquanto o menu é carregado.

func _ready() -> void:
	_open_presentation.call_deferred()

func _open_presentation() -> void:
	var presentation := CampaignLoading.new()
	presentation.name = "CampaignLoading"
	presentation.opening = true
	get_tree().root.add_child(presentation)
	presentation.begin("res://scenes/menu/main_menu.tscn", _enter_menu, true)

func _enter_menu(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)
