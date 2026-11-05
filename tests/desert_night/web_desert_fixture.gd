extends Node
## TEST ONLY: staging export. Sem login, banco ou chamadas de backend.
var loading: CampaignLoading
var phase: Node3D
var _callback: JavaScriptObject
var _order := 1
var _switching := false
var _pedestal_fixture_id := ""
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
	_switching=false
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
		_switch_to.call_deferred(2)
	if args.size() and str(args[0]).begins_with("phase:") and not _switching:
		_switching=true
		_switch_to.call_deferred(clampi(int(str(args[0]).trim_prefix("phase:")),1,10))
	if args.size() and str(args[0]) == "cactus" and is_instance_valid(phase) and _order==2:
		phase._spawn_enemy(phase._troops,{"id":"web.roof.pursuit","pos":[phase._player.position.x+6.0,float(phase._phase.surfaces[0].height)+0.02,0],"patrol":[-4,4],"troop":true})
	if args.size() and str(args[0]) == "powers" and is_instance_valid(phase):
		for kind in ["rupture","amber","dash"]:
			for index in range(3): phase._player.restore_charge(kind)
	# TEST ONLY: aproxima o ator de uma recarga real; a física realiza a coleta.
	if args.size() and str(args[0]) in ["bridge","task"] and is_instance_valid(phase):
		var hole: Dictionary=phase._phase.tasks[0] if str(args[0])=="task" else phase._phase.tasks.filter(func(g: Dictionary) -> bool:return g.task_kind=="bridge")[0]
		phase._player.position=Vector3(float(hole.start)-1.6,float(hole.from_y)+0.1,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._player.attack_charges=0
		phase._player.defense_charges=0
		phase._stream_world(phase._player.position.x,true)
	if args.size() and str(args[0]) == "pedestal" and is_instance_valid(phase):
		for item: Node3D in get_tree().get_nodes_in_group("campaign_pickups"):
			if phase.is_ancestor_of(item) and item.get("kind") == "attack":
				_pedestal_fixture_id = str(item.get_meta("pickup_id"))
				phase._player.attack_charges = 2
				phase._player._invulnerable = 999.0
				phase._player.position = item.global_position + Vector3.UP*0.05
				phase._player.velocity = Vector3.ZERO
				break
	var size := get_viewport().get_visible_rect().size
	var state := {"size":[size.x,size.y],"iphone":UIScale.is_iphone(),"stage":"loading","read":PhaseStory.was_read(_order)}
	if is_instance_valid(phase):
		state.stage = "play"
		state.order = phase._order
		state.skyline = is_instance_valid(phase._scenery._skyline)
		state.palace_pool = phase._scenery._skyline._palaces.size() if state.skyline else 0
		state.rooftop_terraces = get_tree().get_nodes_in_group("rooftop_terraces").size()
		state.roof_surfaces = phase._world.find_children("City_roof","MeshInstance3D",true,false).size()
		state.bridge_task = rect(phase._hud._bridge_task) if phase._hud._bridge_task.visible else []
		state.bridges = []
		for bridge in get_tree().get_nodes_in_group("earth_bridges"):
			state.bridges.append({"raised":bridge.raised,"solid":not bridge._shape.disabled,"end":bridge.hole.end,"start":bridge.hole.start,"kind":bridge.hole.task_kind})
		state.defense_charge = phase._player.defense_charges
		state.pedestal_fixture = not _pedestal_fixture_id.is_empty()
		state.pedestal_collected = phase._collected_ids.has(_pedestal_fixture_id)
		state.pedestal_count = get_tree().get_nodes_in_group("campaign_pedestals").filter(func(n: Node) -> bool: return n.get_meta("pickup_id","") == _pedestal_fixture_id).size()
		state.pickup_count = get_tree().get_nodes_in_group("campaign_pickups").filter(func(n: Node) -> bool: return n.get_meta("pickup_id","") == _pedestal_fixture_id).size()

		state.art_ids=[]
		for node in get_tree().get_nodes_in_group("kingdom_art"):
			if phase.is_ancestor_of(node):
				var id: String=node.get_meta("asset_id","")
				if not state.art_ids.has(id): state.art_ids.append(id)
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

func _switch_to(order: int) -> void:
	if is_instance_valid(phase): phase.queue_free()
	phase=null
	await get_tree().process_frame
	_order=order
	loading=CampaignLoading.new()
	add_child(loading)
	loading.begin("res://scenes/desert/phase_%02d.tscn" % order,_launch)
