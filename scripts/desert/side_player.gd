class_name SidePlayer
extends CharacterBody3D

## Protagonista em plataforma lateral. Movimento restrito ao plano XY (Z fixo em 0).
## Pulo: primeiro salto com "pulo"; segundo salto no ar com "pulo_duplo" e impulso próprio.
## Máximo de dois saltos por sequência, reiniciados somente ao tocar o chão. Aterrissagem
## com "retorno". Animações são iniciadas por evento (salto, aterrissagem, ataque), nunca
## a cada quadro. Parado usa pose estática, pois não há idle verificado para este personagem.

signal health_changed(current: int, maximum: int)
signal died

const SPEED := 6.0
const JUMP_VELOCITY := 9.2
const DOUBLE_JUMP_VELOCITY := 8.6
const MAX_JUMPS := 2
const GRAVITY := 24.0
const MAX_FALL_SPEED := -26.0
const MAX_HEALTH := 5
const LANDING_MIN_AIR_TIME := 0.1
const ATTACK_DURATION := 0.42
const ATTACK_COOLDOWN := 0.35
const ATTACK_RANGE := 1.5
const ATTACK_DAMAGE := 2
const HIT_INVULNERABLE := 0.9
const HIT_KNOCKBACK := Vector3(4.0, 4.5, 0.0)
## Rastro de eventos de salto e aterrissagem no log, para testes. Desligado em produção.
const DEBUG_TRACE := false

var health: int = MAX_HEALTH
var is_dead: bool = false
var facing: float = 1.0
## Saltos já usados na sequência atual. Zera ao tocar o chão.
var jumps_used: int = 0

var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _invulnerable: float = 0.0
var _landing_timer: float = 0.0
var _was_on_floor: bool = true
var _air_time: float = 0.0
var _model: CharacterSlot


func _ready() -> void:
	add_to_group("player")
	_model = $Model as CharacterSlot
	health_changed.emit(health, MAX_HEALTH)


func setup(entry: Dictionary) -> void:
	_model.load_entry(entry)
	_model.set_pose("base", 0.0)
	jumps_used = 0
	_attack_timer = 0.0
	_attack_cooldown = 0.0
	_invulnerable = 0.0
	_air_time = 0.0
	_was_on_floor = false
	_landing_timer = 0.0


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_landing_timer = maxf(_landing_timer - delta, 0.0)

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = signf(direction)

	var jumped := false
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, MAX_FALL_SPEED)
	if Input.is_action_just_pressed("jump"):
		jumped = _try_jump()

	if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
		_start_attack()

	var attacking := _attack_timer > 0.0
	velocity.x = 0.0 if attacking else direction * SPEED
	velocity.z = 0.0
	move_and_slide()
	global_position.z = 0.0

	_update_floor_state(jumped)
	_update_model_facing()
	if not attacking and _landing_timer <= 0.0 and not jumped:
		_update_locomotion_animation(direction)


## Executa um salto se ainda houver algum disponível. Retorna true se saltou.
func _try_jump() -> bool:
	if is_on_floor():
		jumps_used = 1
		velocity.y = JUMP_VELOCITY
		_model.play_animation("pulo", false)
		_trace("salto 1 (pulo) y=%.2f" % global_position.y)
		return true
	if jumps_used < MAX_JUMPS:
		jumps_used += 1
		velocity.y = DOUBLE_JUMP_VELOCITY
		_model.play_animation("pulo_duplo", false)
		_trace("salto %d (pulo_duplo) y=%.2f" % [jumps_used, global_position.y])
		return true
	_trace("salto rejeitado: limite de %d atingido" % MAX_JUMPS)
	return false


func _trace(message: String) -> void:
	if DEBUG_TRACE:
		print("[SidePlayer] ", message)


## Detecta toque e saída do chão. Reinicia a contagem de saltos ao tocar o chão e toca
## "retorno" na aterrissagem. Sair de uma plataforma sem pular conta como primeiro salto.
func _update_floor_state(jumped: bool) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		# Só é aterrissagem se o jogador esteve no ar por tempo suficiente. Evita disparos
		# repetidos quando o contato com o chão oscila por um quadro (ex.: encostando em inimigo).
		if _air_time >= LANDING_MIN_AIR_TIME and not jumped:
			_land()
		if _air_time >= LANDING_MIN_AIR_TIME or _was_on_floor:
			jumps_used = 0
		_air_time = 0.0
	else:
		_air_time += get_physics_process_delta_time()
		if _was_on_floor and not jumped:
			jumps_used = 1
	_was_on_floor = on_floor


func _land() -> void:
	_trace("aterrissagem x=%.2f y=%.2f" % [global_position.x, global_position.y])
	if not _model.has_animation("retorno"):
		return
	_model.play_animation("retorno", false)
	_landing_timer = _model.animation_length("retorno")


func take_damage(amount: int, from_x: float) -> void:
	if is_dead or _invulnerable > 0.0:
		return
	health = maxi(health - amount, 0)
	_invulnerable = HIT_INVULNERABLE
	var push := signf(global_position.x - from_x)
	velocity.x = HIT_KNOCKBACK.x * (push if push != 0.0 else 1.0)
	velocity.y = HIT_KNOCKBACK.y
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()


func _start_attack() -> void:
	_attack_timer = ATTACK_DURATION
	_attack_cooldown = maxf(ATTACK_COOLDOWN, ATTACK_DURATION)
	_model.play_animation("ataque", false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("take_damage") and _can_hit(enemy):
			enemy.take_damage(ATTACK_DAMAGE)


func _can_hit(enemy: Node3D) -> bool:
	var offset := enemy.global_position.x - global_position.x
	var in_front := signf(offset) == facing or absf(offset) < 0.4
	return in_front and absf(offset) <= ATTACK_RANGE and absf(enemy.global_position.y - global_position.y) < 1.4


func _update_model_facing() -> void:
	# O modelo Mixamo olha para +Z. Girar 90° em Y coloca o olhar em +X ou -X.
	_model.rotation.y = PI * 0.5 * facing


func _update_locomotion_animation(direction: float) -> void:
	if not is_on_floor():
		return
	if absf(direction) > 0.01:
		_model.play_animation("base", true)
	elif not _model.is_static_pose:
		_model.set_pose("base", 0.0)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	_model.play_animation("morte", false)
	died.emit()
