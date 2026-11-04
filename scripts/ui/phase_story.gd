class_name PhaseStory
extends CanvasLayer
## História manual com leitura local persistente; sem alterar progresso ou recompensas.
signal finished
signal cancelled
const STORIES_PATH := "res://data/ui/phase_stories.json"
const READ_PATH := "user://desert_story_read_v3.cfg"
const READ_KEY := "qse-v3:desert:story-read:v3:"
var force_replay := false
var _carousel: PresentationCarousel
var _closed := false
var _order := 0
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
	_carousel.hide()
func begin(order: int) -> void:
	_order = order
	if not force_replay and was_read(order):
		_finish.call_deferred()
		return
	var entries := cards_for(order)
	if entries.is_empty():
		_finish.call_deferred()
		return
	_carousel.set_cards_data(entries)
	_carousel.show()
static func cards_for(order: int) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORIES_PATH))
	var entries: Array = parsed.get("phases",{}).get("%02d" % order,[]).duplicate(true) if parsed is Dictionary else []
	for index in range(entries.size()):
		var atlas_entry: bool = entries[index].has("atlas_region")
		for ext in ["webp","png","jpg","jpeg"]:
			var path := "res://assets/story/origin_%02d.%s" % [index+1,ext] if atlas_entry else "res://assets/story/fase%02d_%02d.%s" % [order,index+1,ext]
			if ResourceLoader.exists(path):
				entries[index].image = path
				entries[index].erase("atlas_region")
				break
	return entries
static func was_read(order: int) -> bool:
	if order < 1 or order > 10: return false
	var saved := ConfigFile.new()
	if saved.load(READ_PATH) == OK and bool(saved.get_value("read","phase_%02d" % order,false)): return true
	if OS.has_feature("web"):
		return UIScale.js_true(JavaScriptBridge.eval("(function(){try{return localStorage.getItem("+JSON.stringify(READ_KEY+str(order))+")===\"1\";}catch(e){return false;}})()"))
	return false
static func mark_read(order: int) -> Error:
	if order < 1 or order > 10: return ERR_INVALID_PARAMETER
	var saved := ConfigFile.new()
	saved.load(READ_PATH)
	saved.set_value("read","phase_%02d" % order,true)
	var result := saved.save(READ_PATH)
	if OS.has_feature("web"):
		var backed_up := UIScale.js_true(JavaScriptBridge.eval("(function(){try{localStorage.setItem("+JSON.stringify(READ_KEY+str(order))+",\"1\");return true;}catch(e){return false;}})()"))
		if backed_up: return OK
	return result
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()
func _finish() -> void:
	if _closed: return
	_closed = true
	mark_read(_order)
	finished.emit()
	queue_free()
func _cancel() -> void:
	if _closed: return
	_closed = true
	cancelled.emit()
	queue_free()
