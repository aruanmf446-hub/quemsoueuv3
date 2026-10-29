extends SceneTree
## Variedade: cada fase passa por quatro lugares (fundo e luz mudam) e há corações que
## recuperam vida sem passar de 3/3. Fixtures reposicionam o jogador.
const Layout = preload("res://scripts/desert/t15d/campaign_layout.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures += 1
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func run() -> void:
	for order in range(1,10):
		var hearts: int = Layout.build(order).pickups.filter(func(p: Dictionary) -> bool: return p.kind == "health").size()
		check(hearts >= 4,"fase %02d tem %d recargas de vida" % [order,hearts])
	var phase: Node3D = load("res://scenes/desert/phase_04.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(20)
	var player: SidePlayer = phase._player
	var places := {}
	var changes := [0]
	phase._scenery.location_changed.connect(func(_p: Dictionary) -> void: changes[0] += 1)
	var start := float(phase._phase.player_spawn[0])
	# Pontos em chão firme (início e bandeiras de checkpoint): nunca cai num vão largo.
	var spots: Array[float] = [start+2.0]
	for index in [1,3,5,6]: spots.append(float(phase._phase.checkpoints[index].pos[0]))
	for x in spots:
		player.position = Vector3(x,0.05,0)
		phase._stream_world(player.position.x,true)
		for actor in get_nodes_in_group("enemies"): actor.queue_free()
		await frames(5)
		places[phase._scenery.current_place().name] = true
	check(places.size() == 4,"percurso passa por quatro lugares diferentes (%s)" % ", ".join(places.keys()))
	check(changes[0] >= 3,"cada troca de lugar avisa a fase (nome e luz)")
	await frames(90)
	var front: Sprite3D = phase._scenery._layers[phase._scenery._front]
	check(is_equal_approx(front.modulate.a,1.0),"transição do fundo termina visível")
	# Coração: cura 1 e não passa do máximo; cheio, fica no mapa.
	var heart: Dictionary
	for pickup: Dictionary in phase._phase.pickups:
		if pickup.kind == "health": heart = pickup; break
	phase._restart_level()
	await frames(5)
	player.position = Vector3(float(heart.pos[0])-3.0,0.05,0)
	phase._stream_world(player.position.x,true)
	for actor in get_nodes_in_group("enemies"): actor.queue_free()
	await frames(10)
	Input.action_press("move_right")
	await frames(40)
	Input.action_release("move_right")
	check(not phase._collected_ids.has(heart.id),"com vida cheia o coração fica no mapa")
	# Dano vindo de trás empurra para longe do coração (o recuo não pode pegar o item).
	player._invulnerable = 0.0
	player.take_damage(1,player.position.x-1)
	await frames(60)
	var before := player.health
	player.position = Vector3(float(heart.pos[0])-2.0,0.05,0)
	await frames(5)
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(before == 2 and player.health == 3 and phase._collected_ids.has(heart.id),"coração recupera 1 de vida e some")
	print("VARIETY_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
