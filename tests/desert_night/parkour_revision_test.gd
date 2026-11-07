extends SceneTree
## Inspeção física focada; reposicionamento é fixture, caminhada usa entradas reais.
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+text)
func frames(n: int) -> void:
	for i in n: await physics_frame
func ray(phase: Node3D,x: float,y: float) -> Dictionary:
	return phase.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,y+1,0),Vector3(x,y-2,0),1))
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var tasks := 0
	var profiles: Dictionary={}
	for order in range(1,11):
		var stage := Layout.build(order)
		tasks += stage.tasks.size()
		if order == 10: continue
		var heights: Array = stage.surfaces.map(func(s: Dictionary) -> float:return float(s.height))
		var relief: float=heights.max()-heights.min()
		var clusters: Dictionary={}
		for platform: Dictionary in stage.platforms:
			if platform.get("parkour_route",false):clusters[platform.module]=true
		check(relief>=1.7 or (relief>=0.6 and clusters.size()>=6),"fase%d: desníveis por terreno ou sequências de parkour" % order)
		var signature: Array=[]
		for i in 12:signature.append(snappedf(float(heights[i])-float(heights[0]),0.01))
		profiles[str(signature)]=true
		check(stage.holes.all(func(g: Dictionary) -> bool:return g.get("requires_task",false) or (absf(float(g.from_y)-float(g.to_y))<0.56 and float(g.width)<=3.2)),"fase%d: retorno por salto continua alcançável" % order)
		check(clusters.size()==0 if order==2 else clusters.size()>=6,"fase%d: telhados reais ou ao menos seis conjuntos de parkour, sem invadir Tasks" % order)
		var controls_on_floor:=true
		for task: Dictionary in stage.tasks:
			var device:=preload("res://scripts/desert/t15d/earth_bridge.gd").new()
			device.configure(task)
			for step in task.actions.size():
				for right in [false,true]:
					var point: Vector3=device.action_point(step,right)
					var floor:=Layout.floor_at(stage,point.x)
					controls_on_floor=controls_on_floor and not floor.is_empty() and not floor.get("task_void",false) and absf(float(floor.get("height",-999))-point.y)<0.01
			device.free()
		check(controls_on_floor,"fase%d: pontos das Tasks ficam apoiados nas duas margens" % order)
		check(stage.tasks.all(func(t: Dictionary) -> bool:return t.actions.size()==(1 if order==1 and t.task_kind=="gate" else 2)),"fase%d: etapas de mecanismo próprias da região" % order)
		check(stage.holes.filter(func(g: Dictionary) -> bool:return g.get("crumble_bridge",false)).size()==2,"fase%d: duas pontes frágeis" % order)
	check(tasks==19,"dezenove tarefas de cenário, sem habilidades permanentes")
	check(profiles.size()==9,"nove perfis diferentes de subida/descida, sem repetir o mesmo percurso")
	var phase: Node3D = load("res://scenes/desert/phase_04.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(10)
	phase.set_physics_process(false)
	var hole: Dictionary = phase._phase.tasks.filter(func(g: Dictionary) -> bool:return g.task_kind=="bridge")[0]
	var player: Node3D = phase._player
	player.position = Vector3(float(hole.start)-4.8,float(hole.from_y)+0.1,0)
	player.velocity = Vector3.ZERO
	phase._stream_world(player.position.x,true)
	for enemy in phase._troops.get_children(): phase._retire_enemy(enemy)
	player._invulnerable = 999
	await frames(15)
	phase._update_bridge_hint()
	check(phase._hud._bridge_task.visible,"tarefa aparece apenas perto da passagem")
	check(ray(phase,(float(hole.start)+float(hole.end))*0.5,float(hole.from_y)).is_empty(),"vão realmente aberto antes da montagem")
	player.attack_charges=0
	player.defense_charges=0
	var powers: Dictionary=player.abilities.duplicate()
	var bridge: Node3D=get_nodes_in_group("earth_bridges")[0]
	phase._hud._bridge_task.pressed.emit()
	check(not bridge.raised and int(phase._task_steps.get(str(hole.id),0))==1,"primeiro mecanismo libera a segunda etapa, sem montar a ponte")
	player.position.x=float(hole.start)-1.6
	player.velocity=Vector3.ZERO
	await frames(3)
	phase._update_bridge_hint()
	phase._hud._bridge_task.pressed.emit()
	check(bridge.raised and bridge._shape.disabled,"montagem começa girando a peça, sem colisão antecipada")
	var assembly_x: float=player.position.x
	Input.action_press("move_right")
	await frames(30)
	check(absf(player.position.x-assembly_x)<0.01,"segurar avanço durante a montagem não derruba no vazio")
	Input.action_release("move_right")
	await frames(60)
	check(not bridge._shape.disabled and not ray(phase,(float(hole.start)+float(hole.end))*0.5,float(hole.from_y)).is_empty(),"ponte montada tem piso real")
	check(player.defense_charges==0 and player.attack_charges==0 and player.abilities==powers,"tarefa não usa poderes nem altera recursos")
	check(not phase._hud._bridge_task.visible,"botão contextual some após concluir")
	Input.action_press("move_right")
	for frame in 600:
		await physics_frame
		if player.position.x>float(hole.end)+1: break
	Input.action_release("move_right")
	check(player.position.x>float(hole.end)+0.4 and player.is_on_floor(),"ponte atravessável andando para a direita")
	Input.action_press("move_left")
	for frame in 600:
		await physics_frame
		if player.position.x<float(hole.start)-1: break
	Input.action_release("move_left")
	check(player.position.x<float(hole.start)-0.4 and player.is_on_floor(),"ponte atravessável andando para a esquerda")
	var id := str(hole.id)
	phase._stream_world(player.position.x+700,true)
	phase._stream_world(player.position.x,true)
	await frames(4)
	check(get_nodes_in_group("earth_bridges").size()==1 and get_nodes_in_group("earth_bridges")[0].raised and phase._raised_bridges.has(id),"descarregar e voltar preserva ponte sem duplicar")
	var fragile: Dictionary=phase._phase.holes.filter(func(g: Dictionary) -> bool:return g.get("crumble_bridge",false))[0]
	var center := (float(fragile.start)+float(fragile.end))*0.5
	phase._stream_world(center,true)
	var stone: Node3D
	for node in get_nodes_in_group("crumble_stones"):
		if absf(node.position.x-center)<0.1: stone=node
	check(stone!=null and stone.timber,"ponte frágil usa a peça física de desmoronamento")
	player.position=Vector3(center,stone.position.y+stone.stone_size.y*0.5+0.05,0)
	player.velocity=Vector3.ZERO
	await frames(8)
	check(player.is_on_floor() and stone._timer>0,"pisar inicia aviso antes da queda")
	await frames(60)
	check(stone._shape.disabled and player.position.y<float(fragile.from_y)-0.2,"ponte perde colisão e deixa cair de verdade")
	player.position=Vector3(float(fragile.start)-2,float(fragile.from_y)+0.1,0)
	player.velocity=Vector3.ZERO
	await frames(170)
	check(not stone._shape.disabled,"ponte se recompõe para retorno ou nova tentativa")
	phase.free()
	current_scene=null
	await frames(3)
	check(get_nodes_in_group("earth_bridges").is_empty() and get_nodes_in_group("crumble_stones").is_empty(),"saída limpa pontes e tarefas")
	print("PARKOUR_REVISION checks=%d failures=%d" % [checks,failures])
	await preload("res://tests/common/audio_cleanup.gd").finish(self)
	quit(1 if failures else 0)
