extends SceneTree
## Reprodução real do MenuMusic com os MP3 importados. Roda com janela e áudio do sistema:
## godot --path . -s res://tools/godot/music_playback.gd
## A autorização de teste existe só em memória; o catálogo do repositório não muda.
## Ao final, a seleção salva é removida e o catálogo real é recarregado.

const SELECTION_FILE := "user://menu_music_selection.cfg"
const COVER := "res://assets/processed/logos/logo_quem_sou_eu_retangular.png"
const SILENCE := -60.0

var failures := 0
var music: Node


class Preferences:
	extends Node
	var values := {"music": 1.0}
	func set_preference(key: String, value: float) -> bool:
		values[key] = value
		var index := AudioServer.get_bus_index("Music")
		if index >= 0:
			AudioServer.set_bus_mute(index, value <= 0.001)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
		return true


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	music = root.get_node("MenuMusic")
	music.save_selection([], [])
	music.tracks = _fixtures()
	var menu := load("res://scenes/menu/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	for frame in range(60):
		await process_frame
	check(music._inside, "menu ativa o player")
	check(music.current_id != "" and _playing() == 1, "menu toca a primeira faixa autorizada")
	var pref := Preferences.new()
	root.add_child(pref)
	music._preferences = pref
	var first: String = music.current_id
	await _wait(1.5)
	check(_position() > 0.5, "reprodução real avança (%.2fs)" % _position())

	music.next_track()
	await _wait(0.2)
	var outgoing: AudioStreamPlayer = music._players[1 - music._active]
	var incoming: AudioStreamPlayer = music._players[music._active]
	check(music.current_id != first, "próxima troca de faixa")
	check(incoming.volume_db > SILENCE + 1.0 and outgoing.playing, "transição: entrada sobe e saída ainda audível")
	await _wait(1.2)
	check(not outgoing.playing and is_equal_approx(incoming.volume_db, 0.0), "transição termina: só a faixa nova toca")

	music.previous_track()
	await _wait(0.2)
	check(music.current_id == first, "anterior volta à faixa inicial")

	music.pause()
	var paused_at := _position()
	await _wait(0.6)
	check(music.paused and absf(_position() - paused_at) < 0.05, "pausa congela a posição")
	music.resume()
	await _wait(0.6)
	check(not music.paused and _position() > paused_at + 0.2, "retomar continua de onde parou")

	music.set_volume(0.2)
	var bus := AudioServer.get_bus_index("Music")
	check(bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.2)), "volume chega ao barramento Music")
	music.set_muted(true)
	check(bus >= 0 and AudioServer.is_bus_mute(bus) and pref.values.music == 0.0, "mudo silencia o barramento")
	music.set_muted(false)
	check(bus >= 0 and not AudioServer.is_bus_mute(bus) and is_equal_approx(pref.values.music, 0.2), "desmutar restaura o volume anterior")

	var playing_now: String = music.current_id
	music.save_selection([playing_now], [])
	await _wait(0.4)
	check(music.current_id != playing_now and not _is_playing_id(playing_now), "ocultar a faixa em reprodução a tira do ar e troca")

	music.save_selection([], [])
	menu.queue_free()
	for frame in range(10):
		await process_frame
	check(not music._inside and _playing() == 0, "sair do menu (gameplay) interrompe os dois canais")
	await _wait(0.8)
	check(_playing() == 0, "nada toca fora do menu")
	_cleanup()
	print("MUSIC_PLAYBACK_FAILURES ", failures)
	quit(1 if failures > 0 else 0)


func _playing() -> int:
	var count := 0
	for player in music._players:
		if player.playing:
			count += 1
	return count


func _is_playing_id(id: String) -> bool:
	for player in music._players:
		if player.playing and str(player.get_meta("track", {}).get("id", "")) == id:
			return true
	return false


func _position() -> float:
	var player: AudioStreamPlayer = music._players[music._active]
	return player.get_playback_position() if player.playing else 0.0


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _fixtures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names := {"t-a": "Almost In Love", "t-b": "Bad at Being Good", "t-c": "Too Good to Miss"}
	var files := {"t-a": "res://assets/music/pop/Almost In Love.mp3", "t-b": "res://assets/music/pop/Bad at Being Good.mp3", "t-c": "res://assets/music/pop/Too Good to Miss.mp3"}
	for id: String in ["t-a", "t-b", "t-c"]:
		result.append({"id": id, "category": "pop", "title": names[id], "artist": "", "audio": files[id], "cover": COVER, "enabled": true,
			"license": {"status": "approved", "scope": "main_menu", "reference": "TESTE-LOCAL-MEMORIA", "starts_at": 0, "ends_at": 4102444800}})
	return result


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SELECTION_FILE))
	music.reload_catalog()
	check(music.tracks.size() == 14 and music.available_tracks().is_empty(), "catálogo real restaurado ao final")
