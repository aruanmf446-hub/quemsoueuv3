extends SceneTree
## Enquadra os telhados como na reclamação e verifica o muro abaixo da borda da tela.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func run() -> void:
	preload("res://tests/desert_night/tutorial_fixture.gd").experienced()
	var args:=OS.get_cmdline_user_args()
	var out:=args[0]
	var size:=args[1].split("x")
	root.size=Vector2i(int(size[0]),int(size[1]))
	DirAccess.make_dir_recursive_absolute(out)
	var phase: Node3D=load("res://scenes/desert/phase_02.tscn").instantiate()
	root.add_child(phase)
	current_scene=phase
	phase.set_physics_process(false)
	var house: Dictionary=phase._phase.surfaces[12]
	phase._player.position=Vector3(lerpf(house.left,house.right,0.55),float(house.height)+0.04,0)
	phase._player.velocity=Vector3.ZERO
	phase._player._invulnerable=999
	phase._stream_world(phase._player.position.x,true)
	for i in 2400:
		if phase._build_queue.is_empty():break
		phase._process(0)
	for enemy in phase._troops.get_children():phase._retire_enemy(enemy)
	for i in 16:await physics_frame
	check(phase._player.is_on_floor(),"personagem apoiado no teto")
	phase._player.set_physics_process(false)
	phase._player._model.visible=true
	phase._follow_camera(1.0)
	for wall: Node3D in phase._scenery._skyline._walls:
		var masonry: MeshInstance3D=wall.get_node("City_stone")
		var bounds:=masonry.get_aabb()
		var foot:=masonry.to_global(bounds.position+Vector3(bounds.size.x*0.5,0,bounds.size.z*0.5))
		var screen: Vector2=phase._camera.unproject_position(foot)
		check(screen.y>root.get_visible_rect().size.y+20,"muro contínuo ultrapassa a borda inferior: "+str(wall.name))
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out+"/muro_ate_embaixo.png")==OK,"captura real salva")
	FileAccess.open(out+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_device":false,"fixture_teleport":true},"\t"))
	phase.free()
	print("SKYLINE_DEPTH_RENDER checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
