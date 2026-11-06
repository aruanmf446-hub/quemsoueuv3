extends SceneTree
## Revisão visual: posições de inspeção por teleporte; não prova de travessia.
var records: Array = []
func _initialize() -> void: call_deferred("run")
func shot(phase: Node3D, x: float, y: float, name: String, out: String) -> void:
	phase._player.position = Vector3(x,y+0.05,0)
	phase._player.velocity = Vector3.ZERO
	phase._player.set_physics_process(false)
	phase.set_physics_process(false)
	phase._stream_world(x,true)
	for i in 240:
		if phase._build_queue.is_empty(): break
		phase._process(0)
	phase._follow_camera(1.0)
	for i in 10: await process_frame
	phase._player._model.visible = true
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(out+"/"+name+".png")
	records.append({"name":name,"fixture_teleport":true,"x":x,"y":y,"error":error,"iphone":UIScale.is_iphone()})
	print("SKYLINE_CAPTURE ",name," error=",error)
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var dims := args[1].split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]),int(dims[1]))
	for order in [2,3,5,7,9]:
		var phase: Node3D = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase._player._invulnerable=999
		if order == 2:
			await shot(phase,float(phase._phase.player_spawn[0]),float(phase._phase.player_spawn[1]),"telhados_inicio",out)
			for index in [0,4,12]:
				var gap: Dictionary = phase._phase.holes[index]
				await shot(phase,float(gap.start)-1.2,float(gap.from_y),"telhados_vao_%02d" % index,out)
		var floor: Dictionary = phase._phase.surfaces[floori(phase._phase.surfaces.size()/2.0)]
		await shot(phase,(float(floor.left)+float(floor.right))*0.5,float(floor.height),"fase_%02d_fundo" % order,out)
		phase.free()
		current_scene=null
		paused=false
		for i in 3: await process_frame
	var file := FileAccess.open(out+"/captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	quit(0 if records.all(func(r: Dictionary) -> bool: return r.error == 0) else 1)
