extends CactusEnemy
var _windup := 0.0
var _stagger := 0.0
var _attack_direction := 1.0
var _recovery := 0.0
var attacks_delivered := 0
func _ready() -> void:
	super._ready()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.18
func setup(entry: Dictionary, spawn: Dictionary) -> void:
	super.setup(entry, spawn)
	health = 3
	attack_range = 1.25
func _physics_process(delta: float) -> void:
	if _state == State.DEAD: return
	if global_position.y < KILL_PLANE_Y:
		remove_from_group("enemies")
		queue_free()
		return
	if not is_instance_valid(_player): _player = get_tree().get_first_node_in_group("player") as SidePlayer
	_cooldown = maxf(_cooldown - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_recovery = maxf(_recovery - delta, 0.0)
	velocity.y = maxf(velocity.y - GRAVITY * delta, -26.0)
	var offset := _player.global_position - global_position if is_instance_valid(_player) and not _player.is_dead else Vector3(INF, INF, 0)
	if _stagger > 0.0:
		velocity.x = move_toward(velocity.x, 0, delta * 10)
	elif _windup > 0.0:
		velocity.x = 0.0
		_windup -= delta
		if _windup <= 0.0:
			_recovery = 0.22
			attacks_delivered += 1
			if is_instance_valid(_player) and not _player.is_dead and absf(offset.x) <= attack_range + 0.15 and absf(offset.y) < 1.1 and offset.x * _attack_direction > -0.2:
				var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.7,_player.global_position+Vector3.UP*0.7,1)
				if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					_player.take_damage(damage, global_position.x)
	elif _recovery > 0.0:
		velocity.x = 0.0
	elif absf(offset.x) <= attack_range and absf(offset.y) < 1.1:
		_state = State.ATTACK
		velocity.x = 0
		_face(signf(offset.x))
		if _cooldown <= 0.0:
			_windup = 0.36
			_cooldown = attack_cooldown_time
			_attack_direction = signf(offset.x)
			_model.play_animation("ataque", false)
			_model.flash(Color("#ffbf62"))
		else:
			_model.play_animation("pronto",true)
	else:
		var chasing := absf(offset.x) < detect_range and absf(offset.y) < 1.6
		_state = State.CHASE if chasing else State.PATROL
		if not chasing:
			if position.x <= _patrol_min: _direction = 1
			if position.x >= _patrol_max: _direction = -1
		var direction := signf(offset.x) if chasing else _direction
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(direction * 0.75, 0.6, 0), global_position + Vector3(direction * 0.75, -0.7, 0), 1)
		var has_ground := not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var wall := test_move(global_transform, Vector3(direction * 0.2, 0, 0))
		if is_on_floor() and (not has_ground or wall):
			velocity.x = 0
			_direction = -direction
			_model.play_animation("pronto",true)
		else:
			_move_toward(direction, chase_speed if chasing else speed, "correr" if chasing else "base")
	move_and_slide()
	global_position.z = 0.0
func take_damage(amount: int) -> void:
	if _state == State.DEAD: return
	_model.flash(Color("#fff4c6"))
	_windup = 0.0
	_stagger = 0.18
	var dx := global_position.x - _player.global_position.x if is_instance_valid(_player) else 1.0
	velocity.x = signf(dx) * 3.0
	super.take_damage(amount)
func _die() -> void:
	_state = State.DEAD
	defeated.emit()
	remove_from_group("enemies")
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_model.play_animation("morte",false)
	get_tree().create_timer(1.6,false).timeout.connect(queue_free)
