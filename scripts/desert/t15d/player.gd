extends SidePlayer
signal strike_landed(point: Vector3)
signal inventory_changed
signal action_empty(kind: String)
signal swung
signal jumped_up
signal landed
signal strike_window
signal hurt
const ActorSlot = preload("res://scripts/desert/t15d/actor_slot.gd")
const SandFx = preload("res://scripts/desert/t15d/sand_fx.gd")
const RUN_MAX_HEALTH := 3
var attack_charges := 1
var defense_charges := 1
var _shield_timer := 0.0
var _hit_delivered := false
var _attack_buffer := 0.0
var _defend_buffer := 0.0
const STRIKE_TIME := 0.16
const SWING := 0.42
## Tempo de virada do modelo (o colisor vira na hora; só o visual gira).
const TURN_RATE := 22.0
const HURT_TIME := 0.32
var _yaw := PI*0.5
var _hurt_timer := 0.0
var _blink := 0.0
var _fist: Node3D
var _actor: ActorSlot:
	get: return _model as ActorSlot
func _ready() -> void:
	super._ready()
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.18
	floor_max_angle = deg_to_rad(48)
	health = RUN_MAX_HEALTH
func setup(entry: Dictionary) -> void:
	super.setup(entry)
	_hit_delivered = false
	_attack_buffer = 0.0
	_defend_buffer = 0.0
	attack_charges = 1
	defense_charges = 1
	_shield_timer = 0.0
	_hurt_timer = 0.0
	_yaw = PI*0.5*facing
	health = RUN_MAX_HEALTH
	health_changed.emit(health,RUN_MAX_HEALTH)
	inventory_changed.emit()
	_actor.play_animation("pronto", true)
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
	_defend_buffer = maxf(_defend_buffer - delta, 0.0)
	_shield_timer = maxf(_shield_timer-delta,0.0)
	_hurt_timer = maxf(_hurt_timer-delta,0.0)
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0 and _attack_timer <= 0.0:
		facing = signf(direction)
	velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL_SPEED)
	if Input.is_action_just_pressed("jump"): _jump_buffer = JUMP_BUFFER
	if Input.is_action_just_pressed("attack"):
		if attack_charges > 0: _attack_buffer = 0.15
		else: action_empty.emit("attack")
	# Defesa com buffer curto: apertar pouco antes de pousar ou no fim do golpe não se perde.
	if Input.is_action_just_pressed("defend"):
		if defense_charges > 0: _defend_buffer = 0.2
		else: action_empty.emit("defense")
	if _defend_buffer > 0.0 and defense_charges > 0 and is_on_floor() and _attack_timer <= 0.0:
		_defend_buffer = 0.0
		defense_charges -= 1
		_shield_timer = 1.2
		inventory_changed.emit()
	is_defending = _shield_timer > 0.0 and is_on_floor() and _knockback_timer <= 0.0 and _attack_timer <= 0.0
	_set_crouched(not is_defending and Input.is_action_pressed("crouch") and is_on_floor() and _attack_timer <= 0.0)
	var jumped := false
	if _jump_buffer > 0.0 and not is_defending and _attack_timer <= 0.15:
		jumped = _try_jump()
		if jumped: jumped_up.emit()
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
		if _attack_timer > 0.0: target *= 0.0 if is_on_floor() else 0.7
		velocity.x = move_toward(velocity.x, target, (48.0 if is_on_floor() else 24.0) * delta)
	velocity.z = 0.0
	move_and_slide()
	_separate_actors()
	global_position.z = 0.0
	_update_floor_state(jumped)
	_update_model_facing()
	if _attack_timer > 0.0:
		# A investida termina antes da janela do golpe; volta à guarda suavemente.
		if _actor.current_clip() != "golpe" and _hurt_timer <= 0.0: _actor.play_animation("pronto", true, 0.18)
	elif not jumped and not is_on_floor():
		_update_air_animation()
	elif _landing_timer <= 0.0 and _hurt_timer <= 0.0 and not jumped:
		_update_stance_animation(direction)
	# Cadência da corrida acompanha a velocidade real: sem pés deslizando na aceleração.
	_actor.set_rate(clampf(absf(velocity.x)/SPEED,0.45,1.0) if _actor.current_clip() == "base" else 1.0)
## No ar: mantém pulo/pulo duplo enquanto sobe e passa para a pose de queda ao descer
## ou ao sair de uma borda andando (antes o clipe de corrida continuava no ar).
func _update_air_animation() -> void:
	if _hurt_timer > 0.0: return
	var clip := _actor.current_clip()
	var position := _actor.clip_position()
	var still_jumping := (clip == "pulo" and position < 1.02) or (clip == "pulo_duplo" and position < 0.85)
	if still_jumping and velocity.y > -6.0: return
	if velocity.y < -1.0 or not still_jumping: _actor.play_animation("queda", true, 0.16)
func _update_stance_animation(direction: float) -> void:
	if not is_on_floor(): return
	if is_defending: _actor.play_animation("defesa", true)
	elif is_crouching: _actor.play_animation("agachado", true)
	elif absf(direction) > 0.01: _actor.play_animation("base", true)
	else: _actor.play_animation("pronto", true)
func _start_attack() -> void:
	if attack_charges <= 0: return
	attack_charges -= 1
	inventory_changed.emit()
	if is_on_floor(): velocity.x = 0.0
	_attack_timer = SWING
	_attack_cooldown = 0.62
	_hit_delivered = false
	_actor.play_animation("golpe", false, 0.05)
	# Mão esquerda do modelo é a que soca (fica à frente nas duas direções).
	var skeleton: Skeleton3D = _actor._skeleton
	if skeleton != null:
		_fist = SandFx.SandPunch.new()
		_fist.direction = facing
		_fist.skeleton = skeleton
		_fist.bone = skeleton.find_bone("mixamorig_LeftHand")
		get_parent().add_child(_fist)
	swung.emit()
## Golpe: soco corpo a corpo no quadro do braço estendido; o dano vale para Cactus à
## frente, até 1,7m, sem parede. A areia envolve o punho desde o começo do golpe.
func _deliver_hit() -> void:
	_hit_delivered = true
	strike_window.emit()
	if is_instance_valid(_fist): _fist.strike()
	for enemy: Node3D in get_tree().get_nodes_in_group("enemies"):
		if not enemy.has_method("take_damage") or not _can_hit(enemy): continue
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, enemy.global_position + Vector3.UP * 0.7, 1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		enemy.take_damage(ATTACK_DAMAGE)
		var point := enemy.global_position + Vector3.UP * 0.8
		SandFx.SandPunch.impact(get_parent(), point)
		strike_landed.emit(point)
func restore_charge(kind: String) -> bool:
	if is_dead: return false
	if kind == "health" and health < RUN_MAX_HEALTH:
		health += 1
		health_changed.emit(health,RUN_MAX_HEALTH)
	elif kind == "attack" and attack_charges < 1:
		attack_charges = 1
	elif kind == "defense" and defense_charges < 1:
		defense_charges = 1
	else: return false
	inventory_changed.emit()
	return true
func _can_hit(enemy: Node3D) -> bool:
	var offset := enemy.global_position-global_position
	return (offset.x*facing > 0.0 or absf(offset.x)<0.3) and absf(offset.x)<=1.7 and absf(offset.y)<1.35
func take_damage(amount: int, from_x: float) -> void:
	if is_dead or _invulnerable > 0.0: return
	if is_defending:
		_shield_timer = 0.0
		is_defending = false
		_invulnerable = 0.35
		blocked.emit()
		_model.flash(Color("#8ccfff"))
		return
	health = maxi(health-amount,0)
	_invulnerable = HIT_INVULNERABLE
	_knockback_timer = 0.18
	var direction := signf(global_position.x-from_x)
	velocity = Vector3(4.0*(direction if direction != 0 else 1.0),4.5,0)
	health_changed.emit(health,RUN_MAX_HEALTH)
	_model.flash(Color("#ff8a6a"))
	_hurt_timer = HURT_TIME
	_actor.play_animation("dano", false, 0.04)
	hurt.emit()
	if health <= 0: _die()
## Visual: virada curta e piscar durante a invulnerabilidade depois do recuo.
func _update_model_facing() -> void:
	var delta := get_physics_process_delta_time()
	# Interpolação linear entre ±90°: a virada passa pela frente do modelo, nunca pelas costas.
	_yaw = lerpf(_yaw, PI*0.5*facing, 1.0-exp(-TURN_RATE*delta))
	_model.basis = Basis(Vector3.UP, _yaw)
	if _invulnerable > 0.0 and not is_dead and not is_defending and _hurt_timer <= 0.0:
		_blink += delta
		_model.visible = fmod(_blink, 0.14) < 0.09
	else:
		_blink = 0.0
		_model.visible = true
func _land() -> void:
	landed.emit()
	if _hurt_timer > 0.0: return
	_actor.play_animation("aterrissagem", false, 0.05)
	_landing_timer = LANDING_LOCK
func fall_out() -> void:
	if is_dead: return
	health = 0
	health_changed.emit(health,RUN_MAX_HEALTH)
	_die()
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
		if absf(enemy.global_position.y-global_position.y) > 1.15: continue
		var dx := global_position.x-enemy.global_position.x
		if absf(dx) <= 1.08:
			take_damage(1,enemy.global_position.x)
		if absf(dx) >= 1.05: continue
		var side := signf(dx) if absf(dx) > 0.01 else -facing
		var correction := Vector3(side*1.05-dx,0,0)
		if not test_move(global_transform,correction):
			global_position += correction
			if velocity.x*side < 0: velocity.x = 0.0
