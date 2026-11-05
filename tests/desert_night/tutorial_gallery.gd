extends SceneTree
const Tutorial=preload("res://scripts/desert/t15d/first_use_tutorial.gd")
var phase: Node3D
var out: String
var records: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func ticks(n: int) -> void:
	for i in n:await physics_frame
func snap(name: String) -> void:
	phase._player._model.visible=true
	await frames(3)
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(out+"/"+name+".png")
	records.append({"name":name,"error":error,"fixture_teleport":true,"paused":paused,"attack":phase._player.attack_charges,"defense":phase._player.defense_charges})
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	out=args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var size:=args[1].split("x")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(int(size[0]),int(size[1]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.SAVE_PATH))
	phase=load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(10)
	await snap("primeiro_ataque")
	phase._first_use._continue.pressed.emit()
	await ticks(4)
	for item in get_nodes_in_group("campaign_pickups"):
		if phase.is_ancestor_of(item) and item.kind=="defense":
			phase._player.position=item.global_position+Vector3.UP*0.05
			phase._player.velocity=Vector3.ZERO
			phase._player._invulnerable=999
			break
	await ticks(12)
	await snap("primeira_defesa")
	phase._first_use._continue.pressed.emit()
	await ticks(3)
	var task: Dictionary=phase._phase.tasks[0]
	phase._player.position=Vector3(float(task.start)-2,float(task.from_y)+0.1,0)
	phase._player.velocity=Vector3.ZERO
	phase._stream_world(phase._player.position.x,true)
	for i in 1500:
		if phase._build_queue.is_empty():break
		phase._process(0)
	for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	await ticks(12)
	phase._follow_camera(1)
	await snap("primeira_task")
	phase._first_use._continue.pressed.emit()
	await ticks(3)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	phase._hud._toast.hide()
	phase._player._model.visible=true
	await snap("botao_task_acima_ataque")
	FileAccess.open(out+"/captures.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	phase.free()
	current_scene=null
	await frames(3)
	quit(0 if records.size()==4 and records.all(func(r: Dictionary) -> bool:return r.error==0) else 1)
