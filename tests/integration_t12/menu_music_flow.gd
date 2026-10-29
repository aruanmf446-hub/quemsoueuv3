extends SceneTree
## Integration against the approved lobby; no fixture tracks or visual changes.
var failures := 0
var music: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func frames(count: int = 5) -> void:
	for i in count: await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await frames(1)
	event.pressed = false
	root.push_input(event)
	await frames(1)

func silent() -> bool:
	return not music._players[0].playing and not music._players[1].playing

func run() -> void:
	check(Engine.get_version_info().string.begins_with("4.7.2"), "Godot 4.7.2 runtime")
	check(ProjectSettings.get_setting("internationalization/locale/fallback") == "pt_BR", "Portuguese fallback preserved")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == 0, "landscape orientation preserved")
	music = root.get_node("MenuMusic")
	check(music is MenuMusicPlayer, "central autoload available")
	# O catálogo traz as faixas liberadas pelo proprietário: toda entrada carregada precisa
	# passar pela validação completa (aprovada, vigente, com áudio e capa importados).
	var all_licensed := true
	for track: Dictionary in music.tracks:
		if not music.licensed(track): all_licensed = false
	check(all_licensed and music.available_tracks().size() == music.tracks.size(), "every bundled track is licensed with audio and cover")
	var scene: Control = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(30)
	var prefs: Node = scene.get_node("Services").preferences
	var old_volume := float(prefs.values.music)
	check(music._inside and music._menu == scene, "autoload recognizes approved lobby")
	check(music._preferences == prefs, "music uses lobby preference instance")
	var reserved: AudioStreamPlayer = scene.get_node("MenuMusic")
	check(reserved.stream == null and not reserved.playing and not reserved.autoplay, "Claude reserved audio node preserved and silent")
	check(music._players[0].bus == &"Music" and music._players[1].bus == &"Music", "both channels use configured Music bus")
	var nav: Node = scene.get_node("Navigation")
	nav.open("settings", {})
	await frames(30)
	check(music._inside and nav._active.is_visible_in_tree(), "settings route keeps menu music context")
	var sliders: Array[Node] = nav._active.find_children("*", "HSlider", true, false)
	check(sliders.size() >= 3, "existing settings controls intact")
	if sliders.size() >= 3:
		sliders[1].value = 0.42
		await frames()
		check(is_equal_approx(float(prefs.values.music), 0.42), "existing music slider persists volume")
		check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) - 0.42) < 0.01, "existing slider controls transport bus")
	music.set_muted(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "transport mute integrates existing settings")
	music.set_muted(false)
	check(is_equal_approx(float(prefs.values.music), 0.42), "transport unmute restores prior volume")
	nav.back()
	await frames(30)
	await key(KEY_F7)
	check(music.paused, "F7 pause routed without new UI")
	await key(KEY_F7)
	check(not music.paused, "F7 resume routed without new UI")
	await key(KEY_F6)
	await key(KEY_F8)
	check(not music.current_id.is_empty() and not silent(), "skip controls keep a licensed track playing")
	music.pause()
	prefs.set_preference("music", old_volume)
	root.remove_child(scene)
	current_scene = null
	check(not music._inside and silent(), "menu exit immediately stops central transport")
	scene.free()
	var outside := Node.new()
	outside.scene_file_path = "res://scenes/desert/phase_01.tscn"
	root.add_child(outside)
	current_scene = outside
	await frames()
	check(not music._inside and silent(), "non-menu context cannot play menu audio")
	outside.free()
	current_scene = null
	var returned: Control = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(returned)
	current_scene = returned
	await frames(30)
	check(music._inside and music._menu == returned, "return binds new approved lobby instance")
	check(music.paused, "manual pause preserved across scene changes")
	check(music._preferences == returned.get_node("Services").preferences, "return rebinds live preferences")
	music.resume()
	await frames(10)
	check(not music.paused and not music.current_id.is_empty(), "return resumes the licensed playlist")
	returned.queue_free()
	current_scene = null
	await frames()
	print("T12_INTEGRATION_FAILURES ", failures)
	quit(1 if failures else 0)
