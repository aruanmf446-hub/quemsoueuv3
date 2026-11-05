extends "res://tests/desert_night/roof_skyline_gallery.gd"
func save_frame(name: String,out: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(out+"/"+name+".png")
	records.append({"name":name,"fixture_teleport":true,"error":error,"iphone":UIScale.is_iphone()})
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var dims := args[1].split("x")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(int(dims[0]),int(dims[1]))
	for order in [1,2,4]:
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase._player._invulnerable=999
		if "--steps-only" in args:
			var step_floor: Dictionary=phase._phase.surfaces[3]
			var step_x: float = float(step_floor.left)+(float(phase._phase.length)+6.0 if order==2 else float(phase._phase.length)+26.0)/phase._phase.surfaces.size()*(0.35 if order==2 else 0.5)-4.0
			await shot(phase,step_x,float(step_floor.height),"fase_%02d_patamares" % order,out)
			phase.free()
			current_scene=null
			paused=false
			for i in 3:await process_frame
			continue
		var gap: Dictionary=phase._phase.holes[0]
		await shot(phase,float(gap.start)-1.6,float(gap.from_y),"fase_%02d_borda" % order,out)
		var floor: Dictionary=phase._phase.surfaces[3]
		await shot(phase,float(floor.left)+(float(phase._phase.length)+6.0 if order==2 else float(phase._phase.length)+26.0)/phase._phase.surfaces.size()*(0.35 if order==2 else 0.5)-4.0,float(floor.height),"fase_%02d_patamares" % order,out)
		if order==2:
			floor=phase._phase.surfaces[5]
			await shot(phase,float(floor.left)+3,float(floor.height),"telhado_alto",out)
			floor=phase._phase.surfaces[8]
			await shot(phase,float(floor.right)-2,float(floor.height),"telhado_descida",out)
		if order==4:
			var fragile: Dictionary=phase._phase.holes.filter(func(g: Dictionary) -> bool:return g.get("crumble_bridge",false))[0]
			await shot(phase,float(fragile.start)-1.2,float(fragile.from_y),"ponte_fragil",out)
			var stone: Node3D
			for node in get_nodes_in_group("crumble_stones"):
				if absf(node.position.x-(float(fragile.start)+float(fragile.end))*0.5)<0.1:stone=node
			stone._crumble()
			for i in 7:await process_frame
			await save_frame("ponte_fragil_caindo",out)
			gap=phase._phase.tasks.filter(func(g: Dictionary) -> bool:return g.task_kind=="bridge")[0]
			await shot(phase,float(gap.start)-1.6,float(gap.from_y),"tarefa_ponte_antes",out)
			phase._player.set_physics_process(true)
			for i in 12: await physics_frame
			phase._player.set_physics_process(false)
			phase._update_bridge_hint()
			await save_frame("tarefa_ponte_botao",out)
			phase._raise_earth_bridge()
			for index in 4:
				for i in 6: await process_frame
				await save_frame("tarefa_ponte_%02d" % index,out)
		phase.free()
		current_scene=null
		paused=false
		for i in 3:await process_frame
	FileAccess.open(out+("/steps-captures.json" if "--steps-only" in args else "/captures.json"),FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit(0 if records.all(func(r: Dictionary) -> bool:return r.error==0) else 1)
