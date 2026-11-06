extends SceneTree
const Tutorial=preload("res://scripts/desert/t15d/first_use_tutorial.gd")
var checks:=0
var failures:=0
var output:=""
var captures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+text)
func frames(n: int) -> void:
	for i in n:await process_frame
func ticks(n: int) -> void:
	for i in n:await physics_frame
func flush(phase: Node3D) -> void:
	for i in 2400:
		if phase._build_queue.is_empty():break
		phase._process(0)
func snap(phase: Node3D,label: String) -> void:
	if output.is_empty():return
	var running: bool=phase._player.is_physics_processing()
	phase._player.set_physics_process(false)
	phase._player._model.visible=true
	phase._follow_camera(1.0)
	await frames(4)
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output+"/"+label+".png")
	captures.append({"name":label,"error":error,"fixture_teleport":true,"physical_device":false})
	phase._player.set_physics_process(running)
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()>=2:
		output=args[0]
		DirAccess.make_dir_recursive_absolute(output)
		var dimensions:=args[1].split("x")
		root.size=Vector2i(int(dimensions[0]),int(dimensions[1]))
	var old:=ConfigFile.new()
	for kind in ["amber","dash","rupture"]:old.set_value("discovered",kind,true)
	old.save("user://desert_abilities_v3.cfg")
	var seen:=ConfigFile.new()
	for kind in ["attack","defense","task"]:seen.set_value("guest",kind,true)
	seen.save(Tutorial.SAVE_PATH)
	for spec: Array in [[3,"amber"],[4,"dash"],[5,"rupture"]]:
		var order:=int(spec[0])
		var kind:=str(spec[1])
		var phase: Node3D=load("res://scenes/desert/phase_%02d.tscn" % order).instantiate()
		root.add_child(phase)
		current_scene=phase
		phase.set_physics_process(false)
		await ticks(4)
		check(phase._player.charges(kind)==0 and not phase._player.discovered.has(kind),kind+": inicia zerado e oculto, inclusive com save antigo de concessão automática")
		phase._touch_pad._layout()
		check(not phase._touch_pad._buttons.has(kind) and not phase._hud._action_buttons.has(kind),kind+": nenhum botão fantasma no toque ou teclado")
		check(not phase._first_use.active and not paused,kind+": fase começa sem explicação prematura")
		await snap(phase,kind+"_antes_sem_carga")
		var spawn: Dictionary=phase._phase.pickups.filter(func(p: Dictionary) -> bool:return p.kind==kind)[0]
		phase._player.position=Vector3(float(spawn.pos[0]),float(spawn.pos[1])+0.05,0)
		phase._player.velocity=Vector3.ZERO
		phase._player._invulnerable=999
		phase._stream_world(phase._player.position.x,true)
		flush(phase)
		for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
		for i in 60:
			await process_frame
			if phase._first_use.active:break
		check(phase._first_use.active and phase._first_use.kind==kind and paused,kind+": primeira coleta pausa e apresenta a lição correta")
		check(phase._player.charges(kind)==1 and phase._first_use._illustration.visible and phase._first_use._illustration.texture!=null,kind+": uma carga real e ilustração presente")
		await snap(phase,kind+"_primeira_recarga_licao")
		var at: Vector3=phase._player.position
		var elapsed: float=phase._elapsed
		Input.action_press(kind)
		Input.action_press("move_right")
		await frames(6)
		check(phase._player.position==at and phase._elapsed==elapsed and phase._player.charges(kind)==1,kind+": ilustração pausa movimento, relógio e uso do poder")
		phase._first_use._continue.pressed.emit()
		await ticks(3)
		check(not paused and phase._first_use.seen(kind) and not Input.is_action_pressed(kind) and not Input.is_action_pressed("move_right"),kind+": continuar salva e limpa os comandos")
		if kind=="rupture":
			var floor: Dictionary=phase._phase.platforms.filter(func(p: Dictionary) -> bool:return p.get("breakable",false))[0]
			phase._player.position=Vector3(float(floor.span_end)+3,float(floor.surface_top)+0.05,0)
			phase._player.velocity=Vector3.ZERO
			phase._stream_world(phase._player.position.x,true)
			flush(phase)
			await ticks(4)
		check(phase._player.use_ability(kind),kind+": poder coletado funciona")
		phase._touch_pad._layout()
		check(phase._player.charges(kind)==0 and phase._touch_pad._buttons.has(kind) and phase._hud._action_buttons[kind].visible and phase._hud._action_buttons[kind].get_node("Count").text=="0",kind+": após usar, botão permanece e contador mostra zero")
		await snap(phase,kind+"_usado_botao_zero")
		phase._first_use.present(kind)
		check(not phase._first_use.active,kind+": explicação não se repete depois de confirmada")
		phase._restart_level()
		phase._touch_pad._layout()
		check(phase._player.charges(kind)==0 and phase._player.discovered.has(kind) and phase._touch_pad._buttons.has(kind),kind+": reinício mantém conhecimento, sem fabricar cargas")
		phase._hud._toast.hide()
		phase._player.attack_charges=0
		phase._player.restore_charge("attack")
		phase._on_pickup_collected("quiet-pickup-fixture","attack")
		check(phase._player.attack_charges==1 and not phase._hud._toast.visible,kind+": fogo atualiza o contador sem texto no centro")
		phase._hud.notify("Ataque cheio • item preservado")
		check(phase._hud._toast.position.x+phase._hud._toast.size.x<phase._hud._root.size.x*0.5,kind+": avisos excepcionais ficam na lateral")
		phase.free()
		current_scene=null
		paused=false
		await frames(3)
	# Reabrir uma fase conhecida conserva o botão e continua sem carga inicial.
	var replay: Node3D=load("res://scenes/desert/phase_03.tscn").instantiate()
	root.add_child(replay)
	check(replay._player.charges("amber")==0 and replay._player.discovered.has("amber") and not replay._player.discovered.has("dash"),"reentrada conserva só o poder já apresentado e permitido no capítulo")
	replay.free()
	print("POWER_INTRODUCTIONS checks=%d failures=%d" % [checks,failures])
	if not output.is_empty():FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures},"\t"))
	quit(1 if failures else 0)
