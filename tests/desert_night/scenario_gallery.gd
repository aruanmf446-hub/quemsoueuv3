extends SceneTree
## Capturas reais de inspeção. Aproximação por fixture; corrida no topo usa entradas físicas.
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func flush(phase: Node3D) -> void:
	for i in 1500:
		if phase._build_queue.is_empty():break
		phase._process(0)
func snap(phase: Node3D,out: String,name: String) -> void:
	phase._player.set_physics_process(false)
	phase._player._model.visible=true
	phase._follow_camera(1.0)
	phase._hud._toast.hide()
	if is_instance_valid(phase._hud._place):phase._hud._place.hide()
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(out+"/"+name+".png")
	records.append({"name":name,"error":error,"fixture_teleport":true,"on_floor":phase._player.is_on_floor(),"x":phase._player.position.x,"y":phase._player.position.y})
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var out:=args[0]
	var profile:=args[1]
	DirAccess.make_dir_recursive_absolute(out)
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(844,390) if profile=="iphone" else (Vector2i(640,360) if profile=="640" else Vector2i(1672,941))
	var orders: Array=range(1,11) if profile=="iphone" else ([1,2,3,7] if profile=="desktop" else [2,7])
	for order: int in orders:
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		if order==2:
			var house: Dictionary=phase._phase.surfaces[0]
			phase._player.position=Vector3(float(house.left)+1.0,float(house.height)+0.1,0)
		else:
			var route: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false))[0]
			phase._player.position=Vector3(float(route.span_start)+0.5,float(route.pos[1])+0.15,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._stream_world(phase._player.position.x,true)
		flush(phase)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		await frames(12)
		Input.action_press("move_right")
		await frames(20)
		Input.action_release("move_right")
		phase._player.set_physics_process(false)
		await snap(phase,out,"corrida_fase_%02d" % order)
		if profile=="desktop" and order in [1,3,7]:
			var task: Dictionary=phase._phase.tasks[0]
			phase._player.position=Vector3(float(task.start)-1.7,float(task.from_y)+0.1,0)
			phase._player.velocity=Vector3.ZERO
			phase._player.set_physics_process(true)
			phase._stream_world(phase._player.position.x,true)
			flush(phase)
			for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
			await frames(15)
			phase._update_bridge_hint()
			await snap(phase,out,"tarefa_%02d_antes" % order)
			phase._hud._bridge_task.pressed.emit()
			await frames(60)
			phase._player.set_physics_process(false)
			await snap(phase,out,"tarefa_%02d_depois" % order)
		phase.free()
		current_scene=null
		paused=false
		await frames(3)
	FileAccess.open(out+"/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit(0 if not records.is_empty() and records.all(func(r: Dictionary) -> bool:return r.error==0) else 1)
