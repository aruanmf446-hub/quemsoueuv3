extends "res://tools/godot/phase01_scenario.gd"
## Demonstração contínua da travessia, exclusivamente por ações reais após o spawn.
func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	_phase = load("res://scenes/desert/phase_01.tscn").instantiate()
	root.add_child(_phase)
	current_scene = _phase
	_player = _phase._player
	_platforms = (JSON.parse_string(FileAccess.get_file_as_string(PLATFORMS_PATH)) as Dictionary).platforms
	_player.died.connect(func() -> void: _deaths += 1)
	await _frames(40)
	await _walk_to(52,40,true,true)
	check(_phase.completed,"travessia contínua concluída")
	check(_deaths == 0,"travessia sem morte ou respawn")
	await _frames(75)
	print("CONTINUOUS_ROUTE deaths=",_deaths," health=",_player.health," defeated=",_phase._defeated," x=",_player.position.x)
	quit(1 if failures else 0)
