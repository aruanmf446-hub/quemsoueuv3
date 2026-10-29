extends SidePlayer
signal strike_landed(point: Vector3)
var _hit_delivered := false
var _attack_buffer := 0.0
const STRIKE_TIME := 0.18
const SWING := 0.52
func _ready() -> void:
	super._ready()
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.18
	floor_max_angle = deg_to_rad(48)
func setup(entry: Dictionary) -> void:
	super.setup(entry)
	_hit_delivered = false
	_attack_buffer = 0.0
	_model.play_animation("pronto", true)
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL_SPEED)
		move_and_slide()
		return
	_knockback_timer = maxf(_knockback_timer - delta, 0.0)
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_landing_timer = maxf(_landing_timer - delta, 0.0)
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0 and _attack_timer <= 0.0:
		facing = signf(direction)
	velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL_SPEED)
	if Input.is_action_just_pressed("jump"): _jump_buffer = JUMP_BUFFER
	if Input.is_action_just_pressed("attack"): _attack_buffer = 0.15
	is_defending = Input.is_action_pressed("defend") and is_on_floor() and _knockback_timer <= 0.0 and _attack_timer <= 0.0
	_set_crouched(not is_defending and Input.is_action_pressed("crouch") and is_on_floor() and _attack_timer <= 0.0)
	var jumped := false
	if _jump_buffer > 0.0 and not is_defending and _attack_timer <= 0.15:
		jumped = _try_jump()
		if jumped:
			_jump_buffer = 0.0
			_set_crouched(false)
	if _attack_buffer > 0.0 and _attack_cooldown <= 0.0 and not is_defending and not is_crouching:
		_start_attack()
		_attack_buffer = 0.0
	if _attack_timer > 0.0 and not _hit_delivered and _attack_timer <= SWING - STRIKE_TIME:
		_deliver_hit()
	if _knockback_timer <= 0.0:
		var target := direction * SPEED
		if is_defending or is_crouching: target = 0.0
		if _attack_timer > 0.0: target *= 0.22 if is_on_floor() else 0.7
		velocity.x = move_toward(velocity.x, target, (48.0 if is_on_floor() else 24.0) * delta)
	velocity.z = 0.0
	move_and_slide()
	_separate_actors()
	global_position.z = 0.0
	_update_floor_state(jumped)
	_update_model_facing()
	if _attack_timer <= 0.0 and _landing_timer <= 0.0 and not jumped:
		_update_stance_animation(direction)
func _update_stance_animation(direction: float) -> void:
	if not is_on_floor(): return
	if is_defending: _model.play_animation("defesa", true)
	elif is_crouching: _model.play_animation("agachado", true)
	elif absf(direction) > 0.01: _model.play_animation("base", true)
	else: _model.play_animation("pronto", true)
func _start_attack() -> void:
	_attack_timer = SWING
	_attack_cooldown = 0.62
	_hit_delivered = false
	_model.play_animation("ataque", false)
func _deliver_hit() -> void:
	_hit_delivered = true
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_damage") or not _can_hit(enemy): continue
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, enemy.global_position + Vector3.UP * 0.7, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		enemy.take_damage(ATTACK_DAMAGE)
		strike_landed.emit(enemy.global_position + Vector3.UP * 0.8)
func take_damage(amount: int, from_x: float) -> void:
	var before := health
	super.take_damage(amount, from_x)
	if health < before: _model.flash(Color("#fff1d7"))
	elif is_defending: _model.flash(Color("#8ccfff"))
func _set_crouched(value: bool) -> void:
	if not value and is_crouching and is_inside_tree():
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = STAND_HEIGHT
		capsule.radius = RADIUS
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (STAND_HEIGHT * 0.5 + 0.03))
		query.collision_mask = 1
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return
	super._set_crouched(value)

func _separate_actors() -> void:
	# Contato lateral sem permitir aterrissar na cabeça do inimigo.
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if absf(enemy.global_position.y-global_position.y) > 0.7: continue
		var dx := global_position.x-enemy.global_position.x
		if absf(dx) >= 1.05: continue
		var side := signf(dx) if absf(dx) > 0.01 else -facing
		var correction := Vector3(side*1.05-dx,0,0)
		if not test_move(global_transform,correction):
			global_position += correction
			if velocity.x*side < 0: velocity.x = 0.0
