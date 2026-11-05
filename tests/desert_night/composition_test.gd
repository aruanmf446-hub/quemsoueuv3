extends SceneTree
const Assets = preload("res://scripts/desert/t15d/kingdom_assets.gd")
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+message)
func run() -> void:
	for order in range(1,11):
		var phase: Node3D = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		phase.set_physics_process(false)
		phase._player.set_physics_process(false)
		var stage := Layout.build(order)
		var bounded := true
		var variety := {}
		for floor: Dictionary in stage.surfaces:
			var parts := Assets.composition(order,int(floor.index),floor.left,floor.right,floor.height)
			if parts.size()>5: bounded = false
			var signature := ""
			for part: Dictionary in parts:
				if part.x-part.width*0.5<floor.left+0.59 or part.x+part.width*0.5>floor.right-0.59 or part.z>-5.0: bounded=false
				if not Assets.paths(order).has(Assets.entry(part.asset).texture): bounded=false
				if part.asset=="desert_mine_entrance": bounded=false
				if order==2 and float(part.y)>float(floor.height)-8.0: bounded=false
				signature += String(part.asset)+str(part.z)
			variety[signature] = true
		check(bounded,"fase %02d: grupos no piso, atrás da pista, aquecidos, até cinco módulos" % order)
		check(variety.size()>=3,"fase %02d: conjuntos e profundidades variados" % order)
		for x in [30.0,61.0,65.0,350.0,700.0,1100.0,30.0]:
			phase._player.position.x = x
			phase._stream_world(x,true)
			for i in 240:
				if phase._build_queue.is_empty(): break
				phase._process(0)
			for i in 2: await process_frame
			var ids := {}
			var valid: bool = phase._loaded_chunks.size()<=5
			for art: Node3D in get_nodes_in_group("kingdom_art"):
				if not phase.is_ancestor_of(art) or not art.has_meta("composition_id"): continue
				var id := str(art.get_meta("composition_id"))
				if ids.has(id) or not phase._world.is_ancestor_of(art): valid=false
				var half_width: float = art.pixel_size*float(art.texture.get_width())*0.5
				if art.position.x-half_width < float(art.get_meta("surface_left"))+0.59 or art.position.x+half_width > float(art.get_meta("surface_right"))-0.59: valid=false
				ids[id] = true
			check(valid and not ids.is_empty(),"fase %02d x%.0f: sem duplicação e streaming limitado" % [order,x])
		phase.free()
		for i in 2: await process_frame
		check(get_nodes_in_group("kingdom_art").is_empty(),"fase %02d: descarte remove a arte" % order)
	print("COMPOSITION checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
