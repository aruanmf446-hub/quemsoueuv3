extends SceneTree
const Assets = preload("res://scripts/desert/t15d/kingdom_assets.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func run() -> void:
	var used := {}
	for order in range(1,11):
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		phase._player.set_physics_process(false)
		phase._player._invulnerable=999
		for point: Dictionary in Assets.placements(order):
			phase._player.position=Vector3(float(point.x),float(point.y)+0.05,0)
			phase._stream_world(float(point.x),true)
			for step in range(200):
				if phase._build_queue.is_empty(): break
				phase._process(0)
			var matched := false
			for node in get_nodes_in_group("kingdom_art"):
				if not phase.is_ancestor_of(node): continue
				var id := String(node.get_meta("asset_id",""))
				used[id]=true
				if point.anchor in ["facade","under_surface"]:
					if id==point.asset and node.has_meta("clip_left") and float(point.x)>=float(node.get_meta("clip_left"))-0.01 and float(point.x)<=float(node.get_meta("clip_right"))+0.01: matched=true
				elif node.get_meta("landmark_id","")==point.id: matched=true
			check(matched,"fase%02d instala %s %s" % [order,point.id,point.asset])
		check(phase._phase.player_spawn[1]>=8.0 if order==2 else true,"fase%02d preserva apoio do percurso" % order)
		if order in [6,10]: check(phase._scenery._panorama==null,"fase%02d subterrânea sem céu" % order)
		# Arte de piso é filha da mesma peça removida pela Ruptura.
		var art: Array = phase._world.find_children("CapitalHouseArt","Sprite3D",true,false)
		check(not art.is_empty(),"fase%02d contém arte aprovada no mundo" % order)
		phase.free()
		current_scene=null
		paused=false
		for frame in range(2): await process_frame
	check(used.size()==15,"quinze módulos aprovados usados nas dez fases")
	print("APPROVED_ASSETS_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
