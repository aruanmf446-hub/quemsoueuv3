extends SceneTree
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS " if value else "FAIL ")+message)
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func run() -> void:
	for order in range(1,11):
		var stage := Layout.build(order)
		check(stage.order == order and stage.districts.size()==8,"fase%d: identidade e oito setores" % order)
		for ability: String in Layout.ABILITY_PHASE:
			check(stage.pickups.any(func(item: Dictionary)->bool:return item.kind == ability) == (order >= Layout.ABILITY_PHASE[ability]),"fase%d: recarga %s respeita progressão" % [order,ability])
		check(stage.minimum_traversal_seconds >= 180,"fase%d: percurso extenso" % order)
		var safe := true
		var separate := true
		for item: Dictionary in stage.pickups:
			var floor := Layout.floor_at(stage,float(item.pos[0]))
			if floor.is_empty() or absf(float(item.pos[1])-float(floor.get("height",INF)))>0.01: safe=false
			for other: Dictionary in stage.pickups:
				if item.id != other.id and absf(float(item.pos[0])-float(other.pos[0]))<2.0: separate=false
		check(safe and separate,"fase%d: recargas sustentadas pelo piso e separadas" % order)
		check(stage.holes.all(func(g: Dictionary)->bool:return g.width<=3.2 and absf(g.from_y-g.to_y)<=0.65),"fase%d: saltos alcançáveis por soldados" % order)
		if order == 2:check(stage.surfaces.all(func(s: Dictionary)->bool:return s.height>=8),"fase2: toda rota sobre edifícios, sem rua como piso")
		var phase = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene = phase
		await frames(8)
		check(phase._order == order and phase._player.position.y >= float(stage.player_spawn[1])-0.4,"fase%d: cena real abre na altura projetada" % order)
		phase.free()
		current_scene=null
		await frames(2)
	var phase = load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(12)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	for soldier in phase._troops.get_children(): phase._retire_enemy(soldier)
	var gap: Dictionary = phase._phase.holes[0]
	phase._player.position=Vector3(float(gap.end)+6.0,float(gap.to_y)+0.02,0)
	phase._player._invulnerable=999
	phase._spawn_enemy(phase._troops,{"id":"roof-jump-fixture","pos":[float(gap.start)-3.0,float(gap.from_y)+0.02,0],"patrol":[-100,100],"troop":true})
	var enemy=phase._troops.get_child(0)
	var start:float=enemy.position.x
	var peak:float=enemy.position.y
	for frame in range(220):
		await physics_frame
		peak=maxf(peak,enemy.position.y)
	check(enemy.position.x>float(gap.end)+0.4 and enemy.position.x>start+4,"Cactus atravessa vão real do primeiro telhado por física")
	check(peak>float(gap.from_y)+0.9 and enemy.position.y>7.5,"Cactus salta na laje e não persegue na rua")
	enemy.set_physics_process(false)
	enemy.position=phase._player.position+Vector3(1.2,0,0)
	enemy.health=3
	phase._player.restore_charge("dash")
	phase._player.use_ability("dash")
	phase._player._shock_nearby()
	check(enemy.health==2,"corrida elétrica causa choque real em inimigo próximo")
	phase._player._shock_nearby()
	check(enemy.health==2,"choque não repete dano a cada quadro da mesma corrida")
	phase._player.cancel_dash()
	# Congelamento deve atingir somente atrás, inclusive se El Fuego virar à esquerda.
	enemy.set_physics_process(false)
	phase._player.facing=1
	enemy.position=phase._player.position+Vector3(3,0,0)
	phase._player.restore_charge("amber")
	phase._player.use_ability("amber")
	check(enemy.crystallized_left==0,"congelamento não atinge inimigo à frente")
	enemy.position=phase._player.position-Vector3(3,0,0)
	phase._player.restore_charge("amber")
	phase._player.use_ability("amber")
	check(enemy.crystallized_left>0,"congelamento atinge perseguidor atrás")
	enemy.crystallized_left=0
	phase._player.facing=-1
	phase._player.restore_charge("amber")
	phase._player.use_ability("amber")
	check(enemy.crystallized_left==0,"congelamento respeita orientação ao virar")
	phase._player.facing=1
	enemy.set_physics_process(true)
	var landing_x := float(gap.end)
	var landing_y := float(gap.to_y)
	var target_before: Vector3 = phase._player.position
	enemy.set_physics_process(false)
	enemy.position=Vector3(landing_x+0.75,landing_y+0.02,0)
	phase._player.position=Vector3(landing_x+0.3,landing_y+0.02,0)
	phase._player.set_physics_process(true)
	await frames(3)
	phase._player.set_physics_process(false)
	var supported:Vector3=phase._player.position
	phase._player._separate_actors()
	check(phase._player.position.x>=landing_x,"contato na aterrissagem não empurra o jogador para o vão")
	phase._player.position=target_before
	enemy.set_physics_process(true)
	enemy.position.x=phase._player.position.x-3
	enemy.crystallize(0.3)
	var frozen:Vector3=enemy.position
	await frames(12)
	check(enemy.position.is_equal_approx(frozen) and enemy.crystallized_left>0,"Âmbar imobiliza temporariamente")
	var target: Vector3=phase._player.position
	var health: int=phase._player.health
	phase._player._invulnerable=0
	phase._player.position=enemy.position+Vector3(-0.9,0,0)
	phase._player._separate_actors()
	check(phase._player.health==health,"soldado em cristal não causa dano por contato")
	phase._player.position=target
	phase._player._invulnerable=999
	await frames(45)
	check(enemy.crystallized_left==0 and enemy.position.x>frozen.x,"Cactus retoma perseguição depois do cristal")
	for soldier in phase._troops.get_children(): phase._retire_enemy(soldier)
	var candidate: Dictionary = {}
	for platform: Dictionary in phase._phase.platforms:
		if platform.get("breakable",false): candidate=platform; break
	check(not candidate.is_empty(),"telhados mantêm pisos explicitamente rompíveis")
	if not candidate.is_empty():
		var top := float(candidate.pos[1])+0.5
		phase._player.position=Vector3(float(candidate.span_end)+2.1,top+0.02,0)
		phase._stream_world(phase._player.position.x,true)
		await frames(3)
		var point := Vector3(float(candidate.pos[0]),top+0.25,0)
		var ray := PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*0.5,1)
		check(not phase.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"laje alta tem colisão antes da Ruptura")
		phase._player.restore_charge("rupture")
		check(phase._player.use_ability("rupture"),"botão/poder aciona Ruptura na laje alta")
		await frames(3)
		check(phase.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Ruptura remove colisão real na altura do telhado")
		phase._set_floor_broken(str(candidate.id),false)
		await frames(2)
		check(not phase.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"restauração recupera a laje alta")
	if not candidate.is_empty():
		phase._player.position=Vector3(float(candidate.span_start)-2.1,float(candidate.pos[1])+0.52,0)
		phase._player.facing=-1
		phase._player.restore_charge("rupture")
		phase._player.use_ability("rupture")
		check(phase._ruptured.has(str(candidate.id)),"Ruptura abre piso à direita quando El Fuego olha para esquerda")
	for kind in ["attack","defense","rupture","amber","dash"]:
		for index in range(4): phase._player.restore_charge(kind)
		check(phase._player.charges(kind)==3 and not phase._player.restore_charge(kind),"%s respeita capacidade3 sem consumir recarga cheia" % kind)
	phase.queue_free()
	current_scene=null
	await frames(8)
	print("REINO10_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
