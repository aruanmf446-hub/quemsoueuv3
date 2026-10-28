class_name CactusEnemy
extends CharacterBody3D

## Cacto do Reino do Deserto. Patrulha entre dois limites, persegue o jogador ao detectá-lo,
## ataca com cooldown e morre com a animação "morte". Parâmetros vêm de data/desert_enemies.json.

signal defeated

enum State { PATROL, CHASE, ATTACK, DEAD }

const GRAVITY := 24.0

var health: int = 2
var damage: int = 1
var speed: float = 2.0
var chase_speed: float = 3.2
var detect_range: float = 5.5
var attack_range: float = 1.1
var attack_cooldown_time: float = 1.3

var _patrol_min: float = 0.0
var _patrol_max: float = 0.0
var _direction: float = 1.0
var _state: State = State.PATROL
var _cooldown: float = 0.0
var _model: CharacterSlot
var _player: SidePlayer


func _ready() -> void:
	add_to_group("enemies")
	_model = $Model as CharacterSlot


func setup(entry: Dictionary, spawn: Dictionary) -> void:
	health = int(entry.get("health", health))
	damage = int(entry.get("damage", damage))
	speed = float(entry.get("speed", speed))
	chase_speed = float(entry.get("chase_speed", chase_speed))
	detect_range = float(entry.get("detect_range", detect_range))
	attack_range = float(entry.get("attack_range", attack_range))
	attack_cooldown_time = float(entry.get("attack_cooldown", attack_cooldown_time))
	var patrol: Array = spawn.get("patrol", [global_position.x - 3.0, global_position.x + 3.0])
	_patrol_min = float(patrol[0])
	_patrol_max = float(patrol[1])
	_model.load_entry(entry)
	_model.set_pose("base", 0.0)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as SidePlayer

	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -26.0)
	else:
		velocity.y = 0.0

	var to_player := Vector3.ZERO
	if _player and not _player.is_dead:
		to_player = _player.global_position - global_position

	var distance_x := absf(to_player.x) if is_instance_valid(_player) and not _player.is_dead else INF
	if distance_x <= attack_range and absf(to_player.y) < 1.4:
		_set_state(State.ATTACK)
	elif distance_x <= detect_range and absf(to_player.y) < 2.0:
		_set_state(State.CHASE)
	else:
		_set_state(State.PATROL)

	match _state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_move_toward(signf(to_player.x), chase_speed, "correr")
		State.ATTACK:
			velocity.x = 0.0
			_face(signf(to_player.x))
			if _cooldown <= 0.0:
				_cooldown = attack_cooldown_time
				_model.play_animation("ataque", false)
				if _player and not _player.is_dead and distance_x <= attack_range + 0.3:
					_player.take_damage(damage, global_position.x)

	move_and_slide()
	global_position.z = 0.0


func take_damage(amount: int) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	if health <= 0:
		_die()


func _patrol(_delta: float) -> void:
	if global_position.x <= _patrol_min:
		_direction = 1.0
	elif global_position.x >= _patrol_max:
		_direction = -1.0
	_move_toward(_direction, speed, "base")


func _move_toward(direction: float, move_speed: float, anim: StringName) -> void:
	velocity.x = direction * move_speed
	_face(direction)
	_model.play_animation(anim, true)


func _face(direction: float) -> void:
	if direction != 0.0:
		_model.rotation.y = PI * 0.5 * direction


func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next


func _die() -> void:
	_state = State.DEAD
	defeated.emit()
	remove_from_group("enemies")
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_model.play_animation("morte", false)
	get_tree().create_timer(1.6).timeout.connect(queue_free)
