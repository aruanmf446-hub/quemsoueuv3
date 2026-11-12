extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("COMBAT_","PASS " if ok else "FAIL ",text)
func tick(n: int) -> void:
	for i in n:await physics_frame
func ready_to_attack(player: Node3D) -> void:
	for frame in 240:
		if player._attack_timer<=0 and player._attack_cooldown<=0:return
		await tick(1)
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var phase:=load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	phase.set("opening_grace",0.0) # mecânica sem o respiro de entrada
	root.add_child(phase)
	current_scene=phase
	await tick(20)
	var player: Node3D=phase._player
	check(player.is_on_floor(),"arena floor supports spawn")
	player.position=Vector3(7.8,8.95,0)
	player.velocity=Vector3.ZERO
	await tick(15)
	player.facing=1
	player.attack_charges=3
	phase.encounter._green_wait=100
	phase._clear_chemicals()
	Input.action_press("attack")
	await tick(2)
	Input.action_release("attack")
	await tick(29)
	check(player.attack_charges==2,"existing attack consumes one charge")
	check(phase.encounter.damage==2,"actual melee reaches boss")
	await ready_to_attack(player)
	Input.action_press("attack")
	await tick(2)
	Input.action_release("attack")
	for frame in 240:
		if phase.encounter.is_stunned():break
		await tick(1)
	check(phase.encounter.is_stunned(),"second real hit stuns")
	check(player.attack_charges==3 and player.defense_charges==3,"stun refills to cap")
	await ready_to_attack(player)
	phase.encounter.suspended=true
	player._invulnerable=0
	player.defense_charges=3
	await tick(15)
	Input.action_press("defend")
	await tick(2)
	Input.action_release("defend")
	check(player.is_defending and player.defense_charges==2,"existing defense spends charge")
	var before: int=player.health
	var red:=preload("res://scripts/desert/malagueta/chemical.gd").new()
	red.kind="red"
	red.warning=0
	red.direction=Vector3.ZERO
	red.position=player.position+Vector3(0.15,0.7,0)
	phase.arena.add_child(red)
	await tick(5)
	check(player.health==before and not player.is_defending,"red blocked by real shield")
	await tick(65)
	player._invulnerable=0
	red=preload("res://scripts/desert/malagueta/chemical.gd").new()
	red.warning=0
	red.direction=Vector3.ZERO
	red.position=player.position+Vector3(0.15,0.7,0)
	phase.arena.add_child(red)
	await tick(5)
	check(player.health==before-1,"unblocked chemical applies normal damage")
	player.fill_ability("attack")
	var item:=preload("res://scripts/desert/t15d/charge_pickup.gd").new()
	item.kind="attack"
	item.position=player.position
	phase.arena.add_child(item)
	await tick(4)
	check(not item._taken and player.attack_charges==3,"full pickup is not consumed")
	player.attack_charges=1
	await tick(4)
	check(player.attack_charges<=3 and player.attack_charges>1,"contact pickup uses existing refill")
	# Contact with a cutting end uses the same damage path as the chemical.
	player.set_physics_process(false)
	player.health=3
	player._invulnerable=0
	player.is_defending=false
	var file: Node3D=phase.files[0]
	player.position=file.global_position+Vector3(-file.span*0.5-0.07,-0.4,0)
	await tick(4)
	check(player.health==2,"cutting edge applies normal damage")
	phase.queue_free()
	await tick(3)
	print("COMBAT_SUMMARY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
