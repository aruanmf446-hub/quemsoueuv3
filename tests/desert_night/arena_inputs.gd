extends "res://tests/desert_night/route.gd"
## Fixture isolada para depurar a arena: não substitui prova da travessia completa.
func run() -> void:
	order=10
	for previous in range(1,10):Progress.complete(previous)
	phase=load("res://scenes/desert/phase_10.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	player=phase._player
	platforms=phase._phase.platforms
	var arena:Dictionary=phase._phase.surfaces[-1]
	player.position=Vector3(float(arena.left)+4,float(arena.height)+0.05,0)
	phase._stream_world(player.position.x,true)
	for frame in range(5):await physics_frame
	for kind in ["attack","defense","amber"]:
		for count in range(3):player.restore_charge(kind)
	for step in range(60*100):
		if player.is_dead or phase.completed:break
		if step==_attack_release_at:Input.action_release("attack")
		if step==_jump_release_at:Input.action_release("jump")
		if step==_amber_release_at:Input.action_release("amber")
		if step==_defense_release_at:Input.action_release("defend")
		if player.is_on_floor() and player.defense_charges>0 and player._shield_timer<=0 and player._attack_timer<=0.15 and is_instance_valid(phase._boss) and phase._boss._windup>0:
			Input.action_press("defend")
			_defense_release_at=step+2
		if not fight_malagueta(step):
			var goal:float=phase._phase.goal.pos[0]
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_press("move_left" if player.position.x>goal else "move_right")
			if player.position.x>goal:auto_jump_left(step)
		await physics_frame
	print("ARENA_INPUTS complete=",phase.completed," health=",player.health," boss_dead=",phase._boss_defeated)
	quit(0 if phase.completed else 1)
