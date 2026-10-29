extends SceneTree
## Roteiro de entrada na Fase 01 em janela real. Uso:
## godot --path . -s res://tools/godot/phase01_run.gd -- <saida_prefixo> [WxH]
## Pressiona ações reais do jogo (move_right, jump, attack), registra estado e salva capturas.

const STEP := 0.25

var _prefix := "phase01"
var _phase: Node3D
var _player: SidePlayer
var _log: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_prefix = args[0] if not args.is_empty() else "phase01"
	var size := (args[1] if args.size() > 1 else "1920x1080").split("x")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(int(size[0]), int(size[1]))
	await process_frame
	_phase = load("res://scenes/desert/phase_01.tscn").instantiate() as Node3D
	root.add_child(_phase)
	current_scene = _phase
	await _frames(40)
	_player = _phase.get("_player")
	await _snap("start")
	await _hold("move_right", 1.2, "run_right")
	await _hold("jump", 0.1, "jump_1")
	await _frames(20)
	await _snap("jump_1_air")
	await _hold("jump", 0.1, "jump_2")
	await _frames(40)
	await _snap("double_jump")
	await _hold("attack", 0.1, "attack")
	await _frames(20)
	await _snap("attack")
	await _hold("move_right", 2.0, "run_right_2")
	await _snap("mid")
	for line in _log:
		print(line)
	print("PHASE01_RUN_DONE ", _prefix)
	quit(0)


func _hold(action: String, seconds: float, label: String) -> void:
	Input.action_press(action)
	await _frames(int(seconds * 60.0))
	Input.action_release(action)
	_record(label)


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("%s_%s.png" % [_prefix, label])
	_record("snap:" + label)


func _record(label: String) -> void:
	var p := _player.global_position
	_log.append("%-18s x=%6.2f y=%6.2f vx=%6.2f vy=%6.2f floor=%s jumps=%d hp=%d dead=%s anim=%s" % [
		label, p.x, p.y, _player.velocity.x, _player.velocity.y, _player.is_on_floor(),
		_player.jumps_used, _player.health, _player.is_dead,
		_player.get_node("Model").get("_anim_player").current_animation if _player.get_node("Model").get("_anim_player") else "-"])


func _frames(count: int) -> void:
	for i in count:
		await process_frame
