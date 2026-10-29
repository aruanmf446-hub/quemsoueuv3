class_name MenuMusicPlayer
extends Node
## Menu-only transport. No audio is bundled; licensing is an explicit opt-in.
signal track_changed(track: Dictionary)
signal state_changed
signal catalog_error(message: String)

const CATALOG := "res://data/music/catalog.json"
const MENU := "res://scenes/menu/main_menu.tscn"
const SILENCE := -60.0
var tracks: Array[Dictionary] = []
var current_id := ""
var paused := false
var fade_seconds := 0.8
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade: Tween
var _menu: Node
var _position := 0.0
var _inside := false
var _preferences: Node
var _last_volume := 1.0
var _retry_in := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		player.finished.connect(_finished.bind(i))
		_players.append(player)
	reload_catalog()

func reload_catalog(path: String = CATALOG) -> bool:
	if not _players.is_empty() and _players[_active].playing:
		_position = _players[_active].get_playback_position()
	_stop()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		tracks.clear()
		_stop()
		catalog_error.emit("Catálogo indisponível")
		return false
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	var data: Variant = parser.data if parsed == OK else null
	if not data is Dictionary or data.get("version") != 1 or not data.get("tracks") is Array:
		tracks.clear()
		_stop()
		catalog_error.emit("Catálogo inválido")
		return false
	tracks.clear()
	var ids := {}
	for entry: Variant in data.tracks:
		if not entry is Dictionary or not _valid_entry(entry) or ids.has(entry.id):
			continue
		ids[entry.id] = true
		tracks.append(entry.duplicate(true))
	var transition: Variant = data.get("fade_seconds", 0.8)
	if (transition is float or transition is int) and is_finite(float(transition)):
		fade_seconds = clampf(float(transition), 0.05, 5.0)
	if _index(current_id) < 0 or not _available(current_track()):
		_stop()
		current_id = ""
		_position = 0.0
	if _inside and not paused:
		_restore()
	state_changed.emit()
	return true

func _valid_entry(t: Dictionary) -> bool:
	for field: String in ["id", "title", "artist", "audio", "cover"]:
		if not t.get(field) is String or str(t[field]).is_empty():
			return false
	if not str(t.audio).begins_with("res://assets/music/") or not str(t.cover).begins_with("res://assets/music/"):
		return false
	if ".." in str(t.audio) or ".." in str(t.cover):
		return false
	var license_data: Variant = t.get("license")
	if not license_data is Dictionary:
		return false
	for field: String in ["starts_at", "ends_at"]:
		var value: Variant = license_data.get(field)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
			return false
	return true

func _available(t: Dictionary) -> bool:
	if t.is_empty():
		return false
	var rights: Dictionary = t.license
	var now := Time.get_unix_time_from_system()
	return t.get("enabled", false) == true and rights.get("status") == "approved" \
		and rights.get("scope") == "main_menu" and rights.get("reference", "") is String \
		and not str(rights.get("reference", "")).is_empty() and now >= float(rights.starts_at) \
		and now < float(rights.ends_at) and ResourceLoader.exists(t.audio, "AudioStream") \
		and ResourceLoader.exists(t.cover, "Texture2D")

func current_track() -> Dictionary:
	var index := _index(current_id)
	return tracks[index].duplicate(true) if index >= 0 else {}

func available_tracks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for track in tracks:
		if _available(track): result.append(track.duplicate(true))
	return result

func _index(id: String) -> int:
	for i in tracks.size():
		if tracks[i].id == id: return i
	return -1

func _process(delta: float) -> void:
	_retry_in = maxf(0.0, _retry_in - delta)
	var scene := get_tree().current_scene
	var in_menu := scene != null and scene.scene_file_path == MENU
	if in_menu and _menu != scene:
		_menu = scene
		_menu.tree_exiting.connect(_leave_menu, CONNECT_ONE_SHOT)
		var services := scene.get_node_or_null("Services")
		_preferences = services.get("preferences") if services != null else null
		_inside = true
		if not paused: _restore()
	elif not in_menu and _inside:
		_leave_menu()
	# Recheck licenses while playing, including both sides of a crossfade.
	if _inside:
		for player in _players:
			var playing_id := str(player.get_meta("track", {}).get("id", ""))
			var catalog_index := _index(playing_id)
			if player.playing and (catalog_index < 0 or not _available(tracks[catalog_index])):
				player.stop()
		if not paused:
			var player := _players[_active]
			if not player.playing and _retry_in <= 0.0:
				_retry_in = 0.5
				_select(1)
			elif player.playing and (_fade == null or not _fade.is_running()):
				var remaining := player.stream.get_length() - player.get_playback_position()
				if remaining > 0.0 and remaining <= fade_seconds:
					next_track()

func _leave_menu() -> void:
	if not _inside: return
	_position = _players[_active].get_playback_position()
	_inside = false
	_menu = null
	_preferences = null
	_stop()

func _restore() -> void:
	var t := current_track()
	if _available(t):
		_play(t, _position)
	else:
		_select(1)

func next_track() -> void:
	_position = 0.0
	_select(1)

func previous_track() -> void:
	_position = 0.0
	_select(-1)

func _select(direction: int) -> void:
	if not _inside: return
	var start := _index(current_id)
	if start < 0: start = -1 if direction > 0 else 0
	for step in range(1, tracks.size() + 1):
		var index := posmod(start + direction * step, tracks.size())
		if _available(tracks[index]):
			_play(tracks[index])
			return
	_stop()
	current_id = ""
	state_changed.emit()

func _play(track: Dictionary, position: float = 0.0) -> void:
	if not _inside or not _available(track): return
	var stream := load(track.audio) as AudioStream
	if stream == null: return
	# Imported loop flags must not prevent playlist advancement.
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	if _fade != null: _fade.kill()
	var outgoing := _players[_active]
	_active = 1 - _active
	var incoming := _players[_active]
	incoming.stop()
	incoming.stream = stream
	incoming.set_meta("track", track.duplicate(true))
	incoming.volume_db = SILENCE
	incoming.play(position if position < stream.get_length() else 0.0)
	incoming.stream_paused = paused
	outgoing.stream_paused = paused
	current_id = track.id
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", 0.0, fade_seconds)
	_fade.tween_property(outgoing, "volume_db", SILENCE, fade_seconds)
	_fade.chain().tween_callback(outgoing.stop)
	if paused: _fade.pause()
	track_changed.emit(current_track())
	state_changed.emit()

func pause() -> void:
	paused = true
	for player in _players: player.stream_paused = true
	if _fade != null: _fade.pause()
	state_changed.emit()

func resume() -> void:
	paused = false
	if _inside:
		if _players[_active].playing:
			for player in _players: player.stream_paused = false
			if _fade != null: _fade.play()
		else: _restore()
	state_changed.emit()

func set_volume(value: float) -> bool:
	if not is_instance_valid(_preferences) or not is_finite(value): return false
	return _preferences.set_preference("music", clampf(value, 0.0, 1.0))

func set_muted(muted: bool) -> bool:
	if not is_instance_valid(_preferences): return false
	var volume := float(_preferences.values.music)
	if muted and volume > 0.0: _last_volume = volume
	return set_volume(0.0 if muted else _last_volume)

func _stop() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	for player in _players: player.stop()

func _finished(index: int) -> void:
	if index == _active and _inside and not paused: next_track()

func _unhandled_key_input(event: InputEvent) -> void:
	if not _inside or not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F6: previous_track()
		KEY_F7:
			if paused: resume()
			else: pause()
		KEY_F8: next_track()
		KEY_F9:
			if is_instance_valid(_preferences): set_muted(float(_preferences.values.music) > 0.0)
		_: return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_stop()
