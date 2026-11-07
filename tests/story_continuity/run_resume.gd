extends SceneTree
const Run=preload("res://scripts/desert/t15d/campaign_run.gd")
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	preload("res://scripts/desert/t15d/campaign_progress.gd").merge_highest("",5)
	var phase: Node3D=load("res://scenes/desert/phase_06.tscn").instantiate()
	root.add_child(phase)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	var floor: Dictionary=phase._phase.surfaces[26]
	var saved_at:=Vector3(float(floor.left)+2,float(floor.height)+0.01,0)
	phase._player.position=saved_at
	phase._safe_position=saved_at
	phase._checkpoint_index=5
	phase._checkpoint=phase._vec3(phase._phase.checkpoints[5].pos)
	phase._player.health=2
	phase._player.attack_charges=2
	phase._player.defense_charges=0
	phase._player.abilities={"amber":0,"dash":1,"rupture":3}
	phase._collected_ids[str(phase._phase.pickups[0].id)]=true
	phase._defeated_ids[str(phase._phase.enemies[0].id)]=true
	phase._raised_bridges[str(phase._phase.tasks[0].id)]=true
	phase._task_steps[str(phase._phase.tasks[1].id)]=1
	phase._snapshot={"defeated":phase._defeated_ids.duplicate(),"collected":phase._collected_ids.duplicate(),"tasks":phase._raised_bridges.duplicate(),"task_steps":{}}
	phase._save_active_run()
	var state: Dictionary=Run.read("").state
	check(Run.valid(state) and int(state.checkpoint)==5,"partida guarda checkpoint 6 e estado válido")
	phase.free()
	phase=load("res://scenes/desert/phase_06.tscn").instantiate()
	root.add_child(phase)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	check(phase._player.position.distance_to(saved_at+Vector3.UP*0.05)<0.02,"reabrir retoma o último ponto seguro")
	check(phase._player.health==2 and phase._charge_snapshot()=={"attack":2,"defense":0,"amber":0,"dash":1,"rupture":3},"reabrir mantém vida e cinco recursos exatos")
	check(phase._checkpoint_index==5 and phase._collected_ids.size()==1 and phase._defeated_ids.size()==1 and phase._raised_bridges.size()==1,"reabrir conserva itens, inimigos e Task concluída")
	check(int(phase._task_steps.get(str(phase._phase.tasks[1].id),0))==1,"reabrir conserva a primeira etapa de uma Task ainda não terminada")
	phase._on_goal_entered(phase._player)
	check(not phase.completed,"saída não libera capítulo com Task obrigatória faltando")
	# Pré-condição explícita da integração de vitória; travessias por entradas são separadas.
	for task: Dictionary in phase._phase.tasks:phase._raised_bridges[str(task.id)]=true
	phase._on_goal_entered(phase._player)
	check(phase.completed and int(Run.read("").state.phase)==7,"vitória prepara a próxima fase no salvamento completo")
	check(Run.read("").state.charges==state.charges,"vitória leva recursos exatos para a próxima fase")
	phase.free()
	phase=load("res://scenes/desert/phase_07.tscn").instantiate()
	root.add_child(phase)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	var player: Node=phase._player
	player.health=3
	player.facing=1
	player.is_defending=true
	player._invulnerable=0
	player.take_damage(1,player.position.x+3)
	check(player.health==3,"escudo bloqueia golpe que vem pela frente")
	player.is_defending=true
	player._invulnerable=0
	player.take_damage(1,player.position.x-3)
	check(player.health==2,"escudo frontal não bloqueia golpe pelas costas")
	phase.free()
	print("RUN_RESUME checks=%d failures=%d" % [checks,failures])
	await preload("res://tests/common/audio_cleanup.gd").finish(self)
	quit(1 if failures else 0)
