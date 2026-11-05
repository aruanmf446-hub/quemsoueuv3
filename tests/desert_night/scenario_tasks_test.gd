extends SceneTree
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+text)
func frames(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var titles:={}
	for order in range(1,11):
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		await frames(5)
		phase.set_physics_process(false)
		check(phase._phase.tasks.size()==(1 if order==10 else 2),"fase%d: quantidade de tarefas contextualizadas" % order)
		check(not phase._phase.platforms.any(func(p: Dictionary) -> bool:return p.get("parkour_step",false)),"fase%d: pilhas rejeitadas removidas" % order)
		check(phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false) and float(p.size[0])>5 and float(p.size[1])<=0.21).size()==(0 if order==2 else (4 if order==10 else 8)),"fase%d: tetos próprios e obstáculos apenas nas fases adequadas" % order)
		for task: Dictionary in phase._phase.tasks:
			check(not titles.has(str(task.task_text)),"tarefa própria: "+str(task.task_text))
			titles[str(task.task_text)]=true
			var player: Node3D=phase._player
			player.position=Vector3(float(task.start)-1.7,float(task.from_y)+0.1,0)
			player.velocity=Vector3.ZERO
			player.set_physics_process(true)
			player._invulnerable=999
			phase._stream_world(player.position.x,true)
			for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
			await frames(15)
			player.defense_charges=0
			player.attack_charges=0
			phase._update_bridge_hint()
			check(phase._hud._bridge_task.visible and phase._hud._bridge_task.tooltip_text.begins_with(str(task.task_text)),"aviso acessível antes de "+str(task.id))
			var device: Node3D
			for node in get_nodes_in_group("earth_bridges"):
				if str(node.hole.id)==str(task.id):device=node
			check(device!=null,"mecanismo instanciado uma vez: "+str(task.id))
			var event:=InputEventKey.new()
			event.physical_keycode=KEY_F
			event.pressed=true
			Input.parse_input_event(event)
			await frames(60)
			check(device.raised and not device._shape.disabled and player.is_physics_processing(),"interação física conclui e devolve comandos: "+str(task.id))
			check(player.defense_charges==0 and player.attack_charges==0,"sem custo de poder: "+str(task.id))
			var start_x: float=player.position.x
			Input.action_press("move_right")
			for i in 600:
				await physics_frame
				if player.position.x>float(task.end)+0.8:break
			Input.action_release("move_right")
			check(player.position.x>float(task.end)+0.5 and player.is_on_floor(),"passagem real após tarefa: "+str(task.id))
			Input.action_press("move_left")
			for i in 600:
				await physics_frame
				if player.position.x<start_x+0.1:break
			Input.action_release("move_left")
			check(player.position.x<start_x+0.2 and player.is_on_floor(),"retorno após tarefa: "+str(task.id))
		phase.free()
		current_scene=null
		await frames(3)
		check(get_nodes_in_group("earth_bridges").is_empty(),"fase%d: mecanismos limpos ao sair" % order)
	# Cactus segue por cima de um obstáculo real, sem teleporte durante a perseguição.
	var phase: Node3D=load("res://scenes/desert/phase_03.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(8)
	phase.set_physics_process(false)
	var route: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false))[0]
	phase._player.position=Vector3(float(route.span_end)+2,float(route.surface_top)+0.1,0)
	phase._stream_world(float(route.pos[0]),true)
	for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	phase._player._invulnerable=999
	await frames(12)
	phase._player.set_physics_process(false)
	phase._spawn_enemy(phase._troops,{"id":"task.qa.pursuit","pos":[float(route.span_start)-2,float(route.surface_top)+0.1,0],"patrol":[-999,999],"troop":true})
	var guard: Node3D=phase._troops.get_child(0)
	var used_top:=false
	for i in 240:
		await physics_frame
		if guard.is_on_floor() and absf(guard.position.y-(float(route.pos[1])+0.1))<0.1:used_top=true
	check(guard._challenger and used_top and guard.position.x>float(route.span_end),"cacto persegue saltando e correndo sobre o obstáculo")
	phase._retire_enemy(guard)
	phase._spawn_enemy(phase._troops,{"id":"task.qa.elite","pos":[float(route.span_end)+8,float(route.surface_top)+0.1,0],"patrol":[-999,999],"elite":true})
	guard=phase._troops.get_child(0)
	check(guard.health==3 and guard._elite,"guarda resistente mantém perfil próprio")
	guard.take_damage(2)
	check(guard.health==1,"guarda resiste ao primeiro soco, sem invulnerabilidade artificial")
	guard.take_damage(2)
	check(guard.health<=0,"segundo soco derrota o guarda")
	phase.free()
	current_scene=null
	await frames(3)
	print("SCENARIO_TASKS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
