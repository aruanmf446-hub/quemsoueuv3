extends Node
## TEST ONLY: staging export. Sem login, banco ou chamadas de backend.
var loading: CampaignLoading
var phase: Node3D
var _callback: JavaScriptObject
var _order := 1
var _switching := false
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
	if args.size() and str(args[0]) == "rooftops" and not _switching:
		_switching=true
		_rooftops.call_deferred()
	if args.size() and str(args[0]) == "cactus" and is_instance_valid(phase) and _order==2:
		phase._spawn_enemy(phase._troops,{"id":"web.roof.pursuit","pos":[phase._player.position.x+6.0,float(phase._phase.surfaces[0].height)+0.02,0],"patrol":[-4,4],"troop":true})
	if args.size() and str(args[0]) == "powers" and is_instance_valid(phase):
		for kind in ["rupture","amber","dash"]:
			for index in range(3): phase._player.restore_charge(kind)
	var size := get_viewport().get_visible_rect().size
	var state := {"size":[size.x,size.y],"iphone":UIScale.is_iphone(),"stage":"loading","read":PhaseStory.was_read(_order)}
	if is_instance_valid(phase):
		state.stage = "play"
		state.order = phase._order
		state.y = phase._player.position.y
		state.soldiers = []
		for enemy in phase._troops.get_children():
			state.soldiers.append({"id":str(enemy.get_meta("spawn_id","")),"x":enemy.position.x,"y":enemy.position.y,"vx":enemy.velocity.x})
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

func _rooftops() -> void:
	if is_instance_valid(phase): phase.queue_free()
	phase=null
	await get_tree().process_frame
	_order=2
	loading=CampaignLoading.new()
	add_child(loading)
	loading.begin("res://scenes/desert/phase_02.tscn",_launch)
