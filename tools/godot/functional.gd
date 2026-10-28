extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func _run() -> void:
	var phase := load("res://scenes/desert/phase_01.tscn").instantiate() as Node3D
	root.add_child(phase)
	current_scene = phase
	await frames(60)
	var player: SidePlayer = phase.get("_player")
	check(player.is_on_floor(), "floor_collision")
	var start := player.position.x
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	check(player.position.x > start + 0.5 and is_zero_approx(player.position.z), "lateral_movement")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.velocity.y > 0, "jump")
	await frames(10)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.jumps_used == 2 and player.velocity.y > 0, "double_jump")
	await frames(4)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.jumps_used == 2, "third_jump_denied")
	await frames(100)
	player.position = Vector3(-8, 0.05, 0)
	player.velocity = Vector3.ZERO
	await frames(10)
	start = player.position.x
	player.take_damage(1, start - 1)
	await frames(3)
	check(player.position.x > start + 0.03, "damage_knockback")
	player.set("_invulnerable", 0.0)
	player.position = Vector3(12, 0.1, 0)
	await frames(3)
	check(absf(phase.get("_checkpoint").x - 12.0) < 0.01, "checkpoint_area")
	# Garante um golpe fatal no teste, independente do contato ao entrar na área.
	player.set("_invulnerable", 0.0)
	player.take_damage(SidePlayer.MAX_HEALTH, 0)
	await create_timer(2.0).timeout
	print("RESPAWN_STATE ", player.is_dead, " health=", player.health, " x=", player.position.x)
	check(not player.is_dead and player.health == SidePlayer.MAX_HEALTH and absf(player.position.x-12) < 0.1, "checkpoint_respawn")
	var enemy := get_first_node_in_group("enemies") as CactusEnemy
	enemy.position = player.position + Vector3(1, 0, 0)
	enemy.set_physics_process(false)
	player.facing = 1
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	check(enemy.get("_state") == CactusEnemy.State.DEAD, "attack_defeats_cactus")
	await create_timer(1.8).timeout
	phase.queue_free()
	await frames(3)
	phase = load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	root.add_child(phase)
	current_scene = phase
	await frames(30)
	player = phase.get("_player")
	phase.call("_on_goal_entered", player)
	check(not phase.get("completed"), "boss_exit_locked")
	var boss: CactusEnemy = null
	for actor in get_nodes_in_group("enemies"):
		if actor.get_node("Model").character_id == &"malagueta": boss = actor
	check(boss != null, "actual_malagueta_model")
	if boss != null:
		boss.take_damage(boss.health)
		phase.call("_on_goal_entered", player)
		check(phase.get("completed"), "boss_exit_after_defeat")
	await create_timer(1.8).timeout
	quit(1 if failures else 0)
