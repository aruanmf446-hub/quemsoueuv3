extends SceneTree
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var out:=args[0]
	var dims:=args[1].split("x")
	DirAccess.make_dir_recursive_absolute(out)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(int(dims[0]),int(dims[1]))
	var phase: Node3D=load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	phase.set_physics_process(false)
	for index in [0,1,2,4]:
		var house: Dictionary=phase._phase.surfaces[index]
		var x: float=(float(house.left)+float(house.right))*0.5 if index%2==0 else float(house.right)-1.0
		phase._player.position=Vector3(x,float(house.height)+0.06,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._player.set_physics_process(true)
		phase._stream_world(x,true)
		for i in 1500:
			if phase._build_queue.is_empty():break
			phase._process(0)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		for i in 12:await physics_frame
		phase._player.set_physics_process(false)
		phase._player._model.visible=true
		phase._follow_camera(1)
		phase._hud._toast.hide()
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		var name: String="casa_%02d" % index
		var error:=root.get_texture().get_image().save_png(out+"/"+name+".png")
		records.append({"name":name,"error":error,"fixture_teleport":true,"on_floor":phase._player.is_on_floor(),"house":index})
	FileAccess.open(out+"/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	phase.free()
	current_scene=null
	quit(0 if records.size()==4 and records.all(func(r: Dictionary) -> bool:return r.error==0 and r.on_floor) else 1)
