extends SceneTree
## Lança real, colisões reais, escudo/cápsula reais. Aproximação por fixture explícita.
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks:=0
var failures:=0
var phase: Node3D
var player: CharacterBody3D
var guard: CharacterBody3D
var supply: Dictionary
var output:=""
var bake_defense:=false
func bake_lesson() -> void:
	paused=true
	phase._hud._root.hide()
	phase._touch_pad.hide()
	var focus: Vector3=player.position+Vector3(2.5,1.0,0)
	phase._camera.size=3.5
	phase._camera.position=focus+Vector3(0,0.8,14)
	phase._camera.look_at(focus)
	phase._scenery.follow(phase._camera,player.position.x)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://assets/desert/tutorial/source")
	picture.save_png("res://assets/desert/tutorial/source/defense.png")
	picture.resize(960,360,Image.INTERPOLATE_LANCZOS)
	picture.convert(Image.FORMAT_RGB8)
	picture.generate_mipmaps()
	var error:=ResourceSaver.save(ImageTexture.create_from_image(picture),"res://assets/desert/tutorial/defense.res",ResourceSaver.FLAG_COMPRESS)
	print("DEFENSE_LESSON save=",error)
	paused=false
func snap(label: String) -> void:
	if output.is_empty():return
	var before:=paused
	paused=true
	player._model.show()
	for i in 3:phase._follow_camera(1.0)
	phase._scenery.follow(phase._camera,player.position.x)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.94)
	paused=before
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
	for i in n:await physics_frame
func make_phase(collect:=true) -> void:
	for action in ["move_left","move_right","jump","crouch","defend"]:
		if InputMap.has_action(action):Input.action_release(action)
	phase=load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	player=phase._player
	supply=phase._phase.pickups.filter(func(p: Dictionary) -> bool:return p.kind=="defense")[0]
	var spec: Dictionary=phase._phase.enemies.filter(func(e: Dictionary) -> bool:return e.get("spear_tutorial",false))[0]
	guard=phase._enemy_live[str(spec.id)]
	for enemy in phase._troops.get_children():
		if enemy!=guard:phase._retire_enemy(enemy)
	player.position=Vector3(float(supply.pos[0])-(0.0 if collect else 1.2),float(supply.pos[1])+0.04,0)
	player.velocity=Vector3.ZERO
	player.facing=1.0
	if collect:
		for i in 60:
			await physics_frame
			if player.defense_charges>0:break
func clear() -> void:
	paused=false
	if is_instance_valid(phase):phase.free()
	current_scene=null
	for action in ["move_left","move_right","jump","crouch","defend"]:Input.action_release(action)
	await process_frame
func wait_shot() -> bool:
	for i in 180:
		await physics_frame
		if is_instance_valid(guard._spear_guard._shot) and not guard._spear_guard._shot._done:return true
	return false
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	bake_defense="--bake-defense" in args
	if bake_defense:root.size=Vector2i(1280,480)
	if args.size()>=2:
		output=args[0]
		DirAccess.make_dir_recursive_absolute(output)
		var size:=args[1].split("x")
		root.size=Vector2i(int(size[0]),int(size[1]))
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	for order in range(1,11):
		var data:=Layout.build(order)
		var spears: Array=data.enemies.filter(func(e: Dictionary) -> bool:return e.get("spear",false))
		check(not spears.is_empty() if order in [1,6,8] else spears.is_empty(),"fase%02d: distribuição pontual dos lanceiros" % order)
	await make_phase(false)
	var start: Vector3=guard.position
	await ticks(150)
	check(guard._spear_guard.throws==0 and not guard.persistent_follow and guard.position.distance_to(start)<0.03,"primeiro soldado espera a recarga, sem arremessar nem perseguir")
	player.position=Vector3(float(supply.pos[0]),float(supply.pos[1])+0.04,0)
	for i in 60:
		await physics_frame
		if player.defense_charges>0:break
	check(player.defense_charges==1 and guard._spear_guard.enabled,"coleta real habilita escudo e encontro")
	var blocked: Array=[0]
	player.blocked.connect(func() -> void:blocked[0]+=1)
	Input.action_press("defend")
	await ticks(2)
	Input.action_release("defend")
	await ticks(8)
	await snap("01_preparacao_escudo")
	var shot_captured:=false
	for i in 180:
		await physics_frame
		if bake_defense and is_instance_valid(guard._spear_guard._shot) and not guard._spear_guard._shot._done:
			var tip: Vector3=guard._spear_guard._shot.global_position+guard._spear_guard._shot._direction*0.94
			if absf(tip.x-player.position.x)>0.74 and absf(tip.x-player.position.x)<1.45:
				await bake_lesson()
				await clear()
				quit(0 if failures==0 else 1)
				return
		if not shot_captured and is_instance_valid(guard._spear_guard._shot) and guard._spear_guard._shot._age<0.10 and not guard._spear_guard._shot._done:
			shot_captured=true
			await snap("02_lanca_no_ar")
		if guard._spear_guard.pursuit_allowed:break
	check(blocked[0]==1 and player.health==3 and player.defense_charges==0,"escudo real bloqueia a lança, consome uma carga e preserva três vidas")
	check(guard._spear_guard.pursuit_allowed and guard.persistent_follow,"impacto no escudo libera perseguição")
	await snap("03_impacto_no_escudo")
	if bake_defense:
		await bake_lesson()
		await clear()
		quit(0 if failures==0 else 1)
		return
	await ticks(8)
	check(guard.velocity.x<0.0,"soldado corre na direção do jogador após o impacto")
	await snap("04_perseguicao_apos_impacto")
	await clear()
	await make_phase()
	Input.action_press("crouch")
	check(await wait_shot(),"cacto usa o ataque existente para arremessar")
	await ticks(12)
	await snap("05_desvio_agachado")
	await ticks(360)
	check(player.health==3 and guard._spear_guard.throws>=2,"agachar desvia; erro permite outro arremesso")
	check(not guard._spear_guard.pursuit_allowed and not guard.persistent_follow and absf(guard.position.x-start.x)<0.03,"errar a lança não libera perseguição")
	await clear()
	await make_phase()
	check(await wait_shot(),"lança ativa para o salto")
	for i in 120:
		await physics_frame
		var shot: Node3D=guard._spear_guard._shot
		if absf(shot.position.x-player.position.x)<4.0:break
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
	await ticks(10)
	await snap("06_desvio_pulo")
	await ticks(85)
	check(player.health==3 and not guard._spear_guard.pursuit_allowed,"pulo real deixa a lança passar sem dano nem perseguição")
	await clear()
	await make_phase()
	for i in 180:
		await physics_frame
		if player.health<3:break
	check(player.health==2 and not player.is_dead,"lança sem defesa remove exatamente uma vida")
	await snap("07_dano_uma_vida")
	check(guard._spear_guard.pursuit_allowed,"acerto no corpo libera perseguição")
	await clear()
	await make_phase()
	player.health=1
	for i in 180:
		await physics_frame
		if player.is_dead:break
	check(player.health==0 and player.is_dead,"última vida atingida pela lança causa morte real")
	await snap("08_ultima_vida")
	for i in 180:
		await process_frame
		if phase._session.opened:break
	check(phase._session.opened,"morte apresenta a derrota existente")
	var restart: Button
	for button in phase._session._column.get_children():
		if button is Button and "Recomeçar" in button.text:restart=button
	check(is_instance_valid(restart),"derrota oferece recomeçar")
	if is_instance_valid(restart):
		restart.pressed.emit()
		await ticks(5)
		check(not player.is_dead and player.health==3 and player.defense_charges==0,"recomeçar restaura vida e a regra de começar sem defesa: dead=%s hp=%s defense=%s checkpoint=%s pos=%s" % [player.is_dead,player.health,player.defense_charges,phase._checkpoint_index,player.position])
	await clear()
	await make_phase()
	check(await wait_shot(),"lança ativa para colisão com cenário")
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(0.04,3.0,2.0)
	shape.shape=box
	wall.add_child(shape)
	phase.add_child(wall)
	wall.position=player.position+Vector3(3,1.0,0)
	await ticks(100)
	check(player.health==3 and not guard._spear_guard.pursuit_allowed,"parede fina intercepta a lança sem dano e sem liberar perseguição")
	await clear()
	await make_phase()
	for i in 50:
		await physics_frame
		if guard._spear_guard.state=="windup":break
	guard.crystallize(0.6)
	var throws: int=guard._spear_guard.throws
	await ticks(20)
	check(guard._spear_guard.throws==throws and guard.crystallized_left>0,"âmbar pausa o arremesso junto com o soldado")
	await clear()
	check(get_nodes_in_group("campaign_spears").is_empty(),"sair/recomeçar limpa lanças e callbacks")
	print("SPEAR_ENCOUNTERS checks=%d failures=%d" % [checks,failures])
	if not output.is_empty():FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"fixture_teleport":true,"physical_device":false,"capture_freezes_frame":true},"\t"))
	quit(1 if failures else 0)
