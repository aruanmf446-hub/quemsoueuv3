extends Node
## TEST ONLY: staging export. Sem login, banco ou chamadas de backend.
var loading: CampaignLoading
var phase: Node3D
var _callback: JavaScriptObject
func _ready() -> void:
	if not OS.has_feature("iphone_layout_fixture"):
		push_error("Use only the isolated Web fixture export")
		return
	_callback = JavaScriptBridge.create_callback(_probe)
	JavaScriptBridge.get_interface("window").qseDesertProbe = _callback
	loading = CampaignLoading.new()
	add_child(loading)
	loading.begin("res://scenes/desert/phase_01.tscn",_launch)
func _launch(packed: PackedScene) -> void:
	phase = packed.instantiate()
	get_tree().root.add_child(phase)
	get_tree().current_scene = phase
	if is_instance_valid(loading): loading.queue_free()
func rect(control: Control) -> Array:
	var area := control.get_global_rect()
	return [area.position.x,area.position.y,area.size.x,area.size.y]
func _probe(args: Array) -> void:
	if args.size() and str(args[0]) == "powers" and is_instance_valid(phase):
		for kind in ["rupture","amber","dash"]:
			for index in range(3): phase._player.restore_charge(kind)
	var size := get_viewport().get_visible_rect().size
	var state := {"size":[size.x,size.y],"iphone":UIScale.is_iphone(),"stage":"loading","read":PhaseStory.was_read(1)}
	if is_instance_valid(phase):
		state.stage = "play"
		state.charges = phase._player.abilities
		phase._touch_pad._layout()
		state.buttons = {}
		for kind in phase._touch_pad._buttons:
			var spec: Array = phase._touch_pad._buttons[kind]
			state.buttons[kind] = [spec[0].x,spec[0].y,spec[1]]
		state.health = phase._player.health
		state.x = phase._player.position.x
		state.player_dash = phase._player._dash_left
	elif is_instance_valid(loading) and is_instance_valid(loading._carousel):
		state.index = loading._carousel.index
		state.cards = loading._carousel.cards.size()
		state.story = loading._story_mode
		state.ready = loading._packed != null
		state.next = rect(loading._carousel._story_next)
		state.skip = rect(loading._carousel._skip)
	JavaScriptBridge.eval("window.qseDesertState="+JSON.stringify(state))
