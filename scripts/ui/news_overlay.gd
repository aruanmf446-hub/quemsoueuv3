class_name NewsOverlay
extends CanvasLayer
## Notícias locais do jogo; cartões editáveis em data/ui/presentation.json.

var _carousel: PresentationCarousel

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carousel = PresentationCarousel.new()
	_carousel.set_cards("news")
	_carousel.dwell_seconds = 5.0
	_carousel.show_close = true
	_carousel.allow_skip = false
	_carousel.close_requested.connect(queue_free)
	add_child(_carousel)
	_carousel.focus_close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
