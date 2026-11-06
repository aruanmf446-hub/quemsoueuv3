extends SceneTree
const Layout=preload("res://scripts/desert/t15d/campaign_layout.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+text)
func ticks(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	for order in range(1,11):
		var level:=Layout.build(order)
		for task: Dictionary in level.tasks:
			if task.task_kind=="gate":continue
			check(float(task.width)>=18,"%s: vão excede alcance de pulo duplo e corrida" % task.id)
			var clear:=true
			for p: Dictionary in level.platforms:
				if float(p.pos[0])>float(task.start) and float(p.pos[0])<float(task.end):clear=false
			check(clear,"%s: sem piso ou obstáculo para contornar a Task" % task.id)
	# Tentativas reais contra portão e vão, com pulo duplo e corrida desbloqueados na fixture.
	for order in [1,2]:
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		var task: Dictionary=phase._phase.tasks[0]
		var player: Node3D=phase._player
		player.position=Vector3(float(task.start)-1.0,float(task.from_y)+0.1,0)
		player.velocity=Vector3.ZERO
		player._invulnerable=999
		phase._stream_world(player.position.x,true)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		await ticks(12)
		player.restore_charge("dash")
		player.use_ability("dash")
		Input.action_press("move_right")
		Input.action_press("jump")
		await ticks(2)
		Input.action_release("jump")
		var double_used:=false
		var farthest: float=player.position.x
		for i in 180:
			if not double_used and player.velocity.y<0:
				Input.action_press("jump")
				double_used=true
				await ticks(2)
				Input.action_release("jump")
			await physics_frame
			farthest=maxf(farthest,player.position.x)
			if player.position.y<float(task.from_y)-5:break
		Input.action_release("move_right")
		check(double_used and farthest<float(task.end),"fase%d: não atravessa Task fechada com pulo duplo e corrida" % order)
		phase.free()
		current_scene=null
		await ticks(3)
	print("TASK_BARRIERS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
