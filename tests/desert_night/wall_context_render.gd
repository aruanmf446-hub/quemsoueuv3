extends SceneTree
## Câmera de gameplay e saltos reais. Somente a aproximação entre trechos usa fixture.
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
	for i in n:await physics_frame
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	root.size=Vector2i(844,390)
	var args:=OS.get_cmdline_user_args()
	var out:=args[0]
	if args.size()>1:
		var size:=args[1].split("x")
		root.size=Vector2i(int(size[0]),int(size[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var phase: Node3D=load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	for requested_slot in [0,12,31,70,106]:
		var slot: int=requested_slot
		# Uma Task pode retirar o piso desse módulo. Parte sempre de um teto existente.
		while phase._phase.surfaces[slot].get("task_void",false):slot-=1
		var floor: Dictionary=phase._phase.surfaces[slot]
		var camera_base:=0.0
		var city_base:=0.0
		for high in [0.0,3.0]:
			phase._player._model.set_rate(1.0)
			phase._player.set_physics_process(true)
			if high==0.0:
				phase._player.position=Vector3(float(floor.right)-1.3,float(floor.height)+0.04,0)
				phase._player.velocity=Vector3.ZERO
				phase._announced_place=false
				phase._stream_world(phase._player.position.x,true)
				for i in 2400:
					if phase._build_queue.is_empty():break
					phase._process(0)
				for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
				await ticks(15)
				check(phase._player.is_on_floor(),"ator pousado no teto real do trecho %d" % slot)
			else:
				Input.action_press("jump")
				await ticks(2)
				Input.action_release("jump")
				await ticks(18)
				Input.action_press("jump")
				await ticks(2)
				Input.action_release("jump")
				for i in 18:
					if phase._player.position.y>float(floor.height)+2.7:break
					await physics_frame
				check(not phase._player.is_on_floor() and phase._player.position.y>float(floor.height)+2.7,"salto duplo real para conferir a base ao subir")
			phase._player.set_physics_process(false)
			phase._player._model.set_rate(0.0)
			for i in 3:phase._follow_camera(1.0)
			phase._scenery.follow(phase._camera,phase._player.position.x)
			var skyline: Node3D=phase._scenery._skyline
			if high==0.0:
				camera_base=phase._camera.global_position.y
				city_base=skyline.global_position.y
			else:
				check(absf(skyline.global_position.y-city_base)<absf(phase._camera.global_position.y-camera_base)*0.5,"cidade não acompanha a subida da câmera como plataforma suspensa")
			for base: Node3D in skyline._walls+skyline._palaces:
				var mesh: MeshInstance3D=base.get_node("City_stone")
				var bounds:=mesh.get_aabb()
				var foot:=mesh.to_global(bounds.position+Vector3(bounds.size.x*0.5,0,bounds.size.z*0.5))
				check(phase._camera.unproject_position(foot).y>root.get_visible_rect().size.y+20,"fundação continua abaixo da tela: "+str(base.name))
			for i in 3:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(out+"/p02_slot%d_high%d.jpg" % [slot,int(high)],0.92)
	phase.free()
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"fixture_teleport":true,"physical_device":false,"real_jump_input":true},"\t"))
	print("WALL_CONTEXT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
