extends SceneTree
var finished_count := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "/tmp/avatar-stage"
	DirAccess.make_dir_recursive_absolute(output)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640, 360)
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var clips := ["anim_2", "anim_3", "anim_4"]
	for i in range(clips.size()):
		var stage := preload("res://scripts/ui/battle/avatar_sequence.gd").new()
		host.add_child(stage)
		var started := Time.get_ticks_msec()
		stage.finished.connect(func() -> void: finished_count += 1)
		stage.present([{"nickname":"Cowboy" if i != 1 else "Michelly", "skin_id":"cowboy" if i != 1 else "michelly"}], clips[i], 0.1, i == 0)
		await create_timer(2.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(clips[i] + ".png"))
		print("CAPTURED ", clips[i], " bounds=", stage.get_rect(), " stage=", stage._stage.get_rect())
		while is_instance_valid(stage): await process_frame
		var elapsed := (Time.get_ticks_msec() - started) / 1000.0
		print("DURATION ", clips[i], "=",elapsed)
		if elapsed < 6.0:
			failures += 1
			push_error("Avatar presentation ended before six seconds")
	var music := AudioServer.get_bus_index("Music")
	var effects_before := AudioServer.get_bus_effect_count(music) if music >= 0 else 0
	var cancellable := preload("res://scripts/ui/battle/avatar_sequence.gd").new()
	host.add_child(cancellable)
	cancellable.present([{"nickname":"Cowboy", "skin_id":"cowboy"}], "anim_2", 0.1)
	await create_timer(0.5).timeout
	cancellable._skip.grab_focus()
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "ui_accept"
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await process_frame
	if is_instance_valid(cancellable):
		failures += 1
		cancellable.queue_free()
	if music >= 0 and AudioServer.get_bus_effect_count(music) != effects_before: failures += 1
	print("FINISHED clips=", finished_count, " failures=", failures)
	await load("res://tests/common/audio_cleanup.gd").finish(self, host)
	quit(0 if finished_count == 3 and failures == 0 else 1)
