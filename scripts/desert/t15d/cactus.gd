extends CactusEnemy
signal winding_up
signal alerted
signal retired(enemy: Node3D)
var _loaded := false
var _generation := 0
## Perseguição: quem passa direto por um Cacto vivo (correndo ou pulando por cima) é
## perseguido por alguns segundos. Mais rápido que a patrulha, mas abaixo da corrida do
## jogador (6 m/s): continuar correndo despista; parar ou errar um pulo deixa ele alcançar.
const PURSUE_SPEED := 5.7
const PURSUE_TIME := 6.0
const PURSUE_RANGE := 18.0
const PASS_WINDOW := 4.0
var crystallized_left := 0.0
var _crystal: Node3D
var blocked_at_edge := false
var persistent_follow := false
var allow_gap_jumps := true
var _pursue := 0.0
var _side := 0.0
var _windup := 0.0
var _stagger := 0.0
var _attack_direction := 1.0
var _recovery := 0.0
var attacks_delivered := 0
var _yaw_target := PI*0.5
func _ready() -> void:
	super._ready()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.18
func setup(entry: Dictionary, spawn: Dictionary) -> void:
	_generation += 1
	allow_gap_jumps = str(entry.get("id","cactus")) == "cactus"
	if not _loaded:
		super.setup(entry, spawn)
		_loaded = true
	else:
		var patrol: Array = spawn.get("patrol",[position.x-3,position.x+3])
		_patrol_min = float(patrol[0])
		_patrol_max = float(patrol[1])
	_state = State.PATROL
	_pursue = 0.0
	_side = 0.0
	_windup = 0.0
	_stagger = 0.0
	_recovery = 0.0
	_cooldown = 0.0
	crystallized_left = 0.0
	if is_instance_valid(_crystal): _crystal.queue_free()
	_model.set_rate(1.0)
	_model.play_animation("base",true)
	collision_layer = 4
	collision_mask = 1
	velocity = Vector3.ZERO
	health = 1 if str(entry.get("id","cactus")) == "cactus" else int(entry.get("health",20))
	attack_range = 1.25 if str(entry.get("id","cactus")) == "cactus" else float(entry.get("attack_range",1.7))
	_model.rotation.y = _yaw_target
func _physics_process(delta: float) -> void:
	if _state == State.DEAD: return
	if global_position.y < KILL_PLANE_Y:
		remove_from_group("enemies")
		retired.emit(self)
		return
	if not is_instance_valid(_player): _player = get_tree().get_first_node_in_group("player") as SidePlayer
	if crystallized_left > 0.0:
		crystallized_left = maxf(0.0,crystallized_left-delta)
		velocity = Vector3.ZERO
		_model.set_rate(0.0)
		if crystallized_left <= 0.0:
			if is_instance_valid(_crystal): _crystal.queue_free()
			_model.set_rate(1.0)
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_stagger = maxf(_stagger - delta, 0.0)
	_recovery = maxf(_recovery - delta, 0.0)
	_pursue = maxf(_pursue - delta, 0.0)
	velocity.y = maxf(velocity.y - GRAVITY * delta, -26.0)
	var offset := _player.global_position - global_position if is_instance_valid(_player) and not _player.is_dead else Vector3(INF, INF, 0)
	_watch_pass(offset)
	if is_finite(offset.x) and offset.x > 1.5 and offset.x < 16.0 and absf(offset.y) < 2.5:
		persistent_follow = true
	_model.set_rate(1.0)
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
			winding_up.emit()
		else:
			_model.play_animation("pronto",true)
	else:
		var pursuing := persistent_follow or (_pursue > 0.0 and absf(offset.x) < PURSUE_RANGE and absf(offset.y) < 3.0)
		if _pursue > 0.0 and not pursuing: _pursue = 0.0
		var chasing := pursuing or (absf(offset.x) < detect_range and absf(offset.y) < 1.6)
		_state = State.CHASE if chasing else State.PATROL
		if not chasing:
			if position.x <= _patrol_min: _direction = 1
			if position.x >= _patrol_max: _direction = -1
		var direction := signf(offset.x) if chasing else _direction
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(direction * 0.75, 0.6, 0), global_position + Vector3(direction * 0.75, -0.7, 0), 1)
		var has_ground := not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var wall := not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3(0,0.3,0),global_position+Vector3(direction*0.9,0.3,0),1)).is_empty()
		blocked_at_edge = is_on_floor() and (not has_ground or wall)
		if is_on_floor() and (wall or not has_ground) and (can_jump_low(direction) if wall else pursuing and allow_gap_jumps and can_jump_gap(direction)):
			velocity.y = 9.4 if not has_ground else 6.3
			velocity.x = direction*PURSUE_SPEED
			blocked_at_edge = false
		elif blocked_at_edge:
			velocity.x = 0
			_direction = -direction
			# Na beira de um vão ou contra um muro ele não segue: desiste em seguida.
			if pursuing: _pursue = maxf(_pursue, 0.7)
			_model.play_animation("pronto",true)
		else:
			_move_toward(direction, PURSUE_SPEED if pursuing else (chase_speed if chasing else speed), "correr" if chasing else "base")
		_model.set_rate(PURSUE_SPEED / chase_speed if pursuing and velocity.x != 0.0 else 1.0)
	_keep_formation()
	move_and_slide()
	global_position.z = 0.0
	_model.rotation.y = lerp_angle(_model.rotation.y,_yaw_target,1.0-exp(-16.0*delta))
## O jogador cruzou o Cacto (estava de um lado, agora está do outro, perto dele): começa
## a perseguição. Cruzar de novo enquanto ele persegue só renova o tempo.
func _watch_pass(offset: Vector3) -> void:
	if not is_finite(offset.x) or absf(offset.x) > PASS_WINDOW or absf(offset.y) > 3.0:
		_side = 0.0
		return
	var side := signf(offset.x)
	if side == 0.0: return
	if _side != 0.0 and side != _side:
		if _pursue <= 0.0: _alert()
		_pursue = PURSUE_TIME
	_side = side
## "!" dourado sobre a cabeça, para o jogador entender que está sendo seguido.
func _alert() -> void:
	alerted.emit()
	_model.flash(Color("#ffd27a"))
	var mark := Label3D.new()
	mark.text = "!"
	mark.font = preload("res://assets/desert/phase01/interface.ttf")
	mark.font_size = 96
	mark.pixel_size = 0.006
	mark.outline_size = 18
	mark.modulate = Color("#ffcf5a")
	mark.outline_modulate = Color("#2a1205")
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.position = Vector3(0, 2.25, 0)
	add_child(mark)
	var pop := mark.create_tween()
	pop.tween_property(mark, "scale", Vector3.ONE, 0.16).from(Vector3.ONE * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(0.6)
	pop.tween_property(mark, "modulate:a", 0.0, 0.25)
	pop.tween_callback(mark.queue_free)
## Virada visual curta, como a do protagonista; a direção lógica muda na hora.
func _face(direction: float) -> void:
	if direction != 0.0: _yaw_target = PI*0.5*direction
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
	crystallized_left = 0.0
	_model.set_rate(1.0)
	if is_instance_valid(_crystal): _crystal.queue_free()
	defeated.emit()
	remove_from_group("enemies")
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_model.play_animation("morte",false)
	var generation := _generation
	get_tree().create_timer(1.6,false).timeout.connect(func() -> void:
		if generation == _generation: retired.emit(self))

## Somente obstáculo sólido baixo/estreito e piso contínuo do outro lado.
func can_jump_low(direction: float) -> bool:
	var space := get_world_3d().direct_space_state
	var origin := global_position
	var low := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(0,0.15,0),origin+Vector3(direction*1.9,0.15,0),1))
	if low.is_empty(): return false
	var high := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(0,0.68,0),origin+Vector3(direction*1.9,0.68,0),1))
	if not high.is_empty(): return false
	var reverse := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(direction*2.1,0.15,0),origin+Vector3(0,0.15,0),1))
	if reverse.is_empty() or reverse.collider != low.collider: return false
	if absf(float(reverse.position.x)-float(low.position.x)) > 1.25: return false
	# O patamar de aterrissagem deve ser chão, não o topo do próprio bloco.
	for distance in [2.0,2.25,2.5]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3(direction*distance,0.7,0),origin+Vector3(direction*distance,-0.25,0),1))
		if hit.is_empty() or absf(float(hit.position.y)-origin.y) > 0.12: return false
	return true

func crystallize(seconds: float) -> void:
	if _state == State.DEAD: return
	crystallized_left = maxf(crystallized_left,seconds)
	_windup = 0.0
	velocity = Vector3.ZERO
	if is_instance_valid(_crystal): return
	_crystal = Node3D.new()
	add_child(_crystal)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0,0.77,0.30,0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for index in range(3):
		var mesh := MeshInstance3D.new()
		var crystal := CylinderMesh.new()
		crystal.top_radius = 0.0
		crystal.bottom_radius = 0.38
		crystal.height = 1.6+index*0.2
		crystal.radial_segments = 5
		mesh.mesh = crystal
		mesh.material_override = material
		mesh.position = Vector3((index-1)*0.35,0.9,0.25)
		_crystal.add_child(mesh)

## Procura uma laje real de aterrissagem; não pula abismo sem destino nem muro alto.
func can_jump_gap(direction: float) -> bool:
	if direction == 0: return false
	var space := get_world_3d().direct_space_state
	for distance: float in [1.4,1.8,2.2,2.6,3.0,3.4,3.8,4.2]:
		var point := global_position+Vector3(direction*distance,0,0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.9,point-Vector3.UP*0.9,1))
		if hit.is_empty(): continue
		var height: float = hit.position.y-global_position.y
		if height > 0.65 or height < -0.9: continue
		var beyond: Vector3 = hit.position+Vector3(direction*0.6,0,0)
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond+Vector3.UP*0.2,beyond-Vector3.UP*0.2,1)).is_empty(): continue
		var above := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.8,hit.position+Vector3.UP*1.8,1)
		if not space.intersect_ray(above).is_empty(): return false
		return distance <= 4.2
	return false

## Espaçamento no mesmo patamar: soldados aguardam o líder, sem se empilhar.
func _keep_formation() -> void:
	if absf(velocity.x)<0.01 or not is_on_floor(): return
	var direction := signf(velocity.x)
	for other: Node3D in get_tree().get_nodes_in_group("enemies"):
		if other == self or absf(other.global_position.y-global_position.y)>0.55: continue
		var ahead := (other.global_position.x-global_position.x)*direction
		if ahead > 0 and ahead < 0.85:
			velocity.x = direction*maxf(0.0,minf(absf(velocity.x),absf(other.velocity.x)))
