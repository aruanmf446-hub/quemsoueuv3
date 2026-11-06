extends SceneTree
## Fixture explícita de apresentação. Usa comando Âmbar real, alvos reais e efeitos reais.
var checks:=0
var failures:=0
var output:=""
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
	for i in n:await physics_frame
func shot(label: String) -> void:
	if output.is_empty():return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.93)==OK,label+": captura real")
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args:=OS.get_cmdline_user_args()
	if args.size()>=2:
		output=args[0]
		DirAccess.make_dir_recursive_absolute(output)
		var size:=args[1].split("x")
		root.size=Vector2i(int(size[0]),int(size[1]))
	var phase: Node3D=load("res://scenes/desert/phase_03.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	phase.set_physics_process(false)
	var floor: Dictionary=phase._phase.surfaces[6]
	var hero: Node3D=phase._player
	var x:=float(floor.left)+13.0
	var y:=float(floor.height)
	hero.position=Vector3(x,y+0.03,0)
	hero.velocity=Vector3.ZERO
	hero.facing=1.0
	hero.set_physics_process(false)
	phase._stream_world(x,true)
	for i in 2400:
		if phase._build_queue.is_empty():break
		phase._process(0)
	for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	var targets: Array[Node3D]=[]
	for offset: float in [-2.8,3.0,-10.0]:
		var target: Node3D=phase._create_enemy()
		target.reparent(phase._troops)
		target.setup(phase._enemy_catalog.cactus,{"patrol":[x-15.0,x+6.0]})
		target.position=Vector3(x+offset,y+0.03,0)
		target.add_to_group("enemies")
		target.set_physics_process(false)
		targets.append(target)
	await ticks(8)
	var cactus: Node3D=targets[0]
	cactus._model.play_animation("base",true)
	cactus._model._anim_player.seek(0.28,true)
	phase._follow_camera(1.0)
	phase._scenery.follow(phase._camera,x)
	await shot("01_antes")
	hero.restore_charge("amber")
	check(hero.use_ability("amber") and hero.charges("amber")==0,"comando real consome uma carga")
	check(is_equal_approx(cactus.crystallized_left,3.5) and targets[1].crystallized_left==0 and targets[2].crystallized_left==0,"mesmos 3,5 segundos, somente atrás, até 8m")
	cactus.set_physics_process(true)
	var point: Vector3=cactus.position
	await ticks(4)
	await shot("02_formando")
	await ticks(14)
	check(cactus.position.is_equal_approx(point) and cactus._model._anim_player.speed_scale==0.0,"posição e pose imobilizadas")
	check(cactus._crystal._shell.mesh.get_surface_count()==1 and cactus._crystal._chips.multimesh.instance_count==12,"uma superfície compartilhada e doze lascas, sem luzes novas")
	await shot("03_congelado_no_jogo")
	# Aproximação somente para avaliação do acabamento; câmera de gameplay acima preservada.
	var cam: Camera3D=phase._camera
	cam.size=3.2
	var focus: Vector3=cactus.position+Vector3(1.2,0.95,0)
	cam.position=focus+Vector3(0,0.8,14)
	cam.look_at(focus)
	phase._scenery.follow(cam,x)
	phase._hud._root.hide()
	phase._touch_pad.hide()
	await ticks(5)
	await shot("04_detalhe")
	# Reaplicar não acumula casulos nem materiais.
	var same: Node3D=cactus._crystal
	var previous: float=cactus.crystallized_left
	var previous_age: float=same._age
	cactus.crystallize(0.18)
	check(cactus._crystal==same and cactus.crystallized_left==previous and same._age==previous_age,"reaplicação conserva maior duração e reutiliza efeito sem piscar")
	cactus._model.flash(Color.WHITE)
	for i in 120:
		if cactus._model._flash_left<=0.0:break
		await process_frame
	check(cactus._model._meshes.all(func(mesh: MeshInstance3D) -> bool:return mesh.material_overlay==same._frost),"flash de dano restaura a cristalização, sem apagar nem substituir texturas")
	while cactus.crystallized_left>0.13:await physics_frame
	await shot("05_fissuras")
	while cactus.crystallized_left>0.0:await physics_frame
	cactus.set_physics_process(false)
	check(cactus._model._anim_player.speed_scale==1.0,"animação liberada ao final da duração original")
	check(cactus._model._meshes.all(func(mesh: MeshInstance3D) -> bool:return mesh.material_overlay==null),"descongelar restaura todos os materiais originais")
	await ticks(7)
	await shot("06_quebrando")
	check(cactus._crystal.top_level,"lascas ficam no local da quebra, sem seguir o Cactus")
	await ticks(30)
	check(not same.visible and not same.is_processing(),"efeito finaliza e para de processar")
	cactus.crystallize(0.16)
	check(cactus._crystal==same and not same.top_level and same.transform==Transform3D.IDENTITY,"nova ativação reutiliza e reposiciona corretamente")
	cactus.set_physics_process(true)
	await ticks(14)
	cactus.setup(phase._enemy_catalog.cactus,{"patrol":[x-5.0,x+5.0]})
	await process_frame
	check(cactus._crystal==null and cactus.crystallized_left==0 and not is_instance_valid(same),"reciclagem limpa o efeito e a imobilização")
	cactus.crystallize(1.0)
	var dying: Node3D=cactus._crystal
	cactus._die()
	await process_frame
	check(not is_instance_valid(dying) and cactus.crystallized_left==0,"morte limpa o cristal")
	phase.free()
	print("AMBER_FREEZE checks=%d failures=%d" % [checks,failures])
	if not output.is_empty():FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"fixture_teleport":true,"detail_camera_fixture":true,"physical_device":false},"\t"))
	quit(1 if failures else 0)
