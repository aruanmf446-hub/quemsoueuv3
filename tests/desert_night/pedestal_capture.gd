extends SceneTree
## Capturas de inspeção: coleta solicitada pela fixture, não prova de percurso.
func _initialize() -> void: call_deferred("run")
func shot(path: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1672,941)
	var phase: Node3D = load("res://scenes/desert/phase_03.tscn").instantiate()
	root.add_child(phase)
	phase.set_physics_process(false)
	phase._player.set_physics_process(false)
	var item: Area3D
	for candidate: Area3D in get_nodes_in_group("campaign_pickups"):
		if candidate.kind == "attack": item=candidate; break
	if item == null: quit(1); return
	phase._player.attack_charges=2
	phase._player.position=item.global_position+Vector3(1.8,0.05,0)
	phase._follow_camera(1.0)
	phase._player._model.visible=true
	await shot(out+"/pedestal_antes_fixture.png")
	item._try_collect(phase._player)
	await shot(out+"/pedestal_depois_fixture.png")
	phase.free()
	for i in 3: await process_frame
	quit(0)
