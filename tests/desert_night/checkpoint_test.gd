extends SceneTree
## Checkpoints por distrito e painel de derrota. Fixtures reposicionam o jogador:
## não são evidência de percurso.
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
func buttons(phase: Node) -> Array:
	return phase._session._column.get_children().filter(func(c: Node) -> bool: return c is Button)
func run() -> void:
	for order in range(1,10):
		var stage := Layout.build(order)
		var points: Array = stage.checkpoints
		var safe := points.size() == 7
		for point: Dictionary in points:
			var x := float(point.pos[0])
			for hole: Dictionary in stage.holes:
				if x >= float(hole.start)-3.0 and x <= float(hole.end)+3.0: safe = false
			for platform: Dictionary in stage.platforms:
				if platform.kind != "ground" and absf(x-float(platform.pos[0])) <= float(platform.size[0])*0.5+1.0: safe = false
			for enemy: Dictionary in stage.enemies:
				if x >= float(enemy.patrol[0])-6.0 and x <= float(enemy.patrol[1])+6.0: safe = false
		check(safe,"fase %02d: sete checkpoints em chão firme, longe de vãos, degraus e Cactus" % order)
	var phase: Node3D = load("res://scenes/desert/phase_03.tscn").instantiate()
	root.add_child(phase)
	current_scene = phase
	await frames(30)
	var player: SidePlayer = phase._player
	var returned := [0]
	phase.return_requested.connect(func() -> void: returned[0] += 1)
	var first: Dictionary = phase._phase.checkpoints[0]
	player.position = Vector3(float(first.pos[0])-1.0,0.05,0)
	phase._stream_world(player.position.x,true)
	await frames(10)
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(phase._checkpoint_index == 0,"passar pela bandeira ativa o checkpoint 1")
	var lit := false
	for banner in get_nodes_in_group("campaign_checkpoints"):
		if banner.index == 0 and banner._light.visible: lit = true
	check(lit,"bandeira do checkpoint fica acesa")
	# Estado depois do checkpoint: gasta o ataque e derrota um Cactus mais adiante.
	var later: Dictionary = {}
	for spawn: Dictionary in phase._phase.enemies:
		if float(spawn.pos[0]) > float(first.pos[0]): later = spawn; break
	player.attack_charges = 0
	phase._defeated_ids[str(later.id)] = true
	player.fall_out()
	var opened := false
	for step in range(120):
		await physics_frame
		if phase._session.opened and phase._session._death: opened = true; break
	var labels: Array = buttons(phase).map(func(b: Button) -> String: return b.text)
	check(opened and paused,"morte pausa a fase e abre o painel")
	check(labels == ["Voltar ao checkpoint","Recomeçar fase","Voltar ao menu"],"painel oferece checkpoint, recomeçar e menu (%s)" % ", ".join(labels))
	(buttons(phase)[0] as Button).pressed.emit()
	await frames(10)
	check(not paused and not player.is_dead and player.health == 3,"checkpoint volta com vida cheia")
	check(absf(player.position.x-float(first.pos[0])) < 0.5,"jogador reaparece na bandeira")
	check(player.attack_charges == 1 and player.defense_charges == 1,"cargas voltam ao que eram no checkpoint")
	check(not phase._defeated_ids.has(str(later.id)),"Cactus derrotado depois do checkpoint volta")
	check(phase._checkpoint_index == 0,"checkpoint continua ativo depois de voltar")
	player.fall_out()
	for step in range(120):
		await physics_frame
		if phase._session.opened: break
	(buttons(phase)[1] as Button).pressed.emit()
	await frames(10)
	check(phase._checkpoint_index == -1 and absf(player.position.x-float(phase._phase.player_spawn[0])) < 0.5,"Recomeçar fase volta ao início e apaga o checkpoint")
	player.fall_out()
	for step in range(120):
		await physics_frame
		if phase._session.opened: break
	(buttons(phase)[1] as Button).pressed.emit()
	await frames(5)
	check(returned[0] == 1,"Voltar ao menu sai da fase")
	print("CHECKPOINT_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
