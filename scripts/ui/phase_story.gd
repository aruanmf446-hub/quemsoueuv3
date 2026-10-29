class_name PhaseStory
extends CanvasLayer
## Introdução ilustrada de cada fase. A cena já foi lida antes de abrir este painel.

signal finished
signal cancelled

var _carousel: PresentationCarousel
var _closed := false

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carousel = PresentationCarousel.new()
	_carousel.name = "PhaseStoryCards"
	_carousel.manual_story = true
	_carousel.allow_skip = true
	_carousel.skip_requested.connect(_finish)
	_carousel.story_finished.connect(_finish)
	add_child(_carousel)

func begin(order: int) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/phase_stories.json"))
	var entries: Array = parsed.get("phases", {}).get("%02d" % order, []) if parsed is Dictionary else []
	if entries.is_empty():
		_finish.call_deferred()
		return
	_carousel.set_cards_data(entries)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()

func _finish() -> void:
	if _closed: return
	_closed = true
	finished.emit()
	queue_free()

func _cancel() -> void:
	if _closed: return
	_closed = true
	cancelled.emit()
	queue_free()
