class_name PrototypeReturnOverlay
extends CanvasLayer

## Apenas navegação ao redor da cena original; não modifica seu gameplay ou HUD.
var return_action: Callable


func _ready() -> void:
	var back := PlayerUI.button("‹ Voltar aos reinos", return_action)
	back.position = Vector2(24, 18)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		return_action.call()
		get_viewport().set_input_as_handled()
