extends "res://scripts/desert/t15d/cactus.gd"
## Arena waypoints only. Existing AI still owns locomotion, jumping, damage and formation.
var _route: Node3D
func _point(body: Node3D) -> Vector3:
	return body.future_position(0.45) if body.has_method("future_position") else body.get_meta("navigation_point",body.global_position)
func _chase_direction(offset: Vector3) -> float:
	if not is_on_floor() and is_instance_valid(_route):
		var dx: float=_point(_route).x-global_position.x
		return signf(dx) if absf(dx)>0.25 else 0.0
	_route=null
	if absf(offset.y)>0.85:
		var climbing:=offset.y>0
		for file in get_tree().get_nodes_in_group("mining_files"):
			var rise: float=_point(file).y-global_position.y
			var distance: float=absf(_point(file).x-global_position.x)
			if distance>4.2 or absf(rise)>1.75 or absf(rise)<0.25:continue
			if (climbing and rise<0) or (not climbing and rise>0):continue
			if _route==null or absf(rise)<absf(_point(_route).y-global_position.y):_route=file
	if is_instance_valid(_route):
		var dx: float=_point(_route).x-global_position.x
		return signf(dx) if absf(dx)>0.15 else 1.0
	return super._chase_direction(offset)
func _can_jump_route(direction: float) -> bool:
	if is_instance_valid(_route):return absf(_point(_route).x-global_position.x)<2.9
	return super._can_jump_route(direction)
