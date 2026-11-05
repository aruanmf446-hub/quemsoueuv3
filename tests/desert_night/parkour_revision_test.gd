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
	var tasks := 0
	for order in range(1,11):
		var stage := Layout.build(order)
		tasks += stage.tasks.size()
		if order == 10: continue
		var heights: Array = stage.surfaces.map(func(s: Dictionary) -> float:return float(s.height))
		check(heights.max()-heights.min()>2.5,"fase%d: diferenças de nível visíveis" % order)
		check(stage.holes.all(func(g: Dictionary) -> bool:return absf(float(g.from_y)-float(g.to_y))<0.56 and float(g.width)<=3.2),"fase%d: retorno por salto continua alcançável" % order)
		check(stage.platforms.filter(func(p: Dictionary) -> bool:return p.get("parkour_route",false)).size()==(0 if order==2 else 8),"fase%d: rota de teto real ou obstáculo conforme a fase" % order)
		check(stage.holes.filter(func(g: Dictionary) -> bool:return g.get("crumble_bridge",false)).size()==2,"fase%d: duas pontes frágeis" % order)
	check(tasks==19,"dezenove tarefas de cenário, sem habilidades permanentes")
	var phase: Node3D = load("res://scenes/desert/phase_04.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(10)
	phase.set_physics_process(false)
	var hole: Dictionary = phase._phase.tasks.filter(func(g: Dictionary) -> bool:return g.task_kind=="bridge")[0]
	var player: Node3D = phase._player
	player.position = Vector3(float(hole.start)-1.6,float(hole.from_y)+0.1,0)
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
	for frame in 120:
		await physics_frame
		if player.position.x>float(hole.end)+1: break
	Input.action_release("move_right")
	check(player.position.x>float(hole.end)+0.4 and player.is_on_floor(),"ponte atravessável andando para a direita")
	Input.action_press("move_left")
	for frame in 120:
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
	quit(1 if failures else 0)
