extends "res://scripts/desert/t15d/cactus.gd"
## Arena waypoints only. Existing AI still owns locomotion, jumping, damage and formation.
var _route: Node3D
func _point(body: Node3D) -> Vector3:
	return body.future_position(0.45) if body.has_method("future_position") else body.get_meta("navigation_point",body.global_position)
func _chase_direction(offset: Vector3) -> float:
	if not is_on_floor() and is_instance_valid(_route) and (not _route.has_method("is_available") or _route.is_available(0.45)):
		var dx: float=_point(_route).x-global_position.x
		return signf(dx) if absf(dx)>0.25 else 0.0
	_route=null
	if absf(offset.y)>0.85:
		var climbing:=offset.y>0
		for file in get_tree().get_nodes_in_group("mining_files"):
			if file.has_method("is_available") and not file.is_available(0.45):continue
			var rise: float=_point(file).y-global_position.y
			var distance: float=absf(_point(file).x-global_position.x)
			if distance>4.2 or absf(rise)>2.05 or absf(rise)<0.25:continue
			if (climbing and rise<0) or (not climbing and rise>0):continue
			if _route==null or absf(rise)<absf(_point(_route).y-global_position.y):_route=file
	if is_instance_valid(_route):
		var dx: float=_point(_route).x-global_position.x
		return signf(dx) if absf(dx)>0.15 else 1.0
	# Ride the current saw while the next level is still outside the arena.
	# Chasing the player directly here would run off the only available support.
	if offset.y>0.85 and is_on_floor():
		for file in get_tree().get_nodes_in_group("mining_files"):
			if not file.has_method("is_available") or not file.is_available():continue
			if absf(file.global_position.y-global_position.y)>0.2:continue
			var dx: float=file.global_position.x-global_position.x
			if absf(dx)<file.span*0.5+0.2:return signf(dx) if absf(dx)>0.25 else 0.0
	return super._chase_direction(offset)
func _can_jump_route(direction: float) -> bool:
	if is_instance_valid(_route):return absf(_point(_route).x-global_position.x)<2.9
	return super._can_jump_route(direction)

func _physics_process(delta: float)->void:
	var grounded:=is_on_floor()
	super._physics_process(delta)
	# Only these arena pursuers need enough lift for the revised 1.9 m saw levels.
	if grounded and not is_on_floor() and is_instance_valid(_route) and velocity.y>9.0:
		velocity.y=10.2
