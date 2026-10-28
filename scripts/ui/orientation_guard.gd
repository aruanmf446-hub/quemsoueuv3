class_name PlayerOrientationGuard
extends CanvasLayer

var _overlay: Control


func _ready() -> void:
	layer = 100
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0c1730")
	_overlay.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := PlayerUI.column(center)
	column.custom_minimum_size.x = 600
	var title := PlayerUI.label("Gire o dispositivo", 42, PlayerUI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := PlayerUI.label("Quem Sou Eu utiliza a tela na horizontal.", 25)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	get_viewport().size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	var window_size := DisplayServer.window_get_size()
	_overlay.visible = window_size.y > window_size.x


func _input(_event: InputEvent) -> void:
	if _overlay != null and _overlay.visible:
		get_viewport().set_input_as_handled()
