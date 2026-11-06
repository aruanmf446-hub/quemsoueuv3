extends Node3D
## Projétil leve: varredura da ponta entre quadros, sem atravessar jogador ou paredes.
signal player_struck(blocked: bool,point: Vector3)
signal missed
const MESH=preload("res://assets/desert/weapons/cactus_spear.res")
var velocity:=Vector3.ZERO
var source_x:=0.0
var actor: CharacterBody3D
var _visual: MeshInstance3D
var _last_tip:=Vector3.ZERO
var _age:=0.0
var _done:=false
var _linger:=0.0
var _direction:=Vector3.RIGHT
func _ready() -> void:
	add_to_group("campaign_spears")
	_visual=MeshInstance3D.new()
	_visual.mesh=MESH
	_visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_last_tip=global_position
	_direction=velocity.normalized()
	_visual.rotation.z=atan2(_direction.y,_direction.x)
func _physics_process(delta: float) -> void:
	if _done:
		_linger-=delta
		_visual.transparency=clampf(1.0-_linger/0.16,0,1)
		if _linger<=0.0:queue_free()
		return
	_age+=delta
	var next:=global_position+velocity*delta
	var tip:=next+_direction*0.94
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_last_tip,tip,1|2))
	# A parede de terra é visual; intercepta a lança antes da cápsula do jogador.
	if is_instance_valid(actor) and not actor.is_dead and actor.is_defending and velocity.x*actor.facing<0.0:
		var plane: float=actor.global_position.x+actor.facing*0.72
		var dx:=tip.x-_last_tip.x
		if absf(dx)>0.0001:
			var t: float=(plane-_last_tip.x)/dx
			var point:=_last_tip.lerp(tip,t)
			var first: bool=hit.is_empty() or point.distance_squared_to(_last_tip)<=hit.position.distance_squared_to(_last_tip)
			if t>=0.0 and t<=1.0 and point.y>=actor.global_position.y+0.05 and point.y<=actor.global_position.y+1.9 and first:
				_hit_player(point,true)
				return
	if not hit.is_empty():
		if hit.collider==actor and is_instance_valid(actor) and not actor.is_dead:_hit_player(hit.position,actor.is_defending)
		else:
			_set_impact(hit.position)
			missed.emit()
		return
	global_position=next
	_last_tip=tip
	if _age>=3.2:
		_done=true
		_linger=0.16
		missed.emit()
func _hit_player(point: Vector3,blocked: bool) -> void:
	_set_impact(point)
	actor.take_damage(1,source_x)
	player_struck.emit(blocked,point)
func _set_impact(point: Vector3) -> void:
	_done=true
	_linger=0.30
	global_position=point-_direction*0.84
	velocity=Vector3.ZERO
