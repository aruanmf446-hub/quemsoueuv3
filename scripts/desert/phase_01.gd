extends Node3D

## Fase 01 do Reino do Deserto. Monta plataformas, inimigos e meta a partir de
## data/desert/phase_01.json. El Fuego é o protagonista e não depende de desbloqueio:
## o bloqueio do lobby só afeta equipar no catálogo, não a campanha.
## Geometria de cenário é placeholder de caixa, até a arte do Reino do Deserto existir.

@export_file("*.json") var phase_path := "res://data/desert/phase_01.json"
var _checkpoint := Vector3.ZERO
var _respawning := false
var _boss_defeated := false
const ENEMIES_PATH := "res://data/desert_enemies.json"
const PROTAGONIST_TYPE := "el_fuego"
## Câmera de perfil: perto o bastante para El Fuego ocupar uma fatia legível da tela.
const CAMERA_LEAD := 1.2
const CAMERA_HEIGHT := 1.8
const CAMERA_DISTANCE := 6.5
const CAMERA_FOV := 48.0
const CAMERA_LOOK_HEIGHT := 1.0
const CHECKPOINT_FLASH := 1.4

var completed: bool = false

var _phase: Dictionary
var _enemy_catalog: Dictionary
var _player: SidePlayer
var _camera: Camera3D
var _health_label: Label
var _progress_label: Label
var _message_label: Label
var _message_token := 0
var _touch: TouchControls


func _ready() -> void:
	_ensure_input_actions()
	_phase = _read_json(phase_path)
	_enemy_catalog = _read_json(ENEMIES_PATH).get("enemies", {})
	_build_environment()
	_build_platforms()
	_checkpoint = _vec3(_phase["player_spawn"])
	_build_goal()
	_build_checkpoints()
	_build_player()
	_build_enemies()
	_build_camera()
	_build_hud()


func _physics_process(delta: float) -> void:
	if _player == null or _respawning or completed:
		return
	if _player.global_position.y < float(_phase.get("kill_plane_y", -8.0)):
		_player.fall_out()
		return
	_update_progress()
	_camera.global_position = _camera.global_position.lerp(
		Vector3(_player.global_position.x + CAMERA_LEAD, CAMERA_HEIGHT, CAMERA_DISTANCE),
		1.0 - exp(-8.0 * delta)
	)
	_camera.look_at(Vector3(_camera.global_position.x - CAMERA_LEAD, CAMERA_LOOK_HEIGHT, 0.0), Vector3.UP)


## Iluminação de dia no deserto, com o mesmo ambiente quente do lobby. O cenário ainda é
## placeholder de caixa; a luz é ajustada para que o protagonista não fique escuro.
func _build_environment() -> void:
	var settings := GraphicsProfile.settings(GraphicsProfile.default_for_platform())
	get_viewport().msaa_3d = settings["msaa_3d"]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#8fc1e6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#ffe9c8")
	env.environment.ambient_light_energy = 0.4
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_color = Color("#fff1d6")
	sun.light_energy = 0.85
	sun.shadow_enabled = settings["shadows"]
	add_child(sun)

	# Luz de preenchimento sem sombra, vinda do lado oposto, para tirar o preto das costas.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	fill.light_color = Color("#c7dcff")
	fill.light_energy = 0.25
	add_child(fill)


func _build_platforms() -> void:
	for platform: Dictionary in _phase.get("platforms", []):
		var size := _vec3(platform["size"])
		var body := StaticBody3D.new()
		body.position = _vec3(platform["pos"])
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		mesh.mesh = box_mesh
		mesh.material_override = _placeholder_material(platform.get("kind", "ground"))
		if _phase.get("legacy_placeholder_visuals", true):
			body.add_child(mesh)
		else:
			mesh.free()
		add_child(body)


func _build_goal() -> void:
	var goal := Area3D.new()
	goal.position = _vec3(_phase["goal"]["pos"])
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 3.0, 1.0)
	shape.shape = box
	goal.add_child(shape)
	var flag := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 3.0
	flag.mesh = pole
	flag.material_override = _placeholder_material("goal")
	goal.add_child(flag)
	goal.body_entered.connect(_on_goal_entered)
	add_child(goal)


func _build_player() -> void:
	_player = SidePlayer.new()
	_player.position = _vec3(_phase["player_spawn"])
	var model := CharacterSlot.new()
	model.name = "Model"
	_player.add_child(model)
	add_child(_player)
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	var entry := _find_protagonist()
	_player.setup(entry)


func _build_enemies() -> void:
	for spawn: Dictionary in _phase.get("enemies", []):
		var entry: Dictionary = _enemy_catalog.get(spawn["type"], {})
		if entry.is_empty():
			push_warning("Inimigo sem entrada no catálogo: %s" % spawn["type"])
			continue
		var enemy := CactusEnemy.new()
		enemy.position = _vec3(spawn["pos"])
		enemy.set_meta("spawn_position", enemy.position)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.4
		shape.shape = capsule
		shape.position = Vector3(0.0, 0.7, 0.0)
		enemy.add_child(shape)
		var model := CharacterSlot.new()
		model.name = "Model"
		enemy.add_child(model)
		add_child(enemy)
		enemy.setup(entry, spawn)
		if spawn["type"] == "malagueta":
			enemy.defeated.connect(func() -> void: _boss_defeated = true)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 48.0
	_camera.current = true
	add_child(_camera)
	_camera.global_position = Vector3(_player.global_position.x + CAMERA_LEAD, CAMERA_HEIGHT, CAMERA_DISTANCE)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = _phase.get("name", "Fase")
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#ffd34d"))
	title.add_theme_color_override("font_outline_color", Color("#0a1630"))
	title.add_theme_constant_override("outline_size", 6)
	layer.add_child(title)

	_health_label = Label.new()
	_health_label.position = Vector2(24, 58)
	_health_label.add_theme_font_size_override("font_size", 22)
	_health_label.add_theme_color_override("font_color", Color("#ffffff"))
	_health_label.add_theme_color_override("font_outline_color", Color("#0a1630"))
	_health_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_health_label)

	_progress_label = Label.new()
	_progress_label.position = Vector2(24, 92)
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override("font_color", Color("#dbe7ff"))
	_progress_label.add_theme_color_override("font_outline_color", Color("#0a1630"))
	_progress_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_progress_label)

	_message_label = Label.new()
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 34)
	_message_label.add_theme_color_override("font_color", Color("#ffffff"))
	_message_label.add_theme_color_override("font_outline_color", Color("#0a1630"))
	_message_label.add_theme_constant_override("outline_size", 8)
	_message_label.visible = false
	layer.add_child(_message_label)

	_touch = TouchControls.new()
	layer.add_child(_touch)
	_on_player_health_changed(_player.health, SidePlayer.MAX_HEALTH)


func _on_player_health_changed(current: int, maximum: int) -> void:
	if _health_label:
		_health_label.text = "Vida %d / %d" % [current, maximum]


func _on_player_died() -> void:
	if _respawning or completed:
		return
	_respawning = true
	_show_message("Derrotado — reiniciando...")
	get_tree().create_timer(1.8).timeout.connect(_respawn_player)


func _respawn_player() -> void:
	_player.is_dead = false
	_player.health = SidePlayer.MAX_HEALTH
	_player.position = _checkpoint
	_respawning = false
	_player.velocity = Vector3.ZERO
	_message_label.visible = false
	_on_player_health_changed(_player.health, SidePlayer.MAX_HEALTH)
	_player.setup(_find_protagonist())
	_player.set("_invulnerable", SidePlayer.HIT_INVULNERABLE)
	# Evita reaparecer dentro de um inimigo que perseguiu o checkpoint.
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(_checkpoint) < 2.0 and enemy.has_meta("spawn_position"):
			enemy.position = enemy.get_meta("spawn_position")
			if enemy is CharacterBody3D:
				enemy.velocity = Vector3.ZERO


func _on_goal_entered(body: Node3D) -> void:
	if body != _player or completed or _player.is_dead or _respawning:
		return
	if _phase.get("boss_id") == "malagueta" and not _boss_defeated:
		_show_message("Derrote Malagueta antes de sair")
		return
	completed = true
	_player.is_dead = true
	_show_message("Fase concluída localmente — sem concessão online")
	var next_path := str(_phase.get("next_scene", ""))
	if not next_path.is_empty():
		var next_button := Button.new()
		next_button.text = "Próxima fase"
		next_button.position = get_viewport().get_visible_rect().size * 0.5 + Vector2(-110, 70)
		next_button.custom_minimum_size = Vector2(220, 56)
		next_button.pressed.connect(_advance.bind(next_path))
		_message_label.get_parent().add_child(next_button)


func _show_message(text: String) -> void:
	_message_token += 1
	_message_label.text = text
	_message_label.visible = true


## Aviso temporário (ex.: checkpoint). Não apaga uma mensagem permanente que chegou depois.
func _flash_message(text: String) -> void:
	_show_message(text)
	var token := _message_token
	get_tree().create_timer(CHECKPOINT_FLASH).timeout.connect(func() -> void:
		if token == _message_token and not completed and not _respawning:
			_message_label.visible = false)


## Progresso até a saída, em porcentagem da distância entre o início e a meta.
func _update_progress() -> void:
	if _progress_label == null or _player == null:
		return
	var start := float(_phase["player_spawn"][0])
	var goal := float(_phase["goal"]["pos"][0])
	var share := clampf((_player.global_position.x - start) / maxf(goal - start, 0.01), 0.0, 1.0)
	_progress_label.text = "Progresso %d%%" % roundi(share * 100.0)


## El Fuego é localizado no catálogo de personagens pelo id estável. A campanha não usa
## o estado de desbloqueio do lobby.
func _find_protagonist() -> Dictionary:
	var groups := CharacterCatalog.load_all()
	for entry: Dictionary in groups["unlockable"] + groups["playable"]:
		if entry["id"] == PROTAGONIST_TYPE:
			return entry
	push_error("Protagonista '%s' não encontrado no catálogo." % PROTAGONIST_TYPE)
	return {}


func _placeholder_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# Cores de areia e pedra para os blocos de placeholder; sem arte de cenário ainda.
	var colors := {
		"ground": Color("#d9b27c"),
		"ledge": Color("#c49a63"),
		"goal": Color("#ffd34d"),
	}
	material.albedo_color = colors.get(kind, Color("#777777"))
	material.roughness = 0.9
	return material


func _ensure_input_actions() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE, KEY_W, KEY_UP],
		"crouch": [KEY_S, KEY_DOWN],
		"attack": [KEY_J, KEY_K],
		"defend": [KEY_L, KEY_SHIFT],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: Key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JSON ausente: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _vec3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _build_checkpoints() -> void:
	for checkpoint: Dictionary in _phase.get("checkpoints", []):
		var area := Area3D.new()
		area.position = _vec3(checkpoint.pos)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.5, 3.0, 2.0)
		shape.shape = box
		area.add_child(shape)
		area.body_entered.connect(func(body: Node3D) -> void:
			if body == _player and not _player.is_dead and not completed and _vec3(checkpoint.pos).x > _checkpoint.x:
				_checkpoint = _vec3(checkpoint.pos)
				_flash_message("Checkpoint salvo"))
		add_child(area)


func _advance(path: String) -> void:
	# Mantém o wrapper de retorno ao menu e sua sessão; sem escrever progresso online.
	var scene := load(path) as PackedScene
	if scene == null:
		_show_message("Não foi possível carregar a próxima fase")
		return
	var parent := get_parent()
	parent.add_child(scene.instantiate())
	queue_free()
