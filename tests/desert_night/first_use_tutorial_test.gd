extends SceneTree
const Tutorial=preload("res://scripts/desert/t15d/first_use_tutorial.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+text)
func frames(n: int) -> void:
	for i in n:await process_frame
func ticks(n: int) -> void:
	for i in n:await physics_frame
func collect(phase: Node3D,kind: String) -> void:
	for item in get_nodes_in_group("campaign_pickups"):
		if phase.is_ancestor_of(item) and item.kind==kind:
			phase._player.position=item.global_position+Vector3.UP*0.05
			phase._player.velocity=Vector3.ZERO
			phase._player._invulnerable=999
			await ticks(10)
			return
func at_task(phase: Node3D) -> void:
	var task: Dictionary=phase._phase.tasks[0]
	phase._player.position=Vector3(float(task.start)-2,float(task.from_y)+0.1,0)
	phase._player.velocity=Vector3.ZERO
	phase._stream_world(phase._player.position.x,true)
	for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	await ticks(15)
func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.SAVE_PATH))
	var phase: Node3D=load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(8)
	check(phase._player.attack_charges==0 and phase._player.defense_charges==0,"fase1 começa sem ataque e defesa")
	check(phase._first_use.active and phase._first_use.kind=="attack" and paused,"primeira lição de ataque pausa o jogo")
	var position: Vector3=phase._player.position
	var elapsed: float=phase._elapsed
	Input.action_press("move_right")
	await frames(20)
	check(phase._player.position==position and phase._elapsed==elapsed,"pausa realmente congela movimento e relógio")
	phase._first_use._continue.pressed.emit()
	await ticks(5)
	check(not paused and not phase._first_use.active and phase._first_use.seen("attack"),"continuar funciona e salva a primeira lição")
	check(not Input.is_action_pressed("move_right"),"continuar não conserva comando pressionado")
	await collect(phase,"attack")
	check(phase._player.attack_charges==1 and not paused,"recarga real libera ataque sem repetir a lição")
	await collect(phase,"defense")
	check(phase._first_use.active and phase._first_use.kind=="defense" and paused,"primeira recarga de defesa pausa e explica o escudo")
	phase._first_use._continue.pressed.emit()
	await ticks(3)
	check(not paused and phase._first_use.seen("defense"),"defesa fica marcada como ensinada")
	await at_task(phase)
	check(phase._first_use.active and phase._first_use.kind=="task" and paused,"primeira Task pausa e explica o botão contextual")
	check(phase._hud._bridge_task.visible,"botão contextual está disponível durante a explicação")
	phase._first_use._continue.pressed.emit()
	await ticks(4)
	var area: Rect2=phase._hud._bridge_task.get_global_rect()
	if phase._hud._actions.visible:
		check(area.get_center().y<phase._hud._action_buttons.attack.get_global_rect().get_center().y,"Task fica acima do ataque no desktop")
	else:
		check(area.get_center().y<phase._touch_pad._buttons.attack[0].y,"Task fica acima do ataque no toque")
	phase._hud._bridge_task.pressed.emit()
	await ticks(70)
	check(not phase._hud._bridge_task.visible,"botão some depois de executar a Task")
	check(phase._player.defense_charges==1,"Task preserva a carga de defesa recebida")
	check(phase._player.is_physics_processing() and not paused,"controles voltam após a montagem")
	phase.free()
	current_scene=null
	await frames(3)
	phase=load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(8)
	check(not paused and not phase._first_use.active,"lição não reaparece ao reabrir a fase 1")
	check(phase._player.attack_charges==0 and phase._player.defense_charges==0,"reabrir fase1 mantém inventário inicial zerado")
	await collect(phase,"defense")
	check(not paused and not phase._first_use.active,"defesa não repete explicação já lida")
	await at_task(phase)
	check(not paused and phase._hud._bridge_task.visible,"Task seguinte funciona sem repetir a lição")
	phase.free()
	current_scene=null
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.SAVE_PATH))
	phase=load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	await frames(8)
	check(not paused and not phase._first_use.active,"fase2 não apresenta as lições da fase1")
	check(phase._player.attack_charges==1 and phase._player.defense_charges==1,"inventário inicial das outras fases preservado")
	phase.free()
	current_scene=null
	await frames(3)
	check(not paused,"sair das cenas não deixa o jogo pausado")
	print("FIRST_USE_TUTORIAL checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
