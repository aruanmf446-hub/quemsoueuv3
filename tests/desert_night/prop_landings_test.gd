extends SceneTree
## Aproximação por fixture; saltos, corrida e aterrissagens usam física e comandos reais.
const Landings=preload("res://scripts/desert/t15d/prop_landings.gd")
var checks:=0
var failures:=0
var output:=""
var phase: Node3D
var player: CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func ticks(n: int) -> void:
	for i in n:await physics_frame
func flush() -> void:
	for i in 2400:
		if phase._build_queue.is_empty():break
		phase._process(0)
func snap(label: String) -> void:
	if output.is_empty():return
	player.set_physics_process(false)
	player._model.show()
	phase._follow_camera(1.0)
	phase._scenery.follow(phase._camera,player.position.x)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(output+"/"+label+".jpg",0.93)
	player.set_physics_process(true)
func place(x: float,y: float) -> void:
	for action in ["move_left","move_right","jump","crouch"]:Input.action_release(action)
	player.position=Vector3(x,y+0.04,0)
	player.velocity=Vector3.ZERO
	player._invulnerable=999
	await ticks(12)
func jump() -> void:
	Input.action_press("jump")
	await ticks(2)
	Input.action_release("jump")
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args:=OS.get_cmdline_user_args()
	if args.size()>=2:
		output=args[0]
		DirAccess.make_dir_recursive_absolute(output)
		var size:=args[1].split("x")
		root.size=Vector2i(int(size[0]),int(size[1]))
	phase=load("res://scenes/desert/phase_03.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	phase.set_physics_process(false)
	player=phase._player
	flush()
	for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	var roofs:=get_nodes_in_group(Landings.GROUP).filter(func(n: Node) -> bool:return n.get_meta("prop_asset","")=="capital_market_stall" and n.get_meta("prop_ledge",-1)==0)
	check(not roofs.is_empty(),"tendas existentes recebem apoio na lona")
	if roofs.is_empty():quit(1);return
	var roof: StaticBody3D=roofs[0]
	var span: Vector2=roof.get_meta("landing_span")
	var x: float=roof.position.x
	var base: float=roof.get_meta("source_floor")
	var top: float=roof.get_meta("one_way_top")
	check(top-base>2.0 and top-base<3.3,"lona alcançável com os saltos aprovados: %.2fm" % (top-base))
	await place(x,base)
	check(player.is_on_floor(),"parte do piso real abaixo da tenda")
	await snap("01_debaixo_da_tenda")
	# Salto único: cabeça atravessa a lona, pés não alcançam; não gruda por baixo.
	await jump()
	var ceiling:=false
	var peak:=player.position.y
	for i in 95:
		await physics_frame
		peak=maxf(peak,player.position.y)
		ceiling=ceiling or player.is_on_ceiling()
	check(not ceiling and peak>base+1.6 and peak<top-0.1,"salto insuficiente não bate a cabeça nem se prende à lona")
	check(player.is_on_floor() and player.position.y<top-0.5,"desce normalmente para o balcão, sem subir por teleporte")
	await place(x,base)
	await jump()
	await ticks(18)
	await jump()
	ceiling=false
	var crossed:=false
	var landed:=false
	for i in 160:
		await physics_frame
		ceiling=ceiling or player.is_on_ceiling()
		crossed=crossed or player.position.y>top+0.04
		if crossed and player.is_on_floor() and absf(player.position.y-top)<0.04:
			landed=true
			break
	check(crossed and not ceiling,"salto duplo atravessa a lona de baixo para cima")
	check(landed and player.jumps_used==0,"aterrissa de verdade na lona e recupera os saltos")
	await ticks(15)
	await snap("02_em_cima_da_lona")
	var before:=player.position.x
	Input.action_press("move_right")
	await ticks(8)
	Input.action_release("move_right")
	await ticks(5)
	check(player.position.x>before+0.15 and absf(player.position.y-top)<0.04,"corre apoiado em cima da tenda")
	await jump()
	await ticks(8)
	check(player.position.y>top+0.5,"consegue saltar novamente de cima da lona")
	await snap("03_salto_a_partir_da_lona")
	await ticks(90)
	Input.action_press("move_left")
	for i in 100:
		await physics_frame
		if player.position.x<span.x-0.6:break
	Input.action_release("move_left")
	await ticks(15)
	check(player.position.x<span.x-0.5 and player.position.y<top-0.2 and not player.is_dead,"sai pela borda e cai sem travar")
	# Uma passarela antiga também deve deixar subir por baixo.
	var routes:=get_nodes_in_group(Landings.GROUP).filter(func(n: Node) -> bool:return n.get_meta("parkour_route",false))
	check(not routes.is_empty(),"obstáculos de parkour existentes usam a mesma passagem por baixo")
	var old: StaticBody3D=routes[0]
	var old_top: float=old.get_meta("one_way_top")
	await place(old.position.x,old_top-1.10)
	Input.action_press("crouch")
	await ticks(3)
	Input.action_release("crouch")
	await ticks(3)
	check(not player.is_crouching,"levanta após agachar por baixo do balcão, sem ficar preso")
	await jump()
	var old_ceiling:=false
	var old_crossed:=false
	for i in 95:
		await physics_frame
		old_ceiling=old_ceiling or player.is_on_ceiling()
		old_crossed=old_crossed or player.position.y>old_top+0.05
	check(old_crossed and not old_ceiling,"balcão de parkour atravessável por baixo, mantendo apoio por cima")
	var crates:=get_nodes_in_group(Landings.GROUP).filter(func(n: Node) -> bool:return n.get_meta("prop_asset","")=="city_supplies_context")
	check(not crates.is_empty(),"caixas do cenário também oferecem apoio")
	if not crates.is_empty():
		var crate: StaticBody3D=crates[0]
		var crate_top: float=crate.get_meta("one_way_top")
		player.position=Vector3(crate.position.x,crate_top+0.4,0)
		player.velocity=Vector3.ZERO
		await ticks(45)
		check(player.is_on_floor() and absf(player.position.y-crate_top)<0.04,"pisa de verdade na caixa, sem flutuar")
		await snap("04_em_cima_da_caixa")
	phase.free()
	await process_frame
	check(get_nodes_in_group(Landings.GROUP).is_empty(),"sair da fase remove todos os apoios")
	# Geometria/ownership em todas as fases: nunca ocupa vazios ou vira fundo distante.
	var orders: Array=[] if "--captures-only" in args else range(1,11)
	var tested_assets: Dictionary={}
	for order in orders:
		phase=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		phase.set_physics_process(false)
		phase._player.set_physics_process(false)
		for at in [12.0,350.0,700.0,1100.0,12.0]:
			phase._player.position.x=at
			phase._player.position.y=-30.0
			Landings.sync(phase._player)
			phase._stream_world(at,true)
			flush()
			await process_frame
			var exceptions: Array=phase._player.get_collision_exceptions()
			check(exceptions.all(func(body: Node) -> bool:return is_instance_valid(body)) and exceptions.size()<=get_nodes_in_group(Landings.GROUP).size(),"fase%02d x%.0f: streaming limpa referências físicas antigas" % [order,at])
			var valid:=true
			var ids: Dictionary={}
			for body: StaticBody3D in get_nodes_in_group(Landings.GROUP):
				if not body.has_meta("prop_asset"):continue
				var art: Sprite3D=body.get_node(body.get_meta("prop_art"))
				var key:=str(art.get_instance_id())+":"+str(body.get_meta("prop_ledge"))
				if ids.has(key) or art.position.z < -8.0:valid=false
				ids[key]=true
				var extent: Vector2=body.get_meta("landing_span")
				var floor: Dictionary=preload("res://scripts/desert/t15d/campaign_layout.gd").floor_at(phase._phase,(extent.x+extent.y)*0.5)
				if floor.is_empty() or floor.get("task_void",false) or extent.x<floor.left or extent.y>floor.right:valid=false
			check(valid,"fase%02d x%.0f: apoios únicos, sobre piso existente, sem fechar lacunas" % [order,at])
			for body: StaticBody3D in get_nodes_in_group(Landings.GROUP):
				var asset:=str(body.get_meta("prop_asset",""))
				if asset.is_empty() or tested_assets.has(asset):continue
				tested_assets[asset]=true
				var actor: CharacterBody3D=phase._player
				var ledge_top: float=body.get_meta("one_way_top")
				actor.position=Vector3(body.position.x,ledge_top+0.4,0)
				actor.velocity=Vector3.ZERO
				actor._invulnerable=999
				actor.set_physics_process(true)
				await ticks(45)
				check(actor.is_on_floor() and absf(actor.position.y-ledge_top)<0.04,asset+": aterrissagem real por cima")
				actor.set_physics_process(false)
		phase.free()
		await process_frame
		check(get_nodes_in_group(Landings.GROUP).is_empty(),"fase%02d descarrega apoios sem resíduos" % order)
	print("PROP_LANDINGS checks=%d failures=%d" % [checks,failures])
	if not output.is_empty():FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"fixture_teleport":true,"physical_device":false},"\t"))
	quit(1 if failures else 0)
