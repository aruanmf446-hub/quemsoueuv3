extends SceneTree
## Actual renderer readback; safe area is simulated with the --iphone profile.
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("LAYOUT_", "PASS " if ok else "FAIL ", label)
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var dims := args[1].split("x")
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(dims[0]), int(dims[1]))
	UIScale.apply_device_profile(root)
	await process_frame
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await create_timer(0.7).timeout
	var nav := menu.get_node("Navigation")
	nav.back()
	await create_timer(0.5).timeout
	var hero := menu.get_node("HeroCarousel") as Control
	hero.set_process(false)
	for index in range(3):
		hero._select_slide(index)
		await create_timer(0.6).timeout
		var layer: Control = hero._layers[index]
		var title: Control = layer.get_node("Title")
		var description: Control = layer.get_node("Description")
		var reward: Control = layer.get_node("Reward")
		var action: Control = layer.get_node("Play")
		check(not title.get_rect().intersects(description.get_rect()), "title separated from description %d" % index)
		check(not description.get_rect().intersects(reward.get_rect()), "description separated from reward %d" % index)
		check(not reward.get_rect().intersects(action.get_rect()), "reward separated from CTA %d" % index)
		var bounds := Rect2(Vector2.ZERO, hero.size)
		for control in [title, description, reward, action, hero._previous, hero._next, hero._logo] + hero._tabs + hero._dots:
			check(bounds.encloses(control.get_rect()), "bounds %d %s" % [index, control.name])
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		check(picture.get_size() == root.size, "actual requested resolution")
		check(picture.save_png(output + "/slide_%d.png" % index) == OK, "capture slide %d" % index)
	print("HERO_CAPTURE_RESULT failures=", failures, " resolution=", root.size, " logical=", hero.size)
	quit(1 if failures else 0)
