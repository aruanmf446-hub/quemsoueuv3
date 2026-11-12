extends SceneTree
## Escada fixa da arena: com os controles reais (pulo + pulo duplo) o jogador sobe do chão ao
## patamar do chefe sem depender das serras e sem perder vida para elas.
var failures := 0
func _initialize() -> void: call_deferred("run")
func tick(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ")+what)
	if not ok: failures += 1
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var phase := load("res://scenes/desert/phase_10.tscn").instantiate() as Node3D
	phase.set("opening_grace",0.0)
	root.add_child(phase)
	current_scene=phase
	await tick(6)
	phase.encounter.suspended=true
	var player: Node3D=phase._player
	player._invulnerable=0
	player.position=Vector3(10.6,0.1,0)
	player.velocity=Vector3.ZERO
	await tick(20)
	var health: int=player.health
	var tops: Array=[1.2,3.1,5.0,6.9,8.85]
	var rests: Array=[]
	for attempt in 8:
		if player.position.y>8.7: break
		Input.action_press("jump")
		await tick(3)
		Input.action_release("jump")
		await tick(24)
		Input.action_press("jump")
		await tick(3)
		Input.action_release("jump")
		for frame in 150:
			await physics_frame
			if player.is_on_floor(): break
		rests.append(snappedf(player.position.y,0.01))
		# Parado no degrau enquanto as serras passam: deslizam sob os pés, não ferem.
		await tick(60)
	var on_steps := true
	for y: float in rests:
		if not tops.any(func(top: float) -> bool: return absf(top-y)<0.12): on_steps=false
	check(on_steps and not rests.is_empty(),"cada pouso é num degrau ou no patamar: "+str(rests))
	check(player.position.y>8.7,"pulo e pulo duplo levam do chão ao patamar do chefe")
	await tick(900)
	check(player.health==health,"nenhuma vida perdida parado na escada e no patamar (%d/%d)" % [player.health,health])
	check(player.position.y>8.7 and absf(player.position.x-10.6)<1.6,"jogador permanece no patamar do chefe")
	print("STEPS failures=",failures)
	quit(1 if failures>0 else 0)
