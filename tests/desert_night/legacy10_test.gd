extends SceneTree
## A fase10 foi incluída no novo escopo. Mantém Malagueta, seu modelo e combate.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS " if ok else "FAIL ")+message)
func frames(count: int) -> void:
	for frame in range(count): await physics_frame
func run() -> void:
	var phase=load("res://scenes/desert/phase_10.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(12)
	check(phase._order==10 and phase._phase.theme=="mine_interior","fase10 abre o interior subterrâneo modular")
	check(float(phase._phase.length)>=1452,"fase10 conserva percurso extenso")
	phase._player.position=Vector3(float(phase._phase.goal.pos[0])-15,float(phase._phase.goal.pos[1])-1.48,0)
	phase._stream_world(phase._player.position.x,true)
	phase._player.set_physics_process(false)
	phase._player._invulnerable=999
	await frames(2)
	check(is_instance_valid(phase._boss) and phase._boss.health==20,"Malagueta original aparece na arena final com vida20")
	phase._boss.set_physics_process(false)
	phase._on_goal_entered(phase._player)
	check(not phase.completed,"saída não ignora o chefe vivo")
	phase._player.position=phase._boss.position+Vector3(-1.4,0,0)
	phase._player.facing=1
	phase._player.set_physics_process(true)
	Input.action_press("attack")
	await frames(18)
	Input.action_release("attack")
	check(phase._boss.health==18,"ataque real preserva dano2 no chefe original")
	phase._boss.take_damage(18)
	phase._on_goal_entered(phase._player)
	check(phase.completed and phase._boss_defeated,"chefe derrotado libera conclusão do interior")
	phase.queue_free()
	await frames(12)
	print("MINE10_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
