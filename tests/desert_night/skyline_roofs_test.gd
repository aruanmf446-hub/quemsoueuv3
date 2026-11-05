extends SceneTree
## Verifica camada aditiva, pool fixo, ausência de física nova e telhados apoiados.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ")+text)
func frames() -> void:
	for i in 3: await physics_frame
func run() -> void:
	for order in range(1,11):
		var phase: Node3D = load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		phase.set_physics_process(false)
		phase._player.set_physics_process(false)
		await frames()
		var skyline: Node3D = phase._scenery._skyline
		if order in [6,10]:
			check(skyline==null and phase._scenery._panorama==null,"fase%02d: subterrâneo preservado sem céu ou palácios" % order)
		else:
			check(skyline!=null,"fase%02d: camada de muralhas/palácios presente" % order)
			check(phase._scenery._panorama.texture.resource_path=="res://assets/desert/modular/capital_desert.res","fase%02d: dunas aprovadas mantidas" % order)
			check(skyline._walls.size()==3 and skyline._palaces.size()==3,"fase%02d: pool fixo de três muros e três palácios" % order)
			var nodes: Array = skyline.find_children("*","",true,false)
			check(nodes.all(func(n: Node) -> bool: return not n is CollisionObject3D and not n is Light3D),"fase%02d: fundo não adiciona colisão nem luz" % order)
			var count := nodes.size()
			for x in [-8.0,50.0,500.0,1400.0,10000.0,0.0]:
				skyline.follow(phase._camera,x,clampf(x/1452.0,0,1))
			check(skyline.find_children("*","",true,false).size()==count,"fase%02d: avançar e voltar não cria objetos" % order)
			check(nodes.all(func(n: Node) -> bool: return not n is GeometryInstance3D or n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"fase%02d: fundo sem sombras novas" % order)
		if order==2:
			check(phase._player.position.y>=8,"fase2: jogador continua na altura dos telhados")
			check(get_nodes_in_group("rooftop_terraces").is_empty(),"fase2: nenhuma cobertura extra sobre as casas")
			check(not get_nodes_in_group("playable_house_roofs").is_empty(),"fase2: tetos das próprias casas presentes")
			check(phase._world.find_children("City_roof","MeshInstance3D",true,false).is_empty(),"fase2: faixa contínua de piso removida")
			var gap: Dictionary = phase._phase.holes[0]
			var x := (float(gap.start)+float(gap.end))*0.5
			var query := PhysicsRayQueryParameters3D.create(Vector3(x,float(gap.from_y)+2,0),Vector3(x,-15,0),1)
			check(phase.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"fase2: primeiro vão continua realmente aberto")
			query = PhysicsRayQueryParameters3D.create(Vector3(float(gap.end)+1,float(gap.to_y)+2,0),Vector3(float(gap.end)+1,-15,0),1)
			var hit := phase.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and absf(float(hit.position.y)-float(gap.to_y))<0.02,"fase2: aterrissagem na altura original")
		else:
			check(get_nodes_in_group("rooftop_terraces").is_empty(),"fase%02d: decoração de cobertura não invade outras fases" % order)
		phase.free()
		await frames()
		check(get_nodes_in_group("capital_skyline").is_empty() and get_nodes_in_group("rooftop_terraces").is_empty(),"fase%02d: sair limpa o fundo e os terraços" % order)
	print("SKYLINE_ROOFS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
