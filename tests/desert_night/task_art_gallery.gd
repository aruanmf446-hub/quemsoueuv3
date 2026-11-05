extends SceneTree
## Galeria de mecanismos reais; aproximação por fixture, sem trocar a câmera do jogo.
var records: Array = []
func _initialize() -> void:call_deferred("run")
func ticks(count: int) -> void:
	for i in count:await physics_frame
func flush(phase: Node3D) -> void:
	for i in 2000:
		if phase._build_queue.is_empty():break
		phase._process(0)
func snap(phase: Node3D,out: String,label: String) -> void:
	phase._player.set_physics_process(false)
	phase._player._model.visible=true
	phase._follow_camera(1.0)
	phase._hud._toast.hide()
	if is_instance_valid(phase._hud._place):phase._hud._place.hide()
	await ticks(4)
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(out+"/"+label+".png")
	records.append({"name":label,"error":error,"fixture_teleport":true,"on_floor":phase._player.is_on_floor()})
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var size := args[1].split("x")
	root.size=Vector2i(int(size[0]),int(size[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var examples: PackedStringArray = args[2].split(",") if args.size()>2 else PackedStringArray(["1:0","2:0","7:0"])
	for example: String in examples:
		var pair := example.split(":")
		var order := int(pair[0])
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		var task: Dictionary=phase._phase.tasks[int(pair[1])]
		phase._player.position=Vector3(float(task.start)-1.7,float(task.from_y)+0.1,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._stream_world(phase._player.position.x,true)
		flush(phase)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		await ticks(15)
		phase._update_bridge_hint()
		var label := "fase_%02d_%s" % [order,task.task_kind]
		await snap(phase,out,label+"_antes")
		phase._hud._bridge_task.pressed.emit()
		await ticks(60)
		if task.task_kind!="gate":
			# Inspeção no interior da passagem, usando a câmera e as peças verdadeiras.
			phase._player.position=Vector3(float(task.start)+4.0,lerpf(float(task.from_y),float(task.to_y),4.0/float(task.width))+0.10,0)
			phase._player.velocity=Vector3.ZERO
			phase._player.set_physics_process(true)
			await ticks(12)
		await snap(phase,out,label+"_depois")
		phase.free()
		current_scene=null
		paused=false
		await ticks(3)
	FileAccess.open(out+"/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit(0 if records.all(func(r: Dictionary) -> bool:return r.error==0) else 1)
