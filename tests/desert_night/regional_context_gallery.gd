extends SceneTree
## Aproximação por fixture; cenário, personagens, câmera e HUD verdadeiros.
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args:=OS.get_cmdline_user_args()
	var out:=args[0]
	var size:=args[1].split("x")
	root.size=Vector2i(int(size[0]),int(size[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var examples:=args[2].split(",") if args.size()>2 else PackedStringArray(["1:2","2:3","3:8","4:9","4:38","5:8","5:38","6:12","7:8","8:9","9:35","10:10"])
	for example in examples:
		var spec:=example.split(":")
		var order:=int(spec[0])
		var slot:=int(spec[1])
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		while phase._phase.surfaces[slot].get("task_void",false):slot+=1
		var surface: Dictionary=phase._phase.surfaces[slot]
		var width:=float(surface.right)-float(surface.left)
		phase._player.position=Vector3(float(surface.left)+minf(7.5,width*0.35),float(surface.height)+0.05,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._stream_world(phase._player.position.x,true)
		for i in 2400:
			if phase._build_queue.is_empty():break
			phase._process(0)
		for enemy in phase._troops.get_children():enemy.set_physics_process(false)
		await ticks(16)
		phase._player.set_physics_process(false)
		phase._player._model.visible=true
		phase._follow_camera(1.0)
		phase._hud._toast.hide()
		if is_instance_valid(phase._hud._place):phase._hud._place.hide()
		await ticks(4)
		await RenderingServer.frame_post_draw
		var label:="fase_%02d_regiao_%02d" % [order,slot]
		var error:=root.get_texture().get_image().save_png(out+"/"+label+".png")
		records.append({"name":label,"error":error,"order":order,"surface":slot,"on_floor":phase._player.is_on_floor(),"fixture_teleport":true,"physical_device":false})
		phase.free()
		current_scene=null
		paused=false
		await ticks(3)
	FileAccess.open(out+"/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit(0 if records.all(func(r: Dictionary) -> bool:return r.error==0 and r.on_floor) else 1)
