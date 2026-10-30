class_name PlayerOrientationGuard
extends CanvasLayer

var _overlay: Control
var _center: CenterContainer
var _column: VBoxContainer


func _ready() -> void:
	layer = 100
	_overlay = Control.new()
	add_child(_overlay)
	PlayerUI.apply_theme(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0d131a")
	_overlay.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center = CenterContainer.new()
	_overlay.add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_column = PlayerUI.column(_center)
	_column.custom_minimum_size.x = 320
	var title := PlayerUI.label("Gire o dispositivo", 32, PlayerUI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var detail := PlayerUI.label("Quem Sou Eu utiliza a tela na horizontal.", 18)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(detail)
	_center.minimum_size_changed.connect(func() -> void: _resize.call_deferred())
	get_viewport().size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	var window_size := _overlay.get_window().size
	var unit := PlayerUI.unit(_overlay)
	_center.scale = Vector2.ONE * unit
	_center.size = get_viewport().get_visible_rect().size / unit
	_column.custom_minimum_size.x = maxf(240, minf(420, _center.size.x - 40))
	_overlay.visible = window_size.y > window_size.x


func _input(_event: InputEvent) -> void:
	if _overlay != null and _overlay.visible:
		get_viewport().set_input_as_handled()
