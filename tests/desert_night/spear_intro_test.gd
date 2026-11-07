extends SceneTree
## Migração da explicação de defesa: save antigo não esconde o encontro novo.
const Lesson=preload("res://scripts/desert/t15d/first_use_tutorial.gd")
var checks:=0
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func frames(n: int) -> void:
	for i in n:await process_frame
func collect(phase: Node3D) -> void:
	var item: Dictionary=phase._phase.pickups.filter(func(p: Dictionary) -> bool:return p.kind=="defense")[0]
	phase._player.position=Vector3(float(item.pos[0]),float(item.pos[1])+0.04,0)
	phase._player.velocity=Vector3.ZERO
	for i in 120:
		await process_frame
		if phase._player.defense_charges>0:break
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>=2:
		output=args[0]
		DirAccess.make_dir_recursive_absolute(output)
		var size:=args[1].split("x")
		root.size=Vector2i(int(size[0]),int(size[1]))
	var old:=ConfigFile.new()
	old.set_value("guest","attack",true)
	old.set_value("guest","defense",true)
	old.save(Lesson.SAVE_PATH)
	var phase: Node3D=load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(5)
	check(not paused and not phase._first_use.active,"save antigo não repete ataque")
	await collect(phase)
	await frames(5)
	check(paused and phase._first_use.active and phase._first_use.kind=="defense","recarga real apresenta a explicação nova mesmo com defesa antiga ensinada")
	check(phase._first_use._illustration.visible and phase._first_use._illustration.texture!=null and "lança" in phase._first_use._body.text,"ilustração real e texto explicam a lança")
	var panel: Rect2=phase._first_use._panel.get_global_rect()
	check(panel.position.y>=0 and panel.end.y<=root.get_visible_rect().size.y and panel.position.x>=0 and panel.end.x<=root.get_visible_rect().size.x,"explicação e botão cabem na janela")
	var guards: Array=phase._troops.get_children().filter(func(n: Node) -> bool:return is_instance_valid(n._spear_guard) and n._spear_guard.active)
	var at: Vector3=phase._player.position
	Input.action_press("defend")
	Input.action_press("move_right")
	await frames(8)
	check(phase._player.position==at and phase._player.defense_charges==1 and guards[0]._spear_guard.throws==0,"durante explicação, movimento, arremesso e carga ficam pausados")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(output+"/primeira_defesa_lanca.jpg",0.94)
	phase._first_use._continue.pressed.emit()
	await frames(3)
	check(not paused and not Input.is_action_pressed("defend") and not Input.is_action_pressed("move_right"),"continuar libera jogo sem comando preso")
	var saved:=ConfigFile.new()
	saved.load(Lesson.SAVE_PATH)
	check(saved.get_value("guest","defense",false) and saved.get_value("guest","defense_spear_v1",false),"nova lição salva sem apagar o registro antigo")
	phase.free()
	await frames(3)
	phase=load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await collect(phase)
	await frames(4)
	check(not paused and not phase._first_use.active,"lição nova não se repete depois de confirmada")
	phase.free()
	await frames(6)
	print("SPEAR_INTRO checks=%d failures=%d" % [checks,failures])
	if not output.is_empty():FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_device":false,"fixture_teleport":true},"\t"))
	await preload("res://tests/common/audio_cleanup.gd").finish(self)
	quit(1 if failures else 0)
