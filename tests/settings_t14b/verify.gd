extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(('PASS ' if ok else 'FAIL ') + message)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred('_run')
func _run() -> void:
	var legacy := ConfigFile.new()
	legacy.set_value('device', 'master', 0.23)
	legacy.set_value('device', 'music', 0.52)
	legacy.set_value('device', 'locale', 'pt_BR')
	legacy.save(DevicePreferences.SAVE_PATH)
	var services := PlayerServices.new()
	root.add_child(services)
	var prefs := services.preferences
	check(is_equal_approx(prefs.values.master, 0.23) and is_equal_approx(prefs.values.music, 0.52) and not prefs.values.muted, 'legacy preferences preserved without mute field')
	var stage := load('res://scenes/lobby/lobby_stage.tscn').instantiate() as LobbyStage
	root.add_child(stage)
	for profile: String in ['baixo', 'medio', 'alto']:
		prefs.set_preference('quality', profile)
		await process_frame
		var expected := GraphicsProfile.settings(profile)
		check(stage.get_node('Viewport').msaa_3d == expected.msaa_3d and stage.stretch_shrink == expected.stretch_shrink and stage.get_node('Viewport/World/KeyLight').shadow_enabled == expected.shadows, 'real preview profile ' + profile)
	stage.queue_free()
	check(prefs.set_preference('master', 0.37), 'master saves')
	check(prefs.set_preference('music', 0.61), 'music saves')
	check(prefs.set_preference('sfx', 0.48), 'effects save')
	check(prefs.set_preference('muted', true), 'mute saves')
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index('Master')), 'Master actually muted')
	check(is_equal_approx(prefs.values.master, 0.37), 'mute preserves gain')
	check(not prefs.set_preference('muted', 1), 'reject invalid mute')
	check(not prefs.set_preference('master', 1.1), 'reject invalid gain')
	check(prefs.set_preference('accept_key', KEY_F), 'remap confirm')
	check(not prefs.set_preference('back_key', KEY_F), 'reject duplicate key')
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	check(InputMap.event_is_action(key, 'ui_accept'), 'InputMap applies remap')
	check(prefs.set_preference('quality', 'baixo'), 'quality saves')
	check(prefs.set_preference('locale', 'en'), 'locale saves')
	var fresh := DevicePreferences.new()
	root.add_child(fresh)
	check(fresh.values == prefs.values, 'preferences survive reload')
	fresh.queue_free()
	var screen := load('res://scenes/player/settings.tscn').instantiate() as PlayerScreen
	root.add_child(screen)
	screen.show_screen()
	await process_frame
	check(not screen.has_node('CrestFrame'), 'ornamental frame removed')
	check(screen.heading.text == 'Settings', 'English heading')
	check(screen.get('_tabs').size() == 4, 'four categories')
	for index in range(4):
		screen.call('_select', index)
		await process_frame
		check(screen.get('_tabs')[index].button_pressed, 'category %d selected' % index)
	# Real screen input, including duplicate rejection and save feedback.
	screen.call('_select', 2)
	var button := Button.new()
	screen.add_child(button)
	screen.call('_wait_for_key', 'accept_key', button)
	key.pressed = true
	key.physical_keycode = KEY_ESCAPE
	screen.call('_input', key)
	check(screen.get('_waiting_action') == 'accept_key', 'duplicate remap stays waiting')
	key.physical_keycode = KEY_G
	screen.call('_input', key)
	check(prefs.values.accept_key == KEY_G and screen.get('_waiting_action') == '', 'screen remap functional')
	prefs.set_preference('locale', 'pt_BR')
	prefs.set_preference('muted', false)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index('Master')), 'unmute restores audio')
	print('SETTINGS_RESULT failures=', failures)
	quit(1 if failures else 0)
