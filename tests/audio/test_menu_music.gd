extends SceneTree

class Services:
	extends Node
	var preferences: Node

var music: Node
var failures := 0

class Preferences:
	extends Node
	var values := {"music": 1.0}
	func set_preference(key: String, value: float) -> bool:
		values[key] = value
		var index := AudioServer.get_bus_index("Music")
		AudioServer.set_bus_mute(index, value <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		return true

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	music = load("res://scripts/audio/menu_music.gd").new()
	root.add_child(music)
	music.set_process(false)
	check(music.tracks.size() == 14 and music.available_tracks().is_empty() \
		and music._players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing), "14 pending catalog entries stay silent")
	var pref := Preferences.new()
	root.add_child(pref)
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	music._preferences = pref
	music._inside = true
	check(music.reload_catalog("res://tests/audio/catalog.json"), "load authorized technical silence fixtures")
	check(music.available_tracks().size() == 2, "disabled expired pending future and missing tracks excluded")
	check(music.current_id == "a" and music._players[music._active].playing, "autoplay first available")
	music.next_track()
	check(music.current_id == "b", "next skips unavailable")
	music.previous_track()
	check(music.current_id == "a", "previous wraps")
	music.pause()
	check(music.paused and music._players[music._active].stream_paused, "pause during fade")
	music.resume()
	check(not music.paused and not music._players[music._active].stream_paused, "resume")
	music.next_track()
	music.next_track()
	await create_timer(0.15).timeout
	var playing := 0
	for player in music._players:
		if player.playing: playing += 1
	check(playing == 1, "rapid skips cancel stale fades")
	check(music.set_volume(0.35), "volume delegates preferences")
	music.set_muted(true)
	check(pref.values.music == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "mute uses existing bus")
	music.set_muted(false)
	check(is_equal_approx(pref.values.music, 0.35), "unmute restores volume")
	music._leave_menu()
	check(not music._players[0].playing and not music._players[1].playing, "leaving menu stops both channels immediately")
	music._inside = true
	music._restore()
	check(music._players[music._active].playing, "return restores transport")
	await create_timer(2.1).timeout
	check(music.current_id == "b", "natural finish advances")
	music.tracks[music._index("b")].license.status = "revoked"
	music.next_track()
	check(music.current_id == "a", "revocation prevents selection")
	music.tracks[0].license.ends_at = 1
	music._select(1)
	check(music.current_id.is_empty() and not music._players[music._active].playing, "no valid licenses stops playback")
	# Exercise automatic scene ownership without loading unrelated game systems.
	music.reload_catalog("res://tests/audio/catalog.json")
	var menu := Node.new()
	menu.scene_file_path = music.MENU
	var services := Services.new()
	services.name = "Services"
	services.preferences = pref
	menu.add_child(services)
	root.add_child(menu)
	current_scene = menu
	music._process(0.01)
	check(music._inside and music._players[music._active].playing, "main menu detection starts playback")
	await create_timer(1.97).timeout
	music._process(0.01)
	check(music.current_id == "b", "pre-finish crossfade advances without a gap")
	music.tracks[music._index("b")].license.ends_at = 1
	music._players[1 - music._active].stop()
	music._process(0.01)
	check(music.current_id == "a", "active expired license is stopped and skipped")
	menu.free()
	check(not music._inside and not music._players[music._active].playing, "scene tree exit stops playback before gameplay")
	var gameplay := Node.new()
	gameplay.scene_file_path = "res://scenes/desert/phase_01.tscn"
	root.add_child(gameplay)
	current_scene = gameplay
	music._process(0.01)
	check(not music._inside, "gameplay never starts menu music")
	gameplay.free()
	check(not music.reload_catalog("res://tests/audio/invalid.json") and music.tracks.is_empty(), "malformed catalog fails closed")
	music.queue_free()
	pref.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
