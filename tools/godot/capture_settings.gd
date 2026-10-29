extends SceneTree
func _initialize() -> void:
	call_deferred('_capture')
func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var resolution := args[1].split('x')
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(resolution[0]), int(resolution[1]))
	await process_frame
	var services := PlayerServices.new()
	root.add_child(services)
	services.preferences.set_preference('locale', 'en' if args.size() > 2 else 'pt_BR')
	var screen := load('res://scenes/player/settings.tscn').instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	for index in range(4):
		screen.call('_select', index)
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var bounds := Rect2(Vector2.ZERO, screen.size)
		for tab: Button in screen.get('_tabs'):
			if not bounds.encloses(tab.get_global_rect()):
				push_error('SETTINGS_TAB_OUT_OF_BOUNDS')
				quit(1)
				return
		if not bounds.encloses(screen.get('_feedback').get_global_rect()):
			push_error('SETTINGS_FEEDBACK_OUT_OF_BOUNDS')
			quit(1)
			return
		var picture := root.get_texture().get_image()
		var error := picture.save_png(output + '_%d.png' % index)
		if error != OK:
			quit(1)
			return
		print('CAPTURE ', index, ' logical=', screen.size, ' pixels=', picture.get_size())
		if index == 0 and int(resolution[1]) < 600:
			screen.get('_scroll').scroll_vertical = 100000
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output + '_audio_scrolled.png')
	quit()
