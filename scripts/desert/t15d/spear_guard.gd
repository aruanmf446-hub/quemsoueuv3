extends Node
## Guarda imóvel até acertar jogador/escudo. Erro gera outra tentativa; acerto libera perseguição.
const Spear=preload("res://scripts/desert/t15d/cactus_spear.gd")
var shooter: CharacterBody3D
var active:=false
var enabled:=false
var pursuit_allowed:=false
var supply_id:=""
var state:="watch"
var throws:=0
var last_hit:=""
var _tutorial:=false
var _wait:=0.0
var _windup:=0.0
var _duration:=0.72
var _direction:=1.0
var _shot: Node3D
var _held: MeshInstance3D
var _hand:=-1
func _ready() -> void:
	_held=MeshInstance3D.new()
	_held.mesh=Spear.MESH
	_held.top_level=true
	_held.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_held)
func configure(owner_actor: CharacterBody3D,spawn: Dictionary) -> void:
	shutdown()
	shooter=owner_actor
	active=bool(spawn.get("spear",false))
	enabled=bool(spawn.get("spear_enabled",true))
	pursuit_allowed=false
	supply_id=str(spawn.get("spear_supply",""))
	_tutorial=bool(spawn.get("spear_tutorial",false))
	_duration=0.50 if _tutorial else 0.72
	state="watch"
	throws=0
	last_hit=""
	_held.visible=active
	if is_instance_valid(shooter._model._skeleton):_hand=shooter._model._skeleton.find_bone("mixamorig_RightHand")
	set_process(active)
func shutdown() -> void:
	active=false
	_wait=0.0
	_windup=0.0
	if is_instance_valid(_shot):_shot.queue_free()
	_shot=null
	if is_instance_valid(_held):_held.hide()
	set_process(false)
func enable_for(id: String) -> void:
	if supply_id==id:enabled=true
func handle(delta: float,offset: Vector3) -> bool:
	if not active or pursuit_allowed:return false
	shooter.velocity.x=0.0
	shooter._model.set_rate(1.0)
	if is_finite(offset.x) and absf(offset.x)>0.1:
		if _windup<=0.0:_direction=signf(offset.x)
		shooter._face(_direction)
	_wait=maxf(0.0,_wait-delta)
	if _windup>0.0:
		_windup=maxf(0.0,_windup-delta)
		if _windup==0.0:_launch()
	elif not is_instance_valid(_shot) or _shot._done:
		state="watch"
		shooter._model.play_animation("pronto",true)
		if enabled and _wait<=0.0 and is_finite(offset.x) and absf(offset.x)<=12.0 and absf(offset.y)<2.0 and shooter.is_on_floor() and is_instance_valid(shooter._player) and not shooter._player.is_dead:
			var a:=shooter.global_position+Vector3.UP*1.14
			var b:=Vector3(shooter._player.global_position.x,a.y,0)
			if shooter.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty():
				_windup=_duration
				state="windup"
				shooter._model.play_animation("ataque",false)
				shooter.winding_up.emit()
		else:
			state="watch"
			shooter._model.play_animation("pronto",true)
	shooter.move_and_slide()
	shooter.global_position.z=0.0
	shooter._model.rotation.y=lerp_angle(shooter._model.rotation.y,shooter._yaw_target,1.0-exp(-16.0*delta))
	return true
func _hand_point() -> Vector3:
	if _hand>=0 and is_instance_valid(shooter._model._skeleton):
		var skeleton: Skeleton3D=shooter._model._skeleton
		return skeleton.global_transform*skeleton.get_bone_global_pose(_hand).origin
	return shooter.global_position+Vector3(_direction*0.35,1.14,0)
func _process(_delta: float) -> void:
	if not active or pursuit_allowed or not is_instance_valid(shooter):return
	_held.visible=not is_instance_valid(_shot) or _shot._done
	_held.global_position=_hand_point()
	var angle:=lerpf(0.9,0.0,1.0-_windup/_duration) if _windup>0.0 else 0.9
	_held.global_rotation=Vector3(0,0,angle if _direction>0.0 else PI-angle)
func _launch() -> void:
	if not is_instance_valid(shooter._player) or shooter._player.is_dead:return
	if is_instance_valid(_shot):_shot.queue_free()
	_shot=Spear.new()
	_shot.actor=shooter._player
	_shot.source_x=shooter.global_position.x
	var hand:=_hand_point()
	# Mira uma faixa fixa: saltar/agachar funciona, sem mira que persegue o jogador no ar.
	var target:=Vector3(hand.x+_direction*8.0,shooter.global_position.y+1.14,0)
	_shot.velocity=(target-hand).normalized()*12.0
	shooter.get_parent().get_parent().add_child(_shot)
	_shot.global_position=hand
	_shot._last_tip=hand
	_shot.player_struck.connect(_on_hit)
	_shot.missed.connect(func() -> void:
		_wait=1.8
		state="recover")
	_held.hide()
	throws+=1
	state="flight"
func _on_hit(_blocked: bool,_point: Vector3) -> void:
	if not active or not is_instance_valid(shooter) or shooter.health<=0:return
	last_hit="shield" if _blocked else "body"
	pursuit_allowed=true
	state="pursue"
	shooter.persistent_follow=true
	shooter._alert()
	_held.hide()
func interrupt() -> void:
	if _windup>0.0:
		_windup=0.0
		_wait=maxf(_wait,0.8)
		state="recover"
