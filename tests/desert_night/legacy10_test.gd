extends SceneTree
## Fase10 usa os recursos/controllers originais e mantém seu combate anterior.
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
	var phase = load("res://scenes/desert/phase_10.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(30)
	var player: SidePlayer = phase._player
	check(phase.get_script().resource_path == "res://scripts/desert/phase_01.gd","Fase10 permanece no controlador original")
	check(player.get_script().resource_path == "res://scripts/desert/side_player.gd","Fase10 mantém movimento e combate compartilhados originais")
	check(player.health == SidePlayer.MAX_HEALTH and player.health == 5,"Fase10 mantém vida original5")
	check(phase._phase.goal.pos[0] == 52.0 and phase._phase.boss_id == "malagueta","Fase10 mantém mapa e chefe originais")
	var boss: CactusEnemy
	for enemy: CactusEnemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy.health == 20: boss = enemy
	check(boss != null,"Malagueta original aparece")
	player.position = Vector3(47.6,0.05,0)
	player.velocity = Vector3.ZERO
	boss.position = Vector3(49,0.05,0)
	player.facing = 1
	await frames(2)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	check(boss.health == 18,"ataque original preserva dano2 na Fase10")
	await frames(30)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	check(boss.health == 16,"Fase10 mantém ataques reutilizáveis sem carga consumível")
	phase._on_goal_entered(player)
	check(not phase.completed,"saída continua bloqueada enquanto chefe vive")
	print("LEGACY10_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
