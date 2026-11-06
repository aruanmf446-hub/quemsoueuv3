extends Node
## TEST ONLY: staging export. Sem login, banco ou chamadas de backend.
var loading: CampaignLoading
var phase: Node3D
var _callback: JavaScriptObject
var _order := 1
var _switching := false
var _pedestal_fixture_id := ""
var _amber_showcase: Node3D
var _prop_fixture: StaticBody3D
func _ready() -> void:
	if not OS.has_feature("iphone_layout_fixture"):
		push_error("Use only the isolated Web fixture export")
		return
	if bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('firstUse')")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://desert_first_use_v1.cfg"))
	else:
		preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
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
	if args.size() and str(args[0])=="prop_approach" and is_instance_valid(phase):
		phase.set_physics_process(false)
		for i in 2400:
			if phase._build_queue.is_empty():break
			phase._process(0)
		_prop_fixture=get_tree().get_nodes_in_group("campaign_one_way").filter(func(n: Node) -> bool:return n.get_meta("prop_asset","")=="capital_market_stall" and n.get_meta("prop_ledge",-1)==0)[0]
		phase._player.position=Vector3(_prop_fixture.position.x,float(_prop_fixture.get_meta("source_floor"))+0.04,0)
		phase._player.velocity=Vector3.ZERO
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		phase._player._invulnerable=0.0
		for i in 3:phase._follow_camera(1.0)
		phase._scenery.follow(phase._camera,phase._player.position.x)
	# Fixture de acabamento: pose mantida para conferir o shader WebGL, sem medir gameplay.
	if args.size() and str(args[0])=="amber_showcase" and is_instance_valid(phase):
		phase.set_physics_process(false)
		phase._player.set_physics_process(false)
		phase._player._invulnerable=0.0
		phase._player._model.show()
		var floor: Dictionary=phase._phase.surfaces[6]
		var x:=float(floor.left)+13.0
		var y:=float(floor.height)
		phase._player.position=Vector3(x,y+0.03,0)
		phase._player.velocity=Vector3.ZERO
		phase._player.facing=1.0
		phase._stream_world(x,true)
		for i in 2400:
			if phase._build_queue.is_empty():break
			phase._process(0)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		_amber_showcase=phase._create_enemy()
		_amber_showcase.reparent(phase._troops)
		_amber_showcase.setup(phase._enemy_catalog.cactus,{"patrol":[x-8.0,x+8.0]})
		_amber_showcase.position=Vector3(x-2.8,y+0.03,0)
		_amber_showcase.add_to_group("enemies")
		_amber_showcase.show()
		_amber_showcase.set_physics_process(false)
		phase._player.restore_charge("amber")
		phase._player.use_ability("amber")
		_amber_showcase._model.set_rate(0.0)
		for i in 3:phase._follow_camera(1.0)
		phase._scenery.follow(phase._camera,x)
	if args.size() and str(args[0]).begins_with("collect_power:") and is_instance_valid(phase):
		var kind:=str(args[0]).trim_prefix("collect_power:")
		var item: Dictionary=phase._phase.pickups.filter(func(p: Dictionary) -> bool:return p.kind==kind)[0]
		phase._player.position=Vector3(float(item.pos[0]),float(item.pos[1])+0.05,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._stream_world(phase._player.position.x,true)
		for i in 2400:
			if phase._build_queue.is_empty():break
			phase._process(0)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	if args.size() and str(args[0])=="rupture_floor" and is_instance_valid(phase):
		var floor: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("breakable",false))[0]
		phase._player.position=Vector3(float(floor.span_end)+3,float(floor.surface_top)+0.05,0)
		phase._player.velocity=Vector3.ZERO
		phase._stream_world(phase._player.position.x,true)
		for i in 2400:
			if phase._build_queue.is_empty():break
			phase._process(0)
	if args.size() and str(args[0])=="tutorial:defense" and is_instance_valid(phase):
		for item in get_tree().get_nodes_in_group("campaign_pickups"):
			if phase.is_ancestor_of(item) and item.kind=="defense":
				phase._player.position=item.global_position+Vector3.UP*0.05
				phase._player.velocity=Vector3.ZERO
				phase._player._invulnerable=999
				break
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
	if args.size() and str(args[0]) in ["bridge","task","tutorial:task"] and is_instance_valid(phase):
		var hole: Dictionary=phase._phase.tasks[0] if str(args[0]) in ["task","tutorial:task"] else phase._phase.tasks.filter(func(g: Dictionary) -> bool:return g.task_kind=="bridge")[0]
		phase._player.position=Vector3(float(hole.start)-1.6,float(hole.from_y)+0.1,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		if str(args[0])!="tutorial:task":
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
		state.paused=get_tree().paused
		state.first_use={"active":phase._first_use.active,"kind":phase._first_use.kind,"continue":rect(phase._first_use._continue),"illustration":phase._first_use._illustration.visible}
		state.attack_charge=phase._player.attack_charges
		state.order = phase._order
		state.skyline = is_instance_valid(phase._scenery._skyline)
		state.palace_pool = phase._scenery._skyline._palaces.size() if state.skyline else 0
		state.house_roofs = get_tree().get_nodes_in_group("playable_house_roofs").size()
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
		if _order==2:
			var support:=preload("res://scripts/desert/t15d/campaign_layout.gd").floor_at(phase._phase,phase._player.position.x)
			if not support.is_empty():
				var samples: Array=[]
				for i in range(2,19):
					var fraction:=i/20.0
					var x:=lerpf(float(support.left),float(support.right),fraction)
					if absf(x-phase._player.position.x)<1.3:continue
					var screen: Vector2=phase._camera.unproject_position(Vector3(x,float(support.height),0))
					if screen.x<16 or screen.x>size.x-16:continue
					var occupied:=false
					for pedestal: Node3D in get_tree().get_nodes_in_group("campaign_pedestals"):
						if absf(pedestal.global_position.x-x)<0.8:occupied=true
					if occupied:continue
					samples.append([screen.x,screen.y])
					if samples.size()==3:break
				state.roof={"samples":samples,"lead":phase._lead,"grounded":phase._player.is_on_floor(),"height":support.height}
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
		state.grounded=phase._player.is_on_floor()
		state.ceiling=phase._player.is_on_ceiling()
		state.vy=phase._player.velocity.y
		state.jumps_used=phase._player.jumps_used
		if is_instance_valid(_prop_fixture):
			state.prop={"top":_prop_fixture.get_meta("one_way_top"),"base":_prop_fixture.get_meta("source_floor"),"span":_prop_fixture.get_meta("landing_span")}
		state.amber_showcase=is_instance_valid(_amber_showcase) and _amber_showcase.is_visible_in_tree() and _amber_showcase.crystallized_left>0 and is_instance_valid(_amber_showcase._crystal) and _amber_showcase._crystal.is_visible_in_tree()
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
